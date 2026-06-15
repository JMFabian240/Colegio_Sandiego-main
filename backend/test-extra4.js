const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const rs = await prisma.periodoEvaluacion.findMany();
  console.log(rs);
}
main().finally(() => prisma.$disconnect());
