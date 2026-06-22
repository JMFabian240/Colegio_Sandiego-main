/**
 * SAE — Grupos Service
 */

'use strict';

const gruposRepository = require('../../repositories/grupos/grupos.repository');

async function listar(filtros, usuario = null) {
  return gruposRepository.findAll(filtros, usuario);
}

async function obtenerPorId(id) {
  const grupo = await gruposRepository.findById(id);
  if (!grupo) {
    throw Object.assign(new Error('Grupo no encontrado.'), { statusCode: 404 });
  }
  return grupo;
}

async function crear(datos, auditCtx = {}) {
  return gruposRepository.create(datos, auditCtx);
}

async function actualizar(id, datos, auditCtx = {}) {
  await obtenerPorId(id);
  return gruposRepository.update(id, datos, auditCtx);
}

async function eliminar(id, auditCtx = {}) {
  await obtenerPorId(id);
  return gruposRepository.softDelete(id, auditCtx);
}

async function obtenerAlumnosMateria(grupoMateriaId) {
  return gruposRepository.obtenerAlumnosMateria(grupoMateriaId);
}

async function actualizarAlumnosMateria(grupoMateriaId, alumnosIds, auditCtx = {}) {
  return gruposRepository.actualizarAlumnosMateria(grupoMateriaId, alumnosIds, auditCtx);
}

module.exports = { listar, obtenerPorId, crear, actualizar, eliminar, obtenerAlumnosMateria, actualizarAlumnosMateria };
