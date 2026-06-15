const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const MATERIAS_POR_NIVEL = {
  PREESCOLAR: [
    'Pensamiento Matemático',
    'Lenguaje y Comunicación',
    'Exploración y Comprensión del Mundo',
    'Artes',
    'Educación Socioemocional',
    'Educación Física'
  ],
  PRIMARIA: [
    'Matemáticas',
    'Español',
    'Ciencias Naturales',
    'Historia',
    'Geografía',
    'Inglés',
    'Educación Física',
    'Artes'
  ],
  SECUNDARIA: [
    'Matemáticas',
    'Español',
    'Ciencias',
    'Historia',
    'Geografía',
    'Inglés',
    'Educación Física',
    'Tecnología',
    'Formación Cívica y Ética'
  ],
  BACHILLERATO: [
    'Matemáticas',
    'Literatura',
    'Física',
    'Química',
    'Historia',
    'Inglés',
    'Metodología de la Investigación',
    'Informática'
  ]
};

async function main() {
  console.log('Iniciando asignación automática de materias...');

  const grupos = await prisma.grupo.findMany({
    include: {
      nivel: true,
      _count: {
        select: { gruposMaterias: true }
      }
    }
  });

  let gruposActualizados = 0;

  for (const grupo of grupos) {
    if (grupo._count.gruposMaterias === 0) {
      console.log(`El grupo ${grupo.nombre} no tiene materias. Asignando...`);
      
      const materiasBase = MATERIAS_POR_NIVEL[grupo.nivel.codigo];
      if (!materiasBase) continue;

      for (const nombreMateria of materiasBase) {
        // Find or create Materia
        const materia = await prisma.materia.upsert({
          where: {
            nivelId_nombre_tipo: {
              nivelId: grupo.nivelId,
              nombre: nombreMateria,
              tipo: 'curricular'
            }
          },
          update: {},
          create: {
            nivelId: grupo.nivelId,
            nombre: nombreMateria,
            tipo: 'curricular',
            cuentaParaPromedio: true
          }
        });

        // Create GrupoMateria
        await prisma.grupoMateria.create({
          data: {
            grupoId: grupo.grupoId,
            materiaId: materia.materiaId,
          }
        });
      }
      gruposActualizados++;
    }
  }

  console.log(`\n¡Listo! Se asignaron materias a ${gruposActualizados} grupos.`);
}

main()
  .catch(e => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
