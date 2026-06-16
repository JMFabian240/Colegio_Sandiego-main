const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const currentActive = await prisma.cicloEscolar.findFirst({ where: { activo: true } });
  
  // Find the cycle with the most groups to use as template
  const cycleToCopy = await prisma.cicloEscolar.findFirst({
    where: { cicloId: 2 }, // Using cycle 2 as it has 16 groups and 76 materias
  });

  console.log(`Copying groups from cycle ${cycleToCopy.nombre} to ${currentActive.nombre}`);

  // Delete existing groups in current cycle (to clean up the empty ones we created earlier)
  await prisma.grupoMateria.deleteMany({
    where: { grupo: { cicloId: currentActive.cicloId } }
  });
  await prisma.grupo.deleteMany({
    where: { cicloId: currentActive.cicloId }
  });

  // Fetch groups from cycle 2
  const grupos = await prisma.grupo.findMany({
    where: { cicloId: cycleToCopy.cicloId, eliminadoEn: null },
    include: { gruposMaterias: true }
  });

  for (const grp of grupos) {
    const nuevoGrupo = await prisma.grupo.create({
      data: {
        cicloId: currentActive.cicloId,
        nivelId: grp.nivelId,
        grado: grp.grado,
        seccion: grp.seccion,
        nombre: grp.nombre,
        docenteTitularId: grp.docenteTitularId,
        cupoMaximo: grp.cupoMaximo
      }
    });

    console.log(`Created group ${nuevoGrupo.nombre}`);

    if (grp.gruposMaterias && grp.gruposMaterias.length > 0) {
      const nuevasMaterias = grp.gruposMaterias.map(m => ({
        grupoId: nuevoGrupo.grupoId,
        materiaId: m.materiaId,
        docenteId: m.docenteId,
        horario: m.horario,
        aula: m.aula
      }));
      await prisma.grupoMateria.createMany({
        data: nuevasMaterias
      });
      console.log(`  Copied ${nuevasMaterias.length} materias`);
    }
  }

  console.log('Done!');
}

main().catch(console.error).finally(() => prisma.$disconnect());
