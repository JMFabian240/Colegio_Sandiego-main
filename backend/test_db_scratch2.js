require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const intentos = await prisma.$queryRaw`SELECT nombre_usuario_intentado, exitoso, creado_en FROM intento_login ORDER BY creado_en DESC LIMIT 5`;
  console.log('Últimos intentos de login:', intentos);
}
main().catch(console.error).finally(() => prisma.$disconnect());
