const prisma = require('./src/config/database');

async function run() {
  const alumno = await prisma.alumno.findFirst({ orderBy: { alumnoId: 'desc' } });
  if (!alumno) return console.log('No hay alumnos');
  
  const ciclo = await prisma.cicloEscolar.findFirst({ where: { activo: true } });
  
  await prisma.inscripcionCiclo.updateMany({
    where: { alumnoId: alumno.alumnoId, cicloId: ciclo.cicloId },
    data: { mesesAdeudo: 3 }
  });
  
  console.log('Meses de adeudo actualizados a 3 para:', alumno.nombreCompleto);
}

run().finally(() => prisma.$disconnect());
