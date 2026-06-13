/**
 * SAE — Usuarios Service
 */

'use strict';

const usuariosRepository = require('../../repositories/usuarios/usuarios.repository');
const { hashPassword }   = require('../../utils/hash.utils');

async function listar(filtros) {
  return usuariosRepository.findAll(filtros);
}

async function obtenerPorId(id) {
  const usuario = await usuariosRepository.findById(id);
  if (!usuario) {
    throw Object.assign(new Error('Usuario no encontrado.'), { statusCode: 404 });
  }
  return usuario;
}

async function crear(datos, auditCtx = {}) {
  // Verificar username único
  const existente = await usuariosRepository.findByUsername(datos.username);
  if (existente) {
    throw Object.assign(
      new Error(`El nombre de usuario "${datos.username}" ya está en uso.`),
      { statusCode: 409 }
    );
  }

  const passwordHash = await hashPassword(datos.password);

  return usuariosRepository.create({
    nombre:   datos.nombre,
    username: datos.username,
    password: passwordHash,
    rol:      datos.rol || 'MAESTRA',
  }, auditCtx);
}

async function actualizar(id, datos, auditCtx = {}) {
  await obtenerPorId(id);

  const updateData = { ...datos };

  // Si se actualiza la contraseña, hashearla
  if (datos.password) {
    updateData.password = await hashPassword(datos.password);
  }

  return usuariosRepository.update(id, updateData, auditCtx);
}

async function eliminar(id, auditCtx = {}) {
  await obtenerPorId(id);
  return usuariosRepository.softDelete(id, auditCtx);
}

module.exports = { listar, obtenerPorId, crear, actualizar, eliminar };
