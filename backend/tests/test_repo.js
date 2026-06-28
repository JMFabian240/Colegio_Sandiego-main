const prisma = require('./src/config/database');
const repo = require('./src/repositories/pagos/pagos.repository');

async function testListar() {
  const pagos = await repo.findAll({ limit: 10 });
  const tieneDoc = pagos.filter(p => p.documentos && p.documentos.length > 0);
  console.log('Total:', pagos.length);
  if (tieneDoc.length > 0) {
    console.log(JSON.stringify(tieneDoc[0].documentos, null, 2));
  } else {
    console.log('Ningun pago tiene documento.');
  }
}
testListar().catch(console.error).finally(() => prisma.$disconnect());
