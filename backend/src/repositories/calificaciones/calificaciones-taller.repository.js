const prisma = require('../../config/database');
async function findUnique(alumnoId, periodoId, cicloId) {
  return prisma.calificacionTaller.findUnique({
    where: {
      alumnoId_periodoId_cicloId: {
        alumnoId,
        periodoId,
        cicloId
      }
    }
  });
}

async function findByAlumno(alumnoId) {
  return prisma.calificacionTaller.findMany({
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

async function create(data) {
  return prisma.calificacionTaller.create({
    data
  });
}

async function update(id, data) {
  return prisma.calificacionTaller.update({
    where: { calificacionTallerId: id },
    data
  });
}

module.exports = {
  findUnique,
  findByAlumno,
  create,
  update
};
