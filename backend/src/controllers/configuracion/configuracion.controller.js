'use strict';

const prisma = require('../../config/database');

/**
 * GET /api/v1/configuracion
 * Lista todas las configuraciones del sistema (globales o del ciclo activo).
 */
async function listar(req, res, next) {
  try {
    const configs = await prisma.configuracionSistema.findMany({
      where: { cicloId: null },
      orderBy: { clave: 'asc' },
    });
    res.json({ ok: true, data: configs });
  } catch (err) { next(err); }
}

/**
 * PUT /api/v1/configuracion
 * Actualiza múltiples claves de configuración de una sola vez.
 * Body: { configs: [{ clave: 'x', valor: 'y' }, ...] }
 */
async function actualizar(req, res, next) {
  try {
    const { configs } = req.body;
    if (!Array.isArray(configs) || configs.length === 0) {
      return res.status(400).json({ ok: false, message: 'Se requiere un array de configuraciones.' });
    }

    const resultados = [];
    for (const { clave, valor, descripcion } of configs) {
      const updated = await prisma.configuracionSistema.upsert({
        where: { clave_cicloId: { clave, cicloId: null } },
        update: { valor: String(valor), actualizadoPor: req.usuario?.id ?? null },
        create: { clave, valor: String(valor), descripcion: descripcion || null, tipoDato: 'string' },
      });
      resultados.push(updated);
    }

    res.json({ ok: true, data: resultados, message: 'Configuración actualizada.' });
  } catch (err) { next(err); }
}

module.exports = { listar, actualizar };
