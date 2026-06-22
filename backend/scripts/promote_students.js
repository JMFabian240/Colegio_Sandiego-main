const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const GRADE_MAPPING = {
  'PREESCOLAR': {
    '1': { nivel: 'PREESCOLAR', grado: '2' },
    '2': { nivel: 'PREESCOLAR', grado: '3' },
    '3': { nivel: 'PRIMARIA', grado: '1' }
  },
  'PRIMARIA': {
    '1': { nivel: 'PRIMARIA', grado: '2' },
    '2': { nivel: 'PRIMARIA', grado: '3' },
    '3': { nivel: 'PRIMARIA', grado: '4' },
    '4': { nivel: 'PRIMARIA', grado: '5' },
    '5': { nivel: 'PRIMARIA', grado: '6' },
    '6': { nivel: 'SECUNDARIA', grado: '1' }
  },
  'SECUNDARIA': {
    '1': { nivel: 'SECUNDARIA', grado: '2' },
    '2': { nivel: 'SECUNDARIA', grado: '3' },
    '3': { nivel: 'BACHILLERATO', grado: '1' }
  },
  'BACHILLERATO': {
    '1': { nivel: 'BACHILLERATO', grado: '2' },
    '2': { nivel: 'BACHILLERATO', grado: '3' },
    '3': { nivel: 'BACHILLERATO', grado: '4' },
    '4': { nivel: 'BACHILLERATO', grado: '5' },
    '5': { nivel: 'BACHILLERATO', grado: '6' },
    '6': null // Egresado
  }
};

async function main() {
  const activeCycle = await prisma.cicloEscolar.findFirst({ where: { activo: true } });
  if (!activeCycle) {
    console.log('No active cycle');
    return;
  }

  // Find the previous cycle we are promoting from (ciclo 2)
  const previousCycleId = 2; // Hardcoded based on our knowledge that ciclo 2 has all the data

  // Fetch all promoted inscriptions from previous cycle
  const previousInscriptions = await prisma.inscripcionCiclo.findMany({
    where: { 
      cicloId: previousCycleId, 
      estadoEnCiclo: 'promovido',
      eliminadoEn: null
    },
    include: {
      grupo: {
        include: { nivel: true }
      }
    }
  });

  console.log(`Found ${previousInscriptions.length} promoted students in cycle ${previousCycleId}.`);

  // Fetch all groups in new cycle
  const newGroups = await prisma.grupo.findMany({
    where: { cicloId: activeCycle.cicloId, eliminadoEn: null },
    include: { 
      nivel: true,
      gruposMaterias: { where: { eliminadoEn: null } } 
    }
  });

  let enrolledCount = 0;

  for (const insc of previousInscriptions) {
    if (!insc.grupo || !insc.grupo.nivel) continue;

    const oldNivelCodigo = insc.grupo.nivel.codigo;
    const oldGrado = insc.grupo.grado;
    const oldSeccion = insc.grupo.seccion;

    const mapping = GRADE_MAPPING[oldNivelCodigo]?.[oldGrado];
    
    if (!mapping) {
      console.log(`No mapping found for student ${insc.alumnoId} from ${oldGrado} ${oldNivelCodigo}`);
      continue; // Egresado or mapping error
    }

    const { nivel: nextNivelCodigo, grado: nextGrado } = mapping;

    // Find the matching group in the new cycle
    let targetGroup = newGroups.find(g => 
      g.nivel.codigo === nextNivelCodigo && 
      g.grado === nextGrado && 
      g.seccion === oldSeccion
    );

    // Fallback to section 'A' if their section doesn't exist in the new grade
    if (!targetGroup) {
      targetGroup = newGroups.find(g => 
        g.nivel.codigo === nextNivelCodigo && 
        g.grado === nextGrado && 
        g.seccion === 'A'
      );
    }

    if (!targetGroup) {
      console.log(`Could not find target group for ${nextGrado} ${nextNivelCodigo} for student ${insc.alumnoId}`);
      continue;
    }

    // Check if they are already enrolled in the new cycle
    let newInsc = await prisma.inscripcionCiclo.findFirst({
      where: {
        alumnoId: insc.alumnoId,
        cicloId: activeCycle.cicloId,
        eliminadoEn: null
      }
    });

    if (!newInsc) {
      newInsc = await prisma.inscripcionCiclo.create({
        data: {
          alumnoId: insc.alumnoId,
          cicloId: activeCycle.cicloId,
          grupoId: targetGroup.grupoId,
          estadoEnCiclo: 'activa'
        }
      });
      enrolledCount++;
      console.log(`Enrolled student ${insc.alumnoId} into group ${targetGroup.nombre}`);
    } else if (newInsc.grupoId !== targetGroup.grupoId) {
      // Update their group just in case
      await prisma.inscripcionCiclo.update({
        where: { inscripcionId: newInsc.inscripcionId },
        data: { grupoId: targetGroup.grupoId }
      });
      console.log(`Moved student ${insc.alumnoId} to correct group ${targetGroup.nombre}`);
    }

    // Now assign them to the subjects of their new group
    for (const gm of targetGroup.gruposMaterias) {
      const existingInscMat = await prisma.inscripcionMateria.findFirst({
        where: {
          alumnoId: insc.alumnoId,
          grupoMateriaId: gm.grupoMateriaId
        }
      });

      if (!existingInscMat) {
        await prisma.inscripcionMateria.create({
          data: {
            alumnoId: insc.alumnoId,
            grupoMateriaId: gm.grupoMateriaId
          }
        });
      }
    }
  }

  console.log(`Successfully enrolled ${enrolledCount} students!`);
}

main().catch(console.error).finally(() => prisma.$disconnect());
