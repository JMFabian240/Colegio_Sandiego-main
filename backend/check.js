const p = require('./src/config/database');
p.calendarioPago.findFirst({
  include: {
    alumno: {
      include: {
        asignacionesBeca: {
          include: { beca: true }
        }
      }
    }
  }
}).then(c => {
  console.log(JSON.stringify(c, null, 2));
}).finally(() => {
  p.$disconnect();
});
