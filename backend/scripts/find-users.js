// Encuentra usuarios admin en la BD
const prisma = require('../src/config/database');
async function main() {
  const usuarios = await prisma.usuario.findMany({
    where: { activo: true, eliminadoEn: null },
    select: { usuarioId: true, nombreUsuario: true, nombreCompleto: true },
    take: 5,
  });
  console.log('Usuarios activos:');
  usuarios.forEach(u => console.log(`  id=${u.usuarioId} | username="${u.nombreUsuario}" | nombre="${u.nombreCompleto}"`));
  await prisma.$disconnect();
}
main().catch(e => { console.error(e.message); process.exit(1); });
