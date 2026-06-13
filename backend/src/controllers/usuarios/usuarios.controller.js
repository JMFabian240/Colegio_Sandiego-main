/**
 * SAE — Usuarios Controller
 */

'use strict';

const usuariosService      = require('../../services/usuarios/usuarios.service');
const { success, created } = require('../../utils/response.utils');

async function listar(req, res, next) {
  try {
    const { rol, incluirInactivos } = req.query;
    const usuarios = await usuariosService.listar({ rol, incluirInactivos: incluirInactivos === 'true' });
    return success(res, usuarios, `${usuarios.length} usuarios encontrados.`);
  } catch (err) { next(err); }
}

async function obtener(req, res, next) {
  try {
    const usuario = await usuariosService.obtenerPorId(req.params.id);
    return success(res, usuario);
  } catch (err) { next(err); }
}

async function crear(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const usuario = await usuariosService.crear(req.body, auditCtx);
    return created(res, usuario, 'Usuario creado correctamente.');
  } catch (err) { next(err); }
}

async function actualizar(req, res, next) {
  try {
    // Impedir que un ADMIN cambie su propio rol.
    if (req.body.rol && req.usuario?.id === Number(req.params.id)) {
      return res.status(403).json({
        ok: false,
        message: 'No puedes modificar el rol de tu propia cuenta.',
      });
    }
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const usuario = await usuariosService.actualizar(req.params.id, req.body, auditCtx);
    return success(res, usuario, 'Usuario actualizado correctamente.');
  } catch (err) { next(err); }
}

async function eliminar(req, res, next) {
  try {
    if (req.usuario?.id === Number(req.params.id)) {
      return res.status(403).json({
        ok: false,
        message: 'Acción denegada: No puede eliminar su propia cuenta activa.',
      });
    }
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    await usuariosService.eliminar(req.params.id, auditCtx);
    return success(res, null, 'Usuario desactivado correctamente.');
  } catch (err) { next(err); }
}

async function reactivar(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const usuario = await usuariosService.reactivar(req.params.id, auditCtx);
    return success(res, usuario, 'Usuario reactivado correctamente.');
  } catch (err) { next(err); }
}

module.exports = { listar, obtener, crear, actualizar, eliminar, reactivar };
