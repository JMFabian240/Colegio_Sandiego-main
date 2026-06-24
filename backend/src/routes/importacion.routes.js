'use strict';

const { Router }        = require('express');
const importacionController = require('../controllers/importacion/importacion.controller');
const { authenticate }  = require('../middleware/auth.middleware');
const { authorize }     = require('../middleware/rbac.middleware');

const router = Router();

router.use(authenticate);

// Importaciones — solo ADMIN y GESTOR
router.post('/alumnos', authorize('ADMIN', 'GESTOR'), importacionController.importarAlumnos);
router.post('/docentes', authorize('ADMIN', 'GESTOR'), importacionController.importarDocentes);

module.exports = router;
