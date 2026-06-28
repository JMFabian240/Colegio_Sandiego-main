const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const extraService = require('./src/services/calificaciones/calificaciones-extra.service');

async function main() {
  try {
    const res = await extraService.modificarCalificacion(12, {
      valorNumerico: 4,
      motivo: "Actualización en lote desde panel",
      usuarioId: 6
    });
    console.log("Success:", res);
  } catch (e) {
    console.error("Error modifying:", e);
  }
}
main().finally(() => prisma.$disconnect());
