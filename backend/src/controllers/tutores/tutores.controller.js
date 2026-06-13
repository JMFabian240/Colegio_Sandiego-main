'use strict';

const tutoresService       = require('../../services/tutores/tutores.service');
const { success, created } = require('../../utils/response.utils');

async function listar(req, res, next) {
  try {
    const { q, activo, page, limit } = req.query;
    
    const filtros = { q, page, limit };
    if (activo !== undefined) {
      filtros.activo = activo === 'true';
    }

    const resultado = await tutoresService.listar(filtros);

    if (resultado && resultado.pagination) {
      const { data, pagination } = resultado;
      return res.status(200).json({
        ok: true,
        message: `${pagination.total} tutores encontrados (página ${pagination.page}/${pagination.pages}).`,
        data,
        pagination,
      });
    }

    return success(res, resultado, `${resultado.length} tutores encontrados.`);
  } catch (err) { next(err); }
}

async function obtener(req, res, next) {
  try {
    const tutor = await tutoresService.obtenerPorId(req.params.id);
    return success(res, tutor);
  } catch (err) { next(err); }
}

async function crear(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const tutor = await tutoresService.crear(req.body, auditCtx);
    return created(res, tutor, 'Tutor registrado correctamente.');
  } catch (err) { next(err); }
}

async function actualizar(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const tutor = await tutoresService.actualizar(req.params.id, req.body, auditCtx);
    return success(res, tutor, 'Datos del tutor actualizados.');
  } catch (err) { next(err); }
}

async function eliminar(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    await tutoresService.eliminar(req.params.id, auditCtx);
    return success(res, null, 'Tutor desactivado correctamente.');
  } catch (err) { next(err); }
}

async function vincularAlumno(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const { alumnoId, tipoRelacion, esResponsableFinanciero } = req.body;
    const relacion = await tutoresService.vincularAlumno(req.params.id, alumnoId, { tipoRelacion, esResponsableFinanciero }, auditCtx);
    return success(res, relacion, 'Alumno vinculado correctamente.');
  } catch (err) { next(err); }
}

async function desvincularAlumno(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    await tutoresService.desvincularAlumno(req.params.id, req.params.alumnoId, auditCtx);
    return success(res, null, 'Alumno desvinculado correctamente.');
  } catch (err) { next(err); }
}

module.exports = {
  listar,
  obtener,
  crear,
  actualizar,
  eliminar,
  vincularAlumno,
  desvincularAlumno
};
