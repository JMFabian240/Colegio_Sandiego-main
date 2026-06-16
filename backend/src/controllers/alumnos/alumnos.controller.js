/**
 * SAE — Alumnos Controller
 */

'use strict';

const alumnosService          = require('../../services/alumnos/alumnos.service');
const { success, created }    = require('../../utils/response.utils');

async function listar(req, res, next) {
  try {
    const { q, grupoId, nivel, grado, seccion, estado, page, limit } = req.query;
    const resultado = await alumnosService.listar({ q, grupoId, nivel, grado, seccion, estado, page, limit }, req.usuario);

    // Con paginación: resultado = { data, pagination }
    if (resultado && resultado.pagination) {
      const { data, pagination } = resultado;
      return res.status(200).json({
        ok: true,
        message: `${pagination.total} alumnos encontrados (página ${pagination.page}/${pagination.pages}).`,
        data,
        pagination,
      });
    }

    // Sin paginación: resultado = array (backward compat)
    return success(res, resultado, `${resultado.length} alumnos encontrados.`);
  } catch (err) { next(err); }
}

async function obtener(req, res, next) {
  try {
    const alumno = await alumnosService.obtenerPorId(req.params.id);
    return success(res, alumno);
  } catch (err) { next(err); }
}

async function crear(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const alumno = await alumnosService.crear(req.body, auditCtx);
    return created(res, alumno, 'Alumno registrado correctamente.');
  } catch (err) { next(err); }
}

async function actualizar(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const alumno = await alumnosService.actualizar(req.params.id, req.body, auditCtx);
    return success(res, alumno, 'Datos del alumno actualizados.');
  } catch (err) { next(err); }
}

async function eliminar(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    await alumnosService.eliminar(req.params.id, auditCtx);
    return success(res, null, 'Alumno desactivado correctamente.');
  } catch (err) { next(err); }
}

async function obtenerHistorialAcademico(req, res, next) {
  try {
    const historial = await alumnosService.obtenerHistorialAcademico(req.params.id);
    return success(res, historial);
  } catch (err) {
    require('fs').appendFileSync('debug.log', new Date().toISOString() + ' ERROR: ' + err.stack + '\n');
    next(err); 
  }
}

module.exports = { listar, obtener, crear, actualizar, eliminar, obtenerHistorialAcademico };
