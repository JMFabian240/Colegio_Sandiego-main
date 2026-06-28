const prisma = require('./src/config/database');
async function main() {
  const calendarios = await prisma.calendarioPago.findMany({
    orderBy: { calendarioPagoId: 'desc' },
    take: 1,
    include: { recargos: true }
  });
  console.log(JSON.stringify(calendarios, null, 2));
}
main().catch(console.error).finally(() => prisma.$disconnect());
