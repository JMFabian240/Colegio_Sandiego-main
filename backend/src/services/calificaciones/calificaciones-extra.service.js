const calificacionesExtraRepository = require('../../repositories/calificaciones/calificaciones-extra.repository');
const prisma = require('../../config/database');


const CLUBES_VALIDOS = ['inglés', 'computación', 'danza'];

/**
 * Registra una nueva calificación extracurricular
 */
async function registrarCalificacion({ alumnoId, club, numeroTrimestre, cicloId, valorNumerico, usuarioId }) {
  if (!CLUBES_VALIDOS.includes(club.toLowerCase())) {
    const err = new Error('Club extracurricular inválido. Opciones: ' + CLUBES_VALIDOS.join(', '));
    err.statusCode = 400;
    throw err;
  }

  // Resolver periodo real
  const alumno = await prisma.alumno.findUnique({ where: { alumnoId: parseInt(alumnoId, 10) } });
  if (!alumno) throw new Error('Alumno no encontrado.');

  const periodo = await prisma.periodoEvaluacion.findFirst({
    where: {
      nivelId: alumno.nivelId,
      numero: parseInt(numeroTrimestre, 10)
    },
    orderBy: { ciclo: { fechaInicio: 'desc' } }
  });

  if (!periodo) {
    const err = new Error(`No se encontró el periodo (Trimestre ${numeroTrimestre}) para el nivel de este alumno.`);
    err.statusCode = 404;
    throw err;
  }

  const periodoId = periodo.periodoId;
  const realCicloId = periodo.cicloId;

  // Verificar si ya existe
  const existente = await calificacionesExtraRepository.findUnique(alumnoId, club, periodoId, realCicloId);
  
  if (existente) {
    const err = new Error('Ya existe una calificación registrada para este alumno, club, periodo y ciclo escolar.');
    err.statusCode = 409;
    throw err;
  }

  // Crear registro
  return calificacionesExtraRepository.create({
    alumnoId,
    club,
    periodoId,
    cicloId: realCicloId,
    valorNumerico,
    registradaPor: usuarioId
  });
}

/**
 * Obtiene todas las calificaciones extracurriculares de un alumno
 */
async function obtenerPorAlumno(alumnoId) {
  return calificacionesExtraRepository.findByAlumno(alumnoId);
}

/**
 * Modifica una calificación extracurricular existente
 */
async function modificarCalificacion(id, { valorNumerico, motivo, usuarioId }) {
  if (!motivo || motivo.trim() === '') {
    const err = new Error('Debe proporcionar un motivo para modificar una calificación registrada.');
    err.statusCode = 400;
    throw err;
  }

  return calificacionesExtraRepository.update(id, {
    valorNumerico,
    modificadaMotivo: motivo,
    registradaPor: usuarioId // Opcional: registrar quién hizo la última modificación
  });
}

module.exports = {
  registrarCalificacion,
  obtenerPorAlumno,
  modificarCalificacion
};
