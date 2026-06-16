const { withAudit } = require('../../utils/audit.utils');
/**
 * SAE — Becas Repository (PostgreSQL)
 * Mantiene compatibilidad con el frontend existente.
 *
 * Arquitectura PostgreSQL:
 *   beca (catálogo) → asignacion_beca (por alumno/ciclo)
 *                  → solicitud_beca (workflow RF-21)
 *
 * Backward compat: los endpoints de "becas" activas devuelven
 * asignaciones activas del ciclo corriente, no el catálogo.
 */

'use strict';

const prisma = require('../../config/database');

// ── Mapper de asignación → formato frontend (backward compat) ─
function mapAsignacion(asig) {
  return {
    id:         asig.asignacionId,
    alumnoId:   asig.alumnoId,
    becaId:     asig.becaId,
    tipo:       asig.beca?.criterio?.toUpperCase() ?? 'OTRO',
    nombre:     asig.beca?.nombreBeca ?? null,
    porcentaje: Number(asig.beca?.porcentaje ?? 0),
    activa:     asig.estado === 'activa',
    estado:     asig.estado,
    fechaInicio:asig.fechaAsignacion,
    fechaFin:   asig.fechaRetiro,
    motivoRetiro:asig.motivoRetiro,
    createdAt:  asig.creadoEn,
    updatedAt:  asig.actualizadoEn,
    alumno: asig.alumno
      ? { id: asig.alumno.alumnoId, nombre: asig.alumno.nombreCompleto, matricula: asig.alumno.matricula }
      : null,
    beca: asig.beca
      ? { id: asig.beca.becaId, nombre: asig.beca.nombreBeca, criterio: asig.beca.criterio, porcentaje: Number(asig.beca.porcentaje) }
      : null,
  };
}

// ── Mapper de solicitud ───────────────────────────────────────
function mapSolicitud(sol) {
  return {
    id:              sol.solicitudId,
    alumnoId:        sol.alumnoId,
    solicitadoPorId: sol.solicitadaPor,
    tipo:            sol.beca?.criterio?.toUpperCase() ?? 'OTRO',
    nombre:          sol.beca?.nombreBeca ?? null,
    porcentaje:      Number(sol.beca?.porcentaje ?? 0),
    tipoSolicitud:   sol.tipoSolicitud,
    motivo:          sol.motivo,
    estado:          sol.estado?.toUpperCase() ?? 'PENDIENTE',
    aprobadoPorId:   sol.resueltaPor,
    fechaSolicitud:  sol.fechaSolicitud,
    fechaResolucion: sol.fechaResolucion,
    observaciones:   sol.observaciones,
    alumno: sol.alumno
      ? { id: sol.alumno.alumnoId, nombre: sol.alumno.nombreCompleto, matricula: sol.alumno.matricula }
      : null,
    solicitadoPor: sol.solicitadaPorUsuario
      ? { id: sol.solicitadaPorUsuario.usuarioId, nombre: sol.solicitadaPorUsuario.nombreCompleto }
      : null,
    aprobadoPor: sol.resueltaPorUsuario
      ? { id: sol.resueltaPorUsuario.usuarioId, nombre: sol.resueltaPorUsuario.nombreCompleto }
      : null,
  };
}

// ── INCLUDE comunes ───────────────────────────────────────────
const INCLUDE_ASIGNACION = {
  alumno: { select: { alumnoId: true, nombreCompleto: true, matricula: true } },
  beca:   { select: { becaId: true, nombreBeca: true, criterio: true, porcentaje: true } },
  asignadaPorUsuario: { select: { usuarioId: true, nombreCompleto: true } },
};

const INCLUDE_SOLICITUD = {
  alumno:              { select: { alumnoId: true, nombreCompleto: true, matricula: true } },
  beca:                { select: { becaId: true, nombreBeca: true, criterio: true, porcentaje: true } },
  solicitadaPorUsuario:{ select: { usuarioId: true, nombreCompleto: true } },
  resueltaPorUsuario:  { select: { usuarioId: true, nombreCompleto: true } },
};

// ── Ciclo activo helper ───────────────────────────────────────
async function getCicloActivo() {
  return prisma.cicloEscolar.findFirst({ where: { activo: true } });
}

// ── BECAS ACTIVAS (asignaciones) ─────────────────────────────

async function findBecasActivas() {
  const ciclo = await getCicloActivo();
  const asignaciones = await prisma.asignacionBeca.findMany({
    where: {
      estado: 'activa',
      eliminadoEn: null,
      ...(ciclo ? { cicloId: ciclo.cicloId } : {}),
    },
    include: INCLUDE_ASIGNACION,
    orderBy: { creadoEn: 'desc' },
  });
  return asignaciones.map(mapAsignacion);
}

async function findBecaByAlumno(alumnoId) {
  const ciclo = await getCicloActivo();
  const asignaciones = await prisma.asignacionBeca.findMany({
    where: {
      alumnoId: Number(alumnoId),
      estado:   'activa',
      eliminadoEn: null,
      ...(ciclo ? { cicloId: ciclo.cicloId } : {}),
    },
    include: INCLUDE_ASIGNACION,
  });
  return asignaciones.map(mapAsignacion);
}

/**
 * Crea una asignación de beca para un alumno.
 * Acepta el mismo formato que antes:
 *   { alumnoId, tipo, porcentaje, asignadoPorId }
 */
async function createBeca(datos) {
  const { alumnoId, tipo, porcentaje, asignadoPorId, nombre } = datos;

  const ciclo = await getCicloActivo();
  if (!ciclo) throw Object.assign(new Error('No hay ciclo escolar activo.'), { statusCode: 422 });

  // Buscar beca del catálogo por criterio o nombre
  let beca;
  if (nombre) {
    beca = await prisma.beca.findFirst({ where: { nombreBeca: { equals: nombre, mode: 'insensitive' }, eliminadoEn: null } });
  }
  if (!beca && tipo) {
    const criterioMap = {
      HERMANOS:             'hermanos',
      EXCELENCIA:           'calificacion',
      INSCRIPCION_TEMPRANA: 'inscripcion_temprana',
      OTRO:                 'otro',
    };
    beca = await prisma.beca.findFirst({
      where: { criterio: criterioMap[tipo] ?? tipo.toLowerCase(), eliminadoEn: null },
    });
  }
  if (!beca) {
    // Crear beca en catálogo si no existe
    beca = await prisma.beca.create({
      data: {
        nombreBeca:  nombre ?? tipo,
        criterio:    'otro',
        porcentaje:  porcentaje ?? 0,
      },
    });
  }

  const asignacion = await prisma.asignacionBeca.create({
    data: {
      alumnoId:    Number(alumnoId),
      becaId:      beca.becaId,
      cicloId:     ciclo.cicloId,
      estado:      'activa',
      asignadaPor: asignadoPorId ? Number(asignadoPorId) : null,
    },
    include: INCLUDE_ASIGNACION,
  });

  return mapAsignacion(asignacion);
}

async function createAsignacionDirecta(datos, asignadaPorId, auditCtx = {}) { return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
  const { alumnoId, becaId, cicloId } = datos;

  const ciclo = cicloId
    ? await tx.cicloEscolar.findUnique({ where: { cicloId: Number(cicloId) } })
    : await getCicloActivo();

  if (!ciclo) throw Object.assign(new Error('No hay ciclo escolar activo.'), { statusCode: 422 });

  const beca = await tx.beca.findUnique({ where: { becaId: Number(becaId) } });
  if (!beca) throw Object.assign(new Error('Beca no encontrada.'), { statusCode: 404 });

  // Desactivar becas anteriores del alumno en este ciclo
  await tx.asignacionBeca.updateMany({
    where: { alumnoId: Number(alumnoId), cicloId: ciclo.cicloId, estado: 'activa' },
    data: { estado: 'retirada', fechaRetiro: new Date(), motivoRetiro: 'Reemplazada por una nueva beca' }
  });

  const asignacion = await tx.asignacionBeca.create({
    data: {
      alumnoId:    Number(alumnoId),
      becaId:      beca.becaId,
      cicloId:     ciclo.cicloId,
      estado:      'activa',
      asignadaPor: asignadaPorId ? Number(asignadaPorId) : null,
    },
    include: INCLUDE_ASIGNACION,
  });

  return mapAsignacion(asignacion);
});
}

/**
 * Retira (desactiva) una beca de un alumno.
 */
async function deactivateBeca(id, auditCtx = {}) { return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
  const asignacion = await tx.asignacionBeca.update({
    where: { asignacionId: Number(id) },
    data:  { estado: 'retirada', fechaRetiro: new Date() },
    include: INCLUDE_ASIGNACION,
  });
  return mapAsignacion(asignacion);
});
}

async function retirarAsignacionDirecta(asignacionId, motivo, retiradaPorId, auditCtx = {}) { return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
  const asignacion = await tx.asignacionBeca.update({
    where: { asignacionId: Number(asignacionId) },
    data:  { 
      estado: 'retirada', 
      fechaRetiro: new Date(),
      motivoRetiro: motivo,
      retiradaPor: retiradaPorId ? Number(retiradaPorId) : null 
    },
    include: INCLUDE_ASIGNACION,
  });
  return mapAsignacion(asignacion);
});
}

// ── SOLICITUDES DE BECA (Flujo RF-21) ────────────────────────

async function findSolicitudes({ estado, solicitadoPorId } = {}) {
  const where = { eliminadoEn: null };
  if (estado && estado !== 'TODOS') {
    where.estado = estado.toLowerCase();
  }
  if (solicitadoPorId) where.solicitadaPor = Number(solicitadoPorId);

  const solicitudes = await prisma.solicitudBeca.findMany({
    where,
    include: INCLUDE_SOLICITUD,
    orderBy: { fechaSolicitud: 'desc' },
  });

  return solicitudes.map(mapSolicitud);
}

async function findSolicitudById(id) {
  const sol = await prisma.solicitudBeca.findUnique({
    where: { solicitudId: Number(id) },
    include: INCLUDE_SOLICITUD,
  });
  return sol ? mapSolicitud(sol) : null;
}

async function createSolicitud(datos, auditCtx = {}) { return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
  const { alumnoId, becaId, tipoSolicitud, motivo, solicitadoPorId, cicloId } = datos;

  const ciclo = cicloId
    ? await tx.cicloEscolar.findUnique({ where: { cicloId: Number(cicloId) } })
    : await getCicloActivo();

  if (!ciclo) throw Object.assign(new Error('No hay ciclo escolar activo.'), { statusCode: 422 });

  const beca = await tx.beca.findUnique({ where: { becaId: Number(becaId) } });
  if (!beca) throw Object.assign(new Error('Beca no encontrada en el catálogo.'), { statusCode: 404 });

  const sol = await tx.solicitudBeca.create({
    data: {
      alumnoId:   Number(alumnoId),
      becaId:     beca.becaId,
      cicloId:    ciclo.cicloId,
      motivo:     motivo ?? '',
      estado:     'pendiente',
      solicitadaPor: solicitadoPorId ? Number(solicitadoPorId) : null,
    },
    include: INCLUDE_SOLICITUD,
  });

  return mapSolicitud(sol);
});
}

/**
 * Resuelve una solicitud (aprobada/rechazada).
 * Si se aprueba → crea asignacion_beca.
 */
async function resolverSolicitud(id, { estado, aprobadoPorId, observaciones }, auditCtx = {}) { return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
  const estadoNorm = estado.toLowerCase();

  const sol = await tx.solicitudBeca.update({
    where: { solicitudId: Number(id) },
    data: {
      estado:          estadoNorm,
      resueltaPor:     aprobadoPorId ? Number(aprobadoPorId) : null,
      observaciones,
      fechaResolucion: new Date(),
    },
    include: INCLUDE_SOLICITUD,
  });

  // Si se aprueba, materializar la acción de beca
  if (estadoNorm === 'aprobada') {
    // Desactivar becas anteriores del alumno en este ciclo
    await tx.asignacionBeca.updateMany({
      where: { alumnoId: sol.alumnoId, cicloId: sol.cicloId, estado: 'activa', becaId: { not: sol.becaId } },
      data: { estado: 'retirada', fechaRetiro: new Date(), motivoRetiro: 'Reemplazada por nueva beca autorizada' }
    });

    await tx.asignacionBeca.upsert({
      where: { alumnoId_becaId_cicloId: { alumnoId: sol.alumnoId, becaId: sol.becaId, cicloId: sol.cicloId } },
      update: { estado: 'activa', fechaRetiro: null, motivoRetiro: null },
      create: {
        alumnoId:    sol.alumnoId,
        becaId:      sol.becaId,
        cicloId:     sol.cicloId,
        solicitudId: sol.solicitudId,
        estado:      'activa',
        asignadaPor: sol.resueltaPor,
      },
    });
  }

  return mapSolicitud(sol);
});
}

// ── CATÁLOGO DE BECAS ─────────────────────────────────────────

async function getCatalogoBecas() {
  return prisma.beca.findMany({
    where: { eliminadoEn: null },
    orderBy: { creadoEn: 'desc' },
  });
}

async function createCatalogoBeca({ nombreBeca, criterio, porcentaje, descripcion }, auditCtx = {}) { return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
  return tx.beca.create({
    data: {
      nombreBeca,
      criterio,
      porcentaje: Number(porcentaje),
      descripcion,
    },
  });
});
}

async function updateCatalogoBeca(id, { nombreBeca, criterio, porcentaje, descripcion }, auditCtx = {}) { return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
  return tx.beca.update({
    where: { becaId: Number(id) },
    data: {
      ...(nombreBeca && { nombreBeca }),
      ...(criterio && { criterio }),
      ...(porcentaje && { porcentaje: Number(porcentaje) }),
      ...(descripcion !== undefined && { descripcion }),
    },
  });
});
}

async function deleteCatalogoBeca(id) {
  return prisma.beca.update({
    where: { becaId: Number(id) },
    data: { eliminadoEn: new Date() },
  });
}

module.exports = {
  findBecasActivas, findBecaByAlumno, deactivateBeca,
  createAsignacionDirecta, retirarAsignacionDirecta,
  findSolicitudes, findSolicitudById, createSolicitud, resolverSolicitud,
  getCatalogoBecas, createCatalogoBeca, updateCatalogoBeca, deleteCatalogoBeca,
};
