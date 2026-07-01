const prisma = require('./src/config/database');
async function main() {
  const res = await prisma.$queryRawUnsafe(`SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'pago_metodo_pago_check'`);
  console.log(res);
}
main().catch(console.error).finally(() => prisma.$disconnect());
