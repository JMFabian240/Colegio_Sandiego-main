const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const al = await prisma.alumno.findFirst({
    where: { nombreCompleto: { contains: 'Alejandro Cruz Martinez' } },
    include: { inscripciones: { include: { grupo: true } } }
  });
  console.dir(al, {depth: null});
}
main().finally(() => prisma.$disconnect());
