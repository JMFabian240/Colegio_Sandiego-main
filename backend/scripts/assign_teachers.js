const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const users = await prisma.usuario.findMany({ include: { roles: { include: { rol: true } } } });
  
  const maestras = users.filter(u => u.roles.some(r => r.rol.nombre === 'Docente'));
  console.log(`Found ${maestras.length} maestras with exact role 'Docente'.`);
  
  if (maestras.length > 0) {
    const gruposMateriasSinDocente = await prisma.grupoMateria.findMany({
      where: { docenteId: null, eliminadoEn: null }
    });

    console.log(`Found ${gruposMateriasSinDocente.length} materias sin docente asignado.`);

    for (const gm of gruposMateriasSinDocente) {
      const randomMaestra = maestras[Math.floor(Math.random() * maestras.length)];
      await prisma.grupoMateria.update({
        where: { grupoMateriaId: gm.grupoMateriaId },
        data: { docenteId: randomMaestra.usuarioId }
      });
    }

    console.log('Done assigning teachers!');
  }
}

main().catch(console.error).finally(() => prisma.$disconnect());
