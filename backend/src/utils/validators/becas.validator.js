'use strict';

const { body, param } = require('express-validator');
const { TIPOS_BECA_VALIDOS, ESTADOS_SOLICITUD_VALIDOS } = require('../constants');

const crearSolicitudBecaValidators = [
  body('alumnoId')
    .isInt({ min: 1 }).withMessage('El alumnoId es obligatorio.'),

  body('tipo')
    .notEmpty().withMessage('El tipo de beca es obligatorio.'),

  body('motivo')
    .trim()
    .notEmpty().withMessage('El motivo de la solicitud es obligatorio.')
    .isLength({ min: 10, max: 500 }).withMessage('El motivo debe tener entre 10 y 500 caracteres.'),
];

const resolverSolicitudValidators = [
  param('id').isInt({ min: 1 }).withMessage('El ID de la solicitud debe ser un número válido.'),

  body('estado')
    .notEmpty().withMessage('El estado es obligatorio.')
    .isIn(['APROBADA', 'RECHAZADA'])
    .withMessage('El estado debe ser APROBADA o RECHAZADA.'),

  body('observaciones')
    .optional({ nullable: true })
    .trim()
    .isLength({ max: 500 }).withMessage('Las observaciones no pueden exceder 500 caracteres.'),
];

module.exports = { crearSolicitudBecaValidators, resolverSolicitudValidators };
