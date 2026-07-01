'use strict';

const cron = require('node-cron');
const { verificarYEnviarAlertas } = require('../services/notificaciones/alertasPagos.service');

/**
 * Inicia todas las tareas programadas (CRON jobs) relacionadas a pagos.
 */
function initPagosCron() {
  console.log('⏰ CRON: Inicializando tareas programadas de Pagos...');

  // Se ejecuta todos los días a las 10:00 AM
  // Formato: minutos(0-59) horas(0-23) día_mes(1-31) mes(1-12) día_semana(0-7)
  cron.schedule('0 10 * * *', async () => {
    console.log(`[${new Date().toISOString()}] ⏰ CRON: Ejecutando verificación de alertas de pago (10:00 AM)`);
    await verificarYEnviarAlertas();
  }, {
    scheduled: true,
    timezone: "America/Mexico_City" // Ajustar a la zona horaria del colegio
  });
}

module.exports = {
  initPagosCron
};
