/**
 * SAE — Bitácora Controller
 * RF-09: listar registros de auditoría en pantalla.
 * RF-10: exportar bitácora en PDF.
 */

'use strict';

const bitacoraService = require('../../services/bitacora/bitacora.service');
const { success }     = require('../../utils/response.utils');

/**
 * GET /api/v1/bitacora
 * Query params: fechaInicio, fechaFin, usuarioId, pagina, limite
 */
async function listar(req, res, next) {
  try {
    const { fechaInicio, fechaFin, usuarioId, accion, rol, pagina, limite } = req.query;
    const resultado = await bitacoraService.listar({
      fechaInicio,
      fechaFin,
      usuarioId: usuarioId ? Number(usuarioId) : undefined,
      accion:    accion    || undefined,
      rol:       rol       || undefined,
      pagina:    pagina    ? Number(pagina)    : 1,
      limite:    limite    ? Number(limite)    : 50,
    });
    return success(res, resultado, `${resultado.total} registros en la bitácora.`);
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/bitacora/exportar?formato=pdf
 * Query params opcionales: fechaInicio, fechaFin, usuarioId
 */
async function exportar(req, res, next) {
  try {
    const { fechaInicio, fechaFin, usuarioId } = req.query;
    const filtros = {
      fechaInicio,
      fechaFin,
      usuarioId: usuarioId ? Number(usuarioId) : undefined,
    };

    const pdfBuffer = await bitacoraService.exportarPDF(filtros);

    const timestamp = new Date().toISOString().slice(0, 10);
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="bitacora_${timestamp}.pdf"`
    );
    return res.send(pdfBuffer);
  } catch (err) { next(err); }
}

module.exports = { listar, exportar };
