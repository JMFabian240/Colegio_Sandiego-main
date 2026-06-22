const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const materias = await prisma.materia.findMany({ where: { nombre: 'promp' } });
  console.log(materias);
}
main().finally(() => prisma.$disconnect());
