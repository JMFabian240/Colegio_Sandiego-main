const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const ciclos = await prisma.cicloEscolar.findMany({ include: { grupos: { include: { gruposMaterias: true } } } });
  
  for (const c of ciclos) {
    let totalM = 0;
    c.grupos.forEach(g => { totalM += g.gruposMaterias.length });
    console.log(`Ciclo ${c.cicloId} (${c.nombre}): ${c.grupos.length} grupos, ${totalM} materias`);
    if (totalM > 0) {
      c.grupos.forEach(g => {
        if (g.gruposMaterias.length > 0) {
          console.log(`  - Grupo ${g.nombre}: ${g.gruposMaterias.length} materias`);
        }
      });
    }
  }
}

main().catch(console.error).finally(() => prisma.$disconnect());
