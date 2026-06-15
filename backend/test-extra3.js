const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const rs = await prisma.calificacionExtracurricular.findMany({
    where: { alumnoId: 10 },
    include: { periodo: true, ciclo: true }
  });
  console.log(JSON.stringify(rs, null, 2));
}
main().finally(() => prisma.$disconnect());
