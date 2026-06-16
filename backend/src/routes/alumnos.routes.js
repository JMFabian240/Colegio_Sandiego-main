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

// GET /api/v1/alumnos — Listar (requiere permiso de lectura)
router.get('/', buscarAlumnoValidators, validate,
  authorizePermiso('alumnos', 'lectura'),
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
