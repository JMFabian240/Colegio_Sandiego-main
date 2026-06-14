'use strict';

const { Router }                   = require('express');
const alumnosController            = require('../controllers/alumnos/alumnos.controller');
const cierreController             = require('../controllers/alumnos/cierre.controller');
const { authenticate }             = require('../middleware/auth.middleware');
const { authorize }                = require('../middleware/rbac.middleware');
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

// GET /api/v1/alumnos — ADMIN y GESTOR pueden listar
router.get('/', buscarAlumnoValidators, validate,
  authorize('ADMIN', 'GESTOR'),
  alumnosController.listar
);

// GET /api/v1/alumnos/:id
router.get('/:id',
  authorize('ADMIN', 'GESTOR', 'MAESTRA'),
  alumnosController.obtener
);

// POST /api/v1/alumnos — solo ADMIN y GESTOR pueden crear
router.post('/', crearAlumnoValidators, validate,
  authorize('ADMIN', 'GESTOR'),
  alumnosController.crear
);

// PUT /api/v1/alumnos/:id
router.put('/:id', actualizarAlumnoValidators, validate,
  authorize('ADMIN', 'GESTOR'),
  alumnosController.actualizar
);

// DELETE /api/v1/alumnos/:id — solo ADMIN
router.delete('/:id',
  authorize('ADMIN'),
  alumnosController.eliminar
);

module.exports = router;
