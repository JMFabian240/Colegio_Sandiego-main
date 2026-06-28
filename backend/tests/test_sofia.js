const prisma = require('./src/config/database');
const repo = require('./src/repositories/pagos/pagos.repository');

async function testSofia() {
  const alumnos = await prisma.alumno.findMany({ where: { nombreCompleto: { contains: 'Mendoza' } } });
  if (alumnos.length === 0) return console.log('No sofia found');
  console.log('Sofia ID:', alumnos[0].alumnoId);
  const pagos = await repo.findAll({ alumnoId: alumnos[0].alumnoId });
  pagos.forEach(p => {
    console.log(`Pago ID: ${p.id}, Monto: ${p.monto}, Documentos: ${p.documentos.length}`);
  });
}
testSofia().catch(console.error).finally(() => prisma.$disconnect());
