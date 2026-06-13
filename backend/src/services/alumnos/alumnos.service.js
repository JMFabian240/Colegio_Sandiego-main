/**
 * SAE — Alumnos Service
 * Lógica de negocio: validaciones, reglas y orquestación.
 */

'use strict';

const alumnosRepository = require('../../repositories/alumnos/alumnos.repository');

async function listar(filtros) {
  // page y limit son opcionales — sin ellos la respuesta es el array plano (backward compat)
  return alumnosRepository.findAll(filtros);
}

async function obtenerPorId(id) {
  const alumno = await alumnosRepository.findById(id);
  if (!alumno) {
    throw Object.assign(new Error('Alumno no encontrado.'), { statusCode: 404 });
  }
  return alumno;
}

async function crear(datos, auditCtx) {
  // Verificar matrícula única
  const existente = await alumnosRepository.findByMatricula(datos.matricula);
  if (existente) {
    throw Object.assign(
      new Error(`Ya existe un alumno con la matrícula ${datos.matricula}.`),
      { statusCode: 409 }
    );
  }
  return alumnosRepository.create(datos, auditCtx);
}

async function actualizar(id, datos, auditCtx) {
  await obtenerPorId(id); // Lanza 404 si no existe
  return alumnosRepository.update(id, datos, auditCtx);
}

async function eliminar(id, auditCtx) {
  await obtenerPorId(id); // Lanza 404 si no existe
  return alumnosRepository.softDelete(id, auditCtx);
}

module.exports = { listar, obtenerPorId, crear, actualizar, eliminar };
