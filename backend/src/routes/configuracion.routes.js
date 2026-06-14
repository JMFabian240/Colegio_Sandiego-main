'use strict';

const { Router } = require('express');
const configController = require('../controllers/configuracion/configuracion.controller');
const { authenticate } = require('../middleware/auth.middleware');
const { soloAdmin }    = require('../middleware/rbac.middleware');

const router = Router();
router.use(authenticate, soloAdmin);

router.get('/', configController.listar);
router.put('/', configController.actualizar);

module.exports = router;
