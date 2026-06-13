-- =====================================================================
-- migration_rf03_rf06.sql
-- SAE - Colegio San Diego
--
-- RF-03: tabla usuario_permiso_modulo (permisos granulares por módulo)
-- RF-06: tabla token_revocado (logout real / invalidación de JWT)
--
-- EJECUTAR MANUALMENTE en la base de datos después de aplicar este archivo:
--   psql -U <usuario> -d <base_datos> -f migration_rf03_rf06.sql
-- =====================================================================

-- ──────────────────────────────────────────────────────────────────────
-- 1. RF-03: Permisos granulares por módulo
-- ──────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS usuario_permiso_modulo (
    permiso_id     SERIAL       PRIMARY KEY,
    usuario_id     INT          NOT NULL REFERENCES usuario(usuario_id) ON DELETE CASCADE,
    modulo         VARCHAR(30)  NOT NULL,
    nivel          VARCHAR(10)  NOT NULL CHECK (nivel IN ('lectura', 'escritura')),
    activo         BOOLEAN      NOT NULL DEFAULT TRUE,
    creado_en      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (usuario_id, modulo)
);

COMMENT ON TABLE usuario_permiso_modulo IS
'Permisos individuales por módulo para usuarios GESTOR y MAESTRA (RF-03).
ADMIN siempre tiene acceso total — no se almacenan filas para ADMIN.
nivel: lectura = solo GET; escritura = GET + POST + PUT + DELETE.';

CREATE INDEX IF NOT EXISTS idx_upm_usuario_modulo
    ON usuario_permiso_modulo(usuario_id, modulo)
    WHERE activo = TRUE;

-- ──────────────────────────────────────────────────────────────────────
-- 2. RF-06: Lista negra de tokens revocados (logout real)
-- ──────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS token_revocado (
    id          BIGSERIAL    PRIMARY KEY,
    jti         VARCHAR(36)  NOT NULL UNIQUE,   -- JWT ID claim (UUID v4)
    usuario_id  INT          REFERENCES usuario(usuario_id) ON DELETE CASCADE,
    revocado_en TIMESTAMPTZ  NOT NULL DEFAULT now(),
    expira_en   TIMESTAMPTZ  NOT NULL            -- para purga periódica
);

COMMENT ON TABLE token_revocado IS
'Lista negra de JWTs invalidados por logout explícito (RF-06).
El backend verifica este registro en authenticate().
Los tokens expirados (expira_en < now()) pueden purgarse periódicamente.';

CREATE UNIQUE INDEX IF NOT EXISTS idx_token_revocado_jti
    ON token_revocado(jti);

CREATE INDEX IF NOT EXISTS idx_token_revocado_expira
    ON token_revocado(expira_en);

-- ──────────────────────────────────────────────────────────────────────
-- 3. Job de purga (opcional, ejecutar por cron o manualmente)
-- ──────────────────────────────────────────────────────────────────────
-- Para purgar tokens expirados manualmente:
--   DELETE FROM token_revocado WHERE expira_en < now();

-- =====================================================================
-- FIN migration_rf03_rf06.sql
-- =====================================================================
