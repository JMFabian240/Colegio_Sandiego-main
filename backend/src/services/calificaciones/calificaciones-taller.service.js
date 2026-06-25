const calificacionesTallerRepository = require('../../repositories/calificaciones/calificaciones-taller.repository');
const prisma = require('../../config/database');

async function registrarCalificacion({ alumnoId, numeroTrimestre, cicloId, valorCualitativo, usuarioId }) {
  if (valorCualitativo !== 'A' && valorCualitativo !== 'NA' && valorCualitativo !== '') {
    const err = new Error('Valor cualitativo inválido. Opciones: A, NA');
    err.statusCode = 400;
    throw err;
  }

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

  const existente = await calificacionesTallerRepository.findUnique(alumnoId, periodoId, realCicloId);
  
  if (existente) {
    const err = new Error('Ya existe una calificación de Taller registrada para este alumno, periodo y ciclo escolar.');
    err.statusCode = 409;
    throw err;
  }

  try {
    return await calificacionesTallerRepository.create({
      alumnoId,
      periodoId,
      cicloId: realCicloId,
      valorCualitativo,
      registradaPor: usuarioId
    });
  } catch (err) {
    if (err.message && err.message.includes('Invalid prisma')) {
      const customErr = new Error('Error en la base de datos al registrar la calificación del Taller. Por favor, verifique la configuración.');
      customErr.statusCode = 500;
      throw customErr;
    }
    throw err;
  }
}

async function obtenerPorAlumno(alumnoId) {
  const cicloActivo = await prisma.cicloEscolar.findFirst({ where: { activo: true } });
  if (!cicloActivo) return [];
  
  const calificaciones = await calificacionesTallerRepository.findByAlumno(alumnoId);
  return calificaciones.filter(c => c.cicloId === cicloActivo.cicloId);
}

async function modificarCalificacion(id, { valorCualitativo, motivo, usuarioId }) {
  if (!motivo || motivo.trim() === '') {
    const err = new Error('Debe proporcionar un motivo para modificar una calificación registrada.');
    err.statusCode = 400;
    throw err;
  }

  if (valorCualitativo !== 'A' && valorCualitativo !== 'NA' && valorCualitativo !== '') {
    const err = new Error('Valor cualitativo inválido. Opciones: A, NA');
    err.statusCode = 400;
    throw err;
  }

  return calificacionesTallerRepository.update(id, {
    valorCualitativo,
    modificadaMotivo: motivo,
    registradaPor: usuarioId
  });
}

module.exports = {
  registrarCalificacion,
  obtenerPorAlumno,
  modificarCalificacion
};
