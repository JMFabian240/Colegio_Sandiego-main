const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const count = await prisma.alumno.count();
  console.log('Total alumnos en DB:', count);
}
main().finally(() => prisma.$disconnect());
