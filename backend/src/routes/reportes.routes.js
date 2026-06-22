'use strict';

const { Router } = require('express');
const reportesController = require('../controllers/reportes/reportes.controller');
const { authenticate }   = require('../middleware/auth.middleware');
const { authorize, authorizePermiso } = require('../middleware/rbac.middleware');

const router = Router();
router.use(authenticate, authorizePermiso('reportes', 'lectura'));

router.get('/corte-caja',         reportesController.corteCaja);
router.get('/ingresos-mensuales', reportesController.ingresosMensuales);
router.get('/deudores',           reportesController.deudores);
router.get('/facturables',        reportesController.facturables);
router.get('/examen-restringido', reportesController.examenRestringido);

module.exports = router;
