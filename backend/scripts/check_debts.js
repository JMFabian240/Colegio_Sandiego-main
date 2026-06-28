const prisma = require('./src/config/database');
async function check() {
  const deudas = await prisma.calendarioPago.findMany({ where: { alumnoId: 19 } });
  console.log(deudas);
}
check().finally(() => prisma.$disconnect());
