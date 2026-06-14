const prisma = require('./src/config/database');

async function syncDeudas() {
  const inscripciones = await prisma.inscripcionCiclo.findMany();
  for (const ins of inscripciones) {
    const adeudosReales = await prisma.calendarioPago.count({
      where: {
        alumnoId: ins.alumnoId,
        cicloId: ins.cicloId,
        concepto: 'colegiatura',
        estadoCobro: { not: 'pagado' },
        eliminadoEn: null
      }
    });
    
    if (ins.mesesAdeudo !== adeudosReales) {
      await prisma.inscripcionCiclo.update({
        where: { inscripcionId: ins.inscripcionId },
        data: { mesesAdeudo: adeudosReales }
      });
      console.log(`Alumno ${ins.alumnoId} sincronizado: ${ins.mesesAdeudo} -> ${adeudosReales}`);
    }
  }
}

syncDeudas().finally(() => prisma.$disconnect());
