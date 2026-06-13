/**
 * SAE — Becas Service
 * Reglas de negocio RF-21: Gestor solicita → Admin aprueba.
 */

'use strict';

const becasRepository   = require('../../repositories/becas/becas.repository');
const alumnosRepository = require('../../repositories/alumnos/alumnos.repository');
const { PORCENTAJES_BECA } = require('../../utils/constants');

async function listarBecasActivas() {
  return becasRepository.findBecasActivas();
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

  const porcentaje = PORCENTAJES_BECA[datos.tipo] ?? 0;

  return becasRepository.createSolicitud({
    alumnoId:        Number(datos.alumnoId),
    tipo:            datos.tipo,
    porcentaje,
    motivo:          datos.motivo,
    solicitadoPorId,
  }, auditCtx);
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
  return becasRepository.resolverSolicitud(solicitudId, {
    estado,
    aprobadoPorId,
    observaciones,
  }, auditCtx);
}

async function desactivarBeca(becaId, auditCtx = {}) {
  return becasRepository.deactivateBeca(becaId, auditCtx);
}

module.exports = {
  listarBecasActivas,
  listarSolicitudes,
  solicitarBeca,
  resolverSolicitud,
  desactivarBeca,
};
