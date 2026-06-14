const { PrismaClient } = require('@prisma/client'); 
const prisma = new PrismaClient(); 
async function main() { 
  await prisma.$executeRawUnsafe(`
    DO $$
    BEGIN
      -- Beca
      IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_beca') THEN
        CREATE TRIGGER trg_audit_beca
        AFTER INSERT OR UPDATE OR DELETE ON public.beca
        FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger('beca_id');
      END IF;

      -- Solicitud Beca
      IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_solicitud_beca') THEN
        CREATE TRIGGER trg_audit_solicitud_beca
        AFTER INSERT OR UPDATE OR DELETE ON public.solicitud_beca
        FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger('solicitud_id');
      END IF;

      -- Asignacion Beca
      IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_asignacion_beca') THEN
        CREATE TRIGGER trg_audit_asignacion_beca
        AFTER INSERT OR UPDATE OR DELETE ON public.asignacion_beca
        FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger('asignacion_id');
      END IF;
    END;
    $$;
  `);
  console.log("Triggers creados correctamente.");
  console.log(res); 
} 
main().finally(() => prisma.$disconnect());
