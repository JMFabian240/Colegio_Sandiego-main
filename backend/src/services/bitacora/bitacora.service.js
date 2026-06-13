/**
 * SAE — Bitácora Service
 * Lógica de negocio para consultar y exportar el log de auditoría.
 *
 * Cumple: RF-09 (visualizar), RF-10 (exportar PDF).
 */

'use strict';

const bitacoraRepository = require('../../repositories/bitacora/bitacora.repository');
const PDFDocument         = require('pdfkit');

// ── Colores institucionales Colegio San Diego ──────────────────
const AZUL_MARINO = '#050E77';
const AZUL_CLARO  = '#88D0F8';
const ROJO        = '#F90300';

/**
 * Lista registros de la bitácora con filtros y paginación.
 */
async function listar(filtros) {
  return bitacoraRepository.findAll(filtros);
}

/**
 * Genera un PDF de la bitácora con los filtros indicados.
 * Retorna un Buffer con el contenido del PDF.
 *
 * @param {{ fechaInicio?, fechaFin?, usuarioId? }} filtros
 * @returns {Promise<Buffer>}
 */
async function exportarPDF(filtros) {
  // Obtener TODOS los registros para el export (sin paginación)
  const { datos } = await bitacoraRepository.findAll({ ...filtros, limite: 10000, pagina: 1 });

  return new Promise((resolve, reject) => {
    const buffers = [];
    const doc = new PDFDocument({ margin: 40, size: 'A4', bufferPages: true });

    doc.on('data', (chunk) => buffers.push(chunk));
    doc.on('end',  () => resolve(Buffer.concat(buffers)));
    doc.on('error', reject);

    // ── Encabezado ───────────────────────────────────────────
    doc
      .fillColor(AZUL_MARINO)
      .fontSize(16)
      .font('Helvetica-Bold')
      .text('COLEGIO SAN DIEGO', { align: 'center' });

    doc
      .fillColor(ROJO)
      .fontSize(12)
      .font('Helvetica-Bold')
      .text('Bitácora de Auditoría del Sistema', { align: 'center' });

    // Filtros aplicados
    const rangoFechas = filtros.fechaInicio || filtros.fechaFin
      ? `Período: ${filtros.fechaInicio || '—'} al ${filtros.fechaFin || '—'}`
      : 'Período: todos los registros';

    doc
      .moveDown(0.5)
      .fillColor('#444444')
      .fontSize(9)
      .font('Helvetica')
      .text(rangoFechas, { align: 'center' })
      .text(`Generado: ${new Date().toLocaleString('es-MX', { timeZone: 'America/Mexico_City' })}`, { align: 'center' })
      .text(`Total de registros: ${datos.length}`, { align: 'center' });

    doc.moveDown(1);

    // ── Línea separadora ──────────────────────────────────────
    doc
      .moveTo(40, doc.y)
      .lineTo(555, doc.y)
      .strokeColor(AZUL_MARINO)
      .lineWidth(1.5)
      .stroke();

    doc.moveDown(0.5);

    // ── Cabecera de tabla ─────────────────────────────────────
    const colX    = { fecha: 40, usuario: 155, accion: 285, tabla: 340, registro: 450 };
    const rowH    = 14;
    const headerY = doc.y;

    doc
      .fillColor(AZUL_MARINO)
      .rect(40, headerY - 2, 515, rowH + 4)
      .fill();

    doc
      .fillColor('white')
      .fontSize(8)
      .font('Helvetica-Bold')
      .text('Fecha / Hora',   colX.fecha,    headerY, { width: 110, lineBreak: false })
      .text('Usuario',        colX.usuario,  headerY, { width: 125, lineBreak: false })
      .text('Acción',         colX.accion,   headerY, { width: 50,  lineBreak: false })
      .text('Tabla',          colX.tabla,    headerY, { width: 105, lineBreak: false })
      .text('ID Registro',    colX.registro, headerY, { width: 60,  lineBreak: false });

    doc.moveDown(1.2);

    // ── Filas ─────────────────────────────────────────────────
    const ACCIONES_COLOR = { INSERT: '#1a7a1a', UPDATE: '#b07a00', DELETE: '#cc0000' };

    datos.forEach((row, idx) => {
      // Nueva página si no cabe la fila
      if (doc.y > 750) {
        doc.addPage();
        doc.y = 40;
      }

      const y = doc.y;
      const bg = idx % 2 === 0 ? '#f4f7ff' : 'white';

      doc.fillColor(bg).rect(40, y - 1, 515, rowH + 2).fill();

      const fechaStr = new Date(row.fechaHora).toLocaleString('es-MX', {
        timeZone: 'America/Mexico_City',
        year: '2-digit', month: '2-digit', day: '2-digit',
        hour: '2-digit', minute: '2-digit',
      });

      doc
        .fillColor('#333333')
        .fontSize(7.5)
        .font('Helvetica')
        .text(fechaStr,          colX.fecha,    y, { width: 110, lineBreak: false })
        .text(row.usuario.nombre, colX.usuario, y, { width: 125, lineBreak: false });

      doc
        .fillColor(ACCIONES_COLOR[row.accion] || '#333333')
        .font('Helvetica-Bold')
        .text(row.accion,       colX.accion,   y, { width: 50,  lineBreak: false });

      doc
        .fillColor('#333333')
        .font('Helvetica')
        .text(row.tabla,        colX.tabla,    y, { width: 105, lineBreak: false })
        .text(row.registroId ?? '—', colX.registro, y, { width: 60, lineBreak: false });

      doc.moveDown(0.95);
    });

    if (datos.length === 0) {
      doc
        .fillColor('#888888')
        .fontSize(10)
        .font('Helvetica')
        .text('No se encontraron registros con los filtros aplicados.', { align: 'center' });
    }

    // ── Pie de página ─────────────────────────────────────────
    const totalPages = doc.bufferedPageRange().count;
    for (let i = 0; i < totalPages; i++) {
      doc.switchToPage(i);
      doc
        .fillColor('#aaaaaa')
        .fontSize(7)
        .text(
          `SAE Colegio San Diego — Bitácora de Auditoría — Página ${i + 1} de ${totalPages}`,
          40, 820, { align: 'center', width: 515 }
        );
    }

    doc.end();
  });
}

module.exports = { listar, exportarPDF };
