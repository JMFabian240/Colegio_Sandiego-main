'use strict';

const { Router }         = require('express');
const permisosController = require('../controllers/permisos/permisos.controller');
const { authenticate }   = require('../middleware/auth.middleware');
const { soloAdmin }      = require('../middleware/rbac.middleware');

const router = Router();

router.use(authenticate, soloAdmin);

// GET /api/v1/permisos/modulos — lista módulos válidos del sistema
router.get('/modulos', permisosController.listarModulos);

// GET /api/v1/permisos/usuarios/:id — permisos de un usuario
router.get('/usuarios/:id', permisosController.listarPorUsuario);

// PUT /api/v1/permisos/usuarios/:id — reemplazar todos los permisos
router.put('/usuarios/:id', permisosController.asignar);

// DELETE /api/v1/permisos/usuarios/:id/:modulo — revocar permiso de un módulo
router.delete('/usuarios/:id/:modulo', permisosController.revocar);

module.exports = router;
