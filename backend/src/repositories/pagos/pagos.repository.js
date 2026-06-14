/**
 * SAE — Pagos Repository (PostgreSQL)
 * Mantiene compatibilidad de respuesta con el frontend existente.
 *
 * Arquitectura de pagos PostgreSQL:
 *   pago → aplicacion_pago → calendario_pago (schedule)
 *          recargo (si aplica)
 *
 * Backward compat: retorna campos con el mismo contrato que el frontend espera:
 *   { id, alumnoId, concepto, monto, fecha, tieneRecargo, montoRecargo, ... }
 */

'use strict';

const prisma = require('../../config/database');

// ── Mappers ───────────────────────────────────────────────────

function mapPago(p) {
  // Determinar concepto y recargo desde aplicacion_pago → calendario_pago
  const aplicacion = p.aplicaciones?.[0];
  const calendarioPago = aplicacion?.calendarioPago;
  const recargos = calendarioPago?.recargos ?? [];
  const tieneRecargo = recargos.some(r => r.estado === 'aplicado' && Number(r.montoActual) > 0);
  const montoRecargo = recargos.reduce((sum, r) => sum + Number(r.montoActual), 0);

  return {
    id:             p.pagoId,
    alumnoId:       p.alumnoId,
    tutorId:        p.tutorId,
    concepto:       calendarioPago?.concepto ?? 'OTRO',
    mes:            calendarioPago?.mes ?? null,
    monto:          Number(p.montoTotal),
    fecha:          p.fechaPago,
    metodoPago:     p.metodoPago,
    tieneRecargo,
    montoRecargo,
    observaciones:  p.observaciones,
    registradoPorId:p.registradoPor,
    // Datos relacionados
    alumno: p.alumno
      ? { id: p.alumno.alumnoId, nombre: p.alumno.nombreCompleto, matricula: p.alumno.matricula }
      : null,
    registradoPor: p.registradoPorUsuario
      ? { id: p.registradoPorUsuario.usuarioId, nombre: p.registradoPorUsuario.nombreCompleto }
      : null,
    aplicaciones: (p.aplicaciones ?? []).map(ap => ({
      id:             ap.aplicacionId,
      calendarioPagoId: ap.calendarioPagoId,
      montoAplicado:  Number(ap.montoAplicado),
      aplicadoA:      ap.aplicadoA,
    })),
    createdAt: p.registradoEn,
  };
}

// ── Queries ───────────────────────────────────────────────────

const INCLUDE_COMPLETO = {
  alumno: {
    select: { alumnoId: true, nombreCompleto: true, matricula: true },
  },
  registradoPorUsuario: {
    select: { usuarioId: true, nombreCompleto: true },
  },
  aplicaciones: {
    include: {
      calendarioPago: {
        select: {
          calendarioPagoId: true, concepto: true, mes: true,
          montoOriginal: true, montoPagado: true, montoRecargo: true,
          saldoPendiente: true, estadoCobro: true, fechaVencimiento: true,
          recargos: {
            where: { estado: 'aplicado' },
            select: { recargoId: true, montoOriginal: true, montoActual: true, estado: true },
          },
        },
      },
    },
  },
};

/**
 * Lista pagos con filtros y paginación opcional.
 *
 * @param {object} opts
 * @param {number}  [opts.alumnoId]   Filtrar por alumno
 * @param {number}  [opts.tutorId]    Filtrar por tutor
 * @param {string}  [opts.concepto]   Filtrar por concepto (colegiatura, inscripcion…)
 * @param {string}  [opts.fechaDesde] Fecha inicio (ISO)
 * @param {string}  [opts.fechaHasta] Fecha fin (ISO)
 * @param {number}  [opts.page]       Página (1-based). Omitir = sin paginación
 * @param {number}  [opts.limit]      Registros por página (default 25, max 100)
 *
 * @returns {Array|{data, pagination}} Sin page → array plano. Con page → { data, pagination }
 */
async function findAll({ alumnoId, concepto, fechaDesde, fechaHasta, tutorId, page, limit } = {}) {
  const where = {};

  if (alumnoId) where.alumnoId = Number(alumnoId);
  if (tutorId)  where.tutorId  = Number(tutorId);

  if (fechaDesde || fechaHasta) {
    where.fechaPago = {};
    if (fechaDesde) where.fechaPago.gte = new Date(fechaDesde);
    if (fechaHasta) where.fechaPago.lte = new Date(fechaHasta);
  }

  // Filtrar por concepto (vía calendario_pago)
  if (concepto) {
    where.aplicaciones = {
      some: {
        calendarioPago: { concepto: concepto.toLowerCase() },
      },
    };
  }

  // ── Sin paginación: backward-compat ─────────────────────────
  if (!page) {
    const pagos = await prisma.pago.findMany({
      where,
      include: INCLUDE_COMPLETO,
      orderBy: { fechaPago: 'desc' },
    });
    return pagos.map(mapPago);
  }

  // ── Con paginación: LIMIT/OFFSET + COUNT en paralelo ────────
  const pageNum  = Math.max(1, Number(page));
  const pageSize = Math.min(100, Math.max(1, Number(limit) || 25));
  const skip     = (pageNum - 1) * pageSize;

  const [pagos, total] = await Promise.all([
    prisma.pago.findMany({
      where,
      include:  INCLUDE_COMPLETO,
      orderBy:  { fechaPago: 'desc' },
      skip,
      take: pageSize,
    }),
    prisma.pago.count({ where }),
  ]);

  return {
    data: pagos.map(mapPago),
    pagination: {
      page:     pageNum,
      limit:    pageSize,
      total,
      pages:    Math.ceil(total / pageSize),
      hasNext:  pageNum < Math.ceil(total / pageSize),
      hasPrev:  pageNum > 1,
    },
  };
}

/**
 * Busca un pago por ID.
 */
async function findById(id) {
  const pago = await prisma.pago.findUnique({
    where: { pagoId: Number(id) },
    include: INCLUDE_COMPLETO,
  });
  return pago ? mapPago(pago) : null;
}

/**
 * Crea un nuevo pago con su aplicación al calendario.
 * Acepta el mismo formato que antes:
 *   { alumnoId, concepto, monto, fecha, tieneRecargo, montoRecargo, registradoPorId, metodoPago }
 */
async function create(datos, auditCtx = {}) {
  const {
    alumnoId, concepto, monto, fecha, tieneRecargo,
    montoRecargo, registradoPorId, observaciones, metodoPago,
    tutorId, calendarioPagoId,
  } = datos;

  const conceptoNorm = (concepto || 'otro').toLowerCase()
    .replace('colegiatura', 'colegiatura')
    .replace('inscripcion', 'inscripcion')
    .replace('material_didactico', 'material')
    .replace('uniforme', 'uniforme');

  const { withAudit } = require('../../utils/audit.utils');
  const pago = await withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
    
    // 1. Resolver tutorId si no viene explícito
    let tId = tutorId ? Number(tutorId) : null;
    if (!tId && alumnoId) {
      const alumno = await tx.alumno.findUnique({ where: { alumnoId: Number(alumnoId) }, select: { tutores: true } });
      if (alumno && alumno.tutores && alumno.tutores.length > 0) {
        tId = alumno.tutores[0].tutorId;
      }
    }

    // 2. Crear el pago principal
    const nuevoPago = await tx.pago.create({
      data: {
        alumnoId:      alumnoId ? Number(alumnoId) : null,
        tutorId:       tId,
        fechaPago:     new Date(fecha),
        montoTotal:    monto,
        metodoPago:    metodoPago ?? 'efectivo',
        observaciones: observaciones ?? null,
        registradoPor: registradoPorId ? Number(registradoPorId) : null,
      },
    });

    let montoRestante = Number(monto);

    if (alumnoId) {
      // 3. Buscar todas las deudas pendientes ordenadas por fechaVencimiento (más viejas primero)
      const whereClause = {
        alumnoId: Number(alumnoId),
        estadoCobro: { not: 'pagado' },
        eliminadoEn: null,
      };
      if (conceptoNorm !== 'otro') {
        whereClause.concepto = conceptoNorm;
      }

      const deudasPendientes = await tx.calendarioPago.findMany({
        where: whereClause,
        orderBy: { fechaVencimiento: 'asc' },
      });

      // 4. Algoritmo de Distribución de Pagos a Saldos Vencidos Primero
      for (const deuda of deudasPendientes) {
        if (montoRestante <= 0) break;

        // Calcular deuda real actual
        const totalOriginal = Number(deuda.montoOriginal);
        let recargoActual = Number(deuda.montoRecargo);
        const pagadoAnterior = Number(deuda.montoPagado);
        
        // Aplicar recargo si es el pago que lo detona y aún no tiene recargo en la DB
        if (tieneRecargo && deuda.calendarioPagoId === calendarioPagoId && recargoActual === 0) {
           recargoActual = Number(montoRecargo ?? 0);
           await tx.calendarioPago.update({
             where: { calendarioPagoId: deuda.calendarioPagoId },
             data: { montoRecargo: recargoActual },
           });
           await tx.recargo.create({
             data: {
               calendarioPagoId: deuda.calendarioPagoId,
               montoOriginal: recargoActual,
               montoActual: recargoActual,
               estado: 'aplicado',
             },
           });
        }

        const saldoPendiente = Math.max(0, (totalOriginal + recargoActual) - pagadoAnterior);

        if (saldoPendiente > 0) {
          const aplicarMonto = Math.min(saldoPendiente, montoRestante);
          montoRestante -= aplicarMonto;

          // Separar capital y recargo en la aplicación
          let aplicadoCapital = 0;
          let aplicadoRecargo = 0;
          
          // Si hay recargo pendiente (esto es simplificado, asumimos que paga recargo primero o proporcional)
          // Regla estándar de finanzas: Se pagan los recargos e intereses primero.
          const pagadoA_RecargoHastaAhora = 0; // en versión real consultaríamos aplicacionPago, pero usaremos heurística simple: si pagadoAnterior < recargoActual, el pagado fue a recargo.
          // Simplificaremos: el pago se registra como "capital" o "recargo" según el monto.
          
          await tx.aplicacionPago.create({
            data: {
              pagoId:           nuevoPago.pagoId,
              calendarioPagoId: deuda.calendarioPagoId,
              montoAplicado:    aplicarMonto,
              aplicadoA:        'capital', // Para esta versión, registramos todo mixto como capital para simplicidad del reporte.
            },
          });

          const nuevoTotalPagado = pagadoAnterior + aplicarMonto;
          const estadoCobro = nuevoTotalPagado >= (totalOriginal + recargoActual) ? 'pagado' : 'parcial';

          await tx.calendarioPago.update({
            where: { calendarioPagoId: deuda.calendarioPagoId },
            data: {
              montoPagado: nuevoTotalPagado,
              estadoCobro,
              liquidadoAt: estadoCobro === 'pagado' ? new Date() : null,
            },
          });
        }
      }
      
      // 5. Si sobra dinero, crear saldo a favor (MovimientoSaldo)
      if (montoRestante > 0 && tId) {
         await tx.movimientoSaldo.create({
           data: {
             tutorId: tId,
             tipo: 'abono',
             monto: montoRestante,
             pagoId: nuevoPago.pagoId,
             descripcion: 'Saldo a favor por sobrepago o pago anticipado (' + conceptoNorm + ')',
           }
         });
      }
    }

    return nuevoPago;
  });

  return findById(pago.pagoId);
}

/**
 * Suma de pagos de un alumno.
 */
async function sumaByAlumno(alumnoId) {
  const result = await prisma.pago.aggregate({
    where: { alumnoId: Number(alumnoId) },
    _sum: { montoTotal: true },
  });
  return { _sum: { monto: Number(result._sum.montoTotal ?? 0) } };
}

/**
 * Lista el calendario de pagos de un alumno.
 */
async function findCalendario({ alumnoId, cicloId, estadoCobro } = {}) {
  const where = { eliminadoEn: null };
  if (alumnoId) where.alumnoId = Number(alumnoId);
  if (cicloId)  where.cicloId  = Number(cicloId);
  if (estadoCobro) where.estadoCobro = estadoCobro;

  return prisma.calendarioPago.findMany({
    where,
    include: {
      recargos: { where: { estado: 'aplicado' } },
    },
    orderBy: [{ fechaVencimiento: 'asc' }],
  });
}

module.exports = { findAll, findById, create, sumaByAlumno, findCalendario };
