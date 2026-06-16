const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const DATA = {
  PREESCOLAR: {
    materias: [
      { nombre: 'Lenguajes', tipo: 'curricular' },
      { nombre: 'Saberes y Pensamiento Científico', tipo: 'curricular' },
      { nombre: 'Ética, Naturaleza y Sociedades', tipo: 'curricular' },
      { nombre: 'De lo Humano y lo Comunitario', tipo: 'curricular' },
      { nombre: 'Inglés', tipo: 'curricular' },
      { nombre: 'Computación', tipo: 'taller' },
      { nombre: 'Educación Física', tipo: 'curricular' }
    ],
    grados: {
      '1': ['Lenguajes', 'Saberes y Pensamiento Científico', 'Ética, Naturaleza y Sociedades', 'De lo Humano y lo Comunitario', 'Inglés', 'Computación', 'Educación Física'],
      '2': ['Lenguajes', 'Saberes y Pensamiento Científico', 'Ética, Naturaleza y Sociedades', 'De lo Humano y lo Comunitario', 'Inglés', 'Computación', 'Educación Física'],
      '3': ['Lenguajes', 'Saberes y Pensamiento Científico', 'Ética, Naturaleza y Sociedades', 'De lo Humano y lo Comunitario', 'Inglés', 'Computación', 'Educación Física']
    }
  },
  PRIMARIA: {
    materias: [
      { nombre: 'Lenguajes', tipo: 'curricular' },
      { nombre: 'Saberes y Pensamiento Científico', tipo: 'curricular' },
      { nombre: 'Ética, Naturaleza y Sociedades', tipo: 'curricular' },
      { nombre: 'De lo Humano y lo Comunitario', tipo: 'curricular' },
      { nombre: 'Inglés', tipo: 'curricular' },
      { nombre: 'Computación', tipo: 'taller' },
      { nombre: 'Educación Física', tipo: 'curricular' }
    ],
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
    materias: [
      { nombre: 'Español', tipo: 'curricular' },
      { nombre: 'Matemáticas', tipo: 'curricular' },
      { nombre: 'Biología (Ciencia y Tecnología)', tipo: 'curricular' },
      { nombre: 'Física (Ciencia y Tecnología)', tipo: 'curricular' },
      { nombre: 'Química (Ciencia y Tecnología)', tipo: 'curricular' },
      { nombre: 'Geografía', tipo: 'curricular' },
      { nombre: 'Historia', tipo: 'curricular' },
      { nombre: 'Inglés', tipo: 'curricular' },
      { nombre: 'Artes', tipo: 'curricular' },
      { nombre: 'Formación Cívica y Ética', tipo: 'curricular' },
      { nombre: 'Tecnología Informática', tipo: 'taller' },
      { nombre: 'Educación Física', tipo: 'curricular' },
      { nombre: 'Vida Saludable', tipo: 'curricular' },
      { nombre: 'Educación Financiera', tipo: 'curricular' },
      { nombre: 'Tutoría y Educación Socioemocional', tipo: 'curricular' },
      { nombre: 'Laboratorio de Investigación', tipo: 'curricular' },
      { nombre: 'Taller', tipo: 'taller' }
    ],
    grados: {
      '1': ['Español', 'Matemáticas', 'Biología (Ciencia y Tecnología)', 'Geografía', 'Historia', 'Inglés', 'Artes', 'Formación Cívica y Ética', 'Tecnología Informática', 'Educación Física', 'Vida Saludable', 'Educación Financiera', 'Tutoría y Educación Socioemocional', 'Laboratorio de Investigación', 'Taller'],
      '2': ['Español', 'Matemáticas', 'Física (Ciencia y Tecnología)', 'Historia', 'Inglés', 'Artes', 'Formación Cívica y Ética', 'Tecnología Informática', 'Educación Física', 'Vida Saludable', 'Educación Financiera', 'Tutoría y Educación Socioemocional', 'Laboratorio de Investigación', 'Taller'],
      '3': ['Español', 'Matemáticas', 'Química (Ciencia y Tecnología)', 'Historia', 'Inglés', 'Artes', 'Formación Cívica y Ética', 'Tecnología Informática', 'Educación Física', 'Vida Saludable', 'Educación Financiera', 'Tutoría y Educación Socioemocional', 'Laboratorio de Investigación', 'Taller']
    }
  },
  BACHILLERATO: {
    materias: [
      { nombre: 'Pensamiento Matemático II', tipo: 'curricular' },
      { nombre: 'Lengua y Comunicación II', tipo: 'curricular' },
      { nombre: 'Inglés II', tipo: 'curricular' },
      { nombre: 'Inglés V', tipo: 'curricular' },
      { nombre: 'Cultura Digital II', tipo: 'curricular' },
      { nombre: 'Ciencias Sociales II', tipo: 'curricular' },
      { nombre: 'Humanidades II', tipo: 'curricular' },
      { nombre: 'Conciencia Histórica', tipo: 'curricular' },
      { nombre: 'Taller de Ciencias I', tipo: 'taller' },
      { nombre: 'Conservación de la Energía', tipo: 'curricular' },
      { nombre: 'Energía de los procesos de la vida diaria', tipo: 'curricular' },
      { nombre: 'Ciencias de la Salud', tipo: 'curricular' },
      { nombre: 'Temas Selectos de Biología', tipo: 'curricular' },
      { nombre: 'Temas Selectos de Física', tipo: 'curricular' },
      { nombre: 'Temas Selectos de Química', tipo: 'curricular' },
      { nombre: 'Cálculo Diferencial', tipo: 'curricular' },
      { nombre: 'Etimologías Grecolatinas', tipo: 'curricular' },
      { nombre: 'Psicología', tipo: 'curricular' },
      { nombre: 'Lógica', tipo: 'curricular' },
      { nombre: 'Educación Física', tipo: 'curricular' },
      { nombre: 'Práctica y Colaboración Ciudadana', tipo: 'curricular' },
      { nombre: 'Educación Integral en Sexualidad y Género', tipo: 'curricular' },
      { nombre: 'Finanzas', tipo: 'curricular' },
      { nombre: 'Ventas y Difusión', tipo: 'curricular' },
      { nombre: 'Danza', tipo: 'taller' },
      { nombre: 'Danza (Currículum Ampliado)', tipo: 'taller' }
    ],
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
  if (!activeCycle) return console.log('No active cycle');

  const nivelesDB = await prisma.nivelEducativo.findMany();
  
  for (const [nivelCodigo, data] of Object.entries(DATA)) {
    const nivel = nivelesDB.find(n => n.codigo === nivelCodigo);
    if (!nivel) continue;

    console.log(`Processing ${nivelCodigo}...`);

    // 1. Ensure all Materias exist
    const materiasIds = {};
    for (const m of data.materias) {
      let materiaDB = await prisma.materia.findFirst({
        where: { nivelId: nivel.nivelId, nombre: m.nombre }
      });
      if (!materiaDB) {
        materiaDB = await prisma.materia.create({
          data: {
            nivelId: nivel.nivelId,
            nombre: m.nombre,
            tipo: m.tipo,
            cuentaParaPromedio: true
          }
        });
        console.log(`  Created Materia: ${m.nombre}`);
      }
      materiasIds[m.nombre] = materiaDB.materiaId;
    }

    // 2. Fetch groups in this level and active cycle
    const grupos = await prisma.grupo.findMany({
      where: { cicloId: activeCycle.cicloId, nivelId: nivel.nivelId, eliminadoEn: null },
      include: { 
        gruposMaterias: true,
        inscripciones: {
          where: { estadoEnCiclo: 'activa' }
        }
      }
    });

    for (const grp of grupos) {
      const asignaturasNecesarias = data.grados[grp.grado] || data.materias.map(m => m.nombre);
      
      for (const nombreAsig of asignaturasNecesarias) {
        const materiaId = materiasIds[nombreAsig];
        if (!materiaId) continue;

        // Check if GrupoMateria exists
        let gm = grp.gruposMaterias.find(gm => gm.materiaId === materiaId);
        if (!gm) {
          gm = await prisma.grupoMateria.create({
            data: {
              grupoId: grp.grupoId,
              materiaId: materiaId
            }
          });
          console.log(`  Assigned ${nombreAsig} to group ${grp.nombre}`);
        }

        // 3. Assign to students in the group
        for (const inscripcion of grp.inscripciones) {
          // Check if student already has this InscripcionMateria
          const existing = await prisma.inscripcionMateria.findFirst({
            where: {
              alumnoId: inscripcion.alumnoId,
              grupoMateriaId: gm.grupoMateriaId
            }
          });
          if (!existing) {
            await prisma.inscripcionMateria.create({
              data: {
                alumnoId: inscripcion.alumnoId,
                grupoMateriaId: gm.grupoMateriaId
              }
            });
          }
        }
      }
    }
  }

  console.log('All done!');
}

main().catch(console.error).finally(() => prisma.$disconnect());
