const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function check() {
  const incs = await prisma.inscripcionCiclo.findMany({ include: { alumno: true } });
  console.log('Inscripciones:', JSON.stringify(incs, null, 2));
}

check().finally(() => prisma.$disconnect());
