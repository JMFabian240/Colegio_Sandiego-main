const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const gm = await prisma.grupoMateria.findMany({
    where: { 
      grupoId: { in: [2, 34] },
      docenteId: 4
    }
  });
  console.log(gm);
}
main().finally(() => prisma.$disconnect());
