const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const query = `
    CREATE TABLE IF NOT EXISTS "calificacion_taller" (
      "calificacion_taller_id" SERIAL NOT NULL,
      "alumno_id" INTEGER NOT NULL,
      "periodo_id" INTEGER NOT NULL,
      "ciclo_id" INTEGER NOT NULL,
      "valor_cualitativo" VARCHAR(5),
      "modificada_motivo" TEXT,
      "registrada_por" INTEGER,
      "registrada_en" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
      "actualizado_en" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

      CONSTRAINT "calificacion_taller_pkey" PRIMARY KEY ("calificacion_taller_id"),
      CONSTRAINT "calificacion_taller_alumno_id_fkey" FOREIGN KEY ("alumno_id") REFERENCES "alumno"("alumno_id") ON DELETE RESTRICT ON UPDATE CASCADE,
      CONSTRAINT "calificacion_taller_periodo_id_fkey" FOREIGN KEY ("periodo_id") REFERENCES "periodo_evaluacion"("periodo_id") ON DELETE RESTRICT ON UPDATE CASCADE,
      CONSTRAINT "calificacion_taller_ciclo_id_fkey" FOREIGN KEY ("ciclo_id") REFERENCES "ciclo_escolar"("ciclo_id") ON DELETE RESTRICT ON UPDATE CASCADE,
      CONSTRAINT "calificacion_taller_registrada_por_fkey" FOREIGN KEY ("registrada_por") REFERENCES "usuario"("usuario_id") ON DELETE SET NULL ON UPDATE CASCADE
    );
  `;
  await prisma.$executeRawUnsafe(query);
  
  const query2 = `
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'calificacion_taller_alumno_id_periodo_id_ciclo_id_key'
      ) THEN
        ALTER TABLE "calificacion_taller" ADD CONSTRAINT "calificacion_taller_alumno_id_periodo_id_ciclo_id_key" UNIQUE ("alumno_id", "periodo_id", "ciclo_id");
      END IF;
    END $$;
  `;
  await prisma.$executeRawUnsafe(query2);

  console.log("Table created!");
}
main().finally(() => prisma.$disconnect());
