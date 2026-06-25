const prisma = require('./src/config/database');
async function check() {
  const planes = await prisma.planPago.findMany({
    where: { activo: true, ciclo: { activo: true } }
  });
  console.log("Planes activos en ciclo activo:", planes);
  process.exit(0);
}
check();
