/**
 * SAE — Middleware de Permisos Granulares por Módulo (RF-03)
 *
 * Uso en rutas:
 *   router.get('/', authenticate, checkPermiso('alumnos', 'lectura'), controller.listar)
 *   router.post('/', authenticate, checkPermiso('alumnos', 'escritura'), controller.crear)
 *
 * Lógica de acceso:
 *   - ADMIN → siempre pasa (sin consultar BD)
 *   - GESTOR / MAESTRA → se consulta usuario_permiso_modulo
 *     * Sin fila activa → 403 (acceso denegado)
 *     * nivel='lectura'  y se requiere 'escritura' → 403
 *     * nivel='escritura' → siempre pasa (incluye lectura)
 */

'use strict';

const permisosRepository = require('../repositories/permisos/permisos.repository');

/**
 * Módulos válidos del sistema SAE.
 */
const MODULOS_VALIDOS = new Set([
  'alumnos', 'tutores', 'pagos', 'becas',
  'colegiaturas', 'calificaciones', 'reportes',
  'bitacora', 'usuarios', 'configuracion',
]);

/**
 * Genera un middleware que valida el permiso del usuario sobre un módulo.
 *
 * @param {string} modulo          - Módulo del sistema (ej. 'alumnos')
 * @param {'lectura'|'escritura'}  nivelRequerido
 * @returns {Function} Middleware Express
 */
function checkPermiso(modulo, nivelRequerido = 'lectura') {
  if (!MODULOS_VALIDOS.has(modulo)) {
    throw new Error(`checkPermiso: módulo inválido "${modulo}". Módulos válidos: ${[...MODULOS_VALIDOS].join(', ')}`);
  }

  return async (req, res, next) => {
    try {
      if (!req.usuario) {
        return res.status(401).json({
          ok: false,
          message: 'No autenticado.',
        });
      }

      // ADMIN siempre tiene acceso total — no se consulta la tabla
      if (req.usuario.rol === 'ADMIN') {
        return next();
      }

      // GESTOR y MAESTRA: consultar permisos individuales
      const permiso = await permisosRepository.findByUsuarioModulo(
        req.usuario.id,
        modulo
      );

      if (!permiso || !permiso.activo) {
        return res.status(403).json({
          ok: false,
          message: `No tienes acceso al módulo "${modulo}".`,
          modulo,
          nivelRequerido,
        });
      }

      // Si se requiere escritura pero solo tiene lectura → denegar
      if (nivelRequerido === 'escritura' && permiso.nivel === 'lectura') {
        return res.status(403).json({
          ok: false,
          message: `Acceso de solo lectura al módulo "${modulo}". Se requiere permiso de escritura.`,
          modulo,
          nivelRequerido,
          nivelActual: permiso.nivel,
        });
      }

      next();
    } catch (err) {
      next(err);
    }
  };
}

module.exports = { checkPermiso, MODULOS_VALIDOS };
