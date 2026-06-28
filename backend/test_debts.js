require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const deudores = await prisma.calendarioPago.groupBy({
    by: ['alumnoId'],
    _count: { calendarioPagoId: true },
    where: {
      estadoCobro: { in: ['pendiente', 'parcial'] },
      fechaVencimiento: { lt: new Date() },
      eliminadoEn: null
    }
  });

  const target = deudores.filter(d => d._count.calendarioPagoId >= 3);
  console.log("Alumnos with 3+ debts:", target.length);
  
  for (const t of target) {
    const aId = t.alumnoId;
    const a = await prisma.alumno.findUnique({ where: { alumnoId: aId } });
    console.log(`Alumno ${aId} - ${a.nombreCompleto} - Estado actual: ${a.estado}`);
  }
}

main().finally(() => prisma.$disconnect());
