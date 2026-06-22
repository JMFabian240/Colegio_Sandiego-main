const alumnosRepo = require('./src/repositories/alumnos/alumnos.repository.js');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const usuario = {
    id: 4,
    rol: 'MAESTRA',
    permisos: { alumnos: 'lectura', pagos: 'NINGUNO' }
  };
  const alumnos = await alumnosRepo.findAll({}, usuario);
  console.log("Total alumnos:", alumnos.length);
  if (alumnos.length > 0) {
     console.log(alumnos[0].nombreCompleto);
  }
}

main().finally(() => prisma.$disconnect());
