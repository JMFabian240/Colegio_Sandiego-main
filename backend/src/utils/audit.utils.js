/**
 * SAE — Utilidad de Auditoría
 *
 * Provee `withAudit(usuarioId, ip, fn)`:
 *   Abre una transacción Prisma, inyecta el contexto de sesión
 *   (sae.usuario_id / sae.direccion_ip) que los triggers de
 *   log_auditoria esperan, luego ejecuta la función de negocio.
 *
 * Cumple RF-08: "registrar el nombre del usuario que ejecutó la acción".
 *
 * Uso:
 *   const resultado = await withAudit(req.usuario.id, req.ip, (tx) => {
 *     return tx.pago.create({ data: { ... } });
 *   });
 */

'use strict';

const prisma = require('../config/database');

/**
 * Ejecuta `fn(tx)` dentro de una transacción Prisma con el contexto
 * de auditoría seteado para que los triggers de PostgreSQL registren
 * correctamente quién realizó la acción.
 *
 * @param {number|null} usuarioId  - ID del usuario autenticado
 * @param {string}      ip         - IP del cliente HTTP (req.ip)
 * @param {Function}    fn         - Función que recibe el cliente de transacción (tx)
 * @returns {Promise<*>}           - Resultado de fn(tx)
 */
async function withAudit(usuarioId, ip, fn) {
  return prisma.$transaction(async (tx) => {
    // SET LOCAL solo afecta la transacción actual (no contamina otras conexiones)
    if (usuarioId != null) {
      await tx.$executeRawUnsafe(
        `SET LOCAL "sae.usuario_id" = '${Number(usuarioId)}'`
      );
    }
    const ipSegura = String(ip || '0.0.0.0').replace(/'/g, '');
    await tx.$executeRawUnsafe(
      `SET LOCAL "sae.direccion_ip" = '${ipSegura}'`
    );

    return fn(tx);
  });
}

module.exports = { withAudit };
