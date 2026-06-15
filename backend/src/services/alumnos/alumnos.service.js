/**
 * SAE — Alumnos Service
 * Lógica de negocio: validaciones, reglas y orquestación.
 */

'use strict';

const alumnosRepository = require('../../repositories/alumnos/alumnos.repository');
const calendarioPagoService = require('../pagos/calendarioPago.service');

async function listar(filtros) {
  // page y limit son opcionales — sin ellos la respuesta es el array plano (backward compat)
  return alumnosRepository.findAll(filtros);
}

async function obtenerPorId(id) {
  const alumno = await alumnosRepository.findById(id);
  if (!alumno) {
    throw Object.assign(new Error('Alumno no encontrado.'), { statusCode: 404 });
  }
  return alumno;
}

async function crear(datos, auditCtx) {
  // Verificar matrícula única
  const existente = await alumnosRepository.findByMatricula(datos.matricula);
  if (existente) {
    throw Object.assign(
      new Error(`Ya existe un alumno con la matrícula ${datos.matricula}.`),
      { statusCode: 409 }
    );
  }
  const alumnoCreado = await alumnosRepository.create(datos, auditCtx);
  
  // Hook: Generar Calendario de Pagos Automáticamente si se inscribió (RF-15)
  // La creación inscribe al alumno en el ciclo activo automáticamente si se pasó grupoId.
  if (datos.grupoId) {
    const { PrismaClient } = require('@prisma/client');
    const prisma = new PrismaClient();
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
    const { PrismaClient } = require('@prisma/client');
    const prisma = new PrismaClient();
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

module.exports = { listar, obtenerPorId, crear, actualizar, eliminar };
