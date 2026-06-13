'use strict';

const tutoresRepository = require('../../repositories/tutores/tutores.repository');

async function listar(filtros) {
  return tutoresRepository.findAll(filtros);
}

async function obtenerPorId(id) {
  const tutor = await tutoresRepository.findById(id);
  if (!tutor) {
    throw Object.assign(new Error('Tutor no encontrado.'), { statusCode: 404 });
  }
  return tutor;
}

async function crear(datos, auditCtx) {
  if (datos.rfc) {
    const existente = await tutoresRepository.findByRfc(datos.rfc);
    if (existente) {
      throw Object.assign(
        new Error(`Ya existe un tutor registrado con el RFC ${datos.rfc}.`),
        { statusCode: 409 }
      );
    }
  }
  return tutoresRepository.create(datos, auditCtx);
}

async function actualizar(id, datos, auditCtx) {
  await obtenerPorId(id);
  
  if (datos.rfc) {
    const existente = await tutoresRepository.findByRfc(datos.rfc);
    if (existente && existente.tutorId !== Number(id)) {
      throw Object.assign(
        new Error(`El RFC ${datos.rfc} ya está registrado en otro perfil.`),
        { statusCode: 409 }
      );
    }
  }

  return tutoresRepository.update(id, datos, auditCtx);
}

async function eliminar(id, auditCtx) {
  await obtenerPorId(id);
  return tutoresRepository.softDelete(id, auditCtx);
}

async function vincularAlumno(id, alumnoId, opciones, auditCtx) {
  await obtenerPorId(id); // verifica que tutor exista
  // Se verifica alumno en la base de datos dentro del repo
  return tutoresRepository.vincularAlumno(id, alumnoId, opciones, auditCtx);
}

async function desvincularAlumno(id, alumnoId, auditCtx) {
  await obtenerPorId(id);
  return tutoresRepository.desvincularAlumno(id, alumnoId, auditCtx);
}

module.exports = {
  listar,
  obtenerPorId,
  crear,
  actualizar,
  eliminar,
  vincularAlumno,
  desvincularAlumno
};
