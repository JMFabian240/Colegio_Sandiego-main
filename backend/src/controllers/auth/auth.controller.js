/**
 * SAE — Auth Controller
 * Única responsabilidad: recibir request, delegar a service, enviar response.
 */

'use strict';

const authService  = require('../../services/auth/auth.service');
const jwtUtils     = require('../../utils/jwt.utils');
const prisma       = require('../../config/database');
const { success }  = require('../../utils/response.utils');

/**
 * POST /api/v1/auth/login
 */
async function login(req, res, next) {
  try {
    const { username, password } = req.body;
    const ip        = req.ip || req.connection?.remoteAddress || '0.0.0.0';
    const userAgent = req.headers['user-agent'] || '';
    const resultado = await authService.login(username, password, ip, userAgent);

    return success(res, resultado, 'Inicio de sesión exitoso.');
  } catch (err) {
    next(err);
  }
}

/**
 * POST /api/v1/auth/logout
 * Revoca el token actual insertándolo en token_revocado.
 * El token sigue siendo válido cripto-gráficamente pero el middleware
 * de autenticación lo rechazará en todas las peticiones futuras.
 */
async function logout(req, res, next) {
  try {
    const { jti, exp } = req.usuario;

    if (!jti) {
      // Token antiguo sin jti — solo limpiamos del lado del cliente
      return success(res, null, 'Sesión cerrada correctamente.');
    }

    // expira_en: usar la expiración del token o 24h por defecto
    const expiraEn = exp
      ? new Date(exp * 1000)
      : new Date(Date.now() + 24 * 60 * 60 * 1000);

    await prisma.tokenRevocado.upsert({
      where:  { jti },
      update: {},   // ya revocado, no hacer nada
      create: {
        jti,
        usuarioId: req.usuario.id ?? null,
        expiraEn,
      },
    });

    return success(res, null, 'Sesión cerrada correctamente.');
  } catch (err) {
    next(err);
  }
}

/**
 * GET /api/v1/auth/me
 * Devuelve el perfil del usuario autenticado.
 * Valida que el usuario siga activo en BD (no desactivado ni eliminado tras emitir el token).
 */
async function me(req, res, next) {
  try {
    const usuario = await authService.findUsuarioActivo(req.usuario.id);
    if (!usuario) {
      return res.status(401).json({
        ok: false,
        message: 'Usuario inactivo o eliminado. Inicia sesión de nuevo.',
      });
    }
    return success(res, req.usuario, 'Perfil de usuario.');
  } catch (err) {
    next(err);
  }
}

/**
 * POST /api/v1/auth/refresh
 * Renueva el access token si el token actual es válido o expiró hace < 2 horas.
 *
 * El token puede llegar:
 *   - Válido (aún no expirado) → renovación proactiva antes del vencimiento
 *   - Expirado hace < 2h       → renovación silenciosa (grace window)
 *   - Expirado hace > 2h       → 401, el usuario debe volver a loguearse
 *
 * No requiere middleware `authenticate` porque el token puede estar expirado.
 * La verificación de firma siempre se realiza (ignoreExpiration: true + check manual).
 */
async function refresh(req, res, next) {
  try {
    const authHeader = req.headers['authorization'] || '';
    const token      = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;

    if (!token) {
      return res.status(401).json({ ok: false, message: 'Token no proporcionado.' });
    }

    // Verificar firma y decodificar payload (ignora solo la expiración, no la firma)
    const payload = jwtUtils.verifyIgnoreExpiration(token);
    if (!payload || !payload.id) {
      return res.status(401).json({ ok: false, message: 'Token inválido o firma corrupta.' });
    }

    // Verificar si el token expiró y cuánto tiempo hace
    const ahora       = Math.floor(Date.now() / 1000);
    const expiro      = payload.exp || 0;
    const segundosExp = ahora - expiro;

    // Ventana de gracia: 2 horas (7200s). Fuera de eso → re-login obligatorio.
    const VENTANA_GRACIA_SEG = 7200;
    if (expiro > 0 && segundosExp > VENTANA_GRACIA_SEG) {
      return res.status(401).json({
        ok: false,
        message: 'Sesión expirada. Por favor inicia sesión de nuevo.',
      });
    }

    // Emitir nuevo token con el mismo payload (sin campos de firma JWT: iat/exp/iss)
    // iss debe omitirse del payload porque generateToken lo agrega vía options.issuer.
    // Si payload.iss y options.issuer coexisten, jsonwebtoken v9 lanza error.
    const { iat, exp, iss, ...payloadLimpio } = payload;
    const nuevoToken = jwtUtils.generateToken(payloadLimpio);

    return success(res, { token: nuevoToken }, 'Token renovado correctamente.');
  } catch (err) {
    next(err);
  }
}

/**
 * PATCH /api/v1/usuarios/:id/reset-password
 * El ADMIN restablece la contraseña de un usuario.
 * La nueva contraseña se comunica verbalmente (sistema LAN sin email).
 * El flag debeCambiarPwd=true obliga al usuario a cambiar en el próximo login.
 */
async function resetPassword(req, res, next) {
  try {
    const { id }              = req.params;
    const { nuevaPassword }   = req.body;

    if (!nuevaPassword || nuevaPassword.length < 6) {
      return res.status(400).json({
        ok: false,
        message: 'La nueva contraseña debe tener al menos 6 caracteres.',
      });
    }

    const resultado = await authService.resetPassword(Number(id), nuevaPassword);
    return success(res, resultado, 'Contraseña restablecida. El usuario deberá cambiarla en el próximo inicio de sesión.');
  } catch (err) {
    next(err);
  }
}

module.exports = { login, logout, me, refresh, resetPassword };
