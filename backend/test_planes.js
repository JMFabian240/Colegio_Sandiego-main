'use strict';
require('dotenv').config({ path: require('path').join(__dirname, '.env') });
const planesService = require('./src/services/planes/planes.service');

async function main() {
  try {
    // Buscar un alumno activo
    const { PrismaClient } = require('@prisma/client');
    const prisma = new PrismaClient();
    
    const alumno = await prisma.alumno.findFirst({
      where: { estado: 'Activo' },
      include: { nivel: true }
    });
    
    if (!alumno) {
      console.log('No hay alumnos activos.');
      return;
    }
    
    console.log(`Previsualizando 12 meses para Alumno ${alumno.alumnoId} (${alumno.nombre})...`);
    const preview = await planesService.previsualizarPlan(alumno.alumnoId, 12);
    console.log(`Calendario generado con ${preview.calendario.length} pagos.`);
    console.log('Monto Diciembre:', preview.calendario.find(c => c.mes === 'diciembre' && c.concepto === 'colegiatura')?.montoOriginal);
    
    // Assign Plan
    console.log(`Asignando plan...`);
    const result = await planesService.asignarPlan(alumno.alumnoId, 12, 1);
    console.log(result);
    
    // Verify CalendarioPago records
    const pagos = await prisma.calendarioPago.findMany({
      where: { alumnoId: alumno.alumnoId }
    });
    console.log(`Se insertaron ${pagos.length} pagos en DB.`);
    
    await prisma.$disconnect();
  } catch (err) {
    console.error('Error:', err);
  }
}

main();
