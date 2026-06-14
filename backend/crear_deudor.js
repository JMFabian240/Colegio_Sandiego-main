const prisma = require('./src/config/database');

async function run() {
  const c = await prisma.calendarioPago.findFirst();
  console.log('Concepto valido:', c ? c.concepto : 'No hay pagos');

  let alumno = await prisma.alumno.findFirst({ orderBy: { alumnoId: 'desc' } });
  if (!alumno) return console.log('No hay alumnos');
  
  const ciclo = await prisma.cicloEscolar.findFirst({ where: { activo: true } });
  const hoy = new Date();
  
  const hace1Mes = new Date(hoy.getFullYear(), hoy.getMonth() - 1, 1);
  const hace2Meses = new Date(hoy.getFullYear(), hoy.getMonth() - 2, 1);
  const hace3Meses = new Date(hoy.getFullYear(), hoy.getMonth() - 3, 1);
  
  try {
    await prisma.calendarioPago.createMany({
      data: [
        { alumnoId: alumno.alumnoId, cicloId: ciclo.cicloId, concepto: c.concepto, mes: 'Marzo', fechaVencimiento: hace3Meses, montoOriginal: 2500, estadoCobro: 'pendiente' },
        { alumnoId: alumno.alumnoId, cicloId: ciclo.cicloId, concepto: c.concepto, mes: 'Abril', fechaVencimiento: hace2Meses, montoOriginal: 2500, estadoCobro: 'pendiente' },
        { alumnoId: alumno.alumnoId, cicloId: ciclo.cicloId, concepto: c.concepto, mes: 'Mayo', fechaVencimiento: hace1Mes, montoOriginal: 2500, estadoCobro: 'pendiente' }
      ]
    });
    console.log('Adeudos creados exitosamente para:', alumno.nombreCompleto);
  } catch (e) {
    console.error('Error al crear:', e.message);
  }
}

run().finally(() => prisma.$disconnect());