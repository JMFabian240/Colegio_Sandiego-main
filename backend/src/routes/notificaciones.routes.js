'use strict';

const express = require('express');
const router = express.Router();
const { verificarYEnviarAlertas } = require('../services/notificaciones/alertasPagos.service');
const { authenticate } = require('../middleware/auth.middleware');
const { authorize } = require('../middleware/rbac.middleware');

/**
 * POST /api/v1/notificaciones/test-cron
 * Endpoint manual para disparar la revisión de vencimientos (solo ADMIN).
 */
router.post('/test-cron', authenticate, authorize('ADMIN'), async (req, res, next) => {
  try {
    const resultado = await verificarYEnviarAlertas();
    res.json({
      ok: resultado.exito,
      message: resultado.exito ? 'Revisión ejecutada exitosamente.' : 'Error al ejecutar la revisión.',
      data: resultado
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
