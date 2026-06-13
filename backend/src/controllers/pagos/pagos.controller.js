/**
 * SAE — Pagos Controller
 */

'use strict';

const pagosService         = require('../../services/pagos/pagos.service');
const { success, created } = require('../../utils/response.utils');

async function listar(req, res, next) {
  try {
    const { alumnoId, concepto, fechaDesde, fechaHasta, tutorId, page, limit } = req.query;
    const resultado = await pagosService.listar({ alumnoId, concepto, fechaDesde, fechaHasta, tutorId, page, limit });

    // Con paginación: resultado = { data, pagination }
    if (resultado && resultado.pagination) {
      const { data, pagination } = resultado;
      return res.status(200).json({
        ok: true,
        message: `${pagination.total} pagos encontrados (página ${pagination.page}/${pagination.pages}).`,
        data,
        pagination,
      });
    }

    // Sin paginación: resultado = array (backward compat)
    return success(res, resultado, `${resultado.length} pagos encontrados.`);
  } catch (err) { next(err); }
}

async function obtener(req, res, next) {
  try {
    const pago = await pagosService.obtenerPorId(req.params.id);
    return success(res, pago);
  } catch (err) { next(err); }
}

async function registrar(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const pago = await pagosService.registrar(req.body, req.usuario.id, auditCtx);
    return created(res, pago, 'Pago registrado correctamente.');
  } catch (err) { next(err); }
}

async function calendario(req, res, next) {
  try {
    const { alumnoId, cicloId, estadoCobro } = req.query;
    const items = await pagosService.obtenerCalendario({ alumnoId, cicloId, estadoCobro });
    return success(res, items, `${items.length} registros en el calendario.`);
  } catch (err) { next(err); }
}

async function totalPorAlumno(req, res, next) {
  try {
    const result = await pagosService.totalPorAlumno(req.params.alumnoId);
    return success(res, result);
  } catch (err) { next(err); }
}

module.exports = { listar, obtener, registrar, calendario, totalPorAlumno };
