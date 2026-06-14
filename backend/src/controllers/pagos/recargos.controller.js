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
    if (!motivo || motivo.trim().length < 3) {
      return res.status(400).json({ ok: false, message: 'Se requiere un motivo de al menos 3 caracteres.' });
    }

    const recargo = await prisma.recargo.findUnique({ where: { recargoId } });
    if (!recargo) {
      return res.status(404).json({ ok: false, message: 'Recargo no encontrado.' });
    }

    const nuevoMonto = Math.max(0, Number(montoNuevo));
    const diferencia = Number(recargo.montoActual) - nuevoMonto;

    // Actualizar el recargo
    const recargoActualizado = await prisma.recargo.update({
      where: { recargoId },
      data: {
        montoActual: nuevoMonto,
        estado: nuevoMonto === 0 ? 'condonado' : 'modificado',
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

    res.json({
      ok: true,
      message: nuevoMonto === 0
        ? 'Recargo condonado completamente.'
        : `Recargo modificado de $${Number(recargo.montoActual).toFixed(2)} a $${nuevoMonto.toFixed(2)}.`,
      data: recargoActualizado,
    });
  } catch (err) { next(err); }
}

module.exports = { modificarRecargo };
