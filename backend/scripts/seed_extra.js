const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('Iniciando carga de datos extra...');
  
  const r = Math.floor(Math.random()*10000);
  const rfcStr = 'XAXX010101' + Math.floor(Math.random()*1000).toString().padStart(3, '0');
  const tutores = await Promise.all([
    prisma.tutor.create({ data: { nombreCompleto: 'Carlos Sánchez Ruiz ' + r, telefono: '555-1234', correoElectronico: 'carlos.sanchez'+r+'@test.com', requiereFactura: false } }),
    prisma.tutor.create({ data: { nombreCompleto: 'Laura Méndez Ortiz ' + r, telefono: '555-5678', correoElectronico: 'laura.mendez'+r+'@test.com', requiereFactura: true, rfc: rfcStr, regimenFiscal: '601' } }),
    prisma.tutor.create({ data: { nombreCompleto: 'Roberto Gómez ' + r, telefono: '555-9012', correoElectronico: 'roberto.gomez'+r+'@test.com', requiereFactura: false } }),
  ]);
  console.log('Tutores creados:', tutores.length);

  // Define relations separately
  const relaciones = {
    [tutores[0].tutorId]: 'padre',
    [tutores[1].tutorId]: 'madre',
    [tutores[2].tutorId]: 'padre',
  };

  const alumnosData = [
    { nombreCompleto: 'Diego Sánchez Méndez', matricula: 'SDM-2026-001-' + r, tutores: [tutores[0].tutorId, tutores[1].tutorId] },
    { nombreCompleto: 'Valeria Sánchez Méndez', matricula: 'SDM-2026-002-' + r, tutores: [tutores[0].tutorId, tutores[1].tutorId] },
    { nombreCompleto: 'Emilio Gómez', matricula: 'SDM-2026-003-' + r, tutores: [tutores[2].tutorId] },
    { nombreCompleto: 'Sofía Castañeda', matricula: 'SDM-2026-004-' + r, tutores: [] },
    { nombreCompleto: 'Mateo Luna', matricula: 'SDM-2026-005-' + r, tutores: [] },
  ];

  const alumnos = [];
  for (const aData of alumnosData) {
    const alumno = await prisma.alumno.create({
      data: {
        nombreCompleto: aData.nombreCompleto,
        matricula: aData.matricula
      }
    });
    alumnos.push(alumno);

    // Link tutores
    for (const tId of aData.tutores) {
      await prisma.tutorAlumno.create({
        data: {
          tutorId: tId,
          alumnoId: alumno.alumnoId,
          tipoRelacion: relaciones[tId] || 'Tutor',
          esResponsableFinanciero: true,
          puedeRecoger: true
        }
      });
    }
  }
  console.log('Alumnos creados:', alumnos.length);

  // Create Payments (CalendarioPagos & Pago)
  const hoy = new Date();
  const mesPasado = new Date(); mesPasado.setMonth(hoy.getMonth() - 1);
  const mesProximo = new Date(); mesProximo.setMonth(hoy.getMonth() + 1);

  const cicloActivo = await prisma.cicloEscolar.findFirst({ where: { activo: true } });
  const cicloConnect = cicloActivo ? { connect: { cicloId: cicloActivo.cicloId } } : undefined;

  for (const alumno of alumnos) {
    // Vencido (Mes Pasado)
    await prisma.calendarioPago.create({
      data: {
        alumno: { connect: { alumnoId: alumno.alumnoId } },
        ciclo: cicloConnect,
        concepto: 'colegiatura',
        fechaVencimiento: mesPasado,
        montoOriginal: 4500.00,
        estadoCobro: 'vencido',
      }
    });

    // Pendiente (Mes Próximo)
    await prisma.calendarioPago.create({
      data: {
        alumno: { connect: { alumnoId: alumno.alumnoId } },
        ciclo: cicloConnect,
        concepto: 'colegiatura',
        fechaVencimiento: mesProximo,
        montoOriginal: 4500.00,
        estadoCobro: 'pendiente',
      }
    });

    // Pagado (Hoy)
    const calPagado = await prisma.calendarioPago.create({
      data: {
        alumno: { connect: { alumnoId: alumno.alumnoId } },
        ciclo: cicloConnect,
        concepto: 'inscripcion',
        fechaVencimiento: hoy,
        montoOriginal: 5000.00,
        estadoCobro: 'pagado',
      }
    });

    const tutorId = alumnosData.find(a => a.matricula === alumno.matricula)?.tutores[0] || null;
    const pagoData = {
      alumno: { connect: { alumnoId: alumno.alumnoId } },
      fechaPago: hoy,
      montoTotal: 5000.00,
      metodoPago: 'transferencia',
      registradoPorUsuario: { connect: { usuarioId: 1 } }, // Assuming admin is 1
    };
    if (tutorId) {
      pagoData.tutor = { connect: { tutorId: tutorId } };
    }
    await prisma.pago.create({ data: pagoData });
  }
  console.log('Pagos y calendarios creados exitosamente.');
}

main()
  .catch(e => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
