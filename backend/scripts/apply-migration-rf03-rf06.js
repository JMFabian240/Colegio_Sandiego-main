// Crea las tablas nuevas de RF-03 y RF-06 usando SQL directo sin COMMENTs
// para evitar problemas con el parser de ';'
const prisma = require('../src/config/database');

const statements = [
  // RF-03: Permisos granulares
  `CREATE TABLE IF NOT EXISTS usuario_permiso_modulo (
    permiso_id     SERIAL       PRIMARY KEY,
    usuario_id     INT          NOT NULL REFERENCES usuario(usuario_id) ON DELETE CASCADE,
    modulo         VARCHAR(30)  NOT NULL,
    nivel          VARCHAR(10)  NOT NULL CHECK (nivel IN ('lectura', 'escritura')),
    activo         BOOLEAN      NOT NULL DEFAULT TRUE,
    creado_en      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (usuario_id, modulo)
  )`,

  `CREATE INDEX IF NOT EXISTS idx_upm_usuario_modulo
    ON usuario_permiso_modulo(usuario_id, modulo)
    WHERE activo = TRUE`,

  // RF-06: Lista negra de tokens
  `CREATE TABLE IF NOT EXISTS token_revocado (
    id          BIGSERIAL    PRIMARY KEY,
    jti         VARCHAR(36)  NOT NULL UNIQUE,
    usuario_id  INT          REFERENCES usuario(usuario_id) ON DELETE CASCADE,
    revocado_en TIMESTAMPTZ  NOT NULL DEFAULT now(),
    expira_en   TIMESTAMPTZ  NOT NULL
  )`,

  `CREATE UNIQUE INDEX IF NOT EXISTS idx_token_revocado_jti ON token_revocado(jti)`,
  `CREATE INDEX IF NOT EXISTS idx_token_revocado_expira ON token_revocado(expira_en)`,
];

async function main() {
  console.log('Aplicando migración RF-03 / RF-06...\n');

  for (const sql of statements) {
    const label = sql.trim().split('\n')[0].substring(0, 70);
    try {
      await prisma.$executeRawUnsafe(sql);
      console.log(`  ✅ ${label}`);
    } catch (e) {
      if (e.message.includes('already exists') || (e.meta && e.meta.code === '42P07')) {
        console.log(`  ⚠️  Ya existe (OK): ${label}`);
      } else {
        console.error(`  ❌ ERROR en: ${label}`);
        console.error(`     ${e.message}\n`);
      }
    }
  }

  // Verificar tablas creadas
  const tablas = await prisma.$queryRawUnsafe(`
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name IN ('usuario_permiso_modulo', 'token_revocado')
    ORDER BY table_name
  `);

  console.log('\nTablas verificadas en BD:');
  tablas.forEach(t => console.log(`  ✅ ${t.table_name}`));

  await prisma.$disconnect();
  console.log('\n✅ Migración completada.');
}

main().catch(e => {
  console.error('Fatal:', e.message);
  process.exit(1);
});
