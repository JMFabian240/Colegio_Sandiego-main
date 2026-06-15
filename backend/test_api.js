const http = require('http');

async function testAPI() {
  // We can just use the database directly, but we want to see the JSON output
  const { PrismaClient } = require('@prisma/client');
  const prisma = new PrismaClient();
  const items = await prisma.calendarioPago.findMany({
    where: { alumnoId: 4, eliminadoEn: null },
    include: {
      recargos: { where: { estado: { in: ['aplicado', 'modificado'] } } },
      alumno: {
        select: {
          asignacionesBeca: {
            where: { estado: 'activa' },
            include: { beca: true }
          }
        }
      }
    },
    orderBy: [{ fechaVencimiento: 'asc' }],
  });
  console.log('Prisma items returned:', items.length);
  console.log('Is Array?', Array.isArray(items));
  // Simulate JSON serialization:
  const jsonStr = JSON.stringify({ ok: true, data: items });
  const res = JSON.parse(jsonStr);
  console.log('Is res.data Array?', Array.isArray(res.data));
  console.log('Sample date from JSON:', res.data[0].fechaVencimiento);
  
  // Test AlpineJS logic
  let datos = res.data;
  const hoy = new Date().toISOString().split('T')[0];
  datos = datos.map(d => {
    if (d.estadoCobro === 'pagado' || Number(d.saldoPendiente) === 0) {
      d.estadoCalc = 'PAGADO';
    } else if (d.fechaVencimiento < hoy) {
      d.estadoCalc = 'VENCIDO';
    } else {
      d.estadoCalc = 'PENDIENTE';
    }
    return d;
  });
  datos.sort((a,b) => new Date(a.fechaVencimiento) - new Date(b.fechaVencimiento));
  console.log('Sorted datos first element:', datos[0].estadoCalc, datos[0].fechaVencimiento);
}
testAPI().catch(console.error);
