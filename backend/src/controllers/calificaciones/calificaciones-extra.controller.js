const calificacionesExtraService = require('../../services/calificaciones/calificaciones-extra.service');

/**
 * Registra una nueva calificación extracurricular
 */
const registrarCalificacion = async (req, res, next) => {
  try {
    const { alumnoId, club, numeroTrimestre, cicloId, valorNumerico } = req.body;
    const usuarioId = req.usuario?.id;

    const nuevaCalif = await calificacionesExtraService.registrarCalificacion({
      alumnoId,
      club,
      numeroTrimestre,
      cicloId,
      valorNumerico,
      usuarioId
    });



    res.status(201).json({
      success: true,
      data: nuevaCalif,
      message: 'Calificación de club extracurricular registrada correctamente.'
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Obtiene las calificaciones extracurriculares de un alumno
 */
const obtenerPorAlumno = async (req, res, next) => {
  try {
    const { alumnoId } = req.params;
    const calificaciones = await calificacionesExtraService.obtenerPorAlumno(parseInt(alumnoId, 10));

    res.status(200).json({
      success: true,
      data: calificaciones
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Modifica una calificación extracurricular existente
 */
const modificarCalificacion = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { valorNumerico, motivo } = req.body;
    const usuarioId = req.usuario?.id;

    const califModificada = await calificacionesExtraService.modificarCalificacion(parseInt(id, 10), {
      valorNumerico,
      motivo,
      usuarioId
    });

    res.status(200).json({
      success: true,
      data: califModificada,
      message: 'Calificación extracurricular modificada correctamente.'
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  registrarCalificacion,
  obtenerPorAlumno,
  modificarCalificacion
};
