require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const users = await prisma.usuario.findMany({ select: { nombreUsuario: true, activo: true } });
  console.log('Usuarios en BD:', users);
}
main().catch(console.error).finally(() => prisma.$disconnect());
