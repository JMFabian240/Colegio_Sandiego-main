/**
 * SAE — Usuarios Repository (PostgreSQL)
 * Mantiene compatibilidad de respuesta con el frontend existente.
 *
 * Cambios:
 *   - username → nombre_usuario
 *   - nombre   → nombre_completo
 *   - rol (string) → N:M via usuario_rol
 *   - activo=false → eliminado_en: timestamp (soft delete)
 */

'use strict';

const prisma = require('../../config/database');
const { derivarRolSistema } = require('../auth/auth.repository');
const { withAudit } = require('../../utils/audit.utils');

// ── Mapper ────────────────────────────────────────────────────
function mapUsuario(u) {
  return {
    id:           u.usuarioId,
    nombre:       u.nombreCompleto,
    username:     u.nombreUsuario,
    rol:          derivarRolSistema(u.roles ?? []),
    activo:       u.activo && !u.eliminadoEn,
    correo:       u.correo,
    telefono:     u.telefono,
    ultimoAcceso: u.ultimoAcceso ?? null,
    createdAt:    u.creadoEn,
    updatedAt:    u.actualizadoEn,
  };
}

// ── Queries ───────────────────────────────────────────────────

async function findAll({ rol, incluirInactivos } = {}) {
  const where = {};
  if (!incluirInactivos) {
    where.activo = true;
    where.eliminadoEn = null;
  }

  // Filtro por rol de sistema (ADMIN/GESTOR/MAESTRA)
  if (rol) {
    const codigosRol = {
      ADMIN:   ['administrador', 'directora'],
      GESTOR:  ['empleado'],
      MAESTRA: ['docente'],
    };
    const codigos = codigosRol[rol] ?? [rol.toLowerCase()];
    where.roles = {
      some: {
        rol: { codigo: { in: codigos } },
        ...(incluirInactivos ? {} : { activo: true, eliminadoEn: null }),
      },
    };
  }

  const usuarios = await prisma.usuario.findMany({
    where,
    select: {
      usuarioId:      true,
      nombreCompleto: true,
      nombreUsuario:  true,
      correo:         true,
      telefono:       true,
      activo:         true,
      eliminadoEn:    true,
      ultimoAcceso:   true,
      creadoEn:       true,
      actualizadoEn:  true,
      roles: {
        where: incluirInactivos ? {} : { activo: true, eliminadoEn: null },
        select: { activo: true, eliminadoEn: true, rol: { select: { codigo: true } } },
      },
    },
    orderBy: { nombreCompleto: 'asc' },
  });

  return usuarios.map(mapUsuario);
}

async function findById(id) {
  const u = await prisma.usuario.findFirst({
    where: { usuarioId: Number(id) },
    select: {
      usuarioId:      true,
      nombreCompleto: true,
      nombreUsuario:  true,
      correo:         true,
      telefono:       true,
      activo:         true,
      eliminadoEn:    true,
      ultimoAcceso:   true,
      creadoEn:       true,
      actualizadoEn:  true,
      roles: {
        select: { activo: true, eliminadoEn: true, rol: { select: { codigo: true } } },
      },
    },
  });
  return u ? mapUsuario(u) : null;
}

async function findByUsername(username) {
  const u = await prisma.usuario.findFirst({
    where: { nombreUsuario: username },
    select: {
      usuarioId:      true,
      nombreCompleto: true,
      nombreUsuario:  true,
      correo:         true,
      activo:         true,
      eliminadoEn:    true,
      roles: {
        where: { activo: true, eliminadoEn: null },
        select: { activo: true, eliminadoEn: true, rol: { select: { codigo: true } } },
      },
    },
  });
  return u ? mapUsuario(u) : null;
}

/**
 * Crea un nuevo usuario con su rol.
 * Acepta: { nombre, username, password, rol, correo, telefono }
 * @param {object} datos
 * @param {{ usuarioId: number|null, ip: string }} [auditCtx]
 */
async function create(datos, auditCtx = {}) {
  const { nombre, username, password, rol, correo, telefono } = datos;

  // Mapear rol sistema → código PostgreSQL
  const codigoRol = {
    ADMIN:   'administrador',
    GESTOR:  'empleado',
    MAESTRA: 'docente',
  }[rol] ?? (rol ? rol.toLowerCase() : 'docente');

  // Buscar el rol en catálogo (fuera de la transacción auditada)
  const rolReg = await prisma.rol.findFirst({ where: { codigo: codigoRol } });
  if (!rolReg) throw new Error(`Rol '${codigoRol}' no encontrado en la BD.`);

  const usuario = await withAudit(auditCtx.usuarioId ?? null, auditCtx.ip ?? '0.0.0.0', async (tx) => {
    const u = await tx.usuario.create({
      data: {
        nombreCompleto: nombre,
        nombreUsuario:  username,
        passwordHash:   password,
        correo:         correo ?? null,
        telefono:       telefono ?? null,
        activo:         true,
        roles: {
          create: {
            rolId: rolReg.rolId,
            activo: true,
          },
        },
      },
      select: {
        usuarioId:      true,
        nombreCompleto: true,
        nombreUsuario:  true,
        correo:         true,
        telefono:       true,
        activo:         true,
        eliminadoEn:    true,
        ultimoAcceso:   true,
        creadoEn:       true,
        actualizadoEn:  true,
        roles: {
          where: { activo: true, eliminadoEn: null },
          select: { activo: true, eliminadoEn: true, rol: { select: { codigo: true } } },
        },
      },
    });

    // Crear permisos por defecto según el rol
    const defaultPermisos = [];
    if (codigoRol === 'empleado' || rol === 'GESTOR') {
      ['alumnos', 'tutores', 'pagos', 'becas', 'calificaciones', 'configuracion', 'colegiaturas'].forEach(m => defaultPermisos.push({ usuarioId: u.usuarioId, modulo: m, nivel: 'escritura', activo: true }));
      defaultPermisos.push({ usuarioId: u.usuarioId, modulo: 'reportes', nivel: 'lectura', activo: true });
    } else if (codigoRol === 'docente' || rol === 'MAESTRA') {
      defaultPermisos.push({ usuarioId: u.usuarioId, modulo: 'tutores', nivel: 'lectura', activo: true });
      defaultPermisos.push({ usuarioId: u.usuarioId, modulo: 'calificaciones', nivel: 'escritura', activo: true });
    }

    if (defaultPermisos.length > 0) {
      await tx.usuarioPermisoModulo.createMany({ data: defaultPermisos });
    }

    return u;
  });

  return mapUsuario(usuario);
}

/**
 * @param {string|number} id
 * @param {object} datos
 * @param {{ usuarioId: number|null, ip: string }} [auditCtx]
 */
async function update(id, datos, auditCtx = {}) {
  const { nombre, username, password, rol, correo, telefono } = datos;

  await withAudit(auditCtx.usuarioId ?? null, auditCtx.ip ?? '0.0.0.0', async (tx) => {
    await tx.usuario.update({
      where: { usuarioId: Number(id) },
      data: {
        ...(nombre   ? { nombreCompleto: nombre } : {}),
        ...(username ? { nombreUsuario: username } : {}),
        ...(password ? { passwordHash: password } : {}),
        ...(correo   !== undefined ? { correo } : {}),
        ...(telefono !== undefined ? { telefono } : {}),
      },
    });

    // Actualizar rol si se especificó
    if (rol) {
      const codigoRol = {
        ADMIN:   'administrador',
        GESTOR:  'empleado',
        MAESTRA: 'docente',
      }[rol] ?? rol.toLowerCase();

      const rolReg = await tx.rol.findFirst({ where: { codigo: codigoRol } });
      if (rolReg) {
        await tx.usuarioRol.updateMany({
          where: { usuarioId: Number(id), activo: true },
          data:  { activo: false },
        });
        await tx.usuarioRol.upsert({
          where: { usuarioId_rolId: { usuarioId: Number(id), rolId: rolReg.rolId } },
          update: { activo: true },
          create: { usuarioId: Number(id), rolId: rolReg.rolId, activo: true },
        });
      }
    }
  });

  return findById(id);
}

/**
 * @param {string|number} id
 * @param {{ usuarioId: number|null, ip: string }} [auditCtx]
 */
async function softDelete(id, auditCtx = {}) {
  return withAudit(auditCtx.usuarioId ?? null, auditCtx.ip ?? '0.0.0.0', (tx) =>
    tx.usuario.update({
      where: { usuarioId: Number(id) },
      data: { activo: false, eliminadoEn: new Date() },
    })
  );
}

async function reactivar(id, auditCtx = {}) {
  await withAudit(auditCtx.usuarioId ?? null, auditCtx.ip ?? '0.0.0.0', async (tx) => {
    await tx.usuario.update({
      where: { usuarioId: Number(id) },
      data: { activo: true, eliminadoEn: null },
    });
    // Reactivar roles
    await tx.usuarioRol.updateMany({
      where: { usuarioId: Number(id) },
      data: { activo: true, eliminadoEn: null },
    });
  });
  return findById(id);
}

module.exports = {
  findAll,
  findById,
  findByUsername,
  create,
  update,
  softDelete,
  reactivar,
};
