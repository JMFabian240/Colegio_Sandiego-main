/**
 * SAE — Calificaciones Controller
 */

'use strict';

const calificacionesService = require('../../services/calificaciones/calificaciones.service');
const { success, created }  = require('../../utils/response.utils');

async function listar(req, res, next) {
  try {
    const { alumnoId, grupoId, grupoMateriaId, periodo } = req.query;
    const calificaciones = await calificacionesService.listar({ alumnoId, grupoId, grupoMateriaId, periodo });
    return success(res, calificaciones, `${calificaciones.length} calificaciones encontradas.`);
  } catch (err) { next(err); }
}

async function listarPorAlumno(req, res, next) {
  try {
    const { periodo } = req.query;
    const calificaciones = await calificacionesService.listarPorAlumno(req.params.alumnoId, periodo);
    return success(res, calificaciones);
  } catch (err) { next(err); }
}

async function guardar(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const calificacion = await calificacionesService.guardar(req.body, req.usuario.id, auditCtx);
    return created(res, calificacion, 'Calificación guardada correctamente.');
  } catch (err) { next(err); }
}

async function guardarLote(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const registros = await calificacionesService.guardarLote(req.body.calificaciones, req.usuario.id, auditCtx);
    return created(res, registros, `${registros.length} calificaciones guardadas.`);
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/calificaciones/promedio/:alumnoId
 * Devuelve el promedio general y por materia de un alumno.
 * Query: ?periodoId=N  o  ?periodo=TRIMESTRE_1
 */
async function promedio(req, res, next) {
  try {
    const { periodoId, periodo } = req.query;
    const resultado = await calificacionesService.calcularPromedio(
      req.params.alumnoId,
      { periodoId, periodo }
    );
    return success(res, resultado, `Promedio calculado: ${resultado.promedioGeneral ?? 'sin calificaciones'}`);
  } catch (err) { next(err); }
}

module.exports = { listar, listarPorAlumno, guardar, guardarLote, promedio };
