const { withAudit } = require('../../utils/audit.utils');
/**
 * SAE — Permisos Repository
 * CRUD sobre usuario_permiso_modulo.
 *
 * Cumple RF-03: permisos por módulo para GESTOR y MAESTRA.
 * ADMIN siempre tiene acceso total (no se consulta esta tabla).
 */

'use strict';

const prisma = require('../../config/database');

/**
 * Lista todos los permisos activos de un usuario.
 * @param {number} usuarioId
 * @returns {Promise<Array<{ modulo, nivel }>>}
 */
async function findByUsuario(usuarioId) {
  return prisma.usuarioPermisoModulo.findMany({
    where: { usuarioId: Number(usuarioId), activo: true },
    select: { modulo: true, nivel: true },
    orderBy: { modulo: 'asc' },
  });
}

/**
 * Busca el permiso de un usuario para un módulo específico.
 * @param {number} usuarioId
 * @param {string} modulo
 * @returns {Promise<{ modulo, nivel, activo }|null>}
 */
async function findByUsuarioModulo(usuarioId, modulo) {
  return prisma.usuarioPermisoModulo.findFirst({
    where: { usuarioId: Number(usuarioId), modulo, activo: true },
    select: { modulo: true, nivel: true, activo: true },
  });
}

/**
 * Crea o actualiza un permiso de módulo para un usuario.
 * @param {number} usuarioId
 * @param {string} modulo    - 'alumnos' | 'pagos' | 'becas' | ...
 * @param {string} nivel     - 'lectura' | 'escritura'
 */
async function upsert(usuarioId, modulo, nivel, auditCtx = {}) { return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
  return tx.usuarioPermisoModulo.upsert({
    where: { usuarioId_modulo: { usuarioId: Number(usuarioId), modulo } },
    update: { nivel, activo: true, actualizadoEn: new Date() },
    create: { usuarioId: Number(usuarioId), modulo, nivel, activo: true },
  });
});
}

/**
 * Desactiva el permiso de un módulo para un usuario (soft delete).
 * @param {number} usuarioId
 * @param {string} modulo
 */
async function revocar(usuarioId, modulo, auditCtx = {}) { return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
  return tx.usuarioPermisoModulo.updateMany({
    where: { usuarioId: Number(usuarioId), modulo },
    data:  { activo: false },
  });
});
}

/**
 * Reemplaza TODOS los permisos de un usuario de una sola vez.
 * Útil para guardar la pantalla de permisos completa.
 * @param {number} usuarioId
 * @param {Array<{ modulo, nivel }>} permisos
 */
async function reemplazar(usuarioId, permisos, auditCtx = {}) {
  const { withAudit } = require('../../utils/audit.utils');
  return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {
    // Desactivar todos los permisos actuales
    await tx.usuarioPermisoModulo.updateMany({
      where: { usuarioId: Number(usuarioId) },
      data:  { activo: false },
    });
    // Insertar / reactivar los nuevos
    for (const { modulo, nivel } of permisos) {
      await tx.usuarioPermisoModulo.upsert({
        where: { usuarioId_modulo: { usuarioId: Number(usuarioId), modulo } },
        update: { nivel, activo: true, actualizadoEn: new Date() },
        create: { usuarioId: Number(usuarioId), modulo, nivel, activo: true },
      });
    }
  });
}

module.exports = { findByUsuario, findByUsuarioModulo, upsert, revocar, reemplazar };
