'use strict';

require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('Generando alumnos de prueba...');
  
  // Obtener ciclo escolar activo
  const ciclo = await prisma.cicloEscolar.findFirst({ where: { activo: true } });
  if (!ciclo) throw new Error('No hay ciclo activo');
  
  // Obtener plan de pago por defecto
  let planPago = await prisma.planPago.findFirst({ where: { cicloId: ciclo.cicloId } });
  if (!planPago) {
    planPago = await prisma.planPago.create({
      data: {
        cicloId: ciclo.cicloId,
        nombre: 'Plan 10 meses',
        meses: 10,
        montoMensual: 4000,
        montoDiciembre: 8000,
        activo: true
      }
    });
  }
  
  // Obtener todos los grupos con su nivel
  const grupos = await prisma.grupo.findMany({
    where: { eliminadoEn: null },
    include: { nivel: true }
  });
  
  console.log(`Encontrados ${grupos.length} grupos.`);
  let totalCreados = 0;
  
  for (const grupo of grupos) {
    console.log(`\nGenerando 10 alumnos para el grupo: ${grupo.nombre}...`);
    
    // Elegimos 3 índices aleatorios para que sean deudores en este grupo
    const deudoresIndices = new Set();
    while (deudoresIndices.size < 3) {
      deudoresIndices.add(Math.floor(Math.random() * 10));
    }
    
    for (let i = 0; i < 10; i++) {
      const isDeudor = deudoresIndices.has(i);
      const randStr = Math.random().toString(36).substring(2, 6).toUpperCase();
      const matricula = `TST-${grupo.nivel.codigo.substring(0,3)}-${grupo.grado}${grupo.seccion}-${randStr}-${i}`;
      
      const nombresNinos = ['Mateo', 'Leonardo', 'Emiliano', 'Santiago', 'Matias', 'Sebastian', 'Gael', 'Diego', 'Thiago', 'Nicolas', 'Daniel', 'Alejandro', 'Gabriel'];
      const nombresNinas = ['Sofia', 'Maria', 'Jose', 'Valentina', 'Regina', 'Camila', 'Valeria', 'Ximena', 'Victoria', 'Renata', 'Isabella', 'Natalia', 'Mia'];
      const apellidos = ['Garcia', 'Martinez', 'Rodriguez', 'Lopez', 'Gonzalez', 'Perez', 'Sanchez', 'Ramirez', 'Cruz', 'Gomez', 'Flores', 'Morales', 'Vazquez', 'Jimenez', 'Reyes', 'Diaz'];
      
      const esNino = Math.random() > 0.5;
      const nombrePila = esNino ? nombresNinos[Math.floor(Math.random()*nombresNinos.length)] : nombresNinas[Math.floor(Math.random()*nombresNinas.length)];
      const ap1 = apellidos[Math.floor(Math.random()*apellidos.length)];
      const ap2 = apellidos[Math.floor(Math.random()*apellidos.length)];
      const nombreCompleto = `${nombrePila} ${ap1} ${ap2}`;
      
      // Crear alumno
      const alumno = await prisma.alumno.create({
        data: {
          nombreCompleto,
          matricula,
          curp: `TEST${Math.floor(Math.random()*100000)}HDFXXX01`,
          nivelId: grupo.nivelId,
          estado: 'Activo',
        }
      });
      
      // Crear tutor
      const tutor = await prisma.tutor.create({
        data: {
          nombreCompleto: `Tutor de ${nombrePila}`,
          telefono: '555' + Math.floor(1000000 + Math.random() * 9000000),
          correoElectronico: `tutor.${randStr}@test.com`
        }
      });
      
      // Vincular
      await prisma.tutorAlumno.create({
        data: {
          tutorId: tutor.tutorId,
          alumnoId: alumno.alumnoId,
          tipoRelacion: 'tutor',
          esResponsableFinanciero: true,
          puedeRecoger: true,
          recibeNotificaciones: true,
        }
      });
      
      const planParaGrupo = await prisma.planPago.findFirst({ where: { cicloId: grupo.cicloId } });
      
      // Inscripción
      await prisma.inscripcionCiclo.create({
        data: {
          alumnoId: alumno.alumnoId,
          cicloId: grupo.cicloId,
          grupoId: grupo.grupoId,
          planPagoId: planParaGrupo ? planParaGrupo.planPagoId : planPago.planPagoId,
          estadoEnCiclo: 'activa',
          estadoFinanciero: isDeudor ? 'aviso_preventivo' : 'al_corriente',
          mesesAdeudo: isDeudor ? 1 : 0
        }
      });
      
      totalCreados++;
    }
  }
  
  console.log(`\n¡Éxito! Se han creado ${totalCreados} alumnos de prueba en total.`);
}

main()
  .catch(e => console.error(e))
  .finally(() => prisma.$disconnect());
