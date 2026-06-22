const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const gms = await prisma.grupoMateria.findMany({
    where: { docenteId: 4, grupo: { ciclo: { activo: true } } },
    include: { grupo: true, materia: true }
  });
  console.log(`Teacher 4 is assigned to ${gms.length} materias en ciclo activo.`);
  const groupsWithSubjects = {};
  gms.forEach(gm => {
    groupsWithSubjects[gm.grupo.nombre] = groupsWithSubjects[gm.grupo.nombre] || [];
    groupsWithSubjects[gm.grupo.nombre].push(gm.materia.nombre);
  });
  console.dir(groupsWithSubjects);
}
main().finally(() => prisma.$disconnect());
