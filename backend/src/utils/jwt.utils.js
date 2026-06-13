/**
 * SAE — Utilidades JWT
 * Centraliza la generación y verificación de tokens.
 */

'use strict';

const jwt    = require('jsonwebtoken');
const crypto = require('crypto');
const config = require('../config/env');

/**
 * Genera un token JWT con el payload del usuario.
 * Incluye un `jti` (JWT ID) único para permitir la revocación por logout (RF-06).
 * @param {{ id: number, username: string, nombre: string, rol: string }} payload
 * @returns {string} Token firmado
 */
function generateToken(payload) {
  return jwt.sign(
    { ...payload, jti: crypto.randomUUID() },
    config.jwt.secret,
    { expiresIn: config.jwt.expiresIn, issuer: 'sae-sandiego' }
  );
}

/**
 * Verifica un token JWT.
 * @param {string} token
 * @returns {{ valid: boolean, payload?: object, error?: string }}
 */
function verifyToken(token) {
  try {
    const payload = jwt.verify(token, config.jwt.secret, {
      issuer: 'sae-sandiego',
    });
    return { valid: true, payload };
  } catch (err) {
    return { valid: false, error: err.name };
  }
}

/**
 * Decodifica un token JWT SIN verificar la firma ni la expiración.
 * Útil para el endpoint de refresh: leer el payload de un token expirado.
 * @param {string} token
 * @returns {object|null} Payload decodificado o null si el formato es inválido
 */
function decodeToken(token) {
  try {
    return jwt.decode(token);
  } catch {
    return null;
  }
}

/**
 * Verifica un token JWT IGNORANDO la expiración pero SÍ validando la firma.
 * Usado en el endpoint de refresh para aceptar tokens expirados dentro de la
 * ventana de gracia, pero rechazar tokens con firma falsificada o payload alterado.
 *
 * @param {string} token
 * @returns {object|null} Payload si la firma es válida; null si está manipulado
 */
function verifyIgnoreExpiration(token) {
  try {
    return jwt.verify(token, config.jwt.secret, {
      issuer: 'sae-sandiego',
      ignoreExpiration: true,
    });
  } catch {
    return null;
  }
}

module.exports = { generateToken, verifyToken, decodeToken, verifyIgnoreExpiration };
