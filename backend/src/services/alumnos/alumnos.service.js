/**
 * SAE — Alumnos Service
 * Lógica de negocio: validaciones, reglas y orquestación.
 */

'use strict';

const alumnosRepository = require('../../repositories/alumnos/alumnos.repository');
const calendarioPagoService = require('../pagos/calendarioPago.service');
const prisma = require('../../config/database');
const AppError = require('../../utils/AppError');

async function listar(filtros, usuario) {
  // page y limit son opcionales — sin ellos la respuesta es el array plano (backward compat)
  return alumnosRepository.findAll(filtros, usuario);
}

async function obtenerPorId(id) {
  const alumno = await alumnosRepository.findById(id);
  if (!alumno) {
    throw new AppError('Alumno no encontrado.', 404);
  }
  return alumno;
}

async function crear(datos, auditCtx) {
  if (datos.curp === '') datos.curp = null;

  // Verificar matrícula única
  const existente = await alumnosRepository.findByMatricula(datos.matricula);
  if (existente) {
    throw new AppError(`Ya existe un alumno con la matrícula ${datos.matricula}.`, 409);
  }
  const alumnoCreado = await alumnosRepository.create(datos, auditCtx);
  
  // Hook: Generar Calendario de Pagos Automáticamente si se inscribió (RF-15)
  // La creación inscribe al alumno en el ciclo activo automáticamente si se pasó grupoId.
  if (datos.grupoId) {
    const inscripcion = await prisma.inscripcionCiclo.findFirst({
      where: { alumnoId: alumnoCreado.id },
      orderBy: { creadoEn: 'desc' }
    });
    if (inscripcion) {
      try {
        await calendarioPagoService.generarCalendario(inscripcion.inscripcionId);
      } catch (e) {
        console.error(`Error al generar calendario automático para alumno ${alumnoCreado.id}:`, e.message);
      }
    }
  }

  return alumnoCreado;
}

async function actualizar(id, datos, auditCtx) {
  if (datos.curp === '') datos.curp = null;
  const alumnoPrevio = await obtenerPorId(id); // Lanza 404 si no existe
  
  const alumnoActualizado = await alumnosRepository.update(id, datos, auditCtx);

  // Hook de Baja / Reactivación Financiera (RF-16)
  if (datos.estado && alumnoPrevio.estado !== datos.estado) {
    const estadoNuevo = datos.estado.toLowerCase();
    const estadoPrevio = alumnoPrevio.estado.toLowerCase();
    
    const esBajaNueva = estadoNuevo === 'baja' || estadoNuevo === 'baja temporal' || estadoNuevo === 'baja definitiva';
    const eraBaja = estadoPrevio === 'baja' || estadoPrevio === 'baja temporal' || estadoPrevio === 'baja definitiva';
    
    if (esBajaNueva && !eraBaja) {
      await calendarioPagoService.gestionarBajaTemporal(id, null, true);
    } else if (estadoNuevo === 'activo' && eraBaja) {
      await calendarioPagoService.gestionarBajaTemporal(id, null, false);
    }
    
    // Si es baja definitiva explícita
    if (estadoNuevo === 'baja definitiva' && estadoPrevio === 'baja temporal') {
      // El calendario ya está suspendido, solo se formaliza el estado.
      // (Aquí se podría agregar lógica extra si fuera necesario, como generar un certificado de baja).
    }
  }

  // Hook: Generar Calendario de Pagos si se le asignó un grupo y no tiene pagos
  if (datos.grupoId !== undefined) {
    const inscripcion = await prisma.inscripcionCiclo.findFirst({
      where: { alumnoId: Number(id) },
      orderBy: { creadoEn: 'desc' }
    });
    if (inscripcion) {
      const pagosGenerados = await prisma.calendarioPago.count({
        where: { alumnoId: inscripcion.alumnoId, cicloId: inscripcion.cicloId }
      });
      if (pagosGenerados === 0 || datos.planPagoId) {
        try {
          await calendarioPagoService.generarCalendario(inscripcion.inscripcionId);
        } catch (e) {
          console.error(`Error al generar calendario automático para alumno ${id}:`, e.message);
        }
      }
    }
  }

  return alumnoActualizado;
}

async function eliminar(id, auditCtx) {
  await obtenerPorId(id); // Lanza 404 si no existe
  return alumnosRepository.softDelete(id, auditCtx);
}

async function obtenerHistorialAcademico(id) {
  const alumno = await alumnosRepository.findById(id);

  if (!alumno) {
    throw new AppError('Alumno no encontrado.', 404);
  }

  const curricularesRaw = await prisma.calificacion.findMany({
    where: { alumnoId: Number(id) },
    include: {
      periodo: true,
      grupoMateria: {
        include: {
          materia: true,
          grupo: {
            include: {
              ciclo: true
            }
          }
        }
      }
    }
  });

  const extraRaw = await prisma.calificacionExtracurricular.findMany({
    where: { alumnoId: Number(id) },
    include: {
      periodo: true,
      ciclo: true
    }
  });

  const tallerRaw = await prisma.calificacionTaller.findMany({
    where: { alumnoId: Number(id) },
    include: {
      periodo: true,
      ciclo: true
    }
  });

  const historialPorCiclo = {};

  curricularesRaw.forEach(c => {
    if (!c.grupoMateria || !c.grupoMateria.grupo || !c.grupoMateria.grupo.ciclo) return;
    const ciclo = c.grupoMateria.grupo.ciclo;
    const cicloId = ciclo.cicloId;

    if (!historialPorCiclo[cicloId]) {
      historialPorCiclo[cicloId] = {
        ciclo: ciclo,
        curriculares: [],
        extracurriculares: [],
        talleres: []
      };
    }

    historialPorCiclo[cicloId].curriculares.push({
      calificacionId: c.calificacionId,
      materia: c.grupoMateria.materia.nombre,
      creditos: c.grupoMateria.materia.creditos || 0,
      tipoEvaluacion: c.tipoEvaluacion,
      valorNumerico: c.valorNumerico,
      valorCualitativo: c.valorCualitativo,
      periodo: c.periodo.nombre,
      fechaAprobacion: c.actualizadoEn,
      grupo: c.grupoMateria.grupo.nombre
    });
  });

  extraRaw.forEach(e => {
    if (!e.ciclo) return;
    const cicloId = e.ciclo.cicloId;

    if (!historialPorCiclo[cicloId]) {
      historialPorCiclo[cicloId] = {
        ciclo: e.ciclo,
        curriculares: [],
        extracurriculares: [],
        talleres: []
      };
    }

    historialPorCiclo[cicloId].extracurriculares.push({
      club: e.club,
      valorNumerico: e.valorNumerico,
      periodo: e.periodo.nombre,
      fechaAprobacion: e.actualizadoEn
    });
  });

  tallerRaw.forEach(t => {
    if (!t.ciclo) return;
    const cicloId = t.ciclo.cicloId;

    if (!historialPorCiclo[cicloId]) {
      historialPorCiclo[cicloId] = {
        ciclo: t.ciclo,
        curriculares: [],
        extracurriculares: [],
        talleres: []
      };
    }

    historialPorCiclo[cicloId].talleres.push({
      taller: 'Taller',
      valorCualitativo: t.valorCualitativo,
      periodo: t.periodo.nombre,
      fechaAprobacion: t.actualizadoEn
    });
  });

  const historialArray = Object.values(historialPorCiclo).sort((a, b) => {
    return new Date(b.ciclo.fechaInicio) - new Date(a.ciclo.fechaInicio);
  });

  return {
    alumno: {
      id: alumno.id,
      nombre: alumno.nombre,
      matricula: alumno.matricula,
      nivel: alumno.nivel,
      grado: alumno.grupo?.grado,
      grupoActual: alumno.grupo?.nombre
    },
    historial: historialArray
  };
}

module.exports = { listar, obtenerPorId, crear, actualizar, eliminar, obtenerHistorialAcademico };
