'use strict';

const { Router } = require('express');
const tarifasController = require('../controllers/tarifas/tarifas.controller');
const { authenticate } = require('../middleware/auth.middleware');
const { adminOGestor } = require('../middleware/rbac.middleware');

const router = Router();
router.use(authenticate, adminOGestor);

router.get('/ciclos', tarifasController.listarCiclos);
router.post('/ciclos', tarifasController.crearCiclo);
router.get('/niveles', tarifasController.listarNiveles);
router.get('/', tarifasController.obtenerTarifas);
router.put('/', tarifasController.guardarTarifas);

module.exports = router;

module.exports = router;
