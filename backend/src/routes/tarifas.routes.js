'use strict';

const { Router } = require('express');
const tarifasController = require('../controllers/tarifas/tarifas.controller');
const { authenticate } = require('../middleware/auth.middleware');
const { authorizePermiso } = require('../middleware/rbac.middleware');

const router = Router();
router.use(authenticate);

router.get('/ciclos', authorizePermiso('configuracion', 'lectura'), tarifasController.listarCiclos);
router.post('/ciclos', authorizePermiso('configuracion', 'escritura'), tarifasController.crearCiclo);
router.get('/niveles', authorizePermiso('configuracion', 'lectura'), tarifasController.listarNiveles);
router.get('/', authorizePermiso('configuracion', 'lectura'), tarifasController.obtenerTarifas);
router.put('/', authorizePermiso('configuracion', 'escritura'), tarifasController.guardarTarifas);

module.exports = router;

module.exports = router;
