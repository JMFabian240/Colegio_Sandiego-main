const prisma = require('./src/config/database');

async function main() {
  const deudas = await prisma.calendarioPago.findMany({
    where: {
      montoRecargo: { gt: 0 }
    },
    include: {
      recargos: true
    }
  });

  let creados = 0;
  for (const deuda of deudas) {
    if (deuda.recargos.length === 0) {
      await prisma.recargo.create({
        data: {
          calendarioPago: { connect: { calendarioPagoId: deuda.calendarioPagoId } },
          montoOriginal: deuda.montoRecargo,
          montoActual: deuda.montoRecargo,
          estado: 'aplicado'
        }
      });
      creados++;
    }
  }
  console.log(`Migración completada. Se crearon ${creados} registros de recargo faltantes.`);
}

main().catch(console.error).finally(() => prisma.$disconnect());
