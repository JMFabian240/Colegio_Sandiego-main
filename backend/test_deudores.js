const reportesService = require('./src/services/reportes/reportes.service');
reportesService.obtenerDeudores().then(d => {
  console.log("Deudores:", d.length);
}).catch(console.error);
