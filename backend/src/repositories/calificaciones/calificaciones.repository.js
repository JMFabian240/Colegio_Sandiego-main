const { withAudit } = require('../../utils/audit.utils');
/**
 * SAE — Calificaciones Repository (PostgreSQL)
 * Mantiene compatibilidad con el frontend existente.
 *
 * Cambios clave:
 *   - calificacion.valor → valor_numerico (Decimal)
 *   - calificacion.periodo (string) → periodo_id (FK a periodo_evaluacion)
 *   - grupoMateria.materia (string) → materia.nombre (FK)
 *
 * Backward compat: el API sigue aceptando "periodo" como string
 * (TRIMESTRE_1/TRIMESTRE_2/TRIMESTRE_3) y lo resuelve a periodo_id.
 */

'use strict';

const prisma = require('../../config/database');

// ── Mapper ────────────────────────────────────────────────────

function mapCalificacion(c) {
  return {
    id:             c.calificacionId,
    alumnoId:       c.alumnoId,
    grupoMateriaId: c.grupoMateriaId,
    periodoId:      c.periodoId,
    // Backward compat: "periodo" como string
    periodo:        c.periodo?.nombre ?? c.periodo?.tipo ?? null,
    tipoEvaluacion: c.tipoEvaluacion,
    valor:          c.valorNumerico !== null ? Number(c.valorNumerico) : null,
    valorCualitativo: c.valorCualitativo,
    textoObservacion: c.textoObservacion,
    cuentaParaPromedio: c.cuentaParaPromedio,
    createdAt: c.registradaEn,
    updatedAt: c.actualizadoEn,
    alumno: c.alumno
      ? { id: c.alumno.alumnoId, nombre: c.alumno.nombreCompleto, matricula: c.alumno.matricula }
      : null,
    grupoMateria: c.grupoMateria
      ? {
          id:      c.grupoMateria.grupoMateriaId,
          materia: c.grupoMateria.materia?.nombre ?? null,
          docente: c.grupoMateria.docente?.nombreCompleto ?? null,
          grupo: c.grupoMateria.grupo
            ? { id: c.grupoMateria.grupo.grupoId, nombre: c.grupoMateria.grupo.nombre }
            : null,
        }
      : null,
    registradoPor: c.registradoPorUsuario
      ? { id: c.registradoPorUsuario.usuarioId, nombre: c.registradoPorUsuario.nombreCompleto }
      : null,
  };
}

// ── INCLUDE estándar ──────────────────────────────────────────
const INCLUDE_COMPLETO = {
  alumno:      { select: { alumnoId: true, nombreCompleto: true, matricula: true } },
  grupoMateria:{
    select: {
      grupoMateriaId: true,
      materia: { select: { materiaId: true, nombre: true } },
      docente: { select: { usuarioId: true, nombreCompleto: true } },
      grupo:   { select: { grupoId: true, nombre: true } },
    },
  },
  periodo:     { select: { periodoId: true, nombre: true, tipo: true, numero: true } },
  registradoPorUsuario: { select: { usuarioId: true, nombreCompleto: true } },
};

// ── Helper: resolver periodo_id desde string ──────────────────
/**
 * Convierte el string de período (ej: "TRIMESTRE_1") al periodo_id
 * del ciclo activo / nivel correspondiente.
 * Si el periodo ya es un número, lo usa directamente.
 */
async function resolverPeriodoId(periodo, grupoMateriaId) {
  if (typeof periodo === 'number' || /^\d+$/.test(String(periodo))) {
    return Number(periodo);
  }

  // Determinar nivel del grupo_materia
  const gm = await prisma.grupoMateria.findUnique({
    where: { grupoMateriaId: Number(grupoMateriaId) },
    select: { grupo: { select: { cicloId: true, nivelId: true } } },
  });

  if (!gm?.grupo) return null;

  // Mapear strings de período a tipo y numero
  const mapa = {
    TRIMESTRE_1: { tipo: 'trimestre', numero: 1 },
    TRIMESTRE_2: { tipo: 'trimestre', numero: 2 },
    TRIMESTRE_3: { tipo: 'trimestre', numero: 3 },
    BIMESTRE_1:  { tipo: 'bimestre',  numero: 1 },
    BIMESTRE_2:  { tipo: 'bimestre',  numero: 2 },
    SEMESTRE_1:  { tipo: 'semestre',  numero: 1 },
    SEMESTRE_2:  { tipo: 'semestre',  numero: 2 },
    FINAL:       { tipo: 'final',     numero: 1 },
  };

  const mapped = mapa[periodo?.toUpperCase?.()] ?? { tipo: 'trimestre', numero: 1 };

  const periodoReg = await prisma.periodoEvaluacion.findFirst({
    where: {
      cicloId: gm.grupo.cicloId,
      nivelId: gm.grupo.nivelId,
      tipo:    mapped.tipo,
      numero:  mapped.numero,
      eliminadoEn: null,
    },
  });

  // Si no existe, crear el período automáticamente.
  // Se maneja P2002 (unique constraint) para la race condition:
  // si dos requests llegan simultáneamente, la que pierde la carrera
  // simplemente recupera el período ya creado por la ganadora.
  if (!periodoReg) {
    const ciclo = await prisma.cicloEscolar.findUnique({
      where: { cicloId: gm.grupo.cicloId },
    });
    try {
      const nuevoPeriodo = await prisma.periodoEvaluacion.create({
        data: {
          cicloId:    gm.grupo.cicloId,
          nivelId:    gm.grupo.nivelId,
          tipo:       mapped.tipo,
          numero:     mapped.numero,
          nombre:     `${mapped.tipo.charAt(0).toUpperCase() + mapped.tipo.slice(1)} ${mapped.numero}`,
          fechaInicio: (() => {
            const d = ciclo?.fechaInicio ? new Date(ciclo.fechaInicio) : new Date();
            d.setMonth(d.getMonth() + ((mapped.numero - 1) * 3));
            return d;
          })(),
          fechaFin: (() => {
            const d = ciclo?.fechaInicio ? new Date(ciclo.fechaInicio) : new Date();
            d.setMonth(d.getMonth() + (mapped.numero * 3));
            d.setDate(d.getDate() - 1);
            return d;
          })(),
        },
      });
      return nuevoPeriodo.periodoId;
    } catch (e) {
      if (e.code === 'P2002') {
        // Otra request ganó la carrera — recuperar el período recién creado
        const existente = await prisma.periodoEvaluacion.findFirst({
          where: {
            cicloId: gm.grupo.cicloId,
            nivelId: gm.grupo.nivelId,
            tipo:    mapped.tipo,
            numero:  mapped.numero,
            eliminadoEn: null,
          },
        });
        return existente?.periodoId ?? null;
      }
      throw e;
    }
  }

  return periodoReg.periodoId;
}

// ── Queries ───────────────────────────────────────────────────

async function findAll({ alumnoId, grupoId, grupoMateriaId, periodo, soloParaPromedio } = {}) {
  const where = {};
  if (alumnoId)      where.alumnoId       = Number(alumnoId);
  if (grupoMateriaId)where.grupoMateriaId = Number(grupoMateriaId);

  // Filtrar directamente en la query cuando solo interesan calificaciones
  // que cuentan para el promedio — evita cargar y descartar registros en memoria
  if (soloParaPromedio) {
    where.cuentaParaPromedio = true;
    where.valorNumerico      = { not: null };
  }

  if (grupoId) {
    where.grupoMateria = { grupoId: Number(grupoId) };
  }

  // Filtro por período (string → id)
  if (periodo) {
    const mapa = {
      TRIMESTRE_1: { tipo: 'trimestre', numero: 1 },
      TRIMESTRE_2: { tipo: 'trimestre', numero: 2 },
      TRIMESTRE_3: { tipo: 'trimestre', numero: 3 },
    };
    const mp = mapa[periodo?.toUpperCase?.()];
    if (mp) {
      where.periodo = { tipo: mp.tipo, numero: mp.numero };
    }
  }

  const cals = await prisma.calificacion.findMany({
    where,
    include: INCLUDE_COMPLETO,
    orderBy: [{ alumno: { nombreCompleto: 'asc' } }],
  });

  return cals.map(mapCalificacion);
}

async function findByAlumnoYPeriodo(alumnoId, periodo) {
  const mapa = {
    TRIMESTRE_1: { tipo: 'trimestre', numero: 1 },
    TRIMESTRE_2: { tipo: 'trimestre', numero: 2 },
    TRIMESTRE_3: { tipo: 'trimestre', numero: 3 },
  };
  const mp = mapa[periodo?.toUpperCase?.()];

  const where = {
    alumnoId: Number(alumnoId),
    ...(mp ? { periodo: { tipo: mp.tipo, numero: mp.numero } } : {}),
  };

  const cals = await prisma.calificacion.findMany({
    where,
    include: INCLUDE_COMPLETO,
  });

  return cals.map(mapCalificacion);
}

/**
 * Upsert de una calificación individual.
 * Acepta el mismo formato anterior:
 *   { alumnoId, grupoMateriaId, periodo (string), valor, registradoPorId }
 */
async function upsert(datos, auditCtx = {}) { 
  const { alumnoId, grupoMateriaId, periodo, valor, registradoPorId, tipoEvaluacion, textoObservacion } = datos;

  const periodoId = await resolverPeriodoId(periodo, grupoMateriaId);
  if (!periodoId) throw new Error(`Período '${periodo}' no pudo resolverse.`);

  return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
    const cal = await tx.calificacion.upsert({
      where: {
        alumnoId_grupoMateriaId_periodoId: {
          alumnoId:       Number(alumnoId),
          grupoMateriaId: Number(grupoMateriaId),
          periodoId,
        },
      },
      create: {
        alumnoId:       Number(alumnoId),
        grupoMateriaId: Number(grupoMateriaId),
        periodoId,
        tipoEvaluacion: tipoEvaluacion ?? 'numerica',
        valorNumerico:  valor !== undefined ? valor : null,
        textoObservacion: textoObservacion ?? null,
        registradaPor:  registradoPorId ? Number(registradoPorId) : null,
      },
      update: {
        valorNumerico: valor !== undefined ? valor : undefined,
        tipoEvaluacion: tipoEvaluacion,
        textoObservacion: textoObservacion !== undefined ? textoObservacion : undefined,
        registradaPor: registradoPorId ? Number(registradoPorId) : undefined,
      },
      include: INCLUDE_COMPLETO,
    });

    return mapCalificacion(cal);
  });
}

/**
 * Upsert masivo de calificaciones.
 */
async function upsertLote(registros, auditCtx = {}) {
  return Promise.all(registros.map((r) => upsert(r, auditCtx)));
}

module.exports = { findAll, findByAlumnoYPeriodo, upsert, upsertLote };
