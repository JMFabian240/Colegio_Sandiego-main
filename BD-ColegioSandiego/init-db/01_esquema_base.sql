-- =====================================================================
-- 01_esquema_base.sql  (v6 - reingeniería con soporte para frontend Sandiego)
-- SAE - Colegio San Diego | Esquema base consolidado
--
-- Cambios respecto a v5:
--   * NUEVA TABLA plan_pago (Categoría C): catálogo de planes con monto
--     mensual y monto diciembre por ciclo.
--   * NUEVA TABLA solicitud_beca (Categoría C): workflow RF-21 con
--     estados pendiente/aprobada/rechazada y vínculo opcional con
--     asignacion_beca al materializarse.
--   * inscripcion_ciclo gana TRES columnas:
--       - plan_pago_id (FK al nuevo catálogo, complementa columna legacy)
--       - estado_financiero (al_corriente/aviso_preventivo/
--         examen_restringido/baja_temporal) — separado de estado_en_ciclo
--       - meses_adeudo (contador denormalizado para vista de deudores)
--   * asignacion_beca gana solicitud_id (FK opcional a solicitud_beca).
--   * Conceptos de pago: agregado 'otro' en tarifa y calendario_pago.
--   * Columna legacy inscripcion_ciclo.plan_pago se MANTIENE (deprecated
--     pero no eliminada, decisión consciente — ver COMMENT).
--
-- Mantiene íntegro todo lo de v5: auditoría 3 categorías, triggers H-02,
-- H-05, H-10, función fn_actualizar_timestamp, índices parciales.
-- =====================================================================

-- =====================================================================
-- BLOQUE 0  Extensiones
-- =====================================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- =====================================================================
-- BLOQUE 1  Función genérica de auditoría de filas
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_actualizar_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.actualizado_en := now();
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_actualizar_timestamp() IS
'Trigger genérico BEFORE UPDATE. Actualiza la columna actualizado_en a now()
en cada modificación. Se aplica a TODAS las tablas con esa columna.';

-- =====================================================================
-- BLOQUE 2  Seguridad: usuarios y roles N:M (Categoría C)
-- =====================================================================
CREATE TABLE IF NOT EXISTS usuario (
    usuario_id        SERIAL       PRIMARY KEY,
    nombre_usuario    VARCHAR(80)  NOT NULL UNIQUE,
    nombre_completo   VARCHAR(120) NOT NULL,
    correo            CITEXT       UNIQUE,
    telefono          VARCHAR(15),
    password_hash     VARCHAR(255) NOT NULL,
    activo            BOOLEAN      NOT NULL DEFAULT TRUE,
    intentos_fallidos INT          NOT NULL DEFAULT 0 CHECK (intentos_fallidos >= 0),
    bloqueado_hasta   TIMESTAMPTZ,
    ultimo_acceso     TIMESTAMPTZ,
    debe_cambiar_pwd  BOOLEAN      NOT NULL DEFAULT FALSE,
    creado_en         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    eliminado_en      TIMESTAMPTZ
);
COMMENT ON TABLE  usuario          IS 'Cuentas de acceso. Roles asignados vía usuario_rol (N:M).';
COMMENT ON COLUMN usuario.activo   IS 'Estado funcional: FALSE = cuenta deshabilitada por seguridad (puede reactivarse).';
COMMENT ON COLUMN usuario.eliminado_en IS 'Marca administrativa: si NO es NULL, la fila se considera eliminada.';

-- Categoría B: rol sin columna 'activo'; eliminado_en es la fuente única
CREATE TABLE IF NOT EXISTS rol (
    rol_id          SERIAL      PRIMARY KEY,
    codigo          VARCHAR(20) NOT NULL UNIQUE,
    nombre          VARCHAR(60) NOT NULL,
    descripcion     TEXT,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en  TIMESTAMPTZ NOT NULL DEFAULT now(),
    eliminado_en    TIMESTAMPTZ
);
COMMENT ON TABLE rol IS 'Catálogo de roles. Categoría B: eliminado_en sustituye al antiguo "activo".';

INSERT INTO rol (codigo, nombre, descripcion) VALUES
    ('administrador', 'Administrador',  'Acceso total al sistema, configuración y seguridad.'),
    ('directora',     'Directora',      'Gestión académica y financiera con privilegios de aprobación.'),
    ('empleado',      'Empleado',       'Registra pagos, alumnos y datos operativos.'),
    ('docente',       'Docente',        'Captura calificaciones y asistencia de sus grupos.')
ON CONFLICT (codigo) DO NOTHING;

-- usuario_rol: Categoría C
CREATE TABLE IF NOT EXISTS usuario_rol (
    usuario_rol_id  SERIAL      PRIMARY KEY,
    usuario_id      INT         NOT NULL REFERENCES usuario(usuario_id) ON DELETE CASCADE,
    rol_id          INT         NOT NULL REFERENCES rol(rol_id) ON DELETE RESTRICT,
    asignado_en     TIMESTAMPTZ NOT NULL DEFAULT now(),
    asignado_por    INT         REFERENCES usuario(usuario_id) ON DELETE SET NULL,
    activo          BOOLEAN     NOT NULL DEFAULT TRUE,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en  TIMESTAMPTZ NOT NULL DEFAULT now(),
    eliminado_en    TIMESTAMPTZ,
    UNIQUE (usuario_id, rol_id)
);
COMMENT ON COLUMN usuario_rol.activo IS
'Vínculo vigente. FALSE = rol revocado pero la fila se conserva como historial.';
COMMENT ON COLUMN usuario_rol.eliminado_en IS
'Eliminación administrativa de la asignación (error de captura, no revocación).';

-- =====================================================================
-- BLOQUE 3  Catálogos y ciclo
-- =====================================================================

-- Categoría B
CREATE TABLE IF NOT EXISTS nivel_educativo (
    nivel_id        SERIAL       PRIMARY KEY,
    codigo          VARCHAR(15)  NOT NULL UNIQUE,
    nombre          VARCHAR(60)  NOT NULL,
    rvoe            VARCHAR(40),
    orden           INT          NOT NULL CHECK (orden > 0),
    creado_en       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    eliminado_en    TIMESTAMPTZ
);
COMMENT ON TABLE nivel_educativo IS 'Catálogo. Categoría B: solo eliminado_en como fuente de baja.';

INSERT INTO nivel_educativo (codigo, nombre, orden) VALUES
    ('PREESCOLAR',   'Preescolar',   1),
    ('PRIMARIA',     'Primaria',     2),
    ('SECUNDARIA',   'Secundaria',   3),
    ('BACHILLERATO', 'Bachillerato', 4)
ON CONFLICT (codigo) DO NOTHING;

-- Categoría C
CREATE TABLE IF NOT EXISTS ciclo_escolar (
    ciclo_id        SERIAL      PRIMARY KEY,
    nombre          VARCHAR(20) NOT NULL UNIQUE,
    fecha_inicio    DATE        NOT NULL,
    fecha_fin       DATE        NOT NULL,
    activo          BOOLEAN     NOT NULL DEFAULT FALSE,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en  TIMESTAMPTZ NOT NULL DEFAULT now(),
    eliminado_en    TIMESTAMPTZ,
    CHECK (fecha_fin > fecha_inicio)
);
COMMENT ON TABLE ciclo_escolar IS 'Pivote temporal. Solo un ciclo activo a la vez (validar en backend).';
COMMENT ON COLUMN ciclo_escolar.activo IS
'Funcional: TRUE = ciclo en curso AHORA. NO confundir con eliminado_en (registro borrado).';

-- =====================================================================
-- BLOQUE 4  Estructura académica (Categoría C)
-- =====================================================================
CREATE TABLE IF NOT EXISTS grupo (
    grupo_id            SERIAL      PRIMARY KEY,
    ciclo_id            INT         NOT NULL REFERENCES ciclo_escolar(ciclo_id) ON DELETE RESTRICT,
    nivel_id            INT         NOT NULL REFERENCES nivel_educativo(nivel_id) ON DELETE RESTRICT,
    grado               VARCHAR(10) NOT NULL,
    seccion             VARCHAR(5)  NOT NULL,
    nombre              VARCHAR(60) NOT NULL,
    docente_titular_id  INT         REFERENCES usuario(usuario_id) ON DELETE SET NULL,
    cupo_maximo         INT         CHECK (cupo_maximo IS NULL OR cupo_maximo > 0),
    creado_en           TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en      TIMESTAMPTZ NOT NULL DEFAULT now(),
    eliminado_en        TIMESTAMPTZ,
    UNIQUE (ciclo_id, nivel_id, grado, seccion),
    UNIQUE (grupo_id, ciclo_id)
);
COMMENT ON TABLE grupo IS 'Grupos por ciclo: combinación nivel+grado+sección con docente titular.';

-- Categoría B
CREATE TABLE IF NOT EXISTS materia (
    materia_id            SERIAL       PRIMARY KEY,
    nivel_id              INT          NOT NULL REFERENCES nivel_educativo(nivel_id) ON DELETE RESTRICT,
    clave_sep             VARCHAR(20),
    nombre                VARCHAR(80)  NOT NULL,
    descripcion           TEXT,
    horas_semanales       INT          CHECK (horas_semanales IS NULL OR horas_semanales BETWEEN 0 AND 50),
    creditos              NUMERIC(4,1) CHECK (creditos IS NULL OR creditos BETWEEN 0 AND 20),
    tipo                  VARCHAR(15)  NOT NULL DEFAULT 'curricular'
                          CHECK (tipo IN ('curricular','club','taller')),
    cuenta_para_promedio  BOOLEAN      NOT NULL DEFAULT TRUE,
    creado_en             TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    eliminado_en          TIMESTAMPTZ,
    UNIQUE (nivel_id, nombre, tipo)
);
COMMENT ON TABLE materia IS 'Catálogo de materias. Categoría B: solo eliminado_en como fuente de baja.';

CREATE TABLE IF NOT EXISTS grupo_materia (
    grupo_materia_id SERIAL      PRIMARY KEY,
    grupo_id         INT         NOT NULL REFERENCES grupo(grupo_id) ON DELETE RESTRICT,
    materia_id       INT         NOT NULL REFERENCES materia(materia_id) ON DELETE RESTRICT,
    docente_id       INT         REFERENCES usuario(usuario_id) ON DELETE SET NULL,
    horario          VARCHAR(80),
    aula             VARCHAR(40),
    creado_en        TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en   TIMESTAMPTZ NOT NULL DEFAULT now(),
    eliminado_en     TIMESTAMPTZ,
    UNIQUE (grupo_id, materia_id)
);
COMMENT ON TABLE grupo_materia IS 'N:M grupo↔materia. Calificaciones y asistencia se anclan aquí.';

CREATE TABLE IF NOT EXISTS periodo_evaluacion (
    periodo_id      SERIAL      PRIMARY KEY,
    ciclo_id        INT         NOT NULL REFERENCES ciclo_escolar(ciclo_id) ON DELETE RESTRICT,
    nivel_id        INT         NOT NULL REFERENCES nivel_educativo(nivel_id) ON DELETE RESTRICT,
    tipo            VARCHAR(15) NOT NULL
                    CHECK (tipo IN ('bloque','trimestre','bimestre','semestre','final')),
    numero          INT         NOT NULL CHECK (numero > 0),
    nombre          VARCHAR(40) NOT NULL,
    fecha_inicio    DATE        NOT NULL,
    fecha_fin       DATE        NOT NULL,
    es_final_ciclo  BOOLEAN     NOT NULL DEFAULT FALSE,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en  TIMESTAMPTZ NOT NULL DEFAULT now(),
    eliminado_en    TIMESTAMPTZ,
    UNIQUE (ciclo_id, nivel_id, tipo, numero),
    CHECK (fecha_fin >= fecha_inicio),
    EXCLUDE USING gist (
        ciclo_id WITH =,
        nivel_id WITH =,
        daterange(fecha_inicio, fecha_fin, '[]') WITH &&
    )
);
COMMENT ON TABLE periodo_evaluacion IS
'Periodos por ciclo/nivel. Sin solapamiento de fechas (H-04).';

-- =====================================================================
-- BLOQUE 5  Comunidad escolar (Categoría C)
-- =====================================================================

CREATE TABLE IF NOT EXISTS tutor (
    tutor_id            SERIAL        PRIMARY KEY,
    nombre_completo     VARCHAR(120)  NOT NULL,
    correo_electronico  CITEXT,
    telefono            VARCHAR(15),
    direccion           TEXT,
    rfc                 VARCHAR(13)   UNIQUE,
    curp                VARCHAR(18),
    regimen_fiscal      VARCHAR(10),
    uso_cfdi            VARCHAR(10),
    direccion_fiscal    TEXT,
    codigo_postal       VARCHAR(10),
    correo_facturacion  CITEXT,
    requiere_factura    BOOLEAN       NOT NULL DEFAULT FALSE,
    tipo_pago_habitual  VARCHAR(15)
                        CHECK (tipo_pago_habitual IN ('transferencia','deposito','tarjeta','efectivo')),
    saldo_a_favor       NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (saldo_a_favor >= 0),
    activo              BOOLEAN       NOT NULL DEFAULT TRUE,
    creado_en           TIMESTAMPTZ   NOT NULL DEFAULT now(),
    actualizado_en      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    eliminado_en        TIMESTAMPTZ
);
COMMENT ON TABLE tutor IS 'Tutor del alumno: padre, madre, abuelo, tutor legal, etc.';
COMMENT ON COLUMN tutor.activo IS
'Funcional: FALSE = tutor inactivo en el sistema (ej. familia ya no en el colegio).';
COMMENT ON COLUMN tutor.eliminado_en IS
'Administrativa: registro eliminado por error de captura. NO confundir con activo.';

CREATE TABLE IF NOT EXISTS alumno (
    alumno_id             SERIAL       PRIMARY KEY,
    matricula             VARCHAR(30)  NOT NULL UNIQUE,
    curp                  VARCHAR(18)  UNIQUE,
    nombre_completo       VARCHAR(120) NOT NULL,
    fecha_nacimiento      DATE,
    lugar_nacimiento      VARCHAR(100),
    sexo                  CHAR(1)      CHECK (sexo IN ('M','F','X')),
    nivel_id              INT          REFERENCES nivel_educativo(nivel_id) ON DELETE RESTRICT,
    estado                VARCHAR(20)  NOT NULL DEFAULT 'Activo'
                          CHECK (estado IN ('Activo','Baja Temporal','Baja Definitiva','Egresado')),
    fecha_baja            DATE,
    motivo_baja           TEXT,
    dia_limite_pago       INT          CHECK (dia_limite_pago BETWEEN 1 AND 31),
    personas_autorizadas  JSONB        NOT NULL DEFAULT '[]'::jsonb
                          CHECK (jsonb_typeof(personas_autorizadas) = 'array'),
    observaciones         TEXT,
    creado_en             TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    eliminado_en          TIMESTAMPTZ
);
COMMENT ON TABLE alumno IS 'Expediente del alumno. Tutores asignados vía tutor_alumno (N:M).';
COMMENT ON COLUMN alumno.estado IS
'Funcional: Activo / Baja Temporal / Baja Definitiva / Egresado. Estado dentro del negocio.';
COMMENT ON COLUMN alumno.eliminado_en IS
'Administrativa: registro borrado por error. NO equivale a "Baja Definitiva" (esa es funcional).';

CREATE TABLE IF NOT EXISTS tutor_alumno (
    tutor_alumno_id            SERIAL      PRIMARY KEY,
    tutor_id                   INT         NOT NULL REFERENCES tutor(tutor_id) ON DELETE CASCADE,
    alumno_id                  INT         NOT NULL REFERENCES alumno(alumno_id) ON DELETE CASCADE,
    tipo_relacion              VARCHAR(15) NOT NULL DEFAULT 'tutor'
                               CHECK (tipo_relacion IN ('padre','madre','tutor_legal','abuelo','otro','tutor')),
    es_responsable_financiero  BOOLEAN     NOT NULL DEFAULT FALSE,
    puede_recoger              BOOLEAN     NOT NULL DEFAULT TRUE,
    recibe_notificaciones      BOOLEAN     NOT NULL DEFAULT TRUE,
    activo                     BOOLEAN     NOT NULL DEFAULT TRUE,
    creado_en                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en             TIMESTAMPTZ NOT NULL DEFAULT now(),
    eliminado_en               TIMESTAMPTZ,
    UNIQUE (tutor_id, alumno_id)
);
COMMENT ON COLUMN tutor_alumno.activo IS
'Funcional: FALSE = vínculo terminado (custodia transferida, divorcio, etc.). Historial preservado.';

-- =====================================================================
-- BLOQUE 6  Plan de pago (NUEVO en v6, Categoría C)
-- DEBE crearse ANTES de inscripcion_ciclo porque ésta lo referencia.
-- =====================================================================
CREATE TABLE IF NOT EXISTS plan_pago (
    plan_pago_id     SERIAL        PRIMARY KEY,
    ciclo_id         INT           NOT NULL REFERENCES ciclo_escolar(ciclo_id) ON DELETE RESTRICT,
    nombre           VARCHAR(40)   NOT NULL,
    meses            INT           NOT NULL CHECK (meses BETWEEN 1 AND 12),
    monto_mensual    NUMERIC(12,2) NOT NULL CHECK (monto_mensual >= 0),
    monto_diciembre  NUMERIC(12,2) NOT NULL CHECK (monto_diciembre >= 0),
    descripcion      TEXT,
    activo           BOOLEAN       NOT NULL DEFAULT TRUE,
    creado_en        TIMESTAMPTZ   NOT NULL DEFAULT now(),
    actualizado_en   TIMESTAMPTZ   NOT NULL DEFAULT now(),
    eliminado_en     TIMESTAMPTZ,
    UNIQUE (ciclo_id, nombre)
);
COMMENT ON TABLE plan_pago IS
'Catálogo de planes de pago por ciclo (10 meses, 12 meses, etc.).
Categoría C: activo (vigente para nuevas altas) coexiste con eliminado_en
(registro borrado administrativamente).';
COMMENT ON COLUMN plan_pago.activo IS
'TRUE = disponible para nuevas inscripciones. FALSE = plan retirado pero
conserva vínculos históricos con inscripciones existentes.';
COMMENT ON COLUMN plan_pago.monto_diciembre IS
'Cobro doble de diciembre (aguinaldo escolar). Política del colegio
San Diego — RF: el mes 12 cobra ~2x mensualidad ordinaria.';

-- =====================================================================
-- BLOQUE 7  Inscripción al ciclo (CAMBIADO en v6: +plan_pago_id,
-- +estado_financiero, +meses_adeudo)
-- =====================================================================
CREATE TABLE IF NOT EXISTS inscripcion_ciclo (
    inscripcion_id     SERIAL      PRIMARY KEY,
    alumno_id          INT         NOT NULL REFERENCES alumno(alumno_id) ON DELETE RESTRICT,
    ciclo_id           INT         NOT NULL REFERENCES ciclo_escolar(ciclo_id) ON DELETE RESTRICT,
    grupo_id           INT         NOT NULL,

    -- Plan de pago: doble referencia durante transición v5→v6
    plan_pago          VARCHAR(10) NOT NULL DEFAULT '10_meses'
                       CHECK (plan_pago IN ('10_meses','12_meses')),
    plan_pago_id       INT         REFERENCES plan_pago(plan_pago_id) ON DELETE RESTRICT,

    fecha_ingreso      DATE        NOT NULL DEFAULT CURRENT_DATE,
    es_ingreso_tardio  BOOLEAN     NOT NULL DEFAULT FALSE,

    -- Estado académico/administrativo (existente)
    estado_en_ciclo    VARCHAR(20) NOT NULL DEFAULT 'activa'
                       CHECK (estado_en_ciclo IN ('activa','baja_temporal','baja_definitiva','egresado')),

    -- Estado financiero (NUEVO v6) — diferenciado del académico
    estado_financiero  VARCHAR(20) NOT NULL DEFAULT 'al_corriente'
                       CHECK (estado_financiero IN ('al_corriente','aviso_preventivo',
                                                     'examen_restringido','baja_temporal')),
    meses_adeudo       INT         NOT NULL DEFAULT 0 CHECK (meses_adeudo >= 0),

    motivo_baja        TEXT,
    fecha_baja         DATE,
    creado_en          TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en     TIMESTAMPTZ NOT NULL DEFAULT now(),
    eliminado_en       TIMESTAMPTZ,
    UNIQUE (alumno_id, ciclo_id),
    CONSTRAINT fk_inscripcion_grupo_ciclo
        FOREIGN KEY (grupo_id, ciclo_id) REFERENCES grupo(grupo_id, ciclo_id) ON DELETE RESTRICT
);
COMMENT ON TABLE inscripcion_ciclo IS
'Historiza alumno×ciclo×grupo. Soporta promoción (RF-15) y consulta multi-ciclo (RF-55).';
COMMENT ON COLUMN inscripcion_ciclo.plan_pago IS
'DEPRECATED desde v6. Mantenida por compatibilidad. La fuente de verdad es plan_pago_id.
Eliminar en v7 una vez backend y queries hayan migrado completamente.';
COMMENT ON COLUMN inscripcion_ciclo.plan_pago_id IS
'FK al catálogo plan_pago. Fuente de verdad para montos mensuales y de diciembre.';
COMMENT ON COLUMN inscripcion_ciclo.estado_en_ciclo IS
'Funcional ACADÉMICO: estado administrativo del alumno en este ciclo.
NO confundir con estado_financiero (que rastrea cumplimiento de pagos).';
COMMENT ON COLUMN inscripcion_ciclo.estado_financiero IS
'Funcional FINANCIERO: cumplimiento de pagos.
Transiciones automáticas por backend:
  al_corriente → aviso_preventivo  (1 mes adeudo)
  aviso_preventivo → examen_restringido (2 meses)
  examen_restringido → baja_temporal (3 meses) → además propaga estado_en_ciclo=baja_temporal (RF-32).';
COMMENT ON COLUMN inscripcion_ciclo.meses_adeudo IS
'Contador denormalizado para vista de deudores. Backend lo recalcula al
registrar pago o ejecutar el job de cierre mensual.';

-- =====================================================================
-- BLOQUE 8  Académico: resultados (Categoría A — solo actualizado_en)
-- =====================================================================
CREATE TABLE IF NOT EXISTS calificacion (
    calificacion_id      SERIAL       PRIMARY KEY,
    alumno_id            INT          NOT NULL REFERENCES alumno(alumno_id) ON DELETE RESTRICT,
    grupo_materia_id     INT          NOT NULL REFERENCES grupo_materia(grupo_materia_id) ON DELETE RESTRICT,
    periodo_id           INT          NOT NULL REFERENCES periodo_evaluacion(periodo_id) ON DELETE RESTRICT,
    tipo_evaluacion      VARCHAR(15)  NOT NULL DEFAULT 'numerica'
                         CHECK (tipo_evaluacion IN ('numerica','cualitativa','observacion')),
    valor_numerico       NUMERIC(4,2) CHECK (valor_numerico IS NULL OR valor_numerico BETWEEN 0 AND 10),
    valor_cualitativo    VARCHAR(5)   CHECK (valor_cualitativo IS NULL OR valor_cualitativo IN ('A','NA')),
    texto_observacion    TEXT,
    cuenta_para_promedio BOOLEAN      NOT NULL DEFAULT TRUE,
    modificada_motivo    TEXT,
    registrada_por       INT          REFERENCES usuario(usuario_id) ON DELETE SET NULL,
    registrada_en        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT chk_calif_valor_por_tipo CHECK (
        (tipo_evaluacion = 'numerica'    AND valor_numerico    IS NOT NULL) OR
        (tipo_evaluacion = 'cualitativa' AND valor_cualitativo IS NOT NULL) OR
        (tipo_evaluacion = 'observacion' AND texto_observacion IS NOT NULL)
    )
);
COMMENT ON TABLE calificacion IS
'Histórica (Categoría A): NO usa eliminado_en. Correcciones requieren modificada_motivo.';

CREATE TABLE IF NOT EXISTS asistencia (
    asistencia_id     SERIAL      PRIMARY KEY,
    alumno_id         INT         NOT NULL REFERENCES alumno(alumno_id) ON DELETE RESTRICT,
    grupo_materia_id  INT         NOT NULL REFERENCES grupo_materia(grupo_materia_id) ON DELETE RESTRICT,
    fecha             DATE        NOT NULL,
    estado            VARCHAR(10) NOT NULL CHECK (estado IN ('presente','ausente','retardo')),
    justificacion     TEXT,
    registrada_por    INT         REFERENCES usuario(usuario_id) ON DELETE SET NULL,
    registrada_en     TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (alumno_id, grupo_materia_id, fecha)
);
COMMENT ON TABLE asistencia IS
'Histórica (Categoría A): la asistencia de un día NO se borra, se corrige con justificacion.';

-- =====================================================================
-- BLOQUE 9  Finanzas
-- =====================================================================
CREATE TABLE IF NOT EXISTS tarifa (
    tarifa_id       SERIAL        PRIMARY KEY,
    ciclo_id        INT           NOT NULL REFERENCES ciclo_escolar(ciclo_id) ON DELETE RESTRICT,
    nivel_id        INT           NOT NULL REFERENCES nivel_educativo(nivel_id) ON DELETE RESTRICT,
    concepto        VARCHAR(15)   NOT NULL
                    CHECK (concepto IN ('inscripcion','colegiatura','material','uniforme','arancel','otro')),
    monto           NUMERIC(12,2) NOT NULL CHECK (monto >= 0),
    descripcion     TEXT,
    activa          BOOLEAN       NOT NULL DEFAULT TRUE,
    creado_en       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    actualizado_en  TIMESTAMPTZ   NOT NULL DEFAULT now(),
    eliminado_en    TIMESTAMPTZ,
    UNIQUE (ciclo_id, nivel_id, concepto)
);
COMMENT ON COLUMN tarifa.activa IS
'Funcional: FALSE = tarifa vigente reemplazada. Tarifas históricas siguen apuntando aquí.';

CREATE TABLE IF NOT EXISTS calendario_pago (
    calendario_pago_id SERIAL        PRIMARY KEY,
    alumno_id          INT           NOT NULL REFERENCES alumno(alumno_id) ON DELETE RESTRICT,
    ciclo_id           INT           NOT NULL REFERENCES ciclo_escolar(ciclo_id) ON DELETE RESTRICT,
    concepto           VARCHAR(15)   NOT NULL
                       CHECK (concepto IN ('inscripcion','colegiatura','material','uniforme','arancel','otro')),
    mes                VARCHAR(15),
    fecha_vencimiento  DATE          NOT NULL,
    monto_original     NUMERIC(12,2) NOT NULL CHECK (monto_original >= 0),
    monto_pagado       NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (monto_pagado >= 0),
    monto_recargo      NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (monto_recargo >= 0),
    saldo_pendiente    NUMERIC(12,2) GENERATED ALWAYS AS
                       (monto_original + monto_recargo - monto_pagado) STORED,
    estado_cobro       VARCHAR(15)   NOT NULL DEFAULT 'pendiente'
                       CHECK (estado_cobro IN ('pendiente','parcial','pagado','vencido','condonado')),
    liquidado_at       TIMESTAMPTZ,
    creado_en          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    actualizado_en     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    eliminado_en       TIMESTAMPTZ,
    UNIQUE (alumno_id, ciclo_id, concepto, mes)
);
COMMENT ON COLUMN calendario_pago.estado_cobro IS
'Funcional: pendiente/parcial/pagado/vencido/condonado.';
COMMENT ON COLUMN calendario_pago.eliminado_en IS
'Administrativa: cargo generado por error y cancelado. Diferente de "condonado" (decisión de negocio).';

-- Categoría A
CREATE TABLE IF NOT EXISTS pago (
    pago_id          SERIAL        PRIMARY KEY,
    alumno_id        INT           REFERENCES alumno(alumno_id) ON DELETE RESTRICT,
    tutor_id         INT           REFERENCES tutor(tutor_id) ON DELETE RESTRICT,
    fecha_pago       DATE          NOT NULL DEFAULT CURRENT_DATE,
    monto_total      NUMERIC(12,2) NOT NULL CHECK (monto_total > 0),
    metodo_pago      VARCHAR(15)   NOT NULL
                     CHECK (metodo_pago IN ('transferencia','deposito','tarjeta','efectivo')),
    aplicado_a_saldo BOOLEAN       NOT NULL DEFAULT FALSE,
    observaciones    TEXT,
    registrado_por   INT           REFERENCES usuario(usuario_id) ON DELETE SET NULL,
    registrado_en    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    actualizado_en   TIMESTAMPTZ   NOT NULL DEFAULT now()
);
COMMENT ON TABLE pago IS
'Histórica (Categoría A): los pagos NO se borran. Errores se compensan con otro movimiento.';

CREATE TABLE IF NOT EXISTS aplicacion_pago (
    aplicacion_id        SERIAL        PRIMARY KEY,
    pago_id              INT           NOT NULL REFERENCES pago(pago_id) ON DELETE CASCADE,
    calendario_pago_id   INT           NOT NULL REFERENCES calendario_pago(calendario_pago_id) ON DELETE RESTRICT,
    monto_aplicado       NUMERIC(12,2) NOT NULL CHECK (monto_aplicado > 0),
    aplicado_a           VARCHAR(15)   NOT NULL DEFAULT 'capital'
                         CHECK (aplicado_a IN ('capital','recargo')),
    creado_en            TIMESTAMPTZ   NOT NULL DEFAULT now(),
    actualizado_en       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    UNIQUE (pago_id, calendario_pago_id, aplicado_a)
);

CREATE TABLE IF NOT EXISTS recargo (
    recargo_id          SERIAL        PRIMARY KEY,
    calendario_pago_id  INT           NOT NULL REFERENCES calendario_pago(calendario_pago_id) ON DELETE CASCADE,
    monto_original      NUMERIC(12,2) NOT NULL CHECK (monto_original >= 0),
    monto_actual        NUMERIC(12,2) NOT NULL CHECK (monto_actual   >= 0),
    estado              VARCHAR(15)   NOT NULL DEFAULT 'aplicado'
                        CHECK (estado IN ('aplicado','reducido','condonado')),
    motivo_modificacion TEXT,
    aplicado_en         DATE          NOT NULL DEFAULT CURRENT_DATE,
    modificado_por      INT           REFERENCES usuario(usuario_id) ON DELETE SET NULL,
    modificado_en       TIMESTAMPTZ,
    actualizado_en      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT chk_recargo_actual_no_excede_original CHECK (monto_actual <= monto_original)
);

CREATE TABLE IF NOT EXISTS movimiento_saldo (
    movimiento_id   SERIAL        PRIMARY KEY,
    tutor_id        INT           NOT NULL REFERENCES tutor(tutor_id) ON DELETE CASCADE,
    tipo            VARCHAR(15)   NOT NULL CHECK (tipo IN ('abono','aplicacion','reverso')),
    monto           NUMERIC(12,2) NOT NULL CHECK (monto > 0),
    pago_id         INT           REFERENCES pago(pago_id) ON DELETE RESTRICT,
    aplicacion_id   INT           REFERENCES aplicacion_pago(aplicacion_id) ON DELETE RESTRICT,
    descripcion     TEXT,
    creado_por      INT           REFERENCES usuario(usuario_id) ON DELETE SET NULL,
    creado_en       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    actualizado_en  TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- Factura con COMMENT blindado
CREATE TABLE IF NOT EXISTS factura (
    factura_id              SERIAL        PRIMARY KEY,
    tutor_id                INT           NOT NULL REFERENCES tutor(tutor_id) ON DELETE RESTRICT,
    numero_factura          VARCHAR(40)   UNIQUE,
    uuid_sat                UUID,
    fecha_emision           DATE          NOT NULL DEFAULT CURRENT_DATE,
    monto_total             NUMERIC(12,2) NOT NULL CHECK (monto_total > 0),
    receptor_rfc            VARCHAR(13)   NOT NULL,
    receptor_razon_social   VARCHAR(255)  NOT NULL,
    receptor_codigo_postal  VARCHAR(10)   NOT NULL,
    receptor_direccion      TEXT          NOT NULL,
    receptor_correo         CITEXT        NOT NULL,
    receptor_regimen_fiscal VARCHAR(10)   NOT NULL,
    uso_cfdi                VARCHAR(10),
    metodo_pago_sat         VARCHAR(10),
    forma_pago_sat          VARCHAR(10),
    estado                  VARCHAR(15)   NOT NULL DEFAULT 'emitida'
                            CHECK (estado IN ('emitida','cancelada','pendiente')),
    xml_documento_id        INT,
    pdf_documento_id        INT,
    emitida_por             INT           REFERENCES usuario(usuario_id) ON DELETE SET NULL,
    creada_en               TIMESTAMPTZ   NOT NULL DEFAULT now(),
    actualizado_en          TIMESTAMPTZ   NOT NULL DEFAULT now()
);
COMMENT ON TABLE factura IS
'CFDI 4.0 emitida por el colegio. NO es el XML del SAT (eso vive en documento.tipo=factura_xml). '
'Esta tabla modela: (1) la solicitud antes del timbrado, '
'(2) el ciclo de vida emitida/cancelada/pendiente, '
'(3) el vínculo N:M con pagos internos via factura_pago, '
'(4) el snapshot fiscal del receptor congelado al momento de emisión (CFDI 4.0 lo exige). '
'El XML es uno de los artefactos generados, referenciado por xml_documento_id. '
'La auditoría fiscal (CFF art. 30) exige conservar trazabilidad 5 años en índice consultable.';

CREATE TABLE IF NOT EXISTS factura_pago (
    factura_id     INT           NOT NULL REFERENCES factura(factura_id) ON DELETE CASCADE,
    pago_id        INT           NOT NULL REFERENCES pago(pago_id) ON DELETE RESTRICT,
    monto          NUMERIC(12,2) NOT NULL CHECK (monto > 0),
    creado_en      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ   NOT NULL DEFAULT now(),
    PRIMARY KEY (factura_id, pago_id)
);

-- =====================================================================
-- BLOQUE 10  Becas
--   beca = Categoría B; asignacion_beca, ventana, solicitud_beca = Categoría C
-- =====================================================================
CREATE TABLE IF NOT EXISTS beca (
    beca_id         SERIAL       PRIMARY KEY,
    nombre_beca     VARCHAR(60)  NOT NULL UNIQUE,
    criterio        VARCHAR(25)  NOT NULL
                    CHECK (criterio IN ('inscripcion_temprana','calificacion','hermanos','convenio','otro')),
    porcentaje      NUMERIC(5,2) NOT NULL CHECK (porcentaje BETWEEN 0 AND 100),
    descripcion     TEXT,
    creado_en       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    eliminado_en    TIMESTAMPTZ
);
COMMENT ON TABLE beca IS 'Catálogo. Categoría B: solo eliminado_en como fuente de baja.';

INSERT INTO beca (nombre_beca, criterio, porcentaje, descripcion) VALUES
    ('Beca por hermanos',      'hermanos',             15.00, 'Aplica cuando hay 2 o más alumnos en el colegio.'),
    ('Excelencia académica',   'calificacion',         20.00, 'Promedio mayor o igual a 9.5 en el ciclo previo.'),
    ('Inscripción temprana',   'inscripcion_temprana', 10.00, 'Liquidación de inscripción dentro de la ventana promocional.')
ON CONFLICT (nombre_beca) DO NOTHING;

-- solicitud_beca creada ANTES de asignacion_beca porque ésta la referencia
CREATE TABLE IF NOT EXISTS solicitud_beca (
    solicitud_id        SERIAL        PRIMARY KEY,
    alumno_id           INT           NOT NULL REFERENCES alumno(alumno_id) ON DELETE RESTRICT,
    beca_id             INT           NOT NULL REFERENCES beca(beca_id) ON DELETE RESTRICT,
    ciclo_id            INT           NOT NULL REFERENCES ciclo_escolar(ciclo_id) ON DELETE RESTRICT,
    motivo              TEXT          NOT NULL,
    estado              VARCHAR(15)   NOT NULL DEFAULT 'pendiente'
                        CHECK (estado IN ('pendiente','aprobada','rechazada')),
    solicitada_por      INT           REFERENCES usuario(usuario_id) ON DELETE SET NULL,
    resuelta_por        INT           REFERENCES usuario(usuario_id) ON DELETE SET NULL,
    observaciones       TEXT,
    fecha_solicitud     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    fecha_resolucion    TIMESTAMPTZ,
    creado_en           TIMESTAMPTZ   NOT NULL DEFAULT now(),
    actualizado_en      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    eliminado_en        TIMESTAMPTZ,
    CONSTRAINT chk_resolucion_coherente CHECK (
        (estado = 'pendiente' AND fecha_resolucion IS NULL AND resuelta_por IS NULL)
        OR (estado IN ('aprobada','rechazada') AND fecha_resolucion IS NOT NULL)
    )
);
COMMENT ON TABLE solicitud_beca IS
'Workflow RF-21: Gestor solicita → Administrador aprueba/rechaza.
La asignación se materializa en asignacion_beca al aprobar. Una vez resuelta,
la solicitud queda como historial inmutable (pendiente NO se elimina, se rechaza).';
COMMENT ON COLUMN solicitud_beca.solicitada_por IS
'Usuario que originó la solicitud (típicamente rol "empleado"/GESTOR del prototipo).';
COMMENT ON COLUMN solicitud_beca.resuelta_por IS
'Usuario que aprobó o rechazó (típicamente rol "administrador"/ADMIN del prototipo).';

CREATE TABLE IF NOT EXISTS asignacion_beca (
    asignacion_id     SERIAL       PRIMARY KEY,
    alumno_id         INT          NOT NULL REFERENCES alumno(alumno_id) ON DELETE RESTRICT,
    beca_id           INT          NOT NULL REFERENCES beca(beca_id) ON DELETE RESTRICT,
    ciclo_id          INT          NOT NULL REFERENCES ciclo_escolar(ciclo_id) ON DELETE RESTRICT,
    solicitud_id      INT          REFERENCES solicitud_beca(solicitud_id) ON DELETE SET NULL,
    estado            VARCHAR(15)  NOT NULL DEFAULT 'activa'
                      CHECK (estado IN ('activa','retirada','finalizada')),
    fecha_asignacion  DATE         NOT NULL DEFAULT CURRENT_DATE,
    fecha_retiro      DATE,
    motivo_retiro     TEXT,
    asignada_por      INT          REFERENCES usuario(usuario_id) ON DELETE SET NULL,
    retirada_por      INT          REFERENCES usuario(usuario_id) ON DELETE SET NULL,
    creado_en         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    eliminado_en      TIMESTAMPTZ,
    UNIQUE (alumno_id, beca_id, ciclo_id)
);
COMMENT ON COLUMN asignacion_beca.solicitud_id IS
'FK opcional a la solicitud que generó esta asignación.
NULL = asignación directa por admin (no pasó por workflow de solicitud)
o asignación legacy pre-v6.';

CREATE TABLE IF NOT EXISTS ventana_inscripcion_temprana (
    ventana_id      SERIAL       PRIMARY KEY,
    ciclo_id        INT          NOT NULL REFERENCES ciclo_escolar(ciclo_id) ON DELETE RESTRICT,
    fecha_inicio    DATE         NOT NULL,
    fecha_fin       DATE         NOT NULL,
    beca_id         INT          NOT NULL REFERENCES beca(beca_id) ON DELETE RESTRICT,
    activa          BOOLEAN      NOT NULL DEFAULT TRUE,
    creado_en       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    eliminado_en    TIMESTAMPTZ,
    CHECK (fecha_fin >= fecha_inicio)
);

-- =====================================================================
-- BLOQUE 11  Soporte
-- =====================================================================
CREATE TABLE IF NOT EXISTS documento (
    documento_id     SERIAL       PRIMARY KEY,
    tipo_documento   VARCHAR(25)  NOT NULL
                     CHECK (tipo_documento IN
                         ('comprobante_pago','curp_alumno','acta_nacimiento',
                          'comprobante_domicilio','factura_pdf','factura_xml','otro')),
    nombre_original  VARCHAR(255) NOT NULL,
    ruta_almacen     TEXT         NOT NULL,
    mime_type        VARCHAR(100) NOT NULL,
    tamano_bytes     BIGINT       NOT NULL CHECK (tamano_bytes > 0),
    hash_sha256      CHAR(64),
    alumno_id        INT          REFERENCES alumno(alumno_id) ON DELETE RESTRICT,
    tutor_id         INT          REFERENCES tutor(tutor_id) ON DELETE RESTRICT,
    pago_id          INT          REFERENCES pago(pago_id) ON DELETE RESTRICT,
    factura_id       INT          REFERENCES factura(factura_id) ON DELETE RESTRICT,
    subido_por       INT          REFERENCES usuario(usuario_id) ON DELETE SET NULL,
    subido_en        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CHECK (
        alumno_id IS NOT NULL OR tutor_id IS NOT NULL
        OR pago_id IS NOT NULL OR factura_id IS NOT NULL
    )
);

CREATE TABLE IF NOT EXISTS notificacion (
    notificacion_id          SERIAL       PRIMARY KEY,
    tipo                     VARCHAR(30)  NOT NULL
                             CHECK (tipo IN (
                                 'recordatorio_5dias','recordatorio_3dias',
                                 'inscripcion_dia55','recargo_aplicado',
                                 'beca_retirada','baja_temporal','otro'
                             )),
    canal                    VARCHAR(10)  NOT NULL DEFAULT 'email'
                             CHECK (canal IN ('email','interna','sms')),
    destinatario_tutor_id    INT          REFERENCES tutor(tutor_id) ON DELETE CASCADE,
    destinatario_email       CITEXT,
    destinatario_usuario_id  INT          REFERENCES usuario(usuario_id) ON DELETE CASCADE,
    asunto                   VARCHAR(160),
    cuerpo                   TEXT,
    estado                   VARCHAR(15)  NOT NULL DEFAULT 'pendiente'
                             CHECK (estado IN ('pendiente','enviada','fallida','leida')),
    intentos                 INT          NOT NULL DEFAULT 0 CHECK (intentos >= 0),
    error_ultimo             TEXT,
    programada_para          TIMESTAMPTZ,
    enviada_en               TIMESTAMPTZ,
    alumno_id                INT          REFERENCES alumno(alumno_id) ON DELETE RESTRICT,
    calendario_pago_id       INT          REFERENCES calendario_pago(calendario_pago_id) ON DELETE RESTRICT,
    creada_en                TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    eliminado_en             TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS intento_login (
    intento_id                SERIAL      PRIMARY KEY,
    usuario_id                INT         REFERENCES usuario(usuario_id) ON DELETE SET NULL,
    nombre_usuario_intentado  VARCHAR(80),
    exitoso                   BOOLEAN     NOT NULL,
    direccion_ip              INET,
    user_agent                TEXT,
    creado_en                 TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE intento_login IS
'Histórica pura (Categoría A). Solo INSERT. Sin actualizado_en porque nunca se modifica.';

CREATE TABLE IF NOT EXISTS log_auditoria (
    log_id          BIGSERIAL    PRIMARY KEY,
    usuario_id      INT          REFERENCES usuario(usuario_id) ON DELETE SET NULL,
    accion          VARCHAR(10)  NOT NULL CHECK (accion IN ('INSERT','UPDATE','DELETE')),
    tabla_afectada  VARCHAR(60)  NOT NULL,
    registro_id     VARCHAR(50),
    valores_antes   JSONB,
    valores_despues JSONB,
    fecha_hora      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    direccion_ip    INET,
    descripcion     TEXT
);
COMMENT ON TABLE log_auditoria IS
'Histórica pura (Categoría A). Solo INSERT. Sin actualizado_en por inmutabilidad estricta.';

-- =====================================================================
-- BLOQUE 12  FKs diferidas (factura → documento)
-- =====================================================================
ALTER TABLE factura
    ADD CONSTRAINT fk_factura_xml_doc
    FOREIGN KEY (xml_documento_id) REFERENCES documento(documento_id) ON DELETE SET NULL;

ALTER TABLE factura
    ADD CONSTRAINT fk_factura_pdf_doc
    FOREIGN KEY (pdf_documento_id) REFERENCES documento(documento_id) ON DELETE SET NULL;

-- =====================================================================
-- BLOQUE 13  Triggers de integridad (H-02, H-05, H-10)
-- =====================================================================
CREATE OR REPLACE FUNCTION fn_validar_ciclo_calificacion()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_ciclo_grupo   INT;
    v_ciclo_periodo INT;
BEGIN
    SELECT g.ciclo_id INTO v_ciclo_grupo
    FROM grupo_materia gm JOIN grupo g ON g.grupo_id = gm.grupo_id
    WHERE gm.grupo_materia_id = NEW.grupo_materia_id;

    SELECT ciclo_id INTO v_ciclo_periodo
    FROM periodo_evaluacion WHERE periodo_id = NEW.periodo_id;

    IF v_ciclo_grupo IS DISTINCT FROM v_ciclo_periodo THEN
        RAISE EXCEPTION
            'Inconsistencia de ciclo: grupo_materia pertenece al ciclo %, periodo al ciclo %.',
            v_ciclo_grupo, v_ciclo_periodo;
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_validar_ciclo_calificacion ON calificacion;
CREATE TRIGGER trg_validar_ciclo_calificacion
    BEFORE INSERT OR UPDATE ON calificacion
    FOR EACH ROW EXECUTE FUNCTION fn_validar_ciclo_calificacion();

CREATE OR REPLACE FUNCTION fn_validar_tutor_paga_alumno()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.tutor_id IS NOT NULL AND NEW.alumno_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM tutor_alumno
            WHERE tutor_id = NEW.tutor_id AND alumno_id = NEW.alumno_id
              AND activo = TRUE AND eliminado_en IS NULL
        ) THEN
            RAISE EXCEPTION 'El tutor_id % no es tutor activo del alumno_id %.',
                NEW.tutor_id, NEW.alumno_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_validar_tutor_paga ON pago;
CREATE TRIGGER trg_validar_tutor_paga
    BEFORE INSERT OR UPDATE ON pago
    FOR EACH ROW EXECUTE FUNCTION fn_validar_tutor_paga_alumno();

CREATE OR REPLACE FUNCTION fn_validar_personas_autorizadas()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE persona JSONB;
BEGIN
    IF NEW.personas_autorizadas IS NULL THEN RETURN NEW; END IF;
    FOR persona IN SELECT * FROM jsonb_array_elements(NEW.personas_autorizadas) LOOP
        IF NOT (persona ? 'nombre' AND persona ? 'parentesco') THEN
            RAISE EXCEPTION
                'Cada persona autorizada debe tener "nombre" y "parentesco". Recibido: %', persona;
        END IF;
    END LOOP;
    RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_validar_personas_autorizadas ON alumno;
CREATE TRIGGER trg_validar_personas_autorizadas
    BEFORE INSERT OR UPDATE OF personas_autorizadas ON alumno
    FOR EACH ROW EXECUTE FUNCTION fn_validar_personas_autorizadas();

-- =====================================================================
-- BLOQUE 14  Triggers de auditoría de filas (incluye nuevas tablas v6)
-- =====================================================================
DO $$
DECLARE
    t TEXT;
    tablas TEXT[] := ARRAY[
        -- Categoría B y C (con actualizado_en + eliminado_en)
        'usuario','rol','usuario_rol','nivel_educativo','ciclo_escolar',
        'grupo','materia','grupo_materia','periodo_evaluacion',
        'tutor','alumno','tutor_alumno','inscripcion_ciclo',
        'tarifa','calendario_pago','asignacion_beca','ventana_inscripcion_temprana',
        'beca','notificacion',
        'plan_pago','solicitud_beca',                    -- NUEVAS v6
        -- Categoría A (solo actualizado_en)
        'calificacion','asistencia','pago','aplicacion_pago','recargo',
        'movimiento_saldo','factura','factura_pago','documento'
    ];
BEGIN
    FOREACH t IN ARRAY tablas LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_actualizar_timestamp_%I ON %I;', t, t);
        EXECUTE format(
            'CREATE TRIGGER trg_actualizar_timestamp_%I
             BEFORE UPDATE ON %I
             FOR EACH ROW EXECUTE FUNCTION fn_actualizar_timestamp();',
            t, t
        );
    END LOOP;
END $$;

-- =====================================================================
-- BLOQUE 15  Índices estratégicos
-- =====================================================================
-- Tablas Categoría B/C con filtro parcial eliminado_en IS NULL
CREATE INDEX IF NOT EXISTS idx_alumno_activo_no_eliminado
    ON alumno (estado) WHERE estado = 'Activo' AND eliminado_en IS NULL;
CREATE INDEX IF NOT EXISTS idx_tutor_alumno_alumno
    ON tutor_alumno (alumno_id) WHERE activo = TRUE AND eliminado_en IS NULL;
CREATE INDEX IF NOT EXISTS idx_tutor_alumno_tutor
    ON tutor_alumno (tutor_id) WHERE activo = TRUE AND eliminado_en IS NULL;
CREATE INDEX IF NOT EXISTS idx_tutor_alumno_responsable
    ON tutor_alumno (alumno_id)
    WHERE es_responsable_financiero = TRUE AND activo = TRUE AND eliminado_en IS NULL;
CREATE INDEX IF NOT EXISTS idx_inscripcion_ciclo_estado
    ON inscripcion_ciclo (ciclo_id, estado_en_ciclo) WHERE eliminado_en IS NULL;
CREATE INDEX IF NOT EXISTS idx_inscripcion_ciclo_grupo
    ON inscripcion_ciclo (ciclo_id, grupo_id) WHERE eliminado_en IS NULL;
CREATE INDEX IF NOT EXISTS idx_inscripcion_estado_financiero
    ON inscripcion_ciclo (ciclo_id, estado_financiero)
    WHERE estado_financiero <> 'al_corriente' AND eliminado_en IS NULL;
CREATE INDEX IF NOT EXISTS idx_inscripcion_plan_pago
    ON inscripcion_ciclo (plan_pago_id) WHERE plan_pago_id IS NOT NULL AND eliminado_en IS NULL;
CREATE INDEX IF NOT EXISTS idx_tutor_requiere_factura
    ON tutor (requiere_factura)
    WHERE requiere_factura = TRUE AND eliminado_en IS NULL;
CREATE INDEX IF NOT EXISTS idx_calendario_pago_estado
    ON calendario_pago (alumno_id, estado_cobro) WHERE eliminado_en IS NULL;
CREATE INDEX IF NOT EXISTS idx_calendario_pago_vencim
    ON calendario_pago (fecha_vencimiento)
    WHERE estado_cobro <> 'pagado' AND eliminado_en IS NULL;
CREATE INDEX IF NOT EXISTS idx_beca_alumno_estado
    ON asignacion_beca (alumno_id, estado) WHERE eliminado_en IS NULL;
CREATE INDEX IF NOT EXISTS idx_usuario_rol_usuario
    ON usuario_rol (usuario_id) WHERE activo = TRUE AND eliminado_en IS NULL;
CREATE INDEX IF NOT EXISTS idx_grupo_materia_docente
    ON grupo_materia (docente_id) WHERE eliminado_en IS NULL;
CREATE INDEX IF NOT EXISTS idx_plan_pago_ciclo_activo
    ON plan_pago (ciclo_id) WHERE activo = TRUE AND eliminado_en IS NULL;
CREATE INDEX IF NOT EXISTS idx_solicitud_beca_pendientes
    ON solicitud_beca (fecha_solicitud DESC)
    WHERE estado = 'pendiente' AND eliminado_en IS NULL;
CREATE INDEX IF NOT EXISTS idx_solicitud_beca_alumno
    ON solicitud_beca (alumno_id, ciclo_id) WHERE eliminado_en IS NULL;

-- Tablas Categoría A
CREATE INDEX IF NOT EXISTS idx_pago_fecha             ON pago (fecha_pago DESC);
CREATE INDEX IF NOT EXISTS idx_pago_tutor             ON pago (tutor_id);
CREATE INDEX IF NOT EXISTS idx_calificacion_alumno_gm ON calificacion (alumno_id, grupo_materia_id);
CREATE INDEX IF NOT EXISTS idx_calificacion_periodo   ON calificacion (periodo_id);
CREATE INDEX IF NOT EXISTS idx_asistencia_gm_fecha    ON asistencia (grupo_materia_id, fecha DESC);
CREATE INDEX IF NOT EXISTS idx_asistencia_alumno      ON asistencia (alumno_id, fecha DESC);
CREATE INDEX IF NOT EXISTS idx_documento_pago         ON documento (pago_id);
CREATE INDEX IF NOT EXISTS idx_documento_alumno       ON documento (alumno_id);
CREATE INDEX IF NOT EXISTS idx_log_auditoria_fecha    ON log_auditoria (fecha_hora DESC);
CREATE INDEX IF NOT EXISTS idx_log_auditoria_tabla    ON log_auditoria (tabla_afectada, fecha_hora DESC);
CREATE INDEX IF NOT EXISTS idx_intento_login_user_fecha ON intento_login (usuario_id, creado_en DESC);
CREATE INDEX IF NOT EXISTS idx_notificacion_pendientes
    ON notificacion (estado, programada_para)
    WHERE estado = 'pendiente' AND eliminado_en IS NULL;

-- =====================================================================
-- BLOQUE 16  Verificación final
-- =====================================================================
DO $$
DECLARE
    total_tablas       INT;
    total_actualizado  INT;
    total_eliminado    INT;
    total_triggers     INT;
    tiene_plan_pago    INT;
    tiene_solicitud    INT;
    tiene_estado_fin   INT;
BEGIN
    SELECT COUNT(*) INTO total_tablas
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE';

    SELECT COUNT(*) INTO total_actualizado
    FROM information_schema.columns
    WHERE table_schema = 'public' AND column_name = 'actualizado_en';

    SELECT COUNT(*) INTO total_eliminado
    FROM information_schema.columns
    WHERE table_schema = 'public' AND column_name = 'eliminado_en';

    SELECT COUNT(DISTINCT trigger_name) INTO total_triggers
    FROM information_schema.triggers
    WHERE trigger_schema = 'public'
      AND trigger_name LIKE 'trg_actualizar_timestamp_%';

    SELECT COUNT(*) INTO tiene_plan_pago
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'plan_pago';

    SELECT COUNT(*) INTO tiene_solicitud
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'solicitud_beca';

    SELECT COUNT(*) INTO tiene_estado_fin
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'inscripcion_ciclo'
      AND column_name = 'estado_financiero';

    RAISE NOTICE '====== Esquema base v6 inicializado ======';
    RAISE NOTICE 'Tablas en public: % (esperadas 30)', total_tablas;
    RAISE NOTICE 'Tablas con actualizado_en: %', total_actualizado;
    RAISE NOTICE 'Tablas con eliminado_en: %', total_eliminado;
    RAISE NOTICE 'Triggers fn_actualizar_timestamp activos: % (esperados 30)', total_triggers;
    RAISE NOTICE 'Tabla plan_pago presente: % (esperado 1)', tiene_plan_pago;
    RAISE NOTICE 'Tabla solicitud_beca presente: % (esperado 1)', tiene_solicitud;
    RAISE NOTICE 'Columna estado_financiero en inscripcion_ciclo: % (esperado 1)', tiene_estado_fin;
    RAISE NOTICE 'Categorías: A (histórica), B (catálogo), C (negocio con estado).';
    RAISE NOTICE '==========================================';
END $$;

-- =====================================================================
-- FIN del archivo 01_esquema_base.sql v6
-- =====================================================================