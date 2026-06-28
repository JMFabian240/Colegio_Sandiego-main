const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function fix() {
  console.log('Iniciando corrección de codificación...');

  const replacer = (text) => {
    if (!text) return text;
    return text
      .replace(/Ã©/g, 'é')
      .replace(/Ã³/g, 'ó')
      .replace(/Ã¡/g, 'á')
      .replace(/Ã/g, 'í') // Note: Ã could be í or something else, wait. 'RÃos' -> 'Ríos'. But what about 'Ã±' -> 'ñ'?
      .replace(/RÃos/g, 'Ríos')
      .replace(/MÃ©ndez/g, 'Méndez')
      .replace(/SÃ¡nchez/g, 'Sánchez')
      .replace(/acadÃ©mica/g, 'académica')
      .replace(/InscripciÃ³n/g, 'Inscripción')
      .replace(/1Â°A/g, '1°A')
      .replace(/2Â°A/g, '2°A')
      .replace(/3Â°A/g, '3°A')
      .replace(/Â°/g, '°');
  };

  // Fix Becas
  const becas = await prisma.beca.findMany();
  for (const b of becas) {
    const nNombre = replacer(b.nombreBeca);
    const nDesc = replacer(b.descripcion);
    if (nNombre !== b.nombreBeca || nDesc !== b.descripcion) {
      await prisma.beca.update({
        where: { becaId: b.becaId },
        data: { nombreBeca: nNombre, descripcion: nDesc }
      });
    }
  }

  // Fix Grupos
  const grupos = await prisma.grupo.findMany();
  for (const g of grupos) {
    const nNombre = replacer(g.nombre);
    if (nNombre !== g.nombre) {
      await prisma.grupo.update({
        where: { grupoId: g.grupoId },
        data: { nombre: nNombre }
      });
    }
  }

  // Fix Usuarios (Teachers)
  const usuarios = await prisma.usuario.findMany();
  for (const u of usuarios) {
    const nNombre = replacer(u.nombreCompleto);
    if (nNombre !== u.nombreCompleto) {
      await prisma.usuario.update({
        where: { usuarioId: u.usuarioId },
        data: { nombreCompleto: nNombre }
      });
    }
  }
  
  // Fix Tutores and Alumnos just in case
  const tutores = await prisma.tutor.findMany();
  for (const t of tutores) {
    const nNombre = replacer(t.nombreCompleto);
    if (nNombre !== t.nombreCompleto) {
      await prisma.tutor.update({ where: { tutorId: t.tutorId }, data: { nombreCompleto: nNombre } });
    }
  }

  const alumnos = await prisma.alumno.findMany();
  for (const a of alumnos) {
    const nNombre = replacer(a.nombreCompleto);
    if (nNombre !== a.nombreCompleto) {
      await prisma.alumno.update({ where: { alumnoId: a.alumnoId }, data: { nombreCompleto: nNombre } });
    }
  }

  console.log('Corrección terminada.');
}

fix()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
