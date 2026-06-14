const prisma = require('./src/config/database');
async function check() {
  const al = await prisma.inscripcionCiclo.findMany({ select: { alumnoId: true, mesesAdeudo: true, alumno: { select: { nombreCompleto: true } } } });
  console.log(al.filter(a => a.mesesAdeudo > 0));
}
check().finally(() => prisma.$disconnect());
