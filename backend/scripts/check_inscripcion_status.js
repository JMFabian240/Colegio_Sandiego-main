const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const count = await prisma.inscripcionCiclo.groupBy({ by: ['estadoEnCiclo'], _count: { estadoEnCiclo: true } });
  console.log(count);
  
  const byCycle = await prisma.inscripcionCiclo.groupBy({ by: ['cicloId'], _count: { cicloId: true } });
  console.log(byCycle);
}

main().catch(console.error).finally(() => prisma.$disconnect());
