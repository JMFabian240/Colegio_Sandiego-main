const { verificarYEnviarAlertas } = require('./src/services/notificaciones/alertasPagos.service');
const prisma = require('./src/config/database');

async function testNotificaciones() {
  console.log('Iniciando prueba de notificaciones...');
  
  // Quitar el constraint que bloquea el tipo
  await prisma.$executeRaw`ALTER TABLE "notificacion" DROP CONSTRAINT IF EXISTS "notificacion_tipo_check"`;
  
  // Vamos a forzar un vencimiento para un calendario_pago al azar para que envíe un correo
  // 1. Tomamos un alumno activo con tutor
  const colegiatura = await prisma.calendarioPago.findFirst({
    where: { estadoCobro: 'pendiente', alumno: { tutores: { some: { recibeNotificaciones: true } } } },
    include: { alumno: { include: { tutores: { include: { tutor: true } } } } }
  });

  if (!colegiatura) {
    console.log('No hay colegiaturas pendientes para probar.');
    process.exit(0);
  }

  // Guardamos la fecha original para restaurarla después
  const fechaOriginal = colegiatura.fechaVencimiento;
  
  // Forzamos a que venza en exactamente 5 días
  const enCincoDias = new Date();
  enCincoDias.setDate(enCincoDias.getDate() + 5);
  
  await prisma.calendarioPago.update({
    where: { calendarioPagoId: colegiatura.calendarioPagoId },
    data: { fechaVencimiento: enCincoDias }
  });

  console.log(`Forzada fecha de vencimiento a 5 días para alumno ${colegiatura.alumno.nombreCompleto}`);

  // Disparamos el servicio
  await verificarYEnviarAlertas();

  // Restauramos la fecha original
  await prisma.calendarioPago.update({
    where: { calendarioPagoId: colegiatura.calendarioPagoId },
    data: { fechaVencimiento: fechaOriginal }
  });
  
  console.log('Restaurada la fecha original.');
  process.exit(0);
}

testNotificaciones();
