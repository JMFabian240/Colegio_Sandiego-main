'use strict';

const planesService = require('../../services/planes/planes.service');
const { success, clientError, serverError } = require('../../utils/response.utils');

async function previewPlan(req, res) {
  try {
    const { id } = req.params;
    const { meses } = req.query;
    
    if (!meses || (Number(meses) !== 10 && Number(meses) !== 12)) {
      return clientError(res, 'Debe especificar meses=10 o meses=12', 400);
    }

    const resultado = await planesService.previsualizarPlan(id, Number(meses));
    return success(res, resultado, 'Vista previa de plan generada.');
  } catch (err) {
    console.error('[PlanesController.previewPlan] Error:', err);
    if (err.statusCode && err.statusCode < 500) {
      return clientError(res, err.message, err.statusCode);
    }
    return serverError(res, err.message || 'Error al generar la vista previa del plan.');
  }
}

async function assignPlan(req, res) {
  try {
    const { id } = req.params;
    const { meses } = req.body;
    
    if (!meses || (Number(meses) !== 10 && Number(meses) !== 12)) {
      return clientError(res, 'Debe especificar meses: 10 o 12 en el body', 400);
    }

    const resultado = await planesService.asignarPlan(id, Number(meses), req.usuario.id);
    return success(res, resultado, 'Plan asignado exitosamente.', 201);
  } catch (err) {
    console.error('[PlanesController.assignPlan] Error:', err);
    if (err.statusCode && err.statusCode < 500) {
      return clientError(res, err.message, err.statusCode);
    }
    return serverError(res, err.message || 'Error al asignar el plan.');
  }
}

async function listarActivos(req, res) {
  try {
    const planes = await require('../../config/database').planPago.findMany({
      where: { activo: true, ciclo: { activo: true } },
      select: { planPagoId: true, nombre: true, meses: true, montoMensual: true }
    });
    return success(res, planes, 'Planes activos obtenidos.');
  } catch(err) {
    console.error('[PlanesController.listarActivos] Error:', err);
    return serverError(res, err.message || 'Error al obtener planes activos.');
  }
}

async function resetPlan(req, res) {
  try {
    const { id } = req.params;
    const resultado = await planesService.resetPlan(id, req.usuario.id);
    return success(res, resultado, 'Plan reseteado exitosamente.', 200);
  } catch (err) {
    console.error('[PlanesController.resetPlan] Error:', err);
    if (err.statusCode && err.statusCode < 500) {
      return clientError(res, err.message, err.statusCode);
    }
    return serverError(res, err.message || 'Error al resetear el plan.');
  }
}

module.exports = {
  previewPlan,
  assignPlan,
  listarActivos,
  resetPlan
};
