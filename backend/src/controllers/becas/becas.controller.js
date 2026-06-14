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

// ── CATÁLOGO DE BECAS ─────────────────────────────────────────

async function listarCatalogoBecas(req, res, next) {
  try {
    const catalogo = await becasService.listarCatalogoBecas();
    return success(res, catalogo, `${catalogo.length} tipos de beca en el catálogo.`);
  } catch (err) { next(err); }
}

async function crearCatalogoBeca(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const nuevaBeca = await becasService.crearCatalogoBeca(req.body, auditCtx);
    return created(res, nuevaBeca, 'Beca agregada al catálogo exitosamente.');
  } catch (err) { next(err); }
}

async function actualizarCatalogoBeca(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const beca = await becasService.actualizarCatalogoBeca(Number(req.params.id), req.body, auditCtx);
    return success(res, beca, 'Beca actualizada correctamente.');
  } catch (err) { next(err); }
}

async function eliminarCatalogoBeca(req, res, next) {
  try {
    await becasService.eliminarCatalogoBeca(req.params.id);
    return success(res, null, 'Beca eliminada del catálogo correctamente.');
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
    return created(res, solicitud, 'Solicitud de beca enviada para autorización.');
  } catch (err) { next(err); }
}

async function asignarBecaDirecta(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const asignacion = await becasService.asignarBecaDirecta(req.body, req.usuario.id, auditCtx);
    return created(res, asignacion, 'Beca asignada correctamente.');
  } catch (err) { next(err); }
}

async function retirarBecaDirecta(req, res, next) {
  try {
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    const asignacion = await becasService.retirarBecaDirecta(Number(req.params.id), req.body.motivoRetiro, req.usuario.id, auditCtx);
    return success(res, asignacion, 'Beca retirada correctamente. La colegiatura se actualizará al 100% a partir del siguiente periodo de pago.');
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

module.exports = {
  listarBecas,
  listarCatalogoBecas,
  crearCatalogoBeca,
  actualizarCatalogoBeca,
  eliminarCatalogoBeca,
  listarSolicitudes,
  solicitarBeca,
  asignarBecaDirecta,
  retirarBecaDirecta,
  resolverSolicitud,
  desactivarBeca
};
