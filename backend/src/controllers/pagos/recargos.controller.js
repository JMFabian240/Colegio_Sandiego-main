'use strict';

const prisma = require('../../config/database');

/**
 * PATCH /api/v1/pagos/recargos/:recargoId
 * Modifica (o condona) un recargo aplicado.
 * Body: { montoNuevo: number, motivo: string }
 */
async function modificarRecargo(req, res, next) {
  try {
    const recargoId = Number(req.params.recargoId);
    const { montoNuevo, motivo } = req.body;

    if (montoNuevo === undefined || montoNuevo === null) {
      return res.status(400).json({ ok: false, message: 'Se requiere montoNuevo.' });
    }
    
    // Validar monto negativo (Flujo B)
    if (Number(montoNuevo) < 0) {
      return res.status(400).json({ ok: false, message: 'El monto del recargo no puede ser negativo.' });
    }

    if (!motivo || motivo.trim().length < 3) {
      return res.status(400).json({ ok: false, message: 'Se requiere un motivo de al menos 3 caracteres.' });
    }

    const recargo = await prisma.recargo.findUnique({ 
      where: { recargoId },
      include: { calendarioPago: true }
    });
    if (!recargo) {
      return res.status(404).json({ ok: false, message: 'Recargo no encontrado.' });
    }

    // Validar que no se modifique si el pago ya fue cubierto (Flujo D)
    if (recargo.calendarioPago && recargo.calendarioPago.estadoCobro === 'pagado') {
      return res.status(400).json({ ok: false, message: 'No se puede modificar un recargo que ya fue cubierto dentro de un pago registrado.' });
    }

    const nuevoMonto = Number(montoNuevo);
    const montoAnterior = Number(recargo.montoActual);

    if (nuevoMonto > Number(recargo.montoOriginal)) {
      return res.status(400).json({ ok: false, message: `El nuevo monto no puede exceder el monto original ($${Number(recargo.montoOriginal).toFixed(2)}).` });
    }

    // Actualizar el recargo
    const recargoActualizado = await prisma.recargo.update({
      where: { recargoId },
      data: {
        montoActual: nuevoMonto,
        estado: nuevoMonto === 0 ? 'condonado' : 'reducido',
        motivoModificacion: motivo.trim(),
        modificadoPor: req.usuario?.id ?? null,
        modificadoEn: new Date(),
      },
    });

    // Recalcular el montoRecargo en CalendarioPago (sumar todos los recargos activos)
    const todosRecargos = await prisma.recargo.findMany({
      where: { calendarioPagoId: recargo.calendarioPagoId },
    });
    const totalRecargos = todosRecargos.reduce((sum, r) => sum + Number(r.montoActual), 0);

    await prisma.calendarioPago.update({
      where: { calendarioPagoId: recargo.calendarioPagoId },
      data: { montoRecargo: totalRecargos },
    });

    // Registrar en bitácora (Flujos Principal y G)
    await prisma.logAuditoria.create({
      data: {
        usuarioId: req.usuario?.id || 1,
        accion: 'UPDATE',
        tablaAfectada: 'recargo',
        registroId: recargoId.toString(),
        valoresAntes: recargo,
        valoresDespues: recargoActualizado,
        direccionIp: req.ip
      }
    });

    res.json({
      ok: true,
      message: nuevoMonto === 0
        ? 'Recargo condonado completamente.'
        : `Recargo modificado de $${montoAnterior.toFixed(2)} a $${nuevoMonto.toFixed(2)}.`,
      data: recargoActualizado,
    });
  } catch (err) { next(err); }
}

module.exports = { modificarRecargo };
