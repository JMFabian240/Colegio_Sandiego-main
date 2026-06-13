'use strict';

const { Router }         = require('express');
const bitacoraController = require('../controllers/bitacora/bitacora.controller');
const { authenticate }   = require('../middleware/auth.middleware');
const { soloAdmin }      = require('../middleware/rbac.middleware');

const router = Router();

router.use(authenticate, soloAdmin);

// GET /api/v1/bitacora?fechaInicio=&fechaFin=&usuarioId=&pagina=&limite=
router.get('/',         bitacoraController.listar);

// GET /api/v1/bitacora/exportar?formato=pdf&fechaInicio=&fechaFin=&usuarioId=
router.get('/exportar', bitacoraController.exportar);

module.exports = router;
