const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const activeCycle = await prisma.cicloEscolar.findFirst({ where: { activo: true } });
  console.log('Active Cycle:', activeCycle.nombre);
  
  const grupos = await prisma.grupo.findMany({ 
    where: { cicloId: activeCycle.cicloId, eliminadoEn: null }, 
    include: { gruposMaterias: { where: { eliminadoEn: null } } } 
  });
  
  console.log('Grupos found:', grupos.length);
  let totalMaterias = 0;
  grupos.forEach(g => {
    console.log(`Grupo ${g.nombre}: ${g.gruposMaterias.length} materias`);
    totalMaterias += g.gruposMaterias.length;
  });
  
  console.log('Total Materias:', totalMaterias);
}

main().catch(console.error).finally(() => prisma.$disconnect());
