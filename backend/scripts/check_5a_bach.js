const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const grupos = await prisma.grupo.findMany({
    where: { nombre: '5°A Bachillerato' }
  });
  console.log(grupos);
}
main().finally(() => prisma.$disconnect());
