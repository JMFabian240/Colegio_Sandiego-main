'use strict';

const express = require('express');
const router = express.Router({ mergeParams: true });
const planesController = require('../../controllers/planes/planes.controller');
const { authenticate } = require('../../middleware/auth.middleware');
const { authorize } = require('../../middleware/rbac.middleware');

router.use(authenticate);

// Endpoint montado asumiendo que viene de /api/v1/alumnos/:id/planes
router.get('/preview', authorize('ADMIN', 'GESTOR'), planesController.previewPlan);
router.post('/', authorize('ADMIN', 'GESTOR'), planesController.assignPlan);

module.exports = router;
