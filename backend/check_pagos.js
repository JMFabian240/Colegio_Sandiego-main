require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const alumnosAlCorriente = await prisma.inscripcionCiclo.count({
    where: { estadoFinanciero: 'al_corriente' }
  });
  const alumnosConAdeudo = await prisma.inscripcionCiclo.count({
    where: { estadoFinanciero: 'adeudo_activo' }
  });
  
  console.log(`Alumnos al corriente: ${alumnosAlCorriente}`);
  console.log(`Alumnos con adeudo: ${alumnosConAdeudo}`);
}

main().finally(() => prisma.$disconnect());
