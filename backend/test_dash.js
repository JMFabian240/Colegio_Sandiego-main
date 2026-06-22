const alumnosRepo = require('./src/repositories/alumnos/alumnos.repository');
alumnosRepo.findAll({ estado: 'Activo', limit: 1, page: 1 }).then(res => {
  console.log("Alumnos:", res.pagination.total);
}).catch(console.error);

const reportesCtrl = require('./src/controllers/reportes/reportes.controller');
// We can't easily call controller, let's call the logic
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
prisma.calendarioPago.findMany({
  where: {
    estadoCobro: { in: ['pendiente', 'parcial'] },
    eliminadoEn: null,
    fechaVencimiento: { lt: new Date() },
  }
}).then(cals => console.log("Cals vencidos:", cals.length)).catch(console.error);
