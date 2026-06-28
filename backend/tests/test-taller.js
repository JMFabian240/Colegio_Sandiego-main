const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const rs = await prisma.materia.findMany({
    where: { nombre: { contains: 'Taller', mode: 'insensitive' } }
  });
  console.log(JSON.stringify(rs, null, 2));
}
main().finally(() => prisma.$disconnect());
