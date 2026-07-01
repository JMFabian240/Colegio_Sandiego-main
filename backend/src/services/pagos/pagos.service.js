/**
 * SAE — Pagos Service
 * Reglas de negocio: recargos automáticos, validación de alumno.
 *
 * Cambios PostgreSQL:
 *   - diaCortePago y montoRecargo se leen de configuracion_sistema
 *     (ya no vienen de cicloEscolar.diaCortePago / montoRecargo)
 *   - Se respeta diaLimitePago del alumno si está definido (prioridad alta)
 */

'use strict';

const pagosRepository   = require('../../repositories/pagos/pagos.repository');
const alumnosRepository = require('../../repositories/alumnos/alumnos.repository');
const prisma            = require('../../config/database');

// ── Helpers de configuración ──────────────────────────────────

/**
 * Lee un parámetro de configuracion_sistema.
 * Retorna el valor numérico o el default si no existe.
 */
async function getConfig(clave, defaultValue) {
  try {
    // @@unique([clave, cicloId]) — usar findFirst filtrando por clave global (cicloId null)
    const config = await prisma.configuracionSistema.findFirst({
      where: { clave, cicloId: null },
    });
    return config ? Number(config.valor) : defaultValue;
  } catch {
    return defaultValue;
  }
}

// ── Service functions ─────────────────────────────────────────

async function listar(filtros) {
  return pagosRepository.findAll(filtros);
}

async function obtenerPorId(id) {
  const pago = await pagosRepository.findById(id);
  if (!pago) {
    throw Object.assign(new Error('Pago no encontrado.'), { statusCode: 404 });
  }
  return pago;
}

/**
 * Registra un pago aplicando la regla de recargo automático.
 *
 * Regla vigente (leída de configuracion_sistema):
 *   - recargo_dia_tope_mes   (default: 5)  → día límite sin recargo
 *   - recargo_colegiatura_monto (default: 400) → monto del recargo
 *
 * Si el alumno tiene diaLimitePago definido, se usa ese valor en lugar del
 * día de corte global (permite acuerdos individuales).
 */
async function registrar(datos, usuarioId, auditCtx = {}) {
  const alumno = await alumnosRepository.findById(datos.alumnoId);
  if (!alumno) {
    throw Object.assign(new Error('Alumno no encontrado.'), { statusCode: 404 });
  }

  // Leer configuración de recargo desde configuracion_sistema
  const diaCortePagoGlobal = await getConfig('recargo_dia_tope_mes', 5);
  const montoRecargoConfig = await getConfig('recargo_colegiatura_monto', 400);

  // El alumno puede tener su propio día límite de pago (acuerdo individual)
  const diaCortePago = alumno.diaLimitePago ?? diaCortePagoGlobal;

  // Calcular si aplica recargo
  // Usar UTC para evitar desfase de zona horaria ('2026-09-05' → día 5 siempre)
  const diaDePago = datos.fecha
    ? parseInt(datos.fecha.split('-')[2] || '1', 10)
    : new Date().getUTCDate();

  const conceptoUpper = (datos.concepto || '').toUpperCase();
  const tieneRecargo  = (conceptoUpper === 'COLEGIATURA') && (diaDePago > diaCortePago);
  const recargo       = tieneRecargo ? montoRecargoConfig : 0;

  return pagosRepository.create({
    alumnoId:        Number(datos.alumnoId),
    concepto:        datos.concepto,
    monto:           datos.monto,
    fecha:           datos.fecha,
    tieneRecargo,
    montoRecargo:    recargo,
    registradoPorId: usuarioId,
    observaciones:   datos.observaciones ?? null,
    metodoPago:      datos.metodoPago ?? 'transferencia',
    tutorId:         datos.tutorId ?? null,
    calendarioPagoId:datos.calendarioPagoId ?? null,
  }, auditCtx);
}

/**
 * Obtiene el calendario de pagos de un alumno.
 */
async function obtenerCalendario(filtros) {
  return pagosRepository.findCalendario(filtros);
}

/**
 * Suma total de pagos de un alumno (para reportes).
 */
async function totalPorAlumno(alumnoId) {
  return pagosRepository.sumaByAlumno(alumnoId);
}

/**
 * Registra un pago adelantado de colegiaturas.
 */
async function registrarAdelantado(datos, usuarioId, auditCtx = {}) {
  const { alumnoId, meses, metodoPago, fecha } = datos;
  const numMeses = parseInt(meses, 10);

  if (!numMeses || numMeses <= 0) {
    throw Object.assign(new Error('Debe especificar una cantidad válida de meses a adelantar.'), { statusCode: 400 });
  }

  const alumno = await alumnosRepository.findById(alumnoId);
  if (!alumno) {
    throw Object.assign(new Error('Alumno no encontrado.'), { statusCode: 404 });
  }

  // Buscar colegiaturas futuras pendientes
  const deudasPendientes = await prisma.calendarioPago.findMany({
    where: {
      alumnoId: Number(alumnoId),
      concepto: 'colegiatura',
      estadoCobro: { not: 'pagado' },
      eliminadoEn: null
    },
    include: {
      alumno: {
        select: {
          asignacionesBeca: {
            where: { estado: 'activa' },
            include: { beca: true }
          }
        }
      }
    },
    orderBy: { fechaVencimiento: 'asc' },
  });

  // Filtrar periodos que no tienen saldo vencido, o asumir que las colegiaturas no vencidas 
  // son las que se van a pagar por adelantado. En estricto sentido, los periodos vencidos se
  // deberían pagar primero. Para asegurar orden cronológico, tomamos todas las pendientes en orden.
  // El usuario paga las siguientes 'numMeses' colegiaturas en la lista.
  if (deudasPendientes.length === 0) {
    throw Object.assign(new Error('No existen colegiaturas pendientes para este alumno.'), { statusCode: 400 });
  }

  if (deudasPendientes.length < numMeses) {
    throw Object.assign(new Error(`Sólo hay ${deudasPendientes.length} meses disponibles para pago adelantado.`), { statusCode: 400 });
  }

  // Tomamos exactamente la cantidad de meses solicitados
  const periodosAPagar = deudasPendientes.slice(0, numMeses);

  // Calcular el monto total considerando posibles becas
  let montoTotalEsperado = 0;
  const periodosProcesados = [];

  for (const periodo of periodosAPagar) {
    const asignacionBeca = periodo.alumno?.asignacionesBeca?.[0];
    const porcentajeBeca = asignacionBeca && asignacionBeca.beca ? Number(asignacionBeca.beca.porcentaje) : 0;
    
    let montoCobrado = Number(periodo.montoOriginal);
    if (porcentajeBeca > 0) {
      const descuento = (montoCobrado * porcentajeBeca) / 100;
      montoCobrado = montoCobrado - descuento;
    }
    
    // Sumar recargos si los hubiera en los periodos seleccionados
    const recargoActual = Number(periodo.montoRecargo);
    const pagadoAnterior = Number(periodo.montoPagado);
    
    const saldoPendiente = Math.max(0, (montoCobrado + recargoActual) - pagadoAnterior);
    
    montoTotalEsperado += saldoPendiente;
    periodosProcesados.push({
      calendarioPagoId: periodo.calendarioPagoId,
      montoOriginal: montoCobrado, // el nuevo monto base tras beca
      montoCobrado: saldoPendiente,
      cicloId: periodo.cicloId
    });
  }

  if (Number(datos.monto) && Math.abs(Number(datos.monto) - montoTotalEsperado) > 0.01) {
    throw Object.assign(new Error(`El monto proporcionado (${Number(datos.monto)}) no coincide con el total de los meses seleccionados (${montoTotalEsperado}).`), { statusCode: 400 });
  }

  return pagosRepository.createAdelantado({
    alumnoId: Number(alumnoId),
    tutorId: datos.tutorId,
    montoTotal: montoTotalEsperado,
    metodoPago: metodoPago,
    fecha: fecha || new Date().toISOString(),
    registradoPorId: usuarioId
  }, periodosProcesados, auditCtx);
}

async function registrarConsolidado(datos, usuarioId, auditCtx = {}) {
  const { tutorId, alumnoId, metodoPago, fecha, abonos } = datos;

  if (!tutorId && !alumnoId) {
    throw Object.assign(new Error('El ID del tutor o del alumno es requerido para un pago consolidado.'), { statusCode: 400 });
  }
  if (!abonos || !Array.isArray(abonos) || abonos.length === 0) {
    throw Object.assign(new Error('No se han proporcionado abonos para procesar el pago consolidado.'), { statusCode: 400 });
  }

  // Validar montos y sumas
  let sumaAbonos = 0;
  for (const abono of abonos) {
    if (!abono.calendarioPagoId || !abono.montoAbonado) {
      throw Object.assign(new Error('Cada abono debe tener calendarioPagoId y montoAbonado.'), { statusCode: 400 });
    }
    const monto = Number(abono.montoAbonado);
    if (isNaN(monto) || monto <= 0) {
      throw Object.assign(new Error('El monto abonado debe ser mayor a 0.'), { statusCode: 400 });
    }
    sumaAbonos += monto;
  }

  const datosConSuma = {
    ...datos,
    montoTotal: sumaAbonos,
    registradoPorId: usuarioId
  };

  return pagosRepository.createConsolidado(datosConSuma, abonos, auditCtx);
}

module.exports = { listar, obtenerPorId, registrar, obtenerCalendario, totalPorAlumno, registrarAdelantado, registrarConsolidado };
