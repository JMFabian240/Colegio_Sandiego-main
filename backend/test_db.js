const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const res = await prisma.$queryRawUnsafe("SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'materia_tipo_check'");
  console.log(res);
}
main().finally(() => prisma.$disconnect());
