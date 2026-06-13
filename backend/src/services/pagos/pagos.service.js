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
    metodoPago:      datos.metodoPago ?? 'efectivo',
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

module.exports = { listar, obtenerPorId, registrar, obtenerCalendario, totalPorAlumno };
