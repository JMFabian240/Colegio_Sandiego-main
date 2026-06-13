/**
 * SAE — Bitácora Repository (PostgreSQL / Prisma)
 * Consulta la tabla log_auditoria con JOIN al nombre del usuario.
 *
 * Cumple: RF-09 (consultar bitácora), RF-10 (exportar).
 */

'use strict';

const prisma = require('../../config/database');

/**
 * Filtra y pagina registros de log_auditoria.
 *
 * @param {object} opciones
 * @param {string}  [opciones.fechaInicio]  - ISO date string (inclusive)
 * @param {string}  [opciones.fechaFin]     - ISO date string (inclusive, hasta fin de día)
 * @param {number}  [opciones.usuarioId]    - Filtrar por usuario específico
 * @param {number}  [opciones.pagina=1]
 * @param {number}  [opciones.limite=50]
 * @returns {Promise<{ datos: object[], total: number }>}
 */
async function findAll({ fechaInicio, fechaFin, usuarioId, pagina = 1, limite = 50 } = {}) {
  const where = {};

  if (fechaInicio) {
    where.fechaHora = { ...where.fechaHora, gte: new Date(fechaInicio) };
  }
  if (fechaFin) {
    const fin = new Date(fechaFin);
    fin.setHours(23, 59, 59, 999);
    where.fechaHora = { ...where.fechaHora, lte: fin };
  }
  if (usuarioId) {
    where.usuarioId = Number(usuarioId);
  }

  const skip = (Math.max(1, pagina) - 1) * limite;

  const [registros, total] = await Promise.all([
    prisma.logAuditoria.findMany({
      where,
      select: {
        logId:          true,
        accion:         true,
        tablaAfectada:  true,
        registroId:     true,
        valoresAntes:   true,
        valoresDespues: true,
        fechaHora:      true,
        descripcion:    true,
        usuario: {
          select: {
            usuarioId:      true,
            nombreCompleto: true,
            nombreUsuario:  true,
          },
        },
      },
      orderBy: { fechaHora: 'desc' },
      skip,
      take: Number(limite),
    }),
    prisma.logAuditoria.count({ where }),
  ]);

  const datos = registros.map((r) => ({
    id:            Number(r.logId),          // BigInt → Number para JSON
    fechaHora:     r.fechaHora,
    accion:        r.accion,
    tabla:         r.tablaAfectada,
    registroId:    r.registroId,
    descripcion:   r.descripcion,
    usuario:       r.usuario
      ? { id: r.usuario.usuarioId, nombre: r.usuario.nombreCompleto, username: r.usuario.nombreUsuario }
      : { id: null, nombre: '(sistema)', username: null },
  }));

  return { datos, total: Number(total), pagina: Number(pagina), limite: Number(limite) };
}

module.exports = { findAll };
