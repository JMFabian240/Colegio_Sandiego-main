/**
 * SAE — Auth Repository (PostgreSQL)
 * Consulta usuario por nombre_usuario con sus roles N:M.
 * Devuelve objeto compatible con auth.service.js (backward compat).
 */

'use strict';

const prisma = require('../../config/database');

/**
 * Mapea los roles PostgreSQL (administrador/directora/empleado/docente)
 * al rol de sistema que espera el frontend (ADMIN/GESTOR/MAESTRA).
 * Prioridad: ADMIN > GESTOR > MAESTRA
 *
 * @param {Array<{rol: {codigo: string}}>} roles
 * @returns {'ADMIN'|'GESTOR'|'MAESTRA'}
 */
function derivarRolSistema(roles) {
  const codigos = roles
    .filter(r => r.activo && !r.eliminadoEn)
    .map(r => r.rol.codigo);

  if (codigos.includes('administrador') || codigos.includes('directora')) return 'ADMIN';
  if (codigos.includes('empleado')) return 'GESTOR';
  if (codigos.includes('docente'))  return 'MAESTRA';
  return 'MAESTRA'; // fallback seguro
}

/**
 * Busca un usuario activo por su nombre_usuario.
 * Retorna datos compatibles con el contrato anterior del auth.service:
 *   { id, nombre, username, password, rol, activo }
 *
 * @param {string} username
 * @returns {Promise<object|null>}
 */
async function findByUsername(username) {
  const usuario = await prisma.usuario.findFirst({
    where: {
      nombreUsuario: username,
      activo: true,
      eliminadoEn: null,
    },
    select: {
      usuarioId:     true,
      nombreCompleto:true,
      nombreUsuario: true,
      passwordHash:  true,
      activo:        true,
      bloqueadoHasta:true,
      intentosFallidos: true,
      roles: {
        where: { activo: true, eliminadoEn: null },
        select: {
          activo: true,
          eliminadoEn: true,
          rol: { select: { codigo: true } },
        },
      },
      permisosModulos: {
        where: { activo: true },
        select: { modulo: true, nivel: true }
      }
    },
  });

  if (!usuario) return null;

  // Mapear a formato compatible con el contrato anterior
  return {
    id:       usuario.usuarioId,
    nombre:   usuario.nombreCompleto,
    username: usuario.nombreUsuario,
    password: usuario.passwordHash,          // campo esperado por auth.service
    rol:      derivarRolSistema(usuario.roles),
    activo:   usuario.activo,
    bloqueadoHasta:   usuario.bloqueadoHasta,
    intentosFallidos: usuario.intentosFallidos,
    permisos: usuario.permisosModulos?.reduce((acc, p) => { acc[p.modulo] = p.nivel; return acc; }, {}) || {}
  };
}

/**
 * Registra un intento de login en la tabla intento_login.
 * @param {object} datos
 */
async function registrarIntento({ usuarioId, nombreUsuarioIntentado, exitoso, direccionIp, userAgent }) {
  return prisma.intentoLogin.create({
    data: {
      usuarioId,
      nombreUsuarioIntentado,
      exitoso,
      direccionIp,
      userAgent,
    },
  });
}

/**
 * Incrementa intentos fallidos y bloquea si supera el máximo.
 * @param {number} usuarioId
 * @param {number} maxIntentos
 * @param {number} minutoBloqueo
 */
async function registrarFallo(usuarioId, maxIntentos = 5, minutosBloqueo = 30) {
  const usuario = await prisma.usuario.findUnique({
    where: { usuarioId },
    select: { intentosFallidos: true },
  });

  const nuevosIntentos = (usuario?.intentosFallidos ?? 0) + 1;
  const bloquear = nuevosIntentos >= maxIntentos;

  return prisma.usuario.update({
    where: { usuarioId },
    data: {
      intentosFallidos: nuevosIntentos,
      bloqueadoHasta: bloquear
        ? new Date(Date.now() + minutosBloqueo * 60 * 1000)
        : undefined,
    },
  });
}

/**
 * Limpia los intentos fallidos al login exitoso.
 * @param {number} usuarioId
 */
async function limpiarFallos(usuarioId) {
  return prisma.usuario.update({
    where: { usuarioId },
    data: {
      intentosFallidos: 0,
      bloqueadoHasta:   null,
      ultimoAcceso:     new Date(),
    },
  });
}

module.exports = {
  findByUsername,
  registrarIntento,
  registrarFallo,
  limpiarFallos,
  derivarRolSistema,
};
