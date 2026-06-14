'use strict';

const { Router }             = require('express');
const becasController        = require('../controllers/becas/becas.controller');
const { authenticate }       = require('../middleware/auth.middleware');
const { authorize }          = require('../middleware/rbac.middleware');
const { validate }           = require('../middleware/validate.middleware');
const {
  crearSolicitudBecaValidators,
  resolverSolicitudValidators,
  crearCatalogoBecaValidators,
  actualizarCatalogoBecaValidators,
  asignarBecaValidators,
  retirarBecaValidators
} = require('../utils/validators/becas.validator');

const router = Router();

router.use(authenticate);

// GET /api/v1/becas — becas activas (todos los roles)
router.get('/', authorize('ADMIN', 'GESTOR', 'MAESTRA'), becasController.listarBecas);

// ── CATÁLOGO DE BECAS ─────────────────────────────────────────
router.get('/catalogo', authorize('ADMIN', 'GESTOR'), becasController.listarCatalogoBecas);
router.post('/catalogo', 
  crearCatalogoBecaValidators, validate,
  authorize('ADMIN', 'GESTOR'), 
  becasController.crearCatalogoBeca
);
router.patch('/catalogo/:id',
  actualizarCatalogoBecaValidators, validate,
  authorize('ADMIN', 'GESTOR'),
  becasController.actualizarCatalogoBeca
);
router.delete('/catalogo/:id', authorize('ADMIN'), becasController.eliminarCatalogoBeca);
// ─────────────────────────────────────────────────────────────

// ── ASIGNACIONES DIRECTAS (ADMIN y GESTOR) ────────────────────────────
router.post('/asignar',
  asignarBecaValidators, validate,
  authorize('ADMIN', 'GESTOR'),
  becasController.asignarBecaDirecta
);

router.post('/asignaciones/:id/retirar',
  retirarBecaValidators, validate,
  authorize('ADMIN', 'GESTOR'),
  becasController.retirarBecaDirecta
);
// ─────────────────────────────────────────────────────────────

// GET /api/v1/becas/solicitudes — ADMIN ve todas; GESTOR ve las suyas
router.get('/solicitudes', authorize('ADMIN', 'GESTOR'), becasController.listarSolicitudes);

// POST /api/v1/becas/solicitudes — GESTOR y ADMIN pueden solicitar (RF-21, 26, 28)
router.post('/solicitudes',
  crearSolicitudBecaValidators, validate,
  authorize('ADMIN', 'GESTOR'),
  becasController.solicitarBeca
);

// PATCH /api/v1/becas/solicitudes/:id/resolver — solo ADMIN puede aprobar/rechazar
router.patch('/solicitudes/:id/resolver',
  resolverSolicitudValidators, validate,
  authorize('ADMIN'),
  becasController.resolverSolicitud
);

// DELETE /api/v1/becas/:id — solo ADMIN puede desactivar beca
router.delete('/:id', authorize('ADMIN'), becasController.desactivarBeca);

module.exports = router;
