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
      grupo: { select: { grupoId: true, nombre: true, grado: true, seccion: true, nivel: { select: { codigo: true } } } },
      ciclo: { select: { cicloId: true, nombre: true, activo: true } },
      planDepago: { select: { planPagoId: true, nombre: true, meses: true, montoMensual: true } },
    },
  },
  asignacionesBeca: {
    where: { estado: 'activa' },
    include: { beca: true }
  },
  inscripcionesMateria: {
    include: {
      grupoMateria: {
        select: {
          grupoMateriaId: true,
          horario: true,
          aula: true,
          materia: { select: { materiaId: true, nombre: true, tipo: true } },
          docente: { select: { usuarioId: true, nombreCompleto: true } }
        }
      }
    }
  }
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
          grado: inscripcionActual.grupo.grado,
          seccion: inscripcionActual.grupo.seccion,
        }
      : null,
    cicloActual: inscripcionActual?.ciclo ?? null,
    estadoPago:  inscripcionActual?.estadoFinanciero ?? null,
    mesesAdeudo: inscripcionActual?.mesesAdeudo ?? 0,
    planPago:    inscripcionActual?.planDepago ?? null,
    beca:        a.asignacionesBeca?.length > 0 ? a.asignacionesBeca[0].beca : null,
    materiasExtra: (a.inscripcionesMateria ?? []).map(im => ({
      id:      im.grupoMateria.grupoMateriaId,
      materia: im.grupoMateria.materia?.nombre ?? null,
      docente: im.grupoMateria.docente?.nombreCompleto ?? null,
      horario: im.grupoMateria.horario ?? null,
      aula:    im.grupoMateria.aula ?? null,
      tipo:    im.grupoMateria.materia?.tipo ?? 'curricular',
    })),
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
async function findAll({ q, grupoId, nivel, grado, seccion, estado, page, limit } = {}, usuario = null) {
  const where = {};

  if (estado && estado !== 'Todos') {
    if (estado !== 'deudores') {
      // Filtramos exactamente por el estado solicitado (Activo, Baja Temporal, Baja Definitiva, Egresado)
      where.estado = estado;
    } else {
      where.eliminadoEn = null;
    }
  } else if (!estado) {
    // Comportamiento por defecto al cargar sin filtros: ocultamos bajas definitivas
    where.eliminadoEn = null;
  }

  if (nivel) {
    where.nivel = { codigo: nivel };
  }

  const inscripcionesSome = { eliminadoEn: null };
  let filterInscripcion = false;

  if (estado === 'deudores') {
    inscripcionesSome.estadoFinanciero = { not: 'al_corriente' };
    filterInscripcion = true;
  }

  let filterGrupo = false;
  const grupoWhere = {};

  if (grupoId) {
    inscripcionesSome.grupoId = Number(grupoId);
    filterInscripcion = true;
  }
  
  if (grado) {
    grupoWhere.grado = String(grado);
    filterGrupo = true;
  }
  if (seccion) {
    grupoWhere.seccion = seccion;
    filterGrupo = true;
  }

  if (usuario && usuario.rol === 'MAESTRA') {
    const tienePermisoPagos = usuario.permisos && usuario.permisos.pagos && usuario.permisos.pagos !== 'NINGUNO';
    if (!tienePermisoPagos) {
      grupoWhere.OR = [
        { docenteTitularId: usuario.id },
        { gruposMaterias: { some: { docenteId: usuario.id, eliminadoEn: null } } }
      ];
      grupoWhere.ciclo = { activo: true };
      filterGrupo = true;
    }
  }

  if (filterGrupo) {
    inscripcionesSome.grupo = grupoWhere;
    filterInscripcion = true;
  }

  if (filterInscripcion) {
    where.inscripciones = { some: inscripcionesSome };
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
    where: { alumnoId: Number(id) },
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
      if (padre.tutorId) {
        tutor = await tx.tutor.findUnique({ where: { tutorId: Number(padre.tutorId) } });
      } else if (rfc || padre.rfc) {
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
      // Buscar el primer plan de pago activo del ciclo (idealmente el de 10 o 12 meses por defecto)
      const planDefault = await tx.planPago.findFirst({
        where: { cicloId: cicloActivo.cicloId, activo: true }
      });
      
      await tx.inscripcionCiclo.upsert({
        where: { alumnoId_cicloId: { alumnoId: alumno.alumnoId, cicloId: cicloActivo.cicloId } },
        update: { 
          grupoId: Number(grupoId), 
          planPagoId: datos.planPagoId ? Number(datos.planPagoId) : (planDefault?.planPagoId ?? null) 
        },
        create: {
          alumnoId: alumno.alumnoId,
          cicloId:  cicloActivo.cicloId,
          grupoId:  Number(grupoId),
          planPagoId: datos.planPagoId ? Number(datos.planPagoId) : (planDefault?.planPagoId ?? null),
          estadoEnCiclo:    'activa',
          estadoFinanciero: 'al_corriente',
        },
      });
      
      // Inscribir automáticamente a las materias del grupo
      const grupoObj = await tx.grupo.findUnique({
        where: { grupoId: Number(grupoId) },
        include: { gruposMaterias: { where: { eliminadoEn: null } } }
      });
      if (grupoObj && grupoObj.gruposMaterias) {
        for (const gm of grupoObj.gruposMaterias) {
          await tx.inscripcionMateria.upsert({
            where: { alumnoId_grupoMateriaId: { alumnoId: alumno.alumnoId, grupoMateriaId: gm.grupoMateriaId } },
            create: { alumnoId: alumno.alumnoId, grupoMateriaId: gm.grupoMateriaId },
            update: {}
          });
        }
      }
    }
  }

  // Re-query con datos completos
  const finalAlumno = await tx.alumno.findFirst({ where: { alumnoId: alumno.alumnoId }, include: INCLUDE_COMPLETO }); return finalAlumno ? mapAlumno(finalAlumno) : null;
});
}

/**
 * Actualiza un alumno por ID.
 */
async function update(id, datos, auditCtx = {}) { return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
  const { padres, nombre, nivel, grupoId, ...rest } = datos;

  let nivelId;
  if (nivel) {
    const nivelReg = await tx.nivelEducativo.findFirst({
      where: { codigo: nivel.toUpperCase() },
    });
    nivelId = nivelReg?.nivelId;
  }

  // Update alumno table
  await tx.alumno.update({
    where: { alumnoId: Number(id) },
    data: {
      ...(nombre ? { nombreCompleto: nombre } : {}),
      ...(nivelId ? { nivelId } : {}),
      ...(rest.curp !== undefined ? { curp: rest.curp } : {}),
      ...(rest.estado ? { 
        estado: rest.estado,
        ...(rest.estado === 'Baja Definitiva' ? { eliminadoEn: new Date() } : (rest.estado === 'Activo' ? { eliminadoEn: null } : {}))
      } : {}),
      ...(rest.fechaNacimiento !== undefined ? { fechaNacimiento: rest.fechaNacimiento ? new Date(rest.fechaNacimiento) : null } : {}),
      ...(rest.diaLimitePago !== undefined ? { diaLimitePago: rest.diaLimitePago } : {}),
      ...(rest.observaciones !== undefined ? { observaciones: rest.observaciones } : {}),
    },
  });

  // Handle inscripcion_ciclo if grupoId was sent
  if (grupoId !== undefined && grupoId !== null) {
    const cicloActivo = await tx.cicloEscolar.findFirst({
      where: { activo: true },
    });
    if (cicloActivo) {
      const planDefault = await tx.planPago.findFirst({
        where: { cicloId: cicloActivo.cicloId, activo: true }
      });
      await tx.inscripcionCiclo.upsert({
        where: { alumnoId_cicloId: { alumnoId: Number(id), cicloId: cicloActivo.cicloId } },
        update: { 
          grupoId: Number(grupoId),
          ...(datos.planPagoId ? { planPagoId: Number(datos.planPagoId) } : {})
        },
        create: {
          alumnoId: Number(id),
          cicloId: cicloActivo.cicloId,
          grupoId: Number(grupoId),
          planPagoId: datos.planPagoId ? Number(datos.planPagoId) : (planDefault?.planPagoId ?? null),
          estadoFinanciero: 'al_corriente',
          mesesAdeudo: 0,
        }
      });
      
      // Inscribir automáticamente a las materias del nuevo grupo
      const grupoObj = await tx.grupo.findUnique({
        where: { grupoId: Number(grupoId) },
        include: { gruposMaterias: { where: { eliminadoEn: null } } }
      });
      if (grupoObj && grupoObj.gruposMaterias) {
        for (const gm of grupoObj.gruposMaterias) {
          await tx.inscripcionMateria.upsert({
            where: { alumnoId_grupoMateriaId: { alumnoId: Number(id), grupoMateriaId: gm.grupoMateriaId } },
            create: { alumnoId: Number(id), grupoMateriaId: gm.grupoMateriaId },
            update: {}
          });
        }
      }
    }
  }

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
