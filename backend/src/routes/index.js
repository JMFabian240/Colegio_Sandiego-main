/**
 * SAE — Router Principal
 * Monta todos los sub-routers bajo /api/v1
 */

'use strict';

const { Router } = require('express');

const authRoutes          = require('./auth.routes');
const alumnosRoutes       = require('./alumnos.routes');
const pagosRoutes         = require('./pagos.routes');
const becasRoutes         = require('./becas.routes');
const calificacionesRoutes= require('./calificaciones.routes');
const usuariosRoutes      = require('./usuarios.routes');
const gruposRoutes        = require('./grupos.routes');
const bitacoraRoutes      = require('./bitacora.routes');
const permisosRoutes      = require('./permisos.routes');
const tutoresRoutes       = require('./tutores.routes');
const configuracionRoutes = require('./configuracion.routes');
const reportesRoutes      = require('./reportes.routes');
const tarifasRoutes       = require('./tarifas.routes');
const planesRoutes        = require('./v1/planes.routes');
const calificacionesExtraRoutes = require('./v1/calificaciones-extra.routes');

const router = Router();

router.use('/auth',          authRoutes);
router.use('/alumnos/:id/planes', planesRoutes);
router.use('/alumnos',       alumnosRoutes);
router.use('/tutores',       tutoresRoutes);
router.use('/pagos',         pagosRoutes);
router.use('/becas',         becasRoutes);
router.use('/calificaciones',calificacionesRoutes);
router.use('/calificaciones-extra', calificacionesExtraRoutes);
router.use('/usuarios',      usuariosRoutes);
router.use('/grupos',        gruposRoutes);
router.use('/bitacora',      bitacoraRoutes);
router.use('/permisos',      permisosRoutes);
router.use('/configuracion', configuracionRoutes);
router.use('/reportes',      reportesRoutes);
router.use('/tarifas',       tarifasRoutes);

module.exports = router;

