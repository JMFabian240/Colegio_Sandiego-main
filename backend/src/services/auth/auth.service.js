/**
 * SAE — Auth Service
 * Lógica de negocio: validación de credenciales, bloqueo por intentos fallidos,
 * generación de JWT.
 *
 * Cambios PostgreSQL:
 *   - usuario.bloqueadoHasta e intentosFallidos en la tabla usuario
 *   - registro de intentos en intento_login vía registrarIntento()
 *   - registro de fallos y bloqueo automático vía registrarFallo()
 *   - limpieza de fallos al login exitoso vía limpiarFallos()
 */

'use strict';

const authRepository = require('../../repositories/auth/auth.repository');
const hashUtils      = require('../../utils/hash.utils');
const jwtUtils       = require('../../utils/jwt.utils');
const { REDIRECT_POR_ROL } = require('../../utils/constants');
const prisma         = require('../../config/database');

/**
 * Lee el máximo de intentos fallidos y minutos de bloqueo desde configuracion_sistema.
 */
async function getLoginConfig() {
  try {
    // @@unique([clave, cicloId]) — buscar configuraciones globales (cicloId null)
    const [cfgIntentos, cfgMinutos] = await Promise.all([
      prisma.configuracionSistema.findFirst({ where: { clave: 'login_max_intentos',    cicloId: null } }),
      prisma.configuracionSistema.findFirst({ where: { clave: 'login_minutos_bloqueo', cicloId: null } }),
    ]);
    return {
      maxIntentos:    cfgIntentos ? Number(cfgIntentos.valor)  : 5,
      minutosBloqueo: cfgMinutos  ? Number(cfgMinutos.valor)   : 30,
    };
  } catch {
    return { maxIntentos: 5, minutosBloqueo: 30 };
  }
}

/**
 * Verifica credenciales y genera JWT.
 * Registra el intento en intento_login para auditoría y bloqueo.
 *
 * @param {string} username
 * @param {string} password
 * @param {string} [ip='0.0.0.0']
 * @param {string} [userAgent='']
 * @returns {{ token: string, usuario: object, redirectTo: string }}
 * @throws {Error} 401 si las credenciales son inválidas
 * @throws {Error} 423 si la cuenta está bloqueada temporalmente
 */
async function login(username, password, ip = '0.0.0.0', userAgent = '') {
  const { maxIntentos, minutosBloqueo } = await getLoginConfig();

  // 1. Buscar usuario (incluye passwordHash mapeado como `password` por backward compat)
  const usuario = await authRepository.findByUsername(username);

  if (!usuario) {
    // Registrar intento fallido (usuario inexistente)
    await authRepository.registrarIntento({
      usuarioId:              null,
      nombreUsuarioIntentado: username,
      exitoso:                false,
      direccionIp:            ip,
      userAgent,
    }).catch(() => {});
    throw Object.assign(new Error('Credenciales incorrectas.'), { statusCode: 401 });
  }

  // 2. Verificar si la cuenta está bloqueada
  if (usuario.bloqueadoHasta && new Date(usuario.bloqueadoHasta) > new Date()) {
    const minutosRestantes = Math.ceil(
      (new Date(usuario.bloqueadoHasta) - Date.now()) / 60000
    );
    throw Object.assign(
      new Error(`Cuenta bloqueada. Intenta en ${minutosRestantes} minuto(s).`),
      { statusCode: 423 }
    );
  }

  // 3. Validar contraseña
  const passwordValida = await hashUtils.comparePassword(password, usuario.password);

  if (!passwordValida) {
    // Registrar fallo e incrementar contador (puede activar bloqueo)
    await authRepository.registrarFallo(usuario.id, maxIntentos, minutosBloqueo).catch(() => {});
    await authRepository.registrarIntento({
      usuarioId:              usuario.id,
      nombreUsuarioIntentado: username,
      exitoso:                false,
      direccionIp:            ip,
      userAgent,
    }).catch(() => {});
    throw Object.assign(new Error('Credenciales incorrectas.'), { statusCode: 401 });
  }

  // 4. Login exitoso: limpiar fallos y registrar éxito
  await authRepository.limpiarFallos(usuario.id).catch(() => {});
  await authRepository.registrarIntento({
    usuarioId:              usuario.id,
    nombreUsuarioIntentado: username,
    exitoso:                true,
    direccionIp:            ip,
    userAgent,
  }).catch(() => {});

  // 5. Generar JWT con payload backward-compatible
  const payload = {
    id:       usuario.id,
    nombre:   usuario.nombre,
    username: usuario.username,
    rol:      usuario.rol,
    permisos: usuario.permisos || {},
  };

  const token = jwtUtils.generateToken(payload);

  // No exponer el hash de la contraseña en la respuesta
  const { password: _omit, bloqueadoHasta: _b, intentosFallidos: _f, ...usuarioSinPassword } = usuario;

  return {
    token,
    usuario:    usuarioSinPassword,
    redirectTo: REDIRECT_POR_ROL[usuario.rol] || '/',
  };
}

/**
 * Restablece la contraseña de un usuario (solo ADMIN).
 * Hashea la nueva contraseña y activa el flag debeCambiarPwd.
 *
 * @param {number} usuarioId
 * @param {string} nuevaPassword - Contraseña en texto plano
 */
async function resetPassword(usuarioId, nuevaPassword) {
  const usuario = await prisma.usuario.findFirst({
    where: { usuarioId, activo: true, eliminadoEn: null },
    select: { usuarioId: true, nombreCompleto: true, nombreUsuario: true },
  });

  if (!usuario) {
    throw Object.assign(new Error('Usuario no encontrado.'), { statusCode: 404 });
  }

  const passwordHash = await hashUtils.hashPassword(nuevaPassword);

  await prisma.usuario.update({
    where: { usuarioId },
    data: {
      passwordHash,
      debeCambiarPwd:  true,
      intentosFallidos: 0,
      bloqueadoHasta:   null,
    },
  });

  return {
    id:       usuario.usuarioId,
    nombre:   usuario.nombreCompleto,
    username: usuario.nombreUsuario,
    debeCambiarPwd: true,
  };
}

/**
 * Verifica si un usuario existe, está activo y no ha sido eliminado.
 * Usado por GET /auth/me para garantizar que el JWT no pertenece a un usuario revocado.
 *
 * @param {number} id - usuarioId del payload JWT
 * @returns {Promise<{ usuarioId: number }|null>} Objeto mínimo si válido, null si no
 */
async function findUsuarioActivo(id) {
  return prisma.usuario.findFirst({
    where: { usuarioId: id, activo: true, eliminadoEn: null },
    select: { usuarioId: true },
  });
}

module.exports = { login, resetPassword, findUsuarioActivo };
