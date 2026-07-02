'use strict';

/**
 * Clase genérica para errores de aplicación que incluye statusCode.
 * Simplifica el lanzamiento de errores en los servicios.
 */
class AppError extends Error {
  constructor(message, statusCode) {
    super(message);
    this.statusCode = statusCode;
    this.name = this.constructor.name;
    Error.captureStackTrace(this, this.constructor);
  }
}

module.exports = AppError;
