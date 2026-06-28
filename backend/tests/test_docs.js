const prisma = require('./src/config/database');

async function test() {
  const pagos = await prisma.pago.findMany({
    take: 10,
    orderBy: { registradoEn: 'desc' },
    include: { documentos: true }
  });
  
  const tieneDoc = pagos.filter(p => p.documentos && p.documentos.length > 0);
  console.log('Pagos totales:', pagos.length);
  console.log('Pagos con documentos:', tieneDoc.length);
  if (tieneDoc.length > 0) {
    console.log(JSON.stringify(tieneDoc[0], null, 2));
  } else {
    // let's see any documento
    const docs = await prisma.documento.findMany({ take: 5, orderBy: { subidoEn: 'desc' } });
    console.log('Documentos recientes:', JSON.stringify(docs, null, 2));
  }
}

test().catch(console.error).finally(() => prisma.$disconnect());
