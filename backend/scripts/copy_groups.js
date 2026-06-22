const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  // Find current active cycle
  const currentActive = await prisma.cicloEscolar.findFirst({
    where: { activo: true },
  });

  if (!currentActive) {
    console.log('No active cycle found');
    return;
  }

  // Find previous cycle (the one with the second highest ID)
  const previousCycle = await prisma.cicloEscolar.findFirst({
    where: { cicloId: { not: currentActive.cicloId } },
    orderBy: { cicloId: 'desc' }
  });

  if (!previousCycle) {
    console.log('No previous cycle found');
    return;
  }

  console.log(`Copying groups from cycle ${previousCycle.nombre} to ${currentActive.nombre}`);

  // Fetch groups from previous cycle
  const grupos = await prisma.grupo.findMany({
    where: { cicloId: previousCycle.cicloId, eliminadoEn: null },
    include: { gruposMaterias: true }
  });

  if (grupos.length === 0) {
    console.log('No groups found in previous cycle');
    return;
  }

  for (const grp of grupos) {
    // Check if group already exists in current cycle
    const exists = await prisma.grupo.findFirst({
      where: {
        cicloId: currentActive.cicloId,
        nivelId: grp.nivelId,
        grado: grp.grado,
        seccion: grp.seccion
      }
    });

    if (exists) {
      console.log(`Group ${grp.nombre} already exists in current cycle, skipping.`);
      continue;
    }

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
