// Script temporal para verificar conexión a BD
const prisma = require('../src/config/database');

async function main() {
  try {
    const r = await prisma.$queryRawUnsafe('SELECT current_database() as db');
    console.log('DB OK:', r[0].db);
    await prisma.$disconnect();
  } catch (e) {
    console.error('DB ERROR:', e.message);
    await prisma.$disconnect();
    process.exit(1);
  }
}
main();
