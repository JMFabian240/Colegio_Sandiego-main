const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const rs = await prisma.calificacionExtracurricular.findMany({ where: { alumnoId: 10 } });
  console.log(JSON.stringify(rs, null, 2));
}
main().finally(() => prisma.$disconnect());
