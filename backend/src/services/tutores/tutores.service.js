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
  // Limpiar campos vacíos para evitar violaciones de clave única (ej. RFC vacío)
  if (datos.rfc === '') datos.rfc = null;
  if (datos.curp === '') datos.curp = null;
  if (datos.correoElectronico === '') datos.correoElectronico = null;
  if (datos.telefono === '') datos.telefono = null;
  if (datos.regimenFiscal === '') datos.regimenFiscal = null;
  if (datos.usoCfdi === '') datos.usoCfdi = null;
  if (datos.codigoPostal === '') datos.codigoPostal = null;
  if (datos.correoFacturacion === '') datos.correoFacturacion = null;

  if (datos.rfc) {
    datos.rfc = datos.rfc.trim().toUpperCase();
    if (datos.rfc.length < 12 || datos.rfc.length > 13) {
      throw Object.assign(
        new Error(`El RFC debe tener exactamente 12 o 13 caracteres.`),
        { statusCode: 400 }
      );
    }
    const existente = await tutoresRepository.findByRfc(datos.rfc);
    if (existente) {
      throw Object.assign(
        new Error(`Ya existe un tutor registrado con el RFC ${datos.rfc}.`),
        { statusCode: 409 }
      );
    }
  }

  if (datos.requiereFactura) {
    if (!datos.rfc || datos.rfc.trim().length === 0) {
      throw Object.assign(new Error('Si el tutor requiere factura, el RFC es obligatorio.'), { statusCode: 400 });
    }
    if (!datos.regimenFiscal || datos.regimenFiscal.trim().length === 0) {
      throw Object.assign(new Error('Si el tutor requiere factura, el Régimen Fiscal es obligatorio.'), { statusCode: 400 });
    }
  }

  return tutoresRepository.create(datos, auditCtx);
}

async function actualizar(id, datos, auditCtx) {
  await obtenerPorId(id);
  
  // Limpiar campos vacíos para evitar violaciones de clave única (ej. RFC vacío)
  if (datos.rfc === '') datos.rfc = null;
  if (datos.curp === '') datos.curp = null;
  if (datos.correoElectronico === '') datos.correoElectronico = null;
  if (datos.telefono === '') datos.telefono = null;
  if (datos.regimenFiscal === '') datos.regimenFiscal = null;
  if (datos.usoCfdi === '') datos.usoCfdi = null;
  if (datos.codigoPostal === '') datos.codigoPostal = null;
  if (datos.correoFacturacion === '') datos.correoFacturacion = null;

  if (datos.rfc) {
    datos.rfc = datos.rfc.trim().toUpperCase();
    if (datos.rfc.length < 12 || datos.rfc.length > 13) {
      throw Object.assign(
        new Error(`El RFC debe tener exactamente 12 o 13 caracteres.`),
        { statusCode: 400 }
      );
    }
    const existente = await tutoresRepository.findByRfc(datos.rfc);
    if (existente && existente.tutorId !== Number(id)) {
      throw Object.assign(
        new Error(`El RFC ${datos.rfc} ya está registrado en otro perfil.`),
        { statusCode: 409 }
      );
    }
  }

  if (datos.requiereFactura) {
    if (!datos.rfc || datos.rfc.trim().length === 0) {
      throw Object.assign(new Error('Si el tutor requiere factura, el RFC es obligatorio.'), { statusCode: 400 });
    }
    if (!datos.regimenFiscal || datos.regimenFiscal.trim().length === 0) {
      throw Object.assign(new Error('Si el tutor requiere factura, el Régimen Fiscal es obligatorio.'), { statusCode: 400 });
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
