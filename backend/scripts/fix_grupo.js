const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const alumno = await prisma.alumno.findUnique({ where: { alumnoId: 16 } });
  const ciclo = await prisma.cicloEscolar.findFirst({ where: { activo: true } });
  
  let grupo = await prisma.grupo.findFirst({
    where: { cicloId: ciclo.cicloId }
  });
  
  if (!grupo) {
    console.log("No hay ningun grupo en el ciclo.");
    return;
  }

  const inscripcion = await prisma.inscripcionCiclo.findFirst({
    where: { alumnoId: 16, cicloId: ciclo.cicloId }
  });

  if (!inscripcion) {
    console.log("Creando inscripción...");
    await prisma.inscripcionCiclo.create({
      data: {
        alumnoId: 16,
        cicloId: ciclo.cicloId,
        grupoId: grupo.grupoId,
        planPago: '12_meses'
      }
    });
    console.log("Inscripción creada exitosamente.");
  } else {
    console.log("El alumno ya tiene inscripción.");
  }
}

main().catch(console.error).finally(() => prisma.$disconnect());
