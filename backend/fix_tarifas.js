const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  // Encontrar a Alumno 16
  const alumno = await prisma.alumno.findUnique({ where: { alumnoId: 16 } });
  if (!alumno) {
    console.log("No se encontró al alumno 16.");
    return;
  }
  
  const nivelId = alumno.nivelId;
  const ciclo = await prisma.cicloEscolar.findFirst({ where: { activo: true } });
  
  // Revisar si tiene colegiatura
  const tarifaColegiatura = await prisma.tarifa.findFirst({
    where: {
      cicloId: ciclo.cicloId,
      nivelId: nivelId,
      concepto: 'colegiatura',
      activa: true
    }
  });
  
  if (!tarifaColegiatura) {
    console.log(`Creando tarifa colegiatura para el nivel ${nivelId} en el ciclo ${ciclo.cicloId}...`);
    await prisma.tarifa.create({
      data: {
        cicloId: ciclo.cicloId,
        nivelId: nivelId,
        concepto: 'colegiatura',
        monto: 1500.00, // un monto ejemplo
        descripcion: 'Colegiatura Mensual Nivel de Alumno 16'
      }
    });
    console.log("Tarifa colegiatura creada.");
  } else {
    console.log("Ya existía la tarifa colegiatura para el nivel de Alumno 16.");
  }

  // Opcional, crear inscripción si no la tiene
  const inscripcion = await prisma.inscripcionCiclo.findFirst({
    where: { alumnoId: 16, cicloId: ciclo.cicloId }
  });

  if (!inscripcion) {
    console.log("Alumno 16 no tiene inscripción. Creando inscripción default...");
    // Obtener un grupo del nivel
    const grupo = await prisma.grupo.findFirst({
      where: { nivelId: nivelId, cicloId: ciclo.cicloId }
    });
    if (grupo) {
      await prisma.inscripcionCiclo.create({
        data: {
          alumnoId: 16,
          cicloId: ciclo.cicloId,
          grupoId: grupo.grupoId
        }
      });
      console.log("Inscripción creada.");
    } else {
      console.log("No hay grupos para este nivel, no se puede crear inscripción.");
    }
  }

}

main().catch(console.error).finally(() => prisma.$disconnect());
