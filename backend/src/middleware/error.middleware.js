/**
 * SAE — Manejador Global de Errores
 * Centraliza el formato de respuesta para todos los errores no manejados.
 * Debe montarse al FINAL de todos los middlewares en app.js.
 */

'use strict';

const config = require('../config/env');

/**
 * @param {Error} err
 * @param {import('express').Request} req
 * @param {import('express').Response} res
 * @param {import('express').NextFunction} next
 */
function errorHandler(err, req, res, next) {
  // Log del error en consola (siempre)
  console.error(`[ERROR] ${req.method} ${req.originalUrl} —`, err.message);
  require('fs').appendFileSync('error_dump.log', `[ERROR] ${req.method} ${req.originalUrl} — ${err.stack}\n`);
  // Log full stack always for debugging
  require('fs').appendFileSync('debug.log', new Date().toISOString() + ' [' + req.method + ' ' + req.originalUrl + '] ' + err.stack + '\n');

  if (config.env === 'development') {
    console.error(err.stack);
  }

  // Errores de validación de Prisma
  if (err.code === 'P2002') {
    return res.status(409).json({
      ok: false,
      message: 'Ya existe un registro con ese valor único.',
      field: err.meta?.target,
    });
  }

  if (err.code === 'P2025') {
    return res.status(404).json({
      ok: false,
      message: 'Registro no encontrado.',
    });
  }

  // Errores de validación express-validator (pasados como error custom)
  if (err.type === 'VALIDATION_ERROR') {
    const detalles = err.errors && Array.isArray(err.errors) 
      ? err.errors.map(e => e.msg).join('; ')
      : 'Revisa los campos del formulario.';
      
    return res.status(422).json({
      ok: false,
      message: `Datos inválidos: ${detalles}`,
      errors: err.errors,
    });
  }

  // Error genérico
  const statusCode = err.statusCode || err.status || 500;
  const message =
    config.env === 'production' && statusCode === 500
      ? 'Error interno del servidor.'
      : err.message || 'Error interno del servidor.';

  res.status(statusCode).json({
    ok: false,
    message,
  });
}

module.exports = errorHandler;
