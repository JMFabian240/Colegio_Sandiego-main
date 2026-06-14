'use strict';

const { body, param, query } = require('express-validator');

const crearAlumnoValidators = [
  body('nombre')
    .trim()
    .notEmpty().withMessage('El nombre del alumno es obligatorio.')
    .isLength({ max: 150 }).withMessage('El nombre no puede exceder 150 caracteres.'),

  body('matricula')
    .trim()
    .notEmpty().withMessage('La matrícula es obligatoria.')
    .matches(/^SDM-\d{4}-\d{4}$/).withMessage('La matrícula debe tener el formato SDM-XXXX-XXXX.'),

  body('curp')
    .optional({ nullable: true })
    .trim()
    .isLength({ min: 18, max: 18 }).withMessage('La CURP debe tener 18 caracteres.')
    .toUpperCase(),

  body('grupoId')
    .optional({ nullable: true })
    .isInt({ min: 1 }).withMessage('El grupoId debe ser un número entero válido.'),

  body('fechaNacimiento')
    .optional({ nullable: true })
    .isISO8601().toDate().withMessage('La fecha de nacimiento debe tener un formato válido.'),

  body('autorizadosRecoger')
    .optional({ nullable: true })
    .isString().trim(),
];

const actualizarAlumnoValidators = [
  param('id').isInt({ min: 1 }).withMessage('El ID del alumno debe ser un número entero válido.'),

  body('nombre')
    .optional()
    .trim()
    .notEmpty().withMessage('El nombre no puede estar vacío.')
    .isLength({ max: 150 }).withMessage('El nombre no puede exceder 150 caracteres.'),

  body('grupoId')
    .optional({ nullable: true })
    .isInt({ min: 1 }).withMessage('El grupoId debe ser un número entero válido.'),
];

const buscarAlumnoValidators = [
  query('q')
    .optional()
    .trim()
    .isLength({ max: 100 }).withMessage('El término de búsqueda no puede exceder 100 caracteres.'),
];

module.exports = { crearAlumnoValidators, actualizarAlumnoValidators, buscarAlumnoValidators };
