const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function cleanup() {
  console.log('Iniciando limpieza de duplicados...');
  
  // Buscar tutores creados por el seed extra (sus nombres contienen estos apellidos o números)
  const tutoresABorrar = await prisma.tutor.findMany({
    where: {
      OR: [
        { nombreCompleto: { contains: 'Carlos Sánchez Ruiz' } },
        { nombreCompleto: { contains: 'Laura Méndez Ortiz' } },
        { nombreCompleto: { contains: 'Roberto Gómez' } }
      ]
    }
  });

  const alumnosABorrar = await prisma.alumno.findMany({
    where: {
      OR: [
        { nombreCompleto: { contains: 'Diego Sánchez Méndez' } },
        { nombreCompleto: { contains: 'Valeria Sánchez Méndez' } },
        { nombreCompleto: { contains: 'Emilio Gómez' } },
        { nombreCompleto: { contains: 'Sofía Castañeda' } },
        { nombreCompleto: { contains: 'Mateo Luna' } }
      ]
    }
  });

  console.log(`Se encontraron ${tutoresABorrar.length} tutores duplicados y ${alumnosABorrar.length} alumnos duplicados.`);

  // Vamos a dejar SOLO 1 copia de cada uno.
  // Agrupar por nombre base
  const tutoresPorNombre = {};
  for(const t of tutoresABorrar) {
    // el nombre base es sin los numeros al final (si los tiene)
    const base = t.nombreCompleto.replace(/\s\d+$/, '');
    if(!tutoresPorNombre[base]) tutoresPorNombre[base] = [];
    tutoresPorNombre[base].push(t);
  }

  const alumnosPorNombre = {};
  for(const a of alumnosABorrar) {
    const base = a.nombreCompleto;
    if(!alumnosPorNombre[base]) alumnosPorNombre[base] = [];
    alumnosPorNombre[base].push(a);
  }

  let tutoresBorrados = 0;
  for(const base in tutoresPorNombre) {
    const lista = tutoresPorNombre[base];
    // Conservar el último (el que se completó bien con las relaciones) o el primero,
    // en este caso el último creado es el que tiene las relaciones correctas y completas
    // ya que el script falló a la mitad en los primeros intentos.
    lista.sort((a,b) => a.tutorId - b.tutorId);
    
    // Dejar solo el de ID más alto
    const aConservar = lista.pop();
    
    for(const t of lista) {
      await prisma.tutor.delete({ where: { tutorId: t.tutorId } });
      tutoresBorrados++;
    }
  }

  let alumnosBorrados = 0;
  for(const base in alumnosPorNombre) {
    const lista = alumnosPorNombre[base];
    lista.sort((a,b) => a.alumnoId - b.alumnoId);
    const aConservar = lista.pop();
    
    for(const a of lista) {
      // Eliminar alumnos requiere eliminar en cascada, o Prisma lo hace si es cascade
      // Sin embargo, si falló, algunos de estos pueden tener calendarios / pagos huerfanos.
      // Mejor borrar por ID forzando.
      
      // Borrar pagos
      await prisma.pago.deleteMany({ where: { alumnoId: a.alumnoId } });
      // Borrar calendarios
      await prisma.calendarioPago.deleteMany({ where: { alumnoId: a.alumnoId } });
      // Borrar relaciones tutor-alumno
      await prisma.tutorAlumno.deleteMany({ where: { alumnoId: a.alumnoId } });
      
      await prisma.alumno.delete({ where: { alumnoId: a.alumnoId } });
      alumnosBorrados++;
    }
  }

  console.log(`Se eliminaron ${tutoresBorrados} tutores y ${alumnosBorrados} alumnos excedentes.`);
}

cleanup()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
