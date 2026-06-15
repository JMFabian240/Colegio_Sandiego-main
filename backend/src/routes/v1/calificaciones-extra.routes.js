'use strict';

const { Router } = require('express');
const router = Router();
const controller = require('../../controllers/calificaciones/calificaciones-extra.controller');
const { authenticate } = require('../../middleware/auth.middleware');
const { authorize }    = require('../../middleware/rbac.middleware');

router.use(authenticate);

// Obtener las calificaciones extra de un alumno (lo pueden ver admin, gestor y docentes)
router.get('/alumno/:alumnoId', authorize('ADMIN', 'GESTOR', 'MAESTRA'), controller.obtenerPorAlumno);

// Solo ADMIN, GESTOR y DOCENTE (o los que determine el caso de uso) pueden registrar y modificar
router.post('/', authorize('ADMIN', 'GESTOR', 'MAESTRA'), controller.registrarCalificacion);
router.put('/:id', authorize('ADMIN', 'GESTOR', 'MAESTRA'), controller.modificarCalificacion);

module.exports = router;
