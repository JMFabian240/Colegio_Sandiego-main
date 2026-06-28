const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  await prisma.$executeRawUnsafe(`
    DO $$
    BEGIN
      -- Ciclo Escolar
      IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_ciclo_escolar') THEN
        CREATE TRIGGER trg_audit_ciclo_escolar
        AFTER INSERT OR UPDATE OR DELETE ON public.ciclo_escolar
        FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger('ciclo_id');
      END IF;

      -- Tarifa
      IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_tarifa') THEN
        CREATE TRIGGER trg_audit_tarifa
        AFTER INSERT OR UPDATE OR DELETE ON public.tarifa
        FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger('tarifa_id');
      END IF;
    END;
    $$;
  `);
  console.log("Triggers de tarifas creados correctamente.");
}
main().finally(() => prisma.$disconnect());
