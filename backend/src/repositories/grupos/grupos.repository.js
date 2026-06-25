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
      tipo:    gm.materia?.tipo ?? 'curricular',
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
      materia: { select: { materiaId: true, nombre: true, tipo: true } },
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

async function findAll({ nivel, cicloId, todos } = {}, usuario = null) {
  const where = { eliminadoEn: null };

  if (nivel) {
    where.nivel = { codigo: nivel.toUpperCase() };
  }

  if (cicloId) {
    where.cicloId = Number(cicloId);
  } else if (!todos) {
    const cicloActivo = await prisma.cicloEscolar.findFirst({ where: { activo: true } });
    if (cicloActivo) where.cicloId = cicloActivo.cicloId;
  }

  // RBAC para MAESTRA
  const include = JSON.parse(JSON.stringify(INCLUDE_COMPLETO));
  if (usuario && usuario.rol === 'MAESTRA') {
    // Solo ver los grupos donde es titular o da clases
    where.OR = [
      { docenteTitularId: usuario.id },
      { gruposMaterias: { some: { docenteId: usuario.id, eliminadoEn: null } } }
    ];
    // Y dentro de esos grupos, ver solo las materias que imparte
    include.gruposMaterias.where.docenteId = usuario.id;
  }

  const grupos = await prisma.grupo.findMany({
    where,
    include,
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

  const existe = await tx.grupo.findFirst({
    where: { cicloId, nivelId, grado, seccion }
  });

  let grupo;
  if (existe) {
    if (!existe.eliminadoEn) {
      throw Object.assign(new Error('Ya existe un grupo activo con ese nivel, grado y sección.'), { statusCode: 422 });
    }
    grupo = await tx.grupo.update({
      where: { grupoId: existe.grupoId },
      data: {
        nombre,
        docenteTitularId,
        eliminadoEn: null,
      },
      include: INCLUDE_COMPLETO,
    });
    
    // Limpiar materias anteriores porque es una "recreación"
    await tx.grupoMateria.updateMany({
      where: { grupoId: existe.grupoId, eliminadoEn: null },
      data: { eliminadoEn: new Date() }
    });
  } else {
    grupo = await tx.grupo.create({
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
  }

  // Crear grupoMaterias si se especificaron
  if (materias && materias.length > 0) {
    for (const mat of materias) {
      let materiaReg = await tx.materia.findFirst({
        where: {
          nombre: { equals: mat.materia ?? mat.nombre, mode: 'insensitive' },
          ...(nivelId ? { nivelId } : {}),
          tipo: mat.tipo || 'curricular',
          eliminadoEn: null,
        },
      });

      if (!materiaReg) {
        materiaReg = await tx.materia.create({
          data: {
            nombre: mat.materia ?? mat.nombre,
            nivelId: nivelId ?? 1,
            tipo: mat.tipo || 'curricular',
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

      const gmExistente = await tx.grupoMateria.findFirst({
        where: { grupoId: grupo.grupoId, materiaId: materiaReg.materiaId }
      });

      if (gmExistente) {
        await tx.grupoMateria.update({
          where: { grupoMateriaId: gmExistente.grupoMateriaId },
          data: {
            docenteId,
            horario: mat.horario ?? null,
            aula: mat.aula ?? null,
            eliminadoEn: null
          }
        });
      } else {
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
        where: { nombre: { equals: nombreMateria, mode: 'insensitive' }, tipo: mat.tipo || 'curricular', eliminadoEn: null },
      });
      if (!materiaReg) {
        materiaReg = await tx.materia.create({
          data: { nombre: nombreMateria, nivelId: nivelIdFinal ?? 1, tipo: mat.tipo || 'curricular' },
        });
      }

      let docenteId = null;
      if (mat.docente) {
        if (typeof mat.docente === 'number') {
          docenteId = mat.docente;
        } else {
          const u = await tx.usuario.findFirst({
            where: { nombreCompleto: { contains: mat.docente, mode: 'insensitive' }, eliminadoEn: null },
          });
          docenteId = u?.usuarioId ?? null;
        }
      }

      const gmExistente = await tx.grupoMateria.findFirst({
        where: { grupoId: Number(id), materiaId: materiaReg.materiaId }
      });

      if (gmExistente) {
        await tx.grupoMateria.update({
          where: { grupoMateriaId: gmExistente.grupoMateriaId },
          data: {
            docenteId,
            horario: mat.horario,
            aula: mat.aula,
            eliminadoEn: null
          }
        });
      } else {
        await tx.grupoMateria.create({
          data: {
            grupoId: Number(id),
            materiaId: materiaReg.materiaId,
            docenteId,
            horario: mat.horario,
            aula: mat.aula,
          },
        });
      }
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

async function obtenerAlumnosMateria(grupoMateriaId) {
  const inscripciones = await prisma.inscripcionMateria.findMany({
    where: { grupoMateriaId: Number(grupoMateriaId) },
    include: { alumno: { select: { alumnoId: true, matricula: true, nombreCompleto: true } } }
  });
  return inscripciones.map(i => i.alumno);
}

async function actualizarAlumnosMateria(grupoMateriaId, alumnosIds, auditCtx = {}) {
  return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
    await tx.inscripcionMateria.deleteMany({
      where: { grupoMateriaId: Number(grupoMateriaId) }
    });
    
    if (alumnosIds && alumnosIds.length > 0) {
      await tx.inscripcionMateria.createMany({
        data: alumnosIds.map(id => ({
          grupoMateriaId: Number(grupoMateriaId),
          alumnoId: Number(id)
        }))
      });
    }
  });
}

async function promover(origenGrupoId, destinoGrupoId, alumnosIds, auditCtx = {}) {
  return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
    const destino = await tx.grupo.findUnique({
      where: { grupoId: Number(destinoGrupoId) },
      include: { gruposMaterias: { where: { eliminadoEn: null } } }
    });
    
    if (!destino) {
      throw Object.assign(new Error('Grupo destino no encontrado.'), { statusCode: 404 });
    }
    
    for (const alumnoIdStr of alumnosIds) {
      const alumnoId = Number(alumnoIdStr);
      
      // Actualizar o crear inscripción al ciclo
      const inscripcion = await tx.inscripcionCiclo.findUnique({
        where: { alumnoId_cicloId: { alumnoId, cicloId: destino.cicloId } }
      });
      
      if (inscripcion) {
        await tx.inscripcionCiclo.update({
          where: { inscripcionId: inscripcion.inscripcionId },
          data: { grupoId: destino.grupoId }
        });
      } else {
        await tx.inscripcionCiclo.create({
          data: {
            alumnoId,
            cicloId: destino.cicloId,
            grupoId: destino.grupoId
          }
        });
      }
      
      // Inscribir a las materias del nuevo grupo
      for (const gm of destino.gruposMaterias) {
        await tx.inscripcionMateria.upsert({
          where: { alumnoId_grupoMateriaId: { alumnoId, grupoMateriaId: gm.grupoMateriaId } },
          create: { alumnoId, grupoMateriaId: gm.grupoMateriaId },
          update: {}
        });
      }
      
      // Actualizar nivel del alumno para que concuerde con el grupo destino
      await tx.alumno.update({
        where: { alumnoId },
        data: { nivelId: destino.nivelId }
      });
    }
  });
}

module.exports = { findAll, findById, create, update, softDelete, obtenerAlumnosMateria, actualizarAlumnosMateria, promover };
