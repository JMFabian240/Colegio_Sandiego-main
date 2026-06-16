'use strict';

const { Router }               = require('express');
const calificacionesController = require('../controllers/calificaciones/calificaciones.controller');
const { authenticate }         = require('../middleware/auth.middleware');
const { authorize, authorizePermiso } = require('../middleware/rbac.middleware');
const { validate }             = require('../middleware/validate.middleware');
const {
  guardarCalificacionValidators,
  guardarCalificacionesLoteValidators,
} = require('../utils/validators/calificaciones.validator');

const router = Router();

router.use(authenticate);

// GET /api/v1/calificaciones
router.get('/', authorizePermiso('calificaciones', 'lectura'), calificacionesController.listar);

// GET /api/v1/calificaciones/alumno/:alumnoId
router.get('/alumno/:alumnoId',
  authorizePermiso('calificaciones', 'lectura'),
  calificacionesController.listarPorAlumno
);

// GET /api/v1/calificaciones/promedio/:alumnoId
// Query: ?periodoId=N | ?periodo=TRIMESTRE_1 | sin query = todos los períodos
router.get('/promedio/:alumnoId',
  authorizePermiso('calificaciones', 'lectura'),
  calificacionesController.promedio
);

// POST /api/v1/calificaciones — guardar una calificación
router.post('/', guardarCalificacionValidators, validate,
  authorizePermiso('calificaciones', 'escritura'),
  calificacionesController.guardar
);

// POST /api/v1/calificaciones/lote — guardar lote
router.post('/lote', guardarCalificacionesLoteValidators, validate,
  authorizePermiso('calificaciones', 'escritura'),
  calificacionesController.guardarLote
);

module.exports = router;
