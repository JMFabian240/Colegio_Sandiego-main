'use strict';

const { Router }        = require('express');
const gruposController  = require('../controllers/grupos/grupos.controller');
const { authenticate }  = require('../middleware/auth.middleware');
const { authorize }     = require('../middleware/rbac.middleware');

const router = Router();

router.use(authenticate);

// GET — todos los roles pueden consultar grupos
router.get('/',    authorize('ADMIN', 'GESTOR', 'MAESTRA'), gruposController.listar);
router.get('/materias/:id/alumnos', authorize('ADMIN', 'GESTOR', 'MAESTRA'), gruposController.obtenerAlumnosMateria);
router.get('/:id', authorize('ADMIN', 'GESTOR', 'MAESTRA'), gruposController.obtener);

// Modificaciones — solo ADMIN y GESTOR
router.post('/',   authorize('ADMIN', 'GESTOR'), gruposController.crear);
router.put('/materias/:id/alumnos', authorize('ADMIN', 'GESTOR'), gruposController.actualizarAlumnosMateria);
router.put('/:id', authorize('ADMIN', 'GESTOR'), gruposController.actualizar);
router.delete('/:id', authorize('ADMIN', 'GESTOR'), gruposController.eliminar);

module.exports = router;
