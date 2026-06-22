const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  await prisma.$executeRaw`ALTER TABLE inscripcion_ciclo DROP CONSTRAINT inscripcion_ciclo_estado_en_ciclo_check`;
  await prisma.$executeRaw`ALTER TABLE inscripcion_ciclo ADD CONSTRAINT inscripcion_ciclo_estado_en_ciclo_check CHECK (estado_en_ciclo::text = ANY (ARRAY['activa'::character varying, 'baja_temporal'::character varying, 'baja_definitiva'::character varying, 'egresado'::character varying, 'promovido'::character varying, 'transicion_pendiente'::character varying]::text[]))`;
  console.log('Constraint updated');
}

main().catch(console.error).finally(() => prisma.$disconnect());
