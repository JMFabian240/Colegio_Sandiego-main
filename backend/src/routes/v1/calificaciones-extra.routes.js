'use strict';

const { Router } = require('express');
const router = Router();
const controller = require('../../controllers/calificaciones/calificaciones-extra.controller');
const { authenticate } = require('../../middleware/auth.middleware');
const { authorize, authorizePermiso } = require('../../middleware/rbac.middleware');
const { validate } = require('../../middleware/validate.middleware');

router.use(authenticate);

// GET /api/v1/calificaciones-extra/alumno/:alumnoId
router.get('/alumno/:alumnoId', authorizePermiso('calificaciones', 'lectura'), controller.obtenerPorAlumno);

// POST /api/v1/calificaciones-extra
router.post('/', authorizePermiso('calificaciones', 'escritura'), controller.registrarCalificacion);
router.put('/:id', authorizePermiso('calificaciones', 'escritura'), controller.modificarCalificacion);

module.exports = router;
