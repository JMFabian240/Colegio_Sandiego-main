'use strict';

const path                  = require('path');
const { Router }            = require('express');
const multer                = require('multer');
const pagosController       = require('../controllers/pagos/pagos.controller');
const documentosController  = require('../controllers/pagos/documentos.controller');
const recargosController    = require('../controllers/pagos/recargos.controller');
const { authenticate }      = require('../middleware/auth.middleware');
const { authorize, authorizePermiso } = require('../middleware/rbac.middleware');
const { validate }          = require('../middleware/validate.middleware');
const { crearPagoValidators } = require('../utils/validators/pagos.validator');

// Configurar multer para comprobantes
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const dir = path.join(__dirname, '..', '..', 'uploads', 'comprobantes');
    const fs = require('fs');
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: function (req, file, cb) {
    const ext = path.extname(file.originalname);
    cb(null, `pago_${req.params.pagoId}_${Date.now()}${ext}`);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB max
  fileFilter: (req, file, cb) => {
    const allowed = ['application/pdf', 'image/jpeg', 'image/png', 'image/webp'];
    if (allowed.includes(file.mimetype)) cb(null, true);
    else cb(new Error('Solo se permiten archivos PDF, JPG, PNG o WEBP.'));
  },
});

const router = Router();

router.use(authenticate);

// GET /api/v1/pagos
router.get('/', authorizePermiso('pagos', 'lectura'), pagosController.listar);

// GET /api/v1/pagos/calendario — calendar entries (must come BEFORE /:id)
router.get('/calendario', authorizePermiso('pagos', 'lectura'), pagosController.calendario);

// GET /api/v1/pagos/total/:alumnoId — suma total de pagos de un alumno
router.get('/total/:alumnoId', authorizePermiso('pagos', 'lectura'), pagosController.totalPorAlumno);

// PATCH /api/v1/pagos/recargos/:recargoId — modificar/condonar recargo (solo ADMIN)
router.patch('/recargos/:recargoId', authorize('ADMIN'), recargosController.modificarRecargo);

// POST /api/v1/pagos/adelantado
router.post('/adelantado', authorizePermiso('pagos', 'escritura'), pagosController.registrarAdelantado);

// GET /api/v1/pagos/:id
router.get('/:id', authorizePermiso('pagos', 'lectura'), pagosController.obtener);

// POST /api/v1/pagos
router.post('/', crearPagoValidators, validate,
  authorizePermiso('pagos', 'escritura'),
  pagosController.registrar
);

// POST /api/v1/pagos/:pagoId/comprobante — subir comprobante digital
router.post('/:pagoId/comprobante',
  authorizePermiso('pagos', 'escritura'),
  upload.single('comprobante'),
  documentosController.subirComprobante
);

// GET /api/v1/pagos/:pagoId/comprobante — descargar comprobante
router.get('/:pagoId/comprobante',
  authorizePermiso('pagos', 'lectura'),
  documentosController.descargarComprobante
);

// GET /api/v1/pagos/:pagoId/tiene-comprobante
router.get('/:pagoId/tiene-comprobante',
  authorizePermiso('pagos', 'lectura'),
  documentosController.tieneComprobante
);

module.exports = router;
