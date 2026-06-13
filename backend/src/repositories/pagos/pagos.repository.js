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

  // Normalizar concepto al formato PostgreSQL (lowercase)
  const conceptoNorm = (concepto || 'otro').toLowerCase()
    .replace('colegiatura', 'colegiatura')
    .replace('inscripcion', 'inscripcion')
    .replace('material_didactico', 'material')
    .replace('uniforme', 'uniforme');

  const { withAudit } = require('../../utils/audit.utils');
  const pago = await withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
    // 1. Crear el pago principal
    const nuevoPago = await tx.pago.create({
      data: {
        alumnoId:      alumnoId ? Number(alumnoId) : null,
        tutorId:       tutorId  ? Number(tutorId)  : null,
        fechaPago:     new Date(fecha),
        montoTotal:    monto,
        metodoPago:    metodoPago ?? 'efectivo',
        observaciones: observaciones ?? null,
        registradoPor: registradoPorId ? Number(registradoPorId) : null,
      },
    });

    // 2. Buscar o crear calendario_pago si no se especifica
    let calId = calendarioPagoId ? Number(calendarioPagoId) : null;

    if (!calId && alumnoId) {
      // Obtener ciclo activo
      const cicloActivo = await tx.cicloEscolar.findFirst({ where: { activo: true } });
      if (cicloActivo) {
        const mesActual = new Date().toLocaleString('es-MX', { month: 'long' }).toLowerCase();

        // Buscar calendario existente pendiente
        let calPago = await tx.calendarioPago.findFirst({
          where: {
            alumnoId: Number(alumnoId),
            cicloId:  cicloActivo.cicloId,
            concepto: conceptoNorm,
            estadoCobro: { not: 'pagado' },
            eliminadoEn: null,
          },
          orderBy: { fechaVencimiento: 'asc' },
        });

        // Si no existe, crear uno
        if (!calPago) {
          calPago = await tx.calendarioPago.create({
            data: {
              alumnoId: Number(alumnoId),
              cicloId:  cicloActivo.cicloId,
              concepto: conceptoNorm,
              mes:      mesActual,
              fechaVencimiento: new Date(),
              montoOriginal: monto,
              montoRecargo:  tieneRecargo ? (montoRecargo ?? 0) : 0,
              estadoCobro:   'pendiente',
            },
          });
        }
        calId = calPago.calendarioPagoId;

        // Aplicar recargo al calendario si aplica
        if (tieneRecargo && montoRecargo > 0) {
          await tx.calendarioPago.update({
            where: { calendarioPagoId: calId },
            data:  { montoRecargo },
          });

          await tx.recargo.create({
            data: {
              calendarioPagoId: calId,
              montoOriginal:    montoRecargo,
              montoActual:      montoRecargo,
              estado:           'aplicado',
            },
          });
        }
      }
    }

    // 3. Crear aplicacion_pago
    if (calId) {
      // Math.max(0, ...) garantiza que el capital nunca sea negativo.
      // Caso edge: recargo > monto (ej: pago $100 con recargo $400) → capital = 0, no -300.
      const montoCapital = Math.max(0, tieneRecargo ? (monto - (montoRecargo ?? 0)) : monto);

      await tx.aplicacionPago.create({
        data: {
          pagoId:           nuevoPago.pagoId,
          calendarioPagoId: calId,
          montoAplicado:    montoCapital,
          aplicadoA:        'capital',
        },
      });

      if (tieneRecargo && montoRecargo > 0) {
        await tx.aplicacionPago.create({
          data: {
            pagoId:           nuevoPago.pagoId,
            calendarioPagoId: calId,
            montoAplicado:    montoRecargo,
            aplicadoA:        'recargo',
          },
        });
      }

      // 4. Actualizar estado del calendario_pago
      const calActual = await tx.calendarioPago.findUnique({
        where: { calendarioPagoId: calId },
        select: { montoOriginal: true, montoRecargo: true, montoPagado: true },
      });

      if (calActual) {
        // Math.round × 100 / 100 evita imprecisión de floating point al sumar
        // montos Decimal de PostgreSQL con números JS (ej: 2499.90 + 1500.10 = 3999.9999...)
        const totalPagado = Math.round((Number(calActual.montoPagado) + Number(monto)) * 100) / 100;
        const totalDeuda  = Math.round((Number(calActual.montoOriginal) + Number(calActual.montoRecargo)) * 100) / 100;
        const estadoCobro = totalPagado >= totalDeuda ? 'pagado'
          : totalPagado > 0 ? 'parcial' : 'pendiente';

        await tx.calendarioPago.update({
          where: { calendarioPagoId: calId },
          data:  {
            montoPagado: totalPagado,
            estadoCobro,
            liquidadoAt: estadoCobro === 'pagado' ? new Date() : null,
          },
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
