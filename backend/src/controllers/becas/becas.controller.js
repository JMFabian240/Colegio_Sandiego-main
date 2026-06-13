/**
 * SAE — Becas Controller
 * RF-21: Gestor solicita, Admin aprueba.
 */

'use strict';

const becasService         = require('../../services/becas/becas.service');
const { success, created } = require('../../utils/response.utils');

async function listarBecas(req, res, next) {
  try {
    const becas = await becasService.listarBecasActivas();
    return success(res, becas, `${becas.length} becas activas.`);
  } catch (err) { next(err); }
}

async function listarSolicitudes(req, res, next) {
  try {
    const { estado } = req.query;
    // El gestor solo ve sus propias solicitudes; el admin ve todas
    const solicitadoPorId = req.usuario.rol === 'GESTOR' ? req.usuario.id : undefined;
    const solicitudes = await becasService.listarSolicitudes({ estado, solicitadoPorId });
    return success(res, solicitudes);
  } catch (err) { next(err); }
}

async function solicitarBeca(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const solicitud = await becasService.solicitarBeca(req.body, req.usuario.id, auditCtx);
    return created(res, solicitud, 'Solicitud de beca enviada al Administrador.');
  } catch (err) { next(err); }
}

async function resolverSolicitud(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const resultado = await becasService.resolverSolicitud(
      req.params.id,
      req.body,
      req.usuario.id,
      auditCtx
    );
    return success(res, resultado, `Solicitud ${req.body.estado.toLowerCase()} correctamente.`);
  } catch (err) { next(err); }
}

async function desactivarBeca(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    await becasService.desactivarBeca(req.params.id, auditCtx);
    return success(res, null, 'Beca desactivada correctamente.');
  } catch (err) { next(err); }
}

module.exports = { listarBecas, listarSolicitudes, solicitarBeca, resolverSolicitud, desactivarBeca };
