const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const rows = await prisma.$queryRaw`SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'inscripcion_ciclo_estado_en_ciclo_check'`;
  console.log(rows);
}

main().finally(() => prisma.$disconnect());
