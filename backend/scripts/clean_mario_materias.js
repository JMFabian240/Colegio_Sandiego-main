const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const result = await prisma.grupoMateria.updateMany({
    where: {
      docenteId: 4,
      grupo: { docenteTitularId: { not: 4 } }
    },
    data: {
      docenteId: null
    }
  });
  console.log(`Unassigned Mario from ${result.count} subjects in non-titular groups.`);
}
main().finally(() => prisma.$disconnect());
