const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const periodos = await prisma.periodoEvaluacion.findMany();
  console.log(JSON.stringify(periodos, null, 2));
}
main().finally(() => prisma.$disconnect());
