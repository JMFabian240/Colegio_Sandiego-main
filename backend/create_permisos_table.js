const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function createTable() {
  try {
    await prisma.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS "public"."usuario_permiso_modulo" (
          "permiso_id" SERIAL NOT NULL,
          "usuario_id" INTEGER NOT NULL,
          "modulo" VARCHAR(30) NOT NULL,
          "nivel" VARCHAR(10) NOT NULL,
          "activo" BOOLEAN NOT NULL DEFAULT true,
          "creado_en" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
          "actualizado_en" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

          CONSTRAINT "usuario_permiso_modulo_pkey" PRIMARY KEY ("permiso_id")
      );
    `);
    
    await prisma.$executeRawUnsafe(`
      ALTER TABLE "public"."usuario_permiso_modulo" 
      DROP CONSTRAINT IF EXISTS "usuario_permiso_modulo_usuario_id_fkey";
    `);

    await prisma.$executeRawUnsafe(`
      ALTER TABLE "public"."usuario_permiso_modulo" 
      ADD CONSTRAINT "usuario_permiso_modulo_usuario_id_fkey" 
      FOREIGN KEY ("usuario_id") REFERENCES "public"."usuario"("usuario_id") ON DELETE CASCADE ON UPDATE CASCADE;
    `);

    await prisma.$executeRawUnsafe(`
      DROP INDEX IF EXISTS "usuario_permiso_modulo_usuario_id_modulo_key";
    `);
    
    await prisma.$executeRawUnsafe(`
      CREATE UNIQUE INDEX "usuario_permiso_modulo_usuario_id_modulo_key" ON "public"."usuario_permiso_modulo"("usuario_id", "modulo");
    `);

    console.log("Tabla usuario_permiso_modulo creada exitosamente.");
  } catch (err) {
    console.error("Error creando tabla:", err);
  } finally {
    await prisma.$disconnect();
  }
}

createTable();
