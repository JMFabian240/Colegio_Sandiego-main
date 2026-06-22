const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const grupos = await prisma.grupo.findMany({
    where: {
      ciclo: { activo: true },
      OR: [
        { docenteTitularId: 4 },
        { gruposMaterias: { some: { docenteId: 4, eliminadoEn: null } } }
      ]
    },
    include: {
      _count: { select: { inscripciones: { where: { eliminadoEn: null, estadoEnCiclo: 'activa' } } } }
    }
  });
  console.log("Groups where Teacher 4 teaches (active cycle):");
  grupos.forEach(g => {
    console.log(`Grupo ${g.grupoId}: ${g.nombre} - Titular: ${g.docenteTitularId === 4 ? 'Yes' : 'No'} - Alumnos: ${g._count.inscripciones}`);
  });
}
main().finally(() => prisma.$disconnect());
