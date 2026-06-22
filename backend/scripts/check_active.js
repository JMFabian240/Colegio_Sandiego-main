const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  const alumnos = await prisma.alumno.findMany({
    where: {
      eliminadoEn: null,
      inscripciones: {
        some: {
          eliminadoEn: null,
          grupo: {
            OR: [
              { docenteTitularId: 4 },
              { gruposMaterias: { some: { docenteId: 4, eliminadoEn: null } } }
            ],
            ciclo: { activo: true }
          }
        }
      }
    }
  });
  console.log("Total alumnos (active cycle teacher groups):", alumnos.length);
}
main().finally(() => prisma.$disconnect());
