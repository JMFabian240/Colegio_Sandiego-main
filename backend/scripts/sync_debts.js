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
        fechaVencimiento: { lt: new Date() },
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

  // Sincronizar estado global (baja temporal)
  const alumnos = await prisma.alumno.findMany({
    select: { alumnoId: true, estado: true, observaciones: true }
  });

  for (const al of alumnos) {
    const totalAdeudos = await prisma.calendarioPago.count({
      where: {
        alumnoId: al.alumnoId,
        estadoCobro: { in: ['pendiente', 'parcial'] },
        fechaVencimiento: { lt: new Date() },
        eliminadoEn: null
      }
    });

    if (totalAdeudos >= 3 && (al.estado === 'Activo' || al.estado === 'activo')) {
      const obsExtra = `[BAJA TEMPORAL AUTOMÁTICA ${new Date().toLocaleDateString()}]: Por acumular 3 o más meses de adeudo.`;
      const obsFinal = al.observaciones ? al.observaciones + '\n' + obsExtra : obsExtra;
      
      await prisma.alumno.update({
        where: { alumnoId: al.alumnoId },
        data: { estado: 'Baja Temporal', observaciones: obsFinal }
      });
      console.log(`Alumno ${al.alumnoId} suspendido por adeudo (>= 3 meses)`);
    } else if (totalAdeudos < 3 && (al.estado === 'Baja Temporal' || al.estado === 'Baja temporal')) {
      const obsExtra = `[REACTIVACIÓN AUTOMÁTICA ${new Date().toLocaleDateString()}]: Regularización de adeudos (< 3 meses).`;
      const obsFinal = al.observaciones ? al.observaciones + '\n' + obsExtra : obsExtra;
      await prisma.alumno.update({
        where: { alumnoId: al.alumnoId },
        data: { estado: 'Activo', observaciones: obsFinal }
      });
      console.log(`Alumno ${al.alumnoId} reactivado (adeudos regularizados)`);
    }
  }
}

syncDeudas().finally(() => prisma.$disconnect());
