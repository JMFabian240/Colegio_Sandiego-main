'use strict';

const { Router }                   = require('express');
const alumnosController            = require('../controllers/alumnos/alumnos.controller');
const cierreController             = require('../controllers/alumnos/cierre.controller');
const { authenticate }             = require('../middleware/auth.middleware');
const { authorize, authorizePermiso } = require('../middleware/rbac.middleware');
const { validate }                 = require('../middleware/validate.middleware');
const {
  crearAlumnoValidators,
  actualizarAlumnoValidators,
  buscarAlumnoValidators,
} = require('../utils/validators/alumnos.validator');

const router = Router();

// Todos los endpoints de alumnos requieren autenticación
router.use(authenticate);

// POST /api/v1/alumnos/cierre-ciclo — solo ADMIN
router.post('/cierre-ciclo',
  authorize('ADMIN'),
  cierreController.cerrarCiclo
);

// GET /api/v1/alumnos — Listar (requiere permiso de lectura, pagos o calificaciones, o ser MAESTRA para ver sus propios)
router.get('/', buscarAlumnoValidators, validate,
  (req, res, next) => {
    const rol = req.usuario?.rol;
    if (rol === 'ADMIN' || rol === 'MAESTRA') return next();
    const p = req.usuario?.permisos || {};
    if ((p.alumnos && p.alumnos !== 'NINGUNO') || 
        (p.pagos && p.pagos !== 'NINGUNO') || 
        (p.calificaciones && p.calificaciones !== 'NINGUNO')) {
      return next();
    }
    return res.status(403).json({ ok: false, message: 'Se requiere permiso de alumnos, pagos o calificaciones.' });
  },
  alumnosController.listar
);

// GET /api/v1/alumnos/:id/historial-academico
router.get('/:id/historial-academico',
  authorizePermiso('alumnos', 'lectura'),
  alumnosController.obtenerHistorialAcademico
);

// GET /api/v1/alumnos/:id
router.get('/:id',
  authorizePermiso('alumnos', 'lectura'),
  alumnosController.obtener
);

// POST /api/v1/alumnos — Crear (requiere permiso de escritura)
router.post('/', crearAlumnoValidators, validate,
  authorizePermiso('alumnos', 'escritura'),
  alumnosController.crear
);

// PUT /api/v1/alumnos/:id — Actualizar (requiere permiso de escritura)
router.put('/:id', actualizarAlumnoValidators, validate,
  authorizePermiso('alumnos', 'escritura'),
  alumnosController.actualizar
);

// DELETE /api/v1/alumnos/:id — solo ADMIN
router.delete('/:id',
  authorize('ADMIN'),
  alumnosController.eliminar
);

module.exports = router;
