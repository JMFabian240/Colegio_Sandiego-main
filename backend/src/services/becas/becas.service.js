/**
 * SAE — Becas Service
 * Reglas de negocio RF-21: Gestor solicita → Admin aprueba.
 */

'use strict';

const becasRepository   = require('../../repositories/becas/becas.repository');
const alumnosRepository = require('../../repositories/alumnos/alumnos.repository');
const calendarioPagoService = require('../pagos/calendarioPago.service');
const { PORCENTAJES_BECA } = require('../../utils/constants');

async function listarBecasActivas() {
  return becasRepository.findBecasActivas();
}

// ── CATÁLOGO DE BECAS ─────────────────────────────────────────

async function listarCatalogoBecas() {
  return becasRepository.getCatalogoBecas();
}

async function crearCatalogoBeca(datos, auditCtx = {}) {
  try {
    return await becasRepository.createCatalogoBeca(datos, auditCtx);
  } catch (err) {
    if (err.code === 'P2002' && err.meta?.target?.includes('nombre_beca')) {
      throw Object.assign(new Error('Ya existe un tipo de beca con ese nombre. Ingrese un nombre diferente.'), { statusCode: 409 });
    }
    throw err;
  }
}

async function actualizarCatalogoBeca(id, datos, auditCtx = {}) {
  try {
    return await becasRepository.updateCatalogoBeca(id, datos, auditCtx);
  } catch (err) {
    if (err.code === 'P2002' && err.meta?.target?.includes('nombre_beca')) {
      throw Object.assign(new Error('Ya existe un tipo de beca con ese nombre. Ingrese uno diferente.'), { statusCode: 409 });
    }
    throw err;
  }
}

async function eliminarCatalogoBeca(id) {
  return becasRepository.deleteCatalogoBeca(id);
}

async function listarSolicitudes(filtros) {
  return becasRepository.findSolicitudes(filtros);
}

/**
 * El GESTOR envía una solicitud de beca — no la aplica directamente (RF-21).
 * @param {{ alumnoId: number, tipo: string, motivo: string }} datos
 * @param {number} solicitadoPorId
 */
async function solicitarBeca(datos, solicitadoPorId, auditCtx = {}) {
  const alumno = await alumnosRepository.findById(datos.alumnoId);
  if (!alumno) {
    throw Object.assign(new Error('Alumno no encontrado.'), { statusCode: 404 });
  }

  return becasRepository.createSolicitud({
    alumnoId:        Number(datos.alumnoId),
    becaId:          Number(datos.becaId),
    tipoSolicitud:   datos.tipoSolicitud || 'asignacion',
    motivo:          datos.motivo,
    solicitadoPorId,
  }, auditCtx);
}

async function asignarBecaDirecta(datos, asignadoPorId, auditCtx = {}) {
  const alumno = await alumnosRepository.findById(datos.alumnoId);
  if (!alumno) throw Object.assign(new Error('Alumno no encontrado.'), { statusCode: 404 });

  const asignacion = await becasRepository.createAsignacionDirecta(datos, asignadoPorId, auditCtx);
  await calendarioPagoService.recalcularPorBeca(asignacion.alumnoId);
  return asignacion;
}

async function retirarBecaDirecta(asignacionId, motivo, retiradoPorId, auditCtx = {}) {
  const asignacion = await becasRepository.retirarAsignacionDirecta(asignacionId, motivo, retiradoPorId, auditCtx);
  if (asignacion && asignacion.alumnoId) {
    await calendarioPagoService.recalcularPorBeca(asignacion.alumnoId);
  }
  return asignacion;
}

/**
 * El ADMIN resuelve una solicitud (aprueba o rechaza) (RF-21).
 * Si aprueba, crea la beca activa.
 * @param {number} solicitudId
 * @param {{ estado: string, observaciones?: string }} payload
 * @param {number} aprobadoPorId
 */
async function resolverSolicitud(solicitudId, { estado, observaciones }, aprobadoPorId, auditCtx = {}) {
  const solicitud = await becasRepository.findSolicitudById(solicitudId);
  if (!solicitud) {
    throw Object.assign(new Error('Solicitud no encontrada.'), { statusCode: 404 });
  }

  if (solicitud.estado !== 'PENDIENTE') {
    throw Object.assign(
      new Error('Esta solicitud ya fue resuelta.'),
      { statusCode: 409 }
    );
  }

  // resolverSolicitud ya crea la asignacion_beca si estado === 'aprobada'
  const resultado = await becasRepository.resolverSolicitud(solicitudId, {
    estado,
    aprobadoPorId,
    observaciones,
  }, auditCtx);

  // Si fue aprobada, recalcular colegiaturas del alumno
  if (estado.toLowerCase() === 'aprobada') {
    if (resultado && resultado.alumnoId) {
      await calendarioPagoService.recalcularPorBeca(resultado.alumnoId);
    }
  }

  return resultado;
}

async function desactivarBeca(becaId, auditCtx = {}) {
  const resultado = await becasRepository.deactivateBeca(becaId, auditCtx);
  if (resultado && resultado.alumnoId) {
    await calendarioPagoService.recalcularPorBeca(resultado.alumnoId);
  }
  return resultado;
}

module.exports = {
  listarBecasActivas,
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
