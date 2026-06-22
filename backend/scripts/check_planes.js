const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const planes = await prisma.planPago.findMany({
    where: { ciclo: { activo: true } }
  });
  console.log(planes);
}
main().finally(() => prisma.$disconnect());
