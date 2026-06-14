const { withAudit } = require('../../utils/audit.utils');
/**
 * SAE — Grupos Repository (PostgreSQL)
 * Mantiene compatibilidad de respuesta con el frontend existente.
 *
 * Cambios PostgreSQL:
 *   - activo: true → eliminadoEn: null (soft delete)
 *   - id → grupoId
 *   - nivel (string) → nivelId (FK a nivel_educativo)
 *   - materias (embed) → gruposMaterias (N:M con materia FK)
 *   - docente (string) → docenteId (FK a usuario, nullable)
 *   - titular (string) → docenteTitularId (FK a usuario)
 *   - grado + seccion son campos requeridos (parse desde nombre si es necesario)
 *   - GrupoMateria NO tiene campo activo — sólo eliminadoEn para soft delete
 */

'use strict';

const prisma = require('../../config/database');

// ── Mapper ────────────────────────────────────────────────────

function mapGrupo(g) {
  return {
    id:      g.grupoId,
    nombre:  g.nombre,
    nivel:   g.nivel?.codigo ?? null,
    grado:   g.grado,
    seccion: g.seccion,
    cicloId: g.cicloId,
    activo:  g.eliminadoEn === null,
    titular: g.docenteTitular?.nombreCompleto ?? null,
    // Materias en formato anterior: [{ id, materia: string, docente: string, horario, aula }]
    materias: (g.gruposMaterias ?? []).map(gm => ({
      id:      gm.grupoMateriaId,
      materia: gm.materia?.nombre ?? null,
      docente: gm.docente?.nombreCompleto ?? null,
      horario: gm.horario ?? null,
      aula:    gm.aula ?? null,
    })),
    _count: {
      alumnos: g._count?.inscripciones ?? 0,
    },
    createdAt: g.creadoEn,
    updatedAt: g.actualizadoEn,
  };
}

// ── INCLUDE estándar ──────────────────────────────────────────

const INCLUDE_COMPLETO = {
  nivel: { select: { nivelId: true, codigo: true, nombre: true } },
  docenteTitular: { select: { usuarioId: true, nombreCompleto: true } },
  // Relación correcta en Prisma: gruposMaterias (con 's')
  gruposMaterias: {
    where: { eliminadoEn: null },
    select: {
      grupoMateriaId: true,
      horario: true,
      aula: true,
      materia: { select: { materiaId: true, nombre: true } },
      docente: { select: { usuarioId: true, nombreCompleto: true } },
    },
  },
  _count: {
    select: {
      inscripciones: { where: { eliminadoEn: null, estadoEnCiclo: 'activa' } },
    },
  },
};

// ── Helper: parsear grado y seccion desde nombre del grupo ────
/**
 * Extrae grado y seccion del nombre del grupo.
 * Ej: "4°A Primaria" → { grado: '4', seccion: 'A' }
 * Si no puede parsear, retorna defaults.
 */
function parsarGradoSeccion(nombre) {
  const match = nombre?.match(/^(\d+)[°º]?\s*([A-Z])/i);
  if (match) {
    return { grado: match[1], seccion: match[2].toUpperCase() };
  }
  return { grado: '1', seccion: 'A' };
}

// ── Queries ───────────────────────────────────────────────────

async function findAll({ nivel, cicloId } = {}) {
  const where = { eliminadoEn: null };

  if (nivel) {
    where.nivel = { codigo: nivel.toUpperCase() };
  }

  if (cicloId) {
    where.cicloId = Number(cicloId);
  } else {
    const cicloActivo = await prisma.cicloEscolar.findFirst({ where: { activo: true } });
    if (cicloActivo) where.cicloId = cicloActivo.cicloId;
  }

  const grupos = await prisma.grupo.findMany({
    where,
    include: INCLUDE_COMPLETO,
    orderBy: { nombre: 'asc' },
  });

  return grupos.map(mapGrupo);
}

async function findById(id) {
  const grupo = await prisma.grupo.findFirst({
    where: { grupoId: Number(id), eliminadoEn: null },
    include: INCLUDE_COMPLETO,
  });
  return grupo ? mapGrupo(grupo) : null;
}

/**
 * Crea un grupo con sus materias.
 * Acepta el mismo formato anterior:
 *   { nombre, nivel (string), titular (nombre docente o ID), materias: [...] }
 */
async function create(datos, auditCtx = {}) { return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
  const { materias, nombre, nivel, titular, cicloId: datoCicloId, grado: datoGrado, seccion: datoSeccion } = datos;

  // Resolver nivel_id
  let nivelId = null;
  if (nivel) {
    const nivelReg = await tx.nivelEducativo.findFirst({
      where: { codigo: nivel.toUpperCase() },
    });
    nivelId = nivelReg?.nivelId ?? null;
  }

  // Ciclo activo
  const cicloActivo = await tx.cicloEscolar.findFirst({ where: { activo: true } });
  const cicloId = datoCicloId ? Number(datoCicloId) : cicloActivo?.cicloId ?? null;
  if (!cicloId) throw Object.assign(new Error('No hay ciclo escolar activo.'), { statusCode: 422 });

  // grado y seccion (requeridos por el schema)
  const { grado: gradoDefault, seccion: seccionDefault } = parsarGradoSeccion(nombre);
  const grado   = datoGrado   ?? gradoDefault;
  const seccion = datoSeccion ?? seccionDefault;

  // Resolver docente titular
  let docenteTitularId = null;
  if (titular) {
    if (typeof titular === 'number') {
      docenteTitularId = titular;
    } else {
      const docente = await tx.usuario.findFirst({
        where: { nombreCompleto: { contains: titular, mode: 'insensitive' }, eliminadoEn: null },
      });
      docenteTitularId = docente?.usuarioId ?? null;
    }
  }

  const grupo = await tx.grupo.create({
    data: {
      nombre,
      nivelId,
      cicloId,
      grado,
      seccion,
      docenteTitularId,
    },
    include: INCLUDE_COMPLETO,
  });

  // Crear grupoMaterias si se especificaron
  if (materias && materias.length > 0) {
    for (const mat of materias) {
      let materiaReg = await tx.materia.findFirst({
        where: {
          nombre: { equals: mat.materia ?? mat.nombre, mode: 'insensitive' },
          ...(nivelId ? { nivelId } : {}),
          eliminadoEn: null,
        },
      });

      if (!materiaReg) {
        materiaReg = await tx.materia.create({
          data: {
            nombre: mat.materia ?? mat.nombre,
            nivelId: nivelId ?? 1,
            cuentaParaPromedio: true,
          },
        });
      }

      let docenteId = null;
      if (mat.docente) {
        if (typeof mat.docente === 'number') {
          docenteId = mat.docente;
        } else {
          const doc = await tx.usuario.findFirst({
            where: { nombreCompleto: { contains: mat.docente, mode: 'insensitive' }, eliminadoEn: null },
          });
          docenteId = doc?.usuarioId ?? null;
        }
      }

      await tx.grupoMateria.create({
        data: {
          grupoId:   grupo.grupoId,
          materiaId: materiaReg.materiaId,
          docenteId,
          horario:   mat.horario ?? null,
          aula:      mat.aula ?? null,
        },
      });
    }
  }

  return findById(grupo.grupoId);
});
}

/**
 * Actualiza un grupo.
 */
async function update(id, datos, auditCtx = {}) { return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
  const { materias, nombre, nivel, titular } = datos;

  let nivelId;
  if (nivel) {
    const nivelReg = await tx.nivelEducativo.findFirst({
      where: { codigo: nivel.toUpperCase() },
    });
    nivelId = nivelReg?.nivelId;
  }

  let docenteTitularId;
  if (titular !== undefined) {
    if (typeof titular === 'number') {
      docenteTitularId = titular;
    } else if (titular) {
      const docente = await tx.usuario.findFirst({
        where: { nombreCompleto: { contains: titular, mode: 'insensitive' }, eliminadoEn: null },
      });
      docenteTitularId = docente?.usuarioId ?? null;
    } else {
      docenteTitularId = null;
    }
  }

  await tx.grupo.update({
    where: { grupoId: Number(id) },
    data: {
      ...(nombre             ? { nombre }             : {}),
      ...(nivelId            ? { nivelId }            : {}),
      ...(docenteTitularId !== undefined ? { docenteTitularId } : {}),
    },
  });

  // Actualizar materias: desactivar anteriores y crear nuevas
  if (materias && materias.length > 0) {
    await tx.grupoMateria.updateMany({
      where: { grupoId: Number(id), eliminadoEn: null },
      data:  { eliminadoEn: new Date() },
    });

    const grupoActual = await findById(id);
    const nivelIdFinal = nivelId ?? grupoActual?.nivelId ?? null;

    for (const mat of materias) {
      const nombreMateria = mat.materia ?? mat.nombre;
      let materiaReg = await tx.materia.findFirst({
        where: { nombre: { equals: nombreMateria, mode: 'insensitive' }, eliminadoEn: null },
      });
      if (!materiaReg) {
        materiaReg = await tx.materia.create({
          data: { nombre: nombreMateria, nivelId: nivelIdFinal ?? 1, obligatoria: true },
        });
      }

      let docenteId = null;
      if (mat.docente) {
        if (typeof mat.docente === 'number') {
          docenteId = mat.docente;
        } else {
          const doc = await tx.usuario.findFirst({
            where: { nombreCompleto: { contains: mat.docente, mode: 'insensitive' }, eliminadoEn: null },
          });
          docenteId = doc?.usuarioId ?? null;
        }
      }

      await tx.grupoMateria.create({
        data: {
          grupoId:   Number(id),
          materiaId: materiaReg.materiaId,
          docenteId,
          horario:   mat.horario ?? null,
          aula:      mat.aula ?? null,
        },
      });
    }
  }

  return findById(id);
});
}

/**
 * Soft delete de un grupo.
 */
async function softDelete(id, auditCtx = {}) { return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
  return tx.grupo.update({
    where: { grupoId: Number(id) },
    data:  { eliminadoEn: new Date() },
  });
});
}

module.exports = { findAll, findById, create, update, softDelete };
