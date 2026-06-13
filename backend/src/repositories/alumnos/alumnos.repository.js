const { withAudit } = require('../../utils/audit.utils');
/**
 * SAE — Alumnos Repository (PostgreSQL)
 * Mantiene compatibilidad de respuesta con el frontend existente.
 *
 * Mapping de campos:
 *   alumno_id       → id
 *   nombre_completo → nombre
 *   eliminado_en IS NULL → activo: true (soft delete)
 *   tutores (N:M)   → padres[] (backward compat)
 */

'use strict';

const prisma = require('../../config/database');

// ── Selector estándar de include ──────────────────────────────
const INCLUDE_COMPLETO = {
  nivel: { select: { nivelId: true, codigo: true, nombre: true } },
  tutores: {
    where: { activo: true, eliminadoEn: null },
    include: {
      tutor: {
        select: {
          tutorId: true, nombreCompleto: true,
          correoElectronico: true, telefono: true,
          rfc: true, regimenFiscal: true, correoFacturacion: true,
          requiereFactura: true, tipoPagoHabitual: true,
        },
      },
    },
  },
  inscripciones: {
    where: { eliminadoEn: null },
    orderBy: { ciclo: { nombre: 'desc' } },
    take: 1,
    include: {
      grupo: { select: { grupoId: true, nombre: true, nivel: { select: { codigo: true } } } },
      ciclo: { select: { cicloId: true, nombre: true, activo: true } },
      planDepago: { select: { planPagoId: true, nombre: true, meses: true } },
    },
  },
};

/**
 * Convierte un registro Prisma al formato que espera el frontend.
 * Mantiene compatibilidad con la respuesta anterior:
 *   { id, nombre, matricula, curp, grupoId, activo, padres, grupo }
 */
function mapAlumno(a) {
  const inscripcionActual = a.inscripciones?.[0] ?? null;
  return {
    id:       a.alumnoId,
    nombre:   a.nombreCompleto,
    matricula:a.matricula,
    curp:     a.curp,
    grupoId:  inscripcionActual?.grupoId ?? null,
    activo:   a.eliminadoEn === null,
    estado:   a.estado,
    nivel:    a.nivel?.codigo ?? null,
    fechaNacimiento: a.fechaNacimiento,
    sexo:           a.sexo,
    diaLimitePago:  a.diaLimitePago,
    personasAutorizadas: a.personasAutorizadas ?? [],
    observaciones:  a.observaciones,
    // Compatibilidad backward: "padres" como antes
    padres: (a.tutores ?? []).map(ta => ({
      id:      ta.tutor.tutorId,
      nombre:  ta.tutor.nombreCompleto,
      telefono:ta.tutor.telefono,
      email:   ta.tutor.correoElectronico,
      esTutor: ta.esResponsableFinanciero,
      tipoRelacion: ta.tipoRelacion,
      rfc:     ta.tutor.rfc,
      regimenFiscal: ta.tutor.regimenFiscal,
      correoFacturacion: ta.tutor.correoFacturacion,
    })),
    // Datos de inscripción actual
    grupo: inscripcionActual?.grupo
      ? {
          id:    inscripcionActual.grupo.grupoId,
          nombre:inscripcionActual.grupo.nombre,
          nivel: inscripcionActual.grupo.nivel?.codigo ?? null,
        }
      : null,
    cicloActual: inscripcionActual?.ciclo ?? null,
    estadoPago:  inscripcionActual?.estadoFinanciero ?? null,
    mesesAdeudo: inscripcionActual?.mesesAdeudo ?? 0,
    planPago:    inscripcionActual?.planDepago ?? null,
    createdAt:   a.creadoEn,
    updatedAt:   a.actualizadoEn,
  };
}

// ── Queries ───────────────────────────────────────────────────

/**
 * Lista alumnos activos con filtros y paginación opcional.
 *
 * @param {object} opts
 * @param {string}  [opts.q]        Búsqueda libre (nombre, matrícula, CURP)
 * @param {number}  [opts.grupoId]  Filtrar por grupo
 * @param {string}  [opts.nivel]    Filtrar por código de nivel
 * @param {string}  [opts.estado]   Filtrar por estado del alumno
 * @param {number}  [opts.page]     Página (1-based). Omitir = sin paginación
 * @param {number}  [opts.limit]    Registros por página (default 20, max 100)
 *
 * @returns {Array|{data, pagination}} Sin page → array plano. Con page → { data, pagination }
 */
async function findAll({ q, grupoId, nivel, estado, page, limit } = {}) {
  const where = {
    eliminadoEn: null,
  };

  if (estado) {
    where.estado = estado;
  }

  if (nivel) {
    where.nivel = { codigo: nivel };
  }

  if (grupoId) {
    where.inscripciones = {
      some: {
        grupoId: Number(grupoId),
        eliminadoEn: null,
      },
    };
  }

  if (q) {
    where.OR = [
      { nombreCompleto: { contains: q, mode: 'insensitive' } },
      { matricula:      { contains: q, mode: 'insensitive' } },
      { curp:           { contains: q, mode: 'insensitive' } },
    ];
  }

  // ── Sin paginación: backward-compat (mismo comportamiento anterior) ──
  if (!page) {
    const alumnos = await prisma.alumno.findMany({
      where,
      include: INCLUDE_COMPLETO,
      orderBy: { nombreCompleto: 'asc' },
    });
    return alumnos.map(mapAlumno);
  }

  // ── Con paginación: LIMIT/OFFSET + COUNT en paralelo ────────
  const pageNum  = Math.max(1, Number(page));
  const pageSize = Math.min(100, Math.max(1, Number(limit) || 20));
  const skip     = (pageNum - 1) * pageSize;

  const [alumnos, total] = await Promise.all([
    prisma.alumno.findMany({
      where,
      include:  INCLUDE_COMPLETO,
      orderBy:  { nombreCompleto: 'asc' },
      skip,
      take: pageSize,
    }),
    prisma.alumno.count({ where }),
  ]);

  return {
    data: alumnos.map(mapAlumno),
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
 * Busca un alumno por su ID.
 */
async function findById(id) {
  const alumno = await prisma.alumno.findFirst({
    where: { alumnoId: Number(id), eliminadoEn: null },
    include: INCLUDE_COMPLETO,
  });
  return alumno ? mapAlumno(alumno) : null;
}

/**
 * Busca un alumno por matrícula.
 */
async function findByMatricula(matricula) {
  const alumno = await prisma.alumno.findFirst({
    where: { matricula, eliminadoEn: null },
    include: INCLUDE_COMPLETO,
  });
  return alumno ? mapAlumno(alumno) : null;
}

/**
 * Crea un nuevo alumno junto a su tutor principal.
 * Acepta el mismo formato que el frontend: { nombre, matricula, padres[], grupoId, ... }
 */
async function create(datos, auditCtx = {}) { return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
  const {
    padres, nombre, grupoId, nivel,
    // Campos de facturación (antes en alumno, ahora en tutor)
    rfc, regimenFiscal, correoFacturacion,
    autorizadosRecoger,
    ...alumnoData
  } = datos;

  // Resolver nivel_id
  let nivelId = null;
  if (nivel || alumnoData.nivelId) {
    const nivelReg = await tx.nivelEducativo.findFirst({
      where: nivel
        ? { codigo: nivel.toUpperCase() }
        : { nivelId: Number(alumnoData.nivelId) },
    });
    nivelId = nivelReg?.nivelId ?? null;
  }

  // Convertir autorizadosRecoger string → JSONB
  let personasAutorizadas = alumnoData.personasAutorizadas ?? [];
  if (typeof autorizadosRecoger === 'string' && autorizadosRecoger.trim()) {
    personasAutorizadas = [{ nombre: autorizadosRecoger, parentesco: 'tutor' }];
  }

  // Crear el alumno
  const alumno = await tx.alumno.create({
    data: {
      nombreCompleto:     nombre || alumnoData.nombreCompleto,
      matricula:          alumnoData.matricula,
      curp:               alumnoData.curp ?? null,
      fechaNacimiento:    alumnoData.fechaNacimiento ?? null,
      sexo:               alumnoData.sexo ?? null,
      nivelId,
      estado:             alumnoData.estado ?? 'Activo',
      diaLimitePago:      alumnoData.diaLimitePago ?? null,
      personasAutorizadas,
      observaciones:      alumnoData.observaciones ?? null,
    },
    include: INCLUDE_COMPLETO,
  });

  // Crear tutor(es) y vincularlos vía tutor_alumno
  if (padres && padres.length > 0) {
    for (const padre of padres) {
      // Buscar si ya existe el tutor por RFC (o crear nuevo)
      let tutor = null;
      if (rfc || padre.rfc) {
        tutor = await tx.tutor.findFirst({
          where: { rfc: rfc || padre.rfc, eliminadoEn: null },
        });
      }

      if (!tutor) {
        tutor = await tx.tutor.create({
          data: {
            nombreCompleto:    padre.nombre,
            correoElectronico: padre.email ?? null,
            telefono:          padre.telefono ?? null,
            rfc:               rfc ?? padre.rfc ?? null,
            regimenFiscal:     regimenFiscal ?? null,
            correoFacturacion: correoFacturacion ?? null,
            requiereFactura:   !!(correoFacturacion || padre.correoFacturacion),
          },
        });
      }

      // Vincular tutor-alumno
      await tx.tutorAlumno.create({
        data: {
          tutorId:                  tutor.tutorId,
          alumnoId:                 alumno.alumnoId,
          tipoRelacion:             padre.tipoRelacion ?? 'tutor',
          esResponsableFinanciero:  padre.esTutor ?? true,
          puedeRecoger:             true,
          recibeNotificaciones:     true,
        },
      });
    }
  }

  // Inscribir en ciclo activo si se especificó grupoId
  if (grupoId) {
    const cicloActivo = await tx.cicloEscolar.findFirst({
      where: { activo: true },
    });
    if (cicloActivo) {
      await tx.inscripcionCiclo.upsert({
        where: { alumnoId_cicloId: { alumnoId: alumno.alumnoId, cicloId: cicloActivo.cicloId } },
        update: { grupoId: Number(grupoId) },
        create: {
          alumnoId: alumno.alumnoId,
          cicloId:  cicloActivo.cicloId,
          grupoId:  Number(grupoId),
          estadoEnCiclo:    'activa',
          estadoFinanciero: 'al_corriente',
        },
      });
    }
  }

  // Re-query con datos completos
  return findById(alumno.alumnoId);
});
}

/**
 * Actualiza un alumno por ID.
 */
async function update(id, datos, auditCtx = {}) { return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
  const { padres, nombre, nivel, ...rest } = datos;

  let nivelId;
  if (nivel) {
    const nivelReg = await tx.nivelEducativo.findFirst({
      where: { codigo: nivel.toUpperCase() },
    });
    nivelId = nivelReg?.nivelId;
  }

  await tx.alumno.update({
    where: { alumnoId: Number(id) },
    data: {
      ...(nombre ? { nombreCompleto: nombre } : {}),
      ...(nivelId ? { nivelId } : {}),
      ...(rest.curp ? { curp: rest.curp } : {}),
      ...(rest.estado ? { estado: rest.estado } : {}),
      ...(rest.fechaNacimiento !== undefined ? { fechaNacimiento: rest.fechaNacimiento } : {}),
      ...(rest.diaLimitePago !== undefined ? { diaLimitePago: rest.diaLimitePago } : {}),
      ...(rest.observaciones !== undefined ? { observaciones: rest.observaciones } : {}),
    },
  });

  return findById(id);
});
}

/**
 * Soft delete: marca eliminadoEn y estado=Baja Definitiva.
 */
async function softDelete(id, auditCtx = {}) { return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
  return tx.alumno.update({
    where: { alumnoId: Number(id) },
    data: {
      eliminadoEn: new Date(),
      estado:      'Baja Definitiva',
    },
  });
});
}

module.exports = { findAll, findById, findByMatricula, create, update, softDelete };
