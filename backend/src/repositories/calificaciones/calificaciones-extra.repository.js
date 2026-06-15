const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

/**
 * Encuentra una calificación extracurricular específica
 */
async function findUnique(alumnoId, club, periodoId, cicloId) {
  return prisma.calificacionExtracurricular.findUnique({
    where: {
      alumnoId_club_periodoId_cicloId: {
        alumnoId,
        club,
        periodoId,
        cicloId
      }
    }
  });
}

/**
 * Obtiene todas las calificaciones extracurriculares de un alumno
 */
async function findByAlumno(alumnoId) {
  return prisma.calificacionExtracurricular.findMany({
    where: { alumnoId },
    include: {
      periodo: true,
      ciclo: true
    },
    orderBy: [
      { ciclo: { fechaInicio: 'desc' } },
      { periodo: { numero: 'asc' } }
    ]
  });
}

/**
 * Crea una nueva calificación extracurricular
 */
async function create(data) {
  return prisma.calificacionExtracurricular.create({
    data
  });
}

/**
 * Modifica una calificación extracurricular existente
 */
async function update(id, data) {
  return prisma.calificacionExtracurricular.update({
    where: { calificacionExtracurricularId: id },
    data
  });
}

module.exports = {
  findUnique,
  findByAlumno,
  create,
  update
};
