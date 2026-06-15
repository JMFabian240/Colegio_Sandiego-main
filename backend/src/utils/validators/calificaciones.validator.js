'use strict';

const { body } = require('express-validator');
const { PERIODOS_VALIDOS } = require('../constants');

const guardarCalificacionValidators = [
  body('alumnoId')
    .isInt({ min: 1 }).withMessage('El alumnoId es obligatorio.'),

  body('grupoMateriaId')
    .isInt({ min: 1 }).withMessage('El grupoMateriaId es obligatorio.'),

  body('periodo')
    .notEmpty().withMessage('El periodo es obligatorio.')
    .isIn(PERIODOS_VALIDOS)
    .withMessage(`El periodo debe ser: ${PERIODOS_VALIDOS.join(', ')}.`),

  body('valor')
    .custom((value) => {
      if (value === null || value === undefined) return true;
      const num = parseFloat(value);
      if (isNaN(num) || num < 0 || num > 10) {
        throw new Error('La calificación debe ser un número entre 0 y 10.');
      }
      return true;
    }),
];

const guardarCalificacionesLoteValidators = [
  body('calificaciones')
    .isArray({ min: 1 }).withMessage('Se requiere un array de calificaciones.'),

  body('calificaciones.*.alumnoId')
    .isInt({ min: 1 }).withMessage('Cada calificación requiere un alumnoId válido.'),

  body('calificaciones.*.grupoMateriaId')
    .isInt({ min: 1 }).withMessage('Cada calificación requiere un grupoMateriaId válido.'),

  body('calificaciones.*.periodo')
    .isIn(PERIODOS_VALIDOS)
    .withMessage('Periodo inválido en algún registro.'),

  body('calificaciones.*.valor')
    .custom((value) => {
      console.log('VALIDATOR GOT VALUE:', value, typeof value);
      if (value === null || value === undefined || value === '') return true;
      const num = parseFloat(value);
      if (isNaN(num) || num < 0 || num > 10) {
        throw new Error('CUSTOM_ERROR');
      }
      return true;
    }),
];

module.exports = { guardarCalificacionValidators, guardarCalificacionesLoteValidators };
