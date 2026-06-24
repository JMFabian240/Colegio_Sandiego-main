/**
 * SAE Colegio San Diego — Entry point del servidor
 * Inicia Express y valida la conexión a la base de datos.
 */

'use strict';

require('./config/env');

const app    = require('./app');
const config = require('./config/env');
const prisma = require('./config/database');

async function startServer() {
  try {
    // Verificar conexión a la DB antes de levantar el servidor
    await prisma.$connect();
    
    const server = app.listen(config.port, config.host, () => {
      console.log('');
      console.log('╔══════════════════════════════════════════════╗');
      console.log('║   SAE · Colegio San Diego                    ║');
      console.log('║   Sistema Administrativo Escolar             ║');
      console.log('╠══════════════════════════════════════════════╣');
      console.log(`║   Entorno : ${config.env.padEnd(34)}║`);
      console.log(`║   Puerto  : ${String(config.port).padEnd(34)}║`);
      console.log(`║   URL     : http://${config.host}:${config.port}`.padEnd(47) + '║');
      console.log(`║   API     : http://${config.host}:${config.port}/api/v1`.padEnd(47) + '║');
      console.log('╚══════════════════════════════════════════════╝');
      console.log('');
    });

    // Cierre graceful
    const gracefulShutdown = async (signal) => {
      console.log(`\n[SHUTDOWN] Señal ${signal} recibida. Cerrando servidor...`);
      server.close(async () => {
        await prisma.$disconnect();
        console.log('[SHUTDOWN] Conexión DB cerrada. Servidor detenido.');
        process.exit(0);
      });
    };

    process.on('SIGINT',  () => gracefulShutdown('SIGINT'));
    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

    // Capturar promesas rechazadas y excepciones no manejadas
    // Evita que el proceso muera silenciosamente en Node.js moderno
    process.on('unhandledRejection', (reason) => {
      console.error('[FATAL] Unhandled Rejection:', reason);
    });
    process.on('uncaughtException', (err) => {
      console.error('[FATAL] Uncaught Exception:', err);
      gracefulShutdown('UNCAUGHT_EXCEPTION');
    });

  } catch (error) {
    console.error('[FATAL] Error al iniciar el servidor:', error);
    await prisma.$disconnect();
    process.exit(1);
  }
}

startServer();
