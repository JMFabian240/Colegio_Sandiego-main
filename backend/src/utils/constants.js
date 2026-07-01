/**
 * SAE — Constantes del Sistema
 *
 * Reemplaza los enums Prisma para garantizar compatibilidad
 * SQLite ↔ PostgreSQL sin cambios en el código de aplicación.
 *
 * La validación de estos valores se realiza en:
 *   - validators (express-validator)
 *   - services (reglas de negocio)
 *   - middleware (RBAC)
 *
 * Al migrar a PostgreSQL en el futuro, estas constantes
 * pueden convertirse en enums Prisma sin impacto en la lógica.
 */

'use strict';

// ── Roles de usuario ──────────────────────────────────────────
const ROLES = Object.freeze({
  ADMIN:   'ADMIN',
  GESTOR:  'GESTOR',
  MAESTRA: 'MAESTRA',
});

const ROLES_VALIDOS = Object.values(ROLES);

// ── Niveles educativos ────────────────────────────────────────
const NIVELES = Object.freeze({
  PRIMARIA:     'PRIMARIA',
  SECUNDARIA:   'SECUNDARIA',
  BACHILLERATO: 'BACHILLERATO',
});

const NIVELES_VALIDOS = Object.values(NIVELES);

// ── Estado de pago del alumno en el ciclo ────────────────────
const ESTADOS_PAGO = Object.freeze({
  AL_CORRIENTE:       'AL_CORRIENTE',
  AVISO_PREVENTIVO:   'AVISO_PREVENTIVO',
  EXAMEN_RESTRINGIDO: 'EXAMEN_RESTRINGIDO',
  BAJA_TEMPORAL:      'BAJA_TEMPORAL',
});

const ESTADOS_PAGO_VALIDOS = Object.values(ESTADOS_PAGO);

// ── Conceptos de pago ─────────────────────────────────────────
const CONCEPTOS_PAGO = Object.freeze({
  COLEGIATURA:       'COLEGIATURA',
  INSCRIPCION:       'INSCRIPCION',
  MATERIAL_DIDACTICO:'MATERIAL_DIDACTICO',
  UNIFORME:          'UNIFORME',
  OTRO:              'OTRO',
});

const CONCEPTOS_PAGO_VALIDOS = Object.values(CONCEPTOS_PAGO);

// ── Métodos de pago ───────────────────────────────────────────
const METODOS_PAGO = Object.freeze({
  TRANSFERENCIA:   'transferencia',
  TARJETA_CREDITO: 'tarjeta_credito',
  TARJETA_DEBITO:  'tarjeta_debito',
});

const METODOS_PAGO_VALIDOS = Object.values(METODOS_PAGO);

// ── Tipos de beca ─────────────────────────────────────────────
const TIPOS_BECA = Object.freeze({
  HERMANOS:             'HERMANOS',
  EXCELENCIA:           'EXCELENCIA',
  INSCRIPCION_TEMPRANA: 'INSCRIPCION_TEMPRANA',
  OTRO:                 'OTRO',
});

const TIPOS_BECA_VALIDOS = Object.values(TIPOS_BECA);

/** Porcentaje oficial por tipo de beca */
const PORCENTAJES_BECA = Object.freeze({
  HERMANOS:             15,
  EXCELENCIA:           20,
  INSCRIPCION_TEMPRANA: 10,
  OTRO:                  0,
});

// ── Estados de solicitud de beca ─────────────────────────────
const ESTADOS_SOLICITUD = Object.freeze({
  PENDIENTE: 'PENDIENTE',
  APROBADA:  'APROBADA',
  RECHAZADA: 'RECHAZADA',
});

const ESTADOS_SOLICITUD_VALIDOS = Object.values(ESTADOS_SOLICITUD);

// ── Estados de asistencia ─────────────────────────────────────
const ESTADOS_ASISTENCIA = Object.freeze({
  PRESENTE: 'PRESENTE',
  AUSENTE:  'AUSENTE',
  RETARDO:  'RETARDO',
});

const ESTADOS_ASISTENCIA_VALIDOS = Object.values(ESTADOS_ASISTENCIA);

// ── Periodos de calificación ──────────────────────────────────
const PERIODOS = Object.freeze({
  TRIMESTRE_1: 'TRIMESTRE_1',
  TRIMESTRE_2: 'TRIMESTRE_2',
  TRIMESTRE_3: 'TRIMESTRE_3',
});

const PERIODOS_VALIDOS = Object.values(PERIODOS);

// 🛑 Redirecciones por rol 🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑🛑
const REDIRECT_POR_ROL = Object.freeze({
  ADMIN:   '/panel.html',
  GESTOR:  '/panel.html',
  MAESTRA: '/panel.html',
});

const PERMISOS_POR_DEFECTO = Object.freeze({
  GESTOR: {
    alumnos: 'escritura', tutores: 'escritura', grupos: 'escritura', pagos: 'escritura',
    becas: 'escritura', colegiaturas: 'escritura', calificaciones: 'escritura',
    reportes: 'lectura', bitacora: 'NINGUNO', usuarios: 'NINGUNO', configuracion: 'NINGUNO'
  },
  MAESTRA: {
    alumnos: 'lectura', tutores: 'NINGUNO', grupos: 'lectura', pagos: 'NINGUNO',
    becas: 'NINGUNO', colegiaturas: 'NINGUNO', calificaciones: 'escritura',
    reportes: 'NINGUNO', bitacora: 'NINGUNO', usuarios: 'NINGUNO', configuracion: 'NINGUNO'
  }
});

module.exports = {
  ROLES,                    ROLES_VALIDOS,
  NIVELES,                  NIVELES_VALIDOS,
  ESTADOS_PAGO,             ESTADOS_PAGO_VALIDOS,
  CONCEPTOS_PAGO,           CONCEPTOS_PAGO_VALIDOS,
  METODOS_PAGO,             METODOS_PAGO_VALIDOS,
  TIPOS_BECA,               TIPOS_BECA_VALIDOS,
  PORCENTAJES_BECA,
  ESTADOS_SOLICITUD,        ESTADOS_SOLICITUD_VALIDOS,
  ESTADOS_ASISTENCIA,       ESTADOS_ASISTENCIA_VALIDOS,
  PERIODOS,                 PERIODOS_VALIDOS,
  REDIRECT_POR_ROL,
  PERMISOS_POR_DEFECTO,
};
