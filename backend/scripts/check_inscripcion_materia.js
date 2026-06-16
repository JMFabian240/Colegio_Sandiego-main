const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const count = await prisma.inscripcionMateria.count();
  console.log('Total InscripcionMateria:', count);
}

main().catch(console.error).finally(() => prisma.$disconnect());
