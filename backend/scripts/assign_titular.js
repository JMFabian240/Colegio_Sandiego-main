const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const activeCycle = await prisma.cicloEscolar.findFirst({ where: { activo: true } });
  if (!activeCycle) return;

  const gruposSinTitular = await prisma.grupo.findMany({
    where: {
      cicloId: activeCycle.cicloId,
      docenteTitularId: null,
      eliminadoEn: null
    }
  });

  if (gruposSinTitular.length === 0) {
    console.log('No groups found without a titular teacher.');
    return;
  }

  console.log(`Found ${gruposSinTitular.length} groups without a titular teacher.`);

  const users = await prisma.usuario.findMany({ include: { roles: { include: { rol: true } } } });
  const maestras = users.filter(u => u.roles.some(r => r.rol.nombre === 'Docente' && u.activo === true));

  if (maestras.length === 0) {
    console.log('No docentes available to assign.');
    return;
  }

  for (const g of gruposSinTitular) {
    const randomMaestra = maestras[Math.floor(Math.random() * maestras.length)];
    await prisma.grupo.update({
      where: { grupoId: g.grupoId },
      data: { docenteTitularId: randomMaestra.usuarioId }
    });
    console.log(`Assigned teacher ${randomMaestra.nombreCompleto} as titular to group ${g.nombre}`);
  }

  console.log('Done assigning titular teachers!');
}

main().catch(console.error).finally(() => prisma.$disconnect());
