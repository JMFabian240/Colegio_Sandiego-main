/**
 * SAE — Middleware de Control de Acceso por Rol (RBAC)
 * Verifica que el usuario autenticado tenga el rol requerido.
 *
 * Roles del sistema (orden jerárquico descendente):
 *   ADMIN   → acceso total
 *   GESTOR  → acceso administrativo parcial
 *   MAESTRA → acceso académico restringido
 *
 * Uso en rutas:
 *   router.post('/usuarios', authenticate, authorize('ADMIN'), controller.crear)
 *   router.get('/alumnos', authenticate, authorize('ADMIN', 'GESTOR'), controller.listar)
 */

'use strict';

/**
 * Genera un middleware que valida el rol del usuario.
 * @param {...string} rolesPermitidos - Roles que pueden acceder a la ruta
 * @returns {Function} Middleware Express
 */
function authorize(...rolesPermitidos) {
  return (req, res, next) => {
    if (!req.usuario) {
      return res.status(401).json({
        ok: false,
        message: 'No autenticado. Ejecuta authenticate antes de authorize.',
      });
    }

    const rolUsuario = req.usuario.rol;

    if (!rolesPermitidos.includes(rolUsuario)) {
      return res.status(403).json({
        ok: false,
        message: `Acceso denegado. Tu rol (${rolUsuario}) no tiene permisos para esta acción.`,
        rolesRequeridos: rolesPermitidos,
      });
    }

    next();
  };
}

function authorizePermiso(modulo, nivel) {
  return (req, res, next) => {
    if (!req.usuario) {
      return res.status(401).json({
        ok: false,
        message: 'No autenticado. Ejecuta authenticate antes de authorizePermiso.',
      });
    }

    const rolUsuario = req.usuario.rol;
    // ADMIN tiene acceso a todos los módulos operativos por defecto
    if (rolUsuario === 'ADMIN') {
      return next();
    }

    const permisos = req.usuario.permisos || {};
    const { PERMISOS_POR_DEFECTO } = require('../utils/constants');

    // Si es GESTOR o MAESTRA y nunca se le han configurado permisos (objeto vacío),
    // mantiene su acceso por defecto usando PERMISOS_POR_DEFECTO.
    if ((rolUsuario === 'GESTOR' || rolUsuario === 'MAESTRA') && Object.keys(permisos).length === 0) {
      const defaultPerm = PERMISOS_POR_DEFECTO[rolUsuario]?.[modulo] || 'NINGUNO';
      if (defaultPerm === 'NINGUNO') {
        return res.status(403).json({
          ok: false,
          message: `Acceso denegado. No tienes permisos para el módulo ${modulo}.`,
        });
      }
      if (nivel === 'escritura' && defaultPerm !== 'escritura') {
         return res.status(403).json({
          ok: false,
          message: `Acceso denegado. Necesitas permisos de escritura para el módulo ${modulo}.`,
        });
      }
      return next();
    }
    
    const permisoUsuario = permisos[modulo];

    if (!permisoUsuario || permisoUsuario === 'NINGUNO') {
      return res.status(403).json({
        ok: false,
        message: `Acceso denegado. No tienes permisos para el módulo ${modulo}.`,
      });
    }

    if (nivel === 'escritura' && permisoUsuario !== 'escritura') {
       return res.status(403).json({
        ok: false,
        message: `Acceso denegado. Necesitas permisos de escritura para el módulo ${modulo}.`,
      });
    }

    next();
  };
}

/**
 * Atajos de autorización por combinaciones de roles frecuentes
 */
const soloAdmin           = authorize('ADMIN');
const adminOGestor        = authorize('ADMIN', 'GESTOR');
const todosLosRoles       = authorize('ADMIN', 'GESTOR', 'MAESTRA');

module.exports = { authorize, authorizePermiso, soloAdmin, adminOGestor, todosLosRoles };
