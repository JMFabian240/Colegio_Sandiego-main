/**
 * SAE — Grupos Controller
 */

'use strict';

const gruposService        = require('../../services/grupos/grupos.service');
const { success, created } = require('../../utils/response.utils');

async function listar(req, res, next) {
  try {
    const { nivel } = req.query;
    const grupos = await gruposService.listar({ nivel });
    return success(res, grupos, `${grupos.length} grupos encontrados.`);
  } catch (err) { next(err); }
}

async function obtener(req, res, next) {
  try {
    const grupo = await gruposService.obtenerPorId(req.params.id);
    return success(res, grupo);
  } catch (err) { next(err); }
}

async function crear(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const grupo = await gruposService.crear(req.body, auditCtx);
    return created(res, grupo, 'Grupo creado correctamente.');
  } catch (err) { next(err); }
}

async function actualizar(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const grupo = await gruposService.actualizar(req.params.id, req.body, auditCtx);
    return success(res, grupo, 'Grupo actualizado correctamente.');
  } catch (err) { next(err); }
}

module.exports = { listar, obtener, crear, actualizar };
