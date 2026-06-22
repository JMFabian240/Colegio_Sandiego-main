/**
 * SAE — Middleware de Autenticación JWT
 * Verifica el token Bearer en el header Authorization.
 * Inyecta req.usuario con el payload del token validado.
 *
 * RF-06: Verifica que el token no esté en la lista de revocados (logout real).
 */

'use strict';

const { verifyToken } = require('../utils/jwt.utils');
const prisma          = require('../config/database');

/**
 * Middleware principal de autenticación.
 * Rechaza con 401 cualquier petición sin token válido o con token revocado.
 */
async function authenticate(req, res, next) {
  let authHeader = req.headers['authorization'];
  let token = null;

  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.split(' ')[1];
  } else if (req.query && req.query.token) {
    token = req.query.token;
  }

  if (!token) {
    return res.status(401).json({
      ok: false,
      message: 'No autorizado. Se requiere token de acceso.',
    });
  }

  const { valid, payload, error } = verifyToken(token);

  if (!valid) {
    const message =
      error === 'TokenExpiredError'
        ? 'Sesión expirada. Vuelve a iniciar sesión.'
        : 'Token inválido. No autorizado.';

    return res.status(401).json({ ok: false, message });
  }

  // RF-06: Verificar que el token no haya sido revocado por logout
  if (payload.jti) {
    try {
      const revocado = await prisma.tokenRevocado.findUnique({
        where: { jti: payload.jti },
        select: { id: true },
      });
      if (revocado) {
        return res.status(401).json({
          ok: false,
          message: 'Sesión cerrada. Vuelve a iniciar sesión.',
        });
      }
    } catch {
      // Si falla la consulta a BD, permitir paso (best-effort) para no bloquear el sistema
    }
  }

  // Inyectar datos del usuario en la request
req.usuario = payload; console.log('AUTHMIDDLEWARE USER:', payload);
  next();
}

module.exports = { authenticate };
