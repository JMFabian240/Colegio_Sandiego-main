const repo = require('./src/repositories/alumnos/alumnos.repository');

async function test() {
  const res = await repo.findAll({ nivel: 'BACHILLERATO' });
  console.log(`Total Bachillerato found: ${res.length}`);
  if (res.length > 0) {
    console.log(res[0].nombre);
  } else {
    console.log(res);
  }
}

test().catch(console.error).finally(() => process.exit(0));
