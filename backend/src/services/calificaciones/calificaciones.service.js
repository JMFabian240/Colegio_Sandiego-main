/**
 * SAE — Calificaciones Service
 *
 * Funciones:
 *   listar(filtros)                → lista calificaciones con filtros
 *   listarPorAlumno(id, periodo)   → calificaciones de un alumno en un período
 *   guardar(datos, usuarioId)      → upsert individual (resolución automática de periodo)
 *   guardarLote(cals, usuarioId)   → upsert masivo
 *   calcularPromedio(alumnoId, opts) → promedio por materia y promedio general
 *
 * Nota: la resolución automática de periodo_id (string → FK) está
 * encapsulada en el repository (resolverPeriodoId). El servicio no necesita
 * duplicar esa lógica — simplemente orquesta y agrega reglas de negocio.
 */

'use strict';

const calificacionesRepository = require('../../repositories/calificaciones/calificaciones.repository');
const alumnosRepository        = require('../../repositories/alumnos/alumnos.repository');

// ──────────────────────────────────────────────────────────────
// LECTURA
// ──────────────────────────────────────────────────────────────

async function listar(filtros) {
  return calificacionesRepository.findAll(filtros);
}

async function listarPorAlumno(alumnoId, periodo) {
  const alumno = await alumnosRepository.findById(alumnoId);
  if (!alumno) {
    throw Object.assign(new Error('Alumno no encontrado.'), { statusCode: 404 });
  }
  return calificacionesRepository.findByAlumnoYPeriodo(alumnoId, periodo);
}

// ──────────────────────────────────────────────────────────────
// ESCRITURA
// ──────────────────────────────────────────────────────────────

/**
 * Guarda (upsert) una calificación individual.
 * La resolución del periodo_id (string → FK) se delega al repository.
 */
async function guardar(datos, registradoPorId, auditCtx = {}) {
  return calificacionesRepository.upsert({ ...datos, registradoPorId }, auditCtx);
}

/**
 * Guarda (upsert) un lote de calificaciones en paralelo.
 * Cada registro resuelve su periodo_id independientemente.
 */
async function guardarLote(calificaciones, registradoPorId, auditCtx = {}) {
  const registros = calificaciones.map((c) => ({ ...c, registradoPorId }));
  return calificacionesRepository.upsertLote(registros, auditCtx);
}

// ──────────────────────────────────────────────────────────────
// CÁLCULO DE PROMEDIOS (RF-Calificaciones)
// ──────────────────────────────────────────────────────────────

/**
 * Calcula el promedio de un alumno por materia y el promedio general.
 *
 * Regla de negocio:
 *   - Solo se incluyen calificaciones con `cuentaParaPromedio = true`
 *   - Si se especifica `periodoId`, filtra solo ese período
 *   - El promedio general es la media aritmética de los promedios por materia
 *   - Se redondea a 2 decimales
 *
 * @param {number} alumnoId
 * @param {object} [opts]
 * @param {number}  [opts.periodoId]  FK del período (opcional)
 * @param {string}  [opts.periodo]    String del período ("TRIMESTRE_1", etc.) — alternativa a periodoId
 *
 * @returns {{
 *   alumnoId: number,
 *   totalCalificaciones: number,
 *   promedioGeneral: number | null,
 *   materias: Array<{ materia: string, grupoMateriaId: number, promedio: number, calificaciones: number }>
 * }}
 */
async function calcularPromedio(alumnoId, { periodoId, periodo } = {}) {
  // 1. Verificar que el alumno existe
  const alumno = await alumnosRepository.findById(alumnoId);
  if (!alumno) {
    throw Object.assign(new Error('Alumno no encontrado.'), { statusCode: 404 });
  }

  // 2. Obtener calificaciones del alumno que cuentan para promedio.
  //    soloParaPromedio=true empuja el filtro a la query de Prisma (WHERE en DB)
  //    evitando cargar registros en memoria para luego descartarlos.
  const filtros = { alumnoId, soloParaPromedio: true };
  if (periodo) filtros.periodo = periodo;

  const todasLasCalificaciones = await calificacionesRepository.findAll(filtros);

  // 3. Filtrar por periodoId exacto si se especificó (refinamiento en memoria sobre resultado ya reducido)
  const validas = periodoId
    ? todasLasCalificaciones.filter(c => c.periodoId === Number(periodoId))
    : todasLasCalificaciones;

  // 4. Verificación extra: solo valores numéricos válidos (ya garantizado por DB, pero defensivo)
  const validasFinal = validas.filter(c => c.valor !== null && typeof c.valor === 'number');

  if (validasFinal.length === 0) {
    return {
      alumnoId: Number(alumnoId),
      totalCalificaciones: 0,
      promedioGeneral: null,
      materias: [],
    };
  }

  // 5. Agrupar por materia (grupoMateriaId) para calcular promedio por materia
  const porMateria = new Map();

  for (const cal of validasFinal) {
    const key = cal.grupoMateriaId;
    if (!porMateria.has(key)) {
      porMateria.set(key, {
        materia:        cal.grupoMateria?.materia ?? `Materia ${key}`,
        grupoMateriaId: key,
        valores:        [],
      });
    }
    porMateria.get(key).valores.push(cal.valor);
  }

  // 6. Calcular promedio por materia
  const materias = Array.from(porMateria.values()).map((m) => {
    const suma   = m.valores.reduce((acc, v) => acc + v, 0);
    const promedio = Math.round((suma / m.valores.length) * 100) / 100;
    return {
      materia:        m.materia,
      grupoMateriaId: m.grupoMateriaId,
      promedio,
      calificaciones: m.valores.length,
    };
  });

  // 7. Promedio general = media aritmética de los promedios por materia
  const sumaPromedios  = materias.reduce((acc, m) => acc + m.promedio, 0);
  const promedioGeneral = Math.round((sumaPromedios / materias.length) * 100) / 100;

  return {
    alumnoId:           Number(alumnoId),
    totalCalificaciones: validasFinal.length,
    promedioGeneral,
    materias: materias.sort((a, b) => a.materia.localeCompare(b.materia)),
  };
}

module.exports = { listar, listarPorAlumno, guardar, guardarLote, calcularPromedio };
