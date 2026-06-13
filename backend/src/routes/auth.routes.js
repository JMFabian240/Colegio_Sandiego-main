'use strict';

const { Router }           = require('express');
const authController       = require('../controllers/auth/auth.controller');
const { authenticate }     = require('../middleware/auth.middleware');
const { soloAdmin }        = require('../middleware/rbac.middleware');
const { loginValidators }  = require('../utils/validators/auth.validator');
const { validate }         = require('../middleware/validate.middleware');

const router = Router();

// POST /api/v1/auth/login
router.post('/login', loginValidators, validate, authController.login);

// POST /api/v1/auth/logout — revoca el token actual (RF-06)
router.post('/logout', authenticate, authController.logout);

// GET /api/v1/auth/me — requiere token
router.get('/me', authenticate, authController.me);

// POST /api/v1/auth/refresh
router.post('/refresh', authController.refresh);

// PATCH /api/v1/auth/usuarios/:id/reset-password
router.patch('/usuarios/:id/reset-password', authenticate, soloAdmin, authController.resetPassword);

module.exports = router;
