const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('Iniciando creacion de datos de prueba para RF-42...');

  const rnd = Math.floor(Math.random() * 10000);
  
  // 1. Crear Tutor
  const tutor = await prisma.tutor.create({
    data: {
      nombreCompleto: 'Arturo Viveros (Tutor Prueba RF-42)',
      correoElectronico: `arturo.prueba.rf42_${rnd}@example.com`,
      telefono: '5551234567'
    }
  });
  console.log('Tutor creado:', tutor.tutorId);

  // 2. Crear Alumnos
  const alumno1 = await prisma.alumno.create({
    data: {
      matricula: `AL-RF42-1-${rnd}`,
      nombreCompleto: 'Carlos Viveros',
      curp: `VIVC100101HDF${rnd}`,
      fechaNacimiento: new Date('2010-01-01'),
      sexo: 'M',
      estado: 'Activo'
    }
  });

  const alumno2 = await prisma.alumno.create({
    data: {
      matricula: `AL-RF42-2-${rnd}`,
      nombreCompleto: 'Ana Viveros',
      curp: `VIVA120101MDF${rnd}`,
      fechaNacimiento: new Date('2012-01-01'),
      sexo: 'F',
      estado: 'Activo'
    }
  });
  console.log('Alumnos creados:', alumno1.alumnoId, alumno2.alumnoId);

  // 3. Vincular Alumnos al Tutor
  await prisma.tutorAlumno.createMany({
    data: [
      { alumnoId: alumno1.alumnoId, tutorId: tutor.tutorId, tipoRelacion: 'tutor', esResponsableFinanciero: true },
      { alumnoId: alumno2.alumnoId, tutorId: tutor.tutorId, tipoRelacion: 'tutor', esResponsableFinanciero: true }
    ]
  });
  console.log('Alumnos vinculados al tutor.');

  // 4. Crear Ciclo Escolar Dummy si no hay o usar el ultimo
  let ciclo = await prisma.cicloEscolar.findFirst({ orderBy: { fechaInicio: 'desc' } });
  if (!ciclo) {
    ciclo = await prisma.cicloEscolar.create({
      data: { nombre: 'Ciclo 2026-2027', fechaInicio: new Date('2026-08-01'), fechaFin: new Date('2027-07-01') }
    });
  }

  // 5. Crear Deudas (CalendarioPago)
  // Carlos (Adeuda Colegiatura Sept y Oct)
  await prisma.calendarioPago.createMany({
    data: [
      {
        alumnoId: alumno1.alumnoId,
        cicloId: ciclo.cicloId,
        concepto: 'colegiatura',
        mes: 'septiembre',
        fechaVencimiento: new Date('2026-09-10'),
        montoOriginal: 2500.00,
        estadoCobro: 'pendiente'
      },
      {
        alumnoId: alumno1.alumnoId,
        cicloId: ciclo.cicloId,
        concepto: 'colegiatura',
        mes: 'octubre',
        fechaVencimiento: new Date('2026-10-10'),
        montoOriginal: 2500.00,
        estadoCobro: 'pendiente'
      }
    ]
  });

  // Ana (Adeuda Inscripción y Colegiatura Sept)
  await prisma.calendarioPago.createMany({
    data: [
      {
        alumnoId: alumno2.alumnoId,
        cicloId: ciclo.cicloId,
        concepto: 'inscripcion',
        fechaVencimiento: new Date('2026-08-15'),
        montoOriginal: 3500.00,
        estadoCobro: 'pendiente'
      },
      {
        alumnoId: alumno2.alumnoId,
        cicloId: ciclo.cicloId,
        concepto: 'colegiatura',
        mes: 'septiembre',
        fechaVencimiento: new Date('2026-09-10'),
        montoOriginal: 2000.00,
        estadoCobro: 'pendiente'
      }
    ]
  });

  console.log('Deudas de prueba creadas.');
  console.log('==========================================');
  console.log('TUTOR CREADO PARA PRUEBA: Arturo Viveros (Tutor Prueba RF-42)');
  console.log('==========================================');
}

main()
  .catch(e => console.error(e))
  .finally(() => prisma.$disconnect());
