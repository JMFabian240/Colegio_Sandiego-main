const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS public.token_revocado (
      id SERIAL PRIMARY KEY,
      jti VARCHAR(255) NOT NULL UNIQUE,
      revocado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS public.calificacion_extracurricular (
      calificacion_extracurricular_id SERIAL PRIMARY KEY,
      alumno_id INTEGER NOT NULL,
      club VARCHAR(50) NOT NULL,
      periodo_id INTEGER NOT NULL,
      ciclo_id INTEGER NOT NULL,
      valor_numerico DECIMAL(4,2),
      modificada_motivo TEXT,
      registrada_por INTEGER,
      registrada_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  
  await prisma.$executeRawUnsafe(`ALTER TABLE public.calificacion_extracurricular DROP CONSTRAINT IF EXISTS calificacion_extracurricular_alumno_id_fkey;`);
  await prisma.$executeRawUnsafe(`ALTER TABLE public.calificacion_extracurricular ADD CONSTRAINT calificacion_extracurricular_alumno_id_fkey FOREIGN KEY (alumno_id) REFERENCES public.alumno(alumno_id) ON DELETE RESTRICT;`);

  await prisma.$executeRawUnsafe(`ALTER TABLE public.calificacion_extracurricular DROP CONSTRAINT IF EXISTS calificacion_extracurricular_periodo_id_fkey;`);
  await prisma.$executeRawUnsafe(`ALTER TABLE public.calificacion_extracurricular ADD CONSTRAINT calificacion_extracurricular_periodo_id_fkey FOREIGN KEY (periodo_id) REFERENCES public.periodo_evaluacion(periodo_id) ON DELETE RESTRICT;`);
  
  await prisma.$executeRawUnsafe(`ALTER TABLE public.calificacion_extracurricular DROP CONSTRAINT IF EXISTS calificacion_extracurricular_ciclo_id_fkey;`);
  await prisma.$executeRawUnsafe(`ALTER TABLE public.calificacion_extracurricular ADD CONSTRAINT calificacion_extracurricular_ciclo_id_fkey FOREIGN KEY (ciclo_id) REFERENCES public.ciclo_escolar(ciclo_id) ON DELETE RESTRICT;`);

  await prisma.$executeRawUnsafe(`DROP INDEX IF EXISTS calificacion_extracurricular_alumno_id_club_periodo_id_ciclo_id_key;`);
  await prisma.$executeRawUnsafe(`CREATE UNIQUE INDEX calificacion_extracurricular_alumno_id_club_periodo_id_ciclo_id_key ON public.calificacion_extracurricular(alumno_id, club, periodo_id, ciclo_id);`);
  
  console.log("Tables created successfully.");
}
main().catch(console.error).finally(() => prisma.$disconnect());
