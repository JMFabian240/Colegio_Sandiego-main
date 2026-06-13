'use strict';

const { Router }                   = require('express');
const tutoresController            = require('../controllers/tutores/tutores.controller');
const { authenticate }             = require('../middleware/auth.middleware');
const { authorize }                = require('../middleware/rbac.middleware');
const { checkPermiso }             = require('../middleware/permisos.middleware');

const router = Router();

// Todos los endpoints requieren autenticación
router.use(authenticate);

// GET /api/v1/tutores
router.get('/',
  checkPermiso('tutores', 'lectura'),
  tutoresController.listar
);

// GET /api/v1/tutores/:id
router.get('/:id',
  checkPermiso('tutores', 'lectura'),
  tutoresController.obtener
);

// POST /api/v1/tutores
router.post('/',
  checkPermiso('tutores', 'escritura'),
  tutoresController.crear
);

// PUT /api/v1/tutores/:id
router.put('/:id',
  checkPermiso('tutores', 'escritura'),
  tutoresController.actualizar
);

// POST /api/v1/tutores/:id/vincular
router.post('/:id/vincular',
  checkPermiso('tutores', 'escritura'),
  tutoresController.vincularAlumno
);

// DELETE /api/v1/tutores/:id/desvincular/:alumnoId
router.delete('/:id/desvincular/:alumnoId',
  checkPermiso('tutores', 'escritura'),
  tutoresController.desvincularAlumno
);

// DELETE /api/v1/tutores/:id — solo ADMIN
router.delete('/:id',
  authorize('ADMIN'),
  tutoresController.eliminar
);

module.exports = router;
