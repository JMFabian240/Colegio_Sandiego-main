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

const DATA = {
  PREESCOLAR: {
    grados: {
      '1': ['Lenguajes', 'Saberes y Pensamiento Científico', 'Ética, Naturaleza y Sociedades', 'De lo Humano y lo Comunitario', 'Inglés', 'Computación', 'Educación Física'],
      '2': ['Lenguajes', 'Saberes y Pensamiento Científico', 'Ética, Naturaleza y Sociedades', 'De lo Humano y lo Comunitario', 'Inglés', 'Computación', 'Educación Física'],
      '3': ['Lenguajes', 'Saberes y Pensamiento Científico', 'Ética, Naturaleza y Sociedades', 'De lo Humano y lo Comunitario', 'Inglés', 'Computación', 'Educación Física']
    }
  },
  PRIMARIA: {
    grados: {
      '1': ['Lenguajes', 'Saberes y Pensamiento Científico', 'Ética, Naturaleza y Sociedades', 'De lo Humano y lo Comunitario', 'Inglés', 'Computación', 'Educación Física'],
      '2': ['Lenguajes', 'Saberes y Pensamiento Científico', 'Ética, Naturaleza y Sociedades', 'De lo Humano y lo Comunitario', 'Inglés', 'Computación', 'Educación Física'],
      '3': ['Lenguajes', 'Saberes y Pensamiento Científico', 'Ética, Naturaleza y Sociedades', 'De lo Humano y lo Comunitario', 'Inglés', 'Computación', 'Educación Física'],
      '4': ['Lenguajes', 'Saberes y Pensamiento Científico', 'Ética, Naturaleza y Sociedades', 'De lo Humano y lo Comunitario', 'Inglés', 'Computación', 'Educación Física'],
      '5': ['Lenguajes', 'Saberes y Pensamiento Científico', 'Ética, Naturaleza y Sociedades', 'De lo Humano y lo Comunitario', 'Inglés', 'Computación', 'Educación Física'],
      '6': ['Lenguajes', 'Saberes y Pensamiento Científico', 'Ética, Naturaleza y Sociedades', 'De lo Humano y lo Comunitario', 'Inglés', 'Computación', 'Educación Física']
    }
  },
  SECUNDARIA: {
    grados: {
      '1': ['Español', 'Matemáticas', 'Biología (Ciencia y Tecnología)', 'Geografía', 'Historia', 'Inglés', 'Artes', 'Formación Cívica y Ética', 'Tecnología Informática', 'Educación Física', 'Vida Saludable', 'Educación Financiera', 'Tutoría y Educación Socioemocional', 'Laboratorio de Investigación', 'Taller'],
      '2': ['Español', 'Matemáticas', 'Física (Ciencia y Tecnología)', 'Historia', 'Inglés', 'Artes', 'Formación Cívica y Ética', 'Tecnología Informática', 'Educación Física', 'Vida Saludable', 'Educación Financiera', 'Tutoría y Educación Socioemocional', 'Laboratorio de Investigación', 'Taller'],
      '3': ['Español', 'Matemáticas', 'Química (Ciencia y Tecnología)', 'Historia', 'Inglés', 'Artes', 'Formación Cívica y Ética', 'Tecnología Informática', 'Educación Física', 'Vida Saludable', 'Educación Financiera', 'Tutoría y Educación Socioemocional', 'Laboratorio de Investigación', 'Taller']
    }
  },
  BACHILLERATO: {
    grados: {
      '1': ['Pensamiento Matemático II', 'Lengua y Comunicación II', 'Inglés II', 'Cultura Digital II', 'Ciencias Sociales II', 'Humanidades II', 'Conciencia Histórica', 'Taller de Ciencias I', 'Educación Física', 'Conservación de la Energía'],
      '2': ['Pensamiento Matemático II', 'Lengua y Comunicación II', 'Inglés II', 'Cultura Digital II', 'Ciencias Sociales II', 'Humanidades II', 'Conciencia Histórica', 'Taller de Ciencias I', 'Educación Física', 'Energía de los procesos de la vida diaria'],
      '3': ['Inglés V', 'Ciencias de la Salud', 'Temas Selectos de Biología', 'Temas Selectos de Física', 'Temas Selectos de Química', 'Cálculo Diferencial', 'Etimologías Grecolatinas', 'Psicología', 'Lógica', 'Educación Física', 'Práctica y Colaboración Ciudadana', 'Educación Integral en Sexualidad y Género', 'Finanzas', 'Ventas y Difusión', 'Danza', 'Danza (Currículum Ampliado)'],
      '4': ['Inglés V', 'Ciencias de la Salud', 'Temas Selectos de Biología', 'Temas Selectos de Física', 'Temas Selectos de Química', 'Cálculo Diferencial', 'Etimologías Grecolatinas', 'Psicología', 'Lógica', 'Educación Física', 'Práctica y Colaboración Ciudadana', 'Educación Integral en Sexualidad y Género', 'Finanzas', 'Ventas y Difusión', 'Danza', 'Danza (Currículum Ampliado)'],
      '5': ['Inglés V', 'Ciencias de la Salud', 'Temas Selectos de Biología', 'Temas Selectos de Física', 'Temas Selectos de Química', 'Cálculo Diferencial', 'Etimologías Grecolatinas', 'Psicología', 'Lógica', 'Educación Física', 'Práctica y Colaboración Ciudadana', 'Educación Integral en Sexualidad y Género', 'Finanzas', 'Ventas y Difusión', 'Danza', 'Danza (Currículum Ampliado)'],
      '6': ['Inglés V', 'Ciencias de la Salud', 'Temas Selectos de Biología', 'Temas Selectos de Física', 'Temas Selectos de Química', 'Cálculo Diferencial', 'Etimologías Grecolatinas', 'Psicología', 'Lógica', 'Educación Física', 'Práctica y Colaboración Ciudadana', 'Educación Integral en Sexualidad y Género', 'Finanzas', 'Ventas y Difusión', 'Danza', 'Danza (Currículum Ampliado)'],
    }
  }
};

async function main() {
  const activeCycle = await prisma.cicloEscolar.findFirst({ where: { activo: true } });
  if (!activeCycle) return;

  const previousCycleId = 2; // Source cycle
  const previousInscriptions = await prisma.inscripcionCiclo.findMany({
    where: { 
      cicloId: previousCycleId, 
      estadoEnCiclo: 'promovido',
      eliminadoEn: null
    },
    include: { grupo: { include: { nivel: true } } }
  });

  const nivelesDB = await prisma.nivelEducativo.findMany();
  
  // Maestras for random assignment
  const users = await prisma.usuario.findMany({ include: { roles: { include: { rol: true } } } });
  const maestras = users.filter(u => u.roles.some(r => r.rol.nombre === 'Docente' && u.activo === true));

  for (const insc of previousInscriptions) {
    if (!insc.grupo || !insc.grupo.nivel) continue;

    const mapping = GRADE_MAPPING[insc.grupo.nivel.codigo]?.[insc.grupo.grado];
    if (!mapping) continue;

    const { nivel: nextNivelCodigo, grado: nextGrado } = mapping;
    const seccion = insc.grupo.seccion;

    let targetGroup = await prisma.grupo.findFirst({
      where: {
        cicloId: activeCycle.cicloId,
        nivel: { codigo: nextNivelCodigo },
        grado: nextGrado,
        seccion: seccion,
        eliminadoEn: null
      },
      include: { gruposMaterias: true }
    });

    if (!targetGroup) {
      // Create missing group
      const targetNivel = nivelesDB.find(n => n.codigo === nextNivelCodigo);
      const nombreGrupo = `${nextGrado}°${seccion} ${nextNivelCodigo === 'PREESCOLAR' ? 'Preescolar' : nextNivelCodigo === 'PRIMARIA' ? 'Primaria' : nextNivelCodigo === 'SECUNDARIA' ? 'Secundaria' : 'Bachillerato'}`;
      
      console.log(`Creating missing group: ${nombreGrupo}`);
      targetGroup = await prisma.grupo.create({
        data: {
          cicloId: activeCycle.cicloId,
          nivelId: targetNivel.nivelId,
          grado: nextGrado,
          seccion: seccion,
          nombre: nombreGrupo,
          cupoMaximo: 30
        },
        include: { gruposMaterias: true }
      });

      // Add subjects to new group
      const asignaturasNecesarias = DATA[nextNivelCodigo]?.grados[nextGrado] || [];
      for (const nombreAsig of asignaturasNecesarias) {
        let materia = await prisma.materia.findFirst({
          where: { nivelId: targetNivel.nivelId, nombre: nombreAsig }
        });

        if (materia) {
          const randomMaestra = maestras.length > 0 ? maestras[Math.floor(Math.random() * maestras.length)] : null;
          const gm = await prisma.grupoMateria.create({
            data: {
              grupoId: targetGroup.grupoId,
              materiaId: materia.materiaId,
              docenteId: randomMaestra ? randomMaestra.usuarioId : null
            }
          });
          targetGroup.gruposMaterias.push(gm);
        }
      }
    }

    // Enroll student
    let newInsc = await prisma.inscripcionCiclo.findFirst({
      where: { alumnoId: insc.alumnoId, cicloId: activeCycle.cicloId, eliminadoEn: null }
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
      console.log(`Enrolled student ${insc.alumnoId} into new group ${targetGroup.nombre}`);
    } else if (newInsc.grupoId !== targetGroup.grupoId) {
      await prisma.inscripcionCiclo.update({
        where: { inscripcionId: newInsc.inscripcionId },
        data: { grupoId: targetGroup.grupoId }
      });
    }

    // Enroll in subjects
    for (const gm of targetGroup.gruposMaterias) {
      const existingInscMat = await prisma.inscripcionMateria.findFirst({
        where: { alumnoId: insc.alumnoId, grupoMateriaId: gm.grupoMateriaId }
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

  console.log('All missing students and groups processed!');
}

main().catch(console.error).finally(() => prisma.$disconnect());
