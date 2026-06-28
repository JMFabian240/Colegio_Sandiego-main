const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const extraService = require('./src/services/calificaciones/calificaciones-extra.service');

async function main() {
  try {
    const res = await extraService.registrarCalificacion({
      alumnoId: 10,
      club: 'inglés',
      numeroTrimestre: 2,
      cicloId: 1,
      valorNumerico: 4
    });
    console.log("Success:", res);
  } catch (e) {
    console.error("Error:", e);
  }
}
main().finally(() => prisma.$disconnect());
