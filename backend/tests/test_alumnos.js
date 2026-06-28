const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
prisma.alumno.groupBy({ by: ['estado'], _count: true }).then(console.log).finally(() => prisma.$disconnect());
