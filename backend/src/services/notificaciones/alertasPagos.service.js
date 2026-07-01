'use strict';

const prisma = require('../../config/database');
const { enviarCorreo } = require('./mailer.service');

/**
 * Servicio para verificar vencimientos y enviar alertas a los tutores.
 */
async function verificarYEnviarAlertas() {
  console.log('🔄 Ejecutando revisión de alertas de pago...');
  
  try {
    // 1. Obtener ciclo escolar activo
    const cicloActivo = await prisma.cicloEscolar.findFirst({
      where: { activo: true },
      orderBy: { fechaInicio: 'desc' }
    });

    if (!cicloActivo) {
      console.log('⚠️ No hay ciclo escolar activo.');
      return { procesadas: 0, exito: false, mensaje: 'No hay ciclo activo' };
    }

    // 2. Definir fechas objetivo
    const hoy = new Date();
    hoy.setHours(0, 0, 0, 0);

    const enCincoDias = new Date(hoy);
    enCincoDias.setDate(enCincoDias.getDate() + 5);

    // Formatear para consulta exacta a la BD si es necesario, 
    // pero podemos traer los pendientes y compararlos en código.
    const colegiaturasPendientes = await prisma.calendarioPago.findMany({
      where: { 
        cicloId: cicloActivo.cicloId,
        estadoCobro: 'pendiente',
        alumno: { eliminadoEn: null, estado: 'Activo' }
      },
      include: {
        alumno: {
          include: {
            tutores: {
              where: { recibeNotificaciones: true, tutor: { eliminadoEn: null, activo: true } },
              include: { tutor: true }
            },
            nivel: true
          }
        }
      }
    });

    let alertasEnviadas = 0;

    for (const colegiatura of colegiaturasPendientes) {
      const fechaVenc = new Date(colegiatura.fechaVencimiento);
      fechaVenc.setHours(0, 0, 0, 0);

      // Calcular diferencia en días (Math.round para evitar problemas con horario de verano)
      const diffTime = fechaVenc.getTime() - hoy.getTime();
      const diffDias = Math.round(diffTime / (1000 * 60 * 60 * 24));

      let tipoAlerta = null;
      let asunto = '';
      let cuerpoBase = '';

      // Regla 1: 5 días antes
      if (diffDias === 5) {
        tipoAlerta = 'RECORDATORIO_5_DIAS';
        asunto = `Recordatorio de Pago de Colegiatura (${colegiatura.mes}) - Colegio San Diego`;
        cuerpoBase = `
          <h2>Recordatorio Preventivo</h2>
          <p>Le recordamos que el pago de la colegiatura correspondiente al mes de <span class="accent">${colegiatura.mes}</span> 
          tiene fecha de vencimiento el <strong>${fechaVenc.toLocaleDateString('es-MX')}</strong>.</p>
          <p>Monto original: <strong>$${Number(colegiatura.montoOriginal).toFixed(2)}</strong></p>
          <p>Saldo pendiente actual: <strong style="color: #059669;">$${Number(colegiatura.saldoPendiente).toFixed(2)}</strong></p>
          <p>Le agradecemos realizar su pago oportunamente para evitar cargos moratorios.</p>
        `;
      } 
      // Regla 2: 1 día de atraso (Multa recién generada)
      // Asumimos que la multa se genera al día 6 del mes, por lo que diffDias sería -1
      else if (diffDias === -1) {
        tipoAlerta = 'AVISO_RECARGO';
        asunto = `Aviso de Vencimiento y Recargo (${colegiatura.mes}) - Colegio San Diego`;
        cuerpoBase = `
          <h2 style="color: #dc2626;">Aviso de Vencimiento</h2>
          <p>Le informamos que la fecha límite de pago para la colegiatura de <span class="accent">${colegiatura.mes}</span> expiró el día <strong>${fechaVenc.toLocaleDateString('es-MX')}</strong>.</p>
          <p>Debido a esto, se ha aplicado el <strong style="color: #dc2626;">recargo correspondiente por pago tardío</strong> a su estado de cuenta.</p>
          <p>Monto original: <strong>$${Number(colegiatura.montoOriginal).toFixed(2)}</strong></p>
          <p>Le invitamos a regularizar su situación lo antes posible.</p>
        `;
      }

      if (tipoAlerta && colegiatura.alumno.tutores.length > 0) {
        for (const relacion of colegiatura.alumno.tutores) {
          const tutor = relacion.tutor;
          const emailDestino = tutor.correoElectronico || tutor.correoFacturacion;

          if (!emailDestino) continue; // Si no tiene correo, no enviamos.

          // Verificar si ya se envió esta alerta para no duplicar (ej. si el script corre dos veces el mismo día)
          const alertaExistente = await prisma.notificacion.findFirst({
            where: {
              tipo: tipoAlerta,
              calendarioPagoId: colegiatura.calendarioPagoId,
              destinatarioTutorId: tutor.tutorId,
              estado: 'enviada'
            }
          });

          if (alertaExistente) continue;

          // Construir cuerpo personalizado
          const cuerpoPersonalizado = `
            <p>Estimado(a) <strong>${tutor.nombreCompleto}</strong>,</p>
            ${cuerpoBase}
            <br>
            <p style="font-size: 13px; color: #64748b;">
              Alumno: <strong>${colegiatura.alumno.nombreCompleto}</strong><br>
              Nivel: ${colegiatura.alumno.nivel ? colegiatura.alumno.nivel.nombre : 'N/A'}<br>
              Matrícula: ${colegiatura.alumno.matricula}
            </p>
          `;

          // Registrar en BD (Pendiente)
          const notificacion = await prisma.notificacion.create({
            data: {
              tipo: tipoAlerta,
              destinatarioTutorId: tutor.tutorId,
              destinatarioEmail: emailDestino,
              asunto,
              cuerpo: cuerpoBase, // Solo guardamos la base o texto plano
              alumnoId: colegiatura.alumnoId,
              calendarioPagoId: colegiatura.calendarioPagoId,
              estado: 'pendiente'
            }
          });

          // Enviar correo
          const resultado = await enviarCorreo(emailDestino, asunto, cuerpoPersonalizado);

          // Actualizar estado en BD
          if (resultado.exito) {
            await prisma.notificacion.update({
              where: { notificacionId: notificacion.notificacionId },
              data: { estado: 'enviada', enviadaEn: new Date(), intentos: 1 }
            });
            alertasEnviadas++;
          } else {
            await prisma.notificacion.update({
              where: { notificacionId: notificacion.notificacionId },
              data: { estado: 'error', errorUltimo: resultado.error, intentos: 1 }
            });
          }
        }
      }
    }

    console.log(`✅ Revisión terminada. Correos enviados hoy: ${alertasEnviadas}`);
    return { procesadas: colegiaturasPendientes.length, enviadas: alertasEnviadas, exito: true };
    
  } catch (error) {
    console.error('❌ Error en verificarYEnviarAlertas:', error);
    return { exito: false, error: error.message };
  }
}

module.exports = {
  verificarYEnviarAlertas
};
