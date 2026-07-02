const calificacionesExtraRepository = require('../../repositories/calificaciones/calificaciones-extra.repository');
const prisma = require('../../config/database');


/**
 * Registra una nueva calificación extracurricular
 */
async function registrarCalificacion({ alumnoId, club, numeroTrimestre, cicloId, valorNumerico, usuarioId }) {

  // Resolver periodo real
  const alumno = await prisma.alumno.findUnique({ where: { alumnoId: parseInt(alumnoId, 10) } });
  if (!alumno) throw new Error('Alumno no encontrado.');

  const cicloActivo = await prisma.cicloEscolar.findFirst({ where: { activo: true } });
  if (!cicloActivo) throw new Error('No hay un ciclo escolar activo configurado en el sistema.');

  // Buscar periodo por nivel del alumno y ciclo activo
  let periodo = await prisma.periodoEvaluacion.findFirst({
    where: {
      nivelId: alumno.nivelId,
      numero: parseInt(numeroTrimestre, 10),
      cicloId: cicloActivo.cicloId
    }
  });

  // Fallback: si no hay periodo para ese nivel, buscar cualquier periodo del ciclo activo con ese numero
  if (!periodo) {
    periodo = await prisma.periodoEvaluacion.findFirst({
      where: {
        numero: parseInt(numeroTrimestre, 10),
        cicloId: cicloActivo.cicloId
      }
    });
  }

  if (!periodo) {
    const err = new Error(`No se encontró el periodo (Trimestre ${numeroTrimestre}) para el ciclo activo. Configure los periodos en Ciclo Escolar.`);
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
  try {
    return await calificacionesExtraRepository.create({
      alumnoId,
      club,
      periodoId,
      cicloId: realCicloId,
      valorNumerico,
      registradaPor: usuarioId
    });
  } catch (err) {
    if (err.message && err.message.includes('Invalid prisma')) {
      const customErr = new Error('Error en la base de datos al registrar la calificación extracurricular. Por favor, verifique la configuración.');
      customErr.statusCode = 500;
      throw customErr;
    }
    throw err;
  }
}

/**
 * Obtiene todas las calificaciones extracurriculares de un alumno
 */
async function obtenerPorAlumno(alumnoId) {
  const cicloActivo = await prisma.cicloEscolar.findFirst({ where: { activo: true } });
  if (!cicloActivo) return { data: [] };
  
  const calificaciones = await calificacionesExtraRepository.findByAlumno(alumnoId);
  return calificaciones.filter(c => c.cicloId === cicloActivo.cicloId);
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
