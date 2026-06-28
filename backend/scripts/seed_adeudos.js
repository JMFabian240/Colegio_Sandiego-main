const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  // Buscar 3 alumnos
  const alumnos = await prisma.alumno.findMany({ take: 3 });
  if (alumnos.length === 0) return;

  const ciclos = await prisma.cicloEscolar.findMany({ take: 1 });
  const cicloId = ciclos.length > 0 ? ciclos[0].cicloId : 1;

  for (const alumno of alumnos) {
    // Agregar un material didáctico
    await prisma.calendarioPago.create({
      data: {
        alumnoId: alumno.alumnoId,
        cicloId: cicloId,
        concepto: 'material',
        mes: 'inicio',
        fechaVencimiento: new Date('2026-09-09'),
        montoOriginal: 1500,
        estadoCobro: 'pendiente'
      }
    });

    // Agregar un uniforme
    await prisma.calendarioPago.create({
      data: {
        alumnoId: alumno.alumnoId,
        cicloId: cicloId,
        concepto: 'uniforme',
        mes: 'inicio',
        fechaVencimiento: new Date('2026-09-09'),
        montoOriginal: 2500,
        estadoCobro: 'pendiente'
      }
    });

    console.log(`Adeudos generados para: ${alumno.nombreCompleto}`);
  }
}

main()
  .catch(e => console.error(e))
  .finally(() => prisma.$disconnect());
