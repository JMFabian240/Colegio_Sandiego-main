/**
 * SAE — Grupos Controller
 */

'use strict';

const gruposService        = require('../../services/grupos/grupos.service');
const { success, created } = require('../../utils/response.utils');

async function listar(req, res, next) {
  try {
    const { nivel, cicloId, todos } = req.query;
    const grupos = await gruposService.listar({ nivel, cicloId, todos: todos === 'true' }, req.usuario);
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

async function eliminar(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    await gruposService.eliminar(req.params.id, auditCtx);
    return success(res, null, 'Grupo eliminado correctamente.');
  } catch (err) { next(err); }
}
async function obtenerAlumnosMateria(req, res, next) {
  try {
    const alumnos = await gruposService.obtenerAlumnosMateria(req.params.id);
    return success(res, alumnos);
  } catch (err) { next(err); }
}

async function actualizarAlumnosMateria(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const { alumnosIds } = req.body;
    await gruposService.actualizarAlumnosMateria(req.params.id, alumnosIds, auditCtx);
    return success(res, null, 'Inscripciones actualizadas correctamente.');
  } catch (err) { next(err); }
}

async function promover(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const { destinoGrupoId, alumnosIds } = req.body;
    await gruposService.promover(req.params.id, destinoGrupoId, alumnosIds, auditCtx);
    return success(res, null, 'Alumnos promovidos exitosamente.');
  } catch (err) { next(err); }
}

module.exports = { listar, obtener, crear, actualizar, eliminar, obtenerAlumnosMateria, actualizarAlumnosMateria, promover };
