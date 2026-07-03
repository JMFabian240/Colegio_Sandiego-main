'use strict';

const { body, param } = require('express-validator');
const { TIPOS_BECA_VALIDOS, ESTADOS_SOLICITUD_VALIDOS } = require('../constants');

const crearSolicitudBecaValidators = [
  body('alumnoId')
    .notEmpty().withMessage('El ID del alumno es obligatorio.')
    .isInt({ min: 1 }).withMessage('El ID del alumno debe ser numérico.'),
  
  body('becaId')
    .notEmpty().withMessage('El ID de la beca es obligatorio.')
    .isInt({ min: 1 }).withMessage('El ID de la beca debe ser numérico.'),

  body('motivo')
    .optional()
    .trim()
    .isLength({ max: 500 }).withMessage('El motivo no puede exceder 500 caracteres.'),
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

const crearCatalogoBecaValidators = [
  body('nombreBeca')
    .trim()
    .notEmpty().withMessage('El nombre de la beca es obligatorio.')
    .isLength({ max: 60 }).withMessage('El nombre no puede exceder 60 caracteres.'),

  body('criterio')
    .notEmpty().withMessage('El criterio de asignación es obligatorio.')
    .isIn(['inscripcion_temprana', 'calificacion', 'hermanos', 'especial'])
    .withMessage('El criterio debe ser tiempo de inscripción, calificación, beca por hermanos o especial.'),

  body('porcentaje')
    .notEmpty().withMessage('El porcentaje es obligatorio.')
    .isNumeric().withMessage('El porcentaje debe ser numérico.')
    .custom((value) => {
      const p = parseFloat(value);
      if (p < 1 || p > 100) throw new Error('El porcentaje debe ser un valor entre 1 y 100.');
      return true;
    }),
];

const actualizarCatalogoBecaValidators = [
  body('nombreBeca')
    .optional()
    .trim()
    .notEmpty().withMessage('El nombre de la beca no puede estar vacío.')
    .isLength({ max: 60 }).withMessage('El nombre no puede exceder 60 caracteres.'),

  body('criterio')
    .optional()
    .notEmpty().withMessage('El criterio de asignación no puede estar vacío.')
    .isIn(['inscripcion_temprana', 'calificacion', 'hermanos', 'especial'])
    .withMessage('El criterio debe ser tiempo de inscripción, calificación, beca por hermanos o especial.'),

  body('porcentaje')
    .optional()
    .notEmpty().withMessage('El porcentaje no puede estar vacío.')
    .isNumeric().withMessage('El porcentaje debe ser numérico.')
    .custom((value) => {
      const p = parseFloat(value);
      if (p < 1 || p > 100) throw new Error('El porcentaje debe ser un valor entre 1 y 100.');
      return true;
    }),
];

const asignarBecaValidators = [
  body('alumnoId')
    .notEmpty().withMessage('El ID del alumno es obligatorio.')
    .isInt({ min: 1 }).withMessage('El ID del alumno debe ser numérico.'),
  
  body('becaId')
    .notEmpty().withMessage('El ID de la beca es obligatorio.')
    .isInt({ min: 1 }).withMessage('El ID de la beca debe ser numérico.'),
    
  body('motivo')
    .optional()
    .trim()
    .isLength({ max: 500 }).withMessage('El motivo no puede exceder 500 caracteres.'),
];

const retirarBecaValidators = [
  param('id')
    .notEmpty().withMessage('El ID de la asignación es obligatorio.')
    .isInt({ min: 1 }).withMessage('El ID de la asignación debe ser numérico.'),
  body('motivoRetiro')
    .notEmpty().withMessage('El motivo del retiro es obligatorio.')
    .trim()
    .isLength({ max: 500 }).withMessage('El motivo no puede exceder 500 caracteres.'),
];

module.exports = { 
  crearSolicitudBecaValidators, 
  resolverSolicitudValidators, 
  crearCatalogoBecaValidators, 
  actualizarCatalogoBecaValidators,
  asignarBecaValidators,
  retirarBecaValidators
};
