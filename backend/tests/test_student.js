const prisma = require('./src/config/database');

async function main() {
  const alumno = await prisma.alumno.create({
    data: {
      matricula: 'TES' + Date.now().toString().slice(-5),
      nombreCompleto: 'Alumno De Prueba Recargo',
      curp: 'PRUE' + Date.now().toString().slice(-14),
      estado: 'Activo',
    }
  });

  const ciclo = await prisma.cicloEscolar.findFirst();
  
  const deuda = await prisma.calendarioPago.create({
    data: {
      alumno: { connect: { alumnoId: alumno.alumnoId } },
      ciclo: { connect: { cicloId: ciclo.cicloId } },
      concepto: 'colegiatura',
      mes: 'mayo',
      fechaVencimiento: new Date('2026-05-05'),
      montoOriginal: 4000,
      montoPagado: 0,
      montoRecargo: 400,
      estadoCobro: 'pendiente'
    }
  });

  await prisma.recargo.create({
    data: {
      calendarioPago: { connect: { calendarioPagoId: deuda.calendarioPagoId } },
      montoOriginal: 400,
      montoActual: 400,
      estado: 'aplicado'
    }
  });

  console.log('¡Alumno con deuda y recargo creado exitosamente!');
  console.log('Nombre:', alumno.nombreCompleto);
  console.log('Matrícula:', alumno.matricula);
}

main().catch(console.error).finally(() => prisma.$disconnect());
