const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const grupos = await prisma.grupo.findMany({
    where: { OR: [ { docenteTitularId: 4 }, { gruposMaterias: { some: { docenteId: 4 } } } ] }
  });
  console.log(grupos);
}
main().finally(() => prisma.$disconnect());
