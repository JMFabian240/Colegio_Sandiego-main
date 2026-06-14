'use strict';

const prisma = require('../../config/database');

/**
 * Obtiene todas las colegiaturas de un alumno en un ciclo específico.
 */
async function findColegiaturasByAlumno(alumnoId, cicloId) {
  return prisma.calendarioPago.findMany({
    where: {
      alumnoId: Number(alumnoId),
      cicloId: Number(cicloId),
      concepto: 'Colegiatura',
      eliminadoEn: null,
    },
    orderBy: { fechaVencimiento: 'asc' },
  });
}

/**
 * Obtiene la inscripción activa de un alumno en un ciclo.
 */
async function findInscripcion(alumnoId, cicloId) {
  return prisma.inscripcionCiclo.findFirst({
    where: {
      alumnoId: Number(alumnoId),
      cicloId: Number(cicloId),
      estadoEnCiclo: 'activa',
      eliminadoEn: null,
    },
    include: {
      planDepago: true,
    },
  });
}

/**
 * Obtiene todas las becas activas de un alumno en un ciclo.
 */
async function findBecasActivas(alumnoId, cicloId) {
  return prisma.asignacionBeca.findMany({
    where: {
      alumnoId: Number(alumnoId),
      cicloId: Number(cicloId),
      estado: 'activa',
      eliminadoEn: null,
    },
    include: {
      beca: true,
    },
  });
}

/**
 * Actualiza el montoOriginal de un registro en CalendarioPago.
 */
async function updateMontoOriginal(calendarioPagoId, nuevoMontoOriginal) {
  return prisma.calendarioPago.update({
    where: { calendarioPagoId: Number(calendarioPagoId) },
    data: {
      montoOriginal: nuevoMontoOriginal,
    },
  });
}

/**
 * Obtiene una inscripción por su ID, incluyendo el ciclo y plan de pago.
 */
async function findInscripcionById(inscripcionId) {
  return prisma.inscripcionCiclo.findUnique({
    where: { inscripcionId: Number(inscripcionId) },
    include: {
      ciclo: true,
      planDepago: true,
    },
  });
}

/**
 * Crea multiples registros en el calendario de pago.
 */
async function createCalendarioBatch(dataArray) {
  return prisma.calendarioPago.createMany({
    data: dataArray,
  });
}

/**
 * Elimina (lógicamente o físicamente) las colegiaturas futuras que no han sido pagadas.
 */
async function deleteColegiaturasFuturas(alumnoId, cicloId, fechaLimite) {
  return prisma.calendarioPago.deleteMany({
    where: {
      alumnoId: Number(alumnoId),
      cicloId: Number(cicloId),
      concepto: 'Colegiatura',
      fechaVencimiento: { gt: fechaLimite },
      montoPagado: { equals: 0 },
    },
  });
}

module.exports = {
  findColegiaturasByAlumno,
  findInscripcion,
  findInscripcionById,
  findBecasActivas,
  updateMontoOriginal,
  createCalendarioBatch,
  deleteColegiaturasFuturas,
};
