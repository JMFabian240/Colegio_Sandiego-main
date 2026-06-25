require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function check() {
  const res = await prisma.$queryRawUnsafe(`SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'inscripcion_ciclo_estado_financiero_check'`);
  console.log(res);
}

check().catch(console.error).finally(() => prisma.$disconnect());
