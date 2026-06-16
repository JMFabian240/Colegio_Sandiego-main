const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const previousCycle = await prisma.cicloEscolar.findFirst({ where: { cicloId: 5 } });
  if (!previousCycle) {
    console.log('No cycle 5');
    return;
  }
  const grupos = await prisma.grupo.findMany({ where: { cicloId: 5 }, include: { gruposMaterias: true } });
  console.log('Previous Cycle:', previousCycle.nombre);
  grupos.forEach(g => console.log('Grupo', g.nombre, 'materias:', g.gruposMaterias.length));
}

main().catch(console.error).finally(() => prisma.$disconnect());
