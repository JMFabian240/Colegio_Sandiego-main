require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function revert() {
  console.log('Iniciando reversión del último seed...');

  // 1. Borrar tablas intermedias y dependencias primero
  console.log('Borrando dependencias (Inscripciones, Calificaciones, etc.)...');
  await prisma.asistencia.deleteMany();
  await prisma.calificacionExtracurricular.deleteMany();
  await prisma.calificacionTaller.deleteMany();
  await prisma.calificacion.deleteMany();
  await prisma.inscripcionMateria.deleteMany();
  await prisma.inscripcionCiclo.deleteMany();
  await prisma.tutorAlumno.deleteMany(); // Rompe la relación entre tutores y alumnos

  // 2. Borrar estructura académica generada
  console.log('Borrando Grupos y Materias...');
  await prisma.grupoMateria.deleteMany();
  await prisma.materia.deleteMany();
  await prisma.grupo.deleteMany();

  // 3. Borrar Alumnos creados por el seed (identificables por el formato de matrícula)
  console.log('Borrando Alumnos generados...');
  const alumnosBorrados = await prisma.alumno.deleteMany({
    where: {
      matricula: {
        startsWith: `MAT-${new Date().getFullYear()}-`
      }
    }
  });
  console.log(`- ${alumnosBorrados.count} Alumnos eliminados.`);

  // 4. Borrar Tutores creados por el seed
  console.log('Borrando Tutores generados...');
  const tutoresBorrados = await prisma.tutor.deleteMany({
    where: {
      nombreCompleto: {
        startsWith: 'Tutor Genérico'
      }
    }
  });
  console.log(`- ${tutoresBorrados.count} Tutores eliminados.`);

  // 5. Borrar Docentes creados por el seed
  console.log('Borrando Docentes generados...');
  const docentesBorrados = await prisma.usuario.deleteMany({
    where: {
      nombreUsuario: {
        startsWith: 'docente.'
      }
    }
  });
  console.log(`- ${docentesBorrados.count} Docentes eliminados.`);

  console.log('✅ Reversión completada exitosamente.');
}

revert()
  .catch(console.error)
  .finally(async () => {
    await prisma.$disconnect();
  });
