'use strict';

const express = require('express');
const router = express.Router();
const planesController = require('../../controllers/planes/planes.controller');
const { authenticate } = require('../../middleware/auth.middleware');

router.use(authenticate);

router.get('/', planesController.listarActivos);

module.exports = router;
