/**
 * SAE — Permisos Controller (RF-03)
 * Gestión de permisos granulares por módulo para GESTOR y MAESTRA.
 */

'use strict';

const permisosRepository = require('../../repositories/permisos/permisos.repository');
const prisma             = require('../../config/database');
const { success }        = require('../../utils/response.utils');
const { MODULOS_VALIDOS } = require('../../middleware/permisos.middleware');

/**
 * GET /api/v1/permisos/usuarios/:id
 * Lista todos los permisos activos de un usuario.
 */
async function listarPorUsuario(req, res, next) {
  try {
    const permisos = await permisosRepository.findByUsuario(req.params.id);
    return success(res, permisos, `${permisos.length} permisos encontrados.`);
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/permisos/modulos
 * Lista los módulos válidos del sistema (para construir la UI).
 */
async function listarModulos(req, res, next) {
  try {
    return success(res, [...MODULOS_VALIDOS], 'Módulos del sistema.');
  } catch (err) { next(err); }
}

/**
 * PUT /api/v1/permisos/usuarios/:id
 * Reemplaza todos los permisos de un usuario.
 * Body: { permisos: [{ modulo: string, nivel: 'lectura'|'escritura' }] }
 *
 * Guarda protección: no se pueden asignar permisos a un ADMIN.
 */
async function asignar(req, res, next) {
  try {
    const usuarioId = Number(req.params.id);
    const { permisos } = req.body;

    if (!Array.isArray(permisos)) {
      return res.status(400).json({
        ok: false,
        message: 'El campo "permisos" debe ser un arreglo.',
      });
    }

    // Verificar que el usuario destino no sea ADMIN
    const usuario = await prisma.usuario.findFirst({
      where: { usuarioId, activo: true, eliminadoEn: null },
      select: {
        usuarioId: true,
        roles: {
          where: { activo: true, eliminadoEn: null },
          select: { rol: { select: { codigo: true } } },
        },
      },
    });

    if (!usuario) {
      return res.status(404).json({ ok: false, message: 'Usuario no encontrado.' });
    }

    const codigos = usuario.roles.map((r) => r.rol.codigo);
    if (codigos.includes('administrador') || codigos.includes('directora')) {
      return res.status(400).json({
        ok: false,
        message: 'No se pueden configurar permisos para un Administrador. El ADMIN tiene acceso total.',
      });
    }

    // Validar módulos y niveles
    for (const p of permisos) {
      if (!MODULOS_VALIDOS.has(p.modulo)) {
        return res.status(400).json({
          ok: false,
          message: `Módulo inválido: "${p.modulo}".`,
        });
      }
      if (!['lectura', 'escritura'].includes(p.nivel)) {
        return res.status(400).json({
          ok: false,
          message: `Nivel inválido: "${p.nivel}". Usa "lectura" o "escritura".`,
        });
      }
    }

    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    await permisosRepository.reemplazar(usuarioId, permisos, auditCtx);
    const resultado = await permisosRepository.findByUsuario(usuarioId);
    return success(res, resultado, 'Permisos actualizados correctamente.');
  } catch (err) { next(err); }
}

/**
 * DELETE /api/v1/permisos/usuarios/:id/:modulo
 * Revoca el permiso de un módulo específico.
 */
async function revocar(req, res, next) {
  try {
    const { id, modulo } = req.params;
    const auditCtx = { usuarioId: req.usuario?.id, ip: req.ip };
    await permisosRepository.revocar(Number(id), modulo, auditCtx);
    return success(res, null, `Permiso del módulo "${modulo}" revocado.`);
  } catch (err) { next(err); }
}

module.exports = { listarPorUsuario, listarModulos, asignar, revocar };
