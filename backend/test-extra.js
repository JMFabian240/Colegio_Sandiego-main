const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const res = await prisma.calificacionExtracurricular.create({
      data: {
        alumnoId: 10,
        club: 'inglés',
        periodoId: 1,
        cicloId: 1,
        valorNumerico: 9.5,
        registradaPor: 1
      }
    });
    console.log("Success:", res);
  } catch (e) {
    console.error("Prisma error:", e);
  }
  await prisma.$disconnect();
}
main();
