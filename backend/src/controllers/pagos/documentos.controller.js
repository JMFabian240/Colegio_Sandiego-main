'use strict';

const path   = require('path');
const fs     = require('fs');
const crypto = require('crypto');
const prisma = require('../../config/database');

const UPLOAD_DIR = path.join(__dirname, '..', '..', '..', 'uploads', 'comprobantes');

// Asegurar que el directorio de uploads existe
if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

/**
 * POST /api/v1/pagos/:pagoId/comprobante
 * Sube un comprobante (PDF/imagen) y lo vincula al pago.
 */
async function subirComprobante(req, res, next) {
  try {
    const pagoId = Number(req.params.pagoId);

    if (!req.file) {
      return res.status(400).json({ ok: false, message: 'No se recibió ningún archivo.' });
    }

    // Verificar que el pago existe
    const pago = await prisma.pago.findUnique({ where: { pagoId } });
    if (!pago) {
      // Eliminar archivo temporal
      fs.unlinkSync(req.file.path);
      return res.status(404).json({ ok: false, message: 'Pago no encontrado.' });
    }

    // Calcular hash SHA256
    const fileBuffer = fs.readFileSync(req.file.path);
    const hash = crypto.createHash('sha256').update(fileBuffer).digest('hex');

    // Crear registro en Documento
    const documento = await prisma.documento.create({
      data: {
        tipoDocumento: 'comprobante_pago',
        nombreOriginal: req.file.originalname,
        rutaAlmacen: req.file.path,
        mimeType: req.file.mimetype,
        tamanoBytes: BigInt(req.file.size),
        hashSha256: hash,
        pagoId: pagoId,
        subidoPor: req.usuario?.id ?? null,
      },
    });

    res.status(201).json({
      ok: true,
      message: 'Comprobante subido correctamente.',
      data: {
        documentoId: documento.documentoId,
        nombreOriginal: documento.nombreOriginal,
        mimeType: documento.mimeType,
      },
    });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/pagos/:pagoId/comprobante
 * Descarga el comprobante del pago.
 */
async function descargarComprobante(req, res, next) {
  try {
    const pagoId = Number(req.params.pagoId);

    const documento = await prisma.documento.findFirst({
      where: { pagoId, tipoDocumento: 'comprobante_pago' },
      orderBy: { subidoEn: 'desc' },
    });

    if (!documento) {
      return res.status(404).json({ ok: false, message: 'No hay comprobante para este pago.' });
    }

    if (!fs.existsSync(documento.rutaAlmacen)) {
      return res.status(404).json({ ok: false, message: 'El archivo ya no existe en el servidor.' });
    }

    res.set({
      'Content-Type': documento.mimeType,
      'Content-Disposition': `inline; filename="${documento.nombreOriginal}"`,
    });
    fs.createReadStream(documento.rutaAlmacen).pipe(res);
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/pagos/:pagoId/tiene-comprobante
 * Verifica si un pago tiene comprobante (para el icono 📎 en la tabla).
 */
async function tieneComprobante(req, res, next) {
  try {
    const pagoId = Number(req.params.pagoId);
    const doc = await prisma.documento.findFirst({
      where: { pagoId, tipoDocumento: 'comprobante_pago' },
      select: { documentoId: true, nombreOriginal: true },
    });
    res.json({ ok: true, data: { tiene: !!doc, documento: doc } });
  } catch (err) { next(err); }
}

module.exports = { subirComprobante, descargarComprobante, tieneComprobante };
