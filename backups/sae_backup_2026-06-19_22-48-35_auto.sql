--
-- PostgreSQL database dump
--

\restrict KBrMb1vbqONtHkfIlIBzmp3EQukntT6twR4BDharCYvBXMJInJ6rpu6g0lbTiov

-- Dumped from database version 16.14
-- Dumped by pg_dump version 16.14

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: fn_actualizar_timestamp(); Type: FUNCTION; Schema: public; Owner: sae_admin
--

CREATE FUNCTION public.fn_actualizar_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.actualizado_en := now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_actualizar_timestamp() OWNER TO sae_admin;

--
-- Name: FUNCTION fn_actualizar_timestamp(); Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON FUNCTION public.fn_actualizar_timestamp() IS 'Trigger genérico BEFORE UPDATE. Actualiza la columna actualizado_en a now()
en cada modificación. Se aplica a TODAS las tablas con esa columna.';


--
-- Name: fn_audit_trigger(); Type: FUNCTION; Schema: public; Owner: sae_admin
--

CREATE FUNCTION public.fn_audit_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_usuario_id INT;
    v_ip         INET;
    v_pk_name    TEXT;
    v_pk_value   TEXT;
    v_antes      JSONB;
    v_despues    JSONB;
BEGIN
    -- 1.1 Nombre del PK pasado como argumento del trigger
    v_pk_name := TG_ARGV[0];
    IF v_pk_name IS NULL THEN
        RAISE EXCEPTION 'fn_audit_trigger requiere el nombre del PK como argumento';
    END IF;

    -- 1.2 Contexto de sesión (seteado por el backend con SET LOCAL)
    BEGIN
        v_usuario_id := current_setting('sae.usuario_id', true)::INT;
    EXCEPTION WHEN OTHERS THEN
        v_usuario_id := NULL;
    END;

    BEGIN
        v_ip := current_setting('sae.direccion_ip', true)::INET;
    EXCEPTION WHEN OTHERS THEN
        v_ip := NULL;
    END;

    -- 1.3 Snapshots según operación
    IF TG_OP = 'INSERT' THEN
        v_antes    := NULL;
        v_despues  := to_jsonb(NEW);
        v_pk_value := v_despues ->> v_pk_name;

    ELSIF TG_OP = 'UPDATE' THEN
        v_antes    := to_jsonb(OLD);
        v_despues  := to_jsonb(NEW);
        IF v_antes = v_despues THEN
            RETURN NEW;
        END IF;
        v_pk_value := v_despues ->> v_pk_name;

    ELSIF TG_OP = 'DELETE' THEN
        v_antes    := to_jsonb(OLD);
        v_despues  := NULL;
        v_pk_value := v_antes ->> v_pk_name;
    END IF;

    -- 1.4 Enmascarar campos sensibles. password_hash NUNCA debe quedar
    --     replicado en el log.
    IF TG_TABLE_NAME = 'usuario' THEN
        IF v_antes   IS NOT NULL THEN v_antes   := v_antes   - 'password_hash'; END IF;
        IF v_despues IS NOT NULL THEN v_despues := v_despues - 'password_hash'; END IF;
    END IF;

    -- 1.5 Insertar en log_auditoria (best effort: si falla, no rompe la
    --     transacción de negocio)
    BEGIN
        INSERT INTO log_auditoria (
            usuario_id,
            accion,
            tabla_afectada,
            registro_id,
            valores_antes,
            valores_despues,
            direccion_ip,
            descripcion
        ) VALUES (
            v_usuario_id,
            TG_OP,
            TG_TABLE_NAME,
            v_pk_value,
            v_antes,
            v_despues,
            v_ip,
            'Auditoría automática vía trigger fn_audit_trigger'
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Falló auditoría en %.%: %', TG_TABLE_NAME, TG_OP, SQLERRM;
    END;

    -- 1.6 Retornar registro apropiado
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;


ALTER FUNCTION public.fn_audit_trigger() OWNER TO sae_admin;

--
-- Name: FUNCTION fn_audit_trigger(); Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON FUNCTION public.fn_audit_trigger() IS 'Función genérica de auditoría. Registra INSERT/UPDATE/DELETE en log_auditoria.
Lee usuario_id e IP desde sae.usuario_id y sae.direccion_ip seteados por el
backend con SET LOCAL al inicio de cada transacción.';


--
-- Name: fn_validar_ciclo_calificacion(); Type: FUNCTION; Schema: public; Owner: sae_admin
--

CREATE FUNCTION public.fn_validar_ciclo_calificacion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


ALTER FUNCTION public.fn_validar_ciclo_calificacion() OWNER TO sae_admin;

--
-- Name: fn_validar_personas_autorizadas(); Type: FUNCTION; Schema: public; Owner: sae_admin
--

CREATE FUNCTION public.fn_validar_personas_autorizadas() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


ALTER FUNCTION public.fn_validar_personas_autorizadas() OWNER TO sae_admin;

--
-- Name: fn_validar_tutor_paga_alumno(); Type: FUNCTION; Schema: public; Owner: sae_admin
--

CREATE FUNCTION public.fn_validar_tutor_paga_alumno() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


ALTER FUNCTION public.fn_validar_tutor_paga_alumno() OWNER TO sae_admin;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: _prisma_migrations; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public._prisma_migrations (
    id character varying(36) NOT NULL,
    checksum character varying(64) NOT NULL,
    finished_at timestamp with time zone,
    migration_name character varying(255) NOT NULL,
    logs text,
    rolled_back_at timestamp with time zone,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    applied_steps_count integer DEFAULT 0 NOT NULL
);


ALTER TABLE public._prisma_migrations OWNER TO sae_admin;

--
-- Name: alumno; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.alumno (
    alumno_id integer NOT NULL,
    matricula character varying(30) NOT NULL,
    curp character varying(18),
    nombre_completo character varying(120) NOT NULL,
    fecha_nacimiento date,
    sexo character(1),
    nivel_id integer,
    estado character varying(20) DEFAULT 'Activo'::character varying NOT NULL,
    fecha_baja date,
    motivo_baja text,
    dia_limite_pago integer,
    personas_autorizadas jsonb DEFAULT '[]'::jsonb NOT NULL,
    observaciones text,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone NOT NULL,
    eliminado_en timestamp with time zone,
    CONSTRAINT alumno_dia_limite_pago_check CHECK (((dia_limite_pago >= 1) AND (dia_limite_pago <= 31))),
    CONSTRAINT alumno_estado_check CHECK (((estado)::text = ANY ((ARRAY['Activo'::character varying, 'Baja Temporal'::character varying, 'Baja Definitiva'::character varying, 'Egresado'::character varying])::text[]))),
    CONSTRAINT alumno_personas_autorizadas_check CHECK ((jsonb_typeof(personas_autorizadas) = 'array'::text)),
    CONSTRAINT alumno_sexo_check CHECK ((sexo = ANY (ARRAY['M'::bpchar, 'F'::bpchar, 'X'::bpchar])))
);


ALTER TABLE public.alumno OWNER TO sae_admin;

--
-- Name: TABLE alumno; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.alumno IS 'Expediente del alumno. Tutores asignados vía tutor_alumno (N:M).';


--
-- Name: COLUMN alumno.estado; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.alumno.estado IS 'Funcional: Activo / Baja Temporal / Baja Definitiva / Egresado. Estado dentro del negocio.';


--
-- Name: COLUMN alumno.eliminado_en; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.alumno.eliminado_en IS 'Administrativa: registro borrado por error. NO equivale a "Baja Definitiva" (esa es funcional).';


--
-- Name: alumno_alumno_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.alumno_alumno_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.alumno_alumno_id_seq OWNER TO sae_admin;

--
-- Name: alumno_alumno_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.alumno_alumno_id_seq OWNED BY public.alumno.alumno_id;


--
-- Name: aplicacion_pago; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.aplicacion_pago (
    aplicacion_id integer NOT NULL,
    pago_id integer NOT NULL,
    calendario_pago_id integer NOT NULL,
    monto_aplicado numeric(12,2) NOT NULL,
    aplicado_a character varying(15) DEFAULT 'capital'::character varying NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone NOT NULL,
    CONSTRAINT aplicacion_pago_aplicado_a_check CHECK (((aplicado_a)::text = ANY ((ARRAY['capital'::character varying, 'recargo'::character varying])::text[]))),
    CONSTRAINT aplicacion_pago_monto_aplicado_check CHECK ((monto_aplicado > (0)::numeric))
);


ALTER TABLE public.aplicacion_pago OWNER TO sae_admin;

--
-- Name: aplicacion_pago_aplicacion_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.aplicacion_pago_aplicacion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.aplicacion_pago_aplicacion_id_seq OWNER TO sae_admin;

--
-- Name: aplicacion_pago_aplicacion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.aplicacion_pago_aplicacion_id_seq OWNED BY public.aplicacion_pago.aplicacion_id;


--
-- Name: asignacion_beca; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.asignacion_beca (
    asignacion_id integer NOT NULL,
    alumno_id integer NOT NULL,
    beca_id integer NOT NULL,
    ciclo_id integer NOT NULL,
    solicitud_id integer,
    estado character varying(15) DEFAULT 'activa'::character varying NOT NULL,
    fecha_asignacion date DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_retiro date,
    motivo_retiro text,
    asignada_por integer,
    retirada_por integer,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone NOT NULL,
    eliminado_en timestamp with time zone,
    CONSTRAINT asignacion_beca_estado_check CHECK (((estado)::text = ANY ((ARRAY['activa'::character varying, 'retirada'::character varying, 'finalizada'::character varying])::text[])))
);


ALTER TABLE public.asignacion_beca OWNER TO sae_admin;

--
-- Name: COLUMN asignacion_beca.solicitud_id; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.asignacion_beca.solicitud_id IS 'FK opcional a la solicitud que generó esta asignación.
NULL = asignación directa por admin (no pasó por workflow de solicitud)
o asignación legacy pre-v6.';


--
-- Name: asignacion_beca_asignacion_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.asignacion_beca_asignacion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.asignacion_beca_asignacion_id_seq OWNER TO sae_admin;

--
-- Name: asignacion_beca_asignacion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.asignacion_beca_asignacion_id_seq OWNED BY public.asignacion_beca.asignacion_id;


--
-- Name: asistencia; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.asistencia (
    asistencia_id integer NOT NULL,
    alumno_id integer NOT NULL,
    grupo_materia_id integer NOT NULL,
    fecha date NOT NULL,
    estado character varying(10) NOT NULL,
    justificacion text,
    registrada_por integer,
    registrada_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone NOT NULL,
    CONSTRAINT asistencia_estado_check CHECK (((estado)::text = ANY ((ARRAY['presente'::character varying, 'ausente'::character varying, 'retardo'::character varying])::text[])))
);


ALTER TABLE public.asistencia OWNER TO sae_admin;

--
-- Name: TABLE asistencia; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.asistencia IS 'Histórica (Categoría A): la asistencia de un día NO se borra, se corrige con justificacion.';


--
-- Name: asistencia_asistencia_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.asistencia_asistencia_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.asistencia_asistencia_id_seq OWNER TO sae_admin;

--
-- Name: asistencia_asistencia_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.asistencia_asistencia_id_seq OWNED BY public.asistencia.asistencia_id;


--
-- Name: beca; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.beca (
    beca_id integer NOT NULL,
    nombre_beca character varying(60) NOT NULL,
    criterio character varying(25) NOT NULL,
    porcentaje numeric(5,2) NOT NULL,
    descripcion text,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone NOT NULL,
    eliminado_en timestamp with time zone,
    CONSTRAINT beca_criterio_check CHECK (((criterio)::text = ANY ((ARRAY['inscripcion_temprana'::character varying, 'calificacion'::character varying, 'hermanos'::character varying, 'convenio'::character varying, 'otro'::character varying])::text[]))),
    CONSTRAINT beca_porcentaje_check CHECK (((porcentaje >= (0)::numeric) AND (porcentaje <= (100)::numeric)))
);


ALTER TABLE public.beca OWNER TO sae_admin;

--
-- Name: TABLE beca; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.beca IS 'Catálogo. Categoría B: solo eliminado_en como fuente de baja.';


--
-- Name: beca_beca_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.beca_beca_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.beca_beca_id_seq OWNER TO sae_admin;

--
-- Name: beca_beca_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.beca_beca_id_seq OWNED BY public.beca.beca_id;


--
-- Name: calendario_pago; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.calendario_pago (
    calendario_pago_id integer NOT NULL,
    alumno_id integer NOT NULL,
    ciclo_id integer NOT NULL,
    concepto character varying(15) NOT NULL,
    mes character varying(15),
    fecha_vencimiento date NOT NULL,
    monto_original numeric(12,2) NOT NULL,
    monto_pagado numeric(12,2) DEFAULT 0 NOT NULL,
    monto_recargo numeric(12,2) DEFAULT 0 NOT NULL,
    saldo_pendiente numeric(12,2) GENERATED ALWAYS AS (((monto_original + monto_recargo) - monto_pagado)) STORED,
    estado_cobro character varying(15) DEFAULT 'pendiente'::character varying NOT NULL,
    liquidado_at timestamp with time zone,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    eliminado_en timestamp with time zone,
    CONSTRAINT calendario_pago_concepto_check CHECK (((concepto)::text = ANY ((ARRAY['inscripcion'::character varying, 'colegiatura'::character varying, 'material'::character varying, 'uniforme'::character varying, 'arancel'::character varying, 'otro'::character varying])::text[]))),
    CONSTRAINT calendario_pago_estado_cobro_check CHECK (((estado_cobro)::text = ANY ((ARRAY['pendiente'::character varying, 'parcial'::character varying, 'pagado'::character varying, 'vencido'::character varying, 'condonado'::character varying])::text[]))),
    CONSTRAINT calendario_pago_monto_original_check CHECK ((monto_original >= (0)::numeric)),
    CONSTRAINT calendario_pago_monto_pagado_check CHECK ((monto_pagado >= (0)::numeric)),
    CONSTRAINT calendario_pago_monto_recargo_check CHECK ((monto_recargo >= (0)::numeric))
);


ALTER TABLE public.calendario_pago OWNER TO sae_admin;

--
-- Name: COLUMN calendario_pago.estado_cobro; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.calendario_pago.estado_cobro IS 'Funcional: pendiente/parcial/pagado/vencido/condonado.';


--
-- Name: COLUMN calendario_pago.eliminado_en; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.calendario_pago.eliminado_en IS 'Administrativa: cargo generado por error y cancelado. Diferente de "condonado" (decisión de negocio).';


--
-- Name: calendario_pago_calendario_pago_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.calendario_pago_calendario_pago_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.calendario_pago_calendario_pago_id_seq OWNER TO sae_admin;

--
-- Name: calendario_pago_calendario_pago_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.calendario_pago_calendario_pago_id_seq OWNED BY public.calendario_pago.calendario_pago_id;


--
-- Name: calificacion; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.calificacion (
    calificacion_id integer NOT NULL,
    alumno_id integer NOT NULL,
    grupo_materia_id integer NOT NULL,
    periodo_id integer NOT NULL,
    tipo_evaluacion character varying(15) DEFAULT 'numerica'::character varying NOT NULL,
    valor_numerico numeric(4,2),
    valor_cualitativo character varying(5),
    texto_observacion text,
    cuenta_para_promedio boolean DEFAULT true NOT NULL,
    modificada_motivo text,
    registrada_por integer,
    registrada_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT calificacion_tipo_evaluacion_check CHECK (((tipo_evaluacion)::text = ANY ((ARRAY['numerica'::character varying, 'cualitativa'::character varying, 'observacion'::character varying])::text[]))),
    CONSTRAINT calificacion_valor_cualitativo_check CHECK (((valor_cualitativo IS NULL) OR ((valor_cualitativo)::text = ANY ((ARRAY['A'::character varying, 'NA'::character varying])::text[])))),
    CONSTRAINT calificacion_valor_numerico_check CHECK (((valor_numerico IS NULL) OR ((valor_numerico >= (0)::numeric) AND (valor_numerico <= (10)::numeric)))),
    CONSTRAINT chk_calif_valor_por_tipo CHECK (((((tipo_evaluacion)::text = 'numerica'::text) AND (valor_numerico IS NOT NULL)) OR (((tipo_evaluacion)::text = 'cualitativa'::text) AND (valor_cualitativo IS NOT NULL)) OR (((tipo_evaluacion)::text = 'observacion'::text) AND (texto_observacion IS NOT NULL))))
);


ALTER TABLE public.calificacion OWNER TO sae_admin;

--
-- Name: TABLE calificacion; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.calificacion IS 'Histórica (Categoría A): NO usa eliminado_en. Correcciones requieren modificada_motivo.';


--
-- Name: calificacion_calificacion_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.calificacion_calificacion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.calificacion_calificacion_id_seq OWNER TO sae_admin;

--
-- Name: calificacion_calificacion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.calificacion_calificacion_id_seq OWNED BY public.calificacion.calificacion_id;


--
-- Name: calificacion_extracurricular; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.calificacion_extracurricular (
    calificacion_extracurricular_id integer NOT NULL,
    alumno_id integer NOT NULL,
    club character varying(50) NOT NULL,
    periodo_id integer NOT NULL,
    ciclo_id integer NOT NULL,
    valor_numerico numeric(4,2),
    modificada_motivo text,
    registrada_por integer,
    registrada_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.calificacion_extracurricular OWNER TO sae_admin;

--
-- Name: calificacion_extracurricular_calificacion_extracurricular_i_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.calificacion_extracurricular_calificacion_extracurricular_i_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.calificacion_extracurricular_calificacion_extracurricular_i_seq OWNER TO sae_admin;

--
-- Name: calificacion_extracurricular_calificacion_extracurricular_i_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.calificacion_extracurricular_calificacion_extracurricular_i_seq OWNED BY public.calificacion_extracurricular.calificacion_extracurricular_id;


--
-- Name: calificacion_taller; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.calificacion_taller (
    calificacion_taller_id integer NOT NULL,
    alumno_id integer NOT NULL,
    periodo_id integer NOT NULL,
    ciclo_id integer NOT NULL,
    valor_cualitativo character varying(5),
    modificada_motivo text,
    registrada_por integer,
    registrada_en timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    actualizado_en timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.calificacion_taller OWNER TO sae_admin;

--
-- Name: calificacion_taller_calificacion_taller_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.calificacion_taller_calificacion_taller_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.calificacion_taller_calificacion_taller_id_seq OWNER TO sae_admin;

--
-- Name: calificacion_taller_calificacion_taller_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.calificacion_taller_calificacion_taller_id_seq OWNED BY public.calificacion_taller.calificacion_taller_id;


--
-- Name: ciclo_escolar; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.ciclo_escolar (
    ciclo_id integer NOT NULL,
    nombre character varying(20) NOT NULL,
    fecha_inicio date NOT NULL,
    fecha_fin date NOT NULL,
    activo boolean DEFAULT false NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    eliminado_en timestamp with time zone,
    CONSTRAINT ciclo_escolar_check CHECK ((fecha_fin > fecha_inicio))
);


ALTER TABLE public.ciclo_escolar OWNER TO sae_admin;

--
-- Name: TABLE ciclo_escolar; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.ciclo_escolar IS 'Pivote temporal. Solo un ciclo activo a la vez (validar en backend).';


--
-- Name: COLUMN ciclo_escolar.activo; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.ciclo_escolar.activo IS 'Funcional: TRUE = ciclo en curso AHORA. NO confundir con eliminado_en (registro borrado).';


--
-- Name: ciclo_escolar_ciclo_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.ciclo_escolar_ciclo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ciclo_escolar_ciclo_id_seq OWNER TO sae_admin;

--
-- Name: ciclo_escolar_ciclo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.ciclo_escolar_ciclo_id_seq OWNED BY public.ciclo_escolar.ciclo_id;


--
-- Name: configuracion_sistema; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.configuracion_sistema (
    config_id integer NOT NULL,
    clave character varying(80) NOT NULL,
    valor text NOT NULL,
    tipo_dato character varying(20) DEFAULT 'string'::character varying NOT NULL,
    descripcion text,
    ciclo_id integer,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_por integer,
    CONSTRAINT configuracion_sistema_tipo_dato_check CHECK (((tipo_dato)::text = ANY ((ARRAY['string'::character varying, 'int'::character varying, 'decimal'::character varying, 'bool'::character varying, 'json'::character varying])::text[])))
);


ALTER TABLE public.configuracion_sistema OWNER TO sae_admin;

--
-- Name: TABLE configuracion_sistema; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.configuracion_sistema IS 'Parámetros configurables del sistema. El backend lee de aquí en lugar de
hardcodear valores. Soporta override por ciclo escolar (NULL = global).';


--
-- Name: COLUMN configuracion_sistema.clave; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.configuracion_sistema.clave IS 'Identificador del parámetro en snake_case. Ej: recargo_colegiatura_monto';


--
-- Name: COLUMN configuracion_sistema.valor; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.configuracion_sistema.valor IS 'Contenido siempre como texto. El backend lo convierte segun tipo_dato.';


--
-- Name: COLUMN configuracion_sistema.tipo_dato; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.configuracion_sistema.tipo_dato IS 'Indica al backend cómo parsear el valor: int, decimal, bool, json o string.';


--
-- Name: COLUMN configuracion_sistema.ciclo_id; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.configuracion_sistema.ciclo_id IS 'NULL = parámetro global. Si tiene valor, es override para ese ciclo.';


--
-- Name: configuracion_sistema_config_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.configuracion_sistema_config_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.configuracion_sistema_config_id_seq OWNER TO sae_admin;

--
-- Name: configuracion_sistema_config_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.configuracion_sistema_config_id_seq OWNED BY public.configuracion_sistema.config_id;


--
-- Name: documento; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.documento (
    documento_id integer NOT NULL,
    tipo_documento character varying(25) NOT NULL,
    nombre_original character varying(255) NOT NULL,
    ruta_almacen text NOT NULL,
    mime_type character varying(100) NOT NULL,
    tamano_bytes bigint NOT NULL,
    hash_sha256 character(64),
    alumno_id integer,
    tutor_id integer,
    pago_id integer,
    factura_id integer,
    subido_por integer,
    subido_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT documento_check CHECK (((alumno_id IS NOT NULL) OR (tutor_id IS NOT NULL) OR (pago_id IS NOT NULL) OR (factura_id IS NOT NULL))),
    CONSTRAINT documento_tamano_bytes_check CHECK ((tamano_bytes > 0)),
    CONSTRAINT documento_tipo_documento_check CHECK (((tipo_documento)::text = ANY ((ARRAY['comprobante_pago'::character varying, 'curp_alumno'::character varying, 'acta_nacimiento'::character varying, 'comprobante_domicilio'::character varying, 'factura_pdf'::character varying, 'factura_xml'::character varying, 'otro'::character varying])::text[])))
);


ALTER TABLE public.documento OWNER TO sae_admin;

--
-- Name: documento_documento_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.documento_documento_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.documento_documento_id_seq OWNER TO sae_admin;

--
-- Name: documento_documento_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.documento_documento_id_seq OWNED BY public.documento.documento_id;


--
-- Name: factura; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.factura (
    factura_id integer NOT NULL,
    tutor_id integer NOT NULL,
    numero_factura character varying(40),
    uuid_sat uuid,
    fecha_emision date DEFAULT CURRENT_DATE NOT NULL,
    monto_total numeric(12,2) NOT NULL,
    receptor_rfc character varying(13) NOT NULL,
    receptor_razon_social character varying(255) NOT NULL,
    receptor_codigo_postal character varying(10) NOT NULL,
    receptor_direccion text NOT NULL,
    receptor_correo public.citext NOT NULL,
    receptor_regimen_fiscal character varying(10) NOT NULL,
    uso_cfdi character varying(10),
    metodo_pago_sat character varying(10),
    forma_pago_sat character varying(10),
    estado character varying(15) DEFAULT 'emitida'::character varying NOT NULL,
    xml_documento_id integer,
    pdf_documento_id integer,
    emitida_por integer,
    creada_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT factura_estado_check CHECK (((estado)::text = ANY ((ARRAY['emitida'::character varying, 'cancelada'::character varying, 'pendiente'::character varying])::text[]))),
    CONSTRAINT factura_monto_total_check CHECK ((monto_total > (0)::numeric))
);


ALTER TABLE public.factura OWNER TO sae_admin;

--
-- Name: TABLE factura; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.factura IS 'CFDI 4.0 emitida por el colegio. NO es el XML del SAT (eso vive en documento.tipo=factura_xml). Esta tabla modela: (1) la solicitud antes del timbrado, (2) el ciclo de vida emitida/cancelada/pendiente, (3) el vínculo N:M con pagos internos via factura_pago, (4) el snapshot fiscal del receptor congelado al momento de emisión (CFDI 4.0 lo exige). El XML es uno de los artefactos generados, referenciado por xml_documento_id. La auditoría fiscal (CFF art. 30) exige conservar trazabilidad 5 años en índice consultable.';


--
-- Name: factura_factura_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.factura_factura_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.factura_factura_id_seq OWNER TO sae_admin;

--
-- Name: factura_factura_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.factura_factura_id_seq OWNED BY public.factura.factura_id;


--
-- Name: factura_pago; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.factura_pago (
    factura_id integer NOT NULL,
    pago_id integer NOT NULL,
    monto numeric(12,2) NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT factura_pago_monto_check CHECK ((monto > (0)::numeric))
);


ALTER TABLE public.factura_pago OWNER TO sae_admin;

--
-- Name: grupo; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.grupo (
    grupo_id integer NOT NULL,
    ciclo_id integer NOT NULL,
    nivel_id integer NOT NULL,
    grado character varying(10) NOT NULL,
    seccion character varying(5) NOT NULL,
    nombre character varying(60) NOT NULL,
    docente_titular_id integer,
    cupo_maximo integer,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    eliminado_en timestamp with time zone,
    CONSTRAINT grupo_cupo_maximo_check CHECK (((cupo_maximo IS NULL) OR (cupo_maximo > 0)))
);


ALTER TABLE public.grupo OWNER TO sae_admin;

--
-- Name: TABLE grupo; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.grupo IS 'Grupos por ciclo: combinación nivel+grado+sección con docente titular.';


--
-- Name: grupo_grupo_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.grupo_grupo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.grupo_grupo_id_seq OWNER TO sae_admin;

--
-- Name: grupo_grupo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.grupo_grupo_id_seq OWNED BY public.grupo.grupo_id;


--
-- Name: grupo_materia; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.grupo_materia (
    grupo_materia_id integer NOT NULL,
    grupo_id integer NOT NULL,
    materia_id integer NOT NULL,
    docente_id integer,
    horario character varying(80),
    aula character varying(40),
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    eliminado_en timestamp with time zone
);


ALTER TABLE public.grupo_materia OWNER TO sae_admin;

--
-- Name: TABLE grupo_materia; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.grupo_materia IS 'N:M grupo↔materia. Calificaciones y asistencia se anclan aquí.';


--
-- Name: grupo_materia_grupo_materia_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.grupo_materia_grupo_materia_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.grupo_materia_grupo_materia_id_seq OWNER TO sae_admin;

--
-- Name: grupo_materia_grupo_materia_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.grupo_materia_grupo_materia_id_seq OWNED BY public.grupo_materia.grupo_materia_id;


--
-- Name: inscripcion_ciclo; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.inscripcion_ciclo (
    inscripcion_id integer NOT NULL,
    alumno_id integer NOT NULL,
    ciclo_id integer NOT NULL,
    grupo_id integer NOT NULL,
    plan_pago character varying(10) DEFAULT '10_meses'::character varying NOT NULL,
    plan_pago_id integer,
    fecha_ingreso date DEFAULT CURRENT_DATE NOT NULL,
    es_ingreso_tardio boolean DEFAULT false NOT NULL,
    estado_en_ciclo character varying(20) DEFAULT 'activa'::character varying NOT NULL,
    estado_financiero character varying(20) DEFAULT 'al_corriente'::character varying NOT NULL,
    meses_adeudo integer DEFAULT 0 NOT NULL,
    motivo_baja text,
    fecha_baja date,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    eliminado_en timestamp with time zone,
    CONSTRAINT inscripcion_ciclo_estado_en_ciclo_check CHECK (((estado_en_ciclo)::text = ANY (ARRAY[('activa'::character varying)::text, ('baja_temporal'::character varying)::text, ('baja_definitiva'::character varying)::text, ('egresado'::character varying)::text, ('promovido'::character varying)::text, ('transicion_pendiente'::character varying)::text]))),
    CONSTRAINT inscripcion_ciclo_estado_financiero_check CHECK (((estado_financiero)::text = ANY ((ARRAY['al_corriente'::character varying, 'aviso_preventivo'::character varying, 'examen_restringido'::character varying, 'baja_temporal'::character varying])::text[]))),
    CONSTRAINT inscripcion_ciclo_meses_adeudo_check CHECK ((meses_adeudo >= 0)),
    CONSTRAINT inscripcion_ciclo_plan_pago_check CHECK (((plan_pago)::text = ANY ((ARRAY['10_meses'::character varying, '12_meses'::character varying])::text[])))
);


ALTER TABLE public.inscripcion_ciclo OWNER TO sae_admin;

--
-- Name: TABLE inscripcion_ciclo; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.inscripcion_ciclo IS 'Historiza alumno×ciclo×grupo. Soporta promoción (RF-15) y consulta multi-ciclo (RF-55).';


--
-- Name: COLUMN inscripcion_ciclo.plan_pago; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.inscripcion_ciclo.plan_pago IS 'DEPRECATED desde v6. Mantenida por compatibilidad. La fuente de verdad es plan_pago_id.
Eliminar en v7 una vez backend y queries hayan migrado completamente.';


--
-- Name: COLUMN inscripcion_ciclo.plan_pago_id; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.inscripcion_ciclo.plan_pago_id IS 'FK al catálogo plan_pago. Fuente de verdad para montos mensuales y de diciembre.';


--
-- Name: COLUMN inscripcion_ciclo.estado_en_ciclo; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.inscripcion_ciclo.estado_en_ciclo IS 'Funcional ACADÉMICO: estado administrativo del alumno en este ciclo.
NO confundir con estado_financiero (que rastrea cumplimiento de pagos).';


--
-- Name: COLUMN inscripcion_ciclo.estado_financiero; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.inscripcion_ciclo.estado_financiero IS 'Funcional FINANCIERO: cumplimiento de pagos.
Transiciones automáticas por backend:
  al_corriente → aviso_preventivo  (1 mes adeudo)
  aviso_preventivo → examen_restringido (2 meses)
  examen_restringido → baja_temporal (3 meses) → además propaga estado_en_ciclo=baja_temporal (RF-32).';


--
-- Name: COLUMN inscripcion_ciclo.meses_adeudo; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.inscripcion_ciclo.meses_adeudo IS 'Contador denormalizado para vista de deudores. Backend lo recalcula al
registrar pago o ejecutar el job de cierre mensual.';


--
-- Name: inscripcion_ciclo_inscripcion_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.inscripcion_ciclo_inscripcion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.inscripcion_ciclo_inscripcion_id_seq OWNER TO sae_admin;

--
-- Name: inscripcion_ciclo_inscripcion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.inscripcion_ciclo_inscripcion_id_seq OWNED BY public.inscripcion_ciclo.inscripcion_id;


--
-- Name: inscripcion_materia; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.inscripcion_materia (
    inscripcion_materia_id integer NOT NULL,
    alumno_id integer NOT NULL,
    grupo_materia_id integer NOT NULL,
    creado_en timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.inscripcion_materia OWNER TO sae_admin;

--
-- Name: inscripcion_materia_inscripcion_materia_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.inscripcion_materia_inscripcion_materia_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.inscripcion_materia_inscripcion_materia_id_seq OWNER TO sae_admin;

--
-- Name: inscripcion_materia_inscripcion_materia_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.inscripcion_materia_inscripcion_materia_id_seq OWNED BY public.inscripcion_materia.inscripcion_materia_id;


--
-- Name: intento_login; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.intento_login (
    intento_id integer NOT NULL,
    usuario_id integer,
    nombre_usuario_intentado character varying(80),
    exitoso boolean NOT NULL,
    direccion_ip inet,
    user_agent text,
    creado_en timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.intento_login OWNER TO sae_admin;

--
-- Name: TABLE intento_login; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.intento_login IS 'Histórica pura (Categoría A). Solo INSERT. Sin actualizado_en porque nunca se modifica.';


--
-- Name: intento_login_intento_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.intento_login_intento_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.intento_login_intento_id_seq OWNER TO sae_admin;

--
-- Name: intento_login_intento_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.intento_login_intento_id_seq OWNED BY public.intento_login.intento_id;


--
-- Name: log_auditoria; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.log_auditoria (
    log_id bigint NOT NULL,
    usuario_id integer,
    accion character varying(10) NOT NULL,
    tabla_afectada character varying(60) NOT NULL,
    registro_id character varying(50),
    valores_antes jsonb,
    valores_despues jsonb,
    fecha_hora timestamp with time zone DEFAULT now() NOT NULL,
    direccion_ip inet,
    descripcion text,
    CONSTRAINT log_auditoria_accion_check CHECK (((accion)::text = ANY ((ARRAY['INSERT'::character varying, 'UPDATE'::character varying, 'DELETE'::character varying])::text[])))
);


ALTER TABLE public.log_auditoria OWNER TO sae_admin;

--
-- Name: TABLE log_auditoria; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.log_auditoria IS 'Histórica pura (Categoría A). Solo INSERT. Sin actualizado_en por inmutabilidad estricta.';


--
-- Name: log_auditoria_log_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.log_auditoria_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.log_auditoria_log_id_seq OWNER TO sae_admin;

--
-- Name: log_auditoria_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.log_auditoria_log_id_seq OWNED BY public.log_auditoria.log_id;


--
-- Name: materia; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.materia (
    materia_id integer NOT NULL,
    nivel_id integer NOT NULL,
    clave_sep character varying(20),
    nombre character varying(80) NOT NULL,
    descripcion text,
    horas_semanales integer,
    creditos numeric(4,1),
    tipo character varying(15) DEFAULT 'curricular'::character varying NOT NULL,
    cuenta_para_promedio boolean DEFAULT true NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    eliminado_en timestamp with time zone,
    CONSTRAINT materia_creditos_check CHECK (((creditos IS NULL) OR ((creditos >= (0)::numeric) AND (creditos <= (20)::numeric)))),
    CONSTRAINT materia_horas_semanales_check CHECK (((horas_semanales IS NULL) OR ((horas_semanales >= 0) AND (horas_semanales <= 50)))),
    CONSTRAINT materia_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['curricular'::character varying, 'club'::character varying, 'taller'::character varying])::text[])))
);


ALTER TABLE public.materia OWNER TO sae_admin;

--
-- Name: TABLE materia; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.materia IS 'Catálogo de materias. Categoría B: solo eliminado_en como fuente de baja.';


--
-- Name: materia_materia_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.materia_materia_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.materia_materia_id_seq OWNER TO sae_admin;

--
-- Name: materia_materia_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.materia_materia_id_seq OWNED BY public.materia.materia_id;


--
-- Name: movimiento_saldo; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.movimiento_saldo (
    movimiento_id integer NOT NULL,
    tutor_id integer NOT NULL,
    tipo character varying(15) NOT NULL,
    monto numeric(12,2) NOT NULL,
    pago_id integer,
    aplicacion_id integer,
    descripcion text,
    creado_por integer,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT movimiento_saldo_monto_check CHECK ((monto > (0)::numeric)),
    CONSTRAINT movimiento_saldo_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['abono'::character varying, 'aplicacion'::character varying, 'reverso'::character varying])::text[])))
);


ALTER TABLE public.movimiento_saldo OWNER TO sae_admin;

--
-- Name: movimiento_saldo_movimiento_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.movimiento_saldo_movimiento_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.movimiento_saldo_movimiento_id_seq OWNER TO sae_admin;

--
-- Name: movimiento_saldo_movimiento_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.movimiento_saldo_movimiento_id_seq OWNED BY public.movimiento_saldo.movimiento_id;


--
-- Name: nivel_educativo; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.nivel_educativo (
    nivel_id integer NOT NULL,
    codigo character varying(15) NOT NULL,
    nombre character varying(60) NOT NULL,
    rvoe character varying(40),
    orden integer NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    eliminado_en timestamp with time zone,
    CONSTRAINT nivel_educativo_orden_check CHECK ((orden > 0))
);


ALTER TABLE public.nivel_educativo OWNER TO sae_admin;

--
-- Name: TABLE nivel_educativo; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.nivel_educativo IS 'Catálogo. Categoría B: solo eliminado_en como fuente de baja.';


--
-- Name: nivel_educativo_nivel_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.nivel_educativo_nivel_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.nivel_educativo_nivel_id_seq OWNER TO sae_admin;

--
-- Name: nivel_educativo_nivel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.nivel_educativo_nivel_id_seq OWNED BY public.nivel_educativo.nivel_id;


--
-- Name: notificacion; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.notificacion (
    notificacion_id integer NOT NULL,
    tipo character varying(30) NOT NULL,
    canal character varying(10) DEFAULT 'email'::character varying NOT NULL,
    destinatario_tutor_id integer,
    destinatario_email public.citext,
    destinatario_usuario_id integer,
    asunto character varying(160),
    cuerpo text,
    estado character varying(15) DEFAULT 'pendiente'::character varying NOT NULL,
    intentos integer DEFAULT 0 NOT NULL,
    error_ultimo text,
    programada_para timestamp with time zone,
    enviada_en timestamp with time zone,
    alumno_id integer,
    calendario_pago_id integer,
    creada_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    eliminado_en timestamp with time zone,
    CONSTRAINT notificacion_canal_check CHECK (((canal)::text = ANY ((ARRAY['email'::character varying, 'interna'::character varying, 'sms'::character varying])::text[]))),
    CONSTRAINT notificacion_estado_check CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'enviada'::character varying, 'fallida'::character varying, 'leida'::character varying])::text[]))),
    CONSTRAINT notificacion_intentos_check CHECK ((intentos >= 0)),
    CONSTRAINT notificacion_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['recordatorio_5dias'::character varying, 'recordatorio_3dias'::character varying, 'inscripcion_dia55'::character varying, 'recargo_aplicado'::character varying, 'beca_retirada'::character varying, 'baja_temporal'::character varying, 'otro'::character varying])::text[])))
);


ALTER TABLE public.notificacion OWNER TO sae_admin;

--
-- Name: notificacion_notificacion_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.notificacion_notificacion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.notificacion_notificacion_id_seq OWNER TO sae_admin;

--
-- Name: notificacion_notificacion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.notificacion_notificacion_id_seq OWNED BY public.notificacion.notificacion_id;


--
-- Name: pago; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.pago (
    pago_id integer NOT NULL,
    alumno_id integer,
    tutor_id integer,
    fecha_pago date DEFAULT CURRENT_DATE NOT NULL,
    monto_total numeric(12,2) NOT NULL,
    metodo_pago character varying(15) NOT NULL,
    aplicado_a_saldo boolean DEFAULT false NOT NULL,
    observaciones text,
    registrado_por integer,
    registrado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT pago_metodo_pago_check CHECK (((metodo_pago)::text = ANY ((ARRAY['transferencia'::character varying, 'deposito'::character varying, 'tarjeta'::character varying, 'efectivo'::character varying])::text[]))),
    CONSTRAINT pago_monto_total_check CHECK ((monto_total > (0)::numeric))
);


ALTER TABLE public.pago OWNER TO sae_admin;

--
-- Name: TABLE pago; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.pago IS 'Histórica (Categoría A): los pagos NO se borran. Errores se compensan con otro movimiento.';


--
-- Name: pago_pago_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.pago_pago_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pago_pago_id_seq OWNER TO sae_admin;

--
-- Name: pago_pago_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.pago_pago_id_seq OWNED BY public.pago.pago_id;


--
-- Name: periodo_evaluacion; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.periodo_evaluacion (
    periodo_id integer NOT NULL,
    ciclo_id integer NOT NULL,
    nivel_id integer NOT NULL,
    tipo character varying(15) NOT NULL,
    numero integer NOT NULL,
    nombre character varying(40) NOT NULL,
    fecha_inicio date NOT NULL,
    fecha_fin date NOT NULL,
    es_final_ciclo boolean DEFAULT false NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    eliminado_en timestamp with time zone,
    CONSTRAINT periodo_evaluacion_check CHECK ((fecha_fin >= fecha_inicio)),
    CONSTRAINT periodo_evaluacion_numero_check CHECK ((numero > 0)),
    CONSTRAINT periodo_evaluacion_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['bloque'::character varying, 'trimestre'::character varying, 'bimestre'::character varying, 'semestre'::character varying, 'final'::character varying])::text[])))
);


ALTER TABLE public.periodo_evaluacion OWNER TO sae_admin;

--
-- Name: TABLE periodo_evaluacion; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.periodo_evaluacion IS 'Periodos por ciclo/nivel. Sin solapamiento de fechas (H-04).';


--
-- Name: periodo_evaluacion_periodo_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.periodo_evaluacion_periodo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.periodo_evaluacion_periodo_id_seq OWNER TO sae_admin;

--
-- Name: periodo_evaluacion_periodo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.periodo_evaluacion_periodo_id_seq OWNED BY public.periodo_evaluacion.periodo_id;


--
-- Name: plan_pago; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.plan_pago (
    plan_pago_id integer NOT NULL,
    ciclo_id integer NOT NULL,
    nombre character varying(40) NOT NULL,
    meses integer NOT NULL,
    monto_mensual numeric(12,2) NOT NULL,
    monto_diciembre numeric(12,2) NOT NULL,
    descripcion text,
    activo boolean DEFAULT true NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    eliminado_en timestamp with time zone,
    CONSTRAINT plan_pago_meses_check CHECK (((meses >= 1) AND (meses <= 12))),
    CONSTRAINT plan_pago_monto_diciembre_check CHECK ((monto_diciembre >= (0)::numeric)),
    CONSTRAINT plan_pago_monto_mensual_check CHECK ((monto_mensual >= (0)::numeric))
);


ALTER TABLE public.plan_pago OWNER TO sae_admin;

--
-- Name: TABLE plan_pago; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.plan_pago IS 'Catálogo de planes de pago por ciclo (10 meses, 12 meses, etc.).
Categoría C: activo (vigente para nuevas altas) coexiste con eliminado_en
(registro borrado administrativamente).';


--
-- Name: COLUMN plan_pago.monto_diciembre; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.plan_pago.monto_diciembre IS 'Cobro doble de diciembre (aguinaldo escolar). Política del colegio
San Diego — RF: el mes 12 cobra ~2x mensualidad ordinaria.';


--
-- Name: COLUMN plan_pago.activo; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.plan_pago.activo IS 'TRUE = disponible para nuevas inscripciones. FALSE = plan retirado pero
conserva vínculos históricos con inscripciones existentes.';


--
-- Name: plan_pago_plan_pago_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.plan_pago_plan_pago_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.plan_pago_plan_pago_id_seq OWNER TO sae_admin;

--
-- Name: plan_pago_plan_pago_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.plan_pago_plan_pago_id_seq OWNED BY public.plan_pago.plan_pago_id;


--
-- Name: recargo; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.recargo (
    recargo_id integer NOT NULL,
    calendario_pago_id integer NOT NULL,
    monto_original numeric(12,2) NOT NULL,
    monto_actual numeric(12,2) NOT NULL,
    estado character varying(15) DEFAULT 'aplicado'::character varying NOT NULL,
    motivo_modificacion text,
    aplicado_en date DEFAULT CURRENT_DATE NOT NULL,
    modificado_por integer,
    modificado_en timestamp with time zone,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_recargo_actual_no_excede_original CHECK ((monto_actual <= monto_original)),
    CONSTRAINT recargo_estado_check CHECK (((estado)::text = ANY ((ARRAY['aplicado'::character varying, 'reducido'::character varying, 'condonado'::character varying])::text[]))),
    CONSTRAINT recargo_monto_actual_check CHECK ((monto_actual >= (0)::numeric)),
    CONSTRAINT recargo_monto_original_check CHECK ((monto_original >= (0)::numeric))
);


ALTER TABLE public.recargo OWNER TO sae_admin;

--
-- Name: recargo_recargo_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.recargo_recargo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.recargo_recargo_id_seq OWNER TO sae_admin;

--
-- Name: recargo_recargo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.recargo_recargo_id_seq OWNED BY public.recargo.recargo_id;


--
-- Name: rol; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.rol (
    rol_id integer NOT NULL,
    codigo character varying(20) NOT NULL,
    nombre character varying(60) NOT NULL,
    descripcion text,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    eliminado_en timestamp with time zone
);


ALTER TABLE public.rol OWNER TO sae_admin;

--
-- Name: TABLE rol; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.rol IS 'Catálogo de roles. Categoría B: eliminado_en sustituye al antiguo "activo".';


--
-- Name: rol_rol_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.rol_rol_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.rol_rol_id_seq OWNER TO sae_admin;

--
-- Name: rol_rol_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.rol_rol_id_seq OWNED BY public.rol.rol_id;


--
-- Name: solicitud_beca; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.solicitud_beca (
    solicitud_id integer NOT NULL,
    alumno_id integer NOT NULL,
    beca_id integer NOT NULL,
    ciclo_id integer NOT NULL,
    motivo text NOT NULL,
    estado character varying(15) DEFAULT 'pendiente'::character varying NOT NULL,
    solicitada_por integer,
    resuelta_por integer,
    observaciones text,
    fecha_solicitud timestamp with time zone DEFAULT now() NOT NULL,
    fecha_resolucion timestamp with time zone,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    eliminado_en timestamp with time zone,
    CONSTRAINT chk_resolucion_coherente CHECK (((((estado)::text = 'pendiente'::text) AND (fecha_resolucion IS NULL) AND (resuelta_por IS NULL)) OR (((estado)::text = ANY ((ARRAY['aprobada'::character varying, 'rechazada'::character varying])::text[])) AND (fecha_resolucion IS NOT NULL)))),
    CONSTRAINT solicitud_beca_estado_check CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'aprobada'::character varying, 'rechazada'::character varying])::text[])))
);


ALTER TABLE public.solicitud_beca OWNER TO sae_admin;

--
-- Name: TABLE solicitud_beca; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.solicitud_beca IS 'Workflow RF-21: Gestor solicita → Administrador aprueba/rechaza.
La asignación se materializa en asignacion_beca al aprobar. Una vez resuelta,
la solicitud queda como historial inmutable (pendiente NO se elimina, se rechaza).';


--
-- Name: COLUMN solicitud_beca.solicitada_por; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.solicitud_beca.solicitada_por IS 'Usuario que originó la solicitud (típicamente rol "empleado"/GESTOR del prototipo).';


--
-- Name: COLUMN solicitud_beca.resuelta_por; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.solicitud_beca.resuelta_por IS 'Usuario que aprobó o rechazó (típicamente rol "administrador"/ADMIN del prototipo).';


--
-- Name: solicitud_beca_solicitud_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.solicitud_beca_solicitud_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.solicitud_beca_solicitud_id_seq OWNER TO sae_admin;

--
-- Name: solicitud_beca_solicitud_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.solicitud_beca_solicitud_id_seq OWNED BY public.solicitud_beca.solicitud_id;


--
-- Name: tarifa; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.tarifa (
    tarifa_id integer NOT NULL,
    ciclo_id integer NOT NULL,
    nivel_id integer NOT NULL,
    concepto character varying(15) NOT NULL,
    monto numeric(12,2) NOT NULL,
    descripcion text,
    activa boolean DEFAULT true NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    eliminado_en timestamp with time zone,
    CONSTRAINT tarifa_concepto_check CHECK (((concepto)::text = ANY ((ARRAY['inscripcion'::character varying, 'colegiatura'::character varying, 'material'::character varying, 'uniforme'::character varying, 'arancel'::character varying, 'otro'::character varying])::text[]))),
    CONSTRAINT tarifa_monto_check CHECK ((monto >= (0)::numeric))
);


ALTER TABLE public.tarifa OWNER TO sae_admin;

--
-- Name: COLUMN tarifa.activa; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.tarifa.activa IS 'Funcional: FALSE = tarifa vigente reemplazada. Tarifas históricas siguen apuntando aquí.';


--
-- Name: tarifa_tarifa_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.tarifa_tarifa_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tarifa_tarifa_id_seq OWNER TO sae_admin;

--
-- Name: tarifa_tarifa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.tarifa_tarifa_id_seq OWNED BY public.tarifa.tarifa_id;


--
-- Name: token_revocado; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.token_revocado (
    id integer NOT NULL,
    jti character varying(255) NOT NULL,
    revocado_en timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.token_revocado OWNER TO sae_admin;

--
-- Name: token_revocado_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.token_revocado_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.token_revocado_id_seq OWNER TO sae_admin;

--
-- Name: token_revocado_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.token_revocado_id_seq OWNED BY public.token_revocado.id;


--
-- Name: tutor; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.tutor (
    tutor_id integer NOT NULL,
    nombre_completo character varying(120) NOT NULL,
    correo_electronico public.citext,
    telefono character varying(15),
    direccion text,
    rfc character varying(13),
    curp character varying(18),
    regimen_fiscal character varying(10),
    uso_cfdi character varying(10),
    direccion_fiscal text,
    codigo_postal character varying(10),
    correo_facturacion public.citext,
    requiere_factura boolean DEFAULT false NOT NULL,
    tipo_pago_habitual character varying(15),
    saldo_a_favor numeric(12,2) DEFAULT 0 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    eliminado_en timestamp with time zone,
    CONSTRAINT tutor_saldo_a_favor_check CHECK ((saldo_a_favor >= (0)::numeric)),
    CONSTRAINT tutor_tipo_pago_habitual_check CHECK (((tipo_pago_habitual)::text = ANY ((ARRAY['transferencia'::character varying, 'deposito'::character varying, 'tarjeta'::character varying, 'efectivo'::character varying])::text[])))
);


ALTER TABLE public.tutor OWNER TO sae_admin;

--
-- Name: TABLE tutor; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.tutor IS 'Tutor del alumno: padre, madre, abuelo, tutor legal, etc.';


--
-- Name: COLUMN tutor.activo; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.tutor.activo IS 'Funcional: FALSE = tutor inactivo en el sistema (ej. familia ya no en el colegio).';


--
-- Name: COLUMN tutor.eliminado_en; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.tutor.eliminado_en IS 'Administrativa: registro eliminado por error de captura. NO confundir con activo.';


--
-- Name: tutor_alumno; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.tutor_alumno (
    tutor_alumno_id integer NOT NULL,
    tutor_id integer NOT NULL,
    alumno_id integer NOT NULL,
    tipo_relacion character varying(15) DEFAULT 'tutor'::character varying NOT NULL,
    es_responsable_financiero boolean DEFAULT false NOT NULL,
    puede_recoger boolean DEFAULT true NOT NULL,
    recibe_notificaciones boolean DEFAULT true NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    eliminado_en timestamp with time zone,
    CONSTRAINT tutor_alumno_tipo_relacion_check CHECK (((tipo_relacion)::text = ANY ((ARRAY['padre'::character varying, 'madre'::character varying, 'tutor_legal'::character varying, 'abuelo'::character varying, 'otro'::character varying, 'tutor'::character varying])::text[])))
);


ALTER TABLE public.tutor_alumno OWNER TO sae_admin;

--
-- Name: COLUMN tutor_alumno.activo; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.tutor_alumno.activo IS 'Funcional: FALSE = vínculo terminado (custodia transferida, divorcio, etc.). Historial preservado.';


--
-- Name: tutor_alumno_tutor_alumno_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.tutor_alumno_tutor_alumno_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tutor_alumno_tutor_alumno_id_seq OWNER TO sae_admin;

--
-- Name: tutor_alumno_tutor_alumno_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.tutor_alumno_tutor_alumno_id_seq OWNED BY public.tutor_alumno.tutor_alumno_id;


--
-- Name: tutor_tutor_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.tutor_tutor_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tutor_tutor_id_seq OWNER TO sae_admin;

--
-- Name: tutor_tutor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.tutor_tutor_id_seq OWNED BY public.tutor.tutor_id;


--
-- Name: usuario; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.usuario (
    usuario_id integer NOT NULL,
    nombre_usuario character varying(80) NOT NULL,
    nombre_completo character varying(120) NOT NULL,
    correo public.citext,
    telefono character varying(15),
    password_hash character varying(255) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    intentos_fallidos integer DEFAULT 0 NOT NULL,
    bloqueado_hasta timestamp with time zone,
    ultimo_acceso timestamp with time zone,
    debe_cambiar_pwd boolean DEFAULT false NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    eliminado_en timestamp with time zone,
    CONSTRAINT usuario_intentos_fallidos_check CHECK ((intentos_fallidos >= 0))
);


ALTER TABLE public.usuario OWNER TO sae_admin;

--
-- Name: TABLE usuario; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TABLE public.usuario IS 'Cuentas de acceso. Roles asignados vía usuario_rol (N:M).';


--
-- Name: COLUMN usuario.activo; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.usuario.activo IS 'Estado funcional: FALSE = cuenta deshabilitada por seguridad (puede reactivarse).';


--
-- Name: COLUMN usuario.eliminado_en; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.usuario.eliminado_en IS 'Marca administrativa: si NO es NULL, la fila se considera eliminada.';


--
-- Name: usuario_permiso_modulo; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.usuario_permiso_modulo (
    permiso_id integer NOT NULL,
    usuario_id integer NOT NULL,
    modulo character varying(30) NOT NULL,
    nivel character varying(10) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    creado_en timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    actualizado_en timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.usuario_permiso_modulo OWNER TO sae_admin;

--
-- Name: usuario_permiso_modulo_permiso_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.usuario_permiso_modulo_permiso_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.usuario_permiso_modulo_permiso_id_seq OWNER TO sae_admin;

--
-- Name: usuario_permiso_modulo_permiso_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.usuario_permiso_modulo_permiso_id_seq OWNED BY public.usuario_permiso_modulo.permiso_id;


--
-- Name: usuario_rol; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.usuario_rol (
    usuario_rol_id integer NOT NULL,
    usuario_id integer NOT NULL,
    rol_id integer NOT NULL,
    asignado_en timestamp with time zone DEFAULT now() NOT NULL,
    asignado_por integer,
    activo boolean DEFAULT true NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    eliminado_en timestamp with time zone
);


ALTER TABLE public.usuario_rol OWNER TO sae_admin;

--
-- Name: COLUMN usuario_rol.activo; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.usuario_rol.activo IS 'Vínculo vigente. FALSE = rol revocado pero la fila se conserva como historial.';


--
-- Name: COLUMN usuario_rol.eliminado_en; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON COLUMN public.usuario_rol.eliminado_en IS 'Eliminación administrativa de la asignación (error de captura, no revocación).';


--
-- Name: usuario_rol_usuario_rol_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.usuario_rol_usuario_rol_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.usuario_rol_usuario_rol_id_seq OWNER TO sae_admin;

--
-- Name: usuario_rol_usuario_rol_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.usuario_rol_usuario_rol_id_seq OWNED BY public.usuario_rol.usuario_rol_id;


--
-- Name: usuario_usuario_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.usuario_usuario_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.usuario_usuario_id_seq OWNER TO sae_admin;

--
-- Name: usuario_usuario_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.usuario_usuario_id_seq OWNED BY public.usuario.usuario_id;


--
-- Name: ventana_inscripcion_temprana; Type: TABLE; Schema: public; Owner: sae_admin
--

CREATE TABLE public.ventana_inscripcion_temprana (
    ventana_id integer NOT NULL,
    ciclo_id integer NOT NULL,
    fecha_inicio date NOT NULL,
    fecha_fin date NOT NULL,
    beca_id integer NOT NULL,
    activa boolean DEFAULT true NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    eliminado_en timestamp with time zone,
    CONSTRAINT ventana_inscripcion_temprana_check CHECK ((fecha_fin >= fecha_inicio))
);


ALTER TABLE public.ventana_inscripcion_temprana OWNER TO sae_admin;

--
-- Name: ventana_inscripcion_temprana_ventana_id_seq; Type: SEQUENCE; Schema: public; Owner: sae_admin
--

CREATE SEQUENCE public.ventana_inscripcion_temprana_ventana_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ventana_inscripcion_temprana_ventana_id_seq OWNER TO sae_admin;

--
-- Name: ventana_inscripcion_temprana_ventana_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sae_admin
--

ALTER SEQUENCE public.ventana_inscripcion_temprana_ventana_id_seq OWNED BY public.ventana_inscripcion_temprana.ventana_id;


--
-- Name: alumno alumno_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.alumno ALTER COLUMN alumno_id SET DEFAULT nextval('public.alumno_alumno_id_seq'::regclass);


--
-- Name: aplicacion_pago aplicacion_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.aplicacion_pago ALTER COLUMN aplicacion_id SET DEFAULT nextval('public.aplicacion_pago_aplicacion_id_seq'::regclass);


--
-- Name: asignacion_beca asignacion_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.asignacion_beca ALTER COLUMN asignacion_id SET DEFAULT nextval('public.asignacion_beca_asignacion_id_seq'::regclass);


--
-- Name: asistencia asistencia_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.asistencia ALTER COLUMN asistencia_id SET DEFAULT nextval('public.asistencia_asistencia_id_seq'::regclass);


--
-- Name: beca beca_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.beca ALTER COLUMN beca_id SET DEFAULT nextval('public.beca_beca_id_seq'::regclass);


--
-- Name: calendario_pago calendario_pago_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.calendario_pago ALTER COLUMN calendario_pago_id SET DEFAULT nextval('public.calendario_pago_calendario_pago_id_seq'::regclass);


--
-- Name: calificacion calificacion_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.calificacion ALTER COLUMN calificacion_id SET DEFAULT nextval('public.calificacion_calificacion_id_seq'::regclass);


--
-- Name: calificacion_extracurricular calificacion_extracurricular_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.calificacion_extracurricular ALTER COLUMN calificacion_extracurricular_id SET DEFAULT nextval('public.calificacion_extracurricular_calificacion_extracurricular_i_seq'::regclass);


--
-- Name: calificacion_taller calificacion_taller_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.calificacion_taller ALTER COLUMN calificacion_taller_id SET DEFAULT nextval('public.calificacion_taller_calificacion_taller_id_seq'::regclass);


--
-- Name: ciclo_escolar ciclo_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.ciclo_escolar ALTER COLUMN ciclo_id SET DEFAULT nextval('public.ciclo_escolar_ciclo_id_seq'::regclass);


--
-- Name: configuracion_sistema config_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.configuracion_sistema ALTER COLUMN config_id SET DEFAULT nextval('public.configuracion_sistema_config_id_seq'::regclass);


--
-- Name: documento documento_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.documento ALTER COLUMN documento_id SET DEFAULT nextval('public.documento_documento_id_seq'::regclass);


--
-- Name: factura factura_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.factura ALTER COLUMN factura_id SET DEFAULT nextval('public.factura_factura_id_seq'::regclass);


--
-- Name: grupo grupo_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.grupo ALTER COLUMN grupo_id SET DEFAULT nextval('public.grupo_grupo_id_seq'::regclass);


--
-- Name: grupo_materia grupo_materia_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.grupo_materia ALTER COLUMN grupo_materia_id SET DEFAULT nextval('public.grupo_materia_grupo_materia_id_seq'::regclass);


--
-- Name: inscripcion_ciclo inscripcion_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.inscripcion_ciclo ALTER COLUMN inscripcion_id SET DEFAULT nextval('public.inscripcion_ciclo_inscripcion_id_seq'::regclass);


--
-- Name: inscripcion_materia inscripcion_materia_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.inscripcion_materia ALTER COLUMN inscripcion_materia_id SET DEFAULT nextval('public.inscripcion_materia_inscripcion_materia_id_seq'::regclass);


--
-- Name: intento_login intento_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.intento_login ALTER COLUMN intento_id SET DEFAULT nextval('public.intento_login_intento_id_seq'::regclass);


--
-- Name: log_auditoria log_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.log_auditoria ALTER COLUMN log_id SET DEFAULT nextval('public.log_auditoria_log_id_seq'::regclass);


--
-- Name: materia materia_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.materia ALTER COLUMN materia_id SET DEFAULT nextval('public.materia_materia_id_seq'::regclass);


--
-- Name: movimiento_saldo movimiento_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.movimiento_saldo ALTER COLUMN movimiento_id SET DEFAULT nextval('public.movimiento_saldo_movimiento_id_seq'::regclass);


--
-- Name: nivel_educativo nivel_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.nivel_educativo ALTER COLUMN nivel_id SET DEFAULT nextval('public.nivel_educativo_nivel_id_seq'::regclass);


--
-- Name: notificacion notificacion_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.notificacion ALTER COLUMN notificacion_id SET DEFAULT nextval('public.notificacion_notificacion_id_seq'::regclass);


--
-- Name: pago pago_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.pago ALTER COLUMN pago_id SET DEFAULT nextval('public.pago_pago_id_seq'::regclass);


--
-- Name: periodo_evaluacion periodo_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.periodo_evaluacion ALTER COLUMN periodo_id SET DEFAULT nextval('public.periodo_evaluacion_periodo_id_seq'::regclass);


--
-- Name: plan_pago plan_pago_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.plan_pago ALTER COLUMN plan_pago_id SET DEFAULT nextval('public.plan_pago_plan_pago_id_seq'::regclass);


--
-- Name: recargo recargo_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.recargo ALTER COLUMN recargo_id SET DEFAULT nextval('public.recargo_recargo_id_seq'::regclass);


--
-- Name: rol rol_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.rol ALTER COLUMN rol_id SET DEFAULT nextval('public.rol_rol_id_seq'::regclass);


--
-- Name: solicitud_beca solicitud_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.solicitud_beca ALTER COLUMN solicitud_id SET DEFAULT nextval('public.solicitud_beca_solicitud_id_seq'::regclass);


--
-- Name: tarifa tarifa_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.tarifa ALTER COLUMN tarifa_id SET DEFAULT nextval('public.tarifa_tarifa_id_seq'::regclass);


--
-- Name: token_revocado id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.token_revocado ALTER COLUMN id SET DEFAULT nextval('public.token_revocado_id_seq'::regclass);


--
-- Name: tutor tutor_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.tutor ALTER COLUMN tutor_id SET DEFAULT nextval('public.tutor_tutor_id_seq'::regclass);


--
-- Name: tutor_alumno tutor_alumno_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.tutor_alumno ALTER COLUMN tutor_alumno_id SET DEFAULT nextval('public.tutor_alumno_tutor_alumno_id_seq'::regclass);


--
-- Name: usuario usuario_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.usuario ALTER COLUMN usuario_id SET DEFAULT nextval('public.usuario_usuario_id_seq'::regclass);


--
-- Name: usuario_permiso_modulo permiso_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.usuario_permiso_modulo ALTER COLUMN permiso_id SET DEFAULT nextval('public.usuario_permiso_modulo_permiso_id_seq'::regclass);


--
-- Name: usuario_rol usuario_rol_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.usuario_rol ALTER COLUMN usuario_rol_id SET DEFAULT nextval('public.usuario_rol_usuario_rol_id_seq'::regclass);


--
-- Name: ventana_inscripcion_temprana ventana_id; Type: DEFAULT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.ventana_inscripcion_temprana ALTER COLUMN ventana_id SET DEFAULT nextval('public.ventana_inscripcion_temprana_ventana_id_seq'::regclass);


--
-- Data for Name: _prisma_migrations; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public._prisma_migrations (id, checksum, finished_at, migration_name, logs, rolled_back_at, started_at, applied_steps_count) FROM stdin;
89dc72cb-a92b-40fd-91cb-34cd52c9bf97	02479478c8adf1f997b1002a8820afbb8414d5c63b8de3f563ef429169a69ad2	2026-06-12 06:01:18.593202+00	20260527000001_init_postgresql		\N	2026-06-12 06:01:18.593202+00	0
\.


--
-- Data for Name: alumno; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.alumno (alumno_id, matricula, curp, nombre_completo, fecha_nacimiento, sexo, nivel_id, estado, fecha_baja, motivo_baja, dia_limite_pago, personas_autorizadas, observaciones, creado_en, actualizado_en, eliminado_en) FROM stdin;
1	SDM-2022-0001	MELS170512MVZNPF01	Sofía Mendoza López	2017-05-12	F	2	Activo	\N	\N	\N	[{"nombre": "Roberto Mendoza Hernández", "parentesco": "padre"}, {"nombre": "Lucía López Vargas", "parentesco": "madre"}]	\N	2026-06-12 05:56:10.669773+00	2026-06-12 05:56:10.669773+00	\N
2	SDM-2020-0001	MELD140315HVZNPG07	Diego Mendoza López	2014-03-15	M	3	Activo	\N	\N	\N	[{"nombre": "Roberto Mendoza Hernández", "parentesco": "padre"}, {"nombre": "Lucía López Vargas", "parentesco": "madre"}]	\N	2026-06-12 05:56:10.669773+00	2026-06-12 05:56:10.669773+00	\N
3	SDM-2023-0001	ROAV180220MVZMGL05	Valeria Romero Aguilar	2018-02-20	F	2	Activo	\N	\N	\N	[{"nombre": "Carmen Aguilar Vásquez", "parentesco": "madre"}]	\N	2026-06-12 05:56:10.669773+00	2026-06-12 05:56:10.669773+00	\N
4	SDM-2021-0001	ROAS150408HVZMGB02	Sebastián Romero Aguilar	2015-04-08	M	2	Activo	\N	\N	\N	[{"nombre": "Carmen Aguilar Vásquez", "parentesco": "madre"}]	\N	2026-06-12 05:56:10.669773+00	2026-06-12 05:56:10.669773+00	\N
5	SDM-2019-0001	GORJ130715HVZNZR03	Jorge Andrés González Ruiz	2013-07-15	M	3	Activo	\N	\N	10	[{"nombre": "Jorge González Ramírez", "parentesco": "padre"}]	\N	2026-06-12 05:56:10.669773+00	2026-06-12 05:56:10.669773+00	\N
6	SDM-2024-0001	SOPD190422MVZTRN08	Daniela Soto Pérez	2019-04-22	F	2	Activo	\N	\N	\N	[{"nombre": "Patricia Soto Reyes", "parentesco": "madre"}]	\N	2026-06-12 05:56:10.669773+00	2026-06-12 05:56:10.669773+00	\N
7	SDM-2022-0002	SOPN160830MVZTRT02	Natalia Soto Pérez	2016-08-30	F	2	Activo	\N	\N	\N	[{"nombre": "Patricia Soto Reyes", "parentesco": "madre"}]	\N	2026-06-12 05:56:10.669773+00	2026-06-12 05:56:10.669773+00	\N
8	SDM-2020-0002	SOPE140111HVZTRM05	Emiliano Soto Pérez	2014-01-11	M	3	Activo	\N	\N	\N	[{"nombre": "Patricia Soto Reyes", "parentesco": "madre"}]	\N	2026-06-12 05:56:10.669773+00	2026-06-12 05:56:10.669773+00	\N
11	SDM-2020-0089	GORM140322MDFXXX01	María González Ruiz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-14 18:44:45.668+00	2026-06-14 18:44:45.668+00	\N
13	SDM-2019-0412	FELC190815HDFXXX01	Carlos Fernández López	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-14 18:44:45.746+00	2026-06-14 18:44:45.746+00	\N
14	SDM-2021-0055	\N	Sofía Ramírez Cruz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-14 18:44:45.772+00	2026-06-14 18:44:45.772+00	\N
15	SDM-2022-0099	\N	Miguel Torres Gómez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-14 18:44:45.79+00	2026-06-14 18:44:45.79+00	\N
18	SDM-2019-0277	\N	Valentina Castro Ruiz	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-14 18:44:45.856+00	2026-06-14 18:44:45.856+00	\N
38	TST-PRI-3A-ATQ4-5	TEST51108HDFXXX01	Santiago Vazquez Reyes	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.017+00	2026-06-15 20:52:46.017+00	\N
39	TST-PRI-3A-2BAH-6	TEST59199HDFXXX01	Mateo Diaz Diaz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.039+00	2026-06-15 20:52:46.039+00	\N
40	TST-PRI-3A-S2W0-7	TEST87339HDFXXX01	Natalia Martinez Flores	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.057+00	2026-06-15 20:52:46.057+00	\N
41	TST-PRI-3A-X7S4-8	TEST71356HDFXXX01	Alejandro Flores Diaz	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.076+00	2026-06-15 21:07:31.702328+00	\N
12	SDM-2020-0123	PEMJ140522HDFXXX01	Juan Pérez Morales	\N	\N	2	Baja Definitiva	\N	\N	\N	[]	[BAJA TEMPORAL 14/6/2026]: por joto	2026-06-14 18:44:45.719+00	2026-06-15 04:51:27.570681+00	2026-06-15 04:51:27.578+00
17	SDM-2018-0344	\N	Diego Martínez Soto	\N	\N	4	Baja Definitiva	\N	\N	\N	[]	[BAJA TEMPORAL 14/6/2026]: por jochis	2026-06-14 18:44:45.838+00	2026-06-15 04:54:21.317114+00	2026-06-15 04:54:21.322+00
42	TST-PRI-3A-2ALP-9	TEST3129HDFXXX01	Alejandro Cruz Martinez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.099+00	2026-06-15 20:52:46.099+00	\N
19	SDM-2018-0002	\N	pakito	2024-09-17	\N	\N	Activo	\N	\N	\N	[]	\N	2026-06-15 20:45:49.845+00	2026-06-15 20:45:49.845+00	\N
20	TST-PRI-2A-HCE3-0	TEST22941HDFXXX01	Mia Martinez Martinez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:51:50.023+00	2026-06-15 20:51:50.023+00	\N
21	TST-PRI-2A-BFF4-0	TEST54862HDFXXX01	Jose Reyes Sanchez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:07.927+00	2026-06-15 20:52:07.927+00	\N
22	TST-PRI-2A-MJHC-1	TEST76673HDFXXX01	Daniel Diaz Ramirez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:07.968+00	2026-06-15 20:52:07.968+00	\N
23	TST-PRI-2A-CEHQ-0	TEST34830HDFXXX01	Valeria Sanchez Diaz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:45.655+00	2026-06-15 20:52:45.655+00	\N
24	TST-PRI-2A-8GQB-1	TEST12633HDFXXX01	Maria Garcia Morales	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:45.707+00	2026-06-15 20:52:45.707+00	\N
25	TST-PRI-2A-DBOC-2	TEST20103HDFXXX01	Sebastian Ramirez Martinez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:45.728+00	2026-06-15 20:52:45.728+00	\N
26	TST-PRI-2A-UA1Y-3	TEST15455HDFXXX01	Renata Reyes Jimenez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:45.754+00	2026-06-15 20:52:45.754+00	\N
27	TST-PRI-2A-RZ3Z-4	TEST34522HDFXXX01	Nicolas Vazquez Gonzalez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:45.776+00	2026-06-15 20:52:45.776+00	\N
28	TST-PRI-2A-0UA0-5	TEST8319HDFXXX01	Isabella Flores Reyes	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:45.797+00	2026-06-15 20:52:45.797+00	\N
29	TST-PRI-2A-7KKH-6	TEST60194HDFXXX01	Gael Vazquez Flores	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:45.815+00	2026-06-15 20:52:45.815+00	\N
30	TST-PRI-2A-RBEV-7	TEST50217HDFXXX01	Matias Lopez Cruz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:45.835+00	2026-06-15 20:52:45.835+00	\N
31	TST-PRI-2A-V8J0-8	TEST80522HDFXXX01	Leonardo Ramirez Vazquez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:45.855+00	2026-06-15 20:52:45.855+00	\N
32	TST-PRI-2A-IG1Q-9	TEST17044HDFXXX01	Emiliano Jimenez Diaz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:45.876+00	2026-06-15 20:52:45.876+00	\N
33	TST-PRI-3A-JF45-0	TEST10729HDFXXX01	Mia Gomez Sanchez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:45.897+00	2026-06-15 20:52:45.897+00	\N
34	TST-PRI-3A-6E8Z-1	TEST71409HDFXXX01	Diego Reyes Reyes	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:45.918+00	2026-06-15 20:52:45.918+00	\N
35	TST-PRI-3A-QWKQ-2	TEST82676HDFXXX01	Regina Ramirez Ramirez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:45.939+00	2026-06-15 20:52:45.939+00	\N
36	TST-PRI-3A-GN3C-3	TEST78599HDFXXX01	Emiliano Garcia Garcia	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:45.967+00	2026-06-15 20:52:45.967+00	\N
37	TST-PRI-3A-2ZH3-4	TEST60768HDFXXX01	Diego Flores Reyes	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:45.997+00	2026-06-15 20:52:45.997+00	\N
43	TST-PRI-4A-Z01D-0	TEST87873HDFXXX01	Renata Flores Martinez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.12+00	2026-06-15 20:52:46.12+00	\N
44	TST-PRI-4A-XNOJ-1	TEST44671HDFXXX01	Mateo Martinez Diaz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.138+00	2026-06-15 20:52:46.138+00	\N
45	TST-PRI-4A-YLTA-2	TEST73669HDFXXX01	Matias Ramirez Perez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.185+00	2026-06-15 20:52:46.185+00	\N
46	TST-PRI-4A-T6IE-3	TEST38059HDFXXX01	Santiago Martinez Martinez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.207+00	2026-06-15 20:52:46.207+00	\N
47	TST-PRI-4A-53SC-4	TEST34122HDFXXX01	Sofia Morales Gonzalez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.225+00	2026-06-15 20:52:46.225+00	\N
48	TST-PRI-4A-4C9Z-5	TEST74715HDFXXX01	Gabriel Ramirez Garcia	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.247+00	2026-06-15 20:52:46.247+00	\N
49	TST-PRI-4A-00BT-6	TEST43716HDFXXX01	Mia Vazquez Lopez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.262+00	2026-06-15 20:52:46.262+00	\N
50	TST-PRI-4A-TK9S-7	TEST5302HDFXXX01	Isabella Gonzalez Cruz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.282+00	2026-06-15 20:52:46.282+00	\N
51	TST-PRI-4A-K1WR-8	TEST50711HDFXXX01	Renata Garcia Morales	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.303+00	2026-06-15 20:52:46.303+00	\N
52	TST-PRI-4A-695I-9	TEST74714HDFXXX01	Valentina Ramirez Morales	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.326+00	2026-06-15 20:52:46.326+00	\N
53	TST-PRI-5A-0QR8-0	TEST13413HDFXXX01	Valentina Morales Martinez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.344+00	2026-06-15 20:52:46.344+00	\N
54	TST-PRI-5A-7N51-1	TEST58709HDFXXX01	Alejandro Martinez Rodriguez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.358+00	2026-06-15 20:52:46.358+00	\N
16	SDM-2018-0301	\N	Ana Lucía Hernández	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-14 18:44:45.812+00	2026-06-15 21:46:08.176391+00	\N
55	TST-PRI-5A-K694-2	TEST24231HDFXXX01	Matias Perez Morales	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.377+00	2026-06-15 20:52:46.377+00	\N
56	TST-PRI-5A-G4V5-3	TEST65469HDFXXX01	Santiago Garcia Diaz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.403+00	2026-06-15 20:52:46.403+00	\N
57	TST-PRI-5A-1RJJ-4	TEST45694HDFXXX01	Victoria Ramirez Perez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.42+00	2026-06-15 20:52:46.42+00	\N
58	TST-PRI-5A-NL13-5	TEST75101HDFXXX01	Camila Vazquez Rodriguez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.439+00	2026-06-15 20:52:46.439+00	\N
59	TST-PRI-5A-BYRC-6	TEST97347HDFXXX01	Leonardo Gomez Cruz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.459+00	2026-06-15 20:52:46.459+00	\N
60	TST-PRI-5A-OPL2-7	TEST7329HDFXXX01	Renata Martinez Gomez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.477+00	2026-06-15 20:52:46.477+00	\N
61	TST-PRI-5A-9YCT-8	TEST17281HDFXXX01	Sebastian Vazquez Flores	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.496+00	2026-06-15 20:52:46.496+00	\N
62	TST-PRI-5A-G0JK-9	TEST78143HDFXXX01	Santiago Reyes Ramirez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.516+00	2026-06-15 20:52:46.516+00	\N
64	TST-PRI-6A-WXK9-1	TEST61711HDFXXX01	Santiago Morales Lopez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.551+00	2026-06-15 20:52:46.551+00	\N
65	TST-PRI-6A-UPWW-2	TEST88617HDFXXX01	Natalia Sanchez Vazquez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.57+00	2026-06-15 20:52:46.57+00	\N
66	TST-PRI-6A-XBLB-3	TEST29900HDFXXX01	Valentina Diaz Morales	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.589+00	2026-06-15 20:52:46.589+00	\N
67	TST-PRI-6A-4NSB-4	TEST1572HDFXXX01	Sebastian Lopez Jimenez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.604+00	2026-06-15 20:52:46.604+00	\N
68	TST-PRI-6A-8PUY-5	TEST88775HDFXXX01	Gabriel Vazquez Martinez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.624+00	2026-06-15 20:52:46.624+00	\N
69	TST-PRI-6A-6MTV-6	TEST22042HDFXXX01	Valeria Garcia Flores	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.638+00	2026-06-15 20:52:46.638+00	\N
70	TST-PRI-6A-SLP1-7	TEST41806HDFXXX01	Renata Rodriguez Garcia	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.659+00	2026-06-15 20:52:46.659+00	\N
71	TST-PRI-6A-TZ3A-8	TEST41888HDFXXX01	Alejandro Reyes Cruz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.684+00	2026-06-15 20:52:46.684+00	\N
72	TST-PRI-6A-ELCX-9	TEST93575HDFXXX01	Gabriel Jimenez Reyes	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.706+00	2026-06-15 20:52:46.706+00	\N
73	TST-SEC-1A-5BTC-0	TEST23636HDFXXX01	Renata Martinez Ramirez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.727+00	2026-06-15 20:52:46.727+00	\N
74	TST-SEC-1A-W0H1-1	TEST39012HDFXXX01	Daniel Rodriguez Gomez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.744+00	2026-06-15 20:52:46.744+00	\N
75	TST-SEC-1A-4PBT-2	TEST40080HDFXXX01	Alejandro Cruz Ramirez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.768+00	2026-06-15 20:52:46.768+00	\N
76	TST-SEC-1A-ED7X-3	TEST91964HDFXXX01	Daniel Vazquez Flores	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.788+00	2026-06-15 20:52:46.788+00	\N
77	TST-SEC-1A-Y29U-4	TEST35708HDFXXX01	Gael Ramirez Flores	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.802+00	2026-06-15 20:52:46.802+00	\N
78	TST-SEC-1A-HSX7-5	TEST9319HDFXXX01	Emiliano Perez Flores	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.821+00	2026-06-15 20:52:46.821+00	\N
79	TST-SEC-1A-JNLP-6	TEST81999HDFXXX01	Mia Morales Ramirez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.843+00	2026-06-15 20:52:46.843+00	\N
80	TST-SEC-1A-YKGG-7	TEST17408HDFXXX01	Thiago Lopez Vazquez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.863+00	2026-06-15 20:52:46.863+00	\N
81	TST-SEC-1A-3OMS-8	TEST20304HDFXXX01	Jose Rodriguez Lopez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.881+00	2026-06-15 20:52:46.881+00	\N
82	TST-SEC-1A-L1F2-9	TEST49428HDFXXX01	Thiago Reyes Perez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.897+00	2026-06-15 20:52:46.897+00	\N
83	TST-SEC-2A-JXPG-0	TEST36537HDFXXX01	Leonardo Rodriguez Gonzalez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.917+00	2026-06-15 20:52:46.917+00	\N
84	TST-SEC-2A-L2P4-1	TEST29261HDFXXX01	Natalia Gonzalez Lopez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.937+00	2026-06-15 20:52:46.937+00	\N
85	TST-SEC-2A-Z0YX-2	TEST28241HDFXXX01	Mateo Cruz Morales	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.96+00	2026-06-15 20:52:46.96+00	\N
86	TST-SEC-2A-56XF-3	TEST67509HDFXXX01	Isabella Flores Diaz	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.977+00	2026-06-15 20:52:46.977+00	\N
87	TST-SEC-2A-HJ6X-4	TEST39124HDFXXX01	Sofia Diaz Martinez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.994+00	2026-06-15 20:52:46.994+00	\N
88	TST-SEC-2A-AWQT-5	TEST12409HDFXXX01	Mateo Vazquez Flores	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:47.014+00	2026-06-15 20:52:47.014+00	\N
89	TST-SEC-2A-9MOU-6	TEST6414HDFXXX01	Gael Jimenez Gonzalez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:47.033+00	2026-06-15 20:52:47.033+00	\N
90	TST-SEC-2A-CIJP-7	TEST57148HDFXXX01	Matias Reyes Reyes	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:47.05+00	2026-06-15 20:52:47.05+00	\N
91	TST-SEC-2A-1CXL-8	TEST4337HDFXXX01	Gabriel Morales Gomez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:47.07+00	2026-06-15 20:52:47.07+00	\N
92	TST-SEC-2A-9B3A-9	TEST76578HDFXXX01	Sebastian Flores Rodriguez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:47.091+00	2026-06-15 20:52:47.091+00	\N
93	TST-SEC-3A-4RXN-0	TEST54318HDFXXX01	Emiliano Flores Gonzalez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:47.111+00	2026-06-15 20:52:47.111+00	\N
94	TST-SEC-3A-9BBZ-1	TEST13180HDFXXX01	Ximena Gonzalez Garcia	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:47.129+00	2026-06-15 20:52:47.129+00	\N
95	TST-SEC-3A-SLRT-2	TEST93135HDFXXX01	Jose Reyes Jimenez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:47.149+00	2026-06-15 20:52:47.149+00	\N
96	TST-SEC-3A-7PAP-3	TEST22097HDFXXX01	Valentina Martinez Vazquez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:47.169+00	2026-06-15 20:52:47.169+00	\N
97	TST-SEC-3A-PMJD-4	TEST83400HDFXXX01	Ximena Cruz Ramirez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:47.191+00	2026-06-15 20:52:47.191+00	\N
98	TST-SEC-3A-WX8D-5	TEST92388HDFXXX01	Maria Jimenez Martinez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:47.208+00	2026-06-15 20:52:47.208+00	\N
99	TST-SEC-3A-TZQH-6	TEST22180HDFXXX01	Renata Sanchez Gomez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:47.229+00	2026-06-15 20:52:47.229+00	\N
100	TST-SEC-3A-3FQF-7	TEST79312HDFXXX01	Valeria Sanchez Vazquez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:47.246+00	2026-06-15 20:52:47.246+00	\N
101	TST-SEC-3A-BT91-8	TEST68786HDFXXX01	Valeria Garcia Ramirez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:47.268+00	2026-06-15 20:52:47.268+00	\N
102	TST-SEC-3A-I3TU-9	TEST80312HDFXXX01	Jose Jimenez Martinez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:47.288+00	2026-06-15 20:52:47.288+00	\N
103	TST-PRI-4A-LBDD-0	TEST52135HDFXXX01	Alejandro Vazquez Flores	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:47.312+00	2026-06-15 20:52:47.312+00	\N
104	TST-PRI-2A-NH96-0	TEST99436HDFXXX01	Leonardo Reyes Sanchez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:07.836+00	2026-06-15 20:53:07.836+00	\N
105	TST-PRI-2A-UY1Y-1	TEST17120HDFXXX01	Santiago Sanchez Jimenez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:07.934+00	2026-06-15 20:53:07.934+00	\N
106	TST-PRI-2A-IIBU-2	TEST75955HDFXXX01	Isabella Reyes Rodriguez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:07.956+00	2026-06-15 20:53:07.956+00	\N
107	TST-PRI-2A-IF7T-3	TEST9954HDFXXX01	Jose Gonzalez Gonzalez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:07.98+00	2026-06-15 20:53:07.98+00	\N
108	TST-PRI-2A-JBEM-4	TEST92775HDFXXX01	Renata Ramirez Lopez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.002+00	2026-06-15 20:53:08.002+00	\N
109	TST-PRI-2A-PWTA-5	TEST31453HDFXXX01	Renata Flores Sanchez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.018+00	2026-06-15 20:53:08.018+00	\N
110	TST-PRI-2A-2LRM-6	TEST42885HDFXXX01	Isabella Jimenez Martinez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.044+00	2026-06-15 20:53:08.044+00	\N
111	TST-PRI-2A-EA4S-7	TEST51491HDFXXX01	Emiliano Perez Rodriguez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.078+00	2026-06-15 20:53:08.078+00	\N
112	TST-PRI-2A-JW6D-8	TEST36161HDFXXX01	Daniel Perez Cruz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.124+00	2026-06-15 20:53:08.124+00	\N
113	TST-PRI-2A-4Q8E-9	TEST96051HDFXXX01	Camila Lopez Flores	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.157+00	2026-06-15 20:53:08.157+00	\N
114	TST-PRI-3A-TOWP-0	TEST1280HDFXXX01	Santiago Gonzalez Flores	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.195+00	2026-06-15 20:53:08.195+00	\N
115	TST-PRI-3A-ORLS-1	TEST44694HDFXXX01	Ximena Vazquez Reyes	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.221+00	2026-06-15 20:53:08.221+00	\N
116	TST-PRI-3A-GHTN-2	TEST1433HDFXXX01	Matias Perez Gonzalez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.249+00	2026-06-15 20:53:08.249+00	\N
117	TST-PRI-3A-LNZE-3	TEST99483HDFXXX01	Regina Lopez Sanchez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.27+00	2026-06-15 20:53:08.27+00	\N
118	TST-PRI-3A-GI3H-4	TEST38841HDFXXX01	Maria Vazquez Lopez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.291+00	2026-06-15 20:53:08.291+00	\N
119	TST-PRI-3A-IFFG-5	TEST36836HDFXXX01	Gael Garcia Perez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.307+00	2026-06-15 20:53:08.307+00	\N
120	TST-PRI-3A-8VUP-6	TEST23309HDFXXX01	Sofia Lopez Jimenez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.33+00	2026-06-15 20:53:08.33+00	\N
121	TST-PRI-3A-MH3E-7	TEST95985HDFXXX01	Santiago Gomez Gomez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.467+00	2026-06-15 20:53:08.467+00	\N
122	TST-PRI-3A-HT9N-8	TEST18727HDFXXX01	Mateo Lopez Gomez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.491+00	2026-06-15 20:53:08.491+00	\N
123	TST-PRI-3A-J52H-9	TEST13586HDFXXX01	Emiliano Ramirez Cruz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.511+00	2026-06-15 20:53:08.511+00	\N
124	TST-PRI-4A-QLFQ-0	TEST94624HDFXXX01	Valeria Gomez Ramirez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.531+00	2026-06-15 20:53:08.531+00	\N
125	TST-PRI-4A-BKU5-1	TEST89761HDFXXX01	Emiliano Morales Perez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.553+00	2026-06-15 20:53:08.553+00	\N
126	TST-PRI-4A-ZCXA-2	TEST60572HDFXXX01	Isabella Diaz Garcia	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.584+00	2026-06-15 20:53:08.584+00	\N
127	TST-PRI-4A-NTLD-3	TEST32122HDFXXX01	Leonardo Ramirez Diaz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.602+00	2026-06-15 20:53:08.602+00	\N
128	TST-PRI-4A-OBZ8-4	TEST55041HDFXXX01	Regina Ramirez Gomez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.626+00	2026-06-15 20:53:08.626+00	\N
129	TST-PRI-4A-D4PV-5	TEST21181HDFXXX01	Regina Martinez Cruz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.645+00	2026-06-15 20:53:08.645+00	\N
130	TST-PRI-4A-8QE3-6	TEST9976HDFXXX01	Natalia Martinez Cruz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.663+00	2026-06-15 20:53:08.663+00	\N
131	TST-PRI-4A-KKH5-7	TEST76008HDFXXX01	Thiago Lopez Gomez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.684+00	2026-06-15 20:53:08.684+00	\N
132	TST-PRI-4A-B1XL-8	TEST54319HDFXXX01	Maria Morales Ramirez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.704+00	2026-06-15 20:53:08.704+00	\N
133	TST-PRI-4A-J3XT-9	TEST56036HDFXXX01	Ximena Cruz Rodriguez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.721+00	2026-06-15 20:53:08.721+00	\N
134	TST-PRI-5A-6APJ-0	TEST12033HDFXXX01	Gael Perez Perez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.743+00	2026-06-15 20:53:08.743+00	\N
135	TST-PRI-5A-WARF-1	TEST69323HDFXXX01	Gael Lopez Perez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.761+00	2026-06-15 20:53:08.761+00	\N
137	TST-PRI-5A-KLXC-3	TEST83596HDFXXX01	Gabriel Lopez Garcia	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.803+00	2026-06-15 20:53:08.803+00	\N
138	TST-PRI-5A-SQPU-4	TEST96274HDFXXX01	Alejandro Rodriguez Gomez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.827+00	2026-06-15 20:53:08.827+00	\N
139	TST-PRI-5A-5YXG-5	TEST76352HDFXXX01	Daniel Ramirez Rodriguez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.851+00	2026-06-15 20:53:08.851+00	\N
140	TST-PRI-5A-7XHQ-6	TEST68761HDFXXX01	Santiago Sanchez Gonzalez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.869+00	2026-06-15 20:53:08.869+00	\N
141	TST-PRI-5A-LVTF-7	TEST45123HDFXXX01	Mateo Gomez Cruz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.887+00	2026-06-15 20:53:08.887+00	\N
142	TST-PRI-5A-CEX3-8	TEST25727HDFXXX01	Sebastian Lopez Sanchez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.909+00	2026-06-15 20:53:08.909+00	\N
143	TST-PRI-5A-UZSQ-9	TEST30085HDFXXX01	Isabella Gomez Gonzalez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.932+00	2026-06-15 20:53:08.932+00	\N
144	TST-PRI-6A-DCMD-0	TEST79804HDFXXX01	Matias Vazquez Garcia	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.955+00	2026-06-15 20:53:08.955+00	\N
145	TST-PRI-6A-R8UK-1	TEST56576HDFXXX01	Sebastian Diaz Cruz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.975+00	2026-06-15 20:53:08.975+00	\N
146	TST-PRI-6A-7DJ1-2	TEST47223HDFXXX01	Valeria Rodriguez Lopez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.999+00	2026-06-15 20:53:08.999+00	\N
147	TST-PRI-6A-L86O-3	TEST28059HDFXXX01	Gael Vazquez Flores	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.026+00	2026-06-15 20:53:09.026+00	\N
148	TST-PRI-6A-JSFS-4	TEST26635HDFXXX01	Santiago Cruz Gonzalez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.046+00	2026-06-15 20:53:09.046+00	\N
149	TST-PRI-6A-JO5Q-5	TEST42604HDFXXX01	Natalia Martinez Ramirez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.068+00	2026-06-15 20:53:09.068+00	\N
150	TST-PRI-6A-0SES-6	TEST17145HDFXXX01	Renata Jimenez Vazquez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.098+00	2026-06-15 20:53:09.098+00	\N
151	TST-PRI-6A-L5A6-7	TEST15992HDFXXX01	Gabriel Vazquez Morales	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.127+00	2026-06-15 20:53:09.127+00	\N
152	TST-PRI-6A-3J08-8	TEST21447HDFXXX01	Daniel Morales Garcia	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.156+00	2026-06-15 20:53:09.156+00	\N
153	TST-PRI-6A-7NIQ-9	TEST34513HDFXXX01	Alejandro Gonzalez Diaz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.179+00	2026-06-15 20:53:09.179+00	\N
154	TST-SEC-1A-WYCB-0	TEST17453HDFXXX01	Diego Lopez Gonzalez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.206+00	2026-06-15 20:53:09.206+00	\N
155	TST-SEC-1A-CVOX-1	TEST92117HDFXXX01	Thiago Perez Perez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.226+00	2026-06-15 20:53:09.226+00	\N
156	TST-SEC-1A-E2CB-2	TEST52962HDFXXX01	Camila Reyes Gonzalez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.251+00	2026-06-15 20:53:09.251+00	\N
157	TST-SEC-1A-FB7R-3	TEST3776HDFXXX01	Santiago Jimenez Jimenez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.275+00	2026-06-15 20:53:09.275+00	\N
158	TST-SEC-1A-YYK8-4	TEST32582HDFXXX01	Daniel Lopez Vazquez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.291+00	2026-06-15 20:53:09.291+00	\N
159	TST-SEC-1A-CVJH-5	TEST49492HDFXXX01	Isabella Flores Lopez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.32+00	2026-06-15 20:53:09.32+00	\N
160	TST-SEC-1A-ZGES-6	TEST20800HDFXXX01	Mateo Perez Lopez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.343+00	2026-06-15 20:53:09.343+00	\N
161	TST-SEC-1A-SVGF-7	TEST55448HDFXXX01	Daniel Reyes Cruz	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.363+00	2026-06-15 20:53:09.363+00	\N
162	TST-SEC-1A-3AOO-8	TEST49794HDFXXX01	Sofia Gomez Sanchez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.389+00	2026-06-15 20:53:09.389+00	\N
163	TST-SEC-1A-MJC6-9	TEST56325HDFXXX01	Alejandro Flores Ramirez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.415+00	2026-06-15 20:53:09.415+00	\N
164	TST-SEC-2A-AZ9M-0	TEST8219HDFXXX01	Leonardo Flores Reyes	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.436+00	2026-06-15 20:53:09.436+00	\N
165	TST-SEC-2A-2879-1	TEST27203HDFXXX01	Regina Vazquez Martinez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.461+00	2026-06-15 20:53:09.461+00	\N
166	TST-SEC-2A-KL0R-2	TEST96198HDFXXX01	Regina Vazquez Garcia	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.484+00	2026-06-15 20:53:09.484+00	\N
167	TST-SEC-2A-AJIU-3	TEST69178HDFXXX01	Renata Vazquez Ramirez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.505+00	2026-06-15 20:53:09.505+00	\N
168	TST-SEC-2A-G9GI-4	TEST20300HDFXXX01	Valeria Flores Cruz	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.527+00	2026-06-15 20:53:09.527+00	\N
169	TST-SEC-2A-PGSZ-5	TEST70101HDFXXX01	Natalia Gomez Sanchez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.552+00	2026-06-15 20:53:09.552+00	\N
170	TST-SEC-2A-WUKU-6	TEST597HDFXXX01	Valentina Reyes Morales	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.578+00	2026-06-15 20:53:09.578+00	\N
171	TST-SEC-2A-O69G-7	TEST89171HDFXXX01	Victoria Garcia Reyes	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.597+00	2026-06-15 20:53:09.597+00	\N
172	TST-SEC-2A-UR8H-8	TEST47308HDFXXX01	Mia Ramirez Rodriguez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.619+00	2026-06-15 20:53:09.619+00	\N
173	TST-SEC-2A-NMRI-9	TEST64650HDFXXX01	Sofia Martinez Morales	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.642+00	2026-06-15 20:53:09.642+00	\N
174	TST-SEC-3A-24SN-0	TEST62446HDFXXX01	Alejandro Perez Rodriguez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.665+00	2026-06-15 20:53:09.665+00	\N
175	TST-SEC-3A-Q9ST-1	TEST60378HDFXXX01	Ximena Vazquez Ramirez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.69+00	2026-06-15 20:53:09.69+00	\N
176	TST-SEC-3A-B6SD-2	TEST85195HDFXXX01	Gael Rodriguez Rodriguez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.711+00	2026-06-15 20:53:09.711+00	\N
177	TST-SEC-3A-C3TT-3	TEST28313HDFXXX01	Jose Sanchez Lopez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.732+00	2026-06-15 20:53:09.732+00	\N
178	TST-SEC-3A-46AQ-4	TEST3710HDFXXX01	Valeria Gomez Rodriguez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.755+00	2026-06-15 20:53:09.755+00	\N
179	TST-SEC-3A-Q9AY-5	TEST56292HDFXXX01	Mia Jimenez Morales	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.778+00	2026-06-15 20:53:09.778+00	\N
180	TST-SEC-3A-AIHE-6	TEST99586HDFXXX01	Leonardo Lopez Reyes	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.796+00	2026-06-15 20:53:09.796+00	\N
181	TST-SEC-3A-1XUZ-7	TEST65585HDFXXX01	Isabella Vazquez Garcia	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.819+00	2026-06-15 20:53:09.819+00	\N
182	TST-SEC-3A-XESZ-8	TEST81795HDFXXX01	Gabriel Morales Garcia	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.842+00	2026-06-15 20:53:09.842+00	\N
183	TST-SEC-3A-VM4A-9	TEST21671HDFXXX01	Maria Diaz Perez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.865+00	2026-06-15 20:53:09.865+00	\N
184	TST-PRI-4A-FN46-0	TEST217HDFXXX01	Renata Ramirez Sanchez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.888+00	2026-06-15 20:53:09.888+00	\N
185	TST-PRI-4A-7Z47-1	TEST95802HDFXXX01	Emiliano Jimenez Jimenez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.911+00	2026-06-15 20:53:09.911+00	\N
186	TST-PRI-4A-ZKVZ-2	TEST10557HDFXXX01	Sebastian Vazquez Martinez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.929+00	2026-06-15 20:53:09.929+00	\N
187	TST-PRI-4A-2U8Z-3	TEST92828HDFXXX01	Natalia Reyes Perez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.952+00	2026-06-15 20:53:09.952+00	\N
188	TST-PRI-4A-N92Y-4	TEST49390HDFXXX01	Victoria Flores Lopez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:09.978+00	2026-06-15 20:53:09.978+00	\N
189	TST-PRI-4A-LX6E-5	TEST63991HDFXXX01	Gael Gonzalez Cruz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.003+00	2026-06-15 20:53:10.003+00	\N
190	TST-PRI-4A-E7UB-6	TEST11874HDFXXX01	Diego Perez Sanchez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.028+00	2026-06-15 20:53:10.028+00	\N
191	TST-PRI-4A-8Y5M-7	TEST31639HDFXXX01	Mateo Sanchez Cruz	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.049+00	2026-06-15 20:53:10.049+00	\N
192	TST-PRI-4A-DDIV-8	TEST28083HDFXXX01	Maria Lopez Sanchez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.069+00	2026-06-15 20:53:10.069+00	\N
193	TST-PRI-4A-EOJ3-9	TEST36415HDFXXX01	Mia Perez Jimenez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.096+00	2026-06-15 20:53:10.096+00	\N
194	TST-SEC-5B-SBET-0	TEST69634HDFXXX01	Camila Jimenez Ramirez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.118+00	2026-06-15 20:53:10.118+00	\N
195	TST-SEC-5B-0DR6-1	TEST8945HDFXXX01	Alejandro Sanchez Diaz	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.135+00	2026-06-15 20:53:10.135+00	\N
196	TST-SEC-5B-RTFW-2	TEST72177HDFXXX01	Thiago Vazquez Martinez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.159+00	2026-06-15 20:53:10.159+00	\N
197	TST-SEC-5B-GXTI-3	TEST86703HDFXXX01	Victoria Jimenez Lopez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.181+00	2026-06-15 20:53:10.181+00	\N
198	TST-SEC-5B-I9Z6-4	TEST71094HDFXXX01	Sebastian Gonzalez Jimenez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.2+00	2026-06-15 20:53:10.2+00	\N
199	TST-SEC-5B-K2ZV-5	TEST16182HDFXXX01	Victoria Vazquez Flores	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.219+00	2026-06-15 20:53:10.219+00	\N
200	TST-SEC-5B-F4MB-6	TEST87507HDFXXX01	Diego Jimenez Rodriguez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.243+00	2026-06-15 20:53:10.243+00	\N
201	TST-SEC-5B-4CSN-7	TEST63005HDFXXX01	Valeria Martinez Vazquez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.262+00	2026-06-15 20:53:10.262+00	\N
202	TST-SEC-5B-ZZX0-8	TEST89650HDFXXX01	Natalia Cruz Flores	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.285+00	2026-06-15 20:53:10.285+00	\N
203	TST-SEC-5B-8VKH-9	TEST69914HDFXXX01	Maria Morales Ramirez	\N	\N	3	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.303+00	2026-06-15 20:53:10.303+00	\N
204	TST-BAC-2A-Y88K-0	TEST66663HDFXXX01	Regina Flores Gomez	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.324+00	2026-06-15 20:53:10.324+00	\N
205	TST-BAC-2A-H15R-1	TEST17589HDFXXX01	Thiago Ramirez Ramirez	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.349+00	2026-06-15 20:53:10.349+00	\N
206	TST-BAC-2A-GAH7-2	TEST79584HDFXXX01	Daniel Gonzalez Gomez	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.369+00	2026-06-15 20:53:10.369+00	\N
207	TST-BAC-2A-S0BY-3	TEST62808HDFXXX01	Thiago Morales Martinez	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.394+00	2026-06-15 20:53:10.394+00	\N
208	TST-BAC-2A-13KQ-4	TEST23915HDFXXX01	Jose Ramirez Vazquez	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.418+00	2026-06-15 20:53:10.418+00	\N
209	TST-BAC-2A-XW4H-5	TEST94944HDFXXX01	Santiago Flores Sanchez	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.446+00	2026-06-15 20:53:10.446+00	\N
211	TST-BAC-2A-D9VX-7	TEST41758HDFXXX01	Valentina Martinez Flores	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.52+00	2026-06-15 20:53:10.52+00	\N
212	TST-BAC-2A-A9C2-8	TEST41679HDFXXX01	Jose Rodriguez Perez	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.549+00	2026-06-15 20:53:10.549+00	\N
213	TST-BAC-2A-TNMT-9	TEST92460HDFXXX01	Leonardo Sanchez Vazquez	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.568+00	2026-06-15 20:53:10.568+00	\N
214	TST-BAC-3B-27K4-0	TEST47459HDFXXX01	Matias Morales Gomez	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.588+00	2026-06-15 20:53:10.588+00	\N
215	TST-BAC-3B-T124-1	TEST22483HDFXXX01	Matias Martinez Flores	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.616+00	2026-06-15 20:53:10.616+00	\N
216	TST-BAC-3B-PXF4-2	TEST31505HDFXXX01	Regina Gomez Diaz	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.641+00	2026-06-15 20:53:10.641+00	\N
217	TST-BAC-3B-451U-3	TEST49112HDFXXX01	Santiago Ramirez Gonzalez	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.663+00	2026-06-15 20:53:10.663+00	\N
218	TST-BAC-3B-SOPY-4	TEST32777HDFXXX01	Alejandro Morales Diaz	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.686+00	2026-06-15 20:53:10.686+00	\N
219	TST-BAC-3B-HDGZ-5	TEST74958HDFXXX01	Leonardo Rodriguez Jimenez	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.705+00	2026-06-15 20:53:10.705+00	\N
220	TST-BAC-3B-S2RZ-6	TEST2640HDFXXX01	Sebastian Gonzalez Reyes	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.725+00	2026-06-15 20:53:10.725+00	\N
221	TST-BAC-3B-MLD8-7	TEST87162HDFXXX01	Valeria Lopez Cruz	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.75+00	2026-06-15 20:53:10.75+00	\N
222	TST-BAC-3B-7ZL3-8	TEST14637HDFXXX01	Mateo Cruz Reyes	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.77+00	2026-06-15 20:53:10.77+00	\N
223	TST-BAC-3B-GXA9-9	TEST2246HDFXXX01	Natalia Garcia Jimenez	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.794+00	2026-06-15 20:53:10.794+00	\N
224	TST-PRE-1A-N237-0	TEST37213HDFXXX01	Diego Garcia Sanchez	\N	\N	1	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.818+00	2026-06-15 20:53:10.818+00	\N
225	TST-PRE-1A-SMD6-1	TEST31129HDFXXX01	Victoria Perez Cruz	\N	\N	1	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.835+00	2026-06-15 20:53:10.835+00	\N
226	TST-PRE-1A-GBUY-2	TEST91858HDFXXX01	Leonardo Rodriguez Vazquez	\N	\N	1	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.859+00	2026-06-15 20:53:10.859+00	\N
227	TST-PRE-1A-AZ3M-3	TEST64027HDFXXX01	Renata Morales Martinez	\N	\N	1	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.885+00	2026-06-15 20:53:10.885+00	\N
228	TST-PRE-1A-E2J6-4	TEST83885HDFXXX01	Thiago Vazquez Sanchez	\N	\N	1	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.908+00	2026-06-15 20:53:10.908+00	\N
229	TST-PRE-1A-VK5X-5	TEST13335HDFXXX01	Camila Cruz Ramirez	\N	\N	1	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.931+00	2026-06-15 20:53:10.931+00	\N
230	TST-PRE-1A-47GS-6	TEST44700HDFXXX01	Isabella Flores Reyes	\N	\N	1	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.95+00	2026-06-15 20:53:10.95+00	\N
231	TST-PRE-1A-LL48-7	TEST22661HDFXXX01	Renata Lopez Jimenez	\N	\N	1	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.974+00	2026-06-15 20:53:10.974+00	\N
232	TST-PRE-1A-BS2Y-8	TEST7620HDFXXX01	Renata Perez Diaz	\N	\N	1	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.999+00	2026-06-15 20:53:10.999+00	\N
233	TST-PRE-1A-2FVB-9	TEST9162HDFXXX01	Victoria Jimenez Reyes	\N	\N	1	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:11.022+00	2026-06-15 20:53:11.022+00	\N
9	SDM-2022-0003	CAHC170305MVZSRM06	Camila Castro Hernández	2017-03-05	F	1	Activo	\N	\N	\N	[{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]		2026-06-12 05:56:10.669773+00	2026-06-15 21:03:40.999671+00	\N
210	TST-BAC-2A-JUWE-6	TEST28996HDFXXX01	Alejandro Garcia Ramire	\N	\N	4	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:10.48+00	2026-06-16 02:26:48.711863+00	\N
235	SDM-1593-3214	\N	Lusito Reyes	2016-01-01	\N	\N	Activo	\N	\N	\N	[]	\N	2026-06-16 12:00:42.523+00	2026-06-16 12:00:42.523+00	\N
236	SDM-2026-2026	TEST982165HDFRRN01	juanito gutierritos perez	\N	\N	\N	Activo	\N	\N	\N	[]	\N	2026-06-16 12:01:13.68+00	2026-06-16 12:01:13.68+00	\N
10	SDM-2018-0001	CAHA111018HVZSRD01	Adrián Castro H	2011-10-18	M	3	Activo	\N	\N	\N	[{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]	[BAJA TEMPORAL 16/6/2026]: por gei\n[REACTIVACIÓN 16/6/2026]: porque ya no es gei	2026-06-12 05:56:10.669773+00	2026-06-16 12:46:40.191988+00	\N
234	SDM-1234-4569	\N	Francisco Javier Salmones	2017-07-04	\N	3	Activo	\N	\N	\N	[]	[BAJA TEMPORAL 16/6/2026]: Falta mucho\n[REACTIVACIÓN 16/6/2026]: Pago mucho dinero	2026-06-16 09:14:36.555+00	2026-06-16 12:07:07.158414+00	\N
136	TST-PRI-5A-X5G2-2	TEST63288HDFXXX01	Alejandro Reyes Vazquez	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:53:08.783+00	2026-06-16 12:45:37.748965+00	\N
237	SDM-2222-2222	\N	nuevo alumnodos	\N	\N	\N	Activo	\N	\N	\N	[]	\N	2026-06-16 13:32:09.363+00	2026-06-16 13:32:09.363+00	\N
63	TST-PRI-6A-H76B-0	TEST37870HDFXXX01	Alejandro Vazquez Reyes	\N	\N	2	Activo	\N	\N	\N	[]	\N	2026-06-15 20:52:46.532+00	2026-06-16 14:34:44.72168+00	\N
\.


--
-- Data for Name: aplicacion_pago; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.aplicacion_pago (aplicacion_id, pago_id, calendario_pago_id, monto_aplicado, aplicado_a, creado_en, actualizado_en) FROM stdin;
1	1	2	4500.00	capital	2026-06-12 05:56:10.696221+00	2026-06-12 05:56:10.696221+00
2	2	13	4000.00	capital	2026-06-12 05:56:10.703911+00	2026-06-12 05:56:10.703911+00
3	2	13	400.00	recargo	2026-06-12 05:56:10.703911+00	2026-06-12 05:56:10.703911+00
4	3	14	2000.00	capital	2026-06-12 05:56:10.712725+00	2026-06-12 05:56:10.712725+00
5	4	1	4500.00	capital	2026-06-12 05:56:10.719005+00	2026-06-12 05:56:10.719005+00
6	6	11	4000.00	capital	2026-06-15 03:31:32+00	2026-06-15 03:31:32+00
7	6	12	4000.00	capital	2026-06-15 03:31:32.015+00	2026-06-15 03:31:32.015+00
8	6	14	2000.00	capital	2026-06-15 03:31:32.02+00	2026-06-15 03:31:32.02+00
9	6	15	4000.00	capital	2026-06-15 03:31:32.026+00	2026-06-15 03:31:32.026+00
10	6	16	4000.00	capital	2026-06-15 03:31:32.031+00	2026-06-15 03:31:32.031+00
11	6	17	4000.00	capital	2026-06-15 03:31:32.035+00	2026-06-15 03:31:32.035+00
12	6	18	4000.00	capital	2026-06-15 03:31:32.041+00	2026-06-15 03:31:32.041+00
13	6	19	4000.00	capital	2026-06-15 03:31:32.046+00	2026-06-15 03:31:32.046+00
14	6	20	2000.00	capital	2026-06-15 03:31:32.05+00	2026-06-15 03:31:32.05+00
15	7	20	2000.00	capital	2026-06-15 03:33:07.634+00	2026-06-15 03:33:07.634+00
16	8	21	6000.00	capital	2026-06-15 04:38:52.217+00	2026-06-15 04:38:52.217+00
17	10	23	1500.00	capital	2026-06-15 05:07:25.897+00	2026-06-15 05:07:25.897+00
18	11	23	3000.00	capital	2026-06-15 05:21:22.574+00	2026-06-15 05:21:22.574+00
19	11	24	1500.00	capital	2026-06-15 05:21:22.588+00	2026-06-15 05:21:22.588+00
20	12	24	3000.00	capital	2026-06-15 05:21:55.188+00	2026-06-15 05:21:55.188+00
21	12	25	1500.00	capital	2026-06-15 05:21:55.196+00	2026-06-15 05:21:55.196+00
22	13	25	3000.00	capital	2026-06-15 05:48:55.722+00	2026-06-15 05:48:55.722+00
23	13	26	1500.00	capital	2026-06-15 05:48:55.734+00	2026-06-15 05:48:55.734+00
24	14	22	1500.00	capital	2026-06-16 09:32:36.011+00	2026-06-16 09:32:36.011+00
25	15	26	3000.00	capital	2026-06-16 09:33:02.519+00	2026-06-16 09:33:02.519+00
26	15	27	1500.00	capital	2026-06-16 09:33:02.537+00	2026-06-16 09:33:02.537+00
27	16	27	3000.00	capital	2026-06-16 09:35:44.365+00	2026-06-16 09:35:44.365+00
28	16	28	1500.00	capital	2026-06-16 09:35:44.376+00	2026-06-16 09:35:44.376+00
29	17	28	3000.00	capital	2026-06-16 09:45:30.747+00	2026-06-16 09:45:30.747+00
30	17	29	1500.00	capital	2026-06-16 09:45:30.76+00	2026-06-16 09:45:30.76+00
31	18	29	3000.00	capital	2026-06-16 10:00:16.291+00	2026-06-16 10:00:16.291+00
32	18	30	1500.00	capital	2026-06-16 10:00:16.315+00	2026-06-16 10:00:16.315+00
33	20	91	2000.00	capital	2026-06-16 19:15:35.734+00	2026-06-16 19:15:35.734+00
34	21	94	2000.00	capital	2026-06-16 19:16:39.286+00	2026-06-16 19:16:39.286+00
35	21	95	2000.00	capital	2026-06-16 19:16:39.297+00	2026-06-16 19:16:39.297+00
36	21	96	2000.00	capital	2026-06-16 19:16:39.304+00	2026-06-16 19:16:39.304+00
37	22	68	4000.00	capital	2026-06-16 19:36:56.936+00	2026-06-16 19:36:56.936+00
38	22	69	4000.00	capital	2026-06-16 19:36:56.946+00	2026-06-16 19:36:56.946+00
39	23	106	4500.00	capital	2026-06-16 19:57:26.35+00	2026-06-16 19:57:26.35+00
40	24	35	4000.00	capital	2026-06-16 20:04:39.339+00	2026-06-16 20:04:39.339+00
41	25	63	1500.00	capital	2026-06-16 21:54:58.96+00	2026-06-16 21:54:58.96+00
\.


--
-- Data for Name: asignacion_beca; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.asignacion_beca (asignacion_id, alumno_id, beca_id, ciclo_id, solicitud_id, estado, fecha_asignacion, fecha_retiro, motivo_retiro, asignada_por, retirada_por, creado_en, actualizado_en, eliminado_en) FROM stdin;
1	6	1	2	\N	activa	2026-06-12	\N	\N	1	\N	2026-06-12 05:56:10.684517+00	2026-06-12 05:56:10.684517+00	\N
2	7	1	2	\N	activa	2026-06-12	\N	\N	1	\N	2026-06-12 05:56:10.684517+00	2026-06-12 05:56:10.684517+00	\N
3	8	1	2	\N	activa	2026-06-12	\N	\N	1	\N	2026-06-12 05:56:10.684517+00	2026-06-12 05:56:10.684517+00	\N
4	2	2	2	\N	activa	2026-06-12	\N	\N	1	\N	2026-06-12 05:56:10.684517+00	2026-06-12 05:56:10.684517+00	\N
5	229	6	5	\N	activa	2026-06-16	\N	\N	7	\N	2026-06-16 10:18:37.993+00	2026-06-16 10:18:37.993+00	\N
6	41	1	7	\N	activa	2026-06-16	\N	\N	19	\N	2026-06-16 13:06:47.322+00	2026-06-16 13:06:47.322+00	\N
7	10	2	7	\N	retirada	2026-06-16	2026-06-16	Reemplazada por una nueva beca	19	\N	2026-06-16 13:08:38.049+00	2026-06-16 13:08:54.724316+00	\N
8	10	6	7	\N	activa	2026-06-16	\N	\N	22	\N	2026-06-16 13:08:54.732+00	2026-06-16 13:08:54.732+00	\N
9	42	1	7	\N	activa	2026-06-16	\N	\N	11	\N	2026-06-16 13:48:58.748+00	2026-06-16 13:48:58.748+00	\N
10	163	3	7	\N	activa	2026-06-16	\N	\N	1	\N	2026-06-16 22:01:03.144+00	2026-06-16 22:01:03.144+00	\N
\.


--
-- Data for Name: asistencia; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.asistencia (asistencia_id, alumno_id, grupo_materia_id, fecha, estado, justificacion, registrada_por, registrada_en, actualizado_en) FROM stdin;
\.


--
-- Data for Name: beca; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.beca (beca_id, nombre_beca, criterio, porcentaje, descripcion, creado_en, actualizado_en, eliminado_en) FROM stdin;
1	Beca por hermanos	hermanos	15.00	Aplica cuando hay 2 o más alumnos en el colegio.	2026-06-12 05:56:09.773502+00	2026-06-12 05:56:09.773502+00	\N
2	Excelencia académica	calificacion	20.00	Promedio mayor o igual a 9.5 en el ciclo previo.	2026-06-12 05:56:09.773502+00	2026-06-12 05:56:09.773502+00	\N
3	Inscripción temprana	inscripcion_temprana	10.00	Liquidación de inscripción dentro de la ventana promocional.	2026-06-12 05:56:09.773502+00	2026-06-12 05:56:09.773502+00	\N
4	Beca	inscripcion_temprana	15.00	\N	2026-06-15 04:32:39.676+00	2026-06-15 04:32:39.676+00	\N
6	beca de prueba	calificacion	50.00	\N	2026-06-16 10:18:16.863+00	2026-06-16 10:18:16.863+00	\N
\.


--
-- Data for Name: calendario_pago; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.calendario_pago (calendario_pago_id, alumno_id, ciclo_id, concepto, mes, fecha_vencimiento, monto_original, monto_pagado, monto_recargo, estado_cobro, liquidado_at, creado_en, actualizado_en, eliminado_en) FROM stdin;
3	2	2	colegiatura	octubre	2026-10-05	4500.00	0.00	0.00	pendiente	\N	2026-06-12 05:56:10.689403+00	2026-06-12 05:56:10.689403+00	\N
4	2	2	colegiatura	noviembre	2026-11-05	4500.00	0.00	0.00	pendiente	\N	2026-06-12 05:56:10.689403+00	2026-06-12 05:56:10.689403+00	\N
5	2	2	colegiatura	diciembre	2026-12-05	4500.00	0.00	0.00	pendiente	\N	2026-06-12 05:56:10.689403+00	2026-06-12 05:56:10.689403+00	\N
6	2	2	colegiatura	enero	2027-01-05	4500.00	0.00	0.00	pendiente	\N	2026-06-12 05:56:10.689403+00	2026-06-12 05:56:10.689403+00	\N
7	2	2	colegiatura	febrero	2027-02-05	4500.00	0.00	0.00	pendiente	\N	2026-06-12 05:56:10.689403+00	2026-06-12 05:56:10.689403+00	\N
8	2	2	colegiatura	marzo	2027-03-05	4500.00	0.00	0.00	pendiente	\N	2026-06-12 05:56:10.689403+00	2026-06-12 05:56:10.689403+00	\N
9	2	2	colegiatura	abril	2027-04-05	4500.00	0.00	0.00	pendiente	\N	2026-06-12 05:56:10.689403+00	2026-06-12 05:56:10.689403+00	\N
10	2	2	colegiatura	mayo	2027-05-05	4500.00	0.00	0.00	pendiente	\N	2026-06-12 05:56:10.689403+00	2026-06-12 05:56:10.689403+00	\N
2	2	2	colegiatura	septiembre	2026-09-05	4500.00	4500.00	0.00	pagado	2026-09-04 16:30:00+00	2026-06-12 05:56:10.689403+00	2026-06-12 05:56:10.696221+00	\N
23	10	2	colegiatura	septiembre	2026-09-10	4500.00	4500.00	0.00	pagado	2026-06-15 05:21:22.577+00	2026-06-15 04:28:11.387+00	2026-06-15 05:21:22.529173+00	\N
13	1	2	colegiatura	octubre	2026-10-05	4000.00	4400.00	400.00	pagado	2026-10-08 20:15:00+00	2026-06-12 05:56:10.693557+00	2026-06-12 05:56:10.703911+00	\N
1	2	2	colegiatura	agosto	2026-08-05	4500.00	4500.00	0.00	pagado	2026-08-03 15:00:00+00	2026-06-12 05:56:10.689403+00	2026-06-12 05:56:10.719005+00	\N
11	1	2	colegiatura	agosto	2026-08-05	4000.00	4000.00	0.00	pagado	2026-06-15 03:31:32.005+00	2026-06-12 05:56:10.693557+00	2026-06-15 03:31:31.95737+00	\N
12	1	2	colegiatura	septiembre	2026-09-05	4000.00	4000.00	0.00	pagado	2026-06-15 03:31:32.015+00	2026-06-12 05:56:10.693557+00	2026-06-15 03:31:31.95737+00	\N
14	1	2	colegiatura	noviembre	2026-11-05	4000.00	4000.00	0.00	pagado	2026-06-15 03:31:32.02+00	2026-06-12 05:56:10.693557+00	2026-06-15 03:31:31.95737+00	\N
15	1	2	colegiatura	diciembre	2026-12-05	4000.00	4000.00	0.00	pagado	2026-06-15 03:31:32.027+00	2026-06-12 05:56:10.693557+00	2026-06-15 03:31:31.95737+00	\N
16	1	2	colegiatura	enero	2027-01-05	4000.00	4000.00	0.00	pagado	2026-06-15 03:31:32.031+00	2026-06-12 05:56:10.693557+00	2026-06-15 03:31:31.95737+00	\N
17	1	2	colegiatura	febrero	2027-02-05	4000.00	4000.00	0.00	pagado	2026-06-15 03:31:32.035+00	2026-06-12 05:56:10.693557+00	2026-06-15 03:31:31.95737+00	\N
18	1	2	colegiatura	marzo	2027-03-05	4000.00	4000.00	0.00	pagado	2026-06-15 03:31:32.041+00	2026-06-12 05:56:10.693557+00	2026-06-15 03:31:31.95737+00	\N
19	1	2	colegiatura	abril	2027-04-05	4000.00	4000.00	0.00	pagado	2026-06-15 03:31:32.046+00	2026-06-12 05:56:10.693557+00	2026-06-15 03:31:31.95737+00	\N
20	1	2	colegiatura	mayo	2027-05-05	2000.00	2000.00	0.00	pagado	2026-06-15 03:33:07.64+00	2026-06-12 05:56:10.693557+00	2026-06-15 03:33:07.610073+00	\N
31	10	2	colegiatura	mayo	2027-05-10	4500.00	0.00	0.00	pendiente	\N	2026-06-15 04:28:11.387+00	2026-06-15 04:28:11.387+00	\N
32	10	2	colegiatura	junio	2027-06-10	4500.00	0.00	0.00	pendiente	\N	2026-06-15 04:28:11.387+00	2026-06-15 04:28:11.387+00	\N
21	10	2	inscripcion	inicio	2026-09-10	6000.00	6000.00	0.00	pagado	2026-06-15 04:38:52.219+00	2026-06-15 04:28:11.387+00	2026-06-15 04:38:52.186004+00	\N
33	9	2	inscripcion	inicio	2026-09-10	5000.00	0.00	0.00	pendiente	\N	2026-06-15 04:41:15.246+00	2026-06-15 04:41:15.246+00	\N
34	9	2	material	inicio	2026-09-10	1200.00	0.00	0.00	pendiente	\N	2026-06-15 04:41:15.246+00	2026-06-15 04:41:15.246+00	\N
36	9	2	colegiatura	octubre	2026-10-10	4000.00	0.00	0.00	pendiente	\N	2026-06-15 04:41:15.246+00	2026-06-15 04:41:15.246+00	\N
37	9	2	colegiatura	noviembre	2026-11-10	4000.00	0.00	0.00	pendiente	\N	2026-06-15 04:41:15.246+00	2026-06-15 04:41:15.246+00	\N
38	9	2	colegiatura	diciembre	2026-12-10	4000.00	0.00	0.00	pendiente	\N	2026-06-15 04:41:15.246+00	2026-06-15 04:41:15.246+00	\N
39	9	2	colegiatura	enero	2027-01-10	4000.00	0.00	0.00	pendiente	\N	2026-06-15 04:41:15.246+00	2026-06-15 04:41:15.246+00	\N
40	9	2	colegiatura	febrero	2027-02-10	4000.00	0.00	0.00	pendiente	\N	2026-06-15 04:41:15.246+00	2026-06-15 04:41:15.246+00	\N
41	9	2	colegiatura	marzo	2027-03-10	4000.00	0.00	0.00	pendiente	\N	2026-06-15 04:41:15.246+00	2026-06-15 04:41:15.246+00	\N
42	9	2	colegiatura	abril	2027-04-10	4000.00	0.00	0.00	pendiente	\N	2026-06-15 04:41:15.246+00	2026-06-15 04:41:15.246+00	\N
43	9	2	colegiatura	mayo	2027-05-10	4000.00	0.00	0.00	pendiente	\N	2026-06-15 04:41:15.246+00	2026-06-15 04:41:15.246+00	\N
44	9	2	colegiatura	junio	2027-06-10	4000.00	0.00	0.00	pendiente	\N	2026-06-15 04:41:15.246+00	2026-06-15 04:41:15.246+00	\N
24	10	2	colegiatura	octubre	2026-10-10	4500.00	4500.00	0.00	pagado	2026-06-15 05:21:55.189+00	2026-06-15 04:28:11.387+00	2026-06-15 05:21:55.175978+00	\N
25	10	2	colegiatura	noviembre	2026-11-10	4500.00	4500.00	0.00	pagado	2026-06-15 05:48:55.724+00	2026-06-15 04:28:11.387+00	2026-06-15 05:48:55.691101+00	\N
45	1	1	material	inicio	2026-09-09	1500.00	0.00	0.00	pendiente	\N	2026-06-15 06:19:50.204+00	2026-06-15 06:19:50.204+00	\N
46	1	1	uniforme	inicio	2026-09-09	2500.00	0.00	0.00	pendiente	\N	2026-06-15 06:19:50.221+00	2026-06-15 06:19:50.221+00	\N
47	2	1	material	inicio	2026-09-09	1500.00	0.00	0.00	pendiente	\N	2026-06-15 06:19:50.225+00	2026-06-15 06:19:50.225+00	\N
48	2	1	uniforme	inicio	2026-09-09	2500.00	0.00	0.00	pendiente	\N	2026-06-15 06:19:50.231+00	2026-06-15 06:19:50.231+00	\N
49	3	1	material	inicio	2026-09-09	1500.00	0.00	0.00	pendiente	\N	2026-06-15 06:19:50.237+00	2026-06-15 06:19:50.237+00	\N
50	3	1	uniforme	inicio	2026-09-09	2500.00	0.00	0.00	pendiente	\N	2026-06-15 06:19:50.244+00	2026-06-15 06:19:50.244+00	\N
22	10	2	material	inicio	2026-09-10	1500.00	1500.00	0.00	pagado	2026-06-16 09:32:36.016+00	2026-06-15 04:28:11.387+00	2026-06-16 09:32:35.971281+00	\N
26	10	2	colegiatura	diciembre	2026-12-10	4500.00	4500.00	0.00	pagado	2026-06-16 09:33:02.524+00	2026-06-15 04:28:11.387+00	2026-06-16 09:33:02.4719+00	\N
27	10	2	colegiatura	enero	2027-01-10	4500.00	4500.00	0.00	pagado	2026-06-16 09:35:44.366+00	2026-06-15 04:28:11.387+00	2026-06-16 09:35:44.337237+00	\N
28	10	2	colegiatura	febrero	2027-02-10	4500.00	4500.00	0.00	pagado	2026-06-16 09:45:30.749+00	2026-06-15 04:28:11.387+00	2026-06-16 09:45:30.720278+00	\N
29	10	2	colegiatura	marzo	2027-03-10	4500.00	4500.00	0.00	pagado	2026-06-16 10:00:16.297+00	2026-06-15 04:28:11.387+00	2026-06-16 10:00:16.264307+00	\N
30	10	2	colegiatura	abril	2027-04-10	4500.00	1500.00	0.00	parcial	\N	2026-06-15 04:28:11.387+00	2026-06-16 10:00:16.264307+00	\N
61	1	7	colegiatura	Mayo	2026-05-10	2500.00	0.00	250.00	pendiente	\N	2026-06-16 15:08:56.641+00	2026-06-16 15:08:56.641+00	\N
62	2	7	colegiatura	Mayo	2026-05-10	2500.00	0.00	250.00	pendiente	\N	2026-06-16 15:08:56.653+00	2026-06-16 15:08:56.653+00	\N
64	4	7	colegiatura	Mayo	2026-05-10	2500.00	0.00	250.00	pendiente	\N	2026-06-16 15:08:56.667+00	2026-06-16 15:08:56.667+00	\N
65	120	7	inscripcion	inicio	2026-09-10	4500.00	0.00	0.00	pendiente	\N	2026-06-16 16:41:51.398+00	2026-06-16 16:41:51.398+00	\N
66	120	7	arancel	inicio	2026-09-10	2500.00	0.00	0.00	pendiente	\N	2026-06-16 16:41:51.398+00	2026-06-16 16:41:51.398+00	\N
67	120	7	material	inicio	2026-09-10	450.00	0.00	0.00	pendiente	\N	2026-06-16 16:41:51.398+00	2026-06-16 16:41:51.398+00	\N
70	120	7	colegiatura	noviembre	2026-11-10	4000.00	0.00	0.00	pendiente	\N	2026-06-16 16:41:51.398+00	2026-06-16 16:41:51.398+00	\N
71	120	7	colegiatura	diciembre	2026-12-10	4000.00	0.00	0.00	pendiente	\N	2026-06-16 16:41:51.398+00	2026-06-16 16:41:51.398+00	\N
72	120	7	colegiatura	enero	2027-01-10	4000.00	0.00	0.00	pendiente	\N	2026-06-16 16:41:51.398+00	2026-06-16 16:41:51.398+00	\N
73	120	7	colegiatura	febrero	2027-02-10	4000.00	0.00	0.00	pendiente	\N	2026-06-16 16:41:51.398+00	2026-06-16 16:41:51.398+00	\N
68	120	7	colegiatura	septiembre	2026-09-10	4000.00	4000.00	0.00	pagado	2026-06-16 19:36:56.94+00	2026-06-16 16:41:51.398+00	2026-06-16 19:36:56.917682+00	\N
69	120	7	colegiatura	octubre	2026-10-10	4000.00	4000.00	0.00	pagado	2026-06-16 19:36:56.948+00	2026-06-16 16:41:51.398+00	2026-06-16 19:36:56.917682+00	\N
35	9	2	colegiatura	septiembre	2026-09-10	4000.00	4000.00	0.00	pagado	2026-06-16 20:04:39.343+00	2026-06-15 04:41:15.246+00	2026-06-16 20:04:39.301625+00	\N
63	3	7	colegiatura	Mayo	2026-05-10	2500.00	1500.00	250.00	parcial	\N	2026-06-16 15:08:56.658+00	2026-06-16 21:54:58.929265+00	\N
74	120	7	colegiatura	marzo	2027-03-10	4000.00	0.00	0.00	pendiente	\N	2026-06-16 16:41:51.398+00	2026-06-16 16:41:51.398+00	\N
75	120	7	colegiatura	abril	2027-04-10	4000.00	0.00	0.00	pendiente	\N	2026-06-16 16:41:51.398+00	2026-06-16 16:41:51.398+00	\N
76	120	7	colegiatura	mayo	2027-05-10	4000.00	0.00	0.00	pendiente	\N	2026-06-16 16:41:51.398+00	2026-06-16 16:41:51.398+00	\N
77	120	7	colegiatura	junio	2027-06-10	4000.00	0.00	0.00	pendiente	\N	2026-06-16 16:41:51.398+00	2026-06-16 16:41:51.398+00	\N
78	47	7	inscripcion	inicio	2026-09-10	4500.00	0.00	0.00	pendiente	\N	2026-06-16 16:43:17.715+00	2026-06-16 16:43:17.715+00	\N
79	47	7	arancel	inicio	2026-09-10	2500.00	0.00	0.00	pendiente	\N	2026-06-16 16:43:17.715+00	2026-06-16 16:43:17.715+00	\N
80	47	7	material	inicio	2026-09-10	450.00	0.00	0.00	pendiente	\N	2026-06-16 16:43:17.715+00	2026-06-16 16:43:17.715+00	\N
81	47	7	colegiatura	septiembre	2026-09-10	4000.00	0.00	0.00	pendiente	\N	2026-06-16 16:43:17.715+00	2026-06-16 16:43:17.715+00	\N
82	47	7	colegiatura	octubre	2026-10-10	4000.00	0.00	0.00	pendiente	\N	2026-06-16 16:43:17.715+00	2026-06-16 16:43:17.715+00	\N
83	47	7	colegiatura	noviembre	2026-11-10	4000.00	0.00	0.00	pendiente	\N	2026-06-16 16:43:17.715+00	2026-06-16 16:43:17.715+00	\N
84	47	7	colegiatura	diciembre	2026-12-10	4000.00	0.00	0.00	pendiente	\N	2026-06-16 16:43:17.715+00	2026-06-16 16:43:17.715+00	\N
85	47	7	colegiatura	enero	2027-01-10	4000.00	0.00	0.00	pendiente	\N	2026-06-16 16:43:17.715+00	2026-06-16 16:43:17.715+00	\N
86	47	7	colegiatura	febrero	2027-02-10	4000.00	0.00	0.00	pendiente	\N	2026-06-16 16:43:17.715+00	2026-06-16 16:43:17.715+00	\N
87	47	7	colegiatura	marzo	2027-03-10	4000.00	0.00	0.00	pendiente	\N	2026-06-16 16:43:17.715+00	2026-06-16 16:43:17.715+00	\N
88	47	7	colegiatura	abril	2027-04-10	4000.00	0.00	0.00	pendiente	\N	2026-06-16 16:43:17.715+00	2026-06-16 16:43:17.715+00	\N
89	47	7	colegiatura	mayo	2027-05-10	4000.00	0.00	0.00	pendiente	\N	2026-06-16 16:43:17.715+00	2026-06-16 16:43:17.715+00	\N
90	47	7	colegiatura	junio	2027-06-10	4000.00	0.00	0.00	pendiente	\N	2026-06-16 16:43:17.715+00	2026-06-16 16:43:17.715+00	\N
92	87	7	arancel	inicio	2026-09-10	2000.00	0.00	0.00	pendiente	\N	2026-06-16 16:44:58.088+00	2026-06-16 16:44:58.088+00	\N
93	87	7	material	inicio	2026-09-10	2000.00	0.00	0.00	pendiente	\N	2026-06-16 16:44:58.088+00	2026-06-16 16:44:58.088+00	\N
97	87	7	colegiatura	diciembre	2026-12-10	4000.00	0.00	0.00	pendiente	\N	2026-06-16 16:44:58.088+00	2026-06-16 16:44:58.088+00	\N
98	87	7	colegiatura	enero	2027-01-10	2000.00	0.00	0.00	pendiente	\N	2026-06-16 16:44:58.088+00	2026-06-16 16:44:58.088+00	\N
99	87	7	colegiatura	febrero	2027-02-10	2000.00	0.00	0.00	pendiente	\N	2026-06-16 16:44:58.088+00	2026-06-16 16:44:58.088+00	\N
100	87	7	colegiatura	marzo	2027-03-10	2000.00	0.00	0.00	pendiente	\N	2026-06-16 16:44:58.088+00	2026-06-16 16:44:58.088+00	\N
101	87	7	colegiatura	abril	2027-04-10	2000.00	0.00	0.00	pendiente	\N	2026-06-16 16:44:58.088+00	2026-06-16 16:44:58.088+00	\N
102	87	7	colegiatura	mayo	2027-05-10	2000.00	0.00	0.00	pendiente	\N	2026-06-16 16:44:58.088+00	2026-06-16 16:44:58.088+00	\N
103	87	7	colegiatura	junio	2027-06-10	2000.00	0.00	0.00	pendiente	\N	2026-06-16 16:44:58.088+00	2026-06-16 16:44:58.088+00	\N
104	87	7	colegiatura	julio	2027-07-10	2000.00	0.00	0.00	pendiente	\N	2026-06-16 16:44:58.088+00	2026-06-16 16:44:58.088+00	\N
105	87	7	colegiatura	agosto	2027-08-10	2000.00	0.00	0.00	pendiente	\N	2026-06-16 16:44:58.088+00	2026-06-16 16:44:58.088+00	\N
91	87	7	inscripcion	inicio	2026-09-10	2000.00	2000.00	0.00	pagado	2026-06-16 19:15:35.741+00	2026-06-16 16:44:58.088+00	2026-06-16 19:15:35.697426+00	\N
94	87	7	colegiatura	septiembre	2026-09-10	2000.00	2000.00	0.00	pagado	2026-06-16 19:16:39.29+00	2026-06-16 16:44:58.088+00	2026-06-16 19:16:39.260372+00	\N
95	87	7	colegiatura	octubre	2026-10-10	2000.00	2000.00	0.00	pagado	2026-06-16 19:16:39.298+00	2026-06-16 16:44:58.088+00	2026-06-16 19:16:39.260372+00	\N
96	87	7	colegiatura	noviembre	2026-11-10	2000.00	2000.00	0.00	pagado	2026-06-16 19:16:39.304+00	2026-06-16 16:44:58.088+00	2026-06-16 19:16:39.260372+00	\N
107	42	7	arancel	inicio	2026-09-10	2500.00	0.00	0.00	pendiente	\N	2026-06-16 19:56:42.952+00	2026-06-16 19:56:42.952+00	\N
108	42	7	material	inicio	2026-09-10	450.00	0.00	0.00	pendiente	\N	2026-06-16 19:56:42.952+00	2026-06-16 19:56:42.952+00	\N
109	42	7	colegiatura	septiembre	2026-09-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 19:56:42.952+00	2026-06-16 19:56:42.952+00	\N
110	42	7	colegiatura	octubre	2026-10-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 19:56:42.952+00	2026-06-16 19:56:42.952+00	\N
111	42	7	colegiatura	noviembre	2026-11-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 19:56:42.952+00	2026-06-16 19:56:42.952+00	\N
112	42	7	colegiatura	diciembre	2026-12-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 19:56:42.952+00	2026-06-16 19:56:42.952+00	\N
113	42	7	colegiatura	enero	2027-01-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 19:56:42.952+00	2026-06-16 19:56:42.952+00	\N
114	42	7	colegiatura	febrero	2027-02-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 19:56:42.952+00	2026-06-16 19:56:42.952+00	\N
115	42	7	colegiatura	marzo	2027-03-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 19:56:42.952+00	2026-06-16 19:56:42.952+00	\N
116	42	7	colegiatura	abril	2027-04-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 19:56:42.952+00	2026-06-16 19:56:42.952+00	\N
117	42	7	colegiatura	mayo	2027-05-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 19:56:42.952+00	2026-06-16 19:56:42.952+00	\N
118	42	7	colegiatura	junio	2027-06-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 19:56:42.952+00	2026-06-16 19:56:42.952+00	\N
119	42	7	colegiatura	julio	2027-07-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 19:56:42.952+00	2026-06-16 19:56:42.952+00	\N
120	42	7	colegiatura	agosto	2027-08-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 19:56:42.952+00	2026-06-16 19:56:42.952+00	\N
106	42	7	inscripcion	inicio	2026-09-10	4500.00	4500.00	0.00	pagado	2026-06-16 19:57:26.353+00	2026-06-16 19:56:42.952+00	2026-06-16 19:57:26.320437+00	\N
121	136	7	inscripcion	inicio	2026-09-10	4500.00	0.00	0.00	pendiente	\N	2026-06-16 20:13:26.764+00	2026-06-16 20:13:26.764+00	\N
122	136	7	arancel	inicio	2026-09-10	2500.00	0.00	0.00	pendiente	\N	2026-06-16 20:13:26.764+00	2026-06-16 20:13:26.764+00	\N
123	136	7	material	inicio	2026-09-10	450.00	0.00	0.00	pendiente	\N	2026-06-16 20:13:26.764+00	2026-06-16 20:13:26.764+00	\N
124	136	7	colegiatura	septiembre	2026-09-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 20:13:26.764+00	2026-06-16 20:13:26.764+00	\N
125	136	7	colegiatura	octubre	2026-10-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 20:13:26.764+00	2026-06-16 20:13:26.764+00	\N
126	136	7	colegiatura	noviembre	2026-11-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 20:13:26.764+00	2026-06-16 20:13:26.764+00	\N
127	136	7	colegiatura	diciembre	2026-12-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 20:13:26.764+00	2026-06-16 20:13:26.764+00	\N
128	136	7	colegiatura	enero	2027-01-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 20:13:26.764+00	2026-06-16 20:13:26.764+00	\N
129	136	7	colegiatura	febrero	2027-02-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 20:13:26.764+00	2026-06-16 20:13:26.764+00	\N
130	136	7	colegiatura	marzo	2027-03-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 20:13:26.764+00	2026-06-16 20:13:26.764+00	\N
131	136	7	colegiatura	abril	2027-04-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 20:13:26.764+00	2026-06-16 20:13:26.764+00	\N
132	136	7	colegiatura	mayo	2027-05-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 20:13:26.764+00	2026-06-16 20:13:26.764+00	\N
133	136	7	colegiatura	junio	2027-06-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 20:13:26.764+00	2026-06-16 20:13:26.764+00	\N
134	136	7	colegiatura	julio	2027-07-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 20:13:26.764+00	2026-06-16 20:13:26.764+00	\N
135	136	7	colegiatura	agosto	2027-08-10	3333.33	0.00	0.00	pendiente	\N	2026-06-16 20:13:26.764+00	2026-06-16 20:13:26.764+00	\N
136	10	7	inscripcion	inicio	2026-09-10	2000.00	0.00	0.00	pendiente	\N	2026-06-16 21:28:27.232+00	2026-06-16 21:28:27.232+00	\N
137	10	7	arancel	inicio	2026-09-10	2000.00	0.00	0.00	pendiente	\N	2026-06-16 21:28:27.232+00	2026-06-16 21:28:27.232+00	\N
138	10	7	material	inicio	2026-09-10	2000.00	0.00	0.00	pendiente	\N	2026-06-16 21:28:27.232+00	2026-06-16 21:28:27.232+00	\N
139	10	7	colegiatura	septiembre	2026-09-10	1666.67	0.00	0.00	pendiente	\N	2026-06-16 21:28:27.232+00	2026-06-16 21:28:27.232+00	\N
140	10	7	colegiatura	octubre	2026-10-10	1666.67	0.00	0.00	pendiente	\N	2026-06-16 21:28:27.232+00	2026-06-16 21:28:27.232+00	\N
141	10	7	colegiatura	noviembre	2026-11-10	1666.67	0.00	0.00	pendiente	\N	2026-06-16 21:28:27.232+00	2026-06-16 21:28:27.232+00	\N
142	10	7	colegiatura	diciembre	2026-12-10	3333.34	0.00	0.00	pendiente	\N	2026-06-16 21:28:27.232+00	2026-06-16 21:28:27.232+00	\N
143	10	7	colegiatura	febrero	2027-02-10	1666.67	0.00	0.00	pendiente	\N	2026-06-16 21:28:27.232+00	2026-06-16 21:28:27.232+00	\N
144	10	7	colegiatura	marzo	2027-03-10	1666.67	0.00	0.00	pendiente	\N	2026-06-16 21:28:27.232+00	2026-06-16 21:28:27.232+00	\N
145	10	7	colegiatura	abril	2027-04-10	1666.67	0.00	0.00	pendiente	\N	2026-06-16 21:28:27.232+00	2026-06-16 21:28:27.232+00	\N
146	10	7	colegiatura	mayo	2027-05-10	1666.67	0.00	0.00	pendiente	\N	2026-06-16 21:28:27.232+00	2026-06-16 21:28:27.232+00	\N
147	10	7	colegiatura	junio	2027-06-10	1666.67	0.00	0.00	pendiente	\N	2026-06-16 21:28:27.232+00	2026-06-16 21:28:27.232+00	\N
148	10	7	colegiatura	julio	2027-07-10	1666.67	0.00	0.00	pendiente	\N	2026-06-16 21:28:27.232+00	2026-06-16 21:28:27.232+00	\N
149	10	7	colegiatura	agosto	2027-08-10	1666.67	0.00	0.00	pendiente	\N	2026-06-16 21:28:27.232+00	2026-06-16 21:28:27.232+00	\N
\.


--
-- Data for Name: calificacion; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.calificacion (calificacion_id, alumno_id, grupo_materia_id, periodo_id, tipo_evaluacion, valor_numerico, valor_cualitativo, texto_observacion, cuenta_para_promedio, modificada_motivo, registrada_por, registrada_en, actualizado_en) FROM stdin;
228	42	34	5	numerica	10.00	\N	\N	t	\N	19	2026-06-16 09:53:22.999+00	2026-06-16 09:53:22.999+00
69	10	66	23	numerica	8.80	\N	\N	t	\N	11	2026-06-15 22:34:44.078+00	2026-06-16 08:10:13.440019+00
65	10	71	23	numerica	2.00	\N	\N	t	\N	11	2026-06-15 22:27:32.487+00	2026-06-16 08:10:13.470004+00
72	41	66	23	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.459+00	2026-06-15 23:13:36.459+00
7	1	2	5	observacion	\N	\N	hola 1	t	\N	3	2026-06-15 20:36:00.18+00	2026-06-15 20:36:00.18+00
2	1	1	1	observacion	\N	\N	hola 0	t	\N	3	2026-06-15 20:33:50.745+00	2026-06-15 20:36:00.169537+00
8	1	3	1	observacion	\N	\N	hola 12	t	\N	3	2026-06-15 20:36:00.22+00	2026-06-15 20:36:00.22+00
9	1	4	5	observacion	\N	\N	hola 13	t	\N	3	2026-06-15 20:36:00.22+00	2026-06-15 20:36:00.22+00
11	1	5	2	observacion	\N	\N	hola 14	t	\N	3	2026-06-15 20:36:00.228+00	2026-06-15 20:36:00.228+00
10	1	5	5	observacion	\N	\N	hola 4	t	\N	3	2026-06-15 20:36:00.226+00	2026-06-15 20:36:00.226+00
14	1	2	1	observacion	\N	\N	hola 6	t	\N	3	2026-06-15 20:36:00.245+00	2026-06-15 20:36:00.245+00
12	1	3	2	observacion	\N	\N	hola 2	t	\N	3	2026-06-15 20:36:00.23+00	2026-06-15 20:36:00.23+00
13	1	2	2	observacion	\N	\N	hola 11	t	\N	3	2026-06-15 20:36:00.229+00	2026-06-15 20:36:00.229+00
15	1	4	1	observacion	\N	\N	hola 3	t	\N	3	2026-06-15 20:36:00.249+00	2026-06-15 20:36:00.249+00
18	1	3	5	observacion	\N	\N	hola 7	t	\N	3	2026-06-15 20:36:00.264+00	2026-06-15 20:36:00.264+00
17	1	4	2	observacion	\N	\N	hola 8	t	\N	3	2026-06-15 20:36:00.247+00	2026-06-15 20:36:00.247+00
16	1	1	5	observacion	\N	\N	hola 10	t	\N	3	2026-06-15 20:36:00.237+00	2026-06-15 20:36:00.237+00
19	1	5	1	observacion	\N	\N	hola 9	t	\N	3	2026-06-15 20:36:00.256+00	2026-06-15 20:36:00.256+00
20	1	1	2	observacion	\N	\N	hola 5	t	\N	3	2026-06-15 20:36:00.297+00	2026-06-15 20:36:00.297+00
24	9	1	5	observacion	\N	\N	asc	t	\N	6	2026-06-15 20:36:36.819+00	2026-06-15 20:36:36.819+00
21	9	2	1	observacion	\N	\N	asc	t	\N	6	2026-06-15 20:36:36.819+00	2026-06-15 20:36:36.819+00
27	9	1	1	observacion	\N	\N	acv	t	\N	6	2026-06-15 20:36:36.824+00	2026-06-15 20:36:36.824+00
28	9	2	5	observacion	\N	\N	as	t	\N	6	2026-06-15 20:36:36.83+00	2026-06-15 20:36:36.83+00
29	9	4	2	observacion	\N	\N	asc	t	\N	6	2026-06-15 20:36:36.834+00	2026-06-15 20:36:36.834+00
75	41	66	19	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.468+00	2026-06-15 23:13:36.468+00
229	42	34	1	numerica	6.00	\N	\N	t	\N	19	2026-06-16 09:53:23+00	2026-06-16 09:53:23+00
26	9	4	5	observacion	\N	\N	asc	t	\N	6	2026-06-15 20:36:36.827+00	2026-06-15 20:36:47.15037+00
25	9	1	2	observacion	\N	\N	asdc	t	\N	6	2026-06-15 20:36:36.825+00	2026-06-15 20:36:47.150361+00
33	9	5	1	observacion	\N	\N	asc	t	\N	6	2026-06-15 20:36:36.887+00	2026-06-15 20:36:47.150365+00
3	9	4	1	observacion	\N	\N	qwfqw	t	\N	6	2026-06-15 20:34:33.568+00	2026-06-15 20:36:47.150413+00
31	9	5	5	observacion	\N	\N	asc	t	\N	6	2026-06-15 20:36:36.829+00	2026-06-15 20:36:47.150375+00
5	9	3	1	observacion	\N	\N	qwf	t	\N	6	2026-06-15 20:34:33.569+00	2026-06-15 20:36:47.150423+00
30	9	3	5	observacion	\N	\N	asc	t	\N	6	2026-06-15 20:36:36.834+00	2026-06-15 20:36:47.150285+00
23	9	3	2	observacion	\N	\N	assc	t	\N	6	2026-06-15 20:36:36.821+00	2026-06-15 20:36:47.150273+00
32	9	5	2	observacion	\N	\N	asc	t	\N	6	2026-06-15 20:36:36.878+00	2026-06-15 20:36:47.150391+00
22	9	2	2	observacion	\N	\N	asc	t	\N	6	2026-06-15 20:36:36.82+00	2026-06-15 20:36:47.150302+00
34	19	24	11	observacion	\N	\N	hola	t	\N	6	2026-06-15 20:47:09.263+00	2026-06-15 20:47:09.263+00
35	19	24	12	observacion	\N	\N	no puso atencion	t	\N	6	2026-06-15 20:47:09.266+00	2026-06-15 20:47:09.266+00
36	19	24	13	observacion	\N	\N	kings	t	\N	6	2026-06-15 20:47:09.278+00	2026-06-15 20:47:09.278+00
37	15	16	14	numerica	0.10	\N	\N	t	\N	6	2026-06-15 20:48:19.456+00	2026-06-15 20:48:19.456+00
38	9	24	12	observacion	\N	\N	falto mucho	t	\N	11	2026-06-15 21:17:22.753+00	2026-06-15 21:17:22.753+00
39	219	22	15	numerica	4.00	\N	\N	t	\N	6	2026-06-15 21:47:58.043+00	2026-06-15 21:47:58.043+00
40	219	22	16	numerica	4.00	\N	\N	t	\N	6	2026-06-15 21:47:58.046+00	2026-06-15 21:47:58.046+00
41	219	23	15	numerica	4.00	\N	\N	t	\N	6	2026-06-15 21:47:58.07+00	2026-06-15 21:47:58.07+00
42	219	22	17	numerica	4.00	\N	\N	t	\N	6	2026-06-15 21:47:58.082+00	2026-06-15 21:47:58.082+00
43	219	23	16	numerica	4.00	\N	\N	t	\N	6	2026-06-15 21:47:58.082+00	2026-06-15 21:47:58.082+00
44	219	23	17	numerica	4.00	\N	\N	t	\N	6	2026-06-15 21:47:58.092+00	2026-06-15 21:47:58.092+00
68	10	66	19	numerica	4.10	\N	\N	t	\N	11	2026-06-15 22:34:44.088+00	2026-06-16 08:10:13.444475+00
239	42	35	1	numerica	10.00	\N	\N	t	\N	19	2026-06-16 09:53:23.061+00	2026-06-16 09:53:23.061+00
240	42	37	5	numerica	6.00	\N	\N	t	\N	19	2026-06-16 09:53:23.074+00	2026-06-16 09:53:23.074+00
59	10	70	23	numerica	2.00	\N	\N	t	\N	11	2026-06-15 22:27:32.46+00	2026-06-16 08:10:13.579751+00
51	10	69	19	numerica	2.00	\N	\N	t	\N	11	2026-06-15 22:27:32.368+00	2026-06-16 08:10:13.580222+00
58	10	72	23	numerica	2.00	\N	\N	t	\N	11	2026-06-15 22:27:32.451+00	2026-06-16 08:10:13.469574+00
46	10	68	23	numerica	2.00	\N	\N	t	\N	11	2026-06-15 22:27:32.361+00	2026-06-16 08:10:13.580123+00
245	42	38	1	numerica	10.00	\N	\N	t	\N	19	2026-06-16 09:53:23.123+00	2026-06-16 09:53:23.123+00
74	41	66	20	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.457+00	2026-06-15 23:13:36.457+00
57	10	69	23	numerica	7.00	\N	\N	t	\N	11	2026-06-15 22:27:32.377+00	2026-06-16 08:10:13.580352+00
60	10	72	20	numerica	10.00	\N	\N	t	\N	11	2026-06-15 22:27:32.463+00	2026-06-16 08:10:13.494896+00
50	10	74	19	numerica	2.00	\N	\N	t	\N	11	2026-06-15 22:27:32.363+00	2026-06-16 08:10:13.557555+00
73	41	71	20	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.468+00	2026-06-15 23:13:36.468+00
49	10	68	20	numerica	2.00	\N	\N	t	\N	11	2026-06-15 22:27:32.363+00	2026-06-16 08:10:13.59023+00
48	10	69	20	numerica	2.00	\N	\N	t	\N	11	2026-06-15 22:27:32.367+00	2026-06-16 08:10:13.500402+00
76	41	71	19	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.532+00	2026-06-15 23:13:36.532+00
47	10	70	19	numerica	2.00	\N	\N	t	\N	11	2026-06-15 22:27:32.369+00	2026-06-16 08:10:13.580246+00
78	41	72	23	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.55+00	2026-06-15 23:13:36.55+00
79	41	72	20	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.55+00	2026-06-15 23:13:36.55+00
52	10	68	19	numerica	2.00	\N	\N	t	\N	11	2026-06-15 22:27:32.361+00	2026-06-16 08:10:13.590046+00
80	41	73	23	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.567+00	2026-06-15 23:13:36.567+00
81	41	72	19	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.557+00	2026-06-15 23:13:36.557+00
77	41	70	19	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.55+00	2026-06-15 23:13:36.55+00
82	41	73	19	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.564+00	2026-06-15 23:13:36.564+00
84	41	74	23	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.566+00	2026-06-15 23:13:36.566+00
246	42	38	2	numerica	6.00	\N	\N	t	\N	19	2026-06-16 09:53:23.127+00	2026-06-16 09:53:23.127+00
258	63	265	49	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:14.905+00	2026-06-16 14:33:14.905+00
253	63	264	49	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:14.894+00	2026-06-16 14:33:14.894+00
53	10	73	23	numerica	2.00	\N	\N	t	\N	11	2026-06-15 22:27:32.375+00	2026-06-16 08:10:13.497387+00
260	63	267	43	numerica	10.00	\N	\N	t	\N	6	2026-06-16 14:33:14.982+00	2026-06-16 14:33:14.982+00
265	63	268	53	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:14.993+00	2026-06-16 14:33:14.993+00
274	63	261	43	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.039+00	2026-06-16 14:33:15.039+00
279	63	270	53	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.044+00	2026-06-16 14:33:15.044+00
83	41	70	23	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.563+00	2026-06-15 23:13:36.563+00
85	41	73	20	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.561+00	2026-06-15 23:13:36.561+00
86	41	74	19	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.589+00	2026-06-15 23:13:36.589+00
87	41	74	20	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.595+00	2026-06-15 23:13:36.595+00
88	41	70	20	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.59+00	2026-06-15 23:13:36.59+00
89	41	67	23	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.631+00	2026-06-15 23:13:36.631+00
90	41	68	20	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.638+00	2026-06-15 23:13:36.638+00
230	42	33	1	numerica	6.00	\N	\N	t	\N	19	2026-06-16 09:53:23.002+00	2026-06-16 09:53:23.002+00
241	42	38	5	numerica	6.00	\N	\N	t	\N	19	2026-06-16 09:53:23.07+00	2026-06-16 09:53:23.07+00
244	42	37	1	numerica	6.00	\N	\N	t	\N	19	2026-06-16 09:53:23.124+00	2026-06-16 09:53:23.124+00
251	63	194	43	numerica	10.00	\N	\N	t	\N	6	2026-06-16 14:33:14.892+00	2026-06-16 14:33:14.892+00
264	63	192	49	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:14.992+00	2026-06-16 14:33:14.992+00
280	63	262	49	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.048+00	2026-06-16 14:33:15.048+00
288	63	191	43	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.088+00	2026-06-16 14:33:15.088+00
297	10	377	49	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.757+00	2026-06-16 14:33:38.757+00
306	10	378	43	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.805+00	2026-06-16 14:33:38.805+00
326	10	384	53	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.883+00	2026-06-16 14:33:38.883+00
334	9	368	98	observacion	\N	\N	qwewfqwf	t	\N	6	2026-06-16 14:35:19.337+00	2026-06-16 14:35:19.337+00
353	153	191	43	numerica	9.00	\N	\N	t	\N	6	2026-06-16 14:39:26.817+00	2026-06-16 14:39:26.817+00
355	153	263	43	numerica	9.00	\N	\N	t	\N	6	2026-06-16 14:39:26.981+00	2026-06-16 14:39:26.981+00
373	153	269	53	numerica	10.00	\N	\N	t	\N	6	2026-06-16 14:39:27.106+00	2026-06-16 14:39:27.106+00
386	153	195	49	numerica	9.00	\N	\N	t	\N	6	2026-06-16 14:39:27.226+00	2026-06-16 14:39:27.226+00
396	42	231	103	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.26+00	2026-06-16 14:45:41.26+00
413	42	232	102	numerica	10.00	\N	\N	t	\N	6	2026-06-16 14:45:41.43+00	2026-06-16 14:45:41.43+00
434	75	169	49	numerica	10.00	\N	\N	t	\N	6	2026-06-16 22:11:51.141+00	2026-06-16 22:11:51.141+00
438	75	178	49	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.24+00	2026-06-16 22:11:51.24+00
454	75	171	53	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.339+00	2026-06-16 22:11:51.339+00
466	75	249	43	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.412+00	2026-06-16 22:11:51.412+00
481	75	166	53	numerica	10.00	\N	\N	t	\N	6	2026-06-16 22:11:51.507+00	2026-06-16 22:11:51.507+00
93	41	69	20	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.651+00	2026-06-15 23:13:36.651+00
231	42	39	2	numerica	6.00	\N	\N	t	\N	19	2026-06-16 09:53:23.018+00	2026-06-16 09:53:23.018+00
247	63	197	43	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:14.884+00	2026-06-16 14:33:14.884+00
262	63	271	43	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:14.992+00	2026-06-16 14:33:14.992+00
278	63	267	49	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.042+00	2026-06-16 14:33:15.042+00
287	63	195	43	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.088+00	2026-06-16 14:33:15.088+00
299	10	374	49	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.759+00	2026-06-16 14:33:38.759+00
312	10	381	49	numerica	8.00	\N	\N	t	\N	11	2026-06-16 14:33:38.808+00	2026-06-16 14:33:38.808+00
327	10	383	53	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.902+00	2026-06-16 14:33:38.902+00
335	9	372	89	observacion	\N	\N	qwf	t	\N	6	2026-06-16 14:35:19.336+00	2026-06-16 14:35:19.336+00
342	153	262	53	numerica	9.00	\N	\N	t	\N	6	2026-06-16 14:39:26.813+00	2026-06-16 14:39:26.813+00
361	153	265	53	numerica	8.00	\N	\N	t	\N	6	2026-06-16 14:39:26.988+00	2026-06-16 14:39:26.988+00
372	153	271	43	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:39:27.108+00	2026-06-16 14:39:27.108+00
382	153	194	49	numerica	9.00	\N	\N	t	\N	6	2026-06-16 14:39:27.222+00	2026-06-16 14:39:27.222+00
392	42	231	102	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.249+00	2026-06-16 14:45:41.249+00
405	42	232	103	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.393+00	2026-06-16 14:45:41.393+00
420	42	148	103	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.518+00	2026-06-16 14:45:41.518+00
422	75	166	49	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.138+00	2026-06-16 22:11:51.138+00
442	75	178	43	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.241+00	2026-06-16 22:11:51.241+00
450	75	246	43	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.337+00	2026-06-16 22:11:51.337+00
464	75	177	53	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.412+00	2026-06-16 22:11:51.412+00
92	41	71	23	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.651+00	2026-06-15 23:13:36.651+00
100	75	9	20	numerica	9.00	\N	\N	t	\N	11	2026-06-15 23:15:48.593+00	2026-06-16 00:05:54.811824+00
232	42	40	1	numerica	10.00	\N	\N	t	\N	19	2026-06-16 09:53:23.017+00	2026-06-16 09:53:23.017+00
257	63	268	49	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:14.899+00	2026-06-16 14:33:14.899+00
272	63	197	53	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.02+00	2026-06-16 14:33:15.02+00
284	63	261	53	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.071+00	2026-06-16 14:33:15.071+00
298	10	376	53	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.758+00	2026-06-16 14:33:38.758+00
309	10	381	43	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.808+00	2026-06-16 14:33:38.808+00
320	10	382	43	numerica	8.00	\N	\N	t	\N	11	2026-06-16 14:33:38.871+00	2026-06-16 14:33:38.871+00
332	9	370	90	observacion	\N	\N	qwf	t	\N	6	2026-06-16 14:35:19.336+00	2026-06-16 14:35:19.336+00
346	153	195	43	numerica	9.00	\N	\N	t	\N	6	2026-06-16 14:39:26.82+00	2026-06-16 14:39:26.82+00
354	153	264	43	numerica	10.00	\N	\N	t	\N	6	2026-06-16 14:39:26.981+00	2026-06-16 14:39:26.981+00
368	153	271	53	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:39:27.101+00	2026-06-16 14:39:27.101+00
381	153	195	53	numerica	10.00	\N	\N	t	\N	6	2026-06-16 14:39:27.211+00	2026-06-16 14:39:27.211+00
398	42	228	108	numerica	10.00	\N	\N	t	\N	6	2026-06-16 14:45:41.257+00	2026-06-16 14:45:41.257+00
403	42	234	103	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.392+00	2026-06-16 14:45:41.392+00
415	42	229	103	numerica	10.00	\N	\N	t	\N	6	2026-06-16 14:45:41.456+00	2026-06-16 14:45:41.456+00
430	75	174	53	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.141+00	2026-06-16 22:11:51.141+00
443	75	170	49	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.243+00	2026-06-16 22:11:51.243+00
455	75	246	49	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.34+00	2026-06-16 22:11:51.34+00
469	75	251	53	numerica	10.00	\N	\N	t	\N	6	2026-06-16 22:11:51.413+00	2026-06-16 22:11:51.413+00
479	75	172	49	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.506+00	2026-06-16 22:11:51.506+00
91	41	67	20	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.65+00	2026-06-15 23:13:36.65+00
103	75	8	19	numerica	9.00	\N	\N	t	\N	11	2026-06-15 23:15:48.601+00	2026-06-16 00:05:54.828653+00
233	42	36	5	numerica	6.00	\N	\N	t	\N	19	2026-06-16 09:53:23.027+00	2026-06-16 09:53:23.027+00
259	63	265	43	numerica	10.00	\N	\N	t	\N	6	2026-06-16 14:33:14.9+00	2026-06-16 14:33:14.9+00
268	63	269	43	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.014+00	2026-06-16 14:33:15.014+00
282	63	271	49	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.07+00	2026-06-16 14:33:15.07+00
300	10	374	43	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.778+00	2026-06-16 14:33:38.778+00
314	10	385	49	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.82+00	2026-06-16 14:33:38.82+00
321	10	383	43	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.873+00	2026-06-16 14:33:38.873+00
339	9	368	89	observacion	\N	\N	qwf	t	\N	6	2026-06-16 14:35:19.364+00	2026-06-16 14:35:19.364+00
343	153	264	49	numerica	8.00	\N	\N	t	\N	6	2026-06-16 14:39:26.814+00	2026-06-16 14:39:26.814+00
360	153	267	43	numerica	8.00	\N	\N	t	\N	6	2026-06-16 14:39:26.989+00	2026-06-16 14:39:26.989+00
375	153	270	53	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:39:27.114+00	2026-06-16 14:39:27.114+00
383	153	193	53	numerica	9.00	\N	\N	t	\N	6	2026-06-16 14:39:27.222+00	2026-06-16 14:39:27.222+00
395	42	230	108	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.226+00	2026-06-16 14:45:41.226+00
407	42	147	103	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.392+00	2026-06-16 14:45:41.392+00
421	42	147	108	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.518+00	2026-06-16 14:45:41.518+00
423	75	180	53	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.137+00	2026-06-16 22:11:51.137+00
446	75	171	49	numerica	10.00	\N	\N	t	\N	6	2026-06-16 22:11:51.246+00	2026-06-16 22:11:51.246+00
453	75	248	49	numerica	10.00	\N	\N	t	\N	6	2026-06-16 22:11:51.338+00	2026-06-16 22:11:51.338+00
461	75	251	49	numerica	10.00	\N	\N	t	\N	6	2026-06-16 22:11:51.404+00	2026-06-16 22:11:51.404+00
474	75	170	43	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.494+00	2026-06-16 22:11:51.494+00
94	41	69	19	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.652+00	2026-06-15 23:13:36.652+00
104	75	9	23	numerica	9.00	\N	\N	t	\N	11	2026-06-15 23:15:48.596+00	2026-06-16 00:05:54.827225+00
234	42	40	2	numerica	10.00	\N	\N	t	\N	19	2026-06-16 09:53:23.041+00	2026-06-16 09:53:23.041+00
252	63	197	49	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:14.892+00	2026-06-16 14:33:14.892+00
269	63	195	53	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.015+00	2026-06-16 14:33:15.015+00
281	63	193	49	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.07+00	2026-06-16 14:33:15.07+00
302	10	379	49	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.778+00	2026-06-16 14:33:38.778+00
315	10	383	49	numerica	8.00	\N	\N	t	\N	11	2026-06-16 14:33:38.823+00	2026-06-16 14:33:38.823+00
323	10	376	49	numerica	8.00	\N	\N	t	\N	11	2026-06-16 14:33:38.874+00	2026-06-16 14:33:38.874+00
330	9	369	98	observacion	\N	\N	qwfqwewf	t	\N	6	2026-06-16 14:35:19.334+00	2026-06-16 14:35:19.334+00
345	153	262	43	numerica	9.00	\N	\N	t	\N	6	2026-06-16 14:39:26.821+00	2026-06-16 14:39:26.821+00
362	153	264	53	numerica	8.00	\N	\N	t	\N	6	2026-06-16 14:39:26.989+00	2026-06-16 14:39:26.989+00
370	153	271	49	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:39:27.108+00	2026-06-16 14:39:27.108+00
388	153	193	49	numerica	9.00	\N	\N	t	\N	6	2026-06-16 14:39:27.227+00	2026-06-16 14:39:27.227+00
399	42	147	102	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.268+00	2026-06-16 14:45:41.268+00
412	42	146	103	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.426+00	2026-06-16 14:45:41.426+00
429	75	177	43	numerica	10.00	\N	\N	t	\N	6	2026-06-16 22:11:51.142+00	2026-06-16 22:11:51.142+00
447	75	245	49	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.245+00	2026-06-16 22:11:51.245+00
456	75	249	49	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.339+00	2026-06-16 22:11:51.339+00
462	75	175	53	numerica	10.00	\N	\N	t	\N	6	2026-06-16 22:11:51.411+00	2026-06-16 22:11:51.411+00
475	75	170	53	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.505+00	2026-06-16 22:11:51.505+00
95	41	67	19	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.651+00	2026-06-15 23:13:36.651+00
99	75	7	20	numerica	9.00	\N	\N	t	\N	11	2026-06-15 23:15:48.592+00	2026-06-16 00:05:54.798084+00
235	42	35	2	numerica	10.00	\N	\N	t	\N	19	2026-06-16 09:53:23.048+00	2026-06-16 09:53:23.048+00
289	63	192	43	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.091+00	2026-06-16 14:33:15.091+00
301	10	373	43	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.778+00	2026-06-16 14:33:38.778+00
313	10	382	49	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.817+00	2026-06-16 14:33:38.817+00
318	10	385	53	numerica	10.00	\N	\N	t	\N	11	2026-06-16 14:33:38.864+00	2026-06-16 14:33:38.864+00
337	9	366	98	observacion	\N	\N	qwwfqwfw	t	\N	6	2026-06-16 14:35:19.364+00	2026-06-16 14:35:19.364+00
350	153	197	43	numerica	9.00	\N	\N	t	\N	6	2026-06-16 14:39:26.813+00	2026-06-16 14:39:26.813+00
365	153	268	53	numerica	10.00	\N	\N	t	\N	6	2026-06-16 14:39:27.053+00	2026-06-16 14:39:27.053+00
379	153	261	53	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:39:27.188+00	2026-06-16 14:39:27.188+00
400	42	146	102	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.27+00	2026-06-16 14:45:41.27+00
411	42	234	102	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.422+00	2026-06-16 14:45:41.422+00
431	75	180	49	numerica	10.00	\N	\N	t	\N	6	2026-06-16 22:11:51.138+00	2026-06-16 22:11:51.138+00
437	75	169	53	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.24+00	2026-06-16 22:11:51.24+00
448	75	246	53	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.334+00	2026-06-16 22:11:51.334+00
463	75	250	53	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.411+00	2026-06-16 22:11:51.411+00
478	75	166	43	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.506+00	2026-06-16 22:11:51.506+00
96	41	69	23	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.653+00	2026-06-15 23:13:36.653+00
237	42	36	2	numerica	6.00	\N	\N	t	\N	19	2026-06-16 09:53:23.054+00	2026-06-16 09:53:23.054+00
290	63	194	49	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.091+00	2026-06-16 14:33:15.091+00
303	10	378	53	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.778+00	2026-06-16 14:33:38.778+00
317	10	382	53	numerica	10.00	\N	\N	t	\N	11	2026-06-16 14:33:38.849+00	2026-06-16 14:33:38.849+00
336	9	366	89	observacion	\N	\N	qwfqwf	t	\N	6	2026-06-16 14:35:19.341+00	2026-06-16 14:35:19.341+00
391	42	230	103	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.25+00	2026-06-16 14:45:41.25+00
401	42	228	102	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.271+00	2026-06-16 14:45:41.271+00
408	42	148	108	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.398+00	2026-06-16 14:45:41.398+00
414	42	234	108	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.438+00	2026-06-16 14:45:41.438+00
417	42	149	102	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.464+00	2026-06-16 14:45:41.464+00
426	75	169	43	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.144+00	2026-06-16 22:11:51.144+00
441	75	178	53	numerica	10.00	\N	\N	t	\N	6	2026-06-16 22:11:51.242+00	2026-06-16 22:11:51.242+00
458	75	248	43	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.346+00	2026-06-16 22:11:51.346+00
471	75	176	43	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.418+00	2026-06-16 22:11:51.418+00
98	41	68	23	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.656+00	2026-06-15 23:13:36.656+00
101	75	6	23	numerica	9.00	\N	\N	t	\N	11	2026-06-15 23:15:48.597+00	2026-06-16 00:05:54.776917+00
107	75	7	19	numerica	9.00	\N	\N	t	\N	11	2026-06-15 23:15:48.608+00	2026-06-16 00:05:54.804231+00
109	75	9	19	numerica	9.00	\N	\N	t	\N	11	2026-06-15 23:15:48.65+00	2026-06-16 00:05:54.81417+00
141	87	60	20	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.302+00	2026-06-16 00:14:14.152971+00
126	87	57	20	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.24+00	2026-06-16 00:14:14.160778+00
136	87	61	23	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.247+00	2026-06-16 00:14:14.160801+00
148	87	65	19	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.301+00	2026-06-16 00:14:14.210321+00
139	87	64	20	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.3+00	2026-06-16 00:14:14.210268+00
131	87	64	19	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.242+00	2026-06-16 00:14:14.210169+00
156	8	7	20	numerica	4.00	\N	\N	t	\N	6	2026-06-16 00:18:10.883+00	2026-06-16 00:18:10.883+00
160	8	7	19	numerica	2.00	\N	\N	t	\N	6	2026-06-16 00:18:10.966+00	2026-06-16 00:18:10.966+00
164	8	7	23	numerica	1.20	\N	\N	t	\N	6	2026-06-16 00:18:10.981+00	2026-06-16 00:18:10.981+00
169	111	27	5	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.219+00	2026-06-16 00:19:38.219+00
173	111	30	2	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.274+00	2026-06-16 00:19:38.274+00
175	111	32	5	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.297+00	2026-06-16 00:19:38.297+00
182	111	26	5	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.362+00	2026-06-16 00:19:38.362+00
184	111	27	2	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.402+00	2026-06-16 00:19:38.402+00
187	111	26	1	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.403+00	2026-06-16 00:19:38.403+00
190	196	16	36	numerica	4.00	\N	\N	t	\N	6	2026-06-16 00:21:51.032+00	2026-06-16 00:21:51.032+00
197	196	16	35	numerica	4.00	\N	\N	t	\N	6	2026-06-16 00:21:51.035+00	2026-06-16 00:21:51.035+00
196	196	19	35	numerica	4.00	\N	\N	t	\N	6	2026-06-16 00:21:51.038+00	2026-06-16 00:21:51.038+00
203	196	18	14	numerica	4.00	\N	\N	t	\N	6	2026-06-16 00:21:51.098+00	2026-06-16 00:21:51.098+00
210	107	32	1	numerica	0.00	\N	\N	t	\N	6	2026-06-16 00:22:47.072+00	2026-06-16 00:29:47.991874+00
226	107	32	5	numerica	6.00	\N	\N	t	\N	6	2026-06-16 00:22:47.201+00	2026-06-16 00:29:47.95496+00
204	107	25	2	numerica	6.00	\N	\N	t	\N	6	2026-06-16 00:22:47.066+00	2026-06-16 00:29:48.029772+00
214	107	30	5	numerica	0.00	\N	\N	t	\N	6	2026-06-16 00:22:47.073+00	2026-06-16 00:29:48.075175+00
64	10	73	19	numerica	2.00	\N	\N	t	\N	11	2026-06-15 22:27:32.48+00	2026-06-16 08:10:13.496863+00
45	10	71	20	numerica	2.00	\N	\N	t	\N	11	2026-06-15 22:27:32.364+00	2026-06-16 08:10:13.557687+00
61	10	73	20	numerica	2.00	\N	\N	t	\N	11	2026-06-15 22:27:32.468+00	2026-06-16 08:10:13.574239+00
70	10	67	20	numerica	7.00	\N	\N	t	\N	11	2026-06-15 23:01:23.347+00	2026-06-16 08:10:13.579775+00
236	42	33	5	numerica	6.00	\N	\N	t	\N	19	2026-06-16 09:53:23.048+00	2026-06-16 09:53:23.048+00
123	195	15	36	numerica	8.00	\N	\N	t	\N	7	2026-06-16 00:07:45.244+00	2026-06-16 12:20:00.447352+00
118	195	19	35	numerica	8.00	\N	\N	t	\N	7	2026-06-16 00:07:45.235+00	2026-06-16 12:20:00.467185+00
117	195	19	36	numerica	8.00	\N	\N	t	\N	7	2026-06-16 00:07:45.234+00	2026-06-16 12:20:00.466884+00
113	195	17	14	numerica	8.00	\N	\N	t	\N	7	2026-06-16 00:07:45.159+00	2026-06-16 12:20:00.500703+00
292	10	375	53	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.751+00	2026-06-16 14:33:38.751+00
304	10	378	49	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.777+00	2026-06-16 14:33:38.777+00
311	10	377	43	numerica	10.00	\N	\N	t	\N	11	2026-06-16 14:33:38.807+00	2026-06-16 14:33:38.807+00
316	10	381	53	numerica	10.00	\N	\N	t	\N	11	2026-06-16 14:33:38.835+00	2026-06-16 14:33:38.835+00
324	10	385	43	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.877+00	2026-06-16 14:33:38.877+00
325	10	384	43	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.878+00	2026-06-16 14:33:38.878+00
331	9	370	89	observacion	\N	\N	qwf	t	\N	6	2026-06-16 14:35:19.335+00	2026-06-16 14:35:19.335+00
338	9	370	98	observacion	\N	\N	qwfqewf	t	\N	6	2026-06-16 14:35:19.364+00	2026-06-16 14:35:19.364+00
394	42	229	102	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.251+00	2026-06-16 14:45:41.251+00
409	42	148	102	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.423+00	2026-06-16 14:45:41.423+00
432	75	176	53	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.14+00	2026-06-16 22:11:51.14+00
445	75	179	43	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.243+00	2026-06-16 22:11:51.243+00
449	75	245	53	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.336+00	2026-06-16 22:11:51.336+00
465	75	251	43	numerica	0.00	\N	\N	t	\N	6	2026-06-16 22:11:51.412+00	2026-06-16 22:11:51.412+00
102	75	6	20	numerica	9.00	\N	\N	t	\N	11	2026-06-15 23:15:48.601+00	2026-06-16 00:05:54.776943+00
110	75	8	23	numerica	9.00	\N	\N	t	\N	11	2026-06-15 23:15:48.653+00	2026-06-16 00:05:54.811794+00
146	87	60	23	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.302+00	2026-06-16 00:14:14.153595+00
128	87	58	19	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.24+00	2026-06-16 00:14:14.152501+00
145	87	61	20	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.306+00	2026-06-16 00:14:14.153895+00
135	87	59	19	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.246+00	2026-06-16 00:14:14.20765+00
140	87	65	23	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.3+00	2026-06-16 00:14:14.210292+00
152	87	65	20	numerica	0.00	\N	\N	t	\N	11	2026-06-16 00:14:14.228+00	2026-06-16 00:14:14.228+00
132	87	62	19	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.246+00	2026-06-16 00:14:14.297953+00
153	8	6	19	numerica	0.00	\N	\N	t	\N	6	2026-06-16 00:18:10.86+00	2026-06-16 00:18:10.86+00
157	8	8	20	numerica	8.00	\N	\N	t	\N	6	2026-06-16 00:18:10.894+00	2026-06-16 00:18:10.894+00
161	8	6	20	numerica	10.00	\N	\N	t	\N	6	2026-06-16 00:18:10.975+00	2026-06-16 00:18:10.975+00
165	111	29	2	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.209+00	2026-06-16 00:19:38.209+00
168	111	25	2	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.211+00	2026-06-16 00:19:38.211+00
174	111	31	1	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.295+00	2026-06-16 00:19:38.295+00
177	111	32	1	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.296+00	2026-06-16 00:19:38.296+00
176	111	30	5	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.283+00	2026-06-16 00:19:38.283+00
180	111	27	1	numerica	10.00	\N	\N	t	\N	6	2026-06-16 00:19:38.356+00	2026-06-16 00:19:38.356+00
186	111	28	2	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.403+00	2026-06-16 00:19:38.403+00
188	111	26	2	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.401+00	2026-06-16 00:19:38.401+00
192	196	17	14	numerica	4.00	\N	\N	t	\N	6	2026-06-16 00:21:51.032+00	2026-06-16 00:21:51.032+00
195	196	18	35	numerica	4.00	\N	\N	t	\N	6	2026-06-16 00:21:51.035+00	2026-06-16 00:21:51.035+00
193	196	17	35	numerica	4.00	\N	\N	t	\N	6	2026-06-16 00:21:51.032+00	2026-06-16 00:21:51.032+00
198	196	15	14	numerica	10.00	\N	\N	t	\N	6	2026-06-16 00:21:51.035+00	2026-06-16 00:21:51.035+00
202	196	19	36	numerica	4.00	\N	\N	t	\N	6	2026-06-16 00:21:51.098+00	2026-06-16 00:21:51.098+00
224	107	31	1	numerica	0.00	\N	\N	t	\N	6	2026-06-16 00:22:47.176+00	2026-06-16 00:29:47.877726+00
211	107	27	2	numerica	0.00	\N	\N	t	\N	6	2026-06-16 00:22:47.075+00	2026-06-16 00:29:48.011749+00
219	107	27	5	numerica	0.00	\N	\N	t	\N	6	2026-06-16 00:22:47.17+00	2026-06-16 00:29:48.070277+00
215	107	26	5	numerica	2.00	\N	\N	t	\N	6	2026-06-16 00:22:47.07+00	2026-06-16 00:29:48.070176+00
207	107	30	2	numerica	0.00	\N	\N	t	\N	6	2026-06-16 00:22:47.071+00	2026-06-16 00:29:48.058272+00
220	107	28	1	numerica	0.00	\N	\N	t	\N	6	2026-06-16 00:22:47.172+00	2026-06-16 00:29:48.176001+00
62	10	71	19	numerica	2.00	\N	\N	t	\N	11	2026-06-15 22:27:32.473+00	2026-06-16 08:10:13.482362+00
63	10	74	23	numerica	2.00	\N	\N	t	\N	11	2026-06-15 22:27:32.472+00	2026-06-16 08:10:13.56602+00
238	42	37	2	numerica	6.00	\N	\N	t	\N	19	2026-06-16 09:53:23.056+00	2026-06-16 09:53:23.056+00
120	195	15	35	numerica	8.00	\N	\N	t	\N	7	2026-06-16 00:07:45.236+00	2026-06-16 12:20:00.447386+00
124	195	16	36	numerica	8.00	\N	\N	t	\N	7	2026-06-16 00:07:45.244+00	2026-06-16 12:20:00.501619+00
114	195	16	14	numerica	8.00	\N	\N	t	\N	7	2026-06-16 00:07:45.166+00	2026-06-16 12:20:00.470448+00
293	10	376	43	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.752+00	2026-06-16 14:33:38.752+00
308	10	373	49	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.806+00	2026-06-16 14:33:38.806+00
322	10	384	49	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.873+00	2026-06-16 14:33:38.873+00
328	9	366	90	observacion	\N	\N	efqewaf	t	\N	6	2026-06-16 14:35:19.33+00	2026-06-16 14:35:19.33+00
352	153	192	43	numerica	9.00	\N	\N	t	\N	6	2026-06-16 14:39:26.813+00	2026-06-16 14:39:26.813+00
347	153	197	49	numerica	9.00	\N	\N	t	\N	6	2026-06-16 14:39:26.819+00	2026-06-16 14:39:26.819+00
357	153	265	49	numerica	8.00	\N	\N	t	\N	6	2026-06-16 14:39:26.981+00	2026-06-16 14:39:26.981+00
359	153	263	53	numerica	8.00	\N	\N	t	\N	6	2026-06-16 14:39:26.988+00	2026-06-16 14:39:26.988+00
371	153	270	49	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:39:27.105+00	2026-06-16 14:39:27.105+00
374	153	269	49	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:39:27.115+00	2026-06-16 14:39:27.115+00
384	153	194	43	numerica	9.00	\N	\N	t	\N	6	2026-06-16 14:39:27.226+00	2026-06-16 14:39:27.226+00
390	42	232	108	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.25+00	2026-06-16 14:45:41.25+00
410	42	146	108	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.422+00	2026-06-16 14:45:41.422+00
425	75	180	43	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.137+00	2026-06-16 22:11:51.137+00
433	75	175	43	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.139+00	2026-06-16 22:11:51.139+00
439	75	179	49	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.241+00	2026-06-16 22:11:51.241+00
444	75	179	53	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.244+00	2026-06-16 22:11:51.244+00
457	75	250	49	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.342+00	2026-06-16 22:11:51.342+00
460	75	249	53	numerica	10.00	\N	\N	t	\N	6	2026-06-16 22:11:51.347+00	2026-06-16 22:11:51.347+00
470	75	173	49	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.418+00	2026-06-16 22:11:51.418+00
472	75	168	53	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.418+00	2026-06-16 22:11:51.418+00
476	75	168	43	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.505+00	2026-06-16 22:11:51.505+00
97	41	68	19	numerica	1.00	\N	\N	t	\N	6	2026-06-15 23:13:36.658+00	2026-06-15 23:13:36.658+00
105	75	7	23	numerica	9.00	\N	\N	t	\N	11	2026-06-15 23:15:48.6+00	2026-06-16 00:05:54.794198+00
242	42	33	2	numerica	10.00	\N	\N	t	\N	19	2026-06-16 09:53:23.07+00	2026-06-16 09:53:23.07+00
294	10	374	53	numerica	10.00	\N	\N	t	\N	11	2026-06-16 14:33:38.753+00	2026-06-16 14:33:38.753+00
305	10	379	53	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.8+00	2026-06-16 14:33:38.8+00
319	10	379	43	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.87+00	2026-06-16 14:33:38.87+00
340	9	367	98	observacion	\N	\N	wqfqewf	t	\N	6	2026-06-16 14:35:19.364+00	2026-06-16 14:35:19.364+00
344	153	197	53	numerica	9.00	\N	\N	t	\N	6	2026-06-16 14:39:26.815+00	2026-06-16 14:39:26.815+00
348	153	262	49	numerica	10.00	\N	\N	t	\N	6	2026-06-16 14:39:26.812+00	2026-06-16 14:39:26.812+00
363	153	267	53	numerica	10.00	\N	\N	t	\N	6	2026-06-16 14:39:27.053+00	2026-06-16 14:39:27.053+00
366	153	268	49	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:39:27.054+00	2026-06-16 14:39:27.054+00
376	153	269	43	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:39:27.115+00	2026-06-16 14:39:27.115+00
378	153	261	49	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:39:27.187+00	2026-06-16 14:39:27.187+00
387	153	192	49	numerica	9.00	\N	\N	t	\N	6	2026-06-16 14:39:27.226+00	2026-06-16 14:39:27.226+00
389	42	145	103	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.226+00	2026-06-16 14:45:41.226+00
402	42	229	108	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.38+00	2026-06-16 14:45:41.38+00
418	42	149	108	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.482+00	2026-06-16 14:45:41.482+00
424	75	174	49	numerica	10.00	\N	\N	t	\N	6	2026-06-16 22:11:51.139+00	2026-06-16 22:11:51.139+00
440	75	245	43	numerica	10.00	\N	\N	t	\N	6	2026-06-16 22:11:51.242+00	2026-06-16 22:11:51.242+00
451	75	248	53	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.337+00	2026-06-16 22:11:51.337+00
468	75	250	43	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.412+00	2026-06-16 22:11:51.412+00
480	75	173	43	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.507+00	2026-06-16 22:11:51.507+00
106	75	6	19	numerica	9.00	\N	\N	t	\N	11	2026-06-15 23:15:48.59+00	2026-06-16 00:05:54.77694+00
144	87	57	19	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.305+00	2026-06-16 00:14:14.151976+00
137	87	62	23	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.243+00	2026-06-16 00:14:14.152586+00
129	87	63	20	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.242+00	2026-06-16 00:14:14.207734+00
142	87	62	20	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.301+00	2026-06-16 00:14:14.183613+00
150	87	59	20	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.356+00	2026-06-16 00:14:14.2114+00
134	87	58	23	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.243+00	2026-06-16 00:14:14.210652+00
155	8	9	19	numerica	8.00	\N	\N	t	\N	6	2026-06-16 00:18:10.874+00	2026-06-16 00:18:10.874+00
158	8	9	20	numerica	8.00	\N	\N	t	\N	6	2026-06-16 00:18:10.891+00	2026-06-16 00:18:10.891+00
162	8	8	19	numerica	8.00	\N	\N	t	\N	6	2026-06-16 00:18:10.974+00	2026-06-16 00:18:10.974+00
167	111	29	1	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.211+00	2026-06-16 00:19:38.211+00
170	111	29	5	numerica	10.00	\N	\N	t	\N	6	2026-06-16 00:19:38.272+00	2026-06-16 00:19:38.272+00
178	111	31	2	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.353+00	2026-06-16 00:19:38.353+00
181	111	32	2	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.357+00	2026-06-16 00:19:38.357+00
189	196	17	36	numerica	4.00	\N	\N	t	\N	6	2026-06-16 00:21:51.032+00	2026-06-16 00:21:51.032+00
191	196	18	36	numerica	4.00	\N	\N	t	\N	6	2026-06-16 00:21:51.033+00	2026-06-16 00:21:51.033+00
199	196	19	14	numerica	4.00	\N	\N	t	\N	6	2026-06-16 00:21:51.039+00	2026-06-16 00:21:51.039+00
208	107	25	1	numerica	0.00	\N	\N	t	\N	6	2026-06-16 00:22:47.069+00	2026-06-16 00:29:47.876357+00
222	107	32	2	numerica	2.00	\N	\N	t	\N	6	2026-06-16 00:22:47.174+00	2026-06-16 00:29:47.984545+00
218	107	28	2	numerica	10.00	\N	\N	t	\N	6	2026-06-16 00:22:47.161+00	2026-06-16 00:29:47.991254+00
217	107	31	2	numerica	0.00	\N	\N	t	\N	6	2026-06-16 00:22:47.163+00	2026-06-16 00:29:47.976042+00
205	107	26	1	numerica	0.00	\N	\N	t	\N	6	2026-06-16 00:22:47.068+00	2026-06-16 00:29:47.996006+00
212	107	30	1	numerica	0.00	\N	\N	t	\N	6	2026-06-16 00:22:47.069+00	2026-06-16 00:29:48.167899+00
216	107	29	2	numerica	0.00	\N	\N	t	\N	6	2026-06-16 00:22:47.077+00	2026-06-16 00:29:48.176364+00
225	107	26	2	numerica	0.00	\N	\N	t	\N	6	2026-06-16 00:22:47.201+00	2026-06-16 00:29:48.111959+00
71	10	66	20	numerica	10.00	\N	\N	t	\N	11	2026-06-15 23:01:23.376+00	2026-06-16 08:10:13.444782+00
55	10	70	20	numerica	2.00	\N	\N	t	\N	11	2026-06-15 22:27:32.367+00	2026-06-16 08:10:13.488627+00
56	10	72	19	numerica	2.00	\N	\N	t	\N	11	2026-06-15 22:27:32.363+00	2026-06-16 08:10:13.487347+00
243	42	39	1	numerica	6.00	\N	\N	t	\N	19	2026-06-16 09:53:23.104+00	2026-06-16 09:53:23.104+00
122	195	17	35	numerica	8.00	\N	\N	t	\N	7	2026-06-16 00:07:45.236+00	2026-06-16 12:20:00.513132+00
125	195	16	35	numerica	8.00	\N	\N	t	\N	7	2026-06-16 00:07:45.244+00	2026-06-16 12:20:00.471846+00
112	195	18	14	numerica	8.00	\N	\N	t	\N	7	2026-06-16 00:07:45.16+00	2026-06-16 12:20:00.501421+00
119	195	18	36	numerica	8.00	\N	\N	t	\N	7	2026-06-16 00:07:45.237+00	2026-06-16 12:20:00.523744+00
115	195	19	14	numerica	8.00	\N	\N	t	\N	7	2026-06-16 00:07:45.166+00	2026-06-16 12:20:00.509736+00
295	10	375	49	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.754+00	2026-06-16 14:33:38.754+00
310	10	375	43	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.807+00	2026-06-16 14:33:38.807+00
333	9	369	90	observacion	\N	\N	qwf	t	\N	6	2026-06-16 14:35:19.336+00	2026-06-16 14:35:19.336+00
349	153	191	49	numerica	10.00	\N	\N	t	\N	6	2026-06-16 14:39:26.812+00	2026-06-16 14:39:26.812+00
341	153	194	53	numerica	9.00	\N	\N	t	\N	6	2026-06-16 14:39:26.813+00	2026-06-16 14:39:26.813+00
358	153	263	49	numerica	9.00	\N	\N	t	\N	6	2026-06-16 14:39:26.982+00	2026-06-16 14:39:26.982+00
364	153	265	43	numerica	8.00	\N	\N	t	\N	6	2026-06-16 14:39:27.053+00	2026-06-16 14:39:27.053+00
367	153	270	43	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:39:27.104+00	2026-06-16 14:39:27.104+00
377	153	261	43	numerica	10.00	\N	\N	t	\N	6	2026-06-16 14:39:27.188+00	2026-06-16 14:39:27.188+00
380	153	193	43	numerica	9.00	\N	\N	t	\N	6	2026-06-16 14:39:27.21+00	2026-06-16 14:39:27.21+00
393	42	230	102	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.224+00	2026-06-16 14:45:41.224+00
404	42	145	108	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.388+00	2026-06-16 14:45:41.388+00
419	42	149	103	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.484+00	2026-06-16 14:45:41.484+00
428	75	177	49	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.14+00	2026-06-16 22:11:51.14+00
436	75	172	43	numerica	10.00	\N	\N	t	\N	6	2026-06-16 22:11:51.236+00	2026-06-16 22:11:51.236+00
452	75	171	43	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.337+00	2026-06-16 22:11:51.337+00
467	75	176	49	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.413+00	2026-06-16 22:11:51.413+00
477	75	173	53	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.505+00	2026-06-16 22:11:51.505+00
108	75	8	20	numerica	9.00	\N	\N	t	\N	11	2026-06-15 23:15:48.65+00	2026-06-16 00:05:54.835008+00
151	87	58	20	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.366+00	2026-06-16 00:14:14.153857+00
138	87	63	23	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.284+00	2026-06-16 00:14:14.152073+00
127	87	57	23	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.24+00	2026-06-16 00:14:14.151489+00
149	87	60	19	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.305+00	2026-06-16 00:14:14.160762+00
147	87	63	19	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.303+00	2026-06-16 00:14:14.207652+00
130	87	59	23	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.242+00	2026-06-16 00:14:14.210433+00
143	87	64	23	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.3+00	2026-06-16 00:14:14.210811+00
133	87	61	19	numerica	7.00	\N	\N	t	\N	11	2026-06-16 00:09:45.242+00	2026-06-16 00:14:14.297996+00
154	8	9	23	numerica	8.00	\N	\N	t	\N	6	2026-06-16 00:18:10.877+00	2026-06-16 00:18:10.877+00
159	8	6	23	numerica	0.00	\N	\N	t	\N	6	2026-06-16 00:18:10.895+00	2026-06-16 00:18:10.895+00
163	8	8	23	numerica	8.00	\N	\N	t	\N	6	2026-06-16 00:18:10.977+00	2026-06-16 00:18:10.977+00
416	42	228	103	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.473+00	2026-06-16 14:45:41.473+00
427	75	174	43	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.138+00	2026-06-16 22:11:51.138+00
435	75	175	49	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.236+00	2026-06-16 22:11:51.236+00
166	111	28	1	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.211+00	2026-06-16 00:19:38.211+00
171	111	31	5	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.277+00	2026-06-16 00:19:38.277+00
172	111	30	1	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.268+00	2026-06-16 00:19:38.268+00
179	111	25	5	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.355+00	2026-06-16 00:19:38.355+00
183	111	25	1	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.373+00	2026-06-16 00:19:38.373+00
185	111	28	5	numerica	1.00	\N	\N	t	\N	6	2026-06-16 00:19:38.401+00	2026-06-16 00:19:38.401+00
194	196	15	36	numerica	4.00	\N	\N	t	\N	6	2026-06-16 00:21:51.034+00	2026-06-16 00:21:51.034+00
200	196	15	35	numerica	4.00	\N	\N	t	\N	6	2026-06-16 00:21:51.036+00	2026-06-16 00:21:51.036+00
201	196	16	14	numerica	4.00	\N	\N	t	\N	6	2026-06-16 00:21:51.035+00	2026-06-16 00:21:51.035+00
459	75	168	49	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.341+00	2026-06-16 22:11:51.341+00
473	75	172	53	numerica	5.00	\N	\N	t	\N	6	2026-06-16 22:11:51.419+00	2026-06-16 22:11:51.419+00
206	107	25	5	numerica	6.00	\N	\N	t	\N	6	2026-06-16 00:22:47.069+00	2026-06-16 00:29:47.878593+00
209	107	31	5	numerica	2.00	\N	\N	t	\N	6	2026-06-16 00:22:47.07+00	2026-06-16 00:29:48.0013+00
213	107	27	1	numerica	0.00	\N	\N	t	\N	6	2026-06-16 00:22:47.076+00	2026-06-16 00:29:48.017634+00
223	107	29	1	numerica	0.00	\N	\N	t	\N	6	2026-06-16 00:22:47.173+00	2026-06-16 00:29:48.077622+00
227	107	29	5	numerica	0.00	\N	\N	t	\N	6	2026-06-16 00:22:47.201+00	2026-06-16 00:29:48.116336+00
221	107	28	5	numerica	10.00	\N	\N	t	\N	6	2026-06-16 00:22:47.171+00	2026-06-16 00:29:48.175558+00
66	10	67	23	numerica	9.00	\N	\N	t	\N	11	2026-06-15 22:34:44.077+00	2026-06-16 08:10:13.444441+00
54	10	74	20	numerica	7.70	\N	\N	t	\N	11	2026-06-15 22:27:32.372+00	2026-06-16 08:10:13.550142+00
67	10	67	19	numerica	6.00	\N	\N	t	\N	11	2026-06-15 22:34:44.078+00	2026-06-16 08:10:13.579717+00
111	195	15	14	numerica	8.00	\N	\N	t	\N	7	2026-06-16 00:07:45.158+00	2026-06-16 12:20:00.446243+00
116	195	18	35	numerica	8.00	\N	\N	t	\N	7	2026-06-16 00:07:45.231+00	2026-06-16 12:20:00.502971+00
121	195	17	36	numerica	8.00	\N	\N	t	\N	7	2026-06-16 00:07:45.237+00	2026-06-16 12:20:00.500018+00
255	63	264	43	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:14.898+00	2026-06-16 14:33:14.898+00
256	63	263	49	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:14.899+00	2026-06-16 14:33:14.899+00
250	63	191	49	numerica	0.10	\N	\N	t	\N	6	2026-06-16 14:33:14.888+00	2026-06-16 14:33:14.888+00
248	63	194	53	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:14.891+00	2026-06-16 14:33:14.891+00
254	63	262	43	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:14.896+00	2026-06-16 14:33:14.896+00
249	63	263	43	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:14.892+00	2026-06-16 14:33:14.892+00
261	63	264	53	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:14.991+00	2026-06-16 14:33:14.991+00
263	63	268	43	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:14.992+00	2026-06-16 14:33:14.992+00
266	63	191	53	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:14.996+00	2026-06-16 14:33:14.996+00
267	63	193	53	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:14.997+00	2026-06-16 14:33:14.997+00
271	63	262	53	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.016+00	2026-06-16 14:33:15.016+00
270	63	269	49	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.015+00	2026-06-16 14:33:15.015+00
273	63	269	53	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.039+00	2026-06-16 14:33:15.039+00
276	63	271	53	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.04+00	2026-06-16 14:33:15.04+00
275	63	195	49	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.042+00	2026-06-16 14:33:15.042+00
277	63	270	49	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.042+00	2026-06-16 14:33:15.042+00
283	63	261	49	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.07+00	2026-06-16 14:33:15.07+00
285	63	270	43	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.071+00	2026-06-16 14:33:15.071+00
286	63	193	43	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.087+00	2026-06-16 14:33:15.087+00
291	63	192	53	numerica	1.00	\N	\N	t	\N	6	2026-06-16 14:33:15.09+00	2026-06-16 14:33:15.09+00
296	10	373	53	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.756+00	2026-06-16 14:33:38.756+00
307	10	377	53	numerica	9.00	\N	\N	t	\N	11	2026-06-16 14:33:38.804+00	2026-06-16 14:33:38.804+00
329	9	372	98	observacion	\N	\N	qwqwf	t	\N	6	2026-06-16 14:35:19.331+00	2026-06-16 14:35:19.331+00
351	153	191	53	numerica	9.00	\N	\N	t	\N	6	2026-06-16 14:39:26.815+00	2026-06-16 14:39:26.815+00
356	153	267	49	numerica	8.00	\N	\N	t	\N	6	2026-06-16 14:39:26.981+00	2026-06-16 14:39:26.981+00
369	153	268	43	numerica	10.00	\N	\N	t	\N	6	2026-06-16 14:39:27.108+00	2026-06-16 14:39:27.108+00
385	153	192	53	numerica	9.00	\N	\N	t	\N	6	2026-06-16 14:39:27.227+00	2026-06-16 14:39:27.227+00
397	42	145	102	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.252+00	2026-06-16 14:45:41.252+00
406	42	231	108	numerica	7.00	\N	\N	t	\N	6	2026-06-16 14:45:41.398+00	2026-06-16 14:45:41.398+00
\.


--
-- Data for Name: calificacion_extracurricular; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.calificacion_extracurricular (calificacion_extracurricular_id, alumno_id, club, periodo_id, ciclo_id, valor_numerico, modificada_motivo, registrada_por, registrada_en, actualizado_en) FROM stdin;
42	87	computación	20	2	1.00	Actualización en lote desde panel	11	2026-06-16 00:10:19.305+00	2026-06-16 00:12:24.039+00
41	87	inglés	19	2	1.00	Actualización en lote desde panel	11	2026-06-16 00:10:19.308+00	2026-06-16 00:12:24.041+00
45	87	computación	23	2	2.00	Actualización en lote desde panel	11	2026-06-16 00:10:19.312+00	2026-06-16 00:12:24.045+00
46	87	inglés	20	2	2.00	Actualización en lote desde panel	11	2026-06-16 00:10:19.319+00	2026-06-16 00:12:24.049+00
68	107	inglés	5	2	2.00	\N	6	2026-06-16 00:29:55.13+00	2026-06-16 00:29:55.13+00
48	87	danza	20	2	1.00	Actualización en lote desde panel	11	2026-06-16 00:10:19.412+00	2026-06-16 00:12:24.045+00
69	107	computación	1	2	2.00	\N	6	2026-06-16 00:29:55.15+00	2026-06-16 00:29:55.15+00
70	107	danza	2	2	2.00	\N	6	2026-06-16 00:29:55.156+00	2026-06-16 00:29:55.156+00
71	107	computación	5	2	2.00	\N	6	2026-06-16 00:29:55.161+00	2026-06-16 00:29:55.161+00
2	10	danza	1	1	4.00	Actualización en lote desde panel	6	2026-06-15 22:53:33.469+00	2026-06-15 23:10:54.383+00
5	10	computación	2	1	4.00	Actualización en lote desde panel	6	2026-06-15 22:53:33.5+00	2026-06-15 23:10:54.385+00
3	10	danza	2	1	4.00	Actualización en lote desde panel	6	2026-06-15 22:53:33.467+00	2026-06-15 23:10:54.39+00
4	10	inglés	2	1	4.00	Actualización en lote desde panel	6	2026-06-15 22:53:33.492+00	2026-06-15 23:10:54.392+00
1	10	inglés	1	1	9.50	Actualización en lote desde panel	6	2026-06-15 22:47:41.289+00	2026-06-15 23:10:54.39+00
8	10	computación	1	1	4.00	Actualización en lote desde panel	6	2026-06-15 22:53:33.505+00	2026-06-15 23:10:54.399+00
10	10	computación	19	2	4.00	\N	6	2026-06-15 23:10:54.446+00	2026-06-15 23:10:54.446+00
11	10	danza	19	2	4.00	\N	6	2026-06-15 23:10:54.473+00	2026-06-15 23:10:54.473+00
13	41	inglés	20	2	1.00	\N	6	2026-06-15 23:13:49.85+00	2026-06-15 23:13:49.85+00
14	41	danza	19	2	1.00	\N	6	2026-06-15 23:13:49.861+00	2026-06-15 23:13:49.861+00
16	41	danza	20	2	1.00	\N	6	2026-06-15 23:13:49.861+00	2026-06-15 23:13:49.861+00
15	41	inglés	23	2	1.00	\N	6	2026-06-15 23:13:49.861+00	2026-06-15 23:13:49.861+00
17	41	danza	23	2	1.00	\N	6	2026-06-15 23:13:49.865+00	2026-06-15 23:13:49.865+00
18	41	inglés	19	2	1.00	\N	6	2026-06-15 23:13:49.877+00	2026-06-15 23:13:49.877+00
19	41	computación	19	2	1.00	\N	6	2026-06-15 23:13:49.871+00	2026-06-15 23:13:49.871+00
20	41	computación	23	2	1.00	\N	6	2026-06-15 23:13:49.873+00	2026-06-15 23:13:49.873+00
21	41	computación	20	2	1.00	\N	6	2026-06-15 23:13:49.878+00	2026-06-15 23:13:49.878+00
12	10	inglés	19	2	4.00	Actualización en lote desde panel	6	2026-06-15 23:10:54.486+00	2026-06-15 23:35:57.713+00
28	75	computación	20	2	9.00	Actualización en lote desde panel	11	2026-06-15 23:16:17.625+00	2026-06-16 00:05:49.561+00
22	75	danza	19	2	9.00	Actualización en lote desde panel	11	2026-06-15 23:16:17.55+00	2026-06-16 00:05:49.561+00
25	75	danza	20	2	9.00	Actualización en lote desde panel	11	2026-06-15 23:16:17.548+00	2026-06-16 00:05:49.561+00
30	75	inglés	23	2	9.00	Actualización en lote desde panel	11	2026-06-15 23:16:17.644+00	2026-06-16 00:05:49.585+00
26	75	computación	23	2	9.00	Actualización en lote desde panel	11	2026-06-15 23:16:17.61+00	2026-06-16 00:05:49.659+00
49	8	danza	23	2	9.00	\N	6	2026-06-16 00:18:42.944+00	2026-06-16 00:18:42.944+00
29	75	inglés	20	2	9.00	Actualización en lote desde panel	11	2026-06-15 23:16:17.635+00	2026-06-16 00:05:49.659+00
27	75	computación	19	2	9.00	Actualización en lote desde panel	11	2026-06-15 23:16:17.611+00	2026-06-16 00:05:49.658+00
24	75	inglés	19	2	9.00	Actualización en lote desde panel	11	2026-06-15 23:16:17.604+00	2026-06-16 00:05:49.671+00
23	75	danza	23	2	9.00	Actualización en lote desde panel	11	2026-06-15 23:16:17.579+00	2026-06-16 00:05:49.672+00
31	195	inglés	20	2	8.00	\N	6	2026-06-16 00:08:11.235+00	2026-06-16 00:08:11.235+00
32	195	computación	20	2	8.00	\N	6	2026-06-16 00:08:11.246+00	2026-06-16 00:08:11.246+00
33	195	inglés	19	2	8.00	\N	6	2026-06-16 00:08:11.247+00	2026-06-16 00:08:11.247+00
34	195	danza	23	2	8.00	\N	6	2026-06-16 00:08:11.247+00	2026-06-16 00:08:11.247+00
35	195	danza	19	2	8.00	\N	6	2026-06-16 00:08:11.273+00	2026-06-16 00:08:11.273+00
36	195	computación	19	2	8.00	\N	6	2026-06-16 00:08:11.275+00	2026-06-16 00:08:11.275+00
37	195	computación	23	2	8.00	\N	6	2026-06-16 00:08:11.241+00	2026-06-16 00:08:11.241+00
38	195	inglés	23	2	8.00	\N	6	2026-06-16 00:08:11.277+00	2026-06-16 00:08:11.277+00
50	8	inglés	19	2	9.00	\N	6	2026-06-16 00:18:42.99+00	2026-06-16 00:18:42.99+00
51	8	inglés	23	2	10.00	\N	6	2026-06-16 00:18:43.008+00	2026-06-16 00:18:43.008+00
52	8	computación	23	2	9.00	\N	6	2026-06-16 00:18:43.015+00	2026-06-16 00:18:43.015+00
53	8	danza	20	2	9.00	\N	6	2026-06-16 00:18:43.014+00	2026-06-16 00:18:43.014+00
54	8	computación	20	2	9.00	\N	6	2026-06-16 00:18:43.015+00	2026-06-16 00:18:43.015+00
39	195	danza	20	2	8.00	\N	6	2026-06-16 00:08:11.283+00	2026-06-16 00:08:11.283+00
55	8	inglés	20	2	9.00	\N	6	2026-06-16 00:18:43.025+00	2026-06-16 00:18:43.025+00
56	8	computación	19	2	9.00	\N	6	2026-06-16 00:18:43.025+00	2026-06-16 00:18:43.025+00
57	8	danza	19	2	9.00	\N	6	2026-06-16 00:18:43.034+00	2026-06-16 00:18:43.034+00
58	196	danza	19	2	10.00	\N	6	2026-06-16 00:21:59.881+00	2026-06-16 00:21:59.881+00
59	196	inglés	19	2	8.00	\N	6	2026-06-16 00:21:59.892+00	2026-06-16 00:21:59.892+00
60	196	danza	20	2	8.00	\N	6	2026-06-16 00:21:59.893+00	2026-06-16 00:21:59.893+00
61	196	computación	20	2	8.00	\N	6	2026-06-16 00:21:59.896+00	2026-06-16 00:21:59.896+00
62	196	computación	19	2	8.00	\N	6	2026-06-16 00:21:59.896+00	2026-06-16 00:21:59.896+00
72	107	danza	5	2	2.00	\N	6	2026-06-16 00:29:55.166+00	2026-06-16 00:29:55.166+00
63	196	computación	23	2	8.00	\N	6	2026-06-16 00:21:59.899+00	2026-06-16 00:21:59.899+00
64	196	inglés	20	2	8.00	\N	6	2026-06-16 00:21:59.899+00	2026-06-16 00:21:59.899+00
40	87	inglés	23	2	1.00	Actualización en lote desde panel	11	2026-06-16 00:10:19.293+00	2026-06-16 00:12:23.932+00
43	87	danza	23	2	2.00	Actualización en lote desde panel	11	2026-06-16 00:10:19.306+00	2026-06-16 00:12:23.94+00
47	87	danza	19	2	1.00	Actualización en lote desde panel	11	2026-06-16 00:10:19.411+00	2026-06-16 00:12:24.029+00
44	87	computación	19	2	1.00	Actualización en lote desde panel	11	2026-06-16 00:10:19.31+00	2026-06-16 00:12:24.033+00
65	196	inglés	23	2	8.00	\N	6	2026-06-16 00:21:59.901+00	2026-06-16 00:21:59.901+00
66	196	danza	23	2	8.00	\N	6	2026-06-16 00:21:59.902+00	2026-06-16 00:21:59.902+00
67	107	inglés	2	2	2.00	\N	6	2026-06-16 00:29:55.09+00	2026-06-16 00:29:55.09+00
74	107	inglés	1	2	2.00	\N	6	2026-06-16 00:29:55.17+00	2026-06-16 00:29:55.17+00
73	107	danza	1	2	2.00	\N	6	2026-06-16 00:29:55.087+00	2026-06-16 00:29:55.087+00
75	107	computación	2	2	2.00	\N	6	2026-06-16 00:29:55.183+00	2026-06-16 00:29:55.183+00
76	195	Pelis 1	23	2	3.00	\N	6	2026-06-16 06:01:28.722+00	2026-06-16 06:01:28.722+00
77	195	Pelis 1	20	2	3.00	\N	6	2026-06-16 06:01:28.737+00	2026-06-16 06:01:28.737+00
78	195	Pelis 1	19	2	3.00	\N	6	2026-06-16 06:01:28.744+00	2026-06-16 06:01:28.744+00
79	10	Pelis 1	53	7	9.00	\N	11	2026-06-16 14:33:52.16+00	2026-06-16 14:33:52.16+00
80	10	Electricidad	49	7	8.00	\N	11	2026-06-16 14:33:52.184+00	2026-06-16 14:33:52.184+00
81	10	Pelis 1	49	7	9.00	\N	11	2026-06-16 14:33:52.187+00	2026-06-16 14:33:52.187+00
83	10	Pelis 1	43	7	9.00	\N	11	2026-06-16 14:33:52.191+00	2026-06-16 14:33:52.191+00
82	10	Electricidad	53	7	8.00	\N	11	2026-06-16 14:33:52.191+00	2026-06-16 14:33:52.191+00
84	10	Electricidad	43	7	10.00	\N	11	2026-06-16 14:33:52.194+00	2026-06-16 14:33:52.194+00
85	153	Electricidad	90	7	4.00	\N	6	2026-06-16 14:39:36.493+00	2026-06-16 14:39:36.493+00
86	153	Electricidad	98	7	7.00	\N	6	2026-06-16 14:39:36.525+00	2026-06-16 14:39:36.525+00
87	153	Pelis 1	89	7	10.00	\N	6	2026-06-16 14:39:36.53+00	2026-06-16 14:39:36.53+00
88	153	Pelis 1	98	7	7.00	\N	6	2026-06-16 14:39:36.537+00	2026-06-16 14:39:36.537+00
89	153	Electricidad	89	7	7.00	\N	6	2026-06-16 14:39:36.54+00	2026-06-16 14:39:36.54+00
90	153	Pelis 1	90	7	7.00	\N	6	2026-06-16 14:39:36.541+00	2026-06-16 14:39:36.541+00
\.


--
-- Data for Name: calificacion_taller; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.calificacion_taller (calificacion_taller_id, alumno_id, periodo_id, ciclo_id, valor_cualitativo, modificada_motivo, registrada_por, registrada_en, actualizado_en) FROM stdin;
1	10	23	2	A	\N	6	2026-06-15 23:51:43.244+00	2026-06-15 23:51:43.244+00
2	10	20	2	NA	\N	6	2026-06-15 23:51:43.265+00	2026-06-15 23:51:43.265+00
3	10	19	2	NA	\N	6	2026-06-15 23:51:43.27+00	2026-06-15 23:51:43.27+00
4	195	23	2	NA	\N	6	2026-06-16 00:08:16.316+00	2026-06-16 00:08:16.316+00
5	195	20	2	NA	\N	6	2026-06-16 00:08:16.338+00	2026-06-16 00:08:16.338+00
6	195	19	2	NA	\N	6	2026-06-16 00:08:16.346+00	2026-06-16 00:08:16.346+00
7	87	20	2	NA	\N	11	2026-06-16 00:10:16.364+00	2026-06-16 00:10:16.364+00
8	87	19	2	NA	\N	11	2026-06-16 00:10:16.48+00	2026-06-16 00:10:16.48+00
9	87	23	2	A	\N	11	2026-06-16 00:10:16.493+00	2026-06-16 00:10:16.493+00
10	8	23	2	A	\N	6	2026-06-16 00:18:49.447+00	2026-06-16 00:18:49.447+00
11	8	19	2	A	\N	6	2026-06-16 00:18:49.473+00	2026-06-16 00:18:49.473+00
12	8	20	2	A	\N	6	2026-06-16 00:18:49.483+00	2026-06-16 00:18:49.483+00
13	196	19	2	NA	\N	6	2026-06-16 00:22:05.82+00	2026-06-16 00:22:05.82+00
14	196	23	2	NA	\N	6	2026-06-16 00:22:05.835+00	2026-06-16 00:22:05.835+00
15	196	20	2	A	\N	6	2026-06-16 00:22:05.862+00	2026-06-16 00:22:05.862+00
16	107	1	2	A	\N	6	2026-06-16 00:29:59.542+00	2026-06-16 00:29:59.542+00
17	107	2	2	A	\N	6	2026-06-16 00:29:59.594+00	2026-06-16 00:29:59.594+00
18	107	5	2	A	\N	6	2026-06-16 00:29:59.607+00	2026-06-16 00:29:59.607+00
19	42	1	2	NA	\N	19	2026-06-16 09:53:38.443+00	2026-06-16 09:53:38.443+00
21	42	5	2	A	\N	19	2026-06-16 09:53:45.028+00	2026-06-16 09:53:45.028+00
20	42	2	2	A	\N	19	2026-06-16 09:53:45.028+00	2026-06-16 09:53:45.028+00
22	41	20	2	A	\N	19	2026-06-16 09:55:14.12+00	2026-06-16 09:55:14.12+00
23	41	19	2	NA	\N	19	2026-06-16 09:55:14.142+00	2026-06-16 09:55:14.142+00
24	41	23	2	NA	\N	19	2026-06-16 09:55:14.144+00	2026-06-16 09:55:14.144+00
25	10	43	7	A	\N	11	2026-06-16 14:33:57.944+00	2026-06-16 14:33:57.944+00
26	10	49	7	A	\N	11	2026-06-16 14:33:57.977+00	2026-06-16 14:33:57.977+00
27	10	53	7	NA	\N	11	2026-06-16 14:33:57.979+00	2026-06-16 14:33:57.979+00
28	9	89	7	A	\N	6	2026-06-16 14:35:30.731+00	2026-06-16 14:35:30.731+00
29	9	98	7	NA	\N	6	2026-06-16 14:35:30.733+00	2026-06-16 14:35:30.733+00
30	9	90	7	A	\N	6	2026-06-16 14:35:30.738+00	2026-06-16 14:35:30.738+00
31	153	90	7	A	\N	6	2026-06-16 14:39:41.945+00	2026-06-16 14:39:41.945+00
32	153	98	7	NA	\N	6	2026-06-16 14:39:41.983+00	2026-06-16 14:39:41.983+00
33	153	89	7	NA	\N	6	2026-06-16 14:39:41.997+00	2026-06-16 14:39:41.997+00
34	42	103	7	A	\N	6	2026-06-16 14:45:54.491+00	2026-06-16 14:45:54.491+00
35	42	102	7	NA	\N	6	2026-06-16 14:45:54.486+00	2026-06-16 14:45:54.486+00
36	42	108	7	NA	\N	6	2026-06-16 14:45:54.524+00	2026-06-16 14:45:54.524+00
37	75	53	7	NA	\N	6	2026-06-16 22:12:13.004+00	2026-06-16 22:12:13.004+00
38	75	49	7	A	\N	6	2026-06-16 22:12:13.006+00	2026-06-16 22:12:13.006+00
39	75	43	7	NA	\N	6	2026-06-16 22:12:13.01+00	2026-06-16 22:12:13.01+00
\.


--
-- Data for Name: ciclo_escolar; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.ciclo_escolar (ciclo_id, nombre, fecha_inicio, fecha_fin, activo, creado_en, actualizado_en, eliminado_en) FROM stdin;
1	2025-2026	2025-08-04	2026-07-10	f	2026-06-12 05:56:10.405342+00	2026-06-16 10:37:51.864834+00	\N
3	Ciclo 2026-2027	2026-08-01	2027-07-31	f	2026-06-14 18:44:45.452+00	2026-06-16 10:37:51.864834+00	\N
5	Ciclo 2027-2028	2026-06-16	2027-06-16	f	2026-06-16 09:56:16.635+00	2026-06-16 10:37:51.864834+00	\N
2	2026-2027	2026-08-03	2027-07-09	f	2026-06-12 05:56:10.405342+00	2026-06-16 12:15:39.479474+00	\N
7	Ciclo 2026-2030	2026-06-16	2027-06-16	t	2026-06-16 12:17:08.631+00	2026-06-16 12:17:08.631+00	\N
\.


--
-- Data for Name: configuracion_sistema; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.configuracion_sistema (config_id, clave, valor, tipo_dato, descripcion, ciclo_id, actualizado_en, actualizado_por) FROM stdin;
1	recargo_colegiatura_monto	400.00	decimal	RF-22: monto fijo de recargo aplicado cuando la colegiatura se paga después del día tope.	\N	2026-06-12 05:56:10.295236+00	\N
2	recargo_dia_tope_mes	5	int	RF-22: día del mes a partir del cual se considera atrasado el pago de colegiatura.	\N	2026-06-12 05:56:10.295236+00	\N
3	baja_temporal_meses_adeudo	3	int	RF-30: meses consecutivos de adeudo que disparan baja temporal automática.	\N	2026-06-12 05:56:10.297539+00	\N
4	inscripcion_dias_gracia	60	int	RF-45: plazo en días para liquidar inscripción, aranceles y materiales.	\N	2026-06-12 05:56:10.297539+00	\N
5	notif_dias_previos_pago	[5,3]	json	RF-44: días previos al vencimiento en que se envía recordatorio al tutor.	\N	2026-06-12 05:56:10.299242+00	\N
6	notif_dias_previos_inscripcion	5	int	RF-45: días antes del vencimiento del plazo de 60 días para alertar al tutor.	\N	2026-06-12 05:56:10.299242+00	\N
7	login_max_intentos	5	int	RF-05 / RNF-11: intentos fallidos consecutivos antes de bloquear la cuenta.	\N	2026-06-12 05:56:10.300813+00	\N
8	login_minutos_bloqueo	30	int	Duración (minutos) del bloqueo automático de la cuenta tras superar el máximo.	\N	2026-06-12 05:56:10.300813+00	\N
9	smtp_host		string	RNF-22: host del servidor SMTP de salida.	\N	2026-06-12 05:56:10.302781+00	\N
10	smtp_puerto	587	int	RNF-22: puerto SMTP (587 = STARTTLS, estándar).	\N	2026-06-12 05:56:10.302781+00	\N
11	smtp_usuario		string	RNF-22: cuenta de servicio del SMTP.	\N	2026-06-12 05:56:10.302781+00	\N
12	smtp_password_cifrado		string	RNF-22: contraseña cifrada (NUNCA texto plano en producción).	\N	2026-06-12 05:56:10.302781+00	\N
13	smtp_remitente_nombre	Colegio San Diego	string	Nombre que aparece como remitente en los correos enviados.	\N	2026-06-12 05:56:10.302781+00	\N
14	backup_ruta_local		string	RNF-23: ruta local donde se guardan los respaldos automáticos diarios.	\N	2026-06-12 05:56:10.304728+00	\N
15	backup_hora_diaria	02:00	string	RNF-23: hora del día (formato HH:MM, 24h) para ejecutar el respaldo.	\N	2026-06-12 05:56:10.304728+00	\N
17	backup_retener_dias	30	int	Días de retención de respaldos automáticos	\N	2026-06-14 18:44:45.357+00	\N
18	sistema_nombre	SAE Colegio San Diego	string	Nombre del sistema	\N	2026-06-14 18:44:45.366+00	\N
19	sistema_version	2.0.0	string	Versión del sistema	\N	2026-06-14 18:44:45.37+00	\N
\.


--
-- Data for Name: documento; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.documento (documento_id, tipo_documento, nombre_original, ruta_almacen, mime_type, tamano_bytes, hash_sha256, alumno_id, tutor_id, pago_id, factura_id, subido_por, subido_en, actualizado_en) FROM stdin;
1	comprobante_pago	Principio General de la Calidad del Software (1).png	C:\\Users\\Pako\\Desktop\\mmda seria\\Colegio_Sandiego-main\\backend\\uploads\\comprobantes\\pago_6_1781494292110.png	image/png	91057	87b8c3be4431b3f209d5f0281ae94dfe90f3d29af85bcb0256f3ac92b37b5d80	\N	\N	6	\N	1	2026-06-15 03:31:32.124+00	2026-06-15 03:31:32.124+00
2	comprobante_pago	bitacora_2026-06-14.pdf	C:\\Users\\Pako\\Desktop\\mmda seria\\Colegio_Sandiego-main\\backend\\uploads\\comprobantes\\pago_10_1781500046208.pdf	application/pdf	14748	5e1dcafb3c44faf6d679b67c83290588bb0c66e2ed3686d66ce2442bbcc07a8a	\N	\N	10	\N	7	2026-06-15 05:07:26.222+00	2026-06-15 05:07:26.222+00
3	comprobante_pago	bitacora_2026-06-14.pdf	C:\\Users\\Pako\\Desktop\\mmda seria\\Colegio_Sandiego-main\\backend\\uploads\\comprobantes\\pago_11_1781500882915.pdf	application/pdf	14748	5e1dcafb3c44faf6d679b67c83290588bb0c66e2ed3686d66ce2442bbcc07a8a	\N	\N	11	\N	7	2026-06-15 05:21:23.332+00	2026-06-15 05:21:23.332+00
4	comprobante_pago	DiseÃ±o sin tÃ­tulo (3).jpg	C:\\Users\\Pako\\Desktop\\mmda seria\\Colegio_Sandiego-main\\backend\\uploads\\comprobantes\\pago_12_1781500915415.jpg	image/jpeg	86715	12ae2b08950cfad02191a1bbbab6a4a7d80a3da18ad7081e7e31820c7edda9f9	\N	\N	12	\N	7	2026-06-15 05:21:55.61+00	2026-06-15 05:21:55.61+00
5	comprobante_pago	bitacora_2026-06-14.pdf	C:\\Users\\Pako\\Desktop\\mmda seria\\Colegio_Sandiego-main\\backend\\uploads\\comprobantes\\pago_8_1781501005701.pdf	application/pdf	14748	5e1dcafb3c44faf6d679b67c83290588bb0c66e2ed3686d66ce2442bbcc07a8a	\N	\N	8	\N	7	2026-06-15 05:23:25.726+00	2026-06-15 05:23:25.726+00
6	comprobante_pago	Principio General de la Calidad del Software (1).png	C:\\Users\\Pako\\Desktop\\mmda seria\\Colegio_Sandiego-main\\backend\\uploads\\comprobantes\\pago_8_1781501008797.png	image/png	91057	87b8c3be4431b3f209d5f0281ae94dfe90f3d29af85bcb0256f3ac92b37b5d80	\N	\N	8	\N	6	2026-06-15 05:23:28.857+00	2026-06-15 05:23:28.857+00
7	comprobante_pago	Diagrama sin tÃ­tulo.drawio.png	C:\\Users\\Pako\\Desktop\\mmda seria\\Colegio_Sandiego-main\\backend\\uploads\\comprobantes\\pago_10_1781501032735.png	image/png	153740	a6406250e5213c6fd4bfec9f7c6a00e217d6268b5ad651100ab814851d210d0d	\N	\N	10	\N	6	2026-06-15 05:23:52.829+00	2026-06-15 05:23:52.829+00
8	comprobante_pago	Diagrama sin tÃ­tulo.drawio.png	C:\\Users\\Pako\\Desktop\\mmda seria\\Colegio_Sandiego-main\\backend\\uploads\\comprobantes\\pago_10_1781501041914.png	image/png	153740	a6406250e5213c6fd4bfec9f7c6a00e217d6268b5ad651100ab814851d210d0d	\N	\N	10	\N	6	2026-06-15 05:24:01.981+00	2026-06-15 05:24:01.981+00
9	comprobante_pago	Diagrama sin tÃ­tulo.drawio.png	C:\\Users\\Pako\\Desktop\\mmda seria\\Colegio_Sandiego-main\\backend\\uploads\\comprobantes\\pago_6_1781501279384.png	image/png	153740	a6406250e5213c6fd4bfec9f7c6a00e217d6268b5ad651100ab814851d210d0d	\N	\N	6	\N	6	2026-06-15 05:27:59.455+00	2026-06-15 05:27:59.455+00
10	comprobante_pago	Diagrama sin tÃ­tulo.drawio.png	C:\\Users\\Pako\\Desktop\\mmda seria\\Colegio_Sandiego-main\\backend\\uploads\\comprobantes\\pago_3_1781501286535.png	image/png	153740	a6406250e5213c6fd4bfec9f7c6a00e217d6268b5ad651100ab814851d210d0d	\N	\N	3	\N	6	2026-06-15 05:28:06.6+00	2026-06-15 05:28:06.6+00
11	comprobante_pago	class.pdf	C:\\Users\\Pako\\Desktop\\mmda seria\\Colegio_Sandiego-main\\backend\\uploads\\comprobantes\\pago_3_1781501292116.pdf	application/pdf	8924	6d13b5ed952743ef5bb45638f963cd333a76881e0880a781c6b6649390bce105	\N	\N	3	\N	6	2026-06-15 05:28:12.122+00	2026-06-15 05:28:12.122+00
12	comprobante_pago	bitacora_2026-06-14 (1).pdf	C:\\Users\\Pako\\Desktop\\mmda seria\\Colegio_Sandiego-main\\backend\\uploads\\comprobantes\\pago_8_1781501340836.pdf	application/pdf	14750	811edfd79f2a2964ddfb86d2d48b15bf9d4cdafdd05c9549e7929df33230afde	\N	\N	8	\N	7	2026-06-15 05:29:00.843+00	2026-06-15 05:29:00.843+00
13	comprobante_pago	images.jpg	C:\\Users\\Pako\\Desktop\\mmda seria\\Colegio_Sandiego-main\\backend\\uploads\\comprobantes\\pago_5_1781501948942.jpg	image/jpeg	19262	07d8b926baf73566463d87ea69b217ab1b32c85a441c18601c31f3a63f52db75	\N	\N	5	\N	6	2026-06-15 05:39:08.95+00	2026-06-15 05:39:08.95+00
14	comprobante_pago	Diagrama sin tÃ­tulo.drawio.png	C:\\Users\\Pako\\Desktop\\mmda seria\\Colegio_Sandiego-main\\backend\\uploads\\comprobantes\\pago_3_1781501980499.png	image/png	153740	a6406250e5213c6fd4bfec9f7c6a00e217d6268b5ad651100ab814851d210d0d	\N	\N	3	\N	6	2026-06-15 05:39:40.563+00	2026-06-15 05:39:40.563+00
15	comprobante_pago	Diagrama sin tÃ­tulo.drawio.png	C:\\Users\\Pako\\Desktop\\mmda seria\\Colegio_Sandiego-main\\backend\\uploads\\comprobantes\\pago_3_1781501998341.png	image/png	153740	a6406250e5213c6fd4bfec9f7c6a00e217d6268b5ad651100ab814851d210d0d	\N	\N	3	\N	6	2026-06-15 05:39:58.398+00	2026-06-15 05:39:58.398+00
16	comprobante_pago	boleta_sof_a_ram_rez_cruz (2).pdf	C:\\Users\\Pako\\Desktop\\mmda seria\\Colegio_Sandiego-main\\backend\\uploads\\comprobantes\\pago_8_1781502282239.pdf	application/pdf	6036	6684c2bfea34b2d8dab652fa1abc5d3d37c37ecbf2786f5dc77f7dd0fde52310	\N	\N	8	\N	7	2026-06-15 05:44:42.247+00	2026-06-15 05:44:42.247+00
17	comprobante_pago	bitacora_2026-06-14 (1).pdf	C:\\Users\\Pako\\Desktop\\mmda seria\\Colegio_Sandiego-main\\backend\\uploads\\comprobantes\\pago_13_1781502535880.pdf	application/pdf	14750	811edfd79f2a2964ddfb86d2d48b15bf9d4cdafdd05c9549e7929df33230afde	\N	\N	13	\N	7	2026-06-15 05:48:55.888+00	2026-06-15 05:48:55.888+00
18	comprobante_pago	boleta_sof_a_ram_rez_cruz.pdf	C:\\Users\\Pako\\Desktop\\mmda seria\\Colegio_Sandiego-main\\backend\\uploads\\comprobantes\\pago_2_1781502748584.pdf	application/pdf	5554	9d2ff3c3647f9f46ee35a191b2150e3abc9a8ad0263a730d93509b398fdd935f	\N	\N	2	\N	7	2026-06-15 05:52:28.592+00	2026-06-15 05:52:28.592+00
19	comprobante_pago	Diagrama sin tÃ­tulo.drawio.png	C:\\Users\\Pako\\Desktop\\mmda seria\\Colegio_Sandiego-main\\backend\\uploads\\comprobantes\\pago_1_1781511156058.png	image/png	153740	a6406250e5213c6fd4bfec9f7c6a00e217d6268b5ad651100ab814851d210d0d	\N	\N	1	\N	6	2026-06-15 08:12:36.114+00	2026-06-15 08:12:36.114+00
\.


--
-- Data for Name: factura; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.factura (factura_id, tutor_id, numero_factura, uuid_sat, fecha_emision, monto_total, receptor_rfc, receptor_razon_social, receptor_codigo_postal, receptor_direccion, receptor_correo, receptor_regimen_fiscal, uso_cfdi, metodo_pago_sat, forma_pago_sat, estado, xml_documento_id, pdf_documento_id, emitida_por, creada_en, actualizado_en) FROM stdin;
\.


--
-- Data for Name: factura_pago; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.factura_pago (factura_id, pago_id, monto, creado_en, actualizado_en) FROM stdin;
\.


--
-- Data for Name: grupo; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.grupo (grupo_id, ciclo_id, nivel_id, grado, seccion, nombre, docente_titular_id, cupo_maximo, creado_en, actualizado_en, eliminado_en) FROM stdin;
1	2	2	2	A	2°A Primaria	3	25	2026-06-12 05:56:10.632446+00	2026-06-12 05:56:10.632446+00	\N
2	2	2	3	A	3°A Primaria	3	25	2026-06-12 05:56:10.632446+00	2026-06-12 05:56:10.632446+00	\N
3	2	2	4	A	4°A Primaria	3	25	2026-06-12 05:56:10.632446+00	2026-06-12 05:56:10.632446+00	\N
4	2	2	5	A	5°A Primaria	5	25	2026-06-12 05:56:10.632446+00	2026-06-12 05:56:10.632446+00	\N
5	2	2	6	A	6°A Primaria	5	25	2026-06-12 05:56:10.632446+00	2026-06-12 05:56:10.632446+00	\N
7	2	3	2	A	2°A Secundaria	4	30	2026-06-12 05:56:10.632446+00	2026-06-12 05:56:10.632446+00	\N
8	2	3	3	A	3°A Secundaria	4	30	2026-06-12 05:56:10.632446+00	2026-06-12 05:56:10.632446+00	\N
9	3	2	4	A	4°A Primaria	3	\N	2026-06-14 18:44:45.491+00	2026-06-14 18:44:45.491+00	\N
10	3	3	5	B	5°B Secundaria	4	\N	2026-06-14 18:44:45.55+00	2026-06-14 18:44:45.55+00	\N
11	3	4	2	A	2° Bachillerato A	\N	\N	2026-06-14 18:44:45.61+00	2026-06-14 18:44:45.61+00	\N
12	3	4	3	B	3° Bachillerato B	\N	\N	2026-06-14 18:44:45.637+00	2026-06-14 18:44:45.637+00	\N
19	2	4	5	A	5°A Bachillerato	4	\N	2026-06-16 02:02:54.627+00	2026-06-16 02:14:56.621247+00	\N
30	5	2	2	A	2°A Primaria	\N	\N	2026-06-16 10:16:35.156+00	2026-06-16 10:16:35.156+00	\N
32	7	2	2	A	2°A Primaria	3	25	2026-06-16 12:35:14.005+00	2026-06-16 12:35:14.005+00	\N
33	7	2	3	A	3°A Primaria	3	25	2026-06-16 12:35:14.028+00	2026-06-16 12:35:14.028+00	\N
34	7	2	4	A	4°A Primaria	3	25	2026-06-16 12:35:14.038+00	2026-06-16 12:35:14.038+00	\N
35	7	2	5	A	5°A Primaria	5	25	2026-06-16 12:35:14.046+00	2026-06-16 12:35:14.046+00	\N
36	7	2	6	A	6°A Primaria	5	25	2026-06-16 12:35:14.056+00	2026-06-16 12:35:14.056+00	\N
6	2	3	1	A	1°A Secundaria	17	30	2026-06-12 05:56:10.632446+00	2026-06-16 01:11:33.654626+00	\N
37	7	3	2	A	2°A Secundaria	4	30	2026-06-16 12:35:14.068+00	2026-06-16 12:35:14.068+00	\N
16	2	3	1	B	1°B Secundaria	17	\N	2026-06-16 01:40:05.626+00	2026-06-16 01:40:29.663048+00	\N
38	7	3	3	A	3°A Secundaria	4	30	2026-06-16 12:35:14.08+00	2026-06-16 12:35:14.08+00	\N
39	7	4	5	A	5°A Bachillerato	4	\N	2026-06-16 12:35:14.09+00	2026-06-16 12:35:14.09+00	\N
40	7	3	1	A	1°A Secundaria	17	30	2026-06-16 12:35:14.097+00	2026-06-16 12:35:14.097+00	\N
17	2	1	1	B	1°B Preescolar	17	\N	2026-06-16 01:50:19.729+00	2026-06-16 01:50:19.729+00	\N
41	7	3	1	B	1°B Secundaria	17	\N	2026-06-16 12:35:14.107+00	2026-06-16 12:35:14.107+00	\N
42	7	1	1	B	1°B Preescolar	17	\N	2026-06-16 12:35:14.11+00	2026-06-16 12:35:14.11+00	\N
43	7	1	1	A	1°A PREESCOLAR	5	\N	2026-06-16 12:35:14.114+00	2026-06-16 12:35:14.114+00	\N
44	7	4	6	A	6°A Bachillerato	5	\N	2026-06-16 12:35:14.125+00	2026-06-16 12:35:14.125+00	\N
45	7	4	3	A	3°A Bachillerato	17	\N	2026-06-16 12:35:14.13+00	2026-06-16 12:35:14.13+00	\N
46	7	4	2	B	2°B Bachillerato	17	\N	2026-06-16 12:35:14.135+00	2026-06-16 12:35:14.135+00	\N
47	7	4	2	A	2°A Bachillerato	17	\N	2026-06-16 12:35:14.141+00	2026-06-16 12:35:14.141+00	\N
48	7	4	1	A	1°A Bachillerato	17	30	2026-06-16 12:50:45.196+00	2026-06-16 12:51:51.275603+00	\N
49	7	1	2	A	2°A Preescolar	21	30	2026-06-16 12:50:50.229+00	2026-06-16 12:51:51.281232+00	\N
50	7	3	2	B	2°B Secundaria	17	30	2026-06-16 12:50:50.823+00	2026-06-16 12:51:51.285253+00	\N
13	2	1	1	A	1°A PREESCOLAR	5	\N	2026-06-15 20:45:21.263+00	2026-06-16 01:59:49.500592+00	\N
18	2	4	6	A	6°A Bachillerato	5	\N	2026-06-16 02:01:47.898+00	2026-06-16 02:01:47.898+00	\N
20	2	4	3	A	3°A Bachillerato	17	\N	2026-06-16 02:05:57.81+00	2026-06-16 02:05:57.81+00	\N
29	2	4	2	B	2°B Bachillerato	17	\N	2026-06-16 02:07:18.404+00	2026-06-16 02:07:18.404+00	\N
14	2	4	2	A	2°A Bachillerato	17	\N	2026-06-15 21:45:55.72+00	2026-06-16 02:12:09.205386+00	\N
\.


--
-- Data for Name: grupo_materia; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.grupo_materia (grupo_materia_id, grupo_id, materia_id, docente_id, horario, aula, creado_en, actualizado_en, eliminado_en) FROM stdin;
1	3	3	3	Lun-Vie 8:00-9:30	Aula 12	2026-06-12 05:56:10.643991+00	2026-06-12 05:56:10.643991+00	\N
2	3	1	3	Lun-Vie 8:00-9:30	Aula 12	2026-06-12 05:56:10.643991+00	2026-06-12 05:56:10.643991+00	\N
3	3	5	3	Lun-Vie 8:00-9:30	Aula 12	2026-06-12 05:56:10.643991+00	2026-06-12 05:56:10.643991+00	\N
4	3	4	3	Lun-Vie 8:00-9:30	Aula 12	2026-06-12 05:56:10.643991+00	2026-06-12 05:56:10.643991+00	\N
5	3	2	3	Lun-Vie 8:00-9:30	Aula 12	2026-06-12 05:56:10.643991+00	2026-06-12 05:56:10.643991+00	\N
356	48	58	5	\N	\N	2026-06-16 12:50:45.218+00	2026-06-16 12:50:45.218+00	\N
358	48	60	3	\N	\N	2026-06-16 12:50:45.234+00	2026-06-16 12:50:45.234+00	\N
10	9	2	3	Lun-Vie 8:00-9:00	A-101	2026-06-14 18:44:45.507+00	2026-06-14 18:44:45.507+00	\N
11	9	1	3	Lun-Vie 9:00-10:00	A-101	2026-06-14 18:44:45.517+00	2026-06-14 18:44:45.517+00	\N
12	9	3	3	Lun-Mié 10:30-11:30	A-101	2026-06-14 18:44:45.526+00	2026-06-14 18:44:45.526+00	\N
15	10	12	4	Lun-Mié-Vie 7:30-8:30	S-205	2026-06-14 18:44:45.56+00	2026-06-14 18:44:45.56+00	\N
125	6	35	17	Lun, Mie, Vie 12:00-14:00	Aula21	2026-06-16 06:10:11.88+00	2026-06-16 11:07:27.312168+00	\N
122	7	34	17	Lun, Mar, Jue, Vie 07-02	LAB-LIS	2026-06-16 05:41:10.176+00	2026-06-16 11:07:27.50636+00	\N
129	32	2	21	\N	\N	2026-06-16 12:35:14.016+00	2026-06-16 12:35:14.016+00	\N
132	32	4	21	\N	\N	2026-06-16 12:35:14.016+00	2026-06-16 12:35:14.016+00	\N
113	19	30	17	Lun, Mar, Mie, Jue, Vie 09:00-12:00	Aula 3	2026-06-16 04:39:18.685+00	2026-06-16 04:39:18.685+00	\N
13	9	10	5	Mar-Jue 11:30-12:30	C-301	2026-06-14 18:44:45.536+00	2026-06-16 12:44:11.12937+00	\N
14	9	11	17	Vie 12:00-13:00	Cancha	2026-06-14 18:44:45.545+00	2026-06-16 12:44:11.157488+00	\N
16	10	13	4	Mar-Jue 8:30-9:30	S-205	2026-06-14 18:44:45.572+00	2026-06-16 12:44:11.163968+00	\N
17	10	14	21	Lun-Mié 9:30-10:30	S-205	2026-06-14 18:44:45.586+00	2026-06-16 12:44:11.170549+00	\N
18	10	15	4	Mar-Jue 10:30-11:30	Lab-B	2026-06-14 18:44:45.596+00	2026-06-16 12:44:11.176454+00	\N
19	10	16	21	Vie 9:30-11:00	C-301	2026-06-14 18:44:45.606+00	2026-06-16 12:44:11.178833+00	\N
20	11	17	5	Lun-Mié-Vie 7:00-8:00	B-101	2026-06-14 18:44:45.619+00	2026-06-16 12:44:11.181372+00	\N
21	11	18	3	Mar-Jue 8:00-9:30	Lab-F	2026-06-14 18:44:45.629+00	2026-06-16 12:44:11.186342+00	\N
22	12	19	3	Lun-Mié 7:00-8:30	Lab-Q	2026-06-14 18:44:45.649+00	2026-06-16 12:44:11.190257+00	\N
23	12	20	21	Mar-Jue 9:00-10:00	B-203	2026-06-14 18:44:45.659+00	2026-06-16 12:44:11.193271+00	\N
117	7	2	3	\N	\N	2026-06-16 05:41:10.113+00	2026-06-16 12:44:11.196872+00	\N
33	2	2	17	\N	\N	2026-06-15 21:14:53.029+00	2026-06-16 12:44:11.201135+00	\N
34	2	1	21	\N	\N	2026-06-15 21:14:53.039+00	2026-06-16 12:44:11.205685+00	\N
36	2	4	17	\N	\N	2026-06-15 21:14:53.06+00	2026-06-16 12:44:11.218385+00	\N
37	2	5	5	\N	\N	2026-06-15 21:14:53.068+00	2026-06-16 12:44:11.224284+00	\N
38	2	10	3	\N	\N	2026-06-15 21:14:53.076+00	2026-06-16 12:44:11.230213+00	\N
41	4	2	21	\N	\N	2026-06-15 21:14:53.099+00	2026-06-16 12:44:11.239977+00	\N
42	4	1	17	\N	\N	2026-06-15 21:14:53.106+00	2026-06-16 12:44:11.242373+00	\N
43	4	3	3	\N	\N	2026-06-15 21:14:53.115+00	2026-06-16 12:44:11.245169+00	\N
30	1	10	\N	\N	\N	2026-06-15 21:14:52.995+00	2026-06-16 11:06:16.233844+00	2026-06-16 11:06:16.245+00
44	4	4	17	\N	\N	2026-06-15 21:14:53.124+00	2026-06-16 12:44:11.248472+00	\N
45	4	5	5	\N	\N	2026-06-15 21:14:53.135+00	2026-06-16 12:44:11.251952+00	\N
47	4	11	5	\N	\N	2026-06-15 21:14:53.156+00	2026-06-16 12:44:11.261875+00	\N
115	13	33	17	Lun, Mar, Mie, Jue, Vie 10:45-13:45	lab	2026-06-16 04:54:49.977+00	2026-06-16 04:55:06.856182+00	2026-06-16 04:55:06.863+00
48	4	22	5	\N	\N	2026-06-15 21:14:53.166+00	2026-06-16 12:44:11.267962+00	\N
49	5	2	21	\N	\N	2026-06-15 21:14:53.172+00	2026-06-16 12:44:11.273413+00	\N
50	5	1	3	\N	\N	2026-06-15 21:14:53.179+00	2026-06-16 12:44:11.278699+00	\N
51	5	3	5	\N	\N	2026-06-15 21:14:53.185+00	2026-06-16 12:44:11.281495+00	\N
53	5	5	5	\N	\N	2026-06-15 21:14:53.2+00	2026-06-16 12:44:11.287784+00	\N
55	5	11	21	\N	\N	2026-06-15 21:14:53.215+00	2026-06-16 12:44:11.294387+00	\N
24	13	21	\N	07-02	LAB-LIS	2026-06-15 20:45:21.321+00	2026-06-16 04:59:28.265687+00	2026-06-16 04:59:28.289+00
128	32	10	21	\N	\N	2026-06-16 12:35:14.016+00	2026-06-16 12:44:11.300821+00	\N
130	32	1	21	\N	\N	2026-06-16 12:35:14.016+00	2026-06-16 12:44:11.305032+00	\N
131	32	3	17	\N	\N	2026-06-16 12:35:14.016+00	2026-06-16 12:44:11.310566+00	\N
25	1	2	21	\N	\N	2026-06-15 21:14:52.938+00	2026-06-16 11:06:29.828713+00	\N
116	13	34	17	Lun, Mar, Jue, Vie 07-02	LAB-LIS	2026-06-16 04:59:28.33+00	2026-06-16 05:41:09.911139+00	2026-06-16 05:41:09.929+00
28	1	4	21	\N	\N	2026-06-15 21:14:52.978+00	2026-06-16 11:06:29.828713+00	\N
112	13	29	17	Lun, Mar, Mie, Jue, Vie 07:00-00:00	Aula 200	2026-06-16 04:36:52.219+00	2026-06-16 05:41:09.911139+00	\N
114	13	31	17	Lun, Mar, Mie, Jue, Vie 10:45-13:45	lab	2026-06-16 04:46:13.528+00	2026-06-16 05:41:09.911139+00	\N
57	7	7	\N	\N	\N	2026-06-15 21:14:53.235+00	2026-06-16 05:41:10.093907+00	2026-06-16 05:41:10.098+00
58	7	6	\N	\N	\N	2026-06-15 21:14:53.245+00	2026-06-16 05:41:10.093907+00	2026-06-16 05:41:10.098+00
60	7	24	\N	\N	\N	2026-06-15 21:14:53.266+00	2026-06-16 05:41:10.093907+00	2026-06-16 05:41:10.098+00
61	7	25	\N	\N	\N	2026-06-15 21:14:53.274+00	2026-06-16 05:41:10.093907+00	2026-06-16 05:41:10.098+00
63	7	26	\N	\N	\N	2026-06-15 21:14:53.292+00	2026-06-16 05:41:10.093907+00	2026-06-16 05:41:10.098+00
133	32	5	17	\N	\N	2026-06-16 12:35:14.016+00	2026-06-16 12:44:11.31598+00	\N
134	32	11	17	\N	\N	2026-06-16 12:35:14.016+00	2026-06-16 12:44:11.322039+00	\N
66	8	7	5	\N	\N	2026-06-15 21:14:53.329+00	2026-06-16 12:44:11.328027+00	\N
67	8	6	3	\N	\N	2026-06-15 21:14:53.336+00	2026-06-16 12:44:11.330694+00	\N
68	8	23	4	\N	\N	2026-06-15 21:14:53.344+00	2026-06-16 12:44:11.333763+00	\N
69	8	24	4	\N	\N	2026-06-15 21:14:53.352+00	2026-06-16 12:44:11.337963+00	\N
70	8	25	3	\N	\N	2026-06-15 21:14:53.359+00	2026-06-16 12:44:11.340772+00	\N
71	8	8	17	\N	\N	2026-06-15 21:14:53.366+00	2026-06-16 12:44:11.343766+00	\N
72	8	26	5	\N	\N	2026-06-15 21:14:53.373+00	2026-06-16 12:44:11.346954+00	\N
73	8	27	5	\N	\N	2026-06-15 21:14:53.38+00	2026-06-16 12:44:11.350587+00	\N
74	8	28	17	\N	\N	2026-06-15 21:14:53.39+00	2026-06-16 12:44:11.354925+00	\N
136	32	8	5	\N	\N	2026-06-16 12:35:14.016+00	2026-06-16 12:44:11.366292+00	\N
137	33	2	17	\N	\N	2026-06-16 12:35:14.031+00	2026-06-16 12:44:11.372736+00	\N
138	33	1	21	\N	\N	2026-06-16 12:35:14.031+00	2026-06-16 12:44:11.378578+00	\N
139	33	3	3	\N	\N	2026-06-16 12:35:14.031+00	2026-06-16 12:44:11.381018+00	\N
140	33	4	5	\N	\N	2026-06-16 12:35:14.031+00	2026-06-16 12:44:11.384017+00	\N
141	33	5	21	\N	\N	2026-06-16 12:35:14.031+00	2026-06-16 12:44:11.387425+00	\N
142	33	10	3	\N	\N	2026-06-16 12:35:14.031+00	2026-06-16 12:44:11.391403+00	\N
143	33	11	17	\N	\N	2026-06-16 12:35:14.031+00	2026-06-16 12:44:11.394966+00	\N
26	1	1	17	\N	\N	2026-06-15 21:14:52.953+00	2026-06-16 12:44:11.39817+00	\N
27	1	3	21	\N	\N	2026-06-15 21:14:52.964+00	2026-06-16 12:44:11.402021+00	\N
29	1	5	3	\N	\N	2026-06-15 21:14:52.986+00	2026-06-16 12:44:11.406229+00	\N
32	1	22	17	\N	\N	2026-06-15 21:14:53.017+00	2026-06-16 12:44:11.418038+00	\N
126	6	34	17	Lun, Mar, Jue, Vie 07-02	LAB-LIS	2026-06-16 06:10:30.025+00	2026-06-16 06:33:14.455623+00	2026-06-16 06:33:14.474+00
62	7	8	21	Lun, Vie 9:30-11:00	Aula 21	2026-06-15 21:14:53.282+00	2026-06-16 11:07:27.50636+00	\N
145	34	3	3	Lun-Vie 8:00-9:30	Aula 12	2026-06-16 12:35:14.042+00	2026-06-16 12:35:14.042+00	\N
146	34	1	3	Lun-Vie 8:00-9:30	Aula 12	2026-06-16 12:35:14.042+00	2026-06-16 12:35:14.042+00	\N
147	34	5	3	Lun-Vie 8:00-9:30	Aula 12	2026-06-16 12:35:14.042+00	2026-06-16 12:35:14.042+00	\N
148	34	4	3	Lun-Vie 8:00-9:30	Aula 12	2026-06-16 12:35:14.042+00	2026-06-16 12:35:14.042+00	\N
149	34	2	3	Lun-Vie 8:00-9:30	Aula 12	2026-06-16 12:35:14.042+00	2026-06-16 12:35:14.042+00	\N
167	37	34	17	Lun, Mar, Jue, Vie 07-02	LAB-LIS	2026-06-16 12:35:14.073+00	2026-06-16 12:35:14.073+00	\N
180	37	8	21	Lun, Vie 9:30-11:00	Aula 21	2026-06-16 12:35:14.073+00	2026-06-16 12:35:14.073+00	\N
190	39	30	17	Lun, Mar, Mie, Jue, Vie 09:00-12:00	Aula 3	2026-06-16 12:35:14.093+00	2026-06-16 12:35:14.093+00	\N
196	40	35	17	Lun, Mie, Vie 12:00-14:00	Aula21	2026-06-16 12:35:14.1+00	2026-06-16 12:35:14.1+00	\N
198	40	34	17	Lun, Mar, Jue, Vie 07-02	LAB-LIS	2026-06-16 12:35:14.1+00	2026-06-16 12:35:14.1+00	\N
199	43	33	17	Lun, Mar, Mie, Jue, Vie 10:45-13:45	lab	2026-06-16 12:35:14.118+00	2026-06-16 12:35:14.118+00	\N
201	43	34	17	Lun, Mar, Jue, Vie 07-02	LAB-LIS	2026-06-16 12:35:14.118+00	2026-06-16 12:35:14.118+00	\N
202	43	29	17	Lun, Mar, Mie, Jue, Vie 07:00-00:00	Aula 200	2026-06-16 12:35:14.118+00	2026-06-16 12:35:14.118+00	\N
203	43	31	17	Lun, Mar, Mie, Jue, Vie 10:45-13:45	lab	2026-06-16 12:35:14.118+00	2026-06-16 12:35:14.118+00	\N
59	7	23	5	\N	\N	2026-06-15 21:14:53.257+00	2026-06-16 12:44:11.429636+00	\N
119	7	4	17	\N	\N	2026-06-16 05:41:10.135+00	2026-06-16 12:44:11.434101+00	\N
120	7	5	3	\N	\N	2026-06-16 05:41:10.141+00	2026-06-16 12:44:11.437331+00	\N
121	7	11	5	\N	\N	2026-06-16 05:41:10.155+00	2026-06-16 12:44:11.440185+00	\N
65	7	28	21	\N	\N	2026-06-15 21:14:53.322+00	2026-06-16 12:44:11.446761+00	\N
127	1	8	5	\N	\N	2026-06-16 11:06:16.306+00	2026-06-16 12:44:11.45403+00	\N
150	35	2	21	\N	\N	2026-06-16 12:35:14.05+00	2026-06-16 12:44:11.458109+00	\N
151	35	1	21	\N	\N	2026-06-16 12:35:14.05+00	2026-06-16 12:44:11.463957+00	\N
152	35	3	17	\N	\N	2026-06-16 12:35:14.05+00	2026-06-16 12:44:11.469806+00	\N
153	35	4	5	\N	\N	2026-06-16 12:35:14.05+00	2026-06-16 12:44:11.475502+00	\N
154	35	5	17	\N	\N	2026-06-16 12:35:14.05+00	2026-06-16 12:44:11.480748+00	\N
159	36	1	21	\N	\N	2026-06-16 12:35:14.061+00	2026-06-16 12:44:11.497971+00	\N
160	36	3	3	\N	\N	2026-06-16 12:35:14.061+00	2026-06-16 12:44:11.501924+00	\N
161	36	4	3	\N	\N	2026-06-16 12:35:14.061+00	2026-06-16 12:44:11.507443+00	\N
162	36	5	21	\N	\N	2026-06-16 12:35:14.061+00	2026-06-16 12:44:11.513517+00	\N
164	36	11	17	\N	\N	2026-06-16 12:35:14.061+00	2026-06-16 12:44:11.524448+00	\N
166	37	2	4	\N	\N	2026-06-16 12:35:14.073+00	2026-06-16 12:44:11.529908+00	\N
168	37	7	17	\N	\N	2026-06-16 12:35:14.073+00	2026-06-16 12:44:11.533329+00	\N
169	37	6	3	\N	\N	2026-06-16 12:35:14.073+00	2026-06-16 12:44:11.537735+00	\N
170	37	24	4	\N	\N	2026-06-16 12:35:14.073+00	2026-06-16 12:44:11.540648+00	\N
171	37	25	3	\N	\N	2026-06-16 12:35:14.073+00	2026-06-16 12:44:11.543503+00	\N
172	37	26	21	\N	\N	2026-06-16 12:35:14.073+00	2026-06-16 12:44:11.547791+00	\N
173	37	1	4	\N	\N	2026-06-16 12:35:14.073+00	2026-06-16 12:44:11.551301+00	\N
174	37	23	3	\N	\N	2026-06-16 12:35:14.073+00	2026-06-16 12:44:11.557135+00	\N
175	37	4	17	\N	\N	2026-06-16 12:35:14.073+00	2026-06-16 12:44:11.56236+00	\N
176	37	5	17	\N	\N	2026-06-16 12:35:14.073+00	2026-06-16 12:44:11.567803+00	\N
177	37	11	21	\N	\N	2026-06-16 12:35:14.073+00	2026-06-16 12:44:11.573491+00	\N
178	37	27	3	\N	\N	2026-06-16 12:35:14.073+00	2026-06-16 12:44:11.57636+00	\N
179	37	28	4	\N	\N	2026-06-16 12:35:14.073+00	2026-06-16 12:44:11.579183+00	\N
181	38	7	21	\N	\N	2026-06-16 12:35:14.085+00	2026-06-16 12:44:11.581801+00	\N
183	38	23	4	\N	\N	2026-06-16 12:35:14.085+00	2026-06-16 12:44:11.588774+00	\N
184	38	24	17	\N	\N	2026-06-16 12:35:14.085+00	2026-06-16 12:44:11.591682+00	\N
185	38	25	17	\N	\N	2026-06-16 12:35:14.085+00	2026-06-16 12:44:11.594925+00	\N
186	38	8	17	\N	\N	2026-06-16 12:35:14.085+00	2026-06-16 12:44:11.598025+00	\N
187	38	26	3	\N	\N	2026-06-16 12:35:14.085+00	2026-06-16 12:44:11.603907+00	\N
188	38	27	5	\N	\N	2026-06-16 12:35:14.085+00	2026-06-16 12:44:11.609233+00	\N
189	38	28	3	\N	\N	2026-06-16 12:35:14.085+00	2026-06-16 12:44:11.614178+00	\N
200	43	21	17	07-02	LAB-LIS	2026-06-16 12:35:14.118+00	2026-06-16 12:44:11.619747+00	\N
205	42	37	5	\N	\N	2026-06-16 12:40:56.922+00	2026-06-16 12:44:11.625703+00	\N
207	42	39	3	\N	\N	2026-06-16 12:40:56.928+00	2026-06-16 12:44:11.630641+00	\N
208	42	40	5	\N	\N	2026-06-16 12:40:56.933+00	2026-06-16 12:44:11.633794+00	\N
209	42	41	17	\N	\N	2026-06-16 12:40:56.937+00	2026-06-16 12:44:11.638022+00	\N
210	42	42	17	\N	\N	2026-06-16 12:40:56.94+00	2026-06-16 12:44:11.641166+00	\N
211	43	36	17	\N	\N	2026-06-16 12:40:56.944+00	2026-06-16 12:44:11.644477+00	\N
213	43	38	3	\N	\N	2026-06-16 12:40:56.952+00	2026-06-16 12:44:11.655653+00	\N
214	43	39	3	\N	\N	2026-06-16 12:40:56.959+00	2026-06-16 12:44:11.660865+00	\N
216	43	41	21	\N	\N	2026-06-16 12:40:56.97+00	2026-06-16 12:44:11.668985+00	\N
217	43	42	5	\N	\N	2026-06-16 12:40:56.976+00	2026-06-16 12:44:11.672026+00	\N
218	32	43	5	\N	\N	2026-06-16 12:40:57.012+00	2026-06-16 12:44:11.675026+00	\N
219	32	44	17	\N	\N	2026-06-16 12:40:57.016+00	2026-06-16 12:44:11.677769+00	\N
220	32	45	17	\N	\N	2026-06-16 12:40:57.023+00	2026-06-16 12:44:11.680199+00	\N
221	32	46	17	\N	\N	2026-06-16 12:40:57.029+00	2026-06-16 12:44:11.682718+00	\N
223	33	43	17	\N	\N	2026-06-16 12:40:57.04+00	2026-06-16 12:44:11.690646+00	\N
224	33	44	3	\N	\N	2026-06-16 12:40:57.043+00	2026-06-16 12:44:11.69605+00	\N
225	33	45	17	\N	\N	2026-06-16 12:40:57.046+00	2026-06-16 12:44:11.701786+00	\N
226	33	46	5	\N	\N	2026-06-16 12:40:57.048+00	2026-06-16 12:44:11.707437+00	\N
227	33	47	17	\N	\N	2026-06-16 12:40:57.052+00	2026-06-16 12:44:11.712221+00	\N
228	34	43	5	\N	\N	2026-06-16 12:40:57.056+00	2026-06-16 12:44:11.714604+00	\N
230	34	45	21	\N	\N	2026-06-16 12:40:57.064+00	2026-06-16 12:44:11.721985+00	\N
231	34	46	17	\N	\N	2026-06-16 12:40:57.068+00	2026-06-16 12:44:11.724911+00	\N
232	34	10	5	\N	\N	2026-06-16 12:40:57.074+00	2026-06-16 12:44:11.727747+00	\N
233	34	47	21	\N	\N	2026-06-16 12:40:57.079+00	2026-06-16 12:44:11.731305+00	\N
234	34	11	17	\N	\N	2026-06-16 12:40:57.085+00	2026-06-16 12:44:11.737043+00	\N
235	35	43	21	\N	\N	2026-06-16 12:40:57.09+00	2026-06-16 12:44:11.742569+00	\N
236	35	44	17	\N	\N	2026-06-16 12:40:57.093+00	2026-06-16 12:44:11.747741+00	\N
237	35	45	21	\N	\N	2026-06-16 12:40:57.095+00	2026-06-16 12:44:11.75277+00	\N
238	35	46	17	\N	\N	2026-06-16 12:40:57.098+00	2026-06-16 12:44:11.755911+00	\N
118	7	1	3	\N	\N	2026-06-16 05:41:10.123+00	2026-06-16 12:44:11.423617+00	\N
64	7	27	5	\N	\N	2026-06-15 21:14:53.309+00	2026-06-16 12:44:11.443627+00	\N
163	36	10	21	\N	\N	2026-06-16 12:35:14.061+00	2026-06-16 12:44:11.519177+00	\N
182	38	6	21	\N	\N	2026-06-16 12:35:14.085+00	2026-06-16 12:44:11.584961+00	\N
212	43	37	3	\N	\N	2026-06-16 12:40:56.948+00	2026-06-16 12:44:11.6503+00	\N
242	36	45	21	\N	\N	2026-06-16 12:40:57.114+00	2026-06-16 12:44:11.765962+00	\N
243	36	46	3	\N	\N	2026-06-16 12:40:57.117+00	2026-06-16 12:44:11.770197+00	\N
245	37	49	4	\N	\N	2026-06-16 12:40:57.196+00	2026-06-16 12:44:11.777226+00	\N
246	37	51	5	\N	\N	2026-06-16 12:40:57.202+00	2026-06-16 12:44:11.782757+00	\N
247	37	52	4	\N	\N	2026-06-16 12:40:57.208+00	2026-06-16 12:44:11.789139+00	\N
248	37	53	21	\N	\N	2026-06-16 12:40:57.214+00	2026-06-16 12:44:11.794964+00	\N
249	37	54	17	\N	\N	2026-06-16 12:40:57.219+00	2026-06-16 12:44:11.798684+00	\N
250	37	55	5	\N	\N	2026-06-16 12:40:57.222+00	2026-06-16 12:44:11.800979+00	\N
251	37	56	5	\N	\N	2026-06-16 12:40:57.225+00	2026-06-16 12:44:11.804905+00	\N
252	37	57	4	\N	\N	2026-06-16 12:40:57.227+00	2026-06-16 12:44:11.808138+00	\N
253	38	50	3	\N	\N	2026-06-16 12:40:57.23+00	2026-06-16 12:44:11.811109+00	\N
254	38	51	5	\N	\N	2026-06-16 12:40:57.234+00	2026-06-16 12:44:11.815056+00	\N
255	38	52	3	\N	\N	2026-06-16 12:40:57.237+00	2026-06-16 12:44:11.820915+00	\N
256	38	53	4	\N	\N	2026-06-16 12:40:57.241+00	2026-06-16 12:44:11.826204+00	\N
257	38	54	4	\N	\N	2026-06-16 12:40:57.244+00	2026-06-16 12:44:11.831405+00	\N
258	38	55	5	\N	\N	2026-06-16 12:40:57.25+00	2026-06-16 12:44:11.836457+00	\N
259	38	56	21	\N	\N	2026-06-16 12:40:57.256+00	2026-06-16 12:44:11.839201+00	\N
260	38	57	5	\N	\N	2026-06-16 12:40:57.262+00	2026-06-16 12:44:11.841292+00	\N
263	40	24	3	\N	\N	2026-06-16 12:40:57.274+00	2026-06-16 12:44:11.849146+00	\N
265	40	28	3	\N	\N	2026-06-16 12:40:57.28+00	2026-06-16 12:44:11.856653+00	\N
266	40	52	21	\N	\N	2026-06-16 12:40:57.283+00	2026-06-16 12:44:11.859862+00	\N
267	40	26	3	\N	\N	2026-06-16 12:40:57.286+00	2026-06-16 12:44:11.865483+00	\N
268	40	53	5	\N	\N	2026-06-16 12:40:57.29+00	2026-06-16 12:44:11.870903+00	\N
269	40	54	21	\N	\N	2026-06-16 12:40:57.293+00	2026-06-16 12:44:11.876091+00	\N
270	40	55	21	\N	\N	2026-06-16 12:40:57.299+00	2026-06-16 12:44:11.881508+00	\N
272	40	57	21	\N	\N	2026-06-16 12:40:57.312+00	2026-06-16 12:44:11.888534+00	\N
273	41	6	3	\N	\N	2026-06-16 12:40:57.315+00	2026-06-16 12:44:11.891174+00	\N
274	41	7	17	\N	\N	2026-06-16 12:40:57.318+00	2026-06-16 12:44:11.893853+00	\N
275	41	48	17	\N	\N	2026-06-16 12:40:57.321+00	2026-06-16 12:44:11.896437+00	\N
276	41	25	17	\N	\N	2026-06-16 12:40:57.324+00	2026-06-16 12:44:11.899151+00	\N
277	41	24	21	\N	\N	2026-06-16 12:40:57.327+00	2026-06-16 12:44:11.903085+00	\N
280	41	28	21	\N	\N	2026-06-16 12:40:57.337+00	2026-06-16 12:44:11.917819+00	\N
282	41	26	3	\N	\N	2026-06-16 12:40:57.349+00	2026-06-16 12:44:11.92843+00	\N
283	41	53	21	\N	\N	2026-06-16 12:40:57.355+00	2026-06-16 12:44:11.930849+00	\N
284	41	54	21	\N	\N	2026-06-16 12:40:57.361+00	2026-06-16 12:44:11.932965+00	\N
285	41	55	17	\N	\N	2026-06-16 12:40:57.364+00	2026-06-16 12:44:11.936682+00	\N
286	41	56	5	\N	\N	2026-06-16 12:40:57.366+00	2026-06-16 12:44:11.939283+00	\N
287	41	57	3	\N	\N	2026-06-16 12:40:57.369+00	2026-06-16 12:44:11.941859+00	\N
288	39	61	3	\N	\N	2026-06-16 12:40:57.527+00	2026-06-16 12:44:11.944688+00	\N
289	39	69	4	\N	\N	2026-06-16 12:40:57.53+00	2026-06-16 12:44:11.948155+00	\N
290	39	70	5	\N	\N	2026-06-16 12:40:57.534+00	2026-06-16 12:44:11.951748+00	\N
291	39	71	17	\N	\N	2026-06-16 12:40:57.539+00	2026-06-16 12:44:11.95784+00	\N
292	39	72	17	\N	\N	2026-06-16 12:40:57.545+00	2026-06-16 12:44:11.96374+00	\N
293	39	73	4	\N	\N	2026-06-16 12:40:57.551+00	2026-06-16 12:44:11.969305+00	\N
294	39	74	5	\N	\N	2026-06-16 12:40:57.558+00	2026-06-16 12:44:11.974997+00	\N
296	39	76	3	\N	\N	2026-06-16 12:40:57.563+00	2026-06-16 12:44:11.979977+00	\N
297	39	77	4	\N	\N	2026-06-16 12:40:57.566+00	2026-06-16 12:44:11.982505+00	\N
298	39	78	21	\N	\N	2026-06-16 12:40:57.57+00	2026-06-16 12:44:11.985682+00	\N
299	39	79	4	\N	\N	2026-06-16 12:40:57.573+00	2026-06-16 12:44:11.988532+00	\N
300	39	80	21	\N	\N	2026-06-16 12:40:57.577+00	2026-06-16 12:44:11.991921+00	\N
301	39	81	21	\N	\N	2026-06-16 12:40:57.58+00	2026-06-16 12:44:11.995247+00	\N
302	39	82	17	\N	\N	2026-06-16 12:40:57.584+00	2026-06-16 12:44:11.998532+00	\N
303	39	83	17	\N	\N	2026-06-16 12:40:57.59+00	2026-06-16 12:44:12.004795+00	\N
304	44	61	21	\N	\N	2026-06-16 12:40:57.595+00	2026-06-16 12:44:12.010366+00	\N
306	44	70	3	\N	\N	2026-06-16 12:40:57.606+00	2026-06-16 12:44:12.021304+00	\N
307	44	71	5	\N	\N	2026-06-16 12:40:57.61+00	2026-06-16 12:44:12.023823+00	\N
308	44	72	5	\N	\N	2026-06-16 12:40:57.619+00	2026-06-16 12:44:12.026265+00	\N
309	44	73	17	\N	\N	2026-06-16 12:40:57.627+00	2026-06-16 12:44:12.028571+00	\N
313	44	77	3	\N	\N	2026-06-16 12:40:57.652+00	2026-06-16 12:44:12.041563+00	\N
314	44	78	5	\N	\N	2026-06-16 12:40:57.656+00	2026-06-16 12:44:12.044878+00	\N
315	44	79	3	\N	\N	2026-06-16 12:40:57.658+00	2026-06-16 12:44:12.050727+00	\N
319	44	83	17	\N	\N	2026-06-16 12:40:57.672+00	2026-06-16 12:44:12.070409+00	\N
320	45	61	5	\N	\N	2026-06-16 12:40:57.675+00	2026-06-16 12:44:12.07275+00	\N
321	45	69	17	\N	\N	2026-06-16 12:40:57.681+00	2026-06-16 12:44:12.075177+00	\N
322	45	70	17	\N	\N	2026-06-16 12:40:57.687+00	2026-06-16 12:44:12.077382+00	\N
323	45	71	21	\N	\N	2026-06-16 12:40:57.697+00	2026-06-16 12:44:12.079693+00	\N
324	45	72	3	\N	\N	2026-06-16 12:40:57.701+00	2026-06-16 12:44:12.082495+00	\N
325	45	73	17	\N	\N	2026-06-16 12:40:57.704+00	2026-06-16 12:44:12.086117+00	\N
326	45	74	21	\N	\N	2026-06-16 12:40:57.707+00	2026-06-16 12:44:12.089812+00	\N
327	45	75	21	\N	\N	2026-06-16 12:40:57.711+00	2026-06-16 12:44:12.095195+00	\N
328	45	76	21	\N	\N	2026-06-16 12:40:57.715+00	2026-06-16 12:44:12.100913+00	\N
330	45	78	17	\N	\N	2026-06-16 12:40:57.723+00	2026-06-16 12:44:12.111376+00	\N
331	45	79	21	\N	\N	2026-06-16 12:40:57.726+00	2026-06-16 12:44:12.113502+00	\N
333	45	81	5	\N	\N	2026-06-16 12:40:57.739+00	2026-06-16 12:44:12.11974+00	\N
334	45	82	5	\N	\N	2026-06-16 12:40:57.744+00	2026-06-16 12:44:12.122923+00	\N
337	46	59	5	\N	\N	2026-06-16 12:40:57.757+00	2026-06-16 12:44:12.13348+00	\N
338	46	60	17	\N	\N	2026-06-16 12:40:57.76+00	2026-06-16 12:44:12.139793+00	\N
339	46	62	21	\N	\N	2026-06-16 12:40:57.763+00	2026-06-16 12:44:12.151858+00	\N
341	46	64	17	\N	\N	2026-06-16 12:40:57.769+00	2026-06-16 12:44:12.162948+00	\N
344	46	77	3	\N	\N	2026-06-16 12:40:57.782+00	2026-06-16 12:44:12.171802+00	\N
345	46	68	3	\N	\N	2026-06-16 12:40:57.788+00	2026-06-16 12:44:12.175152+00	\N
347	47	59	21	\N	\N	2026-06-16 12:40:57.799+00	2026-06-16 12:44:12.181185+00	\N
348	47	60	5	\N	\N	2026-06-16 12:40:57.802+00	2026-06-16 12:44:12.18527+00	\N
349	47	62	21	\N	\N	2026-06-16 12:40:57.806+00	2026-06-16 12:44:12.189292+00	\N
350	47	63	21	\N	\N	2026-06-16 12:40:57.809+00	2026-06-16 12:44:12.194973+00	\N
351	47	64	3	\N	\N	2026-06-16 12:40:57.812+00	2026-06-16 12:44:12.200278+00	\N
352	47	65	21	\N	\N	2026-06-16 12:40:57.815+00	2026-06-16 12:44:12.205659+00	\N
229	34	44	3	\N	\N	2026-06-16 12:40:57.06+00	2026-06-16 12:44:11.717738+00	\N
241	36	44	17	\N	\N	2026-06-16 12:40:57.109+00	2026-06-16 12:44:11.763084+00	\N
244	36	47	21	\N	\N	2026-06-16 12:40:57.123+00	2026-06-16 12:44:11.773725+00	\N
261	40	48	21	\N	\N	2026-06-16 12:40:57.268+00	2026-06-16 12:44:11.843547+00	\N
278	41	8	5	\N	\N	2026-06-16 12:40:57.331+00	2026-06-16 12:44:11.906486+00	\N
295	39	75	21	\N	\N	2026-06-16 12:40:57.56+00	2026-06-16 12:44:11.977568+00	\N
346	47	58	3	\N	\N	2026-06-16 12:40:57.793+00	2026-06-16 12:44:12.17827+00	\N
361	48	64	17	\N	\N	2026-06-16 12:50:45.246+00	2026-06-16 12:50:45.246+00	\N
363	48	66	3	\N	\N	2026-06-16 12:50:45.256+00	2026-06-16 12:50:45.256+00	\N
364	48	77	5	\N	\N	2026-06-16 12:50:45.26+00	2026-06-16 12:50:45.26+00	\N
365	48	67	21	\N	\N	2026-06-16 12:50:45.265+00	2026-06-16 12:50:45.265+00	\N
367	49	37	21	\N	\N	2026-06-16 12:50:50.245+00	2026-06-16 12:50:50.245+00	\N
368	49	38	3	\N	\N	2026-06-16 12:50:50.253+00	2026-06-16 12:50:50.253+00	\N
369	49	39	5	\N	\N	2026-06-16 12:50:50.259+00	2026-06-16 12:50:50.259+00	\N
370	49	40	17	\N	\N	2026-06-16 12:50:50.265+00	2026-06-16 12:50:50.265+00	\N
374	50	7	17	\N	\N	2026-06-16 12:50:50.841+00	2026-06-16 12:50:50.841+00	\N
375	50	49	17	\N	\N	2026-06-16 12:50:50.849+00	2026-06-16 12:50:50.849+00	\N
376	50	24	3	\N	\N	2026-06-16 12:50:50.854+00	2026-06-16 12:50:50.854+00	\N
378	50	51	17	\N	\N	2026-06-16 12:50:50.863+00	2026-06-16 12:50:50.863+00	\N
379	50	28	17	\N	\N	2026-06-16 12:50:50.868+00	2026-06-16 12:50:50.868+00	\N
380	50	52	17	\N	\N	2026-06-16 12:50:50.872+00	2026-06-16 12:50:50.872+00	\N
382	50	53	5	\N	\N	2026-06-16 12:50:50.881+00	2026-06-16 12:50:50.881+00	\N
383	50	54	5	\N	\N	2026-06-16 12:50:50.887+00	2026-06-16 12:50:50.887+00	\N
384	50	55	5	\N	\N	2026-06-16 12:50:50.894+00	2026-06-16 12:50:50.894+00	\N
385	50	56	17	\N	\N	2026-06-16 12:50:50.901+00	2026-06-16 12:50:50.901+00	\N
386	50	57	3	\N	\N	2026-06-16 12:50:50.907+00	2026-06-16 12:50:50.907+00	\N
357	48	59	\N	\N	\N	2026-06-16 12:50:45.227+00	2026-06-16 19:34:24.648248+00	\N
8	6	8	\N	Lun-Vie 9:30-11:00	Aula 21	2026-06-12 05:56:10.648003+00	2026-06-16 19:34:24.648248+00	2026-06-16 11:07:27.32+00
6	6	6	\N	Lun-Vie 9:30-11:00	Aula 21	2026-06-12 05:56:10.648003+00	2026-06-16 19:34:24.648248+00	2026-06-16 06:10:11.761+00
123	6	1	\N	Lun-Vie 9:30-11:00	Aula 21	2026-06-16 06:10:11.828+00	2026-06-16 19:34:24.648248+00	\N
7	6	9	\N	Lun-Vie 9:30-11:00	Aula 21	2026-06-12 05:56:10.648003+00	2026-06-16 19:34:24.648248+00	\N
124	6	2	\N	Lun-Vie 9:30-11:00	Aula 21	2026-06-16 06:10:11.866+00	2026-06-16 19:34:24.648248+00	\N
9	6	7	\N	Lun-Vie 9:30-11:00	Aula 21	2026-06-12 05:56:10.648003+00	2026-06-16 19:34:24.648248+00	2026-06-16 06:10:11.761+00
35	2	3	\N	\N	\N	2026-06-15 21:14:53.049+00	2026-06-16 19:34:24.648248+00	\N
39	2	11	\N	\N	\N	2026-06-15 21:14:53.083+00	2026-06-16 19:34:24.648248+00	\N
40	2	22	\N	\N	\N	2026-06-15 21:14:53.09+00	2026-06-16 19:34:24.648248+00	\N
46	4	10	\N	\N	\N	2026-06-15 21:14:53.146+00	2026-06-16 19:34:24.648248+00	\N
52	5	4	\N	\N	\N	2026-06-15 21:14:53.193+00	2026-06-16 19:34:24.648248+00	\N
54	5	10	\N	\N	\N	2026-06-15 21:14:53.208+00	2026-06-16 19:34:24.648248+00	\N
56	5	22	\N	\N	\N	2026-06-15 21:14:53.225+00	2026-06-16 19:34:24.648248+00	\N
135	32	22	\N	\N	\N	2026-06-16 12:35:14.016+00	2026-06-16 19:34:24.648248+00	\N
31	1	11	\N	\N	\N	2026-06-15 21:14:53.004+00	2026-06-16 19:34:24.648248+00	\N
359	48	62	\N	\N	\N	2026-06-16 12:50:45.238+00	2026-06-16 19:34:24.648248+00	\N
191	40	8	\N	Lun-Vie 9:30-11:00	Aula 21	2026-06-16 12:35:14.1+00	2026-06-16 19:34:24.648248+00	\N
192	40	6	\N	Lun-Vie 9:30-11:00	Aula 21	2026-06-16 12:35:14.1+00	2026-06-16 19:34:24.648248+00	\N
193	40	1	\N	Lun-Vie 9:30-11:00	Aula 21	2026-06-16 12:35:14.1+00	2026-06-16 19:34:24.648248+00	\N
194	40	9	\N	Lun-Vie 9:30-11:00	Aula 21	2026-06-16 12:35:14.1+00	2026-06-16 19:34:24.648248+00	\N
195	40	2	\N	Lun-Vie 9:30-11:00	Aula 21	2026-06-16 12:35:14.1+00	2026-06-16 19:34:24.648248+00	\N
197	40	7	\N	Lun-Vie 9:30-11:00	Aula 21	2026-06-16 12:35:14.1+00	2026-06-16 19:34:24.648248+00	\N
144	33	22	\N	\N	\N	2026-06-16 12:35:14.031+00	2026-06-16 19:34:24.648248+00	\N
155	35	10	\N	\N	\N	2026-06-16 12:35:14.05+00	2026-06-16 19:34:24.648248+00	\N
156	35	11	\N	\N	\N	2026-06-16 12:35:14.05+00	2026-06-16 19:34:24.648248+00	\N
157	35	22	\N	\N	\N	2026-06-16 12:35:14.05+00	2026-06-16 19:34:24.648248+00	\N
158	36	2	\N	\N	\N	2026-06-16 12:35:14.061+00	2026-06-16 19:34:24.648248+00	\N
165	36	22	\N	\N	\N	2026-06-16 12:35:14.061+00	2026-06-16 19:34:24.648248+00	\N
204	42	36	\N	\N	\N	2026-06-16 12:40:56.914+00	2026-06-16 19:34:24.648248+00	\N
206	42	38	\N	\N	\N	2026-06-16 12:40:56.925+00	2026-06-16 19:34:24.648248+00	\N
215	43	40	\N	\N	\N	2026-06-16 12:40:56.964+00	2026-06-16 19:34:24.648248+00	\N
222	32	47	\N	\N	\N	2026-06-16 12:40:57.035+00	2026-06-16 19:34:24.648248+00	\N
239	35	47	\N	\N	\N	2026-06-16 12:40:57.101+00	2026-06-16 19:34:24.648248+00	\N
240	36	43	\N	\N	\N	2026-06-16 12:40:57.105+00	2026-06-16 19:34:24.648248+00	\N
360	48	63	\N	\N	\N	2026-06-16 12:50:45.242+00	2026-06-16 19:34:24.648248+00	\N
262	40	25	\N	\N	\N	2026-06-16 12:40:57.271+00	2026-06-16 19:34:24.648248+00	\N
264	40	51	\N	\N	\N	2026-06-16 12:40:57.276+00	2026-06-16 19:34:24.648248+00	\N
271	40	56	\N	\N	\N	2026-06-16 12:40:57.305+00	2026-06-16 19:34:24.648248+00	\N
279	41	51	\N	\N	\N	2026-06-16 12:40:57.334+00	2026-06-16 19:34:24.648248+00	\N
281	41	52	\N	\N	\N	2026-06-16 12:40:57.343+00	2026-06-16 19:34:24.648248+00	\N
305	44	69	\N	\N	\N	2026-06-16 12:40:57.601+00	2026-06-16 19:34:24.648248+00	\N
310	44	74	\N	\N	\N	2026-06-16 12:40:57.634+00	2026-06-16 19:34:24.648248+00	\N
311	44	75	\N	\N	\N	2026-06-16 12:40:57.642+00	2026-06-16 19:34:24.648248+00	\N
316	44	80	\N	\N	\N	2026-06-16 12:40:57.661+00	2026-06-16 19:34:24.648248+00	\N
317	44	81	\N	\N	\N	2026-06-16 12:40:57.665+00	2026-06-16 19:34:24.648248+00	\N
318	44	82	\N	\N	\N	2026-06-16 12:40:57.668+00	2026-06-16 19:34:24.648248+00	\N
332	45	80	\N	\N	\N	2026-06-16 12:40:57.733+00	2026-06-16 19:34:24.648248+00	\N
335	45	83	\N	\N	\N	2026-06-16 12:40:57.75+00	2026-06-16 19:34:24.648248+00	\N
336	46	58	\N	\N	\N	2026-06-16 12:40:57.753+00	2026-06-16 19:34:24.648248+00	\N
340	46	63	\N	\N	\N	2026-06-16 12:40:57.766+00	2026-06-16 19:34:24.648248+00	\N
342	46	65	\N	\N	\N	2026-06-16 12:40:57.773+00	2026-06-16 19:34:24.648248+00	\N
343	46	66	\N	\N	\N	2026-06-16 12:40:57.776+00	2026-06-16 19:34:24.648248+00	\N
353	47	66	\N	\N	\N	2026-06-16 12:40:57.819+00	2026-06-16 19:34:24.648248+00	\N
354	47	77	\N	\N	\N	2026-06-16 12:40:57.823+00	2026-06-16 19:34:24.648248+00	\N
355	47	68	\N	\N	\N	2026-06-16 12:40:57.826+00	2026-06-16 19:34:24.648248+00	\N
312	44	76	\N	\N	\N	2026-06-16 12:40:57.649+00	2026-06-16 19:34:24.648248+00	\N
329	45	77	\N	\N	\N	2026-06-16 12:40:57.719+00	2026-06-16 19:34:24.648248+00	\N
362	48	65	\N	\N	\N	2026-06-16 12:50:45.251+00	2026-06-16 19:34:24.648248+00	\N
366	49	36	\N	\N	\N	2026-06-16 12:50:50.238+00	2026-06-16 19:34:24.648248+00	\N
371	49	41	\N	\N	\N	2026-06-16 12:50:50.27+00	2026-06-16 19:34:24.648248+00	\N
372	49	42	\N	\N	\N	2026-06-16 12:50:50.273+00	2026-06-16 19:34:24.648248+00	\N
373	50	6	\N	\N	\N	2026-06-16 12:50:50.835+00	2026-06-16 19:34:24.648248+00	\N
377	50	8	\N	\N	\N	2026-06-16 12:50:50.858+00	2026-06-16 19:34:24.648248+00	\N
381	50	26	\N	\N	\N	2026-06-16 12:50:50.876+00	2026-06-16 19:34:24.648248+00	\N
\.


--
-- Data for Name: inscripcion_ciclo; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.inscripcion_ciclo (inscripcion_id, alumno_id, ciclo_id, grupo_id, plan_pago, plan_pago_id, fecha_ingreso, es_ingreso_tardio, estado_en_ciclo, estado_financiero, meses_adeudo, motivo_baja, fecha_baja, creado_en, actualizado_en, eliminado_en) FROM stdin;
377	150	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:25.871+00	2026-06-16 12:48:25.871+00	\N
378	151	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:25.978+00	2026-06-16 12:48:25.978+00	\N
379	152	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:26.089+00	2026-06-16 12:48:26.089+00	\N
380	153	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:26.206+00	2026-06-16 12:48:26.206+00	\N
381	154	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:26.316+00	2026-06-16 12:48:26.316+00	\N
382	155	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:26.448+00	2026-06-16 12:48:26.448+00	\N
383	156	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:26.587+00	2026-06-16 12:48:26.587+00	\N
384	157	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:26.743+00	2026-06-16 12:48:26.743+00	\N
11	11	3	9	10_meses	1	2026-06-14	f	activa	al_corriente	0	\N	\N	2026-06-14 18:44:45.702+00	2026-06-14 18:44:45.702+00	\N
12	12	3	9	10_meses	1	2026-06-14	f	activa	al_corriente	0	\N	\N	2026-06-14 18:44:45.741+00	2026-06-14 18:44:45.741+00	\N
13	13	3	10	10_meses	1	2026-06-14	f	activa	al_corriente	0	\N	\N	2026-06-14 18:44:45.767+00	2026-06-14 18:44:45.767+00	\N
14	14	3	9	10_meses	1	2026-06-14	f	activa	al_corriente	0	\N	\N	2026-06-14 18:44:45.785+00	2026-06-14 18:44:45.785+00	\N
15	15	3	10	10_meses	1	2026-06-14	f	activa	al_corriente	0	\N	\N	2026-06-14 18:44:45.804+00	2026-06-14 18:44:45.804+00	\N
16	16	3	11	10_meses	1	2026-06-14	f	activa	al_corriente	0	\N	\N	2026-06-14 18:44:45.833+00	2026-06-14 18:44:45.833+00	\N
17	17	3	12	10_meses	1	2026-06-14	f	activa	al_corriente	0	\N	\N	2026-06-14 18:44:45.851+00	2026-06-14 18:44:45.851+00	\N
18	18	3	11	10_meses	1	2026-06-14	f	activa	al_corriente	0	\N	\N	2026-06-14 18:44:45.87+00	2026-06-14 18:44:45.87+00	\N
385	158	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:26.874+00	2026-06-16 12:48:26.874+00	\N
386	159	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:27.002+00	2026-06-16 12:48:27.002+00	\N
387	160	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:27.116+00	2026-06-16 12:48:27.116+00	\N
24	19	2	13	10_meses	\N	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:45:49.904+00	2026-06-15 20:45:49.904+00	\N
388	161	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:27.236+00	2026-06-16 12:48:27.236+00	\N
389	162	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:27.354+00	2026-06-16 12:48:27.354+00	\N
390	163	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:27.485+00	2026-06-16 12:48:27.485+00	\N
391	164	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:27.61+00	2026-06-16 12:48:27.61+00	\N
392	165	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:27.709+00	2026-06-16 12:48:27.709+00	\N
393	166	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:27.797+00	2026-06-16 12:48:27.797+00	\N
394	167	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:27.887+00	2026-06-16 12:48:27.887+00	\N
395	168	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:27.975+00	2026-06-16 12:48:27.975+00	\N
396	169	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:28.065+00	2026-06-16 12:48:28.065+00	\N
397	170	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:28.156+00	2026-06-16 12:48:28.156+00	\N
398	171	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:28.245+00	2026-06-16 12:48:28.245+00	\N
399	172	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:28.337+00	2026-06-16 12:48:28.337+00	\N
400	173	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:28.43+00	2026-06-16 12:48:28.43+00	\N
401	210	7	45	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:28.532+00	2026-06-16 12:48:28.532+00	\N
402	234	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:28.848+00	2026-06-16 12:48:28.848+00	\N
435	237	7	34	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 13:32:09.403+00	2026-06-16 13:32:09.403+00	\N
253	1	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	1	\N	\N	2026-06-16 12:48:15.013+00	2026-06-16 15:15:37.24367+00	\N
254	2	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	1	\N	\N	2026-06-16 12:48:15.112+00	2026-06-16 15:15:37.268677+00	\N
348	120	7	34	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:23.364+00	2026-06-16 19:36:56.917682+00	\N
249	10	7	50	12_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:45:25.382+00	2026-06-16 21:28:27.2086+00	\N
1	1	2	3	12_meses	\N	2026-08-03	f	promovido	al_corriente	0	\N	\N	2026-06-12 05:56:10.679462+00	2026-06-16 12:15:39.479474+00	\N
2	2	2	6	12_meses	\N	2026-08-03	f	promovido	al_corriente	0	\N	\N	2026-06-12 05:56:10.679462+00	2026-06-16 12:15:39.479474+00	\N
3	3	2	2	10_meses	\N	2026-08-03	f	promovido	al_corriente	0	\N	\N	2026-06-12 05:56:10.679462+00	2026-06-16 12:15:39.479474+00	\N
403	41	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:45.271+00	2026-06-16 12:50:45.271+00	\N
404	93	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:46.958+00	2026-06-16 12:50:46.958+00	\N
405	94	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:47.026+00	2026-06-16 12:50:47.026+00	\N
406	95	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:47.089+00	2026-06-16 12:50:47.089+00	\N
407	96	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:47.152+00	2026-06-16 12:50:47.152+00	\N
408	97	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:47.223+00	2026-06-16 12:50:47.223+00	\N
409	98	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:47.35+00	2026-06-16 12:50:47.35+00	\N
410	99	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:47.445+00	2026-06-16 12:50:47.445+00	\N
411	100	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:47.542+00	2026-06-16 12:50:47.542+00	\N
412	101	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:47.64+00	2026-06-16 12:50:47.64+00	\N
413	102	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:47.73+00	2026-06-16 12:50:47.73+00	\N
414	174	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:49.484+00	2026-06-16 12:50:49.484+00	\N
415	175	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:49.556+00	2026-06-16 12:50:49.556+00	\N
416	176	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:49.631+00	2026-06-16 12:50:49.631+00	\N
417	177	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:49.712+00	2026-06-16 12:50:49.712+00	\N
418	178	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:49.797+00	2026-06-16 12:50:49.797+00	\N
419	179	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:49.891+00	2026-06-16 12:50:49.891+00	\N
420	180	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:49.959+00	2026-06-16 12:50:49.959+00	\N
421	181	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:50.027+00	2026-06-16 12:50:50.027+00	\N
422	182	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:50.094+00	2026-06-16 12:50:50.094+00	\N
423	183	7	48	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:50.158+00	2026-06-16 12:50:50.158+00	\N
424	224	7	49	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:50.278+00	2026-06-16 12:50:50.278+00	\N
425	225	7	49	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:50.325+00	2026-06-16 12:50:50.325+00	\N
426	226	7	49	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:50.37+00	2026-06-16 12:50:50.37+00	\N
427	227	7	49	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:50.42+00	2026-06-16 12:50:50.42+00	\N
428	228	7	49	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:50.471+00	2026-06-16 12:50:50.471+00	\N
429	229	7	49	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:50.511+00	2026-06-16 12:50:50.511+00	\N
430	230	7	49	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:50.56+00	2026-06-16 12:50:50.56+00	\N
431	231	7	49	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:50.613+00	2026-06-16 12:50:50.613+00	\N
432	232	7	49	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:50.656+00	2026-06-16 12:50:50.656+00	\N
433	233	7	49	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:50.702+00	2026-06-16 12:50:50.702+00	\N
434	9	7	49	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:50:50.755+00	2026-06-16 12:50:50.755+00	\N
302	63	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:18.839+00	2026-06-16 14:34:44.72168+00	\N
250	136	7	36	12_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:45:37.212+00	2026-06-16 20:13:26.719337+00	\N
257	5	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:15.427+00	2026-06-16 12:48:15.427+00	\N
258	6	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:15.517+00	2026-06-16 12:48:15.517+00	\N
259	7	7	36	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:15.594+00	2026-06-16 12:48:15.594+00	\N
260	8	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:15.671+00	2026-06-16 12:48:15.671+00	\N
261	38	7	34	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:15.802+00	2026-06-16 12:48:15.802+00	\N
262	39	7	34	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:15.877+00	2026-06-16 12:48:15.877+00	\N
263	40	7	34	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:15.947+00	2026-06-16 12:48:15.947+00	\N
265	21	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:16.084+00	2026-06-16 12:48:16.084+00	\N
266	23	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:16.16+00	2026-06-16 12:48:16.16+00	\N
267	24	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:16.234+00	2026-06-16 12:48:16.234+00	\N
268	25	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:16.308+00	2026-06-16 12:48:16.308+00	\N
269	26	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:16.383+00	2026-06-16 12:48:16.383+00	\N
270	27	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:16.456+00	2026-06-16 12:48:16.456+00	\N
271	28	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:16.529+00	2026-06-16 12:48:16.529+00	\N
272	29	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:16.6+00	2026-06-16 12:48:16.6+00	\N
273	30	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:16.678+00	2026-06-16 12:48:16.678+00	\N
274	31	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:16.754+00	2026-06-16 12:48:16.754+00	\N
275	32	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:16.824+00	2026-06-16 12:48:16.824+00	\N
276	33	7	34	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:16.896+00	2026-06-16 12:48:16.896+00	\N
277	34	7	34	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:16.961+00	2026-06-16 12:48:16.961+00	\N
278	35	7	34	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:17.027+00	2026-06-16 12:48:17.027+00	\N
279	36	7	34	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:17.095+00	2026-06-16 12:48:17.095+00	\N
280	37	7	34	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:17.163+00	2026-06-16 12:48:17.163+00	\N
281	43	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:17.23+00	2026-06-16 12:48:17.23+00	\N
282	44	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:17.303+00	2026-06-16 12:48:17.303+00	\N
283	45	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:17.374+00	2026-06-16 12:48:17.374+00	\N
284	46	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:17.449+00	2026-06-16 12:48:17.449+00	\N
286	48	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:17.594+00	2026-06-16 12:48:17.594+00	\N
287	49	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:17.668+00	2026-06-16 12:48:17.668+00	\N
288	50	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:17.743+00	2026-06-16 12:48:17.743+00	\N
289	51	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:17.821+00	2026-06-16 12:48:17.821+00	\N
290	52	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:17.9+00	2026-06-16 12:48:17.9+00	\N
291	53	7	36	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:17.975+00	2026-06-16 12:48:17.975+00	\N
292	54	7	36	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:18.047+00	2026-06-16 12:48:18.047+00	\N
293	16	7	45	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:18.119+00	2026-06-16 12:48:18.119+00	\N
294	55	7	36	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:18.229+00	2026-06-16 12:48:18.229+00	\N
295	56	7	36	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:18.303+00	2026-06-16 12:48:18.303+00	\N
296	57	7	36	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:18.374+00	2026-06-16 12:48:18.374+00	\N
297	58	7	36	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:18.45+00	2026-06-16 12:48:18.45+00	\N
298	59	7	36	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:18.533+00	2026-06-16 12:48:18.533+00	\N
189	185	3	9	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:09.925+00	2026-06-15 20:53:09.925+00	\N
190	186	3	9	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:09.948+00	2026-06-15 20:53:09.948+00	\N
191	187	3	9	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:09.97+00	2026-06-15 20:53:09.97+00	\N
192	188	3	9	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:09.998+00	2026-06-15 20:53:09.998+00	\N
193	189	3	9	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.024+00	2026-06-15 20:53:10.024+00	\N
194	190	3	9	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.041+00	2026-06-15 20:53:10.041+00	\N
197	193	3	9	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.112+00	2026-06-15 20:53:10.112+00	\N
198	194	3	10	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.131+00	2026-06-15 20:53:10.131+00	\N
199	195	3	10	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.155+00	2026-06-15 20:53:10.155+00	\N
200	196	3	10	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.174+00	2026-06-15 20:53:10.174+00	\N
201	197	3	10	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.193+00	2026-06-15 20:53:10.193+00	\N
203	199	3	10	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.237+00	2026-06-15 20:53:10.237+00	\N
204	200	3	10	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.257+00	2026-06-15 20:53:10.257+00	\N
207	203	3	10	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.32+00	2026-06-15 20:53:10.32+00	\N
208	204	3	11	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.342+00	2026-06-15 20:53:10.342+00	\N
209	205	3	11	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.365+00	2026-06-15 20:53:10.365+00	\N
210	206	3	11	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.389+00	2026-06-15 20:53:10.389+00	\N
299	60	7	36	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:18.609+00	2026-06-16 12:48:18.609+00	\N
255	3	7	34	10_meses	\N	2026-06-16	f	activa	al_corriente	1	\N	\N	2026-06-16 12:48:15.241+00	2026-06-16 15:15:37.273492+00	\N
256	4	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	1	\N	\N	2026-06-16 12:48:15.31+00	2026-06-16 15:15:37.278979+00	\N
188	184	3	9	10_meses	1	2026-06-15	f	activa	aviso_preventivo	0	\N	\N	2026-06-15 20:53:09.905+00	2026-06-16 15:15:37.327847+00	\N
195	191	3	9	10_meses	1	2026-06-15	f	activa	aviso_preventivo	0	\N	\N	2026-06-15 20:53:10.065+00	2026-06-16 15:15:37.340816+00	\N
196	192	3	9	10_meses	1	2026-06-15	f	activa	aviso_preventivo	0	\N	\N	2026-06-15 20:53:10.093+00	2026-06-16 15:15:37.348672+00	\N
202	198	3	10	10_meses	1	2026-06-15	f	activa	aviso_preventivo	0	\N	\N	2026-06-15 20:53:10.216+00	2026-06-16 15:15:37.360212+00	\N
205	201	3	10	10_meses	1	2026-06-15	f	activa	aviso_preventivo	0	\N	\N	2026-06-15 20:53:10.279+00	2026-06-16 15:15:37.371657+00	\N
206	202	3	10	10_meses	1	2026-06-15	f	activa	aviso_preventivo	0	\N	\N	2026-06-15 20:53:10.297+00	2026-06-16 15:15:37.376449+00	\N
285	47	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:17.526+00	2026-06-16 16:43:17.690065+00	\N
264	42	7	34	12_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:16.016+00	2026-06-16 19:56:42.905715+00	\N
211	207	3	11	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.411+00	2026-06-15 20:53:10.411+00	\N
212	208	3	11	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.44+00	2026-06-15 20:53:10.44+00	\N
215	211	3	11	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.542+00	2026-06-15 20:53:10.542+00	\N
216	212	3	11	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.562+00	2026-06-15 20:53:10.562+00	\N
220	216	3	12	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.656+00	2026-06-15 20:53:10.656+00	\N
221	217	3	12	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.683+00	2026-06-15 20:53:10.683+00	\N
222	218	3	12	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.699+00	2026-06-15 20:53:10.699+00	\N
223	219	3	12	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.721+00	2026-06-15 20:53:10.721+00	\N
224	220	3	12	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.743+00	2026-06-15 20:53:10.743+00	\N
225	221	3	12	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.766+00	2026-06-15 20:53:10.766+00	\N
226	222	3	12	10_meses	1	2026-06-15	f	activa	al_corriente	0	\N	\N	2026-06-15 20:53:10.79+00	2026-06-15 20:53:10.79+00	\N
300	61	7	36	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:18.682+00	2026-06-16 12:48:18.682+00	\N
301	62	7	36	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:18.752+00	2026-06-16 12:48:18.752+00	\N
303	64	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:18.944+00	2026-06-16 12:48:18.944+00	\N
304	65	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:19.056+00	2026-06-16 12:48:19.056+00	\N
305	66	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:19.16+00	2026-06-16 12:48:19.16+00	\N
306	67	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:19.261+00	2026-06-16 12:48:19.261+00	\N
307	68	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:19.373+00	2026-06-16 12:48:19.373+00	\N
308	69	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:19.489+00	2026-06-16 12:48:19.489+00	\N
309	70	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:19.622+00	2026-06-16 12:48:19.622+00	\N
310	71	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:19.741+00	2026-06-16 12:48:19.741+00	\N
311	72	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:19.859+00	2026-06-16 12:48:19.859+00	\N
312	73	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:20.009+00	2026-06-16 12:48:20.009+00	\N
245	235	2	14	10_meses	4	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:00:42.573+00	2026-06-16 12:00:42.573+00	\N
246	236	2	13	10_meses	4	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:01:13.708+00	2026-06-16 12:01:13.708+00	\N
213	209	3	11	10_meses	1	2026-06-15	f	activa	aviso_preventivo	0	\N	\N	2026-06-15 20:53:10.473+00	2026-06-16 15:15:37.390282+00	\N
4	4	2	5	10_meses	\N	2026-08-03	f	promovido	al_corriente	0	\N	\N	2026-06-12 05:56:10.679462+00	2026-06-16 12:15:39.479474+00	\N
5	5	2	7	10_meses	\N	2026-08-03	f	promovido	al_corriente	0	\N	\N	2026-06-12 05:56:10.679462+00	2026-06-16 12:15:39.479474+00	\N
6	6	2	1	10_meses	\N	2026-08-03	f	promovido	al_corriente	0	\N	\N	2026-06-12 05:56:10.679462+00	2026-06-16 12:15:39.479474+00	\N
7	7	2	4	10_meses	\N	2026-08-03	f	promovido	al_corriente	0	\N	\N	2026-06-12 05:56:10.679462+00	2026-06-16 12:15:39.479474+00	\N
8	8	2	6	10_meses	\N	2026-08-03	f	promovido	al_corriente	0	\N	\N	2026-06-12 05:56:10.679462+00	2026-06-16 12:15:39.479474+00	\N
42	38	2	2	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.033+00	2026-06-16 12:15:39.479474+00	\N
43	39	2	2	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:46.051+00	2026-06-16 12:15:39.479474+00	\N
44	40	2	2	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:46.071+00	2026-06-16 12:15:39.479474+00	\N
45	41	2	8	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.096+00	2026-06-16 12:15:39.479474+00	\N
46	42	2	2	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.113+00	2026-06-16 12:15:39.479474+00	\N
25	21	2	1	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:07.957+00	2026-06-16 12:15:39.479474+00	\N
27	23	2	1	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:45.697+00	2026-06-16 12:15:39.479474+00	\N
28	24	2	1	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:45.724+00	2026-06-16 12:15:39.479474+00	\N
29	25	2	1	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:45.746+00	2026-06-16 12:15:39.479474+00	\N
30	26	2	1	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:45.77+00	2026-06-16 12:15:39.479474+00	\N
31	27	2	1	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:45.789+00	2026-06-16 12:15:39.479474+00	\N
32	28	2	1	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:45.811+00	2026-06-16 12:15:39.479474+00	\N
33	29	2	1	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:45.832+00	2026-06-16 12:15:39.479474+00	\N
34	30	2	1	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:45.849+00	2026-06-16 12:15:39.479474+00	\N
35	31	2	1	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:45.869+00	2026-06-16 12:15:39.479474+00	\N
36	32	2	1	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:45.893+00	2026-06-16 12:15:39.479474+00	\N
37	33	2	2	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:45.912+00	2026-06-16 12:15:39.479474+00	\N
38	34	2	2	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:45.933+00	2026-06-16 12:15:39.479474+00	\N
39	35	2	2	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:45.96+00	2026-06-16 12:15:39.479474+00	\N
40	36	2	2	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:45.989+00	2026-06-16 12:15:39.479474+00	\N
41	37	2	2	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.013+00	2026-06-16 12:15:39.479474+00	\N
47	43	2	3	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:46.131+00	2026-06-16 12:15:39.479474+00	\N
48	44	2	3	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.181+00	2026-06-16 12:15:39.479474+00	\N
49	45	2	3	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:46.201+00	2026-06-16 12:15:39.479474+00	\N
50	46	2	3	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.222+00	2026-06-16 12:15:39.479474+00	\N
51	47	2	3	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.241+00	2026-06-16 12:15:39.479474+00	\N
52	48	2	3	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.259+00	2026-06-16 12:15:39.479474+00	\N
53	49	2	3	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.278+00	2026-06-16 12:15:39.479474+00	\N
54	50	2	3	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.299+00	2026-06-16 12:15:39.479474+00	\N
55	51	2	3	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.32+00	2026-06-16 12:15:39.479474+00	\N
56	52	2	3	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:46.338+00	2026-06-16 12:15:39.479474+00	\N
57	53	2	4	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:46.354+00	2026-06-16 12:15:39.479474+00	\N
214	210	3	11	10_meses	1	2026-06-15	f	activa	aviso_preventivo	0	\N	\N	2026-06-15 20:53:10.512+00	2026-06-16 15:15:37.395993+00	\N
217	213	3	11	10_meses	1	2026-06-15	f	activa	aviso_preventivo	0	\N	\N	2026-06-15 20:53:10.584+00	2026-06-16 15:15:37.404049+00	\N
218	214	3	12	10_meses	1	2026-06-15	f	activa	aviso_preventivo	0	\N	\N	2026-06-15 20:53:10.612+00	2026-06-16 15:15:37.408236+00	\N
219	215	3	12	10_meses	1	2026-06-15	f	activa	aviso_preventivo	0	\N	\N	2026-06-15 20:53:10.635+00	2026-06-16 15:15:37.414918+00	\N
227	223	3	12	10_meses	1	2026-06-15	f	activa	aviso_preventivo	0	\N	\N	2026-06-15 20:53:10.811+00	2026-06-16 15:15:37.427698+00	\N
58	54	2	4	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.374+00	2026-06-16 12:15:39.479474+00	\N
240	16	2	14	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 21:46:08.198+00	2026-06-16 12:15:39.479474+00	\N
59	55	2	4	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.397+00	2026-06-16 12:15:39.479474+00	\N
60	56	2	4	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:46.414+00	2026-06-16 12:15:39.479474+00	\N
61	57	2	4	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.435+00	2026-06-16 12:15:39.479474+00	\N
62	58	2	4	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.452+00	2026-06-16 12:15:39.479474+00	\N
63	59	2	4	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:46.47+00	2026-06-16 12:15:39.479474+00	\N
64	60	2	4	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.492+00	2026-06-16 12:15:39.479474+00	\N
65	61	2	4	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.51+00	2026-06-16 12:15:39.479474+00	\N
66	62	2	4	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.527+00	2026-06-16 12:15:39.479474+00	\N
67	63	2	5	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:46.547+00	2026-06-16 12:15:39.479474+00	\N
68	64	2	5	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:46.567+00	2026-06-16 12:15:39.479474+00	\N
69	65	2	5	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.583+00	2026-06-16 12:15:39.479474+00	\N
70	66	2	5	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:46.601+00	2026-06-16 12:15:39.479474+00	\N
71	67	2	5	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.62+00	2026-06-16 12:15:39.479474+00	\N
72	68	2	5	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.635+00	2026-06-16 12:15:39.479474+00	\N
73	69	2	5	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.654+00	2026-06-16 12:15:39.479474+00	\N
74	70	2	5	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.678+00	2026-06-16 12:15:39.479474+00	\N
75	71	2	5	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.703+00	2026-06-16 12:15:39.479474+00	\N
76	72	2	5	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.72+00	2026-06-16 12:15:39.479474+00	\N
77	73	2	6	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.738+00	2026-06-16 12:15:39.479474+00	\N
78	74	2	6	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:46.765+00	2026-06-16 12:15:39.479474+00	\N
79	75	2	6	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:46.782+00	2026-06-16 12:15:39.479474+00	\N
80	76	2	6	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.798+00	2026-06-16 12:15:39.479474+00	\N
81	77	2	6	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.817+00	2026-06-16 12:15:39.479474+00	\N
82	78	2	6	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.837+00	2026-06-16 12:15:39.479474+00	\N
83	79	2	6	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.857+00	2026-06-16 12:15:39.479474+00	\N
84	80	2	6	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.874+00	2026-06-16 12:15:39.479474+00	\N
85	81	2	6	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:46.893+00	2026-06-16 12:15:39.479474+00	\N
86	82	2	6	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.914+00	2026-06-16 12:15:39.479474+00	\N
87	83	2	7	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.931+00	2026-06-16 12:15:39.479474+00	\N
88	84	2	7	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:46.952+00	2026-06-16 12:15:39.479474+00	\N
89	85	2	7	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:46.971+00	2026-06-16 12:15:39.479474+00	\N
90	86	2	7	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:46.99+00	2026-06-16 12:15:39.479474+00	\N
91	87	2	7	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:47.011+00	2026-06-16 12:15:39.479474+00	\N
92	88	2	7	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:47.027+00	2026-06-16 12:15:39.479474+00	\N
93	89	2	7	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:47.046+00	2026-06-16 12:15:39.479474+00	\N
94	90	2	7	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:47.066+00	2026-06-16 12:15:39.479474+00	\N
95	91	2	7	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:47.087+00	2026-06-16 12:15:39.479474+00	\N
96	92	2	7	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:47.103+00	2026-06-16 12:15:39.479474+00	\N
97	93	2	8	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:47.125+00	2026-06-16 12:15:39.479474+00	\N
98	94	2	8	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:47.145+00	2026-06-16 12:15:39.479474+00	\N
99	95	2	8	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:47.166+00	2026-06-16 12:15:39.479474+00	\N
100	96	2	8	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:52:47.185+00	2026-06-16 12:15:39.479474+00	\N
101	97	2	8	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:47.204+00	2026-06-16 12:15:39.479474+00	\N
102	98	2	8	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:47.226+00	2026-06-16 12:15:39.479474+00	\N
103	99	2	8	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:47.242+00	2026-06-16 12:15:39.479474+00	\N
104	100	2	8	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:47.262+00	2026-06-16 12:15:39.479474+00	\N
105	101	2	8	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:47.282+00	2026-06-16 12:15:39.479474+00	\N
106	102	2	8	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:52:47.306+00	2026-06-16 12:15:39.479474+00	\N
108	104	2	1	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:07.926+00	2026-06-16 12:15:39.479474+00	\N
109	105	2	1	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:07.953+00	2026-06-16 12:15:39.479474+00	\N
110	106	2	1	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:07.976+00	2026-06-16 12:15:39.479474+00	\N
111	107	2	1	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:07.995+00	2026-06-16 12:15:39.479474+00	\N
112	108	2	1	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:08.014+00	2026-06-16 12:15:39.479474+00	\N
113	109	2	1	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.039+00	2026-06-16 12:15:39.479474+00	\N
114	110	2	1	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.067+00	2026-06-16 12:15:39.479474+00	\N
115	111	2	1	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.115+00	2026-06-16 12:15:39.479474+00	\N
116	112	2	1	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.152+00	2026-06-16 12:15:39.479474+00	\N
117	113	2	1	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:08.191+00	2026-06-16 12:15:39.479474+00	\N
118	114	2	2	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.213+00	2026-06-16 12:15:39.479474+00	\N
119	115	2	2	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.243+00	2026-06-16 12:15:39.479474+00	\N
120	116	2	2	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:08.266+00	2026-06-16 12:15:39.479474+00	\N
121	117	2	2	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.285+00	2026-06-16 12:15:39.479474+00	\N
122	118	2	2	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.303+00	2026-06-16 12:15:39.479474+00	\N
123	119	2	2	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:08.325+00	2026-06-16 12:15:39.479474+00	\N
124	120	2	2	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:08.348+00	2026-06-16 12:15:39.479474+00	\N
125	121	2	2	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.485+00	2026-06-16 12:15:39.479474+00	\N
126	122	2	2	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.503+00	2026-06-16 12:15:39.479474+00	\N
127	123	2	2	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.528+00	2026-06-16 12:15:39.479474+00	\N
128	124	2	3	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:08.547+00	2026-06-16 12:15:39.479474+00	\N
129	125	2	3	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.567+00	2026-06-16 12:15:39.479474+00	\N
130	126	2	3	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:08.598+00	2026-06-16 12:15:39.479474+00	\N
131	127	2	3	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.623+00	2026-06-16 12:15:39.479474+00	\N
132	128	2	3	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.639+00	2026-06-16 12:15:39.479474+00	\N
133	129	2	3	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.659+00	2026-06-16 12:15:39.479474+00	\N
134	130	2	3	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.68+00	2026-06-16 12:15:39.479474+00	\N
135	131	2	3	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:08.697+00	2026-06-16 12:15:39.479474+00	\N
136	132	2	3	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.718+00	2026-06-16 12:15:39.479474+00	\N
137	133	2	3	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.739+00	2026-06-16 12:15:39.479474+00	\N
138	134	2	4	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:08.755+00	2026-06-16 12:15:39.479474+00	\N
139	135	2	4	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:08.776+00	2026-06-16 12:15:39.479474+00	\N
140	136	2	4	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.799+00	2026-06-16 12:15:39.479474+00	\N
141	137	2	4	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.823+00	2026-06-16 12:15:39.479474+00	\N
142	138	2	4	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:08.845+00	2026-06-16 12:15:39.479474+00	\N
143	139	2	4	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.863+00	2026-06-16 12:15:39.479474+00	\N
144	140	2	4	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.884+00	2026-06-16 12:15:39.479474+00	\N
145	141	2	4	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.905+00	2026-06-16 12:15:39.479474+00	\N
146	142	2	4	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.925+00	2026-06-16 12:15:39.479474+00	\N
147	143	2	4	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.948+00	2026-06-16 12:15:39.479474+00	\N
148	144	2	5	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.971+00	2026-06-16 12:15:39.479474+00	\N
149	145	2	5	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:08.995+00	2026-06-16 12:15:39.479474+00	\N
150	146	2	5	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.019+00	2026-06-16 12:15:39.479474+00	\N
151	147	2	5	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.039+00	2026-06-16 12:15:39.479474+00	\N
152	148	2	5	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.061+00	2026-06-16 12:15:39.479474+00	\N
153	149	2	5	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.091+00	2026-06-16 12:15:39.479474+00	\N
154	150	2	5	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:09.12+00	2026-06-16 12:15:39.479474+00	\N
155	151	2	5	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.15+00	2026-06-16 12:15:39.479474+00	\N
156	152	2	5	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:09.172+00	2026-06-16 12:15:39.479474+00	\N
157	153	2	5	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:09.2+00	2026-06-16 12:15:39.479474+00	\N
158	154	2	6	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:09.222+00	2026-06-16 12:15:39.479474+00	\N
159	155	2	6	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:09.247+00	2026-06-16 12:15:39.479474+00	\N
160	156	2	6	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.268+00	2026-06-16 12:15:39.479474+00	\N
161	157	2	6	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.287+00	2026-06-16 12:15:39.479474+00	\N
162	158	2	6	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.316+00	2026-06-16 12:15:39.479474+00	\N
163	159	2	6	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.336+00	2026-06-16 12:15:39.479474+00	\N
164	160	2	6	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.359+00	2026-06-16 12:15:39.479474+00	\N
165	161	2	6	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.385+00	2026-06-16 12:15:39.479474+00	\N
166	162	2	6	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.408+00	2026-06-16 12:15:39.479474+00	\N
167	163	2	6	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:09.428+00	2026-06-16 12:15:39.479474+00	\N
168	164	2	7	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.455+00	2026-06-16 12:15:39.479474+00	\N
169	165	2	7	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:09.48+00	2026-06-16 12:15:39.479474+00	\N
170	166	2	7	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.499+00	2026-06-16 12:15:39.479474+00	\N
171	167	2	7	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:09.523+00	2026-06-16 12:15:39.479474+00	\N
172	168	2	7	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:09.548+00	2026-06-16 12:15:39.479474+00	\N
173	169	2	7	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.57+00	2026-06-16 12:15:39.479474+00	\N
174	170	2	7	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.59+00	2026-06-16 12:15:39.479474+00	\N
175	171	2	7	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.615+00	2026-06-16 12:15:39.479474+00	\N
176	172	2	7	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.638+00	2026-06-16 12:15:39.479474+00	\N
177	173	2	7	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.658+00	2026-06-16 12:15:39.479474+00	\N
178	174	2	8	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:09.682+00	2026-06-16 12:15:39.479474+00	\N
179	175	2	8	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.704+00	2026-06-16 12:15:39.479474+00	\N
180	176	2	8	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.728+00	2026-06-16 12:15:39.479474+00	\N
181	177	2	8	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.75+00	2026-06-16 12:15:39.479474+00	\N
182	178	2	8	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.772+00	2026-06-16 12:15:39.479474+00	\N
183	179	2	8	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:09.792+00	2026-06-16 12:15:39.479474+00	\N
184	180	2	8	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.815+00	2026-06-16 12:15:39.479474+00	\N
185	181	2	8	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.835+00	2026-06-16 12:15:39.479474+00	\N
186	182	2	8	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:09.86+00	2026-06-16 12:15:39.479474+00	\N
187	183	2	8	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:09.883+00	2026-06-16 12:15:39.479474+00	\N
228	224	2	13	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:10.831+00	2026-06-16 12:15:39.479474+00	\N
229	225	2	13	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:10.854+00	2026-06-16 12:15:39.479474+00	\N
230	226	2	13	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:10.881+00	2026-06-16 12:15:39.479474+00	\N
231	227	2	13	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:10.902+00	2026-06-16 12:15:39.479474+00	\N
232	228	2	13	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:10.924+00	2026-06-16 12:15:39.479474+00	\N
233	229	2	13	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:10.947+00	2026-06-16 12:15:39.479474+00	\N
234	230	2	13	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:10.971+00	2026-06-16 12:15:39.479474+00	\N
235	231	2	13	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:10.993+00	2026-06-16 12:15:39.479474+00	\N
236	232	2	13	10_meses	4	2026-06-15	f	promovido	al_corriente	0	\N	\N	2026-06-15 20:53:11.016+00	2026-06-16 12:15:39.479474+00	\N
237	233	2	13	10_meses	4	2026-06-15	f	promovido	aviso_preventivo	1	\N	\N	2026-06-15 20:53:11.033+00	2026-06-16 12:15:39.479474+00	\N
9	9	2	13	10_meses	\N	2026-08-03	f	promovido	al_corriente	0	\N	\N	2026-06-12 05:56:10.679462+00	2026-06-16 12:15:39.479474+00	\N
242	210	2	11	10_meses	4	2026-06-16	f	promovido	al_corriente	0	\N	\N	2026-06-16 02:26:48.738+00	2026-06-16 12:15:39.479474+00	\N
10	10	2	16	10_meses	\N	2026-08-03	f	promovido	al_corriente	0	\N	\N	2026-06-12 05:56:10.679462+00	2026-06-16 12:15:39.479474+00	\N
243	234	2	7	10_meses	4	2026-06-16	f	promovido	al_corriente	0	\N	\N	2026-06-16 09:14:36.598+00	2026-06-16 12:15:39.479474+00	\N
313	74	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:20.151+00	2026-06-16 12:48:20.151+00	\N
314	75	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:20.273+00	2026-06-16 12:48:20.273+00	\N
315	76	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:20.392+00	2026-06-16 12:48:20.392+00	\N
316	77	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:20.524+00	2026-06-16 12:48:20.524+00	\N
317	78	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:20.65+00	2026-06-16 12:48:20.65+00	\N
318	79	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:20.773+00	2026-06-16 12:48:20.773+00	\N
319	80	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:20.894+00	2026-06-16 12:48:20.894+00	\N
320	81	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:21.014+00	2026-06-16 12:48:21.014+00	\N
321	82	7	37	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:21.136+00	2026-06-16 12:48:21.136+00	\N
322	83	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:21.257+00	2026-06-16 12:48:21.257+00	\N
323	84	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:21.35+00	2026-06-16 12:48:21.35+00	\N
324	85	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:21.442+00	2026-06-16 12:48:21.442+00	\N
325	86	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:21.534+00	2026-06-16 12:48:21.534+00	\N
327	88	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:21.739+00	2026-06-16 12:48:21.739+00	\N
328	89	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:21.826+00	2026-06-16 12:48:21.826+00	\N
329	90	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:21.919+00	2026-06-16 12:48:21.919+00	\N
330	91	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:22.005+00	2026-06-16 12:48:22.005+00	\N
331	92	7	38	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:22.108+00	2026-06-16 12:48:22.108+00	\N
332	104	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:22.202+00	2026-06-16 12:48:22.202+00	\N
333	105	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:22.278+00	2026-06-16 12:48:22.278+00	\N
334	106	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:22.357+00	2026-06-16 12:48:22.357+00	\N
335	107	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:22.431+00	2026-06-16 12:48:22.431+00	\N
336	108	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:22.505+00	2026-06-16 12:48:22.505+00	\N
337	109	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:22.578+00	2026-06-16 12:48:22.578+00	\N
338	110	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:22.664+00	2026-06-16 12:48:22.664+00	\N
339	111	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:22.734+00	2026-06-16 12:48:22.734+00	\N
340	112	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:22.804+00	2026-06-16 12:48:22.804+00	\N
341	113	7	33	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:22.882+00	2026-06-16 12:48:22.882+00	\N
342	114	7	34	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:22.964+00	2026-06-16 12:48:22.964+00	\N
343	115	7	34	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:23.031+00	2026-06-16 12:48:23.031+00	\N
344	116	7	34	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:23.097+00	2026-06-16 12:48:23.097+00	\N
345	117	7	34	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:23.164+00	2026-06-16 12:48:23.164+00	\N
346	118	7	34	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:23.23+00	2026-06-16 12:48:23.23+00	\N
347	119	7	34	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:23.294+00	2026-06-16 12:48:23.294+00	\N
349	121	7	34	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:23.433+00	2026-06-16 12:48:23.433+00	\N
350	122	7	34	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:23.498+00	2026-06-16 12:48:23.498+00	\N
351	123	7	34	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:23.567+00	2026-06-16 12:48:23.567+00	\N
352	124	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:23.636+00	2026-06-16 12:48:23.636+00	\N
353	125	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:23.708+00	2026-06-16 12:48:23.708+00	\N
354	126	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:23.78+00	2026-06-16 12:48:23.78+00	\N
355	127	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:23.847+00	2026-06-16 12:48:23.847+00	\N
356	128	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:23.915+00	2026-06-16 12:48:23.915+00	\N
357	129	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:24+00	2026-06-16 12:48:24+00	\N
358	130	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:24.125+00	2026-06-16 12:48:24.125+00	\N
359	131	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:24.221+00	2026-06-16 12:48:24.221+00	\N
360	132	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:24.289+00	2026-06-16 12:48:24.289+00	\N
361	133	7	35	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:24.363+00	2026-06-16 12:48:24.363+00	\N
362	134	7	36	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:24.441+00	2026-06-16 12:48:24.441+00	\N
363	135	7	36	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:24.51+00	2026-06-16 12:48:24.51+00	\N
364	137	7	36	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:24.656+00	2026-06-16 12:48:24.656+00	\N
365	138	7	36	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:24.727+00	2026-06-16 12:48:24.727+00	\N
366	139	7	36	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:24.801+00	2026-06-16 12:48:24.801+00	\N
367	140	7	36	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:24.873+00	2026-06-16 12:48:24.873+00	\N
368	141	7	36	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:24.942+00	2026-06-16 12:48:24.942+00	\N
369	142	7	36	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:25.01+00	2026-06-16 12:48:25.01+00	\N
370	143	7	36	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:25.082+00	2026-06-16 12:48:25.082+00	\N
371	144	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:25.154+00	2026-06-16 12:48:25.154+00	\N
372	145	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:25.259+00	2026-06-16 12:48:25.259+00	\N
373	146	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:25.385+00	2026-06-16 12:48:25.385+00	\N
374	147	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:25.506+00	2026-06-16 12:48:25.506+00	\N
375	148	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:25.636+00	2026-06-16 12:48:25.636+00	\N
376	149	7	40	10_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:25.757+00	2026-06-16 12:48:25.757+00	\N
326	87	7	38	12_meses	\N	2026-06-16	f	activa	al_corriente	0	\N	\N	2026-06-16 12:48:21.635+00	2026-06-16 19:16:39.260372+00	\N
\.


--
-- Data for Name: inscripcion_materia; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.inscripcion_materia (inscripcion_materia_id, alumno_id, grupo_materia_id, creado_en) FROM stdin;
1187	87	187	2026-06-16 12:48:21.668+00
1189	87	189	2026-06-16 12:48:21.683+00
1190	87	182	2026-06-16 12:48:21.687+00
1191	87	253	2026-06-16 12:48:21.692+00
1192	87	254	2026-06-16 12:48:21.696+00
1193	87	255	2026-06-16 12:48:21.702+00
1194	87	256	2026-06-16 12:48:21.707+00
1195	87	257	2026-06-16 12:48:21.712+00
1196	87	258	2026-06-16 12:48:21.72+00
1197	87	259	2026-06-16 12:48:21.726+00
1198	87	260	2026-06-16 12:48:21.733+00
1199	88	181	2026-06-16 12:48:21.743+00
13	75	122	2026-06-16 06:04:25.291+00
14	41	122	2026-06-16 06:04:25.291+00
15	13	122	2026-06-16 06:04:25.291+00
16	163	122	2026-06-16 06:04:25.291+00
17	195	122	2026-06-16 06:04:25.291+00
18	156	122	2026-06-16 06:04:25.291+00
19	174	122	2026-06-16 06:04:25.291+00
20	10	125	2026-06-16 06:10:57.033+00
21	75	125	2026-06-16 06:10:57.033+00
22	41	125	2026-06-16 06:10:57.033+00
23	1	150	2026-06-16 12:48:15.03+00
24	1	151	2026-06-16 12:48:15.045+00
25	1	152	2026-06-16 12:48:15.052+00
26	1	153	2026-06-16 12:48:15.06+00
27	1	154	2026-06-16 12:48:15.065+00
28	1	155	2026-06-16 12:48:15.07+00
29	1	156	2026-06-16 12:48:15.074+00
30	1	157	2026-06-16 12:48:15.078+00
31	1	235	2026-06-16 12:48:15.085+00
32	1	236	2026-06-16 12:48:15.092+00
33	1	237	2026-06-16 12:48:15.098+00
34	1	238	2026-06-16 12:48:15.105+00
35	1	239	2026-06-16 12:48:15.108+00
36	2	167	2026-06-16 12:48:15.118+00
37	2	180	2026-06-16 12:48:15.123+00
38	2	166	2026-06-16 12:48:15.126+00
39	2	168	2026-06-16 12:48:15.131+00
40	2	169	2026-06-16 12:48:15.137+00
41	2	170	2026-06-16 12:48:15.141+00
42	2	171	2026-06-16 12:48:15.148+00
43	2	172	2026-06-16 12:48:15.155+00
44	2	173	2026-06-16 12:48:15.162+00
45	2	174	2026-06-16 12:48:15.169+00
46	2	175	2026-06-16 12:48:15.173+00
47	2	176	2026-06-16 12:48:15.177+00
48	2	177	2026-06-16 12:48:15.181+00
49	2	178	2026-06-16 12:48:15.186+00
50	2	179	2026-06-16 12:48:15.19+00
51	2	245	2026-06-16 12:48:15.195+00
52	2	246	2026-06-16 12:48:15.201+00
53	2	247	2026-06-16 12:48:15.206+00
54	2	248	2026-06-16 12:48:15.213+00
55	2	249	2026-06-16 12:48:15.22+00
56	2	250	2026-06-16 12:48:15.226+00
57	2	251	2026-06-16 12:48:15.233+00
58	2	252	2026-06-16 12:48:15.237+00
59	3	145	2026-06-16 12:48:15.246+00
60	3	146	2026-06-16 12:48:15.251+00
61	3	147	2026-06-16 12:48:15.254+00
62	3	148	2026-06-16 12:48:15.258+00
63	3	149	2026-06-16 12:48:15.263+00
64	3	228	2026-06-16 12:48:15.268+00
65	3	230	2026-06-16 12:48:15.275+00
66	3	231	2026-06-16 12:48:15.283+00
67	3	232	2026-06-16 12:48:15.29+00
68	3	233	2026-06-16 12:48:15.296+00
69	3	234	2026-06-16 12:48:15.301+00
70	3	229	2026-06-16 12:48:15.306+00
71	4	191	2026-06-16 12:48:15.316+00
72	4	192	2026-06-16 12:48:15.321+00
73	4	193	2026-06-16 12:48:15.326+00
74	4	194	2026-06-16 12:48:15.33+00
75	4	195	2026-06-16 12:48:15.336+00
76	4	196	2026-06-16 12:48:15.344+00
77	4	197	2026-06-16 12:48:15.351+00
78	4	198	2026-06-16 12:48:15.357+00
79	4	262	2026-06-16 12:48:15.364+00
80	4	263	2026-06-16 12:48:15.369+00
81	4	264	2026-06-16 12:48:15.373+00
82	4	265	2026-06-16 12:48:15.376+00
83	4	266	2026-06-16 12:48:15.379+00
84	4	267	2026-06-16 12:48:15.386+00
85	4	268	2026-06-16 12:48:15.39+00
86	4	269	2026-06-16 12:48:15.394+00
87	4	270	2026-06-16 12:48:15.399+00
88	4	271	2026-06-16 12:48:15.406+00
89	4	272	2026-06-16 12:48:15.413+00
90	4	261	2026-06-16 12:48:15.42+00
91	5	181	2026-06-16 12:48:15.432+00
92	5	183	2026-06-16 12:48:15.436+00
93	5	184	2026-06-16 12:48:15.44+00
94	5	185	2026-06-16 12:48:15.445+00
95	5	186	2026-06-16 12:48:15.45+00
96	5	187	2026-06-16 12:48:15.455+00
97	5	188	2026-06-16 12:48:15.46+00
98	5	189	2026-06-16 12:48:15.465+00
99	5	182	2026-06-16 12:48:15.472+00
100	5	253	2026-06-16 12:48:15.48+00
101	5	254	2026-06-16 12:48:15.487+00
102	5	255	2026-06-16 12:48:15.49+00
103	5	256	2026-06-16 12:48:15.494+00
104	5	257	2026-06-16 12:48:15.497+00
105	5	258	2026-06-16 12:48:15.502+00
106	5	259	2026-06-16 12:48:15.506+00
107	5	260	2026-06-16 12:48:15.512+00
108	6	137	2026-06-16 12:48:15.524+00
109	6	138	2026-06-16 12:48:15.53+00
110	6	139	2026-06-16 12:48:15.537+00
111	6	140	2026-06-16 12:48:15.544+00
112	6	141	2026-06-16 12:48:15.551+00
113	6	142	2026-06-16 12:48:15.555+00
114	6	143	2026-06-16 12:48:15.558+00
115	6	144	2026-06-16 12:48:15.563+00
116	6	223	2026-06-16 12:48:15.568+00
117	6	224	2026-06-16 12:48:15.572+00
118	6	225	2026-06-16 12:48:15.576+00
119	6	226	2026-06-16 12:48:15.581+00
120	6	227	2026-06-16 12:48:15.586+00
121	7	158	2026-06-16 12:48:15.601+00
122	7	159	2026-06-16 12:48:15.608+00
123	7	160	2026-06-16 12:48:15.614+00
124	7	161	2026-06-16 12:48:15.619+00
125	7	162	2026-06-16 12:48:15.623+00
126	7	164	2026-06-16 12:48:15.626+00
127	7	165	2026-06-16 12:48:15.629+00
128	7	240	2026-06-16 12:48:15.634+00
129	7	163	2026-06-16 12:48:15.64+00
130	7	242	2026-06-16 12:48:15.644+00
131	7	243	2026-06-16 12:48:15.65+00
132	7	241	2026-06-16 12:48:15.657+00
133	7	244	2026-06-16 12:48:15.664+00
134	8	167	2026-06-16 12:48:15.679+00
135	8	180	2026-06-16 12:48:15.683+00
136	8	166	2026-06-16 12:48:15.687+00
137	8	168	2026-06-16 12:48:15.691+00
138	8	169	2026-06-16 12:48:15.695+00
139	8	170	2026-06-16 12:48:15.701+00
140	8	171	2026-06-16 12:48:15.705+00
141	8	172	2026-06-16 12:48:15.71+00
142	8	173	2026-06-16 12:48:15.716+00
143	8	174	2026-06-16 12:48:15.724+00
144	8	175	2026-06-16 12:48:15.735+00
145	8	176	2026-06-16 12:48:15.741+00
146	8	177	2026-06-16 12:48:15.745+00
147	8	178	2026-06-16 12:48:15.749+00
148	8	179	2026-06-16 12:48:15.753+00
149	8	245	2026-06-16 12:48:15.757+00
150	8	246	2026-06-16 12:48:15.761+00
151	8	247	2026-06-16 12:48:15.766+00
152	8	248	2026-06-16 12:48:15.771+00
153	8	249	2026-06-16 12:48:15.776+00
154	8	250	2026-06-16 12:48:15.783+00
155	8	251	2026-06-16 12:48:15.791+00
156	8	252	2026-06-16 12:48:15.797+00
157	38	145	2026-06-16 12:48:15.807+00
158	38	146	2026-06-16 12:48:15.814+00
159	38	147	2026-06-16 12:48:15.828+00
160	38	148	2026-06-16 12:48:15.835+00
161	38	149	2026-06-16 12:48:15.838+00
162	38	228	2026-06-16 12:48:15.841+00
163	38	230	2026-06-16 12:48:15.845+00
164	38	231	2026-06-16 12:48:15.851+00
165	38	232	2026-06-16 12:48:15.855+00
166	38	233	2026-06-16 12:48:15.859+00
167	38	234	2026-06-16 12:48:15.865+00
168	38	229	2026-06-16 12:48:15.87+00
169	39	145	2026-06-16 12:48:15.885+00
170	39	146	2026-06-16 12:48:15.891+00
171	39	147	2026-06-16 12:48:15.897+00
172	39	148	2026-06-16 12:48:15.902+00
173	39	149	2026-06-16 12:48:15.905+00
174	39	228	2026-06-16 12:48:15.909+00
175	39	230	2026-06-16 12:48:15.914+00
176	39	231	2026-06-16 12:48:15.918+00
177	39	232	2026-06-16 12:48:15.922+00
178	39	233	2026-06-16 12:48:15.926+00
179	39	234	2026-06-16 12:48:15.934+00
180	39	229	2026-06-16 12:48:15.941+00
181	40	145	2026-06-16 12:48:15.954+00
182	40	146	2026-06-16 12:48:15.957+00
183	40	147	2026-06-16 12:48:15.961+00
184	40	148	2026-06-16 12:48:15.966+00
185	40	149	2026-06-16 12:48:15.97+00
186	40	228	2026-06-16 12:48:15.974+00
187	40	230	2026-06-16 12:48:15.977+00
188	40	231	2026-06-16 12:48:15.981+00
189	40	232	2026-06-16 12:48:15.986+00
190	40	233	2026-06-16 12:48:15.993+00
191	40	234	2026-06-16 12:48:16.001+00
192	40	229	2026-06-16 12:48:16.008+00
193	42	145	2026-06-16 12:48:16.02+00
194	42	146	2026-06-16 12:48:16.024+00
195	42	147	2026-06-16 12:48:16.029+00
196	42	148	2026-06-16 12:48:16.034+00
197	42	149	2026-06-16 12:48:16.04+00
198	42	228	2026-06-16 12:48:16.047+00
199	42	230	2026-06-16 12:48:16.054+00
200	42	231	2026-06-16 12:48:16.061+00
201	42	232	2026-06-16 12:48:16.068+00
202	42	233	2026-06-16 12:48:16.072+00
203	42	234	2026-06-16 12:48:16.076+00
204	42	229	2026-06-16 12:48:16.08+00
205	21	137	2026-06-16 12:48:16.089+00
206	21	138	2026-06-16 12:48:16.094+00
207	21	139	2026-06-16 12:48:16.099+00
208	21	140	2026-06-16 12:48:16.104+00
209	21	141	2026-06-16 12:48:16.111+00
210	21	142	2026-06-16 12:48:16.118+00
211	21	143	2026-06-16 12:48:16.125+00
212	21	144	2026-06-16 12:48:16.131+00
213	21	223	2026-06-16 12:48:16.136+00
214	21	224	2026-06-16 12:48:16.14+00
215	21	225	2026-06-16 12:48:16.144+00
216	21	226	2026-06-16 12:48:16.15+00
217	21	227	2026-06-16 12:48:16.154+00
218	23	137	2026-06-16 12:48:16.165+00
219	23	138	2026-06-16 12:48:16.171+00
220	23	139	2026-06-16 12:48:16.178+00
221	23	140	2026-06-16 12:48:16.184+00
222	23	141	2026-06-16 12:48:16.191+00
223	23	142	2026-06-16 12:48:16.195+00
224	23	143	2026-06-16 12:48:16.198+00
225	23	144	2026-06-16 12:48:16.204+00
226	23	223	2026-06-16 12:48:16.208+00
227	23	224	2026-06-16 12:48:16.213+00
228	23	225	2026-06-16 12:48:16.217+00
229	23	226	2026-06-16 12:48:16.222+00
230	23	227	2026-06-16 12:48:16.226+00
231	24	137	2026-06-16 12:48:16.241+00
232	24	138	2026-06-16 12:48:16.247+00
233	24	139	2026-06-16 12:48:16.254+00
234	24	140	2026-06-16 12:48:16.257+00
235	24	141	2026-06-16 12:48:16.261+00
236	24	142	2026-06-16 12:48:16.265+00
237	24	143	2026-06-16 12:48:16.269+00
238	24	144	2026-06-16 12:48:16.273+00
239	24	223	2026-06-16 12:48:16.277+00
240	24	224	2026-06-16 12:48:16.282+00
241	24	225	2026-06-16 12:48:16.286+00
242	24	226	2026-06-16 12:48:16.293+00
243	24	227	2026-06-16 12:48:16.301+00
244	25	137	2026-06-16 12:48:16.315+00
245	25	138	2026-06-16 12:48:16.319+00
246	25	139	2026-06-16 12:48:16.324+00
247	25	140	2026-06-16 12:48:16.329+00
248	25	141	2026-06-16 12:48:16.334+00
249	25	142	2026-06-16 12:48:16.337+00
250	25	143	2026-06-16 12:48:16.341+00
251	25	144	2026-06-16 12:48:16.346+00
252	25	223	2026-06-16 12:48:16.351+00
253	25	224	2026-06-16 12:48:16.359+00
254	25	225	2026-06-16 12:48:16.366+00
255	25	226	2026-06-16 12:48:16.373+00
256	25	227	2026-06-16 12:48:16.378+00
257	26	137	2026-06-16 12:48:16.388+00
258	26	138	2026-06-16 12:48:16.392+00
259	26	139	2026-06-16 12:48:16.397+00
260	26	140	2026-06-16 12:48:16.402+00
261	26	141	2026-06-16 12:48:16.406+00
262	26	142	2026-06-16 12:48:16.411+00
263	26	143	2026-06-16 12:48:16.416+00
264	26	144	2026-06-16 12:48:16.423+00
265	26	223	2026-06-16 12:48:16.429+00
266	26	224	2026-06-16 12:48:16.435+00
267	26	225	2026-06-16 12:48:16.443+00
268	26	226	2026-06-16 12:48:16.447+00
269	26	227	2026-06-16 12:48:16.452+00
270	27	137	2026-06-16 12:48:16.462+00
271	27	138	2026-06-16 12:48:16.467+00
272	27	139	2026-06-16 12:48:16.472+00
273	27	140	2026-06-16 12:48:16.476+00
274	27	141	2026-06-16 12:48:16.481+00
275	27	142	2026-06-16 12:48:16.488+00
276	27	143	2026-06-16 12:48:16.495+00
277	27	144	2026-06-16 12:48:16.501+00
278	27	223	2026-06-16 12:48:16.508+00
279	27	224	2026-06-16 12:48:16.512+00
280	27	225	2026-06-16 12:48:16.516+00
281	27	226	2026-06-16 12:48:16.52+00
282	27	227	2026-06-16 12:48:16.524+00
283	28	137	2026-06-16 12:48:16.534+00
284	28	138	2026-06-16 12:48:16.538+00
285	28	139	2026-06-16 12:48:16.542+00
286	28	140	2026-06-16 12:48:16.55+00
287	28	141	2026-06-16 12:48:16.557+00
288	28	142	2026-06-16 12:48:16.564+00
289	28	143	2026-06-16 12:48:16.571+00
290	28	144	2026-06-16 12:48:16.575+00
291	28	223	2026-06-16 12:48:16.578+00
292	28	224	2026-06-16 12:48:16.583+00
293	28	225	2026-06-16 12:48:16.587+00
294	28	226	2026-06-16 12:48:16.591+00
295	28	227	2026-06-16 12:48:16.595+00
296	29	137	2026-06-16 12:48:16.605+00
297	29	138	2026-06-16 12:48:16.612+00
298	29	139	2026-06-16 12:48:16.619+00
299	29	140	2026-06-16 12:48:16.626+00
300	29	141	2026-06-16 12:48:16.632+00
301	29	142	2026-06-16 12:48:16.635+00
302	29	143	2026-06-16 12:48:16.639+00
303	29	144	2026-06-16 12:48:16.643+00
304	29	223	2026-06-16 12:48:16.648+00
305	29	224	2026-06-16 12:48:16.654+00
306	29	225	2026-06-16 12:48:16.659+00
307	29	226	2026-06-16 12:48:16.664+00
308	29	227	2026-06-16 12:48:16.672+00
309	30	137	2026-06-16 12:48:16.685+00
310	30	138	2026-06-16 12:48:16.691+00
311	30	139	2026-06-16 12:48:16.694+00
312	30	140	2026-06-16 12:48:16.698+00
313	30	141	2026-06-16 12:48:16.702+00
314	30	142	2026-06-16 12:48:16.706+00
315	30	143	2026-06-16 12:48:16.711+00
316	30	144	2026-06-16 12:48:16.716+00
317	30	223	2026-06-16 12:48:16.722+00
318	30	224	2026-06-16 12:48:16.726+00
319	30	225	2026-06-16 12:48:16.732+00
320	30	226	2026-06-16 12:48:16.74+00
321	30	227	2026-06-16 12:48:16.746+00
322	31	137	2026-06-16 12:48:16.758+00
323	31	138	2026-06-16 12:48:16.762+00
324	31	139	2026-06-16 12:48:16.767+00
325	31	140	2026-06-16 12:48:16.772+00
326	31	141	2026-06-16 12:48:16.776+00
327	31	142	2026-06-16 12:48:16.78+00
328	31	143	2026-06-16 12:48:16.785+00
329	31	144	2026-06-16 12:48:16.789+00
330	31	223	2026-06-16 12:48:16.796+00
331	31	224	2026-06-16 12:48:16.803+00
332	31	225	2026-06-16 12:48:16.81+00
333	31	226	2026-06-16 12:48:16.817+00
334	31	227	2026-06-16 12:48:16.821+00
335	32	137	2026-06-16 12:48:16.829+00
336	32	138	2026-06-16 12:48:16.833+00
337	32	139	2026-06-16 12:48:16.837+00
338	32	140	2026-06-16 12:48:16.841+00
339	32	141	2026-06-16 12:48:16.845+00
340	32	142	2026-06-16 12:48:16.851+00
341	32	143	2026-06-16 12:48:16.857+00
342	32	144	2026-06-16 12:48:16.865+00
343	32	223	2026-06-16 12:48:16.872+00
344	32	224	2026-06-16 12:48:16.878+00
345	32	225	2026-06-16 12:48:16.883+00
346	32	226	2026-06-16 12:48:16.888+00
347	32	227	2026-06-16 12:48:16.892+00
348	33	145	2026-06-16 12:48:16.901+00
349	33	146	2026-06-16 12:48:16.905+00
350	33	147	2026-06-16 12:48:16.908+00
351	33	148	2026-06-16 12:48:16.913+00
352	33	149	2026-06-16 12:48:16.921+00
353	33	228	2026-06-16 12:48:16.927+00
354	33	230	2026-06-16 12:48:16.934+00
355	33	231	2026-06-16 12:48:16.94+00
356	33	232	2026-06-16 12:48:16.943+00
357	33	233	2026-06-16 12:48:16.947+00
358	33	234	2026-06-16 12:48:16.952+00
359	33	229	2026-06-16 12:48:16.955+00
360	34	145	2026-06-16 12:48:16.965+00
361	34	146	2026-06-16 12:48:16.97+00
362	34	147	2026-06-16 12:48:16.975+00
363	34	148	2026-06-16 12:48:16.982+00
364	34	149	2026-06-16 12:48:16.989+00
365	34	228	2026-06-16 12:48:16.995+00
366	34	230	2026-06-16 12:48:17.002+00
367	34	231	2026-06-16 12:48:17.005+00
368	34	232	2026-06-16 12:48:17.009+00
369	34	233	2026-06-16 12:48:17.014+00
370	34	234	2026-06-16 12:48:17.018+00
371	34	229	2026-06-16 12:48:17.023+00
372	35	145	2026-06-16 12:48:17.033+00
373	35	146	2026-06-16 12:48:17.041+00
374	35	147	2026-06-16 12:48:17.048+00
375	35	148	2026-06-16 12:48:17.055+00
376	35	149	2026-06-16 12:48:17.061+00
377	35	228	2026-06-16 12:48:17.066+00
378	35	230	2026-06-16 12:48:17.07+00
379	35	231	2026-06-16 12:48:17.074+00
380	35	232	2026-06-16 12:48:17.077+00
381	35	233	2026-06-16 12:48:17.082+00
382	35	234	2026-06-16 12:48:17.086+00
383	35	229	2026-06-16 12:48:17.091+00
384	36	145	2026-06-16 12:48:17.102+00
385	36	146	2026-06-16 12:48:17.109+00
386	36	147	2026-06-16 12:48:17.115+00
387	36	148	2026-06-16 12:48:17.12+00
388	36	149	2026-06-16 12:48:17.123+00
389	36	228	2026-06-16 12:48:17.127+00
390	36	230	2026-06-16 12:48:17.131+00
391	36	231	2026-06-16 12:48:17.136+00
392	36	232	2026-06-16 12:48:17.141+00
393	36	233	2026-06-16 12:48:17.145+00
394	36	234	2026-06-16 12:48:17.15+00
395	36	229	2026-06-16 12:48:17.156+00
396	37	145	2026-06-16 12:48:17.168+00
397	37	146	2026-06-16 12:48:17.172+00
398	37	147	2026-06-16 12:48:17.176+00
399	37	148	2026-06-16 12:48:17.18+00
400	37	149	2026-06-16 12:48:17.185+00
401	37	228	2026-06-16 12:48:17.19+00
402	37	230	2026-06-16 12:48:17.194+00
403	37	231	2026-06-16 12:48:17.199+00
404	37	232	2026-06-16 12:48:17.206+00
405	37	233	2026-06-16 12:48:17.213+00
406	37	234	2026-06-16 12:48:17.22+00
407	37	229	2026-06-16 12:48:17.226+00
408	43	150	2026-06-16 12:48:17.235+00
409	43	151	2026-06-16 12:48:17.24+00
410	43	152	2026-06-16 12:48:17.245+00
411	43	153	2026-06-16 12:48:17.25+00
412	43	154	2026-06-16 12:48:17.254+00
413	43	155	2026-06-16 12:48:17.258+00
414	43	156	2026-06-16 12:48:17.263+00
415	43	157	2026-06-16 12:48:17.27+00
416	43	235	2026-06-16 12:48:17.276+00
417	43	236	2026-06-16 12:48:17.284+00
418	43	237	2026-06-16 12:48:17.29+00
419	43	238	2026-06-16 12:48:17.293+00
420	43	239	2026-06-16 12:48:17.296+00
421	44	150	2026-06-16 12:48:17.308+00
422	44	151	2026-06-16 12:48:17.312+00
423	44	152	2026-06-16 12:48:17.317+00
424	44	153	2026-06-16 12:48:17.322+00
425	44	154	2026-06-16 12:48:17.327+00
426	44	155	2026-06-16 12:48:17.334+00
427	44	156	2026-06-16 12:48:17.341+00
428	44	157	2026-06-16 12:48:17.347+00
429	44	235	2026-06-16 12:48:17.354+00
430	44	236	2026-06-16 12:48:17.357+00
431	44	237	2026-06-16 12:48:17.361+00
432	44	238	2026-06-16 12:48:17.366+00
433	44	239	2026-06-16 12:48:17.37+00
434	45	150	2026-06-16 12:48:17.379+00
435	45	151	2026-06-16 12:48:17.384+00
436	45	152	2026-06-16 12:48:17.389+00
437	45	153	2026-06-16 12:48:17.395+00
438	45	154	2026-06-16 12:48:17.402+00
439	45	155	2026-06-16 12:48:17.408+00
440	45	156	2026-06-16 12:48:17.414+00
441	45	157	2026-06-16 12:48:17.418+00
442	45	235	2026-06-16 12:48:17.422+00
443	45	236	2026-06-16 12:48:17.426+00
444	45	237	2026-06-16 12:48:17.429+00
445	45	238	2026-06-16 12:48:17.435+00
446	45	239	2026-06-16 12:48:17.441+00
447	46	150	2026-06-16 12:48:17.458+00
448	46	151	2026-06-16 12:48:17.465+00
449	46	152	2026-06-16 12:48:17.471+00
450	46	153	2026-06-16 12:48:17.474+00
451	46	154	2026-06-16 12:48:17.476+00
452	46	155	2026-06-16 12:48:17.48+00
453	46	156	2026-06-16 12:48:17.485+00
454	46	157	2026-06-16 12:48:17.489+00
455	46	235	2026-06-16 12:48:17.494+00
456	46	236	2026-06-16 12:48:17.499+00
457	46	237	2026-06-16 12:48:17.506+00
458	46	238	2026-06-16 12:48:17.513+00
459	46	239	2026-06-16 12:48:17.52+00
460	47	150	2026-06-16 12:48:17.53+00
461	47	151	2026-06-16 12:48:17.534+00
462	47	152	2026-06-16 12:48:17.537+00
463	47	153	2026-06-16 12:48:17.541+00
464	47	154	2026-06-16 12:48:17.546+00
465	47	155	2026-06-16 12:48:17.551+00
466	47	156	2026-06-16 12:48:17.558+00
467	47	157	2026-06-16 12:48:17.565+00
468	47	235	2026-06-16 12:48:17.572+00
469	47	236	2026-06-16 12:48:17.579+00
470	47	237	2026-06-16 12:48:17.583+00
471	47	238	2026-06-16 12:48:17.587+00
472	47	239	2026-06-16 12:48:17.59+00
473	48	150	2026-06-16 12:48:17.6+00
474	48	151	2026-06-16 12:48:17.604+00
475	48	152	2026-06-16 12:48:17.609+00
476	48	153	2026-06-16 12:48:17.614+00
477	48	154	2026-06-16 12:48:17.621+00
478	48	155	2026-06-16 12:48:17.629+00
479	48	156	2026-06-16 12:48:17.635+00
480	48	157	2026-06-16 12:48:17.641+00
481	48	235	2026-06-16 12:48:17.644+00
482	48	236	2026-06-16 12:48:17.649+00
483	48	237	2026-06-16 12:48:17.653+00
484	48	238	2026-06-16 12:48:17.657+00
485	48	239	2026-06-16 12:48:17.663+00
486	49	150	2026-06-16 12:48:17.674+00
487	49	151	2026-06-16 12:48:17.678+00
488	49	152	2026-06-16 12:48:17.686+00
489	49	153	2026-06-16 12:48:17.694+00
490	49	154	2026-06-16 12:48:17.701+00
491	49	155	2026-06-16 12:48:17.707+00
492	49	156	2026-06-16 12:48:17.712+00
493	49	157	2026-06-16 12:48:17.716+00
494	49	235	2026-06-16 12:48:17.721+00
495	49	236	2026-06-16 12:48:17.725+00
496	49	237	2026-06-16 12:48:17.729+00
497	49	238	2026-06-16 12:48:17.734+00
498	49	239	2026-06-16 12:48:17.738+00
499	50	150	2026-06-16 12:48:17.751+00
500	50	151	2026-06-16 12:48:17.757+00
501	50	152	2026-06-16 12:48:17.764+00
502	50	153	2026-06-16 12:48:17.771+00
503	50	154	2026-06-16 12:48:17.774+00
504	50	155	2026-06-16 12:48:17.777+00
505	50	156	2026-06-16 12:48:17.783+00
506	50	157	2026-06-16 12:48:17.787+00
507	50	235	2026-06-16 12:48:17.792+00
508	50	236	2026-06-16 12:48:17.797+00
509	50	237	2026-06-16 12:48:17.801+00
510	50	238	2026-06-16 12:48:17.806+00
511	50	239	2026-06-16 12:48:17.814+00
512	51	150	2026-06-16 12:48:17.828+00
513	51	151	2026-06-16 12:48:17.834+00
514	51	152	2026-06-16 12:48:17.837+00
515	51	153	2026-06-16 12:48:17.841+00
516	51	154	2026-06-16 12:48:17.845+00
517	51	155	2026-06-16 12:48:17.851+00
518	51	156	2026-06-16 12:48:17.855+00
519	51	157	2026-06-16 12:48:17.86+00
520	51	235	2026-06-16 12:48:17.866+00
521	51	236	2026-06-16 12:48:17.873+00
522	51	237	2026-06-16 12:48:17.881+00
523	51	238	2026-06-16 12:48:17.887+00
524	51	239	2026-06-16 12:48:17.895+00
525	52	150	2026-06-16 12:48:17.905+00
526	52	151	2026-06-16 12:48:17.91+00
527	52	152	2026-06-16 12:48:17.914+00
528	52	153	2026-06-16 12:48:17.919+00
529	52	154	2026-06-16 12:48:17.924+00
530	52	155	2026-06-16 12:48:17.927+00
531	52	156	2026-06-16 12:48:17.932+00
532	52	157	2026-06-16 12:48:17.94+00
533	52	235	2026-06-16 12:48:17.948+00
534	52	236	2026-06-16 12:48:17.954+00
535	52	237	2026-06-16 12:48:17.962+00
536	52	238	2026-06-16 12:48:17.967+00
537	52	239	2026-06-16 12:48:17.972+00
538	53	158	2026-06-16 12:48:17.979+00
539	53	159	2026-06-16 12:48:17.984+00
540	53	160	2026-06-16 12:48:17.989+00
541	53	161	2026-06-16 12:48:17.994+00
542	53	162	2026-06-16 12:48:18.002+00
543	53	164	2026-06-16 12:48:18.009+00
544	53	165	2026-06-16 12:48:18.015+00
545	53	240	2026-06-16 12:48:18.022+00
546	53	163	2026-06-16 12:48:18.025+00
547	53	242	2026-06-16 12:48:18.028+00
548	53	243	2026-06-16 12:48:18.033+00
549	53	241	2026-06-16 12:48:18.037+00
550	53	244	2026-06-16 12:48:18.042+00
551	54	158	2026-06-16 12:48:18.052+00
552	54	159	2026-06-16 12:48:18.056+00
553	54	160	2026-06-16 12:48:18.063+00
554	54	161	2026-06-16 12:48:18.07+00
555	54	162	2026-06-16 12:48:18.076+00
556	54	164	2026-06-16 12:48:18.083+00
557	54	165	2026-06-16 12:48:18.086+00
558	54	240	2026-06-16 12:48:18.09+00
559	54	163	2026-06-16 12:48:18.094+00
560	54	242	2026-06-16 12:48:18.099+00
561	54	243	2026-06-16 12:48:18.104+00
562	54	241	2026-06-16 12:48:18.108+00
563	54	244	2026-06-16 12:48:18.114+00
564	16	320	2026-06-16 12:48:18.127+00
565	16	321	2026-06-16 12:48:18.135+00
566	16	322	2026-06-16 12:48:18.142+00
567	16	323	2026-06-16 12:48:18.151+00
568	16	324	2026-06-16 12:48:18.162+00
569	16	325	2026-06-16 12:48:18.168+00
570	16	326	2026-06-16 12:48:18.174+00
571	16	327	2026-06-16 12:48:18.179+00
572	16	328	2026-06-16 12:48:18.185+00
573	16	330	2026-06-16 12:48:18.19+00
574	16	331	2026-06-16 12:48:18.195+00
575	16	332	2026-06-16 12:48:18.201+00
576	16	333	2026-06-16 12:48:18.208+00
577	16	334	2026-06-16 12:48:18.214+00
578	16	335	2026-06-16 12:48:18.221+00
579	16	329	2026-06-16 12:48:18.226+00
580	55	158	2026-06-16 12:48:18.235+00
581	55	159	2026-06-16 12:48:18.239+00
582	55	160	2026-06-16 12:48:18.243+00
583	55	161	2026-06-16 12:48:18.248+00
584	55	162	2026-06-16 12:48:18.253+00
585	55	164	2026-06-16 12:48:18.257+00
586	55	165	2026-06-16 12:48:18.264+00
587	55	240	2026-06-16 12:48:18.271+00
588	55	163	2026-06-16 12:48:18.277+00
589	55	242	2026-06-16 12:48:18.285+00
590	55	243	2026-06-16 12:48:18.291+00
591	55	241	2026-06-16 12:48:18.295+00
592	55	244	2026-06-16 12:48:18.298+00
593	56	158	2026-06-16 12:48:18.307+00
594	56	159	2026-06-16 12:48:18.311+00
595	56	160	2026-06-16 12:48:18.316+00
596	56	161	2026-06-16 12:48:18.32+00
597	56	162	2026-06-16 12:48:18.324+00
598	56	164	2026-06-16 12:48:18.331+00
599	56	165	2026-06-16 12:48:18.338+00
600	56	240	2026-06-16 12:48:18.346+00
601	56	163	2026-06-16 12:48:18.353+00
602	56	242	2026-06-16 12:48:18.357+00
603	56	243	2026-06-16 12:48:18.361+00
604	56	241	2026-06-16 12:48:18.365+00
605	56	244	2026-06-16 12:48:18.37+00
606	57	158	2026-06-16 12:48:18.379+00
607	57	159	2026-06-16 12:48:18.384+00
608	57	160	2026-06-16 12:48:18.388+00
609	57	161	2026-06-16 12:48:18.395+00
610	57	162	2026-06-16 12:48:18.401+00
611	57	164	2026-06-16 12:48:18.408+00
612	57	165	2026-06-16 12:48:18.416+00
613	57	240	2026-06-16 12:48:18.42+00
614	57	163	2026-06-16 12:48:18.424+00
615	57	242	2026-06-16 12:48:18.428+00
616	57	243	2026-06-16 12:48:18.433+00
617	57	241	2026-06-16 12:48:18.438+00
618	57	244	2026-06-16 12:48:18.443+00
619	58	158	2026-06-16 12:48:18.458+00
620	58	159	2026-06-16 12:48:18.465+00
621	58	160	2026-06-16 12:48:18.472+00
622	58	161	2026-06-16 12:48:18.478+00
623	58	162	2026-06-16 12:48:18.483+00
624	58	164	2026-06-16 12:48:18.487+00
625	58	165	2026-06-16 12:48:18.491+00
626	58	240	2026-06-16 12:48:18.495+00
627	58	163	2026-06-16 12:48:18.5+00
628	58	242	2026-06-16 12:48:18.506+00
629	58	243	2026-06-16 12:48:18.511+00
630	58	241	2026-06-16 12:48:18.518+00
631	58	244	2026-06-16 12:48:18.525+00
632	59	158	2026-06-16 12:48:18.543+00
633	59	159	2026-06-16 12:48:18.548+00
634	59	160	2026-06-16 12:48:18.552+00
635	59	161	2026-06-16 12:48:18.556+00
636	59	162	2026-06-16 12:48:18.561+00
637	59	164	2026-06-16 12:48:18.566+00
638	59	165	2026-06-16 12:48:18.571+00
639	59	240	2026-06-16 12:48:18.574+00
640	59	163	2026-06-16 12:48:18.578+00
641	59	242	2026-06-16 12:48:18.585+00
642	59	243	2026-06-16 12:48:18.592+00
643	59	241	2026-06-16 12:48:18.598+00
644	59	244	2026-06-16 12:48:18.605+00
645	60	158	2026-06-16 12:48:18.614+00
646	60	159	2026-06-16 12:48:18.619+00
647	60	160	2026-06-16 12:48:18.623+00
648	60	161	2026-06-16 12:48:18.628+00
649	60	162	2026-06-16 12:48:18.633+00
650	60	164	2026-06-16 12:48:18.637+00
651	60	165	2026-06-16 12:48:18.642+00
652	60	240	2026-06-16 12:48:18.651+00
653	60	163	2026-06-16 12:48:18.657+00
654	60	242	2026-06-16 12:48:18.665+00
655	60	243	2026-06-16 12:48:18.671+00
656	60	241	2026-06-16 12:48:18.674+00
657	60	244	2026-06-16 12:48:18.678+00
658	61	158	2026-06-16 12:48:18.687+00
659	61	159	2026-06-16 12:48:18.691+00
660	61	160	2026-06-16 12:48:18.694+00
661	61	161	2026-06-16 12:48:18.7+00
662	61	162	2026-06-16 12:48:18.704+00
663	61	164	2026-06-16 12:48:18.712+00
664	61	165	2026-06-16 12:48:18.719+00
665	61	240	2026-06-16 12:48:18.725+00
666	61	163	2026-06-16 12:48:18.73+00
667	61	242	2026-06-16 12:48:18.735+00
668	61	243	2026-06-16 12:48:18.738+00
669	61	241	2026-06-16 12:48:18.742+00
670	61	244	2026-06-16 12:48:18.746+00
671	62	158	2026-06-16 12:48:18.756+00
672	62	159	2026-06-16 12:48:18.769+00
673	62	160	2026-06-16 12:48:18.774+00
674	62	161	2026-06-16 12:48:18.78+00
675	62	162	2026-06-16 12:48:18.787+00
676	62	164	2026-06-16 12:48:18.792+00
677	62	165	2026-06-16 12:48:18.801+00
678	62	240	2026-06-16 12:48:18.807+00
679	62	163	2026-06-16 12:48:18.818+00
680	62	242	2026-06-16 12:48:18.822+00
681	62	243	2026-06-16 12:48:18.825+00
682	62	241	2026-06-16 12:48:18.829+00
683	62	244	2026-06-16 12:48:18.835+00
684	63	191	2026-06-16 12:48:18.844+00
685	63	192	2026-06-16 12:48:18.849+00
686	63	193	2026-06-16 12:48:18.856+00
687	63	194	2026-06-16 12:48:18.862+00
688	63	195	2026-06-16 12:48:18.869+00
689	63	196	2026-06-16 12:48:18.872+00
690	63	197	2026-06-16 12:48:18.875+00
691	63	198	2026-06-16 12:48:18.879+00
692	63	262	2026-06-16 12:48:18.884+00
693	63	263	2026-06-16 12:48:18.887+00
694	63	264	2026-06-16 12:48:18.892+00
695	63	265	2026-06-16 12:48:18.897+00
696	63	266	2026-06-16 12:48:18.901+00
697	63	267	2026-06-16 12:48:18.909+00
698	63	268	2026-06-16 12:48:18.916+00
699	63	269	2026-06-16 12:48:18.922+00
700	63	270	2026-06-16 12:48:18.928+00
701	63	271	2026-06-16 12:48:18.931+00
702	63	272	2026-06-16 12:48:18.936+00
703	63	261	2026-06-16 12:48:18.939+00
704	64	191	2026-06-16 12:48:18.948+00
705	64	192	2026-06-16 12:48:18.952+00
706	64	193	2026-06-16 12:48:18.956+00
707	64	194	2026-06-16 12:48:18.961+00
708	64	195	2026-06-16 12:48:18.967+00
709	64	196	2026-06-16 12:48:18.974+00
710	64	197	2026-06-16 12:48:18.979+00
711	64	198	2026-06-16 12:48:18.986+00
712	64	262	2026-06-16 12:48:18.989+00
713	64	263	2026-06-16 12:48:18.992+00
714	64	264	2026-06-16 12:48:18.996+00
715	64	265	2026-06-16 12:48:19.001+00
716	64	266	2026-06-16 12:48:19.005+00
717	64	267	2026-06-16 12:48:19.01+00
718	64	268	2026-06-16 12:48:19.015+00
719	64	269	2026-06-16 12:48:19.02+00
720	64	270	2026-06-16 12:48:19.027+00
721	64	271	2026-06-16 12:48:19.034+00
722	64	272	2026-06-16 12:48:19.04+00
723	64	261	2026-06-16 12:48:19.052+00
724	65	191	2026-06-16 12:48:19.061+00
725	65	192	2026-06-16 12:48:19.065+00
726	65	193	2026-06-16 12:48:19.07+00
727	65	194	2026-06-16 12:48:19.074+00
728	65	195	2026-06-16 12:48:19.078+00
729	65	196	2026-06-16 12:48:19.083+00
730	65	197	2026-06-16 12:48:19.087+00
731	65	198	2026-06-16 12:48:19.094+00
732	65	262	2026-06-16 12:48:19.101+00
733	65	263	2026-06-16 12:48:19.107+00
734	65	264	2026-06-16 12:48:19.114+00
735	65	265	2026-06-16 12:48:19.118+00
736	65	266	2026-06-16 12:48:19.122+00
737	65	267	2026-06-16 12:48:19.125+00
738	65	268	2026-06-16 12:48:19.13+00
739	65	269	2026-06-16 12:48:19.135+00
740	65	270	2026-06-16 12:48:19.138+00
741	65	271	2026-06-16 12:48:19.143+00
742	65	272	2026-06-16 12:48:19.147+00
743	65	261	2026-06-16 12:48:19.154+00
744	66	191	2026-06-16 12:48:19.167+00
745	66	192	2026-06-16 12:48:19.173+00
746	66	193	2026-06-16 12:48:19.177+00
747	66	194	2026-06-16 12:48:19.181+00
748	66	195	2026-06-16 12:48:19.185+00
749	66	196	2026-06-16 12:48:19.188+00
750	66	197	2026-06-16 12:48:19.192+00
751	66	198	2026-06-16 12:48:19.195+00
752	66	262	2026-06-16 12:48:19.201+00
753	66	263	2026-06-16 12:48:19.205+00
754	66	264	2026-06-16 12:48:19.212+00
755	66	265	2026-06-16 12:48:19.22+00
756	66	266	2026-06-16 12:48:19.226+00
757	66	267	2026-06-16 12:48:19.232+00
758	66	268	2026-06-16 12:48:19.236+00
759	66	269	2026-06-16 12:48:19.24+00
760	66	270	2026-06-16 12:48:19.243+00
761	66	271	2026-06-16 12:48:19.247+00
762	66	272	2026-06-16 12:48:19.252+00
763	66	261	2026-06-16 12:48:19.255+00
764	67	191	2026-06-16 12:48:19.267+00
765	67	192	2026-06-16 12:48:19.273+00
766	67	193	2026-06-16 12:48:19.28+00
767	67	194	2026-06-16 12:48:19.286+00
768	67	195	2026-06-16 12:48:19.297+00
769	67	196	2026-06-16 12:48:19.301+00
770	67	197	2026-06-16 12:48:19.305+00
771	67	198	2026-06-16 12:48:19.309+00
772	67	262	2026-06-16 12:48:19.314+00
773	67	263	2026-06-16 12:48:19.318+00
774	67	264	2026-06-16 12:48:19.323+00
775	67	265	2026-06-16 12:48:19.328+00
776	67	266	2026-06-16 12:48:19.334+00
777	67	267	2026-06-16 12:48:19.341+00
778	67	268	2026-06-16 12:48:19.347+00
779	67	269	2026-06-16 12:48:19.353+00
780	67	270	2026-06-16 12:48:19.357+00
781	67	271	2026-06-16 12:48:19.36+00
782	67	272	2026-06-16 12:48:19.364+00
783	67	261	2026-06-16 12:48:19.368+00
784	68	191	2026-06-16 12:48:19.377+00
785	68	192	2026-06-16 12:48:19.382+00
786	68	193	2026-06-16 12:48:19.387+00
787	68	194	2026-06-16 12:48:19.393+00
788	68	195	2026-06-16 12:48:19.401+00
789	68	196	2026-06-16 12:48:19.408+00
790	68	197	2026-06-16 12:48:19.416+00
791	68	198	2026-06-16 12:48:19.42+00
792	68	262	2026-06-16 12:48:19.423+00
793	68	263	2026-06-16 12:48:19.428+00
794	68	264	2026-06-16 12:48:19.432+00
795	68	265	2026-06-16 12:48:19.436+00
796	68	266	2026-06-16 12:48:19.44+00
797	68	267	2026-06-16 12:48:19.444+00
798	68	268	2026-06-16 12:48:19.45+00
799	68	269	2026-06-16 12:48:19.456+00
800	68	270	2026-06-16 12:48:19.466+00
801	68	271	2026-06-16 12:48:19.473+00
802	68	272	2026-06-16 12:48:19.479+00
803	68	261	2026-06-16 12:48:19.485+00
804	69	191	2026-06-16 12:48:19.493+00
805	69	192	2026-06-16 12:48:19.497+00
806	69	193	2026-06-16 12:48:19.502+00
807	69	194	2026-06-16 12:48:19.506+00
808	69	195	2026-06-16 12:48:19.512+00
809	69	196	2026-06-16 12:48:19.517+00
810	69	197	2026-06-16 12:48:19.524+00
811	69	198	2026-06-16 12:48:19.531+00
812	69	262	2026-06-16 12:48:19.538+00
813	69	263	2026-06-16 12:48:19.547+00
814	69	264	2026-06-16 12:48:19.552+00
815	69	265	2026-06-16 12:48:19.557+00
816	69	266	2026-06-16 12:48:19.561+00
817	69	267	2026-06-16 12:48:19.566+00
818	69	268	2026-06-16 12:48:19.572+00
819	69	269	2026-06-16 12:48:19.578+00
820	69	270	2026-06-16 12:48:19.588+00
821	69	271	2026-06-16 12:48:19.594+00
822	69	272	2026-06-16 12:48:19.604+00
823	69	261	2026-06-16 12:48:19.612+00
824	70	191	2026-06-16 12:48:19.631+00
825	70	192	2026-06-16 12:48:19.636+00
826	70	193	2026-06-16 12:48:19.64+00
827	70	194	2026-06-16 12:48:19.644+00
828	70	195	2026-06-16 12:48:19.65+00
829	70	196	2026-06-16 12:48:19.655+00
830	70	197	2026-06-16 12:48:19.66+00
831	70	198	2026-06-16 12:48:19.666+00
832	70	262	2026-06-16 12:48:19.672+00
833	70	263	2026-06-16 12:48:19.679+00
834	70	264	2026-06-16 12:48:19.686+00
835	70	265	2026-06-16 12:48:19.693+00
836	70	266	2026-06-16 12:48:19.698+00
837	70	267	2026-06-16 12:48:19.703+00
838	70	268	2026-06-16 12:48:19.707+00
839	70	269	2026-06-16 12:48:19.711+00
840	70	270	2026-06-16 12:48:19.716+00
841	70	271	2026-06-16 12:48:19.722+00
842	70	272	2026-06-16 12:48:19.727+00
843	70	261	2026-06-16 12:48:19.733+00
844	71	191	2026-06-16 12:48:19.75+00
845	71	192	2026-06-16 12:48:19.756+00
846	71	193	2026-06-16 12:48:19.763+00
847	71	194	2026-06-16 12:48:19.767+00
848	71	195	2026-06-16 12:48:19.771+00
849	71	196	2026-06-16 12:48:19.775+00
850	71	197	2026-06-16 12:48:19.778+00
851	71	198	2026-06-16 12:48:19.784+00
852	71	262	2026-06-16 12:48:19.789+00
853	71	263	2026-06-16 12:48:19.794+00
854	71	264	2026-06-16 12:48:19.8+00
855	71	265	2026-06-16 12:48:19.807+00
856	71	266	2026-06-16 12:48:19.814+00
857	71	267	2026-06-16 12:48:19.822+00
858	71	268	2026-06-16 12:48:19.832+00
859	71	269	2026-06-16 12:48:19.836+00
860	71	270	2026-06-16 12:48:19.84+00
861	71	271	2026-06-16 12:48:19.844+00
862	71	272	2026-06-16 12:48:19.849+00
863	71	261	2026-06-16 12:48:19.854+00
864	72	191	2026-06-16 12:48:19.864+00
865	72	192	2026-06-16 12:48:19.87+00
866	72	193	2026-06-16 12:48:19.877+00
867	72	194	2026-06-16 12:48:19.884+00
868	72	195	2026-06-16 12:48:19.891+00
869	72	196	2026-06-16 12:48:19.9+00
870	72	197	2026-06-16 12:48:19.914+00
871	72	198	2026-06-16 12:48:19.922+00
872	72	262	2026-06-16 12:48:19.93+00
873	72	263	2026-06-16 12:48:19.937+00
874	72	264	2026-06-16 12:48:19.941+00
875	72	265	2026-06-16 12:48:19.945+00
876	72	266	2026-06-16 12:48:19.952+00
877	72	267	2026-06-16 12:48:19.957+00
878	72	268	2026-06-16 12:48:19.962+00
879	72	269	2026-06-16 12:48:19.968+00
880	72	270	2026-06-16 12:48:19.973+00
881	72	271	2026-06-16 12:48:19.981+00
882	72	272	2026-06-16 12:48:19.99+00
883	72	261	2026-06-16 12:48:19.998+00
884	73	167	2026-06-16 12:48:20.018+00
885	73	180	2026-06-16 12:48:20.026+00
886	73	166	2026-06-16 12:48:20.035+00
887	73	168	2026-06-16 12:48:20.041+00
888	73	169	2026-06-16 12:48:20.045+00
889	73	170	2026-06-16 12:48:20.051+00
890	73	171	2026-06-16 12:48:20.054+00
891	73	172	2026-06-16 12:48:20.059+00
892	73	173	2026-06-16 12:48:20.064+00
893	73	174	2026-06-16 12:48:20.068+00
894	73	175	2026-06-16 12:48:20.073+00
895	73	176	2026-06-16 12:48:20.077+00
896	73	177	2026-06-16 12:48:20.085+00
897	73	178	2026-06-16 12:48:20.093+00
898	73	179	2026-06-16 12:48:20.1+00
899	73	245	2026-06-16 12:48:20.106+00
900	73	246	2026-06-16 12:48:20.11+00
901	73	247	2026-06-16 12:48:20.115+00
902	73	248	2026-06-16 12:48:20.121+00
903	73	249	2026-06-16 12:48:20.125+00
904	73	250	2026-06-16 12:48:20.133+00
905	73	251	2026-06-16 12:48:20.138+00
906	73	252	2026-06-16 12:48:20.143+00
907	74	167	2026-06-16 12:48:20.158+00
908	74	180	2026-06-16 12:48:20.165+00
909	74	166	2026-06-16 12:48:20.172+00
910	74	168	2026-06-16 12:48:20.175+00
911	74	169	2026-06-16 12:48:20.177+00
912	74	170	2026-06-16 12:48:20.182+00
913	74	171	2026-06-16 12:48:20.187+00
914	74	172	2026-06-16 12:48:20.192+00
915	74	173	2026-06-16 12:48:20.196+00
916	74	174	2026-06-16 12:48:20.202+00
917	74	175	2026-06-16 12:48:20.206+00
918	74	176	2026-06-16 12:48:20.213+00
919	74	177	2026-06-16 12:48:20.221+00
920	74	178	2026-06-16 12:48:20.227+00
921	74	179	2026-06-16 12:48:20.234+00
922	74	245	2026-06-16 12:48:20.237+00
923	74	246	2026-06-16 12:48:20.24+00
924	74	247	2026-06-16 12:48:20.244+00
925	74	248	2026-06-16 12:48:20.248+00
926	74	249	2026-06-16 12:48:20.252+00
927	74	250	2026-06-16 12:48:20.257+00
928	74	251	2026-06-16 12:48:20.261+00
929	74	252	2026-06-16 12:48:20.265+00
930	75	167	2026-06-16 12:48:20.28+00
931	75	180	2026-06-16 12:48:20.286+00
932	75	166	2026-06-16 12:48:20.292+00
933	75	168	2026-06-16 12:48:20.296+00
934	75	169	2026-06-16 12:48:20.3+00
935	75	170	2026-06-16 12:48:20.304+00
936	75	171	2026-06-16 12:48:20.308+00
937	75	172	2026-06-16 12:48:20.314+00
938	75	173	2026-06-16 12:48:20.319+00
939	75	174	2026-06-16 12:48:20.323+00
940	75	175	2026-06-16 12:48:20.327+00
941	75	176	2026-06-16 12:48:20.334+00
942	75	177	2026-06-16 12:48:20.341+00
943	75	178	2026-06-16 12:48:20.347+00
944	75	179	2026-06-16 12:48:20.354+00
945	75	245	2026-06-16 12:48:20.357+00
946	75	246	2026-06-16 12:48:20.361+00
947	75	247	2026-06-16 12:48:20.365+00
948	75	248	2026-06-16 12:48:20.369+00
949	75	249	2026-06-16 12:48:20.372+00
950	75	250	2026-06-16 12:48:20.376+00
951	75	251	2026-06-16 12:48:20.38+00
952	75	252	2026-06-16 12:48:20.385+00
953	76	167	2026-06-16 12:48:20.4+00
954	76	180	2026-06-16 12:48:20.407+00
955	76	166	2026-06-16 12:48:20.413+00
956	76	168	2026-06-16 12:48:20.417+00
957	76	169	2026-06-16 12:48:20.421+00
958	76	170	2026-06-16 12:48:20.431+00
959	76	171	2026-06-16 12:48:20.435+00
960	76	172	2026-06-16 12:48:20.439+00
961	76	173	2026-06-16 12:48:20.443+00
962	76	174	2026-06-16 12:48:20.447+00
963	76	175	2026-06-16 12:48:20.452+00
964	76	176	2026-06-16 12:48:20.459+00
965	76	177	2026-06-16 12:48:20.467+00
966	76	178	2026-06-16 12:48:20.473+00
967	76	179	2026-06-16 12:48:20.48+00
968	76	245	2026-06-16 12:48:20.485+00
969	76	246	2026-06-16 12:48:20.489+00
970	76	247	2026-06-16 12:48:20.492+00
971	76	248	2026-06-16 12:48:20.496+00
972	76	249	2026-06-16 12:48:20.502+00
973	76	250	2026-06-16 12:48:20.506+00
974	76	251	2026-06-16 12:48:20.51+00
975	76	252	2026-06-16 12:48:20.517+00
976	77	167	2026-06-16 12:48:20.53+00
977	77	180	2026-06-16 12:48:20.538+00
978	77	166	2026-06-16 12:48:20.542+00
979	77	168	2026-06-16 12:48:20.547+00
980	77	169	2026-06-16 12:48:20.552+00
981	77	170	2026-06-16 12:48:20.556+00
982	77	171	2026-06-16 12:48:20.561+00
983	77	172	2026-06-16 12:48:20.565+00
984	77	173	2026-06-16 12:48:20.57+00
985	77	174	2026-06-16 12:48:20.575+00
986	77	175	2026-06-16 12:48:20.581+00
987	77	176	2026-06-16 12:48:20.589+00
988	77	177	2026-06-16 12:48:20.595+00
989	77	178	2026-06-16 12:48:20.602+00
990	77	179	2026-06-16 12:48:20.606+00
991	77	245	2026-06-16 12:48:20.61+00
992	77	246	2026-06-16 12:48:20.614+00
993	77	247	2026-06-16 12:48:20.618+00
994	77	248	2026-06-16 12:48:20.623+00
995	77	249	2026-06-16 12:48:20.626+00
996	77	250	2026-06-16 12:48:20.63+00
997	77	251	2026-06-16 12:48:20.636+00
998	77	252	2026-06-16 12:48:20.642+00
999	78	167	2026-06-16 12:48:20.657+00
1000	78	180	2026-06-16 12:48:20.663+00
1001	78	166	2026-06-16 12:48:20.667+00
1002	78	168	2026-06-16 12:48:20.671+00
1003	78	169	2026-06-16 12:48:20.674+00
1004	78	170	2026-06-16 12:48:20.678+00
1005	78	171	2026-06-16 12:48:20.682+00
1006	78	172	2026-06-16 12:48:20.686+00
1007	78	173	2026-06-16 12:48:20.69+00
1008	78	174	2026-06-16 12:48:20.694+00
1009	78	175	2026-06-16 12:48:20.701+00
1010	78	176	2026-06-16 12:48:20.708+00
1011	78	177	2026-06-16 12:48:20.715+00
1012	78	178	2026-06-16 12:48:20.721+00
1013	78	179	2026-06-16 12:48:20.725+00
1014	78	245	2026-06-16 12:48:20.728+00
1015	78	246	2026-06-16 12:48:20.734+00
1016	78	247	2026-06-16 12:48:20.738+00
1017	78	248	2026-06-16 12:48:20.742+00
1018	78	249	2026-06-16 12:48:20.75+00
1019	78	250	2026-06-16 12:48:20.756+00
1020	78	251	2026-06-16 12:48:20.763+00
1021	78	252	2026-06-16 12:48:20.769+00
1022	79	167	2026-06-16 12:48:20.776+00
1023	79	180	2026-06-16 12:48:20.78+00
1024	79	166	2026-06-16 12:48:20.785+00
1025	79	168	2026-06-16 12:48:20.79+00
1026	79	169	2026-06-16 12:48:20.794+00
1027	79	170	2026-06-16 12:48:20.799+00
1028	79	171	2026-06-16 12:48:20.804+00
1029	79	172	2026-06-16 12:48:20.812+00
1030	79	173	2026-06-16 12:48:20.819+00
1031	79	174	2026-06-16 12:48:20.825+00
1032	79	175	2026-06-16 12:48:20.831+00
1033	79	176	2026-06-16 12:48:20.835+00
1034	79	177	2026-06-16 12:48:20.839+00
1035	79	178	2026-06-16 12:48:20.843+00
1036	79	179	2026-06-16 12:48:20.846+00
1037	79	245	2026-06-16 12:48:20.851+00
1038	79	246	2026-06-16 12:48:20.855+00
1039	79	247	2026-06-16 12:48:20.859+00
1040	79	248	2026-06-16 12:48:20.864+00
1041	79	249	2026-06-16 12:48:20.871+00
1042	79	250	2026-06-16 12:48:20.877+00
1043	79	251	2026-06-16 12:48:20.884+00
1044	79	252	2026-06-16 12:48:20.89+00
1045	80	167	2026-06-16 12:48:20.899+00
1046	80	180	2026-06-16 12:48:20.903+00
1047	80	166	2026-06-16 12:48:20.907+00
1048	80	168	2026-06-16 12:48:20.912+00
1049	80	169	2026-06-16 12:48:20.916+00
1050	80	170	2026-06-16 12:48:20.92+00
1051	80	171	2026-06-16 12:48:20.924+00
1052	80	172	2026-06-16 12:48:20.931+00
1053	80	173	2026-06-16 12:48:20.938+00
1054	80	174	2026-06-16 12:48:20.945+00
1055	80	175	2026-06-16 12:48:20.951+00
1056	80	176	2026-06-16 12:48:20.954+00
1057	80	177	2026-06-16 12:48:20.958+00
1058	80	178	2026-06-16 12:48:20.961+00
1059	80	179	2026-06-16 12:48:20.966+00
1060	80	245	2026-06-16 12:48:20.971+00
1061	80	246	2026-06-16 12:48:20.975+00
1062	80	247	2026-06-16 12:48:20.979+00
1063	80	248	2026-06-16 12:48:20.984+00
1064	80	249	2026-06-16 12:48:20.99+00
1065	80	250	2026-06-16 12:48:20.997+00
1066	80	251	2026-06-16 12:48:21.004+00
1067	80	252	2026-06-16 12:48:21.01+00
1068	81	167	2026-06-16 12:48:21.018+00
1069	81	180	2026-06-16 12:48:21.022+00
1070	81	166	2026-06-16 12:48:21.026+00
1071	81	168	2026-06-16 12:48:21.029+00
1072	81	169	2026-06-16 12:48:21.034+00
1073	81	170	2026-06-16 12:48:21.039+00
1074	81	171	2026-06-16 12:48:21.043+00
1075	81	172	2026-06-16 12:48:21.051+00
1076	81	173	2026-06-16 12:48:21.057+00
1077	81	174	2026-06-16 12:48:21.064+00
1078	81	175	2026-06-16 12:48:21.071+00
1079	81	176	2026-06-16 12:48:21.075+00
1080	81	177	2026-06-16 12:48:21.078+00
1081	81	178	2026-06-16 12:48:21.082+00
1082	81	179	2026-06-16 12:48:21.087+00
1083	81	245	2026-06-16 12:48:21.09+00
1084	81	246	2026-06-16 12:48:21.095+00
1085	81	247	2026-06-16 12:48:21.1+00
1086	81	248	2026-06-16 12:48:21.105+00
1087	81	249	2026-06-16 12:48:21.113+00
1088	81	250	2026-06-16 12:48:21.12+00
1089	81	251	2026-06-16 12:48:21.126+00
1090	81	252	2026-06-16 12:48:21.132+00
1091	82	167	2026-06-16 12:48:21.14+00
1092	82	180	2026-06-16 12:48:21.144+00
1093	82	166	2026-06-16 12:48:21.149+00
1094	82	168	2026-06-16 12:48:21.153+00
1095	82	169	2026-06-16 12:48:21.157+00
1096	82	170	2026-06-16 12:48:21.161+00
1097	82	171	2026-06-16 12:48:21.165+00
1098	82	172	2026-06-16 12:48:21.172+00
1099	82	173	2026-06-16 12:48:21.179+00
1100	82	174	2026-06-16 12:48:21.185+00
1101	82	175	2026-06-16 12:48:21.193+00
1102	82	176	2026-06-16 12:48:21.197+00
1103	82	177	2026-06-16 12:48:21.202+00
1104	82	178	2026-06-16 12:48:21.206+00
1105	82	179	2026-06-16 12:48:21.212+00
1106	82	245	2026-06-16 12:48:21.217+00
1107	82	246	2026-06-16 12:48:21.222+00
1108	82	247	2026-06-16 12:48:21.226+00
1109	82	248	2026-06-16 12:48:21.231+00
1110	82	249	2026-06-16 12:48:21.238+00
1111	82	250	2026-06-16 12:48:21.244+00
1112	82	251	2026-06-16 12:48:21.25+00
1113	82	252	2026-06-16 12:48:21.254+00
1114	83	181	2026-06-16 12:48:21.261+00
1115	83	183	2026-06-16 12:48:21.265+00
1116	83	184	2026-06-16 12:48:21.271+00
1117	83	185	2026-06-16 12:48:21.274+00
1118	83	186	2026-06-16 12:48:21.278+00
1119	83	187	2026-06-16 12:48:21.283+00
1120	83	188	2026-06-16 12:48:21.291+00
1121	83	189	2026-06-16 12:48:21.299+00
1122	83	182	2026-06-16 12:48:21.306+00
1123	83	253	2026-06-16 12:48:21.312+00
1124	83	254	2026-06-16 12:48:21.316+00
1125	83	255	2026-06-16 12:48:21.32+00
1126	83	256	2026-06-16 12:48:21.325+00
1127	83	257	2026-06-16 12:48:21.329+00
1128	83	258	2026-06-16 12:48:21.334+00
1129	83	259	2026-06-16 12:48:21.338+00
1130	83	260	2026-06-16 12:48:21.343+00
1131	84	181	2026-06-16 12:48:21.357+00
1132	84	183	2026-06-16 12:48:21.364+00
1133	84	184	2026-06-16 12:48:21.37+00
1134	84	185	2026-06-16 12:48:21.373+00
1135	84	186	2026-06-16 12:48:21.375+00
1136	84	187	2026-06-16 12:48:21.378+00
1137	84	188	2026-06-16 12:48:21.384+00
1138	84	189	2026-06-16 12:48:21.388+00
1139	84	182	2026-06-16 12:48:21.393+00
1140	84	253	2026-06-16 12:48:21.398+00
1141	84	254	2026-06-16 12:48:21.404+00
1142	84	255	2026-06-16 12:48:21.41+00
1143	84	256	2026-06-16 12:48:21.418+00
1144	84	257	2026-06-16 12:48:21.424+00
1145	84	258	2026-06-16 12:48:21.431+00
1146	84	259	2026-06-16 12:48:21.435+00
1147	84	260	2026-06-16 12:48:21.437+00
1148	85	181	2026-06-16 12:48:21.446+00
1149	85	183	2026-06-16 12:48:21.451+00
1150	85	184	2026-06-16 12:48:21.455+00
1151	85	185	2026-06-16 12:48:21.459+00
1152	85	186	2026-06-16 12:48:21.464+00
1153	85	187	2026-06-16 12:48:21.47+00
1154	85	188	2026-06-16 12:48:21.477+00
1155	85	189	2026-06-16 12:48:21.484+00
1156	85	182	2026-06-16 12:48:21.491+00
1157	85	253	2026-06-16 12:48:21.495+00
1158	85	254	2026-06-16 12:48:21.498+00
1159	85	255	2026-06-16 12:48:21.504+00
1160	85	256	2026-06-16 12:48:21.508+00
1161	85	257	2026-06-16 12:48:21.512+00
1162	85	258	2026-06-16 12:48:21.517+00
1163	85	259	2026-06-16 12:48:21.521+00
1164	85	260	2026-06-16 12:48:21.526+00
1165	86	181	2026-06-16 12:48:21.541+00
1166	86	183	2026-06-16 12:48:21.548+00
1167	86	184	2026-06-16 12:48:21.555+00
1168	86	185	2026-06-16 12:48:21.558+00
1169	86	186	2026-06-16 12:48:21.562+00
1170	86	187	2026-06-16 12:48:21.567+00
1171	86	188	2026-06-16 12:48:21.57+00
1172	86	189	2026-06-16 12:48:21.574+00
1173	86	182	2026-06-16 12:48:21.579+00
1174	86	253	2026-06-16 12:48:21.586+00
1175	86	254	2026-06-16 12:48:21.592+00
1176	86	255	2026-06-16 12:48:21.601+00
1177	86	256	2026-06-16 12:48:21.607+00
1178	86	257	2026-06-16 12:48:21.614+00
1179	86	258	2026-06-16 12:48:21.621+00
1180	86	259	2026-06-16 12:48:21.625+00
1181	86	260	2026-06-16 12:48:21.629+00
1182	87	181	2026-06-16 12:48:21.64+00
1183	87	183	2026-06-16 12:48:21.645+00
1184	87	184	2026-06-16 12:48:21.65+00
1185	87	185	2026-06-16 12:48:21.655+00
1186	87	186	2026-06-16 12:48:21.66+00
1188	87	188	2026-06-16 12:48:21.675+00
1200	88	183	2026-06-16 12:48:21.747+00
1201	88	184	2026-06-16 12:48:21.751+00
1202	88	185	2026-06-16 12:48:21.755+00
1203	88	186	2026-06-16 12:48:21.759+00
1204	88	187	2026-06-16 12:48:21.763+00
1205	88	188	2026-06-16 12:48:21.768+00
1206	88	189	2026-06-16 12:48:21.773+00
1207	88	182	2026-06-16 12:48:21.779+00
1208	88	253	2026-06-16 12:48:21.786+00
1209	88	254	2026-06-16 12:48:21.792+00
1210	88	255	2026-06-16 12:48:21.799+00
1211	88	256	2026-06-16 12:48:21.804+00
1212	88	257	2026-06-16 12:48:21.808+00
1213	88	258	2026-06-16 12:48:21.812+00
1214	88	259	2026-06-16 12:48:21.817+00
1215	88	260	2026-06-16 12:48:21.822+00
1216	89	181	2026-06-16 12:48:21.83+00
1217	89	183	2026-06-16 12:48:21.835+00
1218	89	184	2026-06-16 12:48:21.842+00
1219	89	185	2026-06-16 12:48:21.847+00
1220	89	186	2026-06-16 12:48:21.854+00
1221	89	187	2026-06-16 12:48:21.86+00
1222	89	188	2026-06-16 12:48:21.864+00
1223	89	189	2026-06-16 12:48:21.868+00
1224	89	182	2026-06-16 12:48:21.872+00
1225	89	253	2026-06-16 12:48:21.876+00
1226	89	254	2026-06-16 12:48:21.879+00
1227	89	255	2026-06-16 12:48:21.884+00
1228	89	256	2026-06-16 12:48:21.888+00
1229	89	257	2026-06-16 12:48:21.892+00
1230	89	258	2026-06-16 12:48:21.898+00
1231	89	259	2026-06-16 12:48:21.905+00
1232	89	260	2026-06-16 12:48:21.912+00
1233	90	181	2026-06-16 12:48:21.923+00
1234	90	183	2026-06-16 12:48:21.926+00
1235	90	184	2026-06-16 12:48:21.931+00
1236	90	185	2026-06-16 12:48:21.935+00
1237	90	186	2026-06-16 12:48:21.939+00
1238	90	187	2026-06-16 12:48:21.944+00
1239	90	188	2026-06-16 12:48:21.948+00
1240	90	189	2026-06-16 12:48:21.954+00
1241	90	182	2026-06-16 12:48:21.961+00
1242	90	253	2026-06-16 12:48:21.969+00
1243	90	254	2026-06-16 12:48:21.975+00
1244	90	255	2026-06-16 12:48:21.981+00
1245	90	256	2026-06-16 12:48:21.985+00
1246	90	257	2026-06-16 12:48:21.988+00
1247	90	258	2026-06-16 12:48:21.992+00
1248	90	259	2026-06-16 12:48:21.995+00
1249	90	260	2026-06-16 12:48:21.999+00
1250	91	181	2026-06-16 12:48:22.01+00
1251	91	183	2026-06-16 12:48:22.016+00
1252	91	184	2026-06-16 12:48:22.024+00
1253	91	185	2026-06-16 12:48:22.031+00
1254	91	186	2026-06-16 12:48:22.037+00
1255	91	187	2026-06-16 12:48:22.043+00
1256	91	188	2026-06-16 12:48:22.048+00
1257	91	189	2026-06-16 12:48:22.053+00
1258	91	182	2026-06-16 12:48:22.057+00
1259	91	253	2026-06-16 12:48:22.063+00
1260	91	254	2026-06-16 12:48:22.068+00
1261	91	255	2026-06-16 12:48:22.073+00
1262	91	256	2026-06-16 12:48:22.077+00
1263	91	257	2026-06-16 12:48:22.085+00
1264	91	258	2026-06-16 12:48:22.091+00
1265	91	259	2026-06-16 12:48:22.097+00
1266	91	260	2026-06-16 12:48:22.104+00
1267	92	181	2026-06-16 12:48:22.112+00
1268	92	183	2026-06-16 12:48:22.117+00
1269	92	184	2026-06-16 12:48:22.123+00
1270	92	185	2026-06-16 12:48:22.127+00
1271	92	186	2026-06-16 12:48:22.132+00
1272	92	187	2026-06-16 12:48:22.138+00
1273	92	188	2026-06-16 12:48:22.143+00
1274	92	189	2026-06-16 12:48:22.15+00
1275	92	182	2026-06-16 12:48:22.157+00
1276	92	253	2026-06-16 12:48:22.164+00
1277	92	254	2026-06-16 12:48:22.171+00
1278	92	255	2026-06-16 12:48:22.175+00
1279	92	256	2026-06-16 12:48:22.179+00
1280	92	257	2026-06-16 12:48:22.184+00
1281	92	258	2026-06-16 12:48:22.188+00
1282	92	259	2026-06-16 12:48:22.192+00
1283	92	260	2026-06-16 12:48:22.196+00
1284	104	137	2026-06-16 12:48:22.207+00
1285	104	138	2026-06-16 12:48:22.214+00
1286	104	139	2026-06-16 12:48:22.221+00
1287	104	140	2026-06-16 12:48:22.227+00
1288	104	141	2026-06-16 12:48:22.234+00
1289	104	142	2026-06-16 12:48:22.237+00
1290	104	143	2026-06-16 12:48:22.24+00
1291	104	144	2026-06-16 12:48:22.244+00
1292	104	223	2026-06-16 12:48:22.248+00
1293	104	224	2026-06-16 12:48:22.254+00
1294	104	225	2026-06-16 12:48:22.259+00
1295	104	226	2026-06-16 12:48:22.264+00
1296	104	227	2026-06-16 12:48:22.27+00
1297	105	137	2026-06-16 12:48:22.285+00
1298	105	138	2026-06-16 12:48:22.293+00
1299	105	139	2026-06-16 12:48:22.301+00
1300	105	140	2026-06-16 12:48:22.305+00
1301	105	141	2026-06-16 12:48:22.309+00
1302	105	142	2026-06-16 12:48:22.314+00
1303	105	143	2026-06-16 12:48:22.318+00
1304	105	144	2026-06-16 12:48:22.323+00
1305	105	223	2026-06-16 12:48:22.326+00
1306	105	224	2026-06-16 12:48:22.331+00
1307	105	225	2026-06-16 12:48:22.336+00
1308	105	226	2026-06-16 12:48:22.343+00
1309	105	227	2026-06-16 12:48:22.35+00
1310	106	137	2026-06-16 12:48:22.364+00
1311	106	138	2026-06-16 12:48:22.368+00
1312	106	139	2026-06-16 12:48:22.372+00
1313	106	140	2026-06-16 12:48:22.376+00
1314	106	141	2026-06-16 12:48:22.381+00
1315	106	142	2026-06-16 12:48:22.385+00
1316	106	143	2026-06-16 12:48:22.389+00
1317	106	144	2026-06-16 12:48:22.394+00
1318	106	223	2026-06-16 12:48:22.401+00
1319	106	224	2026-06-16 12:48:22.409+00
1320	106	225	2026-06-16 12:48:22.416+00
1321	106	226	2026-06-16 12:48:22.422+00
1322	106	227	2026-06-16 12:48:22.426+00
1323	107	137	2026-06-16 12:48:22.436+00
1324	107	138	2026-06-16 12:48:22.44+00
1325	107	139	2026-06-16 12:48:22.446+00
1326	107	140	2026-06-16 12:48:22.451+00
1327	107	141	2026-06-16 12:48:22.455+00
1328	107	142	2026-06-16 12:48:22.46+00
1329	107	143	2026-06-16 12:48:22.467+00
1330	107	144	2026-06-16 12:48:22.474+00
1331	107	223	2026-06-16 12:48:22.481+00
1332	107	224	2026-06-16 12:48:22.487+00
1333	107	225	2026-06-16 12:48:22.491+00
1334	107	226	2026-06-16 12:48:22.495+00
1335	107	227	2026-06-16 12:48:22.5+00
1336	108	137	2026-06-16 12:48:22.51+00
1337	108	138	2026-06-16 12:48:22.516+00
1338	108	139	2026-06-16 12:48:22.521+00
1339	108	140	2026-06-16 12:48:22.525+00
1340	108	141	2026-06-16 12:48:22.533+00
1341	108	142	2026-06-16 12:48:22.54+00
1342	108	143	2026-06-16 12:48:22.545+00
1343	108	144	2026-06-16 12:48:22.552+00
1344	108	223	2026-06-16 12:48:22.556+00
1345	108	224	2026-06-16 12:48:22.56+00
1346	108	225	2026-06-16 12:48:22.565+00
1347	108	226	2026-06-16 12:48:22.569+00
1348	108	227	2026-06-16 12:48:22.574+00
1349	109	137	2026-06-16 12:48:22.584+00
1350	109	138	2026-06-16 12:48:22.589+00
1351	109	139	2026-06-16 12:48:22.596+00
1352	109	140	2026-06-16 12:48:22.602+00
1353	109	141	2026-06-16 12:48:22.609+00
1354	109	142	2026-06-16 12:48:22.616+00
1355	109	143	2026-06-16 12:48:22.622+00
1356	109	144	2026-06-16 12:48:22.627+00
1357	109	223	2026-06-16 12:48:22.632+00
1358	109	224	2026-06-16 12:48:22.64+00
1359	109	225	2026-06-16 12:48:22.647+00
1360	109	226	2026-06-16 12:48:22.654+00
1361	109	227	2026-06-16 12:48:22.661+00
1362	110	137	2026-06-16 12:48:22.668+00
1363	110	138	2026-06-16 12:48:22.672+00
1364	110	139	2026-06-16 12:48:22.676+00
1365	110	140	2026-06-16 12:48:22.681+00
1366	110	141	2026-06-16 12:48:22.686+00
1367	110	142	2026-06-16 12:48:22.69+00
1368	110	143	2026-06-16 12:48:22.697+00
1369	110	144	2026-06-16 12:48:22.705+00
1370	110	223	2026-06-16 12:48:22.711+00
1371	110	224	2026-06-16 12:48:22.718+00
1372	110	225	2026-06-16 12:48:22.722+00
1373	110	226	2026-06-16 12:48:22.725+00
1374	110	227	2026-06-16 12:48:22.73+00
1375	111	137	2026-06-16 12:48:22.737+00
1376	111	138	2026-06-16 12:48:22.742+00
1377	111	139	2026-06-16 12:48:22.746+00
1378	111	140	2026-06-16 12:48:22.751+00
1379	111	141	2026-06-16 12:48:22.757+00
1380	111	142	2026-06-16 12:48:22.764+00
1381	111	143	2026-06-16 12:48:22.77+00
1382	111	144	2026-06-16 12:48:22.776+00
1383	111	223	2026-06-16 12:48:22.78+00
1384	111	224	2026-06-16 12:48:22.784+00
1385	111	225	2026-06-16 12:48:22.788+00
1386	111	226	2026-06-16 12:48:22.792+00
1387	111	227	2026-06-16 12:48:22.797+00
1388	112	137	2026-06-16 12:48:22.808+00
1389	112	138	2026-06-16 12:48:22.814+00
1390	112	139	2026-06-16 12:48:22.823+00
1391	112	140	2026-06-16 12:48:22.831+00
1392	112	141	2026-06-16 12:48:22.838+00
1393	112	142	2026-06-16 12:48:22.845+00
1394	112	143	2026-06-16 12:48:22.85+00
1395	112	144	2026-06-16 12:48:22.854+00
1396	112	223	2026-06-16 12:48:22.858+00
1397	112	224	2026-06-16 12:48:22.863+00
1398	112	225	2026-06-16 12:48:22.868+00
1399	112	226	2026-06-16 12:48:22.873+00
1400	112	227	2026-06-16 12:48:22.877+00
1401	113	137	2026-06-16 12:48:22.891+00
1402	113	138	2026-06-16 12:48:22.897+00
1403	113	139	2026-06-16 12:48:22.904+00
1404	113	140	2026-06-16 12:48:22.911+00
1405	113	141	2026-06-16 12:48:22.916+00
1406	113	142	2026-06-16 12:48:22.921+00
1407	113	143	2026-06-16 12:48:22.925+00
1408	113	144	2026-06-16 12:48:22.929+00
1409	113	223	2026-06-16 12:48:22.933+00
1410	113	224	2026-06-16 12:48:22.939+00
1411	113	225	2026-06-16 12:48:22.944+00
1412	113	226	2026-06-16 12:48:22.949+00
1413	113	227	2026-06-16 12:48:22.956+00
1414	114	145	2026-06-16 12:48:22.971+00
1415	114	146	2026-06-16 12:48:22.977+00
1416	114	147	2026-06-16 12:48:22.982+00
1417	114	148	2026-06-16 12:48:22.986+00
1418	114	149	2026-06-16 12:48:22.989+00
1419	114	228	2026-06-16 12:48:22.993+00
1420	114	230	2026-06-16 12:48:22.995+00
1421	114	231	2026-06-16 12:48:23.001+00
1422	114	232	2026-06-16 12:48:23.006+00
1423	114	233	2026-06-16 12:48:23.01+00
1424	114	234	2026-06-16 12:48:23.018+00
1425	114	229	2026-06-16 12:48:23.025+00
1426	115	145	2026-06-16 12:48:23.038+00
1427	115	146	2026-06-16 12:48:23.043+00
1428	115	147	2026-06-16 12:48:23.047+00
1429	115	148	2026-06-16 12:48:23.052+00
1430	115	149	2026-06-16 12:48:23.055+00
1431	115	228	2026-06-16 12:48:23.058+00
1432	115	230	2026-06-16 12:48:23.062+00
1433	115	231	2026-06-16 12:48:23.067+00
1434	115	232	2026-06-16 12:48:23.074+00
1435	115	233	2026-06-16 12:48:23.079+00
1436	115	234	2026-06-16 12:48:23.086+00
1437	115	229	2026-06-16 12:48:23.093+00
1438	116	145	2026-06-16 12:48:23.102+00
1439	116	146	2026-06-16 12:48:23.107+00
1440	116	147	2026-06-16 12:48:23.112+00
1441	116	148	2026-06-16 12:48:23.116+00
1442	116	149	2026-06-16 12:48:23.121+00
1443	116	228	2026-06-16 12:48:23.125+00
1444	116	230	2026-06-16 12:48:23.129+00
1445	116	231	2026-06-16 12:48:23.136+00
1446	116	232	2026-06-16 12:48:23.142+00
1447	116	233	2026-06-16 12:48:23.149+00
1448	116	234	2026-06-16 12:48:23.156+00
1449	116	229	2026-06-16 12:48:23.159+00
1450	117	145	2026-06-16 12:48:23.169+00
1451	117	146	2026-06-16 12:48:23.173+00
1452	117	147	2026-06-16 12:48:23.176+00
1453	117	148	2026-06-16 12:48:23.18+00
1454	117	149	2026-06-16 12:48:23.185+00
1455	117	228	2026-06-16 12:48:23.19+00
1456	117	230	2026-06-16 12:48:23.196+00
1457	117	231	2026-06-16 12:48:23.205+00
1458	117	232	2026-06-16 12:48:23.212+00
1459	117	233	2026-06-16 12:48:23.218+00
1460	117	234	2026-06-16 12:48:23.222+00
1461	117	229	2026-06-16 12:48:23.226+00
1462	118	145	2026-06-16 12:48:23.236+00
1463	118	146	2026-06-16 12:48:23.24+00
1464	118	147	2026-06-16 12:48:23.246+00
1465	118	148	2026-06-16 12:48:23.251+00
1466	118	149	2026-06-16 12:48:23.255+00
1467	118	228	2026-06-16 12:48:23.262+00
1468	118	230	2026-06-16 12:48:23.269+00
1469	118	231	2026-06-16 12:48:23.274+00
1470	118	232	2026-06-16 12:48:23.28+00
1471	118	233	2026-06-16 12:48:23.284+00
1472	118	234	2026-06-16 12:48:23.287+00
1473	118	229	2026-06-16 12:48:23.291+00
1474	119	145	2026-06-16 12:48:23.301+00
1475	119	146	2026-06-16 12:48:23.305+00
1476	119	147	2026-06-16 12:48:23.309+00
1477	119	148	2026-06-16 12:48:23.315+00
1478	119	149	2026-06-16 12:48:23.323+00
1479	119	228	2026-06-16 12:48:23.329+00
1480	119	230	2026-06-16 12:48:23.335+00
1481	119	231	2026-06-16 12:48:23.342+00
1482	119	232	2026-06-16 12:48:23.345+00
1483	119	233	2026-06-16 12:48:23.35+00
1484	119	234	2026-06-16 12:48:23.354+00
1485	119	229	2026-06-16 12:48:23.358+00
1486	120	145	2026-06-16 12:48:23.369+00
1487	120	146	2026-06-16 12:48:23.376+00
1488	120	147	2026-06-16 12:48:23.385+00
1489	120	148	2026-06-16 12:48:23.391+00
1490	120	149	2026-06-16 12:48:23.398+00
1491	120	228	2026-06-16 12:48:23.404+00
1492	120	230	2026-06-16 12:48:23.407+00
1493	120	231	2026-06-16 12:48:23.412+00
1494	120	232	2026-06-16 12:48:23.417+00
1495	120	233	2026-06-16 12:48:23.421+00
1496	120	234	2026-06-16 12:48:23.425+00
1497	120	229	2026-06-16 12:48:23.428+00
1498	121	145	2026-06-16 12:48:23.438+00
1499	121	146	2026-06-16 12:48:23.445+00
1500	121	147	2026-06-16 12:48:23.452+00
1501	121	148	2026-06-16 12:48:23.459+00
1502	121	149	2026-06-16 12:48:23.465+00
1503	121	228	2026-06-16 12:48:23.469+00
1504	121	230	2026-06-16 12:48:23.473+00
1505	121	231	2026-06-16 12:48:23.476+00
1506	121	232	2026-06-16 12:48:23.48+00
1507	121	233	2026-06-16 12:48:23.485+00
1508	121	234	2026-06-16 12:48:23.489+00
1509	121	229	2026-06-16 12:48:23.493+00
1510	122	145	2026-06-16 12:48:23.506+00
1511	122	146	2026-06-16 12:48:23.513+00
1512	122	147	2026-06-16 12:48:23.52+00
1513	122	148	2026-06-16 12:48:23.527+00
1514	122	149	2026-06-16 12:48:23.531+00
1515	122	228	2026-06-16 12:48:23.535+00
1516	122	230	2026-06-16 12:48:23.538+00
1517	122	231	2026-06-16 12:48:23.542+00
1518	122	232	2026-06-16 12:48:23.547+00
1519	122	233	2026-06-16 12:48:23.551+00
1520	122	234	2026-06-16 12:48:23.555+00
1521	122	229	2026-06-16 12:48:23.56+00
1522	123	145	2026-06-16 12:48:23.575+00
1523	123	146	2026-06-16 12:48:23.581+00
1524	123	147	2026-06-16 12:48:23.588+00
1525	123	148	2026-06-16 12:48:23.592+00
1526	123	149	2026-06-16 12:48:23.595+00
1527	123	228	2026-06-16 12:48:23.599+00
1528	123	230	2026-06-16 12:48:23.604+00
1529	123	231	2026-06-16 12:48:23.608+00
1530	123	232	2026-06-16 12:48:23.613+00
1531	123	233	2026-06-16 12:48:23.618+00
1532	123	234	2026-06-16 12:48:23.623+00
1533	123	229	2026-06-16 12:48:23.629+00
1534	124	150	2026-06-16 12:48:23.643+00
1535	124	151	2026-06-16 12:48:23.651+00
1536	124	152	2026-06-16 12:48:23.654+00
1537	124	153	2026-06-16 12:48:23.657+00
1538	124	154	2026-06-16 12:48:23.661+00
1539	124	155	2026-06-16 12:48:23.666+00
1540	124	156	2026-06-16 12:48:23.67+00
1541	124	157	2026-06-16 12:48:23.674+00
1542	124	235	2026-06-16 12:48:23.678+00
1543	124	236	2026-06-16 12:48:23.685+00
1544	124	237	2026-06-16 12:48:23.691+00
1545	124	238	2026-06-16 12:48:23.697+00
1546	124	239	2026-06-16 12:48:23.704+00
1547	125	150	2026-06-16 12:48:23.713+00
1548	125	151	2026-06-16 12:48:23.717+00
1549	125	152	2026-06-16 12:48:23.722+00
1550	125	153	2026-06-16 12:48:23.726+00
1551	125	154	2026-06-16 12:48:23.731+00
1552	125	155	2026-06-16 12:48:23.735+00
1553	125	156	2026-06-16 12:48:23.74+00
1554	125	157	2026-06-16 12:48:23.747+00
1555	125	235	2026-06-16 12:48:23.755+00
1556	125	236	2026-06-16 12:48:23.761+00
1557	125	237	2026-06-16 12:48:23.768+00
1558	125	238	2026-06-16 12:48:23.772+00
1559	125	239	2026-06-16 12:48:23.775+00
1560	126	150	2026-06-16 12:48:23.785+00
1561	126	151	2026-06-16 12:48:23.789+00
1562	126	152	2026-06-16 12:48:23.793+00
1563	126	153	2026-06-16 12:48:23.796+00
1564	126	154	2026-06-16 12:48:23.801+00
1565	126	155	2026-06-16 12:48:23.808+00
1566	126	156	2026-06-16 12:48:23.815+00
1567	126	157	2026-06-16 12:48:23.822+00
1568	126	235	2026-06-16 12:48:23.828+00
1569	126	236	2026-06-16 12:48:23.831+00
1570	126	237	2026-06-16 12:48:23.835+00
1571	126	238	2026-06-16 12:48:23.839+00
1572	126	239	2026-06-16 12:48:23.842+00
1573	127	150	2026-06-16 12:48:23.852+00
1574	127	151	2026-06-16 12:48:23.857+00
1575	127	152	2026-06-16 12:48:23.862+00
1576	127	153	2026-06-16 12:48:23.869+00
1577	127	154	2026-06-16 12:48:23.875+00
1578	127	155	2026-06-16 12:48:23.881+00
1579	127	156	2026-06-16 12:48:23.887+00
1580	127	157	2026-06-16 12:48:23.89+00
1581	127	235	2026-06-16 12:48:23.893+00
1582	127	236	2026-06-16 12:48:23.897+00
1583	127	237	2026-06-16 12:48:23.902+00
1584	127	238	2026-06-16 12:48:23.906+00
1585	127	239	2026-06-16 12:48:23.91+00
1586	128	150	2026-06-16 12:48:23.921+00
1587	128	151	2026-06-16 12:48:23.929+00
1588	128	152	2026-06-16 12:48:23.935+00
1589	128	153	2026-06-16 12:48:23.941+00
1590	128	154	2026-06-16 12:48:23.947+00
1591	128	155	2026-06-16 12:48:23.952+00
1592	128	156	2026-06-16 12:48:23.955+00
1593	128	157	2026-06-16 12:48:23.959+00
1594	128	235	2026-06-16 12:48:23.964+00
1595	128	236	2026-06-16 12:48:23.973+00
1596	128	237	2026-06-16 12:48:23.98+00
1597	128	238	2026-06-16 12:48:23.987+00
1598	128	239	2026-06-16 12:48:23.992+00
1599	129	150	2026-06-16 12:48:24.005+00
1600	129	151	2026-06-16 12:48:24.01+00
1601	129	152	2026-06-16 12:48:24.015+00
1602	129	153	2026-06-16 12:48:24.029+00
1603	129	154	2026-06-16 12:48:24.039+00
1604	129	155	2026-06-16 12:48:24.047+00
1605	129	156	2026-06-16 12:48:24.054+00
1606	129	157	2026-06-16 12:48:24.063+00
1607	129	235	2026-06-16 12:48:24.072+00
1608	129	236	2026-06-16 12:48:24.084+00
1609	129	237	2026-06-16 12:48:24.101+00
1610	129	238	2026-06-16 12:48:24.107+00
1611	129	239	2026-06-16 12:48:24.116+00
1612	130	150	2026-06-16 12:48:24.131+00
1613	130	151	2026-06-16 12:48:24.141+00
1614	130	152	2026-06-16 12:48:24.147+00
1615	130	153	2026-06-16 12:48:24.153+00
1616	130	154	2026-06-16 12:48:24.158+00
1617	130	155	2026-06-16 12:48:24.166+00
1618	130	156	2026-06-16 12:48:24.173+00
1619	130	157	2026-06-16 12:48:24.189+00
1620	130	235	2026-06-16 12:48:24.2+00
1621	130	236	2026-06-16 12:48:24.204+00
1622	130	237	2026-06-16 12:48:24.208+00
1623	130	238	2026-06-16 12:48:24.211+00
1624	130	239	2026-06-16 12:48:24.215+00
1625	131	150	2026-06-16 12:48:24.225+00
1626	131	151	2026-06-16 12:48:24.229+00
1627	131	152	2026-06-16 12:48:24.235+00
1628	131	153	2026-06-16 12:48:24.241+00
1629	131	154	2026-06-16 12:48:24.248+00
1630	131	155	2026-06-16 12:48:24.255+00
1631	131	156	2026-06-16 12:48:24.261+00
1632	131	157	2026-06-16 12:48:24.265+00
1633	131	235	2026-06-16 12:48:24.269+00
1634	131	236	2026-06-16 12:48:24.273+00
1635	131	237	2026-06-16 12:48:24.277+00
1636	131	238	2026-06-16 12:48:24.281+00
1637	131	239	2026-06-16 12:48:24.285+00
1638	132	150	2026-06-16 12:48:24.294+00
1639	132	151	2026-06-16 12:48:24.302+00
1640	132	152	2026-06-16 12:48:24.308+00
1641	132	153	2026-06-16 12:48:24.314+00
1642	132	154	2026-06-16 12:48:24.32+00
1643	132	155	2026-06-16 12:48:24.324+00
1644	132	156	2026-06-16 12:48:24.328+00
1645	132	157	2026-06-16 12:48:24.333+00
1646	132	235	2026-06-16 12:48:24.338+00
1647	132	236	2026-06-16 12:48:24.342+00
1648	132	237	2026-06-16 12:48:24.345+00
1649	132	238	2026-06-16 12:48:24.35+00
1650	132	239	2026-06-16 12:48:24.355+00
1651	133	150	2026-06-16 12:48:24.37+00
1652	133	151	2026-06-16 12:48:24.376+00
1653	133	152	2026-06-16 12:48:24.384+00
1654	133	153	2026-06-16 12:48:24.388+00
1655	133	154	2026-06-16 12:48:24.391+00
1656	133	155	2026-06-16 12:48:24.395+00
1657	133	156	2026-06-16 12:48:24.4+00
1658	133	157	2026-06-16 12:48:24.405+00
1659	133	235	2026-06-16 12:48:24.409+00
1660	133	236	2026-06-16 12:48:24.414+00
1661	133	237	2026-06-16 12:48:24.422+00
1662	133	238	2026-06-16 12:48:24.428+00
1663	133	239	2026-06-16 12:48:24.435+00
1664	134	158	2026-06-16 12:48:24.446+00
1665	134	159	2026-06-16 12:48:24.45+00
1666	134	160	2026-06-16 12:48:24.454+00
1667	134	161	2026-06-16 12:48:24.457+00
1668	134	162	2026-06-16 12:48:24.462+00
1669	134	164	2026-06-16 12:48:24.467+00
1670	134	165	2026-06-16 12:48:24.471+00
1671	134	240	2026-06-16 12:48:24.475+00
1672	134	163	2026-06-16 12:48:24.482+00
1673	134	242	2026-06-16 12:48:24.489+00
1674	134	243	2026-06-16 12:48:24.495+00
1675	134	241	2026-06-16 12:48:24.502+00
1676	134	244	2026-06-16 12:48:24.506+00
1677	135	158	2026-06-16 12:48:24.515+00
1678	135	159	2026-06-16 12:48:24.52+00
1679	135	160	2026-06-16 12:48:24.525+00
1680	135	161	2026-06-16 12:48:24.529+00
1681	135	162	2026-06-16 12:48:24.534+00
1682	135	164	2026-06-16 12:48:24.538+00
1683	135	165	2026-06-16 12:48:24.545+00
1684	135	240	2026-06-16 12:48:24.552+00
1685	135	163	2026-06-16 12:48:24.558+00
1686	135	242	2026-06-16 12:48:24.564+00
1687	135	243	2026-06-16 12:48:24.568+00
1688	135	241	2026-06-16 12:48:24.572+00
1689	135	244	2026-06-16 12:48:24.575+00
1690	136	158	2026-06-16 12:48:24.591+00
1691	136	159	2026-06-16 12:48:24.595+00
1692	136	160	2026-06-16 12:48:24.6+00
1693	136	161	2026-06-16 12:48:24.605+00
1694	136	162	2026-06-16 12:48:24.612+00
1695	136	164	2026-06-16 12:48:24.619+00
1696	136	165	2026-06-16 12:48:24.625+00
1697	136	240	2026-06-16 12:48:24.63+00
1698	136	163	2026-06-16 12:48:24.635+00
1699	136	242	2026-06-16 12:48:24.639+00
1700	136	243	2026-06-16 12:48:24.642+00
1701	136	241	2026-06-16 12:48:24.646+00
1702	136	244	2026-06-16 12:48:24.651+00
1703	137	158	2026-06-16 12:48:24.661+00
1704	137	159	2026-06-16 12:48:24.667+00
1705	137	160	2026-06-16 12:48:24.674+00
1706	137	161	2026-06-16 12:48:24.681+00
1707	137	162	2026-06-16 12:48:24.687+00
1708	137	164	2026-06-16 12:48:24.694+00
1709	137	165	2026-06-16 12:48:24.698+00
1710	137	240	2026-06-16 12:48:24.702+00
1711	137	163	2026-06-16 12:48:24.706+00
1712	137	242	2026-06-16 12:48:24.71+00
1713	137	243	2026-06-16 12:48:24.714+00
1714	137	241	2026-06-16 12:48:24.719+00
1715	137	244	2026-06-16 12:48:24.723+00
1716	138	158	2026-06-16 12:48:24.735+00
1717	138	159	2026-06-16 12:48:24.741+00
1718	138	160	2026-06-16 12:48:24.747+00
1719	138	161	2026-06-16 12:48:24.753+00
1720	138	162	2026-06-16 12:48:24.757+00
1721	138	164	2026-06-16 12:48:24.76+00
1722	138	165	2026-06-16 12:48:24.764+00
1723	138	240	2026-06-16 12:48:24.768+00
1724	138	163	2026-06-16 12:48:24.772+00
1725	138	242	2026-06-16 12:48:24.776+00
1726	138	243	2026-06-16 12:48:24.781+00
1727	138	241	2026-06-16 12:48:24.788+00
1728	138	244	2026-06-16 12:48:24.795+00
1729	139	158	2026-06-16 12:48:24.808+00
1730	139	159	2026-06-16 12:48:24.813+00
1731	139	160	2026-06-16 12:48:24.817+00
1732	139	161	2026-06-16 12:48:24.821+00
1733	139	162	2026-06-16 12:48:24.824+00
1734	139	164	2026-06-16 12:48:24.829+00
1735	139	165	2026-06-16 12:48:24.833+00
1736	139	240	2026-06-16 12:48:24.837+00
1737	139	163	2026-06-16 12:48:24.841+00
1738	139	242	2026-06-16 12:48:24.848+00
1739	139	243	2026-06-16 12:48:24.855+00
1740	139	241	2026-06-16 12:48:24.862+00
1741	139	244	2026-06-16 12:48:24.869+00
1742	140	158	2026-06-16 12:48:24.877+00
1743	140	159	2026-06-16 12:48:24.882+00
1744	140	160	2026-06-16 12:48:24.886+00
1745	140	161	2026-06-16 12:48:24.89+00
1746	140	162	2026-06-16 12:48:24.894+00
1747	140	164	2026-06-16 12:48:24.899+00
1748	140	165	2026-06-16 12:48:24.904+00
1749	140	240	2026-06-16 12:48:24.912+00
1750	140	163	2026-06-16 12:48:24.918+00
1751	140	242	2026-06-16 12:48:24.925+00
1752	140	243	2026-06-16 12:48:24.931+00
1753	140	241	2026-06-16 12:48:24.935+00
1754	140	244	2026-06-16 12:48:24.938+00
1755	141	158	2026-06-16 12:48:24.947+00
1756	141	159	2026-06-16 12:48:24.951+00
1757	141	160	2026-06-16 12:48:24.955+00
1758	141	161	2026-06-16 12:48:24.96+00
1759	141	162	2026-06-16 12:48:24.964+00
1760	141	164	2026-06-16 12:48:24.971+00
1761	141	165	2026-06-16 12:48:24.976+00
1762	141	240	2026-06-16 12:48:24.983+00
1763	141	163	2026-06-16 12:48:24.99+00
1764	141	242	2026-06-16 12:48:24.994+00
1765	141	243	2026-06-16 12:48:24.997+00
1766	141	241	2026-06-16 12:48:25.001+00
1767	141	244	2026-06-16 12:48:25.005+00
1768	142	158	2026-06-16 12:48:25.015+00
1769	142	159	2026-06-16 12:48:25.021+00
1770	142	160	2026-06-16 12:48:25.025+00
1771	142	161	2026-06-16 12:48:25.033+00
1772	142	162	2026-06-16 12:48:25.041+00
1773	142	164	2026-06-16 12:48:25.047+00
1774	142	165	2026-06-16 12:48:25.052+00
1775	142	240	2026-06-16 12:48:25.056+00
1776	142	163	2026-06-16 12:48:25.059+00
1777	142	242	2026-06-16 12:48:25.063+00
1778	142	243	2026-06-16 12:48:25.068+00
1779	142	241	2026-06-16 12:48:25.072+00
1780	142	244	2026-06-16 12:48:25.077+00
1781	143	158	2026-06-16 12:48:25.09+00
1782	143	159	2026-06-16 12:48:25.096+00
1783	143	160	2026-06-16 12:48:25.102+00
1784	143	161	2026-06-16 12:48:25.107+00
1785	143	162	2026-06-16 12:48:25.11+00
1786	143	164	2026-06-16 12:48:25.114+00
1787	143	165	2026-06-16 12:48:25.118+00
1788	143	240	2026-06-16 12:48:25.122+00
1789	143	163	2026-06-16 12:48:25.125+00
1790	143	242	2026-06-16 12:48:25.129+00
1791	143	243	2026-06-16 12:48:25.134+00
1792	143	241	2026-06-16 12:48:25.141+00
1793	143	244	2026-06-16 12:48:25.147+00
1794	144	191	2026-06-16 12:48:25.161+00
1795	144	192	2026-06-16 12:48:25.166+00
1796	144	193	2026-06-16 12:48:25.17+00
1797	144	194	2026-06-16 12:48:25.175+00
1798	144	195	2026-06-16 12:48:25.179+00
1799	144	196	2026-06-16 12:48:25.185+00
1800	144	197	2026-06-16 12:48:25.189+00
1801	144	198	2026-06-16 12:48:25.194+00
1802	144	262	2026-06-16 12:48:25.198+00
1803	144	263	2026-06-16 12:48:25.206+00
1804	144	264	2026-06-16 12:48:25.213+00
1805	144	265	2026-06-16 12:48:25.22+00
1806	144	266	2026-06-16 12:48:25.226+00
1807	144	267	2026-06-16 12:48:25.229+00
1808	144	268	2026-06-16 12:48:25.234+00
1809	144	269	2026-06-16 12:48:25.237+00
1810	144	270	2026-06-16 12:48:25.242+00
1811	144	271	2026-06-16 12:48:25.246+00
1812	144	272	2026-06-16 12:48:25.25+00
1813	144	261	2026-06-16 12:48:25.254+00
1814	145	191	2026-06-16 12:48:25.266+00
1815	145	192	2026-06-16 12:48:25.273+00
1816	145	193	2026-06-16 12:48:25.279+00
1817	145	194	2026-06-16 12:48:25.286+00
1818	145	195	2026-06-16 12:48:25.289+00
1819	145	196	2026-06-16 12:48:25.293+00
1820	145	197	2026-06-16 12:48:25.296+00
1821	145	198	2026-06-16 12:48:25.302+00
1822	145	262	2026-06-16 12:48:25.306+00
1823	145	263	2026-06-16 12:48:25.31+00
1824	145	264	2026-06-16 12:48:25.315+00
1825	145	265	2026-06-16 12:48:25.321+00
1826	145	266	2026-06-16 12:48:25.329+00
1827	145	267	2026-06-16 12:48:25.339+00
1828	145	268	2026-06-16 12:48:25.346+00
1829	145	269	2026-06-16 12:48:25.352+00
1830	145	270	2026-06-16 12:48:25.359+00
1831	145	271	2026-06-16 12:48:25.366+00
1832	145	272	2026-06-16 12:48:25.373+00
1833	145	261	2026-06-16 12:48:25.381+00
1834	146	191	2026-06-16 12:48:25.389+00
1835	146	192	2026-06-16 12:48:25.393+00
1836	146	193	2026-06-16 12:48:25.399+00
1837	146	194	2026-06-16 12:48:25.404+00
1838	146	195	2026-06-16 12:48:25.412+00
1839	146	196	2026-06-16 12:48:25.418+00
1840	146	197	2026-06-16 12:48:25.425+00
1841	146	198	2026-06-16 12:48:25.432+00
1842	146	262	2026-06-16 12:48:25.44+00
1843	146	263	2026-06-16 12:48:25.447+00
1844	146	264	2026-06-16 12:48:25.452+00
1845	146	265	2026-06-16 12:48:25.456+00
1846	146	266	2026-06-16 12:48:25.46+00
1847	146	267	2026-06-16 12:48:25.466+00
1848	146	268	2026-06-16 12:48:25.471+00
1849	146	269	2026-06-16 12:48:25.475+00
1850	146	270	2026-06-16 12:48:25.479+00
1851	146	271	2026-06-16 12:48:25.486+00
1852	146	272	2026-06-16 12:48:25.492+00
1853	146	261	2026-06-16 12:48:25.5+00
1854	147	191	2026-06-16 12:48:25.512+00
1855	147	192	2026-06-16 12:48:25.519+00
1856	147	193	2026-06-16 12:48:25.525+00
1857	147	194	2026-06-16 12:48:25.53+00
1858	147	195	2026-06-16 12:48:25.538+00
1859	147	196	2026-06-16 12:48:25.544+00
1860	147	197	2026-06-16 12:48:25.552+00
1861	147	198	2026-06-16 12:48:25.559+00
1862	147	262	2026-06-16 12:48:25.567+00
1863	147	263	2026-06-16 12:48:25.573+00
1864	147	264	2026-06-16 12:48:25.581+00
1865	147	265	2026-06-16 12:48:25.585+00
1866	147	266	2026-06-16 12:48:25.589+00
1867	147	267	2026-06-16 12:48:25.593+00
1868	147	268	2026-06-16 12:48:25.599+00
1869	147	269	2026-06-16 12:48:25.604+00
1870	147	270	2026-06-16 12:48:25.609+00
1871	147	271	2026-06-16 12:48:25.615+00
1872	147	272	2026-06-16 12:48:25.622+00
1873	147	261	2026-06-16 12:48:25.629+00
1874	148	191	2026-06-16 12:48:25.643+00
1875	148	192	2026-06-16 12:48:25.65+00
1876	148	193	2026-06-16 12:48:25.655+00
1877	148	194	2026-06-16 12:48:25.659+00
1878	148	195	2026-06-16 12:48:25.664+00
1879	148	196	2026-06-16 12:48:25.669+00
1880	148	197	2026-06-16 12:48:25.674+00
1881	148	198	2026-06-16 12:48:25.677+00
1882	148	262	2026-06-16 12:48:25.682+00
1883	148	263	2026-06-16 12:48:25.689+00
1884	148	264	2026-06-16 12:48:25.697+00
1885	148	265	2026-06-16 12:48:25.704+00
1886	148	266	2026-06-16 12:48:25.711+00
1887	148	267	2026-06-16 12:48:25.719+00
1888	148	268	2026-06-16 12:48:25.723+00
1889	148	269	2026-06-16 12:48:25.728+00
1890	148	270	2026-06-16 12:48:25.734+00
1891	148	271	2026-06-16 12:48:25.74+00
1892	148	272	2026-06-16 12:48:25.745+00
1893	148	261	2026-06-16 12:48:25.751+00
1894	149	191	2026-06-16 12:48:25.762+00
1895	149	192	2026-06-16 12:48:25.771+00
1896	149	193	2026-06-16 12:48:25.778+00
1897	149	194	2026-06-16 12:48:25.785+00
1898	149	195	2026-06-16 12:48:25.792+00
1899	149	196	2026-06-16 12:48:25.795+00
1900	149	197	2026-06-16 12:48:25.799+00
1901	149	198	2026-06-16 12:48:25.804+00
1902	149	262	2026-06-16 12:48:25.81+00
1903	149	263	2026-06-16 12:48:25.815+00
1904	149	264	2026-06-16 12:48:25.821+00
1905	149	265	2026-06-16 12:48:25.826+00
1906	149	266	2026-06-16 12:48:25.834+00
1907	149	267	2026-06-16 12:48:25.841+00
1908	149	268	2026-06-16 12:48:25.845+00
1909	149	269	2026-06-16 12:48:25.848+00
1910	149	270	2026-06-16 12:48:25.852+00
1911	149	271	2026-06-16 12:48:25.857+00
1912	149	272	2026-06-16 12:48:25.861+00
1913	149	261	2026-06-16 12:48:25.866+00
1914	150	191	2026-06-16 12:48:25.875+00
1915	150	192	2026-06-16 12:48:25.883+00
1916	150	193	2026-06-16 12:48:25.89+00
1917	150	194	2026-06-16 12:48:25.896+00
1918	150	195	2026-06-16 12:48:25.903+00
1919	150	196	2026-06-16 12:48:25.906+00
1920	150	197	2026-06-16 12:48:25.909+00
1921	150	198	2026-06-16 12:48:25.914+00
1922	150	262	2026-06-16 12:48:25.918+00
1923	150	263	2026-06-16 12:48:25.923+00
1924	150	264	2026-06-16 12:48:25.927+00
1925	150	265	2026-06-16 12:48:25.932+00
1926	150	266	2026-06-16 12:48:25.937+00
1927	150	267	2026-06-16 12:48:25.944+00
1928	150	268	2026-06-16 12:48:25.951+00
1929	150	269	2026-06-16 12:48:25.958+00
1930	150	270	2026-06-16 12:48:25.964+00
1931	150	271	2026-06-16 12:48:25.967+00
1932	150	272	2026-06-16 12:48:25.971+00
1933	150	261	2026-06-16 12:48:25.975+00
1934	151	191	2026-06-16 12:48:25.984+00
1935	151	192	2026-06-16 12:48:25.988+00
1936	151	193	2026-06-16 12:48:25.993+00
1937	151	194	2026-06-16 12:48:25.999+00
1938	151	195	2026-06-16 12:48:26.006+00
1939	151	196	2026-06-16 12:48:26.013+00
1940	151	197	2026-06-16 12:48:26.02+00
1941	151	198	2026-06-16 12:48:26.026+00
1942	151	262	2026-06-16 12:48:26.029+00
1943	151	263	2026-06-16 12:48:26.034+00
1944	151	264	2026-06-16 12:48:26.038+00
1945	151	265	2026-06-16 12:48:26.042+00
1946	151	266	2026-06-16 12:48:26.045+00
1947	151	267	2026-06-16 12:48:26.049+00
1948	151	268	2026-06-16 12:48:26.054+00
1949	151	269	2026-06-16 12:48:26.059+00
1950	151	270	2026-06-16 12:48:26.065+00
1951	151	271	2026-06-16 12:48:26.072+00
1952	151	272	2026-06-16 12:48:26.078+00
1953	151	261	2026-06-16 12:48:26.085+00
1954	152	191	2026-06-16 12:48:26.093+00
1955	152	192	2026-06-16 12:48:26.097+00
1956	152	193	2026-06-16 12:48:26.101+00
1957	152	194	2026-06-16 12:48:26.105+00
1958	152	195	2026-06-16 12:48:26.109+00
1959	152	196	2026-06-16 12:48:26.114+00
1960	152	197	2026-06-16 12:48:26.118+00
1961	152	198	2026-06-16 12:48:26.125+00
1962	152	262	2026-06-16 12:48:26.131+00
1963	152	263	2026-06-16 12:48:26.138+00
1964	152	264	2026-06-16 12:48:26.144+00
1965	152	265	2026-06-16 12:48:26.15+00
1966	152	266	2026-06-16 12:48:26.155+00
1967	152	267	2026-06-16 12:48:26.16+00
1968	152	268	2026-06-16 12:48:26.167+00
1969	152	269	2026-06-16 12:48:26.172+00
1970	152	270	2026-06-16 12:48:26.177+00
1971	152	271	2026-06-16 12:48:26.184+00
1972	152	272	2026-06-16 12:48:26.19+00
1973	152	261	2026-06-16 12:48:26.198+00
1974	153	191	2026-06-16 12:48:26.213+00
1975	153	192	2026-06-16 12:48:26.218+00
1976	153	193	2026-06-16 12:48:26.223+00
1977	153	194	2026-06-16 12:48:26.227+00
1978	153	195	2026-06-16 12:48:26.231+00
1979	153	196	2026-06-16 12:48:26.236+00
1980	153	197	2026-06-16 12:48:26.241+00
1981	153	198	2026-06-16 12:48:26.247+00
1982	153	262	2026-06-16 12:48:26.253+00
1983	153	263	2026-06-16 12:48:26.26+00
1984	153	264	2026-06-16 12:48:26.267+00
1985	153	265	2026-06-16 12:48:26.274+00
1986	153	266	2026-06-16 12:48:26.281+00
1987	153	267	2026-06-16 12:48:26.285+00
1988	153	268	2026-06-16 12:48:26.289+00
1989	153	269	2026-06-16 12:48:26.293+00
1990	153	270	2026-06-16 12:48:26.297+00
1991	153	271	2026-06-16 12:48:26.302+00
1992	153	272	2026-06-16 12:48:26.306+00
1993	153	261	2026-06-16 12:48:26.31+00
1994	154	167	2026-06-16 12:48:26.324+00
1995	154	180	2026-06-16 12:48:26.331+00
1996	154	166	2026-06-16 12:48:26.337+00
1997	154	168	2026-06-16 12:48:26.343+00
1998	154	169	2026-06-16 12:48:26.348+00
1999	154	170	2026-06-16 12:48:26.354+00
2000	154	171	2026-06-16 12:48:26.358+00
2001	154	172	2026-06-16 12:48:26.364+00
2002	154	173	2026-06-16 12:48:26.368+00
2003	154	174	2026-06-16 12:48:26.373+00
2004	154	175	2026-06-16 12:48:26.378+00
2005	154	176	2026-06-16 12:48:26.386+00
2006	154	177	2026-06-16 12:48:26.392+00
2007	154	178	2026-06-16 12:48:26.4+00
2008	154	179	2026-06-16 12:48:26.406+00
2009	154	245	2026-06-16 12:48:26.409+00
2010	154	246	2026-06-16 12:48:26.413+00
2011	154	247	2026-06-16 12:48:26.418+00
2012	154	248	2026-06-16 12:48:26.422+00
2013	154	249	2026-06-16 12:48:26.426+00
2014	154	250	2026-06-16 12:48:26.43+00
2015	154	251	2026-06-16 12:48:26.435+00
2016	154	252	2026-06-16 12:48:26.44+00
2017	155	167	2026-06-16 12:48:26.455+00
2018	155	180	2026-06-16 12:48:26.464+00
2019	155	166	2026-06-16 12:48:26.472+00
2020	155	168	2026-06-16 12:48:26.478+00
2021	155	169	2026-06-16 12:48:26.484+00
2022	155	170	2026-06-16 12:48:26.487+00
2023	155	171	2026-06-16 12:48:26.495+00
2024	155	172	2026-06-16 12:48:26.498+00
2025	155	173	2026-06-16 12:48:26.502+00
2026	155	174	2026-06-16 12:48:26.508+00
2027	155	175	2026-06-16 12:48:26.514+00
2028	155	176	2026-06-16 12:48:26.522+00
2029	155	177	2026-06-16 12:48:26.528+00
2030	155	178	2026-06-16 12:48:26.534+00
2031	155	179	2026-06-16 12:48:26.539+00
2032	155	245	2026-06-16 12:48:26.544+00
2033	155	246	2026-06-16 12:48:26.549+00
2034	155	247	2026-06-16 12:48:26.554+00
2035	155	248	2026-06-16 12:48:26.558+00
2036	155	249	2026-06-16 12:48:26.563+00
2037	155	250	2026-06-16 12:48:26.567+00
2038	155	251	2026-06-16 12:48:26.574+00
2039	155	252	2026-06-16 12:48:26.58+00
2040	156	167	2026-06-16 12:48:26.593+00
2041	156	180	2026-06-16 12:48:26.597+00
2042	156	166	2026-06-16 12:48:26.602+00
2043	156	168	2026-06-16 12:48:26.606+00
2044	156	169	2026-06-16 12:48:26.61+00
2045	156	170	2026-06-16 12:48:26.615+00
2046	156	171	2026-06-16 12:48:26.619+00
2047	156	172	2026-06-16 12:48:26.624+00
2048	156	173	2026-06-16 12:48:26.631+00
2049	156	174	2026-06-16 12:48:26.637+00
2050	156	175	2026-06-16 12:48:26.644+00
2051	156	176	2026-06-16 12:48:26.651+00
2052	156	177	2026-06-16 12:48:26.656+00
2053	156	178	2026-06-16 12:48:26.66+00
2054	156	179	2026-06-16 12:48:26.666+00
2055	156	245	2026-06-16 12:48:26.671+00
2056	156	246	2026-06-16 12:48:26.677+00
2057	156	247	2026-06-16 12:48:26.681+00
2058	156	248	2026-06-16 12:48:26.686+00
2059	156	249	2026-06-16 12:48:26.69+00
2060	156	250	2026-06-16 12:48:26.699+00
2061	156	251	2026-06-16 12:48:26.713+00
2062	156	252	2026-06-16 12:48:26.729+00
2063	157	167	2026-06-16 12:48:26.753+00
2064	157	180	2026-06-16 12:48:26.757+00
2065	157	166	2026-06-16 12:48:26.762+00
2066	157	168	2026-06-16 12:48:26.766+00
2067	157	169	2026-06-16 12:48:26.77+00
2068	157	170	2026-06-16 12:48:26.774+00
2069	157	171	2026-06-16 12:48:26.778+00
2070	157	172	2026-06-16 12:48:26.783+00
2071	157	173	2026-06-16 12:48:26.79+00
2072	157	174	2026-06-16 12:48:26.796+00
2073	157	175	2026-06-16 12:48:26.803+00
2074	157	176	2026-06-16 12:48:26.809+00
2075	157	177	2026-06-16 12:48:26.814+00
2076	157	178	2026-06-16 12:48:26.818+00
2077	157	179	2026-06-16 12:48:26.822+00
2078	157	245	2026-06-16 12:48:26.827+00
2079	157	246	2026-06-16 12:48:26.833+00
2080	157	247	2026-06-16 12:48:26.837+00
2081	157	248	2026-06-16 12:48:26.841+00
2082	157	249	2026-06-16 12:48:26.847+00
2083	157	250	2026-06-16 12:48:26.854+00
2084	157	251	2026-06-16 12:48:26.861+00
2085	157	252	2026-06-16 12:48:26.868+00
2086	158	167	2026-06-16 12:48:26.879+00
2087	158	180	2026-06-16 12:48:26.885+00
2088	158	166	2026-06-16 12:48:26.889+00
2089	158	168	2026-06-16 12:48:26.895+00
2090	158	169	2026-06-16 12:48:26.9+00
2091	158	170	2026-06-16 12:48:26.905+00
2092	158	171	2026-06-16 12:48:26.91+00
2093	158	172	2026-06-16 12:48:26.919+00
2094	158	173	2026-06-16 12:48:26.926+00
2095	158	174	2026-06-16 12:48:26.933+00
2096	158	175	2026-06-16 12:48:26.94+00
2097	158	176	2026-06-16 12:48:26.943+00
2098	158	177	2026-06-16 12:48:26.947+00
2099	158	178	2026-06-16 12:48:26.951+00
2100	158	179	2026-06-16 12:48:26.955+00
2101	158	245	2026-06-16 12:48:26.959+00
2102	158	246	2026-06-16 12:48:26.964+00
2103	158	247	2026-06-16 12:48:26.968+00
2104	158	248	2026-06-16 12:48:26.973+00
2105	158	249	2026-06-16 12:48:26.979+00
2106	158	250	2026-06-16 12:48:26.986+00
2107	158	251	2026-06-16 12:48:26.992+00
2108	158	252	2026-06-16 12:48:26.998+00
2109	159	167	2026-06-16 12:48:27.006+00
2110	159	180	2026-06-16 12:48:27.009+00
2111	159	166	2026-06-16 12:48:27.014+00
2112	159	168	2026-06-16 12:48:27.018+00
2113	159	169	2026-06-16 12:48:27.022+00
2114	159	170	2026-06-16 12:48:27.026+00
2115	159	171	2026-06-16 12:48:27.029+00
2116	159	172	2026-06-16 12:48:27.035+00
2117	159	173	2026-06-16 12:48:27.042+00
2118	159	174	2026-06-16 12:48:27.047+00
2119	159	175	2026-06-16 12:48:27.054+00
2120	159	176	2026-06-16 12:48:27.058+00
2121	159	177	2026-06-16 12:48:27.063+00
2122	159	178	2026-06-16 12:48:27.068+00
2123	159	179	2026-06-16 12:48:27.073+00
2124	159	245	2026-06-16 12:48:27.08+00
2125	159	246	2026-06-16 12:48:27.086+00
2126	159	247	2026-06-16 12:48:27.091+00
2127	159	248	2026-06-16 12:48:27.097+00
2128	159	249	2026-06-16 12:48:27.101+00
2129	159	250	2026-06-16 12:48:27.104+00
2130	159	251	2026-06-16 12:48:27.107+00
2131	159	252	2026-06-16 12:48:27.111+00
2132	160	167	2026-06-16 12:48:27.12+00
2133	160	180	2026-06-16 12:48:27.125+00
2134	160	166	2026-06-16 12:48:27.132+00
2135	160	168	2026-06-16 12:48:27.139+00
2136	160	169	2026-06-16 12:48:27.146+00
2137	160	170	2026-06-16 12:48:27.152+00
2138	160	171	2026-06-16 12:48:27.156+00
2139	160	172	2026-06-16 12:48:27.159+00
2140	160	173	2026-06-16 12:48:27.164+00
2141	160	174	2026-06-16 12:48:27.169+00
2142	160	175	2026-06-16 12:48:27.173+00
2143	160	176	2026-06-16 12:48:27.177+00
2144	160	177	2026-06-16 12:48:27.182+00
2145	160	178	2026-06-16 12:48:27.186+00
2146	160	179	2026-06-16 12:48:27.192+00
2147	160	245	2026-06-16 12:48:27.199+00
2148	160	246	2026-06-16 12:48:27.205+00
2149	160	247	2026-06-16 12:48:27.212+00
2150	160	248	2026-06-16 12:48:27.215+00
2151	160	249	2026-06-16 12:48:27.22+00
2152	160	250	2026-06-16 12:48:27.224+00
2153	160	251	2026-06-16 12:48:27.227+00
2154	160	252	2026-06-16 12:48:27.231+00
2155	161	167	2026-06-16 12:48:27.241+00
2156	161	180	2026-06-16 12:48:27.246+00
2157	161	166	2026-06-16 12:48:27.253+00
2158	161	168	2026-06-16 12:48:27.259+00
2159	161	169	2026-06-16 12:48:27.265+00
2160	161	170	2026-06-16 12:48:27.271+00
2161	161	171	2026-06-16 12:48:27.274+00
2162	161	172	2026-06-16 12:48:27.277+00
2163	161	173	2026-06-16 12:48:27.281+00
2164	161	174	2026-06-16 12:48:27.286+00
2165	161	175	2026-06-16 12:48:27.29+00
2166	161	176	2026-06-16 12:48:27.294+00
2167	161	177	2026-06-16 12:48:27.299+00
2168	161	178	2026-06-16 12:48:27.304+00
2169	161	179	2026-06-16 12:48:27.311+00
2170	161	245	2026-06-16 12:48:27.318+00
2171	161	246	2026-06-16 12:48:27.324+00
2172	161	247	2026-06-16 12:48:27.331+00
2173	161	248	2026-06-16 12:48:27.335+00
2174	161	249	2026-06-16 12:48:27.337+00
2175	161	250	2026-06-16 12:48:27.341+00
2176	161	251	2026-06-16 12:48:27.345+00
2177	161	252	2026-06-16 12:48:27.348+00
2178	162	167	2026-06-16 12:48:27.359+00
2179	162	180	2026-06-16 12:48:27.366+00
2180	162	166	2026-06-16 12:48:27.373+00
2181	162	168	2026-06-16 12:48:27.381+00
2182	162	169	2026-06-16 12:48:27.388+00
2183	162	170	2026-06-16 12:48:27.395+00
2184	162	171	2026-06-16 12:48:27.4+00
2185	162	172	2026-06-16 12:48:27.405+00
2186	162	173	2026-06-16 12:48:27.409+00
2187	162	174	2026-06-16 12:48:27.413+00
2188	162	175	2026-06-16 12:48:27.418+00
2189	162	176	2026-06-16 12:48:27.423+00
2190	162	177	2026-06-16 12:48:27.428+00
2191	162	178	2026-06-16 12:48:27.433+00
2192	162	179	2026-06-16 12:48:27.44+00
2193	162	245	2026-06-16 12:48:27.446+00
2194	162	246	2026-06-16 12:48:27.453+00
2195	162	247	2026-06-16 12:48:27.459+00
2196	162	248	2026-06-16 12:48:27.463+00
2197	162	249	2026-06-16 12:48:27.467+00
2198	162	250	2026-06-16 12:48:27.471+00
2199	162	251	2026-06-16 12:48:27.475+00
2200	162	252	2026-06-16 12:48:27.479+00
2201	163	167	2026-06-16 12:48:27.49+00
2202	163	180	2026-06-16 12:48:27.497+00
2203	163	166	2026-06-16 12:48:27.505+00
2204	163	168	2026-06-16 12:48:27.511+00
2205	163	169	2026-06-16 12:48:27.518+00
2206	163	170	2026-06-16 12:48:27.522+00
2207	163	171	2026-06-16 12:48:27.524+00
2208	163	172	2026-06-16 12:48:27.527+00
2209	163	173	2026-06-16 12:48:27.531+00
2210	163	174	2026-06-16 12:48:27.537+00
2211	163	175	2026-06-16 12:48:27.542+00
2212	163	176	2026-06-16 12:48:27.548+00
2213	163	177	2026-06-16 12:48:27.553+00
2214	163	178	2026-06-16 12:48:27.56+00
2215	163	179	2026-06-16 12:48:27.567+00
2216	163	245	2026-06-16 12:48:27.574+00
2217	163	246	2026-06-16 12:48:27.581+00
2218	163	247	2026-06-16 12:48:27.585+00
2219	163	248	2026-06-16 12:48:27.588+00
2220	163	249	2026-06-16 12:48:27.593+00
2221	163	250	2026-06-16 12:48:27.597+00
2222	163	251	2026-06-16 12:48:27.601+00
2223	163	252	2026-06-16 12:48:27.605+00
2224	164	181	2026-06-16 12:48:27.614+00
2225	164	183	2026-06-16 12:48:27.621+00
2226	164	184	2026-06-16 12:48:27.629+00
2227	164	185	2026-06-16 12:48:27.635+00
2228	164	186	2026-06-16 12:48:27.641+00
2229	164	187	2026-06-16 12:48:27.645+00
2230	164	188	2026-06-16 12:48:27.65+00
2231	164	189	2026-06-16 12:48:27.654+00
2232	164	182	2026-06-16 12:48:27.659+00
2233	164	253	2026-06-16 12:48:27.664+00
2234	164	254	2026-06-16 12:48:27.67+00
2235	164	255	2026-06-16 12:48:27.674+00
2236	164	256	2026-06-16 12:48:27.679+00
2237	164	257	2026-06-16 12:48:27.685+00
2238	164	258	2026-06-16 12:48:27.691+00
2239	164	259	2026-06-16 12:48:27.699+00
2240	164	260	2026-06-16 12:48:27.706+00
2241	165	181	2026-06-16 12:48:27.713+00
2242	165	183	2026-06-16 12:48:27.718+00
2243	165	184	2026-06-16 12:48:27.722+00
2244	165	185	2026-06-16 12:48:27.725+00
2245	165	186	2026-06-16 12:48:27.728+00
2246	165	187	2026-06-16 12:48:27.734+00
2247	165	188	2026-06-16 12:48:27.74+00
2248	165	189	2026-06-16 12:48:27.747+00
2249	165	182	2026-06-16 12:48:27.754+00
2250	165	253	2026-06-16 12:48:27.76+00
2251	165	254	2026-06-16 12:48:27.768+00
2252	165	255	2026-06-16 12:48:27.772+00
2253	165	256	2026-06-16 12:48:27.776+00
2254	165	257	2026-06-16 12:48:27.779+00
2255	165	258	2026-06-16 12:48:27.784+00
2256	165	259	2026-06-16 12:48:27.788+00
2257	165	260	2026-06-16 12:48:27.791+00
2258	166	181	2026-06-16 12:48:27.802+00
2259	166	183	2026-06-16 12:48:27.809+00
2260	166	184	2026-06-16 12:48:27.815+00
2261	166	185	2026-06-16 12:48:27.821+00
2262	166	186	2026-06-16 12:48:27.824+00
2263	166	187	2026-06-16 12:48:27.827+00
2264	166	188	2026-06-16 12:48:27.831+00
2265	166	189	2026-06-16 12:48:27.835+00
2266	166	182	2026-06-16 12:48:27.839+00
2267	166	253	2026-06-16 12:48:27.844+00
2268	166	254	2026-06-16 12:48:27.848+00
2269	166	255	2026-06-16 12:48:27.853+00
2270	166	256	2026-06-16 12:48:27.859+00
2271	166	257	2026-06-16 12:48:27.867+00
2272	166	258	2026-06-16 12:48:27.873+00
2273	166	259	2026-06-16 12:48:27.88+00
2274	166	260	2026-06-16 12:48:27.884+00
2275	167	181	2026-06-16 12:48:27.891+00
2276	167	183	2026-06-16 12:48:27.896+00
2277	167	184	2026-06-16 12:48:27.901+00
2278	167	185	2026-06-16 12:48:27.905+00
2279	167	186	2026-06-16 12:48:27.909+00
2280	167	187	2026-06-16 12:48:27.913+00
2281	167	188	2026-06-16 12:48:27.921+00
2282	167	189	2026-06-16 12:48:27.928+00
2283	167	182	2026-06-16 12:48:27.935+00
2284	167	253	2026-06-16 12:48:27.94+00
2285	167	254	2026-06-16 12:48:27.943+00
2286	167	255	2026-06-16 12:48:27.947+00
2287	167	256	2026-06-16 12:48:27.952+00
2288	167	257	2026-06-16 12:48:27.956+00
2289	167	258	2026-06-16 12:48:27.96+00
2290	167	259	2026-06-16 12:48:27.965+00
2291	167	260	2026-06-16 12:48:27.97+00
2292	168	181	2026-06-16 12:48:27.982+00
2293	168	183	2026-06-16 12:48:27.99+00
2294	168	184	2026-06-16 12:48:27.996+00
2295	168	185	2026-06-16 12:48:28.003+00
2296	168	186	2026-06-16 12:48:28.006+00
2297	168	187	2026-06-16 12:48:28.009+00
2298	168	188	2026-06-16 12:48:28.014+00
2299	168	189	2026-06-16 12:48:28.019+00
2300	168	182	2026-06-16 12:48:28.023+00
2301	168	253	2026-06-16 12:48:28.026+00
2302	168	254	2026-06-16 12:48:28.03+00
2303	168	255	2026-06-16 12:48:28.035+00
2304	168	256	2026-06-16 12:48:28.042+00
2305	168	257	2026-06-16 12:48:28.048+00
2306	168	258	2026-06-16 12:48:28.054+00
2307	168	259	2026-06-16 12:48:28.057+00
2308	168	260	2026-06-16 12:48:28.061+00
2309	169	181	2026-06-16 12:48:28.069+00
2310	169	183	2026-06-16 12:48:28.074+00
2311	169	184	2026-06-16 12:48:28.078+00
2312	169	185	2026-06-16 12:48:28.083+00
2313	169	186	2026-06-16 12:48:28.087+00
2314	169	187	2026-06-16 12:48:28.094+00
2315	169	188	2026-06-16 12:48:28.101+00
2316	169	189	2026-06-16 12:48:28.107+00
2317	169	182	2026-06-16 12:48:28.114+00
2318	169	253	2026-06-16 12:48:28.117+00
2319	169	254	2026-06-16 12:48:28.121+00
2320	169	255	2026-06-16 12:48:28.125+00
2321	169	256	2026-06-16 12:48:28.131+00
2322	169	257	2026-06-16 12:48:28.135+00
2323	169	258	2026-06-16 12:48:28.139+00
2324	169	259	2026-06-16 12:48:28.144+00
2325	169	260	2026-06-16 12:48:28.149+00
2326	170	181	2026-06-16 12:48:28.162+00
2327	170	183	2026-06-16 12:48:28.169+00
2328	170	184	2026-06-16 12:48:28.173+00
2329	170	185	2026-06-16 12:48:28.176+00
2330	170	186	2026-06-16 12:48:28.18+00
2331	170	187	2026-06-16 12:48:28.184+00
2332	170	188	2026-06-16 12:48:28.188+00
2333	170	189	2026-06-16 12:48:28.192+00
2334	170	182	2026-06-16 12:48:28.197+00
2335	170	253	2026-06-16 12:48:28.203+00
2336	170	254	2026-06-16 12:48:28.21+00
2337	170	255	2026-06-16 12:48:28.217+00
2338	170	256	2026-06-16 12:48:28.224+00
2339	170	257	2026-06-16 12:48:28.229+00
2340	170	258	2026-06-16 12:48:28.234+00
2341	170	259	2026-06-16 12:48:28.237+00
2342	170	260	2026-06-16 12:48:28.241+00
2343	171	181	2026-06-16 12:48:28.251+00
2344	171	183	2026-06-16 12:48:28.255+00
2345	171	184	2026-06-16 12:48:28.259+00
2346	171	185	2026-06-16 12:48:28.264+00
2347	171	186	2026-06-16 12:48:28.271+00
2348	171	187	2026-06-16 12:48:28.277+00
2349	171	188	2026-06-16 12:48:28.284+00
2350	171	189	2026-06-16 12:48:28.29+00
2351	171	182	2026-06-16 12:48:28.293+00
2352	171	253	2026-06-16 12:48:28.297+00
2353	171	254	2026-06-16 12:48:28.301+00
2354	171	255	2026-06-16 12:48:28.305+00
2355	171	256	2026-06-16 12:48:28.309+00
2356	171	257	2026-06-16 12:48:28.314+00
2357	171	258	2026-06-16 12:48:28.318+00
2358	171	259	2026-06-16 12:48:28.323+00
2359	171	260	2026-06-16 12:48:28.33+00
2360	172	181	2026-06-16 12:48:28.344+00
2361	172	183	2026-06-16 12:48:28.351+00
2362	172	184	2026-06-16 12:48:28.354+00
2363	172	185	2026-06-16 12:48:28.358+00
2364	172	186	2026-06-16 12:48:28.363+00
2365	172	187	2026-06-16 12:48:28.367+00
2366	172	188	2026-06-16 12:48:28.371+00
2367	172	189	2026-06-16 12:48:28.375+00
2368	172	182	2026-06-16 12:48:28.379+00
2369	172	253	2026-06-16 12:48:28.385+00
2370	172	254	2026-06-16 12:48:28.391+00
2371	172	255	2026-06-16 12:48:28.399+00
2372	172	256	2026-06-16 12:48:28.405+00
2373	172	257	2026-06-16 12:48:28.412+00
2374	172	258	2026-06-16 12:48:28.416+00
2375	172	259	2026-06-16 12:48:28.421+00
2376	172	260	2026-06-16 12:48:28.425+00
2377	173	181	2026-06-16 12:48:28.435+00
2378	173	183	2026-06-16 12:48:28.441+00
2379	173	184	2026-06-16 12:48:28.445+00
2380	173	185	2026-06-16 12:48:28.451+00
2381	173	186	2026-06-16 12:48:28.458+00
2382	173	187	2026-06-16 12:48:28.465+00
2383	173	188	2026-06-16 12:48:28.471+00
2384	173	189	2026-06-16 12:48:28.477+00
2385	173	182	2026-06-16 12:48:28.481+00
2386	173	253	2026-06-16 12:48:28.486+00
2387	173	254	2026-06-16 12:48:28.49+00
2388	173	255	2026-06-16 12:48:28.494+00
2389	173	256	2026-06-16 12:48:28.5+00
2390	173	257	2026-06-16 12:48:28.505+00
2391	173	258	2026-06-16 12:48:28.51+00
2392	173	259	2026-06-16 12:48:28.518+00
2393	173	260	2026-06-16 12:48:28.524+00
2394	210	320	2026-06-16 12:48:28.542+00
2395	210	321	2026-06-16 12:48:28.549+00
2396	210	322	2026-06-16 12:48:28.554+00
2397	210	323	2026-06-16 12:48:28.559+00
2398	210	324	2026-06-16 12:48:28.564+00
2399	210	325	2026-06-16 12:48:28.569+00
2400	210	326	2026-06-16 12:48:28.573+00
2401	210	327	2026-06-16 12:48:28.577+00
2402	210	328	2026-06-16 12:48:28.583+00
2403	210	330	2026-06-16 12:48:28.59+00
2404	210	331	2026-06-16 12:48:28.596+00
2405	210	332	2026-06-16 12:48:28.603+00
2406	210	333	2026-06-16 12:48:28.609+00
2407	210	334	2026-06-16 12:48:28.613+00
2408	210	335	2026-06-16 12:48:28.617+00
2409	210	329	2026-06-16 12:48:28.621+00
2410	10	167	2026-06-16 12:48:28.635+00
2411	10	180	2026-06-16 12:48:28.647+00
2412	10	166	2026-06-16 12:48:28.656+00
2413	10	168	2026-06-16 12:48:28.664+00
2414	10	169	2026-06-16 12:48:28.674+00
2415	10	170	2026-06-16 12:48:28.683+00
2416	10	171	2026-06-16 12:48:28.693+00
2417	10	172	2026-06-16 12:48:28.703+00
2418	10	173	2026-06-16 12:48:28.709+00
2419	10	174	2026-06-16 12:48:28.714+00
2420	10	175	2026-06-16 12:48:28.722+00
2421	10	176	2026-06-16 12:48:28.729+00
2422	10	177	2026-06-16 12:48:28.736+00
2423	10	178	2026-06-16 12:48:28.746+00
2424	10	179	2026-06-16 12:48:28.758+00
2425	10	245	2026-06-16 12:48:28.772+00
2426	10	246	2026-06-16 12:48:28.791+00
2427	10	247	2026-06-16 12:48:28.799+00
2428	10	248	2026-06-16 12:48:28.809+00
2429	10	249	2026-06-16 12:48:28.818+00
2430	10	250	2026-06-16 12:48:28.828+00
2431	10	251	2026-06-16 12:48:28.834+00
2432	10	252	2026-06-16 12:48:28.84+00
2433	234	181	2026-06-16 12:48:28.855+00
2434	234	183	2026-06-16 12:48:28.864+00
2435	234	184	2026-06-16 12:48:28.872+00
2436	234	185	2026-06-16 12:48:28.879+00
2437	234	186	2026-06-16 12:48:28.89+00
2438	234	187	2026-06-16 12:48:28.899+00
2439	234	188	2026-06-16 12:48:28.907+00
2440	234	189	2026-06-16 12:48:28.915+00
2441	234	182	2026-06-16 12:48:28.921+00
2442	234	253	2026-06-16 12:48:28.927+00
2443	234	254	2026-06-16 12:48:28.934+00
2444	234	255	2026-06-16 12:48:28.939+00
2445	234	256	2026-06-16 12:48:28.944+00
2446	234	257	2026-06-16 12:48:28.952+00
2447	234	258	2026-06-16 12:48:28.961+00
2448	234	259	2026-06-16 12:48:28.968+00
2449	234	260	2026-06-16 12:48:28.979+00
2450	41	356	2026-06-16 12:50:45.279+00
2451	41	357	2026-06-16 12:50:45.29+00
2452	41	358	2026-06-16 12:50:45.297+00
2453	41	359	2026-06-16 12:50:45.305+00
2454	41	360	2026-06-16 12:50:45.309+00
2455	41	361	2026-06-16 12:50:45.314+00
2456	41	362	2026-06-16 12:50:45.319+00
2457	41	363	2026-06-16 12:50:45.323+00
2458	41	364	2026-06-16 12:50:45.328+00
2459	41	365	2026-06-16 12:50:45.333+00
2460	93	356	2026-06-16 12:50:46.963+00
2461	93	357	2026-06-16 12:50:46.968+00
2462	93	358	2026-06-16 12:50:46.973+00
2463	93	359	2026-06-16 12:50:46.977+00
2464	93	360	2026-06-16 12:50:46.983+00
2465	93	361	2026-06-16 12:50:46.988+00
2466	93	362	2026-06-16 12:50:46.992+00
2467	93	363	2026-06-16 12:50:47.001+00
2468	93	364	2026-06-16 12:50:47.008+00
2469	93	365	2026-06-16 12:50:47.016+00
2470	94	356	2026-06-16 12:50:47.031+00
2471	94	357	2026-06-16 12:50:47.035+00
2472	94	358	2026-06-16 12:50:47.04+00
2473	94	359	2026-06-16 12:50:47.043+00
2474	94	360	2026-06-16 12:50:47.048+00
2475	94	361	2026-06-16 12:50:47.053+00
2476	94	362	2026-06-16 12:50:47.058+00
2477	94	363	2026-06-16 12:50:47.063+00
2478	94	364	2026-06-16 12:50:47.072+00
2479	94	365	2026-06-16 12:50:47.079+00
2480	95	356	2026-06-16 12:50:47.095+00
2481	95	357	2026-06-16 12:50:47.1+00
2482	95	358	2026-06-16 12:50:47.104+00
2483	95	359	2026-06-16 12:50:47.108+00
2484	95	360	2026-06-16 12:50:47.113+00
2485	95	361	2026-06-16 12:50:47.118+00
2486	95	362	2026-06-16 12:50:47.123+00
2487	95	363	2026-06-16 12:50:47.128+00
2488	95	364	2026-06-16 12:50:47.135+00
2489	95	365	2026-06-16 12:50:47.142+00
2490	96	356	2026-06-16 12:50:47.16+00
2491	96	357	2026-06-16 12:50:47.163+00
2492	96	358	2026-06-16 12:50:47.167+00
2493	96	359	2026-06-16 12:50:47.172+00
2494	96	360	2026-06-16 12:50:47.176+00
2495	96	361	2026-06-16 12:50:47.181+00
2496	96	362	2026-06-16 12:50:47.187+00
2497	96	363	2026-06-16 12:50:47.191+00
2498	96	364	2026-06-16 12:50:47.196+00
2499	96	365	2026-06-16 12:50:47.204+00
2500	97	356	2026-06-16 12:50:47.228+00
2501	97	357	2026-06-16 12:50:47.232+00
2502	97	358	2026-06-16 12:50:47.237+00
2503	97	359	2026-06-16 12:50:47.262+00
2504	97	360	2026-06-16 12:50:47.274+00
2505	97	361	2026-06-16 12:50:47.292+00
2506	97	362	2026-06-16 12:50:47.298+00
2507	97	363	2026-06-16 12:50:47.31+00
2508	97	364	2026-06-16 12:50:47.321+00
2509	97	365	2026-06-16 12:50:47.335+00
2510	98	356	2026-06-16 12:50:47.357+00
2511	98	357	2026-06-16 12:50:47.363+00
2512	98	358	2026-06-16 12:50:47.374+00
2513	98	359	2026-06-16 12:50:47.385+00
2514	98	360	2026-06-16 12:50:47.392+00
2515	98	361	2026-06-16 12:50:47.399+00
2516	98	362	2026-06-16 12:50:47.407+00
2517	98	363	2026-06-16 12:50:47.413+00
2518	98	364	2026-06-16 12:50:47.422+00
2519	98	365	2026-06-16 12:50:47.431+00
2520	99	356	2026-06-16 12:50:47.457+00
2521	99	357	2026-06-16 12:50:47.47+00
2522	99	358	2026-06-16 12:50:47.476+00
2523	99	359	2026-06-16 12:50:47.481+00
2524	99	360	2026-06-16 12:50:47.49+00
2525	99	361	2026-06-16 12:50:47.497+00
2526	99	362	2026-06-16 12:50:47.503+00
2527	99	363	2026-06-16 12:50:47.511+00
2528	99	364	2026-06-16 12:50:47.518+00
2529	99	365	2026-06-16 12:50:47.527+00
2530	100	356	2026-06-16 12:50:47.556+00
2531	100	357	2026-06-16 12:50:47.569+00
2532	100	358	2026-06-16 12:50:47.575+00
2533	100	359	2026-06-16 12:50:47.581+00
2534	100	360	2026-06-16 12:50:47.589+00
2535	100	361	2026-06-16 12:50:47.596+00
2536	100	362	2026-06-16 12:50:47.605+00
2537	100	363	2026-06-16 12:50:47.611+00
2538	100	364	2026-06-16 12:50:47.619+00
2539	100	365	2026-06-16 12:50:47.625+00
2540	101	356	2026-06-16 12:50:47.655+00
2541	101	357	2026-06-16 12:50:47.664+00
2542	101	358	2026-06-16 12:50:47.673+00
2543	101	359	2026-06-16 12:50:47.678+00
2544	101	360	2026-06-16 12:50:47.683+00
2545	101	361	2026-06-16 12:50:47.687+00
2546	101	362	2026-06-16 12:50:47.691+00
2547	101	363	2026-06-16 12:50:47.704+00
2548	101	364	2026-06-16 12:50:47.71+00
2549	101	365	2026-06-16 12:50:47.717+00
2550	102	356	2026-06-16 12:50:47.741+00
2551	102	357	2026-06-16 12:50:47.751+00
2552	102	358	2026-06-16 12:50:47.759+00
2553	102	359	2026-06-16 12:50:47.77+00
2554	102	360	2026-06-16 12:50:47.776+00
2555	102	361	2026-06-16 12:50:47.783+00
2556	102	362	2026-06-16 12:50:47.791+00
2557	102	363	2026-06-16 12:50:47.796+00
2558	102	364	2026-06-16 12:50:47.8+00
2559	102	365	2026-06-16 12:50:47.804+00
2560	174	356	2026-06-16 12:50:49.49+00
2561	174	357	2026-06-16 12:50:49.494+00
2562	174	358	2026-06-16 12:50:49.501+00
2563	174	359	2026-06-16 12:50:49.506+00
2564	174	360	2026-06-16 12:50:49.511+00
2565	174	361	2026-06-16 12:50:49.52+00
2566	174	362	2026-06-16 12:50:49.528+00
2567	174	363	2026-06-16 12:50:49.536+00
2568	174	364	2026-06-16 12:50:49.543+00
2569	174	365	2026-06-16 12:50:49.548+00
2570	175	356	2026-06-16 12:50:49.56+00
2571	175	357	2026-06-16 12:50:49.566+00
2572	175	358	2026-06-16 12:50:49.572+00
2573	175	359	2026-06-16 12:50:49.577+00
2574	175	360	2026-06-16 12:50:49.583+00
2575	175	361	2026-06-16 12:50:49.592+00
2576	175	362	2026-06-16 12:50:49.6+00
2577	175	363	2026-06-16 12:50:49.607+00
2578	175	364	2026-06-16 12:50:49.614+00
2579	175	365	2026-06-16 12:50:49.621+00
2580	176	356	2026-06-16 12:50:49.638+00
2581	176	357	2026-06-16 12:50:49.644+00
2582	176	358	2026-06-16 12:50:49.651+00
2583	176	359	2026-06-16 12:50:49.659+00
2584	176	360	2026-06-16 12:50:49.666+00
2585	176	361	2026-06-16 12:50:49.672+00
2586	176	362	2026-06-16 12:50:49.68+00
2587	176	363	2026-06-16 12:50:49.688+00
2588	176	364	2026-06-16 12:50:49.696+00
2589	176	365	2026-06-16 12:50:49.703+00
2590	177	356	2026-06-16 12:50:49.718+00
2591	177	357	2026-06-16 12:50:49.724+00
2592	177	358	2026-06-16 12:50:49.731+00
2593	177	359	2026-06-16 12:50:49.742+00
2594	177	360	2026-06-16 12:50:49.75+00
2595	177	361	2026-06-16 12:50:49.756+00
2596	177	362	2026-06-16 12:50:49.761+00
2597	177	363	2026-06-16 12:50:49.77+00
2598	177	364	2026-06-16 12:50:49.777+00
2599	177	365	2026-06-16 12:50:49.786+00
2600	178	356	2026-06-16 12:50:49.803+00
2601	178	357	2026-06-16 12:50:49.808+00
2602	178	358	2026-06-16 12:50:49.813+00
2603	178	359	2026-06-16 12:50:49.818+00
2604	178	360	2026-06-16 12:50:49.823+00
2605	178	361	2026-06-16 12:50:49.833+00
2606	178	362	2026-06-16 12:50:49.843+00
2607	178	363	2026-06-16 12:50:49.852+00
2608	178	364	2026-06-16 12:50:49.868+00
2609	178	365	2026-06-16 12:50:49.879+00
2610	179	356	2026-06-16 12:50:49.899+00
2611	179	357	2026-06-16 12:50:49.904+00
2612	179	358	2026-06-16 12:50:49.909+00
2613	179	359	2026-06-16 12:50:49.914+00
2614	179	360	2026-06-16 12:50:49.919+00
2615	179	361	2026-06-16 12:50:49.924+00
2616	179	362	2026-06-16 12:50:49.929+00
2617	179	363	2026-06-16 12:50:49.934+00
2618	179	364	2026-06-16 12:50:49.939+00
2619	179	365	2026-06-16 12:50:49.947+00
2620	180	356	2026-06-16 12:50:49.966+00
2621	180	357	2026-06-16 12:50:49.974+00
2622	180	358	2026-06-16 12:50:49.978+00
2623	180	359	2026-06-16 12:50:49.984+00
2624	180	360	2026-06-16 12:50:49.988+00
2625	180	361	2026-06-16 12:50:49.993+00
2626	180	362	2026-06-16 12:50:49.999+00
2627	180	363	2026-06-16 12:50:50.004+00
2628	180	364	2026-06-16 12:50:50.009+00
2629	180	365	2026-06-16 12:50:50.017+00
2630	181	356	2026-06-16 12:50:50.035+00
2631	181	357	2026-06-16 12:50:50.043+00
2632	181	358	2026-06-16 12:50:50.05+00
2633	181	359	2026-06-16 12:50:50.055+00
2634	181	360	2026-06-16 12:50:50.059+00
2635	181	361	2026-06-16 12:50:50.063+00
2636	181	362	2026-06-16 12:50:50.068+00
2637	181	363	2026-06-16 12:50:50.073+00
2638	181	364	2026-06-16 12:50:50.079+00
2639	181	365	2026-06-16 12:50:50.084+00
2640	182	356	2026-06-16 12:50:50.102+00
2641	182	357	2026-06-16 12:50:50.109+00
2642	182	358	2026-06-16 12:50:50.116+00
2643	182	359	2026-06-16 12:50:50.12+00
2644	182	360	2026-06-16 12:50:50.124+00
2645	182	361	2026-06-16 12:50:50.128+00
2646	182	362	2026-06-16 12:50:50.134+00
2647	182	363	2026-06-16 12:50:50.139+00
2648	182	364	2026-06-16 12:50:50.143+00
2649	182	365	2026-06-16 12:50:50.148+00
2650	183	356	2026-06-16 12:50:50.174+00
2651	183	357	2026-06-16 12:50:50.184+00
2652	183	358	2026-06-16 12:50:50.191+00
2653	183	359	2026-06-16 12:50:50.198+00
2654	183	360	2026-06-16 12:50:50.202+00
2655	183	361	2026-06-16 12:50:50.207+00
2656	183	362	2026-06-16 12:50:50.211+00
2657	183	363	2026-06-16 12:50:50.214+00
2658	183	364	2026-06-16 12:50:50.219+00
2659	183	365	2026-06-16 12:50:50.224+00
2660	224	366	2026-06-16 12:50:50.284+00
2661	224	367	2026-06-16 12:50:50.289+00
2662	224	368	2026-06-16 12:50:50.293+00
2663	224	369	2026-06-16 12:50:50.298+00
2664	224	370	2026-06-16 12:50:50.303+00
2665	224	371	2026-06-16 12:50:50.309+00
2666	224	372	2026-06-16 12:50:50.317+00
2667	225	366	2026-06-16 12:50:50.333+00
2668	225	367	2026-06-16 12:50:50.338+00
2669	225	368	2026-06-16 12:50:50.343+00
2670	225	369	2026-06-16 12:50:50.347+00
2671	225	370	2026-06-16 12:50:50.352+00
2672	225	371	2026-06-16 12:50:50.358+00
2673	225	372	2026-06-16 12:50:50.363+00
2674	226	366	2026-06-16 12:50:50.378+00
2675	226	367	2026-06-16 12:50:50.386+00
2676	226	368	2026-06-16 12:50:50.393+00
2677	226	369	2026-06-16 12:50:50.4+00
2678	226	370	2026-06-16 12:50:50.404+00
2679	226	371	2026-06-16 12:50:50.409+00
2680	226	372	2026-06-16 12:50:50.413+00
2681	227	366	2026-06-16 12:50:50.425+00
2682	227	367	2026-06-16 12:50:50.43+00
2683	227	368	2026-06-16 12:50:50.436+00
2684	227	369	2026-06-16 12:50:50.441+00
2685	227	370	2026-06-16 12:50:50.447+00
2686	227	371	2026-06-16 12:50:50.454+00
2687	227	372	2026-06-16 12:50:50.462+00
2688	228	366	2026-06-16 12:50:50.475+00
2689	228	367	2026-06-16 12:50:50.479+00
2690	228	368	2026-06-16 12:50:50.485+00
2691	228	369	2026-06-16 12:50:50.489+00
2692	228	370	2026-06-16 12:50:50.492+00
2693	228	371	2026-06-16 12:50:50.498+00
2694	228	372	2026-06-16 12:50:50.503+00
2695	229	366	2026-06-16 12:50:50.52+00
2696	229	367	2026-06-16 12:50:50.527+00
2697	229	368	2026-06-16 12:50:50.534+00
2698	229	369	2026-06-16 12:50:50.54+00
2699	229	370	2026-06-16 12:50:50.545+00
2700	229	371	2026-06-16 12:50:50.55+00
2701	229	372	2026-06-16 12:50:50.554+00
2702	230	366	2026-06-16 12:50:50.567+00
2703	230	367	2026-06-16 12:50:50.572+00
2704	230	368	2026-06-16 12:50:50.577+00
2705	230	369	2026-06-16 12:50:50.582+00
2706	230	370	2026-06-16 12:50:50.59+00
2707	230	371	2026-06-16 12:50:50.597+00
2708	230	372	2026-06-16 12:50:50.603+00
2709	231	366	2026-06-16 12:50:50.618+00
2710	231	367	2026-06-16 12:50:50.622+00
2711	231	368	2026-06-16 12:50:50.626+00
2712	231	369	2026-06-16 12:50:50.631+00
2713	231	370	2026-06-16 12:50:50.636+00
2714	231	371	2026-06-16 12:50:50.641+00
2715	231	372	2026-06-16 12:50:50.645+00
2716	232	366	2026-06-16 12:50:50.663+00
2717	232	367	2026-06-16 12:50:50.671+00
2718	232	368	2026-06-16 12:50:50.678+00
2719	232	369	2026-06-16 12:50:50.681+00
2720	232	370	2026-06-16 12:50:50.686+00
2721	232	371	2026-06-16 12:50:50.69+00
2722	232	372	2026-06-16 12:50:50.693+00
2723	233	366	2026-06-16 12:50:50.707+00
2724	233	367	2026-06-16 12:50:50.712+00
2725	233	368	2026-06-16 12:50:50.718+00
2726	233	369	2026-06-16 12:50:50.725+00
2727	233	370	2026-06-16 12:50:50.733+00
2728	233	371	2026-06-16 12:50:50.74+00
2729	233	372	2026-06-16 12:50:50.746+00
2730	9	366	2026-06-16 12:50:50.76+00
2731	9	367	2026-06-16 12:50:50.764+00
2732	9	368	2026-06-16 12:50:50.769+00
2733	9	369	2026-06-16 12:50:50.774+00
2734	9	370	2026-06-16 12:50:50.779+00
2735	9	371	2026-06-16 12:50:50.785+00
2736	9	372	2026-06-16 12:50:50.789+00
2737	10	373	2026-06-16 12:50:50.926+00
2738	10	374	2026-06-16 12:50:50.93+00
2739	10	375	2026-06-16 12:50:50.935+00
2740	10	376	2026-06-16 12:50:50.939+00
2741	10	377	2026-06-16 12:50:50.943+00
2742	10	378	2026-06-16 12:50:50.947+00
2743	10	379	2026-06-16 12:50:50.952+00
2744	10	380	2026-06-16 12:50:50.958+00
2745	10	381	2026-06-16 12:50:50.965+00
2746	10	382	2026-06-16 12:50:50.972+00
2747	10	383	2026-06-16 12:50:50.978+00
2748	10	384	2026-06-16 12:50:50.985+00
2749	10	385	2026-06-16 12:50:50.989+00
2750	10	386	2026-06-16 12:50:50.993+00
\.


--
-- Data for Name: intento_login; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.intento_login (intento_id, usuario_id, nombre_usuario_intentado, exitoso, direccion_ip, user_agent, creado_en) FROM stdin;
1	\N	elizabeth.admin	f	172.18.80.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-12 06:05:24.332+00
2	\N	elizabeth.admin	f	172.18.80.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-12 06:08:01.35+00
3	\N	elizabeth.admin	f	172.18.80.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-12 06:08:14.793+00
4	\N	elizabeth.admin	f	172.18.80.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-12 06:08:27.813+00
5	\N	elizabeth.admin	f	172.18.80.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-12 06:08:50.053+00
6	\N	elizabeth.admin	f	172.18.80.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-12 06:09:51.529+00
7	\N	elizabeth.admin	f	172.18.80.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-12 06:10:09.142+00
8	\N	elizabeth.admin	f	172.18.80.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-12 06:10:20.043+00
9	\N	elizabeth.admin	f	172.18.80.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-12 06:11:56.632+00
10	\N	elizabeth.admin	f	172.18.80.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-12 06:13:16.125+00
11	\N	elizabeth.admin	f	172.18.80.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-12 06:15:00.099+00
12	\N	elizabeth.admin	f	172.18.80.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-12 06:15:56.164+00
13	\N	elizabeth.admin	f	172.18.80.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-12 06:16:10.795+00
14	\N	elizabeth.admin	f	172.18.80.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-12 06:18:56.092+00
15	\N	elizabeth.admin	f	172.18.80.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-12 06:26:26.454+00
16	\N	maria.directora	f	172.18.80.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-12 06:26:49.179+00
17	\N	elizabeth.admin	f	172.18.80.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-12 06:27:46.914+00
18	1	elizabeth.mendoza	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-14 20:29:20.369+00
19	\N	luis.mendoza	f	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-15 04:13:02.185+00
20	\N	Luis.Mendoza	f	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-15 04:13:45.911+00
21	7	maria.directora	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-15 04:14:24.668+00
22	7	maria.directora	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-15 04:14:39.21+00
23	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-15 04:15:09.883+00
24	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-15 05:45:28.187+00
25	7	maria.directora	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-15 08:35:04.421+00
26	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-15 08:35:29.388+00
27	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-15 09:33:12.934+00
28	6	elizabeth.admin	f	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-15 09:35:03.556+00
29	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-15 09:35:10.656+00
30	11	harry.adm	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-15 09:35:53.46+00
31	7	maria.directora	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-15 19:06:28.008+00
32	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-15 19:06:40.275+00
33	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-15 19:46:48.868+00
34	\N	admin	f	127.0.0.1	Mozilla/5.0 (Windows NT; Windows NT 10.0; es-MX) WindowsPowerShell/5.1.26100.8457	2026-06-15 20:27:37.783+00
35	3	laura.rios	t	127.0.0.1	Mozilla/5.0 (Windows NT; Windows NT 10.0; es-MX) WindowsPowerShell/5.1.26100.8457	2026-06-15 20:28:05.666+00
36	3	laura.rios	t	127.0.0.1	Mozilla/5.0 (Windows NT; Windows NT 10.0; es-MX) WindowsPowerShell/5.1.26100.8457	2026-06-15 20:28:22.727+00
37	3	laura.rios	t	127.0.0.1	Mozilla/5.0 (Windows NT; Windows NT 10.0; es-MX) WindowsPowerShell/5.1.26100.8457	2026-06-15 20:28:35.103+00
38	3	laura.rios	t	127.0.0.1		2026-06-15 20:28:58.377+00
39	3	laura.rios	t	127.0.0.1		2026-06-15 20:29:20.366+00
40	3	laura.rios	t	127.0.0.1		2026-06-15 20:30:16.598+00
41	3	laura.rios	t	127.0.0.1		2026-06-15 20:31:00.603+00
42	3	laura.rios	t	127.0.0.1		2026-06-15 20:32:49.175+00
43	3	laura.rios	t	127.0.0.1		2026-06-15 20:33:50.723+00
44	3	laura.rios	t	127.0.0.1		2026-06-15 20:36:00.129+00
45	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-15 21:05:25.441+00
46	11	harry.adm	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-15 21:08:35.403+00
47	11	harry.adm	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-15 21:40:26.797+00
48	11	harry.adm	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-15 23:14:56.62+00
49	11	harry.adm	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 00:24:05.781+00
50	17	HARRY	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 00:25:25.452+00
51	11	harry.adm	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 00:27:34.999+00
52	4	mario.sanchez	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 00:33:52.487+00
53	11	harry.adm	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 00:35:01.083+00
54	7	maria.directora	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 02:20:21.36+00
55	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 04:13:09.542+00
56	17	HARRY	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 06:51:52.191+00
57	4	mario.sanchez	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 06:53:51.413+00
58	11	harry.adm	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 07:23:25.251+00
59	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 07:24:11.791+00
60	17	HARRY	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 07:24:17.786+00
61	11	harry.adm	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 07:42:55.822+00
62	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 08:25:21.295+00
63	6	elizabeth.admin	t	127.0.0.1	node	2026-06-16 08:36:07.3+00
64	6	elizabeth.admin	t	127.0.0.1	node	2026-06-16 08:36:54.11+00
65	6	elizabeth.admin	t	127.0.0.1	node	2026-06-16 08:37:27.974+00
66	6	elizabeth.admin	t	127.0.0.1	node	2026-06-16 08:38:03.584+00
67	6	elizabeth.admin	t	127.0.0.1	node	2026-06-16 08:41:02.308+00
68	6	elizabeth.admin	t	127.0.0.1	node	2026-06-16 08:42:04.527+00
69	8	gestor.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 08:47:00.116+00
70	3	laura.rios	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 08:50:56.813+00
71	4	mario.sanchez	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 08:52:55.535+00
72	6	elizabeth.admin	f	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 08:54:29.099+00
73	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 08:54:35.752+00
74	17	HARRY	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 08:55:17.385+00
75	11	harry.adm	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 08:57:47.345+00
76	19	harry.ga	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 09:12:11.605+00
77	11	harry.adm	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 09:21:15.524+00
78	20	jessi	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 09:23:40.427+00
79	7	maria.directora	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 09:24:53.521+00
80	19	harry.ga	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 09:27:56.725+00
81	8	gestor.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 09:28:21.117+00
82	19	harry.ga	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 09:30:50.427+00
83	8	gestor.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 09:34:58.552+00
84	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 09:35:03.995+00
85	19	harry.ga	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 09:44:11.869+00
86	19	harry.ga	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 09:45:09.819+00
87	19	harry.ga	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 09:54:43.065+00
88	11	harry.adm	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 10:04:57.33+00
89	19	harry.ga	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 10:10:08.173+00
90	17	HARRY	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 10:26:00.539+00
91	\N	elizabeth	f	0.0.0.0		2026-06-16 10:32:09.118+00
92	17	HARRY	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 10:44:18.95+00
93	4	mario.sanchez	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 10:52:47.278+00
94	21	jess	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 10:53:16.964+00
95	17	HARRY	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 10:55:12.36+00
96	7	maria.directora	f	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 10:56:07.203+00
97	7	maria.directora	f	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 10:58:07.049+00
98	7	maria.directora	f	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 10:58:09.753+00
99	7	maria.directora	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 10:58:17.818+00
100	4	mario.sanchez	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 10:58:19.161+00
101	17	HARRY	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 11:04:26.115+00
102	19	harry.ga	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 11:18:30.498+00
103	11	harry.adm	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 11:20:40.233+00
104	19	harry.ga	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 11:36:47.003+00
105	19	harry.ga	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 11:40:13.936+00
106	8	gestor.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 11:40:47.074+00
107	8	gestor.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 11:41:16.9+00
108	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 11:41:31.875+00
109	19	harry.ga	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 12:47:30.105+00
110	7	maria.directora	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 12:47:30.931+00
111	22	jessy	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 13:08:14.356+00
112	7	maria.directora	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 13:09:19.696+00
113	22	jessy	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 13:11:42.889+00
114	19	harry.ga	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 13:15:50.586+00
115	19	harry.ga	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 13:25:15.447+00
116	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 13:25:19.104+00
117	7	maria.directora	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 13:32:46.304+00
118	19	harry.ga	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 13:37:56.922+00
119	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 13:38:01.131+00
120	8	gestor.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 13:38:43.74+00
121	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 13:39:03.426+00
122	11	harry.adm	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 13:40:30.921+00
123	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 16:07:56.482+00
124	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 16:09:04.823+00
125	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 16:18:09.25+00
126	23	morales.a	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 16:22:17.17+00
127	21	jess	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 16:24:39.724+00
128	21	jess	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 16:25:36.005+00
129	21	jess	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 16:26:40.611+00
130	21	jess	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 16:29:25.324+00
131	21	jess	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 16:31:18.71+00
132	21	jess	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 16:32:09.288+00
133	4	mario.sanchez	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 16:35:06.864+00
134	4	mario.sanchez	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 16:36:27.43+00
135	1	elizabeth.mendoza	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 18:47:51.09+00
136	4	mario.sanchez	f	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 18:54:16.097+00
137	4	mario.sanchez	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 18:54:29.482+00
138	4	mario.sanchez	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 19:10:34.091+00
139	1	elizabeth.mendoza	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 19:17:04.412+00
140	4	mario.sanchez	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 19:17:42.633+00
141	1	elizabeth.mendoza	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 19:36:02.889+00
142	4	mario.sanchez	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 19:36:32.511+00
143	1	elizabeth.mendoza	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 19:40:33.841+00
144	6	elizabeth.admin	f	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 20:30:57.214+00
145	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 20:31:07.95+00
146	7	maria.directora	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 21:39:08.268+00
147	21	jess	f	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 21:43:47.611+00
148	7	maria.directora	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 21:44:06.687+00
149	7	maria.directora	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 21:45:15.674+00
150	21	jess	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 21:45:41.307+00
151	4	mario.sanchez	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 21:52:37.32+00
152	1	elizabeth.mendoza	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 21:53:14.086+00
153	4	mario.sanchez	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 21:53:32.269+00
154	1	elizabeth.mendoza	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 21:55:49.152+00
155	7	maria.directora	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 22:04:55.353+00
156	6	elizabeth.admin	t	127.0.0.1	Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36	2026-06-16 22:05:17.13+00
\.


--
-- Data for Name: log_auditoria; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.log_auditoria (log_id, usuario_id, accion, tabla_afectada, registro_id, valores_antes, valores_despues, fecha_hora, direccion_ip, descripcion) FROM stdin;
1	\N	INSERT	usuario	1	\N	{"activo": true, "correo": "elizabeth@sandiego.edu", "telefono": "9211112233", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 1, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-12T05:56:10.412081+00:00", "nombre_usuario": "elizabeth.mendoza", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza Castro", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-12 05:56:10.412081+00	\N	Auditoría automática vía trigger fn_audit_trigger
2	\N	INSERT	usuario	2	\N	{"activo": true, "correo": "direccion@sandiego.edu", "telefono": "9211112234", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 2, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-12T05:56:10.412081+00:00", "nombre_usuario": "maria.dolores", "bloqueado_hasta": null, "nombre_completo": "María Dolores Pérez Rangel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-12 05:56:10.412081+00	\N	Auditoría automática vía trigger fn_audit_trigger
3	\N	INSERT	usuario	3	\N	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-12T05:56:10.412081+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-12 05:56:10.412081+00	\N	Auditoría automática vía trigger fn_audit_trigger
4	\N	INSERT	usuario	4	\N	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-12T05:56:10.412081+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-12 05:56:10.412081+00	\N	Auditoría automática vía trigger fn_audit_trigger
5	\N	INSERT	usuario	5	\N	{"activo": true, "correo": "patricia.nunez@sandiego.edu", "telefono": "9211112237", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 5, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-12T05:56:10.412081+00:00", "nombre_usuario": "patricia.nunez", "bloqueado_hasta": null, "nombre_completo": "Patricia Núñez García", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-12 05:56:10.412081+00	\N	Auditoría automática vía trigger fn_audit_trigger
6	\N	INSERT	usuario_rol	1	\N	{"activo": true, "rol_id": 1, "creado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_id": 1, "asignado_en": "2026-06-12T05:56:10.624731+00:00", "asignado_por": 1, "eliminado_en": null, "actualizado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_rol_id": 1}	2026-06-12 05:56:10.624731+00	\N	Auditoría automática vía trigger fn_audit_trigger
7	\N	INSERT	usuario_rol	2	\N	{"activo": true, "rol_id": 2, "creado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_id": 2, "asignado_en": "2026-06-12T05:56:10.624731+00:00", "asignado_por": 1, "eliminado_en": null, "actualizado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_rol_id": 2}	2026-06-12 05:56:10.624731+00	\N	Auditoría automática vía trigger fn_audit_trigger
8	\N	INSERT	usuario_rol	3	\N	{"activo": true, "rol_id": 3, "creado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_id": 3, "asignado_en": "2026-06-12T05:56:10.624731+00:00", "asignado_por": 1, "eliminado_en": null, "actualizado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_rol_id": 3}	2026-06-12 05:56:10.624731+00	\N	Auditoría automática vía trigger fn_audit_trigger
9	\N	INSERT	usuario_rol	4	\N	{"activo": true, "rol_id": 4, "creado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_id": 5, "asignado_en": "2026-06-12T05:56:10.624731+00:00", "asignado_por": 1, "eliminado_en": null, "actualizado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_rol_id": 4}	2026-06-12 05:56:10.624731+00	\N	Auditoría automática vía trigger fn_audit_trigger
10	\N	INSERT	usuario_rol	5	\N	{"activo": true, "rol_id": 4, "creado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_id": 4, "asignado_en": "2026-06-12T05:56:10.624731+00:00", "asignado_por": 1, "eliminado_en": null, "actualizado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_rol_id": 5}	2026-06-12 05:56:10.624731+00	\N	Auditoría automática vía trigger fn_audit_trigger
11	\N	INSERT	usuario_rol	6	\N	{"activo": true, "rol_id": 4, "creado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_id": 3, "asignado_en": "2026-06-12T05:56:10.624731+00:00", "asignado_por": 1, "eliminado_en": null, "actualizado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_rol_id": 6}	2026-06-12 05:56:10.624731+00	\N	Auditoría automática vía trigger fn_audit_trigger
12	\N	INSERT	alumno	1	\N	{"curp": "MELS170512MVZNPF01", "sexo": "F", "estado": "Activo", "nivel_id": 2, "alumno_id": 1, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2022-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-12T05:56:10.669773+00:00", "dia_limite_pago": null, "nombre_completo": "Sofía Mendoza López", "fecha_nacimiento": "2017-05-12", "personas_autorizadas": [{"nombre": "Roberto Mendoza Hernández", "parentesco": "padre"}, {"nombre": "Lucía López Vargas", "parentesco": "madre"}]}	2026-06-12 05:56:10.669773+00	\N	Auditoría automática vía trigger fn_audit_trigger
13	\N	INSERT	alumno	2	\N	{"curp": "MELD140315HVZNPG07", "sexo": "M", "estado": "Activo", "nivel_id": 3, "alumno_id": 2, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2020-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-12T05:56:10.669773+00:00", "dia_limite_pago": null, "nombre_completo": "Diego Mendoza López", "fecha_nacimiento": "2014-03-15", "personas_autorizadas": [{"nombre": "Roberto Mendoza Hernández", "parentesco": "padre"}, {"nombre": "Lucía López Vargas", "parentesco": "madre"}]}	2026-06-12 05:56:10.669773+00	\N	Auditoría automática vía trigger fn_audit_trigger
14	\N	INSERT	alumno	3	\N	{"curp": "ROAV180220MVZMGL05", "sexo": "F", "estado": "Activo", "nivel_id": 2, "alumno_id": 3, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2023-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-12T05:56:10.669773+00:00", "dia_limite_pago": null, "nombre_completo": "Valeria Romero Aguilar", "fecha_nacimiento": "2018-02-20", "personas_autorizadas": [{"nombre": "Carmen Aguilar Vásquez", "parentesco": "madre"}]}	2026-06-12 05:56:10.669773+00	\N	Auditoría automática vía trigger fn_audit_trigger
15	\N	INSERT	alumno	4	\N	{"curp": "ROAS150408HVZMGB02", "sexo": "M", "estado": "Activo", "nivel_id": 2, "alumno_id": 4, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2021-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-12T05:56:10.669773+00:00", "dia_limite_pago": null, "nombre_completo": "Sebastián Romero Aguilar", "fecha_nacimiento": "2015-04-08", "personas_autorizadas": [{"nombre": "Carmen Aguilar Vásquez", "parentesco": "madre"}]}	2026-06-12 05:56:10.669773+00	\N	Auditoría automática vía trigger fn_audit_trigger
16	\N	INSERT	alumno	5	\N	{"curp": "GORJ130715HVZNZR03", "sexo": "M", "estado": "Activo", "nivel_id": 3, "alumno_id": 5, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2019-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-12T05:56:10.669773+00:00", "dia_limite_pago": 10, "nombre_completo": "Jorge Andrés González Ruiz", "fecha_nacimiento": "2013-07-15", "personas_autorizadas": [{"nombre": "Jorge González Ramírez", "parentesco": "padre"}]}	2026-06-12 05:56:10.669773+00	\N	Auditoría automática vía trigger fn_audit_trigger
17	\N	INSERT	alumno	6	\N	{"curp": "SOPD190422MVZTRN08", "sexo": "F", "estado": "Activo", "nivel_id": 2, "alumno_id": 6, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2024-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-12T05:56:10.669773+00:00", "dia_limite_pago": null, "nombre_completo": "Daniela Soto Pérez", "fecha_nacimiento": "2019-04-22", "personas_autorizadas": [{"nombre": "Patricia Soto Reyes", "parentesco": "madre"}]}	2026-06-12 05:56:10.669773+00	\N	Auditoría automática vía trigger fn_audit_trigger
18	\N	INSERT	alumno	7	\N	{"curp": "SOPN160830MVZTRT02", "sexo": "F", "estado": "Activo", "nivel_id": 2, "alumno_id": 7, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2022-0002", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-12T05:56:10.669773+00:00", "dia_limite_pago": null, "nombre_completo": "Natalia Soto Pérez", "fecha_nacimiento": "2016-08-30", "personas_autorizadas": [{"nombre": "Patricia Soto Reyes", "parentesco": "madre"}]}	2026-06-12 05:56:10.669773+00	\N	Auditoría automática vía trigger fn_audit_trigger
19	\N	INSERT	alumno	8	\N	{"curp": "SOPE140111HVZTRM05", "sexo": "M", "estado": "Activo", "nivel_id": 3, "alumno_id": 8, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2020-0002", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-12T05:56:10.669773+00:00", "dia_limite_pago": null, "nombre_completo": "Emiliano Soto Pérez", "fecha_nacimiento": "2014-01-11", "personas_autorizadas": [{"nombre": "Patricia Soto Reyes", "parentesco": "madre"}]}	2026-06-12 05:56:10.669773+00	\N	Auditoría automática vía trigger fn_audit_trigger
20	\N	INSERT	alumno	9	\N	{"curp": "CAHC170305MVZSRM06", "sexo": "F", "estado": "Activo", "nivel_id": 2, "alumno_id": 9, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2022-0003", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-12T05:56:10.669773+00:00", "dia_limite_pago": null, "nombre_completo": "Camila Castro Hernández", "fecha_nacimiento": "2017-03-05", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	2026-06-12 05:56:10.669773+00	\N	Auditoría automática vía trigger fn_audit_trigger
21	\N	INSERT	alumno	10	\N	{"curp": "CAHA111018HVZSRD01", "sexo": "M", "estado": "Activo", "nivel_id": 3, "alumno_id": 10, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2018-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-12T05:56:10.669773+00:00", "dia_limite_pago": null, "nombre_completo": "Adrián Castro Hernández", "fecha_nacimiento": "2011-10-18", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	2026-06-12 05:56:10.669773+00	\N	Auditoría automática vía trigger fn_audit_trigger
22	1	INSERT	pago	1	\N	{"pago_id": 1, "tutor_id": 1, "alumno_id": 2, "fecha_pago": "2026-09-04", "metodo_pago": "transferencia", "monto_total": 4500.00, "observaciones": "Colegiatura septiembre 2026 - pago puntual (Roberto)", "registrado_en": "2026-06-12T05:56:10.696221+00:00", "actualizado_en": "2026-06-12T05:56:10.696221+00:00", "registrado_por": 1, "aplicado_a_saldo": false}	2026-06-12 05:56:10.696221+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
23	1	INSERT	pago	2	\N	{"pago_id": 2, "tutor_id": 1, "alumno_id": 1, "fecha_pago": "2026-10-08", "metodo_pago": "deposito", "monto_total": 4400.00, "observaciones": "Colegiatura octubre 2026 - tardía, recargo $400 (Roberto)", "registrado_en": "2026-06-12T05:56:10.703911+00:00", "actualizado_en": "2026-06-12T05:56:10.703911+00:00", "registrado_por": 1, "aplicado_a_saldo": false}	2026-06-12 05:56:10.703911+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
24	3	INSERT	pago	3	\N	{"pago_id": 3, "tutor_id": 1, "alumno_id": 1, "fecha_pago": "2026-11-04", "metodo_pago": "efectivo", "monto_total": 2000.00, "observaciones": "Abono parcial colegiatura noviembre 2026 (Roberto)", "registrado_en": "2026-06-12T05:56:10.712725+00:00", "actualizado_en": "2026-06-12T05:56:10.712725+00:00", "registrado_por": 3, "aplicado_a_saldo": false}	2026-06-12 05:56:10.712725+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
25	1	INSERT	pago	4	\N	{"pago_id": 4, "tutor_id": 2, "alumno_id": 2, "fecha_pago": "2026-08-03", "metodo_pago": "transferencia", "monto_total": 4500.00, "observaciones": "Colegiatura agosto 2026 de Diego pagada por Lucía (madre, custodia compartida)", "registrado_en": "2026-06-12T05:56:10.719005+00:00", "actualizado_en": "2026-06-12T05:56:10.719005+00:00", "registrado_por": 1, "aplicado_a_saldo": false}	2026-06-12 05:56:10.719005+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
26	\N	INSERT	usuario	6	\N	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-14T18:44:45.373+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-14 18:44:45.380522+00	\N	Auditoría automática vía trigger fn_audit_trigger
27	\N	INSERT	usuario_rol	7	\N	{"activo": true, "rol_id": 1, "creado_en": "2026-06-14T18:44:45.402+00:00", "usuario_id": 6, "asignado_en": "2026-06-14T18:44:45.402+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-14T18:44:45.402+00:00", "usuario_rol_id": 7}	2026-06-14 18:44:45.404456+00	\N	Auditoría automática vía trigger fn_audit_trigger
28	\N	INSERT	usuario	7	\N	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-14T18:44:45.41+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-14 18:44:45.411125+00	\N	Auditoría automática vía trigger fn_audit_trigger
29	\N	INSERT	usuario_rol	8	\N	{"activo": true, "rol_id": 2, "creado_en": "2026-06-14T18:44:45.414+00:00", "usuario_id": 7, "asignado_en": "2026-06-14T18:44:45.414+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-14T18:44:45.414+00:00", "usuario_rol_id": 8}	2026-06-14 18:44:45.414851+00	\N	Auditoría automática vía trigger fn_audit_trigger
30	\N	INSERT	usuario	8	\N	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-14T18:44:45.42+00:00", "usuario_id": 8, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-14T18:44:45.42+00:00", "nombre_usuario": "gestor.admin", "bloqueado_hasta": null, "nombre_completo": "Gestor Administrativo", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-14 18:44:45.420983+00	\N	Auditoría automática vía trigger fn_audit_trigger
31	\N	INSERT	usuario_rol	9	\N	{"activo": true, "rol_id": 3, "creado_en": "2026-06-14T18:44:45.426+00:00", "usuario_id": 8, "asignado_en": "2026-06-14T18:44:45.426+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-14T18:44:45.426+00:00", "usuario_rol_id": 9}	2026-06-14 18:44:45.426959+00	\N	Auditoría automática vía trigger fn_audit_trigger
32	\N	UPDATE	usuario	3	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-12T05:56:10.412081+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-14T18:44:45.432332+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-14 18:44:45.432332+00	\N	Auditoría automática vía trigger fn_audit_trigger
33	\N	UPDATE	usuario_rol	3	{"activo": true, "rol_id": 3, "creado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_id": 3, "asignado_en": "2026-06-12T05:56:10.624731+00:00", "asignado_por": 1, "eliminado_en": null, "actualizado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_rol_id": 3}	{"activo": true, "rol_id": 3, "creado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_id": 3, "asignado_en": "2026-06-12T05:56:10.624731+00:00", "asignado_por": 1, "eliminado_en": null, "actualizado_en": "2026-06-14T18:44:45.43941+00:00", "usuario_rol_id": 3}	2026-06-14 18:44:45.43941+00	\N	Auditoría automática vía trigger fn_audit_trigger
34	\N	UPDATE	usuario_rol	6	{"activo": true, "rol_id": 4, "creado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_id": 3, "asignado_en": "2026-06-12T05:56:10.624731+00:00", "asignado_por": 1, "eliminado_en": null, "actualizado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_rol_id": 6}	{"activo": true, "rol_id": 4, "creado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_id": 3, "asignado_en": "2026-06-12T05:56:10.624731+00:00", "asignado_por": 1, "eliminado_en": null, "actualizado_en": "2026-06-14T18:44:45.44209+00:00", "usuario_rol_id": 6}	2026-06-14 18:44:45.44209+00	\N	Auditoría automática vía trigger fn_audit_trigger
35	\N	UPDATE	usuario	4	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-12T05:56:10.412081+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-14T18:44:45.445731+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-14 18:44:45.445731+00	\N	Auditoría automática vía trigger fn_audit_trigger
36	\N	UPDATE	usuario_rol	5	{"activo": true, "rol_id": 4, "creado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_id": 4, "asignado_en": "2026-06-12T05:56:10.624731+00:00", "asignado_por": 1, "eliminado_en": null, "actualizado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_rol_id": 5}	{"activo": true, "rol_id": 4, "creado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_id": 4, "asignado_en": "2026-06-12T05:56:10.624731+00:00", "asignado_por": 1, "eliminado_en": null, "actualizado_en": "2026-06-14T18:44:45.449121+00:00", "usuario_rol_id": 5}	2026-06-14 18:44:45.449121+00	\N	Auditoría automática vía trigger fn_audit_trigger
37	\N	INSERT	alumno	11	\N	{"curp": "GORM140322MDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 11, "creado_en": "2026-06-14T18:44:45.668+00:00", "matricula": "SDM-2020-0089", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-14T18:44:45.668+00:00", "dia_limite_pago": null, "nombre_completo": "María González Ruiz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-14 18:44:45.670415+00	\N	Auditoría automática vía trigger fn_audit_trigger
38	\N	INSERT	alumno	12	\N	{"curp": "PEMJ140522HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 12, "creado_en": "2026-06-14T18:44:45.719+00:00", "matricula": "SDM-2020-0123", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-14T18:44:45.719+00:00", "dia_limite_pago": null, "nombre_completo": "Juan Pérez Morales", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-14 18:44:45.720854+00	\N	Auditoría automática vía trigger fn_audit_trigger
39	\N	INSERT	alumno	13	\N	{"curp": "FELC190815HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 13, "creado_en": "2026-06-14T18:44:45.746+00:00", "matricula": "SDM-2019-0412", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-14T18:44:45.746+00:00", "dia_limite_pago": null, "nombre_completo": "Carlos Fernández López", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-14 18:44:45.747693+00	\N	Auditoría automática vía trigger fn_audit_trigger
40	\N	INSERT	alumno	14	\N	{"curp": null, "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 14, "creado_en": "2026-06-14T18:44:45.772+00:00", "matricula": "SDM-2021-0055", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-14T18:44:45.772+00:00", "dia_limite_pago": null, "nombre_completo": "Sofía Ramírez Cruz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-14 18:44:45.772941+00	\N	Auditoría automática vía trigger fn_audit_trigger
41	\N	INSERT	alumno	15	\N	{"curp": null, "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 15, "creado_en": "2026-06-14T18:44:45.79+00:00", "matricula": "SDM-2022-0099", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-14T18:44:45.79+00:00", "dia_limite_pago": null, "nombre_completo": "Miguel Torres Gómez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-14 18:44:45.791084+00	\N	Auditoría automática vía trigger fn_audit_trigger
42	\N	INSERT	alumno	16	\N	{"curp": null, "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 16, "creado_en": "2026-06-14T18:44:45.812+00:00", "matricula": "SDM-2018-0301", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-14T18:44:45.812+00:00", "dia_limite_pago": null, "nombre_completo": "Ana Lucía Hernández", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-14 18:44:45.813034+00	\N	Auditoría automática vía trigger fn_audit_trigger
43	\N	INSERT	alumno	17	\N	{"curp": null, "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 17, "creado_en": "2026-06-14T18:44:45.838+00:00", "matricula": "SDM-2018-0344", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-14T18:44:45.838+00:00", "dia_limite_pago": null, "nombre_completo": "Diego Martínez Soto", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-14 18:44:45.839192+00	\N	Auditoría automática vía trigger fn_audit_trigger
44	\N	INSERT	alumno	18	\N	{"curp": null, "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 18, "creado_en": "2026-06-14T18:44:45.856+00:00", "matricula": "SDM-2019-0277", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-14T18:44:45.856+00:00", "dia_limite_pago": null, "nombre_completo": "Valentina Castro Ruiz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-14 18:44:45.857544+00	\N	Auditoría automática vía trigger fn_audit_trigger
45	\N	UPDATE	usuario	1	{"activo": true, "correo": "elizabeth@sandiego.edu", "telefono": "9211112233", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 1, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-12T05:56:10.412081+00:00", "nombre_usuario": "elizabeth.mendoza", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza Castro", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth@sandiego.edu", "telefono": "9211112233", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 1, "eliminado_en": null, "ultimo_acceso": "2026-06-14T20:29:20.337+00:00", "actualizado_en": "2026-06-14T20:29:20.351631+00:00", "nombre_usuario": "elizabeth.mendoza", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza Castro", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-14 20:29:20.351631+00	\N	Auditoría automática vía trigger fn_audit_trigger
46	1	INSERT	pago	5	\N	{"pago_id": 5, "tutor_id": 12, "alumno_id": 16, "fecha_pago": "2026-06-13", "metodo_pago": "efectivo", "monto_total": 4500.00, "observaciones": null, "registrado_en": "2026-06-14T23:19:57.209+00:00", "actualizado_en": "2026-06-14T23:19:57.209+00:00", "registrado_por": 1, "aplicado_a_saldo": false}	2026-06-14 23:19:57.193402+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
47	1	INSERT	pago	6	\N	{"pago_id": 6, "tutor_id": 1, "alumno_id": 1, "fecha_pago": "2026-06-15", "metodo_pago": "efectivo", "monto_total": 32000.00, "observaciones": null, "registrado_en": "2026-06-15T03:31:31.968+00:00", "actualizado_en": "2026-06-15T03:31:31.968+00:00", "registrado_por": 1, "aplicado_a_saldo": false}	2026-06-15 03:31:31.95737+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
48	1	INSERT	pago	7	\N	{"pago_id": 7, "tutor_id": 1, "alumno_id": 1, "fecha_pago": "2026-06-15", "metodo_pago": "efectivo", "monto_total": 2000.00, "observaciones": "Pago adelantado de colegiaturas (1 meses)", "registrado_en": "2026-06-15T03:33:07.621+00:00", "actualizado_en": "2026-06-15T03:33:07.621+00:00", "registrado_por": 1, "aplicado_a_saldo": false}	2026-06-15 03:33:07.610073+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
49	\N	UPDATE	usuario	7	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-14T18:44:45.41+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-15T04:14:24.642+00:00", "actualizado_en": "2026-06-15T04:14:24.65125+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-15 04:14:24.65125+00	\N	Auditoría automática vía trigger fn_audit_trigger
50	\N	UPDATE	usuario	7	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-15T04:14:24.642+00:00", "actualizado_en": "2026-06-15T04:14:24.65125+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-15T04:14:39.195+00:00", "actualizado_en": "2026-06-15T04:14:39.197936+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-15 04:14:39.197936+00	\N	Auditoría automática vía trigger fn_audit_trigger
51	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-14T18:44:45.373+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-15T04:15:09.878+00:00", "actualizado_en": "2026-06-15T04:15:09.878851+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-15 04:15:09.878851+00	\N	Auditoría automática vía trigger fn_audit_trigger
52	7	INSERT	pago	8	\N	{"pago_id": 8, "tutor_id": 6, "alumno_id": 10, "fecha_pago": "2026-06-15", "metodo_pago": "efectivo", "monto_total": 52500.00, "observaciones": null, "registrado_en": "2026-06-15T04:38:52.196+00:00", "actualizado_en": "2026-06-15T04:38:52.196+00:00", "registrado_por": 7, "aplicado_a_saldo": false}	2026-06-15 04:38:52.186004+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
57	7	UPDATE	alumno	9	{"curp": "CAHC170305MVZSRM06", "sexo": "F", "estado": "Activo", "nivel_id": 2, "alumno_id": 9, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2022-0003", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-12T05:56:10.669773+00:00", "dia_limite_pago": null, "nombre_completo": "Camila Castro Hernández", "fecha_nacimiento": "2017-03-05", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	{"curp": "CAHC170305MVZSRM06", "sexo": "F", "estado": "Activo", "nivel_id": 1, "alumno_id": 9, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2022-0003", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "", "actualizado_en": "2026-06-15T04:41:44.330427+00:00", "dia_limite_pago": null, "nombre_completo": "Camila Castro Hernández", "fecha_nacimiento": "2017-03-05", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	2026-06-15 04:41:44.330427+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
58	7	UPDATE	alumno	12	{"curp": "PEMJ140522HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 12, "creado_en": "2026-06-14T18:44:45.719+00:00", "matricula": "SDM-2020-0123", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-14T18:44:45.719+00:00", "dia_limite_pago": null, "nombre_completo": "Juan Pérez Morales", "fecha_nacimiento": null, "personas_autorizadas": []}	{"curp": "PEMJ140522HDFXXX01", "sexo": null, "estado": "Baja Temporal", "nivel_id": 2, "alumno_id": 12, "creado_en": "2026-06-14T18:44:45.719+00:00", "matricula": "SDM-2020-0123", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "[BAJA TEMPORAL 14/6/2026]: por joto", "actualizado_en": "2026-06-15T04:51:09.705233+00:00", "dia_limite_pago": null, "nombre_completo": "Juan Pérez Morales", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 04:51:09.705233+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
59	7	UPDATE	alumno	12	{"curp": "PEMJ140522HDFXXX01", "sexo": null, "estado": "Baja Temporal", "nivel_id": 2, "alumno_id": 12, "creado_en": "2026-06-14T18:44:45.719+00:00", "matricula": "SDM-2020-0123", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "[BAJA TEMPORAL 14/6/2026]: por joto", "actualizado_en": "2026-06-15T04:51:09.705233+00:00", "dia_limite_pago": null, "nombre_completo": "Juan Pérez Morales", "fecha_nacimiento": null, "personas_autorizadas": []}	{"curp": "PEMJ140522HDFXXX01", "sexo": null, "estado": "Baja Definitiva", "nivel_id": 2, "alumno_id": 12, "creado_en": "2026-06-14T18:44:45.719+00:00", "matricula": "SDM-2020-0123", "fecha_baja": null, "motivo_baja": null, "eliminado_en": "2026-06-15T04:51:27.578+00:00", "observaciones": "[BAJA TEMPORAL 14/6/2026]: por joto", "actualizado_en": "2026-06-15T04:51:27.570681+00:00", "dia_limite_pago": null, "nombre_completo": "Juan Pérez Morales", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 04:51:27.570681+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
60	6	UPDATE	alumno	17	{"curp": null, "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 17, "creado_en": "2026-06-14T18:44:45.838+00:00", "matricula": "SDM-2018-0344", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-14T18:44:45.838+00:00", "dia_limite_pago": null, "nombre_completo": "Diego Martínez Soto", "fecha_nacimiento": null, "personas_autorizadas": []}	{"curp": null, "sexo": null, "estado": "Baja Temporal", "nivel_id": 4, "alumno_id": 17, "creado_en": "2026-06-14T18:44:45.838+00:00", "matricula": "SDM-2018-0344", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "[BAJA TEMPORAL 14/6/2026]: por jochis", "actualizado_en": "2026-06-15T04:54:12.723213+00:00", "dia_limite_pago": null, "nombre_completo": "Diego Martínez Soto", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 04:54:12.723213+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
61	6	UPDATE	alumno	17	{"curp": null, "sexo": null, "estado": "Baja Temporal", "nivel_id": 4, "alumno_id": 17, "creado_en": "2026-06-14T18:44:45.838+00:00", "matricula": "SDM-2018-0344", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "[BAJA TEMPORAL 14/6/2026]: por jochis", "actualizado_en": "2026-06-15T04:54:12.723213+00:00", "dia_limite_pago": null, "nombre_completo": "Diego Martínez Soto", "fecha_nacimiento": null, "personas_autorizadas": []}	{"curp": null, "sexo": null, "estado": "Baja Definitiva", "nivel_id": 4, "alumno_id": 17, "creado_en": "2026-06-14T18:44:45.838+00:00", "matricula": "SDM-2018-0344", "fecha_baja": null, "motivo_baja": null, "eliminado_en": "2026-06-15T04:54:21.322+00:00", "observaciones": "[BAJA TEMPORAL 14/6/2026]: por jochis", "actualizado_en": "2026-06-15T04:54:21.317114+00:00", "dia_limite_pago": null, "nombre_completo": "Diego Martínez Soto", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 04:54:21.317114+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
62	7	INSERT	pago	9	\N	{"pago_id": 9, "tutor_id": 8, "alumno_id": 12, "fecha_pago": "2026-06-15", "metodo_pago": "efectivo", "monto_total": 50000000.00, "observaciones": null, "registrado_en": "2026-06-15T05:04:51.48+00:00", "actualizado_en": "2026-06-15T05:04:51.48+00:00", "registrado_por": 7, "aplicado_a_saldo": false}	2026-06-15 05:04:51.46618+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
63	7	INSERT	pago	10	\N	{"pago_id": 10, "tutor_id": 6, "alumno_id": 10, "fecha_pago": "2026-06-15", "metodo_pago": "efectivo", "monto_total": 1500.00, "observaciones": null, "registrado_en": "2026-06-15T05:07:25.875+00:00", "actualizado_en": "2026-06-15T05:07:25.875+00:00", "registrado_por": 7, "aplicado_a_saldo": false}	2026-06-15 05:07:25.865807+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
64	7	INSERT	pago	11	\N	{"pago_id": 11, "tutor_id": 6, "alumno_id": 10, "fecha_pago": "2026-06-15", "metodo_pago": "efectivo", "monto_total": 4500.00, "observaciones": null, "registrado_en": "2026-06-15T05:21:22.539+00:00", "actualizado_en": "2026-06-15T05:21:22.539+00:00", "registrado_por": 7, "aplicado_a_saldo": false}	2026-06-15 05:21:22.529173+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
65	7	INSERT	pago	12	\N	{"pago_id": 12, "tutor_id": 6, "alumno_id": 10, "fecha_pago": "2026-06-15", "metodo_pago": "efectivo", "monto_total": 4500.00, "observaciones": null, "registrado_en": "2026-06-15T05:21:55.182+00:00", "actualizado_en": "2026-06-15T05:21:55.182+00:00", "registrado_por": 7, "aplicado_a_saldo": false}	2026-06-15 05:21:55.175978+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
66	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-15T04:15:09.878+00:00", "actualizado_en": "2026-06-15T04:15:09.878851+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-15T05:45:28.161+00:00", "actualizado_en": "2026-06-15T05:45:28.166297+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-15 05:45:28.166297+00	\N	Auditoría automática vía trigger fn_audit_trigger
67	7	INSERT	pago	13	\N	{"pago_id": 13, "tutor_id": 6, "alumno_id": 10, "fecha_pago": "2026-06-15", "metodo_pago": "efectivo", "monto_total": 4500.00, "observaciones": null, "registrado_en": "2026-06-15T05:48:55.702+00:00", "actualizado_en": "2026-06-15T05:48:55.702+00:00", "registrado_por": 7, "aplicado_a_saldo": false}	2026-06-15 05:48:55.691101+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
68	\N	UPDATE	usuario	7	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-15T04:14:39.195+00:00", "actualizado_en": "2026-06-15T04:14:39.197936+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-15T08:35:04.385+00:00", "actualizado_en": "2026-06-15T08:35:04.39779+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-15 08:35:04.39779+00	\N	Auditoría automática vía trigger fn_audit_trigger
69	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-15T05:45:28.161+00:00", "actualizado_en": "2026-06-15T05:45:28.166297+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-15T08:35:29.375+00:00", "actualizado_en": "2026-06-15T08:35:29.377245+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-15 08:35:29.377245+00	\N	Auditoría automática vía trigger fn_audit_trigger
70	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-15T08:35:29.375+00:00", "actualizado_en": "2026-06-15T08:35:29.377245+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-15T09:33:12.905+00:00", "actualizado_en": "2026-06-15T09:33:12.90943+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-15 09:33:12.90943+00	\N	Auditoría automática vía trigger fn_audit_trigger
71	6	INSERT	usuario	11	\N	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-15T09:34:07.899+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-15 09:34:07.890176+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
72	6	INSERT	usuario_rol	13	\N	{"activo": true, "rol_id": 1, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "asignado_en": "2026-06-15T09:34:07.899+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-15T09:34:07.899+00:00", "usuario_rol_id": 13}	2026-06-15 09:34:07.890176+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
73	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-15T09:33:12.905+00:00", "actualizado_en": "2026-06-15T09:33:12.90943+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-15T09:33:12.905+00:00", "actualizado_en": "2026-06-15T09:35:03.550243+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 1}	2026-06-15 09:35:03.550243+00	\N	Auditoría automática vía trigger fn_audit_trigger
74	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-15T09:33:12.905+00:00", "actualizado_en": "2026-06-15T09:35:03.550243+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 1}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-15T09:35:10.648+00:00", "actualizado_en": "2026-06-15T09:35:10.650241+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-15 09:35:10.650241+00	\N	Auditoría automática vía trigger fn_audit_trigger
75	\N	UPDATE	usuario	11	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-15T09:34:07.899+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-15T09:35:35.943477+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-15 09:35:35.943477+00	\N	Auditoría automática vía trigger fn_audit_trigger
76	\N	UPDATE	usuario	11	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-15T09:35:35.943477+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-15T09:35:53.448+00:00", "actualizado_en": "2026-06-15T09:35:53.449879+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-15 09:35:53.449879+00	\N	Auditoría automática vía trigger fn_audit_trigger
77	11	UPDATE	tutor	10	{"rfc": null, "curp": null, "activo": true, "tutorId": 10, "usoCfdi": null, "creadoEn": "2026-06-14T18:44:45.775Z", "telefono": "5552223344", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": null, "actualizadoEn": "2026-06-14T18:44:45.775Z", "regimenFiscal": null, "nombreCompleto": "Ana Ramírez", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": null}	{"rfc": "oaiwhdja12365", "curp": null, "activo": true, "tutorId": 10, "usoCfdi": "G01", "creadoEn": "2026-06-14T18:44:45.775Z", "telefono": "5552223344", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "56569", "actualizadoEn": "2026-06-15T09:45:50.300Z", "regimenFiscal": "625", "nombreCompleto": "Ana Ramírez", "direccionFiscal": null, "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": null}	2026-06-15 09:45:50.308+00	127.0.0.1	\N
78	11	UPDATE	tutor	10	{"rfc": "oaiwhdja12365", "curp": null, "activo": true, "tutorId": 10, "usoCfdi": "G01", "creadoEn": "2026-06-14T18:44:45.775Z", "telefono": "5552223344", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "56569", "actualizadoEn": "2026-06-15T09:45:50.300Z", "regimenFiscal": "625", "nombreCompleto": "Ana Ramírez", "direccionFiscal": null, "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": null}	{"rfc": "oai", "curp": null, "activo": true, "tutorId": 10, "usoCfdi": "G01", "creadoEn": "2026-06-14T18:44:45.775Z", "telefono": "5552223344", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "56", "actualizadoEn": "2026-06-15T10:52:57.322Z", "regimenFiscal": "625", "nombreCompleto": "Ana Ramírez", "direccionFiscal": "lopez", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": "lpp"}	2026-06-15 10:52:57.328+00	127.0.0.1	\N
79	11	UPDATE	tutor	10	{"rfc": "oai", "curp": null, "activo": true, "tutorId": 10, "usoCfdi": "G01", "creadoEn": "2026-06-14T18:44:45.775Z", "telefono": "5552223344", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "56", "actualizadoEn": "2026-06-15T10:52:57.322Z", "regimenFiscal": "625", "nombreCompleto": "Ana Ramírez", "direccionFiscal": "lopez", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": "lpp"}	{"rfc": "oai", "curp": null, "activo": true, "tutorId": 10, "usoCfdi": "G01", "creadoEn": "2026-06-14T18:44:45.775Z", "telefono": "5552223344", "direccion": "lop", "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "56", "actualizadoEn": "2026-06-15T10:54:34.424Z", "regimenFiscal": "625", "nombreCompleto": "Ana Ramírez", "direccionFiscal": "lopez", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": "lop", "correoFacturacion": "lpp"}	2026-06-15 10:54:34.43+00	127.0.0.1	\N
80	11	UPDATE	tutor	10	{"rfc": "oai", "curp": null, "activo": true, "tutorId": 10, "usoCfdi": "G01", "creadoEn": "2026-06-14T18:44:45.775Z", "telefono": "5552223344", "direccion": "lop", "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "56", "actualizadoEn": "2026-06-15T10:54:34.424Z", "regimenFiscal": "625", "nombreCompleto": "Ana Ramírez", "direccionFiscal": "lopez", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": "lop", "correoFacturacion": "lpp"}	{"rfc": "oai", "curp": null, "activo": true, "tutorId": 10, "usoCfdi": "G01", "creadoEn": "2026-06-14T18:44:45.775Z", "telefono": "5552223344", "direccion": "lop", "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "56", "actualizadoEn": "2026-06-15T10:56:37.455Z", "regimenFiscal": "625", "nombreCompleto": "Ana Ramírez", "direccionFiscal": "lopez", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": "lop", "correoFacturacion": "lpp"}	2026-06-15 10:56:37.458+00	127.0.0.1	\N
82	\N	UPDATE	usuario	7	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-15T08:35:04.385+00:00", "actualizado_en": "2026-06-15T08:35:04.39779+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-15T19:06:27.96+00:00", "actualizado_en": "2026-06-15T19:06:27.975599+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-15 19:06:27.975599+00	\N	Auditoría automática vía trigger fn_audit_trigger
83	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-15T09:35:10.648+00:00", "actualizado_en": "2026-06-15T09:35:10.650241+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-15T19:06:40.27+00:00", "actualizado_en": "2026-06-15T19:06:40.271758+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-15 19:06:40.271758+00	\N	Auditoría automática vía trigger fn_audit_trigger
84	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-15T19:06:40.27+00:00", "actualizado_en": "2026-06-15T19:06:40.271758+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-15T19:06:40.27+00:00", "actualizado_en": "2026-06-15T19:44:47.692297+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-15 19:44:47.692297+00	\N	Auditoría automática vía trigger fn_audit_trigger
85	\N	UPDATE	usuario_rol	7	{"activo": true, "rol_id": 1, "creado_en": "2026-06-14T18:44:45.402+00:00", "usuario_id": 6, "asignado_en": "2026-06-14T18:44:45.402+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-14T18:44:45.402+00:00", "usuario_rol_id": 7}	{"activo": true, "rol_id": 1, "creado_en": "2026-06-14T18:44:45.402+00:00", "usuario_id": 6, "asignado_en": "2026-06-14T18:44:45.402+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-15T19:44:47.731587+00:00", "usuario_rol_id": 7}	2026-06-15 19:44:47.731587+00	\N	Auditoría automática vía trigger fn_audit_trigger
86	\N	UPDATE	usuario	7	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-15T19:06:27.96+00:00", "actualizado_en": "2026-06-15T19:06:27.975599+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-15T19:06:27.96+00:00", "actualizado_en": "2026-06-15T19:44:47.739873+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-15 19:44:47.739873+00	\N	Auditoría automática vía trigger fn_audit_trigger
87	\N	UPDATE	usuario_rol	8	{"activo": true, "rol_id": 2, "creado_en": "2026-06-14T18:44:45.414+00:00", "usuario_id": 7, "asignado_en": "2026-06-14T18:44:45.414+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-14T18:44:45.414+00:00", "usuario_rol_id": 8}	{"activo": true, "rol_id": 2, "creado_en": "2026-06-14T18:44:45.414+00:00", "usuario_id": 7, "asignado_en": "2026-06-14T18:44:45.414+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-15T19:44:47.751601+00:00", "usuario_rol_id": 8}	2026-06-15 19:44:47.751601+00	\N	Auditoría automática vía trigger fn_audit_trigger
88	\N	UPDATE	usuario	8	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-14T18:44:45.42+00:00", "usuario_id": 8, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-14T18:44:45.42+00:00", "nombre_usuario": "gestor.admin", "bloqueado_hasta": null, "nombre_completo": "Gestor Administrativo", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-14T18:44:45.42+00:00", "usuario_id": 8, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-15T19:44:47.794178+00:00", "nombre_usuario": "gestor.admin", "bloqueado_hasta": null, "nombre_completo": "Gestor Administrativo", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-15 19:44:47.794178+00	\N	Auditoría automática vía trigger fn_audit_trigger
89	\N	UPDATE	usuario_rol	9	{"activo": true, "rol_id": 3, "creado_en": "2026-06-14T18:44:45.426+00:00", "usuario_id": 8, "asignado_en": "2026-06-14T18:44:45.426+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-14T18:44:45.426+00:00", "usuario_rol_id": 9}	{"activo": true, "rol_id": 3, "creado_en": "2026-06-14T18:44:45.426+00:00", "usuario_id": 8, "asignado_en": "2026-06-14T18:44:45.426+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-15T19:44:47.817774+00:00", "usuario_rol_id": 9}	2026-06-15 19:44:47.817774+00	\N	Auditoría automática vía trigger fn_audit_trigger
90	\N	UPDATE	usuario	3	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-14T18:44:45.432332+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-15T19:44:47.838154+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-15 19:44:47.838154+00	\N	Auditoría automática vía trigger fn_audit_trigger
91	\N	UPDATE	usuario_rol	3	{"activo": true, "rol_id": 3, "creado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_id": 3, "asignado_en": "2026-06-12T05:56:10.624731+00:00", "asignado_por": 1, "eliminado_en": null, "actualizado_en": "2026-06-14T18:44:45.43941+00:00", "usuario_rol_id": 3}	{"activo": true, "rol_id": 3, "creado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_id": 3, "asignado_en": "2026-06-12T05:56:10.624731+00:00", "asignado_por": 1, "eliminado_en": null, "actualizado_en": "2026-06-15T19:44:47.854959+00:00", "usuario_rol_id": 3}	2026-06-15 19:44:47.854959+00	\N	Auditoría automática vía trigger fn_audit_trigger
92	\N	UPDATE	usuario_rol	6	{"activo": true, "rol_id": 4, "creado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_id": 3, "asignado_en": "2026-06-12T05:56:10.624731+00:00", "asignado_por": 1, "eliminado_en": null, "actualizado_en": "2026-06-14T18:44:45.44209+00:00", "usuario_rol_id": 6}	{"activo": true, "rol_id": 4, "creado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_id": 3, "asignado_en": "2026-06-12T05:56:10.624731+00:00", "asignado_por": 1, "eliminado_en": null, "actualizado_en": "2026-06-15T19:44:47.883203+00:00", "usuario_rol_id": 6}	2026-06-15 19:44:47.883203+00	\N	Auditoría automática vía trigger fn_audit_trigger
93	\N	UPDATE	usuario	4	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-14T18:44:45.445731+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-15T19:44:47.904991+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-15 19:44:47.904991+00	\N	Auditoría automática vía trigger fn_audit_trigger
94	\N	UPDATE	usuario_rol	5	{"activo": true, "rol_id": 4, "creado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_id": 4, "asignado_en": "2026-06-12T05:56:10.624731+00:00", "asignado_por": 1, "eliminado_en": null, "actualizado_en": "2026-06-14T18:44:45.449121+00:00", "usuario_rol_id": 5}	{"activo": true, "rol_id": 4, "creado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_id": 4, "asignado_en": "2026-06-12T05:56:10.624731+00:00", "asignado_por": 1, "eliminado_en": null, "actualizado_en": "2026-06-15T19:44:47.915054+00:00", "usuario_rol_id": 5}	2026-06-15 19:44:47.915054+00	\N	Auditoría automática vía trigger fn_audit_trigger
95	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-15T19:06:40.27+00:00", "actualizado_en": "2026-06-15T19:44:47.692297+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-15T19:46:48.85+00:00", "actualizado_en": "2026-06-15T19:46:48.858793+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-15 19:46:48.858793+00	\N	Auditoría automática vía trigger fn_audit_trigger
116	\N	INSERT	alumno	29	\N	{"curp": "TEST60194HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 29, "creado_en": "2026-06-15T20:52:45.815+00:00", "matricula": "TST-PRI-2A-7KKH-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:45.815+00:00", "dia_limite_pago": null, "nombre_completo": "Gael Vazquez Flores", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:45.815426+00	\N	Auditoría automática vía trigger fn_audit_trigger
96	\N	UPDATE	usuario	3	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-15T19:44:47.838154+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-15T20:28:05.589+00:00", "actualizado_en": "2026-06-15T20:28:05.603484+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-15 20:28:05.603484+00	\N	Auditoría automática vía trigger fn_audit_trigger
97	\N	UPDATE	usuario	3	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-15T20:28:05.589+00:00", "actualizado_en": "2026-06-15T20:28:05.603484+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-15T20:28:22.721+00:00", "actualizado_en": "2026-06-15T20:28:22.723119+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-15 20:28:22.723119+00	\N	Auditoría automática vía trigger fn_audit_trigger
98	\N	UPDATE	usuario	3	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-15T20:28:22.721+00:00", "actualizado_en": "2026-06-15T20:28:22.723119+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-15T20:28:35.083+00:00", "actualizado_en": "2026-06-15T20:28:35.088505+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-15 20:28:35.088505+00	\N	Auditoría automática vía trigger fn_audit_trigger
99	\N	UPDATE	usuario	3	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-15T20:28:35.083+00:00", "actualizado_en": "2026-06-15T20:28:35.088505+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-15T20:28:58.367+00:00", "actualizado_en": "2026-06-15T20:28:58.370075+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-15 20:28:58.370075+00	\N	Auditoría automática vía trigger fn_audit_trigger
100	\N	UPDATE	usuario	3	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-15T20:28:58.367+00:00", "actualizado_en": "2026-06-15T20:28:58.370075+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-15T20:29:20.354+00:00", "actualizado_en": "2026-06-15T20:29:20.356638+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-15 20:29:20.356638+00	\N	Auditoría automática vía trigger fn_audit_trigger
101	\N	UPDATE	usuario	3	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-15T20:29:20.354+00:00", "actualizado_en": "2026-06-15T20:29:20.356638+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-15T20:30:16.585+00:00", "actualizado_en": "2026-06-15T20:30:16.586813+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-15 20:30:16.586813+00	\N	Auditoría automática vía trigger fn_audit_trigger
102	\N	UPDATE	usuario	3	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-15T20:30:16.585+00:00", "actualizado_en": "2026-06-15T20:30:16.586813+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-15T20:31:00.591+00:00", "actualizado_en": "2026-06-15T20:31:00.591647+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-15 20:31:00.591647+00	\N	Auditoría automática vía trigger fn_audit_trigger
103	\N	UPDATE	usuario	3	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-15T20:31:00.591+00:00", "actualizado_en": "2026-06-15T20:31:00.591647+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-15T20:32:49.147+00:00", "actualizado_en": "2026-06-15T20:32:49.155029+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-15 20:32:49.155029+00	\N	Auditoría automática vía trigger fn_audit_trigger
104	\N	UPDATE	usuario	3	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-15T20:32:49.147+00:00", "actualizado_en": "2026-06-15T20:32:49.155029+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-15T20:33:50.699+00:00", "actualizado_en": "2026-06-15T20:33:50.701592+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-15 20:33:50.701592+00	\N	Auditoría automática vía trigger fn_audit_trigger
105	\N	UPDATE	usuario	3	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-15T20:33:50.699+00:00", "actualizado_en": "2026-06-15T20:33:50.701592+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-15T20:36:00.113+00:00", "actualizado_en": "2026-06-15T20:36:00.118613+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-15 20:36:00.118613+00	\N	Auditoría automática vía trigger fn_audit_trigger
106	6	INSERT	alumno	19	\N	{"curp": null, "sexo": null, "estado": "Activo", "nivel_id": null, "alumno_id": 19, "creado_en": "2026-06-15T20:45:49.845+00:00", "matricula": "SDM-2018-0002", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:45:49.845+00:00", "dia_limite_pago": null, "nombre_completo": "pakito", "fecha_nacimiento": "2024-09-17", "personas_autorizadas": []}	2026-06-15 20:45:49.834302+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
107	\N	INSERT	alumno	20	\N	{"curp": "TEST22941HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 20, "creado_en": "2026-06-15T20:51:50.023+00:00", "matricula": "TST-PRI-2A-HCE3-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:51:50.023+00:00", "dia_limite_pago": null, "nombre_completo": "Mia Martinez Martinez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:51:50.027052+00	\N	Auditoría automática vía trigger fn_audit_trigger
108	\N	INSERT	alumno	21	\N	{"curp": "TEST54862HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 21, "creado_en": "2026-06-15T20:52:07.927+00:00", "matricula": "TST-PRI-2A-BFF4-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:07.927+00:00", "dia_limite_pago": null, "nombre_completo": "Jose Reyes Sanchez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:07.928124+00	\N	Auditoría automática vía trigger fn_audit_trigger
109	\N	INSERT	alumno	22	\N	{"curp": "TEST76673HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 22, "creado_en": "2026-06-15T20:52:07.968+00:00", "matricula": "TST-PRI-2A-MJHC-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:07.968+00:00", "dia_limite_pago": null, "nombre_completo": "Daniel Diaz Ramirez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:07.96782+00	\N	Auditoría automática vía trigger fn_audit_trigger
110	\N	INSERT	alumno	23	\N	{"curp": "TEST34830HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 23, "creado_en": "2026-06-15T20:52:45.655+00:00", "matricula": "TST-PRI-2A-CEHQ-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:45.655+00:00", "dia_limite_pago": null, "nombre_completo": "Valeria Sanchez Diaz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:45.658786+00	\N	Auditoría automática vía trigger fn_audit_trigger
111	\N	INSERT	alumno	24	\N	{"curp": "TEST12633HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 24, "creado_en": "2026-06-15T20:52:45.707+00:00", "matricula": "TST-PRI-2A-8GQB-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:45.707+00:00", "dia_limite_pago": null, "nombre_completo": "Maria Garcia Morales", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:45.708294+00	\N	Auditoría automática vía trigger fn_audit_trigger
112	\N	INSERT	alumno	25	\N	{"curp": "TEST20103HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 25, "creado_en": "2026-06-15T20:52:45.728+00:00", "matricula": "TST-PRI-2A-DBOC-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:45.728+00:00", "dia_limite_pago": null, "nombre_completo": "Sebastian Ramirez Martinez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:45.729249+00	\N	Auditoría automática vía trigger fn_audit_trigger
113	\N	INSERT	alumno	26	\N	{"curp": "TEST15455HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 26, "creado_en": "2026-06-15T20:52:45.754+00:00", "matricula": "TST-PRI-2A-UA1Y-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:45.754+00:00", "dia_limite_pago": null, "nombre_completo": "Renata Reyes Jimenez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:45.755095+00	\N	Auditoría automática vía trigger fn_audit_trigger
114	\N	INSERT	alumno	27	\N	{"curp": "TEST34522HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 27, "creado_en": "2026-06-15T20:52:45.776+00:00", "matricula": "TST-PRI-2A-RZ3Z-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:45.776+00:00", "dia_limite_pago": null, "nombre_completo": "Nicolas Vazquez Gonzalez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:45.777978+00	\N	Auditoría automática vía trigger fn_audit_trigger
115	\N	INSERT	alumno	28	\N	{"curp": "TEST8319HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 28, "creado_en": "2026-06-15T20:52:45.797+00:00", "matricula": "TST-PRI-2A-0UA0-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:45.797+00:00", "dia_limite_pago": null, "nombre_completo": "Isabella Flores Reyes", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:45.797626+00	\N	Auditoría automática vía trigger fn_audit_trigger
117	\N	INSERT	alumno	30	\N	{"curp": "TEST50217HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 30, "creado_en": "2026-06-15T20:52:45.835+00:00", "matricula": "TST-PRI-2A-RBEV-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:45.835+00:00", "dia_limite_pago": null, "nombre_completo": "Matias Lopez Cruz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:45.835599+00	\N	Auditoría automática vía trigger fn_audit_trigger
118	\N	INSERT	alumno	31	\N	{"curp": "TEST80522HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 31, "creado_en": "2026-06-15T20:52:45.855+00:00", "matricula": "TST-PRI-2A-V8J0-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:45.855+00:00", "dia_limite_pago": null, "nombre_completo": "Leonardo Ramirez Vazquez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:45.855785+00	\N	Auditoría automática vía trigger fn_audit_trigger
119	\N	INSERT	alumno	32	\N	{"curp": "TEST17044HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 32, "creado_en": "2026-06-15T20:52:45.876+00:00", "matricula": "TST-PRI-2A-IG1Q-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:45.876+00:00", "dia_limite_pago": null, "nombre_completo": "Emiliano Jimenez Diaz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:45.876634+00	\N	Auditoría automática vía trigger fn_audit_trigger
120	\N	INSERT	alumno	33	\N	{"curp": "TEST10729HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 33, "creado_en": "2026-06-15T20:52:45.897+00:00", "matricula": "TST-PRI-3A-JF45-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:45.897+00:00", "dia_limite_pago": null, "nombre_completo": "Mia Gomez Sanchez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:45.898012+00	\N	Auditoría automática vía trigger fn_audit_trigger
121	\N	INSERT	alumno	34	\N	{"curp": "TEST71409HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 34, "creado_en": "2026-06-15T20:52:45.918+00:00", "matricula": "TST-PRI-3A-6E8Z-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:45.918+00:00", "dia_limite_pago": null, "nombre_completo": "Diego Reyes Reyes", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:45.919055+00	\N	Auditoría automática vía trigger fn_audit_trigger
122	\N	INSERT	alumno	35	\N	{"curp": "TEST82676HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 35, "creado_en": "2026-06-15T20:52:45.939+00:00", "matricula": "TST-PRI-3A-QWKQ-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:45.939+00:00", "dia_limite_pago": null, "nombre_completo": "Regina Ramirez Ramirez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:45.94043+00	\N	Auditoría automática vía trigger fn_audit_trigger
123	\N	INSERT	alumno	36	\N	{"curp": "TEST78599HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 36, "creado_en": "2026-06-15T20:52:45.967+00:00", "matricula": "TST-PRI-3A-GN3C-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:45.967+00:00", "dia_limite_pago": null, "nombre_completo": "Emiliano Garcia Garcia", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:45.968202+00	\N	Auditoría automática vía trigger fn_audit_trigger
124	\N	INSERT	alumno	37	\N	{"curp": "TEST60768HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 37, "creado_en": "2026-06-15T20:52:45.997+00:00", "matricula": "TST-PRI-3A-2ZH3-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:45.997+00:00", "dia_limite_pago": null, "nombre_completo": "Diego Flores Reyes", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:45.997473+00	\N	Auditoría automática vía trigger fn_audit_trigger
125	\N	INSERT	alumno	38	\N	{"curp": "TEST51108HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 38, "creado_en": "2026-06-15T20:52:46.017+00:00", "matricula": "TST-PRI-3A-ATQ4-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.017+00:00", "dia_limite_pago": null, "nombre_completo": "Santiago Vazquez Reyes", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.017423+00	\N	Auditoría automática vía trigger fn_audit_trigger
126	\N	INSERT	alumno	39	\N	{"curp": "TEST59199HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 39, "creado_en": "2026-06-15T20:52:46.039+00:00", "matricula": "TST-PRI-3A-2BAH-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.039+00:00", "dia_limite_pago": null, "nombre_completo": "Mateo Diaz Diaz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.039923+00	\N	Auditoría automática vía trigger fn_audit_trigger
127	\N	INSERT	alumno	40	\N	{"curp": "TEST87339HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 40, "creado_en": "2026-06-15T20:52:46.057+00:00", "matricula": "TST-PRI-3A-S2W0-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.057+00:00", "dia_limite_pago": null, "nombre_completo": "Natalia Martinez Flores", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.058435+00	\N	Auditoría automática vía trigger fn_audit_trigger
128	\N	INSERT	alumno	41	\N	{"curp": "TEST71356HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 41, "creado_en": "2026-06-15T20:52:46.076+00:00", "matricula": "TST-PRI-3A-X7S4-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.076+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Flores Diaz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.077008+00	\N	Auditoría automática vía trigger fn_audit_trigger
129	\N	INSERT	alumno	42	\N	{"curp": "TEST3129HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 42, "creado_en": "2026-06-15T20:52:46.099+00:00", "matricula": "TST-PRI-3A-2ALP-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.099+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Cruz Martinez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.100394+00	\N	Auditoría automática vía trigger fn_audit_trigger
130	\N	INSERT	alumno	43	\N	{"curp": "TEST87873HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 43, "creado_en": "2026-06-15T20:52:46.12+00:00", "matricula": "TST-PRI-4A-Z01D-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.12+00:00", "dia_limite_pago": null, "nombre_completo": "Renata Flores Martinez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.121245+00	\N	Auditoría automática vía trigger fn_audit_trigger
131	\N	INSERT	alumno	44	\N	{"curp": "TEST44671HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 44, "creado_en": "2026-06-15T20:52:46.138+00:00", "matricula": "TST-PRI-4A-XNOJ-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.138+00:00", "dia_limite_pago": null, "nombre_completo": "Mateo Martinez Diaz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.139041+00	\N	Auditoría automática vía trigger fn_audit_trigger
132	\N	INSERT	alumno	45	\N	{"curp": "TEST73669HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 45, "creado_en": "2026-06-15T20:52:46.185+00:00", "matricula": "TST-PRI-4A-YLTA-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.185+00:00", "dia_limite_pago": null, "nombre_completo": "Matias Ramirez Perez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.185446+00	\N	Auditoría automática vía trigger fn_audit_trigger
133	\N	INSERT	alumno	46	\N	{"curp": "TEST38059HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 46, "creado_en": "2026-06-15T20:52:46.207+00:00", "matricula": "TST-PRI-4A-T6IE-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.207+00:00", "dia_limite_pago": null, "nombre_completo": "Santiago Martinez Martinez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.207796+00	\N	Auditoría automática vía trigger fn_audit_trigger
134	\N	INSERT	alumno	47	\N	{"curp": "TEST34122HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 47, "creado_en": "2026-06-15T20:52:46.225+00:00", "matricula": "TST-PRI-4A-53SC-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.225+00:00", "dia_limite_pago": null, "nombre_completo": "Sofia Morales Gonzalez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.226115+00	\N	Auditoría automática vía trigger fn_audit_trigger
135	\N	INSERT	alumno	48	\N	{"curp": "TEST74715HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 48, "creado_en": "2026-06-15T20:52:46.247+00:00", "matricula": "TST-PRI-4A-4C9Z-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.247+00:00", "dia_limite_pago": null, "nombre_completo": "Gabriel Ramirez Garcia", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.248384+00	\N	Auditoría automática vía trigger fn_audit_trigger
136	\N	INSERT	alumno	49	\N	{"curp": "TEST43716HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 49, "creado_en": "2026-06-15T20:52:46.262+00:00", "matricula": "TST-PRI-4A-00BT-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.262+00:00", "dia_limite_pago": null, "nombre_completo": "Mia Vazquez Lopez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.263182+00	\N	Auditoría automática vía trigger fn_audit_trigger
137	\N	INSERT	alumno	50	\N	{"curp": "TEST5302HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 50, "creado_en": "2026-06-15T20:52:46.282+00:00", "matricula": "TST-PRI-4A-TK9S-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.282+00:00", "dia_limite_pago": null, "nombre_completo": "Isabella Gonzalez Cruz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.282835+00	\N	Auditoría automática vía trigger fn_audit_trigger
138	\N	INSERT	alumno	51	\N	{"curp": "TEST50711HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 51, "creado_en": "2026-06-15T20:52:46.303+00:00", "matricula": "TST-PRI-4A-K1WR-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.303+00:00", "dia_limite_pago": null, "nombre_completo": "Renata Garcia Morales", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.303927+00	\N	Auditoría automática vía trigger fn_audit_trigger
139	\N	INSERT	alumno	52	\N	{"curp": "TEST74714HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 52, "creado_en": "2026-06-15T20:52:46.326+00:00", "matricula": "TST-PRI-4A-695I-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.326+00:00", "dia_limite_pago": null, "nombre_completo": "Valentina Ramirez Morales", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.326557+00	\N	Auditoría automática vía trigger fn_audit_trigger
140	\N	INSERT	alumno	53	\N	{"curp": "TEST13413HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 53, "creado_en": "2026-06-15T20:52:46.344+00:00", "matricula": "TST-PRI-5A-0QR8-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.344+00:00", "dia_limite_pago": null, "nombre_completo": "Valentina Morales Martinez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.344747+00	\N	Auditoría automática vía trigger fn_audit_trigger
141	\N	INSERT	alumno	54	\N	{"curp": "TEST58709HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 54, "creado_en": "2026-06-15T20:52:46.358+00:00", "matricula": "TST-PRI-5A-7N51-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.358+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Martinez Rodriguez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.35916+00	\N	Auditoría automática vía trigger fn_audit_trigger
142	\N	INSERT	alumno	55	\N	{"curp": "TEST24231HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 55, "creado_en": "2026-06-15T20:52:46.377+00:00", "matricula": "TST-PRI-5A-K694-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.377+00:00", "dia_limite_pago": null, "nombre_completo": "Matias Perez Morales", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.37839+00	\N	Auditoría automática vía trigger fn_audit_trigger
143	\N	INSERT	alumno	56	\N	{"curp": "TEST65469HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 56, "creado_en": "2026-06-15T20:52:46.403+00:00", "matricula": "TST-PRI-5A-G4V5-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.403+00:00", "dia_limite_pago": null, "nombre_completo": "Santiago Garcia Diaz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.403783+00	\N	Auditoría automática vía trigger fn_audit_trigger
374	7	INSERT	usuario_rol	23	\N	{"activo": true, "rol_id": 1, "creado_en": "2026-06-16T09:18:53.285+00:00", "usuario_id": 20, "asignado_en": "2026-06-16T09:18:53.285+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-16T09:18:53.285+00:00", "usuario_rol_id": 23}	2026-06-16 09:18:53.277069+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
144	\N	INSERT	alumno	57	\N	{"curp": "TEST45694HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 57, "creado_en": "2026-06-15T20:52:46.42+00:00", "matricula": "TST-PRI-5A-1RJJ-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.42+00:00", "dia_limite_pago": null, "nombre_completo": "Victoria Ramirez Perez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.421404+00	\N	Auditoría automática vía trigger fn_audit_trigger
145	\N	INSERT	alumno	58	\N	{"curp": "TEST75101HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 58, "creado_en": "2026-06-15T20:52:46.439+00:00", "matricula": "TST-PRI-5A-NL13-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.439+00:00", "dia_limite_pago": null, "nombre_completo": "Camila Vazquez Rodriguez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.439775+00	\N	Auditoría automática vía trigger fn_audit_trigger
146	\N	INSERT	alumno	59	\N	{"curp": "TEST97347HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 59, "creado_en": "2026-06-15T20:52:46.459+00:00", "matricula": "TST-PRI-5A-BYRC-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.459+00:00", "dia_limite_pago": null, "nombre_completo": "Leonardo Gomez Cruz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.460139+00	\N	Auditoría automática vía trigger fn_audit_trigger
147	\N	INSERT	alumno	60	\N	{"curp": "TEST7329HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 60, "creado_en": "2026-06-15T20:52:46.477+00:00", "matricula": "TST-PRI-5A-OPL2-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.477+00:00", "dia_limite_pago": null, "nombre_completo": "Renata Martinez Gomez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.478168+00	\N	Auditoría automática vía trigger fn_audit_trigger
148	\N	INSERT	alumno	61	\N	{"curp": "TEST17281HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 61, "creado_en": "2026-06-15T20:52:46.496+00:00", "matricula": "TST-PRI-5A-9YCT-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.496+00:00", "dia_limite_pago": null, "nombre_completo": "Sebastian Vazquez Flores", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.496753+00	\N	Auditoría automática vía trigger fn_audit_trigger
149	\N	INSERT	alumno	62	\N	{"curp": "TEST78143HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 62, "creado_en": "2026-06-15T20:52:46.516+00:00", "matricula": "TST-PRI-5A-G0JK-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.516+00:00", "dia_limite_pago": null, "nombre_completo": "Santiago Reyes Ramirez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.516897+00	\N	Auditoría automática vía trigger fn_audit_trigger
150	\N	INSERT	alumno	63	\N	{"curp": "TEST37870HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 63, "creado_en": "2026-06-15T20:52:46.532+00:00", "matricula": "TST-PRI-6A-H76B-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.532+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Vazquez Reyes", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.532577+00	\N	Auditoría automática vía trigger fn_audit_trigger
151	\N	INSERT	alumno	64	\N	{"curp": "TEST61711HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 64, "creado_en": "2026-06-15T20:52:46.551+00:00", "matricula": "TST-PRI-6A-WXK9-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.551+00:00", "dia_limite_pago": null, "nombre_completo": "Santiago Morales Lopez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.55172+00	\N	Auditoría automática vía trigger fn_audit_trigger
152	\N	INSERT	alumno	65	\N	{"curp": "TEST88617HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 65, "creado_en": "2026-06-15T20:52:46.57+00:00", "matricula": "TST-PRI-6A-UPWW-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.57+00:00", "dia_limite_pago": null, "nombre_completo": "Natalia Sanchez Vazquez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.571454+00	\N	Auditoría automática vía trigger fn_audit_trigger
153	\N	INSERT	alumno	66	\N	{"curp": "TEST29900HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 66, "creado_en": "2026-06-15T20:52:46.589+00:00", "matricula": "TST-PRI-6A-XBLB-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.589+00:00", "dia_limite_pago": null, "nombre_completo": "Valentina Diaz Morales", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.589693+00	\N	Auditoría automática vía trigger fn_audit_trigger
154	\N	INSERT	alumno	67	\N	{"curp": "TEST1572HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 67, "creado_en": "2026-06-15T20:52:46.604+00:00", "matricula": "TST-PRI-6A-4NSB-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.604+00:00", "dia_limite_pago": null, "nombre_completo": "Sebastian Lopez Jimenez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.605488+00	\N	Auditoría automática vía trigger fn_audit_trigger
155	\N	INSERT	alumno	68	\N	{"curp": "TEST88775HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 68, "creado_en": "2026-06-15T20:52:46.624+00:00", "matricula": "TST-PRI-6A-8PUY-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.624+00:00", "dia_limite_pago": null, "nombre_completo": "Gabriel Vazquez Martinez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.624907+00	\N	Auditoría automática vía trigger fn_audit_trigger
156	\N	INSERT	alumno	69	\N	{"curp": "TEST22042HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 69, "creado_en": "2026-06-15T20:52:46.638+00:00", "matricula": "TST-PRI-6A-6MTV-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.638+00:00", "dia_limite_pago": null, "nombre_completo": "Valeria Garcia Flores", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.639232+00	\N	Auditoría automática vía trigger fn_audit_trigger
157	\N	INSERT	alumno	70	\N	{"curp": "TEST41806HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 70, "creado_en": "2026-06-15T20:52:46.659+00:00", "matricula": "TST-PRI-6A-SLP1-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.659+00:00", "dia_limite_pago": null, "nombre_completo": "Renata Rodriguez Garcia", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.660318+00	\N	Auditoría automática vía trigger fn_audit_trigger
158	\N	INSERT	alumno	71	\N	{"curp": "TEST41888HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 71, "creado_en": "2026-06-15T20:52:46.684+00:00", "matricula": "TST-PRI-6A-TZ3A-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.684+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Reyes Cruz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.684621+00	\N	Auditoría automática vía trigger fn_audit_trigger
159	\N	INSERT	alumno	72	\N	{"curp": "TEST93575HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 72, "creado_en": "2026-06-15T20:52:46.706+00:00", "matricula": "TST-PRI-6A-ELCX-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.706+00:00", "dia_limite_pago": null, "nombre_completo": "Gabriel Jimenez Reyes", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.70694+00	\N	Auditoría automática vía trigger fn_audit_trigger
160	\N	INSERT	alumno	73	\N	{"curp": "TEST23636HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 73, "creado_en": "2026-06-15T20:52:46.727+00:00", "matricula": "TST-SEC-1A-5BTC-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.727+00:00", "dia_limite_pago": null, "nombre_completo": "Renata Martinez Ramirez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.72754+00	\N	Auditoría automática vía trigger fn_audit_trigger
161	\N	INSERT	alumno	74	\N	{"curp": "TEST39012HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 74, "creado_en": "2026-06-15T20:52:46.744+00:00", "matricula": "TST-SEC-1A-W0H1-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.744+00:00", "dia_limite_pago": null, "nombre_completo": "Daniel Rodriguez Gomez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.744685+00	\N	Auditoría automática vía trigger fn_audit_trigger
162	\N	INSERT	alumno	75	\N	{"curp": "TEST40080HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 75, "creado_en": "2026-06-15T20:52:46.768+00:00", "matricula": "TST-SEC-1A-4PBT-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.768+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Cruz Ramirez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.769041+00	\N	Auditoría automática vía trigger fn_audit_trigger
163	\N	INSERT	alumno	76	\N	{"curp": "TEST91964HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 76, "creado_en": "2026-06-15T20:52:46.788+00:00", "matricula": "TST-SEC-1A-ED7X-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.788+00:00", "dia_limite_pago": null, "nombre_completo": "Daniel Vazquez Flores", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.788582+00	\N	Auditoría automática vía trigger fn_audit_trigger
164	\N	INSERT	alumno	77	\N	{"curp": "TEST35708HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 77, "creado_en": "2026-06-15T20:52:46.802+00:00", "matricula": "TST-SEC-1A-Y29U-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.802+00:00", "dia_limite_pago": null, "nombre_completo": "Gael Ramirez Flores", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.802645+00	\N	Auditoría automática vía trigger fn_audit_trigger
165	\N	INSERT	alumno	78	\N	{"curp": "TEST9319HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 78, "creado_en": "2026-06-15T20:52:46.821+00:00", "matricula": "TST-SEC-1A-HSX7-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.821+00:00", "dia_limite_pago": null, "nombre_completo": "Emiliano Perez Flores", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.822111+00	\N	Auditoría automática vía trigger fn_audit_trigger
166	\N	INSERT	alumno	79	\N	{"curp": "TEST81999HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 79, "creado_en": "2026-06-15T20:52:46.843+00:00", "matricula": "TST-SEC-1A-JNLP-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.843+00:00", "dia_limite_pago": null, "nombre_completo": "Mia Morales Ramirez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.844003+00	\N	Auditoría automática vía trigger fn_audit_trigger
167	\N	INSERT	alumno	80	\N	{"curp": "TEST17408HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 80, "creado_en": "2026-06-15T20:52:46.863+00:00", "matricula": "TST-SEC-1A-YKGG-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.863+00:00", "dia_limite_pago": null, "nombre_completo": "Thiago Lopez Vazquez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.864355+00	\N	Auditoría automática vía trigger fn_audit_trigger
168	\N	INSERT	alumno	81	\N	{"curp": "TEST20304HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 81, "creado_en": "2026-06-15T20:52:46.881+00:00", "matricula": "TST-SEC-1A-3OMS-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.881+00:00", "dia_limite_pago": null, "nombre_completo": "Jose Rodriguez Lopez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.881816+00	\N	Auditoría automática vía trigger fn_audit_trigger
169	\N	INSERT	alumno	82	\N	{"curp": "TEST49428HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 82, "creado_en": "2026-06-15T20:52:46.897+00:00", "matricula": "TST-SEC-1A-L1F2-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.897+00:00", "dia_limite_pago": null, "nombre_completo": "Thiago Reyes Perez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.897521+00	\N	Auditoría automática vía trigger fn_audit_trigger
170	\N	INSERT	alumno	83	\N	{"curp": "TEST36537HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 83, "creado_en": "2026-06-15T20:52:46.917+00:00", "matricula": "TST-SEC-2A-JXPG-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.917+00:00", "dia_limite_pago": null, "nombre_completo": "Leonardo Rodriguez Gonzalez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.918438+00	\N	Auditoría automática vía trigger fn_audit_trigger
171	\N	INSERT	alumno	84	\N	{"curp": "TEST29261HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 84, "creado_en": "2026-06-15T20:52:46.937+00:00", "matricula": "TST-SEC-2A-L2P4-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.937+00:00", "dia_limite_pago": null, "nombre_completo": "Natalia Gonzalez Lopez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.938301+00	\N	Auditoría automática vía trigger fn_audit_trigger
172	\N	INSERT	alumno	85	\N	{"curp": "TEST28241HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 85, "creado_en": "2026-06-15T20:52:46.96+00:00", "matricula": "TST-SEC-2A-Z0YX-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.96+00:00", "dia_limite_pago": null, "nombre_completo": "Mateo Cruz Morales", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.961322+00	\N	Auditoría automática vía trigger fn_audit_trigger
173	\N	INSERT	alumno	86	\N	{"curp": "TEST67509HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 86, "creado_en": "2026-06-15T20:52:46.977+00:00", "matricula": "TST-SEC-2A-56XF-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.977+00:00", "dia_limite_pago": null, "nombre_completo": "Isabella Flores Diaz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.978598+00	\N	Auditoría automática vía trigger fn_audit_trigger
174	\N	INSERT	alumno	87	\N	{"curp": "TEST39124HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 87, "creado_en": "2026-06-15T20:52:46.994+00:00", "matricula": "TST-SEC-2A-HJ6X-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.994+00:00", "dia_limite_pago": null, "nombre_completo": "Sofia Diaz Martinez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:46.99456+00	\N	Auditoría automática vía trigger fn_audit_trigger
175	\N	INSERT	alumno	88	\N	{"curp": "TEST12409HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 88, "creado_en": "2026-06-15T20:52:47.014+00:00", "matricula": "TST-SEC-2A-AWQT-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:47.014+00:00", "dia_limite_pago": null, "nombre_completo": "Mateo Vazquez Flores", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:47.015039+00	\N	Auditoría automática vía trigger fn_audit_trigger
176	\N	INSERT	alumno	89	\N	{"curp": "TEST6414HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 89, "creado_en": "2026-06-15T20:52:47.033+00:00", "matricula": "TST-SEC-2A-9MOU-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:47.033+00:00", "dia_limite_pago": null, "nombre_completo": "Gael Jimenez Gonzalez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:47.03373+00	\N	Auditoría automática vía trigger fn_audit_trigger
177	\N	INSERT	alumno	90	\N	{"curp": "TEST57148HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 90, "creado_en": "2026-06-15T20:52:47.05+00:00", "matricula": "TST-SEC-2A-CIJP-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:47.05+00:00", "dia_limite_pago": null, "nombre_completo": "Matias Reyes Reyes", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:47.05065+00	\N	Auditoría automática vía trigger fn_audit_trigger
178	\N	INSERT	alumno	91	\N	{"curp": "TEST4337HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 91, "creado_en": "2026-06-15T20:52:47.07+00:00", "matricula": "TST-SEC-2A-1CXL-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:47.07+00:00", "dia_limite_pago": null, "nombre_completo": "Gabriel Morales Gomez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:47.071503+00	\N	Auditoría automática vía trigger fn_audit_trigger
179	\N	INSERT	alumno	92	\N	{"curp": "TEST76578HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 92, "creado_en": "2026-06-15T20:52:47.091+00:00", "matricula": "TST-SEC-2A-9B3A-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:47.091+00:00", "dia_limite_pago": null, "nombre_completo": "Sebastian Flores Rodriguez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:47.092115+00	\N	Auditoría automática vía trigger fn_audit_trigger
180	\N	INSERT	alumno	93	\N	{"curp": "TEST54318HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 93, "creado_en": "2026-06-15T20:52:47.111+00:00", "matricula": "TST-SEC-3A-4RXN-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:47.111+00:00", "dia_limite_pago": null, "nombre_completo": "Emiliano Flores Gonzalez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:47.111676+00	\N	Auditoría automática vía trigger fn_audit_trigger
181	\N	INSERT	alumno	94	\N	{"curp": "TEST13180HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 94, "creado_en": "2026-06-15T20:52:47.129+00:00", "matricula": "TST-SEC-3A-9BBZ-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:47.129+00:00", "dia_limite_pago": null, "nombre_completo": "Ximena Gonzalez Garcia", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:47.13029+00	\N	Auditoría automática vía trigger fn_audit_trigger
182	\N	INSERT	alumno	95	\N	{"curp": "TEST93135HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 95, "creado_en": "2026-06-15T20:52:47.149+00:00", "matricula": "TST-SEC-3A-SLRT-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:47.149+00:00", "dia_limite_pago": null, "nombre_completo": "Jose Reyes Jimenez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:47.149395+00	\N	Auditoría automática vía trigger fn_audit_trigger
183	\N	INSERT	alumno	96	\N	{"curp": "TEST22097HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 96, "creado_en": "2026-06-15T20:52:47.169+00:00", "matricula": "TST-SEC-3A-7PAP-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:47.169+00:00", "dia_limite_pago": null, "nombre_completo": "Valentina Martinez Vazquez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:47.17023+00	\N	Auditoría automática vía trigger fn_audit_trigger
184	\N	INSERT	alumno	97	\N	{"curp": "TEST83400HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 97, "creado_en": "2026-06-15T20:52:47.191+00:00", "matricula": "TST-SEC-3A-PMJD-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:47.191+00:00", "dia_limite_pago": null, "nombre_completo": "Ximena Cruz Ramirez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:47.192156+00	\N	Auditoría automática vía trigger fn_audit_trigger
185	\N	INSERT	alumno	98	\N	{"curp": "TEST92388HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 98, "creado_en": "2026-06-15T20:52:47.208+00:00", "matricula": "TST-SEC-3A-WX8D-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:47.208+00:00", "dia_limite_pago": null, "nombre_completo": "Maria Jimenez Martinez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:47.209107+00	\N	Auditoría automática vía trigger fn_audit_trigger
186	\N	INSERT	alumno	99	\N	{"curp": "TEST22180HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 99, "creado_en": "2026-06-15T20:52:47.229+00:00", "matricula": "TST-SEC-3A-TZQH-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:47.229+00:00", "dia_limite_pago": null, "nombre_completo": "Renata Sanchez Gomez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:47.230404+00	\N	Auditoría automática vía trigger fn_audit_trigger
187	\N	INSERT	alumno	100	\N	{"curp": "TEST79312HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 100, "creado_en": "2026-06-15T20:52:47.246+00:00", "matricula": "TST-SEC-3A-3FQF-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:47.246+00:00", "dia_limite_pago": null, "nombre_completo": "Valeria Sanchez Vazquez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:47.24677+00	\N	Auditoría automática vía trigger fn_audit_trigger
188	\N	INSERT	alumno	101	\N	{"curp": "TEST68786HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 101, "creado_en": "2026-06-15T20:52:47.268+00:00", "matricula": "TST-SEC-3A-BT91-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:47.268+00:00", "dia_limite_pago": null, "nombre_completo": "Valeria Garcia Ramirez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:47.268794+00	\N	Auditoría automática vía trigger fn_audit_trigger
189	\N	INSERT	alumno	102	\N	{"curp": "TEST80312HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 102, "creado_en": "2026-06-15T20:52:47.288+00:00", "matricula": "TST-SEC-3A-I3TU-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:47.288+00:00", "dia_limite_pago": null, "nombre_completo": "Jose Jimenez Martinez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:47.288604+00	\N	Auditoría automática vía trigger fn_audit_trigger
190	\N	INSERT	alumno	103	\N	{"curp": "TEST52135HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 103, "creado_en": "2026-06-15T20:52:47.312+00:00", "matricula": "TST-PRI-4A-LBDD-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:47.312+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Vazquez Flores", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:52:47.312987+00	\N	Auditoría automática vía trigger fn_audit_trigger
191	\N	INSERT	alumno	104	\N	{"curp": "TEST99436HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 104, "creado_en": "2026-06-15T20:53:07.836+00:00", "matricula": "TST-PRI-2A-NH96-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:07.836+00:00", "dia_limite_pago": null, "nombre_completo": "Leonardo Reyes Sanchez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:07.838081+00	\N	Auditoría automática vía trigger fn_audit_trigger
192	\N	INSERT	alumno	105	\N	{"curp": "TEST17120HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 105, "creado_en": "2026-06-15T20:53:07.934+00:00", "matricula": "TST-PRI-2A-UY1Y-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:07.934+00:00", "dia_limite_pago": null, "nombre_completo": "Santiago Sanchez Jimenez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:07.935103+00	\N	Auditoría automática vía trigger fn_audit_trigger
193	\N	INSERT	alumno	106	\N	{"curp": "TEST75955HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 106, "creado_en": "2026-06-15T20:53:07.956+00:00", "matricula": "TST-PRI-2A-IIBU-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:07.956+00:00", "dia_limite_pago": null, "nombre_completo": "Isabella Reyes Rodriguez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:07.957058+00	\N	Auditoría automática vía trigger fn_audit_trigger
194	\N	INSERT	alumno	107	\N	{"curp": "TEST9954HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 107, "creado_en": "2026-06-15T20:53:07.98+00:00", "matricula": "TST-PRI-2A-IF7T-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:07.98+00:00", "dia_limite_pago": null, "nombre_completo": "Jose Gonzalez Gonzalez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:07.980387+00	\N	Auditoría automática vía trigger fn_audit_trigger
195	\N	INSERT	alumno	108	\N	{"curp": "TEST92775HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 108, "creado_en": "2026-06-15T20:53:08.002+00:00", "matricula": "TST-PRI-2A-JBEM-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.002+00:00", "dia_limite_pago": null, "nombre_completo": "Renata Ramirez Lopez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.002622+00	\N	Auditoría automática vía trigger fn_audit_trigger
196	\N	INSERT	alumno	109	\N	{"curp": "TEST31453HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 109, "creado_en": "2026-06-15T20:53:08.018+00:00", "matricula": "TST-PRI-2A-PWTA-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.018+00:00", "dia_limite_pago": null, "nombre_completo": "Renata Flores Sanchez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.01868+00	\N	Auditoría automática vía trigger fn_audit_trigger
197	\N	INSERT	alumno	110	\N	{"curp": "TEST42885HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 110, "creado_en": "2026-06-15T20:53:08.044+00:00", "matricula": "TST-PRI-2A-2LRM-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.044+00:00", "dia_limite_pago": null, "nombre_completo": "Isabella Jimenez Martinez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.044661+00	\N	Auditoría automática vía trigger fn_audit_trigger
198	\N	INSERT	alumno	111	\N	{"curp": "TEST51491HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 111, "creado_en": "2026-06-15T20:53:08.078+00:00", "matricula": "TST-PRI-2A-EA4S-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.078+00:00", "dia_limite_pago": null, "nombre_completo": "Emiliano Perez Rodriguez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.079225+00	\N	Auditoría automática vía trigger fn_audit_trigger
199	\N	INSERT	alumno	112	\N	{"curp": "TEST36161HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 112, "creado_en": "2026-06-15T20:53:08.124+00:00", "matricula": "TST-PRI-2A-JW6D-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.124+00:00", "dia_limite_pago": null, "nombre_completo": "Daniel Perez Cruz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.124873+00	\N	Auditoría automática vía trigger fn_audit_trigger
200	\N	INSERT	alumno	113	\N	{"curp": "TEST96051HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 113, "creado_en": "2026-06-15T20:53:08.157+00:00", "matricula": "TST-PRI-2A-4Q8E-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.157+00:00", "dia_limite_pago": null, "nombre_completo": "Camila Lopez Flores", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.15793+00	\N	Auditoría automática vía trigger fn_audit_trigger
201	\N	INSERT	alumno	114	\N	{"curp": "TEST1280HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 114, "creado_en": "2026-06-15T20:53:08.195+00:00", "matricula": "TST-PRI-3A-TOWP-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.195+00:00", "dia_limite_pago": null, "nombre_completo": "Santiago Gonzalez Flores", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.196085+00	\N	Auditoría automática vía trigger fn_audit_trigger
202	\N	INSERT	alumno	115	\N	{"curp": "TEST44694HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 115, "creado_en": "2026-06-15T20:53:08.221+00:00", "matricula": "TST-PRI-3A-ORLS-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.221+00:00", "dia_limite_pago": null, "nombre_completo": "Ximena Vazquez Reyes", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.221599+00	\N	Auditoría automática vía trigger fn_audit_trigger
203	\N	INSERT	alumno	116	\N	{"curp": "TEST1433HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 116, "creado_en": "2026-06-15T20:53:08.249+00:00", "matricula": "TST-PRI-3A-GHTN-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.249+00:00", "dia_limite_pago": null, "nombre_completo": "Matias Perez Gonzalez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.250213+00	\N	Auditoría automática vía trigger fn_audit_trigger
204	\N	INSERT	alumno	117	\N	{"curp": "TEST99483HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 117, "creado_en": "2026-06-15T20:53:08.27+00:00", "matricula": "TST-PRI-3A-LNZE-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.27+00:00", "dia_limite_pago": null, "nombre_completo": "Regina Lopez Sanchez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.270646+00	\N	Auditoría automática vía trigger fn_audit_trigger
205	\N	INSERT	alumno	118	\N	{"curp": "TEST38841HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 118, "creado_en": "2026-06-15T20:53:08.291+00:00", "matricula": "TST-PRI-3A-GI3H-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.291+00:00", "dia_limite_pago": null, "nombre_completo": "Maria Vazquez Lopez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.291809+00	\N	Auditoría automática vía trigger fn_audit_trigger
206	\N	INSERT	alumno	119	\N	{"curp": "TEST36836HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 119, "creado_en": "2026-06-15T20:53:08.307+00:00", "matricula": "TST-PRI-3A-IFFG-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.307+00:00", "dia_limite_pago": null, "nombre_completo": "Gael Garcia Perez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.308043+00	\N	Auditoría automática vía trigger fn_audit_trigger
207	\N	INSERT	alumno	120	\N	{"curp": "TEST23309HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 120, "creado_en": "2026-06-15T20:53:08.33+00:00", "matricula": "TST-PRI-3A-8VUP-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.33+00:00", "dia_limite_pago": null, "nombre_completo": "Sofia Lopez Jimenez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.330877+00	\N	Auditoría automática vía trigger fn_audit_trigger
208	\N	INSERT	alumno	121	\N	{"curp": "TEST95985HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 121, "creado_en": "2026-06-15T20:53:08.467+00:00", "matricula": "TST-PRI-3A-MH3E-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.467+00:00", "dia_limite_pago": null, "nombre_completo": "Santiago Gomez Gomez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.46722+00	\N	Auditoría automática vía trigger fn_audit_trigger
209	\N	INSERT	alumno	122	\N	{"curp": "TEST18727HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 122, "creado_en": "2026-06-15T20:53:08.491+00:00", "matricula": "TST-PRI-3A-HT9N-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.491+00:00", "dia_limite_pago": null, "nombre_completo": "Mateo Lopez Gomez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.491858+00	\N	Auditoría automática vía trigger fn_audit_trigger
210	\N	INSERT	alumno	123	\N	{"curp": "TEST13586HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 123, "creado_en": "2026-06-15T20:53:08.511+00:00", "matricula": "TST-PRI-3A-J52H-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.511+00:00", "dia_limite_pago": null, "nombre_completo": "Emiliano Ramirez Cruz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.511431+00	\N	Auditoría automática vía trigger fn_audit_trigger
211	\N	INSERT	alumno	124	\N	{"curp": "TEST94624HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 124, "creado_en": "2026-06-15T20:53:08.531+00:00", "matricula": "TST-PRI-4A-QLFQ-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.531+00:00", "dia_limite_pago": null, "nombre_completo": "Valeria Gomez Ramirez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.531745+00	\N	Auditoría automática vía trigger fn_audit_trigger
212	\N	INSERT	alumno	125	\N	{"curp": "TEST89761HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 125, "creado_en": "2026-06-15T20:53:08.553+00:00", "matricula": "TST-PRI-4A-BKU5-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.553+00:00", "dia_limite_pago": null, "nombre_completo": "Emiliano Morales Perez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.553842+00	\N	Auditoría automática vía trigger fn_audit_trigger
213	\N	INSERT	alumno	126	\N	{"curp": "TEST60572HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 126, "creado_en": "2026-06-15T20:53:08.584+00:00", "matricula": "TST-PRI-4A-ZCXA-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.584+00:00", "dia_limite_pago": null, "nombre_completo": "Isabella Diaz Garcia", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.584077+00	\N	Auditoría automática vía trigger fn_audit_trigger
214	\N	INSERT	alumno	127	\N	{"curp": "TEST32122HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 127, "creado_en": "2026-06-15T20:53:08.602+00:00", "matricula": "TST-PRI-4A-NTLD-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.602+00:00", "dia_limite_pago": null, "nombre_completo": "Leonardo Ramirez Diaz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.602824+00	\N	Auditoría automática vía trigger fn_audit_trigger
215	\N	INSERT	alumno	128	\N	{"curp": "TEST55041HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 128, "creado_en": "2026-06-15T20:53:08.626+00:00", "matricula": "TST-PRI-4A-OBZ8-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.626+00:00", "dia_limite_pago": null, "nombre_completo": "Regina Ramirez Gomez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.627138+00	\N	Auditoría automática vía trigger fn_audit_trigger
216	\N	INSERT	alumno	129	\N	{"curp": "TEST21181HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 129, "creado_en": "2026-06-15T20:53:08.645+00:00", "matricula": "TST-PRI-4A-D4PV-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.645+00:00", "dia_limite_pago": null, "nombre_completo": "Regina Martinez Cruz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.645892+00	\N	Auditoría automática vía trigger fn_audit_trigger
217	\N	INSERT	alumno	130	\N	{"curp": "TEST9976HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 130, "creado_en": "2026-06-15T20:53:08.663+00:00", "matricula": "TST-PRI-4A-8QE3-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.663+00:00", "dia_limite_pago": null, "nombre_completo": "Natalia Martinez Cruz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.663406+00	\N	Auditoría automática vía trigger fn_audit_trigger
218	\N	INSERT	alumno	131	\N	{"curp": "TEST76008HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 131, "creado_en": "2026-06-15T20:53:08.684+00:00", "matricula": "TST-PRI-4A-KKH5-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.684+00:00", "dia_limite_pago": null, "nombre_completo": "Thiago Lopez Gomez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.684194+00	\N	Auditoría automática vía trigger fn_audit_trigger
219	\N	INSERT	alumno	132	\N	{"curp": "TEST54319HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 132, "creado_en": "2026-06-15T20:53:08.704+00:00", "matricula": "TST-PRI-4A-B1XL-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.704+00:00", "dia_limite_pago": null, "nombre_completo": "Maria Morales Ramirez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.70412+00	\N	Auditoría automática vía trigger fn_audit_trigger
220	\N	INSERT	alumno	133	\N	{"curp": "TEST56036HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 133, "creado_en": "2026-06-15T20:53:08.721+00:00", "matricula": "TST-PRI-4A-J3XT-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.721+00:00", "dia_limite_pago": null, "nombre_completo": "Ximena Cruz Rodriguez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.721723+00	\N	Auditoría automática vía trigger fn_audit_trigger
221	\N	INSERT	alumno	134	\N	{"curp": "TEST12033HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 134, "creado_en": "2026-06-15T20:53:08.743+00:00", "matricula": "TST-PRI-5A-6APJ-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.743+00:00", "dia_limite_pago": null, "nombre_completo": "Gael Perez Perez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.743529+00	\N	Auditoría automática vía trigger fn_audit_trigger
222	\N	INSERT	alumno	135	\N	{"curp": "TEST69323HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 135, "creado_en": "2026-06-15T20:53:08.761+00:00", "matricula": "TST-PRI-5A-WARF-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.761+00:00", "dia_limite_pago": null, "nombre_completo": "Gael Lopez Perez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.76182+00	\N	Auditoría automática vía trigger fn_audit_trigger
223	\N	INSERT	alumno	136	\N	{"curp": "TEST63288HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 136, "creado_en": "2026-06-15T20:53:08.783+00:00", "matricula": "TST-PRI-5A-X5G2-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.783+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Reyes Vazquez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.783928+00	\N	Auditoría automática vía trigger fn_audit_trigger
224	\N	INSERT	alumno	137	\N	{"curp": "TEST83596HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 137, "creado_en": "2026-06-15T20:53:08.803+00:00", "matricula": "TST-PRI-5A-KLXC-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.803+00:00", "dia_limite_pago": null, "nombre_completo": "Gabriel Lopez Garcia", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.804013+00	\N	Auditoría automática vía trigger fn_audit_trigger
225	\N	INSERT	alumno	138	\N	{"curp": "TEST96274HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 138, "creado_en": "2026-06-15T20:53:08.827+00:00", "matricula": "TST-PRI-5A-SQPU-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.827+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Rodriguez Gomez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.827706+00	\N	Auditoría automática vía trigger fn_audit_trigger
226	\N	INSERT	alumno	139	\N	{"curp": "TEST76352HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 139, "creado_en": "2026-06-15T20:53:08.851+00:00", "matricula": "TST-PRI-5A-5YXG-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.851+00:00", "dia_limite_pago": null, "nombre_completo": "Daniel Ramirez Rodriguez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.851317+00	\N	Auditoría automática vía trigger fn_audit_trigger
227	\N	INSERT	alumno	140	\N	{"curp": "TEST68761HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 140, "creado_en": "2026-06-15T20:53:08.869+00:00", "matricula": "TST-PRI-5A-7XHQ-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.869+00:00", "dia_limite_pago": null, "nombre_completo": "Santiago Sanchez Gonzalez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.869992+00	\N	Auditoría automática vía trigger fn_audit_trigger
228	\N	INSERT	alumno	141	\N	{"curp": "TEST45123HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 141, "creado_en": "2026-06-15T20:53:08.887+00:00", "matricula": "TST-PRI-5A-LVTF-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.887+00:00", "dia_limite_pago": null, "nombre_completo": "Mateo Gomez Cruz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.887847+00	\N	Auditoría automática vía trigger fn_audit_trigger
229	\N	INSERT	alumno	142	\N	{"curp": "TEST25727HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 142, "creado_en": "2026-06-15T20:53:08.909+00:00", "matricula": "TST-PRI-5A-CEX3-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.909+00:00", "dia_limite_pago": null, "nombre_completo": "Sebastian Lopez Sanchez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.909636+00	\N	Auditoría automática vía trigger fn_audit_trigger
230	\N	INSERT	alumno	143	\N	{"curp": "TEST30085HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 143, "creado_en": "2026-06-15T20:53:08.932+00:00", "matricula": "TST-PRI-5A-UZSQ-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.932+00:00", "dia_limite_pago": null, "nombre_completo": "Isabella Gomez Gonzalez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.932945+00	\N	Auditoría automática vía trigger fn_audit_trigger
231	\N	INSERT	alumno	144	\N	{"curp": "TEST79804HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 144, "creado_en": "2026-06-15T20:53:08.955+00:00", "matricula": "TST-PRI-6A-DCMD-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.955+00:00", "dia_limite_pago": null, "nombre_completo": "Matias Vazquez Garcia", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.956081+00	\N	Auditoría automática vía trigger fn_audit_trigger
232	\N	INSERT	alumno	145	\N	{"curp": "TEST56576HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 145, "creado_en": "2026-06-15T20:53:08.975+00:00", "matricula": "TST-PRI-6A-R8UK-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.975+00:00", "dia_limite_pago": null, "nombre_completo": "Sebastian Diaz Cruz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:08.975945+00	\N	Auditoría automática vía trigger fn_audit_trigger
233	\N	INSERT	alumno	146	\N	{"curp": "TEST47223HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 146, "creado_en": "2026-06-15T20:53:08.999+00:00", "matricula": "TST-PRI-6A-7DJ1-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.999+00:00", "dia_limite_pago": null, "nombre_completo": "Valeria Rodriguez Lopez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.000386+00	\N	Auditoría automática vía trigger fn_audit_trigger
234	\N	INSERT	alumno	147	\N	{"curp": "TEST28059HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 147, "creado_en": "2026-06-15T20:53:09.026+00:00", "matricula": "TST-PRI-6A-L86O-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.026+00:00", "dia_limite_pago": null, "nombre_completo": "Gael Vazquez Flores", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.026302+00	\N	Auditoría automática vía trigger fn_audit_trigger
235	\N	INSERT	alumno	148	\N	{"curp": "TEST26635HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 148, "creado_en": "2026-06-15T20:53:09.046+00:00", "matricula": "TST-PRI-6A-JSFS-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.046+00:00", "dia_limite_pago": null, "nombre_completo": "Santiago Cruz Gonzalez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.046373+00	\N	Auditoría automática vía trigger fn_audit_trigger
236	\N	INSERT	alumno	149	\N	{"curp": "TEST42604HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 149, "creado_en": "2026-06-15T20:53:09.068+00:00", "matricula": "TST-PRI-6A-JO5Q-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.068+00:00", "dia_limite_pago": null, "nombre_completo": "Natalia Martinez Ramirez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.068662+00	\N	Auditoría automática vía trigger fn_audit_trigger
237	\N	INSERT	alumno	150	\N	{"curp": "TEST17145HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 150, "creado_en": "2026-06-15T20:53:09.098+00:00", "matricula": "TST-PRI-6A-0SES-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.098+00:00", "dia_limite_pago": null, "nombre_completo": "Renata Jimenez Vazquez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.098498+00	\N	Auditoría automática vía trigger fn_audit_trigger
238	\N	INSERT	alumno	151	\N	{"curp": "TEST15992HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 151, "creado_en": "2026-06-15T20:53:09.127+00:00", "matricula": "TST-PRI-6A-L5A6-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.127+00:00", "dia_limite_pago": null, "nombre_completo": "Gabriel Vazquez Morales", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.127651+00	\N	Auditoría automática vía trigger fn_audit_trigger
239	\N	INSERT	alumno	152	\N	{"curp": "TEST21447HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 152, "creado_en": "2026-06-15T20:53:09.156+00:00", "matricula": "TST-PRI-6A-3J08-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.156+00:00", "dia_limite_pago": null, "nombre_completo": "Daniel Morales Garcia", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.156232+00	\N	Auditoría automática vía trigger fn_audit_trigger
240	\N	INSERT	alumno	153	\N	{"curp": "TEST34513HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 153, "creado_en": "2026-06-15T20:53:09.179+00:00", "matricula": "TST-PRI-6A-7NIQ-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.179+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Gonzalez Diaz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.17952+00	\N	Auditoría automática vía trigger fn_audit_trigger
241	\N	INSERT	alumno	154	\N	{"curp": "TEST17453HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 154, "creado_en": "2026-06-15T20:53:09.206+00:00", "matricula": "TST-SEC-1A-WYCB-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.206+00:00", "dia_limite_pago": null, "nombre_completo": "Diego Lopez Gonzalez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.206641+00	\N	Auditoría automática vía trigger fn_audit_trigger
242	\N	INSERT	alumno	155	\N	{"curp": "TEST92117HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 155, "creado_en": "2026-06-15T20:53:09.226+00:00", "matricula": "TST-SEC-1A-CVOX-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.226+00:00", "dia_limite_pago": null, "nombre_completo": "Thiago Perez Perez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.226347+00	\N	Auditoría automática vía trigger fn_audit_trigger
243	\N	INSERT	alumno	156	\N	{"curp": "TEST52962HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 156, "creado_en": "2026-06-15T20:53:09.251+00:00", "matricula": "TST-SEC-1A-E2CB-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.251+00:00", "dia_limite_pago": null, "nombre_completo": "Camila Reyes Gonzalez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.251634+00	\N	Auditoría automática vía trigger fn_audit_trigger
244	\N	INSERT	alumno	157	\N	{"curp": "TEST3776HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 157, "creado_en": "2026-06-15T20:53:09.275+00:00", "matricula": "TST-SEC-1A-FB7R-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.275+00:00", "dia_limite_pago": null, "nombre_completo": "Santiago Jimenez Jimenez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.275593+00	\N	Auditoría automática vía trigger fn_audit_trigger
245	\N	INSERT	alumno	158	\N	{"curp": "TEST32582HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 158, "creado_en": "2026-06-15T20:53:09.291+00:00", "matricula": "TST-SEC-1A-YYK8-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.291+00:00", "dia_limite_pago": null, "nombre_completo": "Daniel Lopez Vazquez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.292242+00	\N	Auditoría automática vía trigger fn_audit_trigger
246	\N	INSERT	alumno	159	\N	{"curp": "TEST49492HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 159, "creado_en": "2026-06-15T20:53:09.32+00:00", "matricula": "TST-SEC-1A-CVJH-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.32+00:00", "dia_limite_pago": null, "nombre_completo": "Isabella Flores Lopez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.320881+00	\N	Auditoría automática vía trigger fn_audit_trigger
247	\N	INSERT	alumno	160	\N	{"curp": "TEST20800HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 160, "creado_en": "2026-06-15T20:53:09.343+00:00", "matricula": "TST-SEC-1A-ZGES-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.343+00:00", "dia_limite_pago": null, "nombre_completo": "Mateo Perez Lopez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.343378+00	\N	Auditoría automática vía trigger fn_audit_trigger
248	\N	INSERT	alumno	161	\N	{"curp": "TEST55448HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 161, "creado_en": "2026-06-15T20:53:09.363+00:00", "matricula": "TST-SEC-1A-SVGF-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.363+00:00", "dia_limite_pago": null, "nombre_completo": "Daniel Reyes Cruz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.363753+00	\N	Auditoría automática vía trigger fn_audit_trigger
249	\N	INSERT	alumno	162	\N	{"curp": "TEST49794HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 162, "creado_en": "2026-06-15T20:53:09.389+00:00", "matricula": "TST-SEC-1A-3AOO-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.389+00:00", "dia_limite_pago": null, "nombre_completo": "Sofia Gomez Sanchez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.389479+00	\N	Auditoría automática vía trigger fn_audit_trigger
250	\N	INSERT	alumno	163	\N	{"curp": "TEST56325HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 163, "creado_en": "2026-06-15T20:53:09.415+00:00", "matricula": "TST-SEC-1A-MJC6-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.415+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Flores Ramirez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.415404+00	\N	Auditoría automática vía trigger fn_audit_trigger
251	\N	INSERT	alumno	164	\N	{"curp": "TEST8219HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 164, "creado_en": "2026-06-15T20:53:09.436+00:00", "matricula": "TST-SEC-2A-AZ9M-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.436+00:00", "dia_limite_pago": null, "nombre_completo": "Leonardo Flores Reyes", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.436688+00	\N	Auditoría automática vía trigger fn_audit_trigger
252	\N	INSERT	alumno	165	\N	{"curp": "TEST27203HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 165, "creado_en": "2026-06-15T20:53:09.461+00:00", "matricula": "TST-SEC-2A-2879-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.461+00:00", "dia_limite_pago": null, "nombre_completo": "Regina Vazquez Martinez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.461743+00	\N	Auditoría automática vía trigger fn_audit_trigger
253	\N	INSERT	alumno	166	\N	{"curp": "TEST96198HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 166, "creado_en": "2026-06-15T20:53:09.484+00:00", "matricula": "TST-SEC-2A-KL0R-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.484+00:00", "dia_limite_pago": null, "nombre_completo": "Regina Vazquez Garcia", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.484919+00	\N	Auditoría automática vía trigger fn_audit_trigger
254	\N	INSERT	alumno	167	\N	{"curp": "TEST69178HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 167, "creado_en": "2026-06-15T20:53:09.505+00:00", "matricula": "TST-SEC-2A-AJIU-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.505+00:00", "dia_limite_pago": null, "nombre_completo": "Renata Vazquez Ramirez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.505788+00	\N	Auditoría automática vía trigger fn_audit_trigger
255	\N	INSERT	alumno	168	\N	{"curp": "TEST20300HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 168, "creado_en": "2026-06-15T20:53:09.527+00:00", "matricula": "TST-SEC-2A-G9GI-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.527+00:00", "dia_limite_pago": null, "nombre_completo": "Valeria Flores Cruz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.527813+00	\N	Auditoría automática vía trigger fn_audit_trigger
256	\N	INSERT	alumno	169	\N	{"curp": "TEST70101HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 169, "creado_en": "2026-06-15T20:53:09.552+00:00", "matricula": "TST-SEC-2A-PGSZ-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.552+00:00", "dia_limite_pago": null, "nombre_completo": "Natalia Gomez Sanchez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.552958+00	\N	Auditoría automática vía trigger fn_audit_trigger
257	\N	INSERT	alumno	170	\N	{"curp": "TEST597HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 170, "creado_en": "2026-06-15T20:53:09.578+00:00", "matricula": "TST-SEC-2A-WUKU-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.578+00:00", "dia_limite_pago": null, "nombre_completo": "Valentina Reyes Morales", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.578342+00	\N	Auditoría automática vía trigger fn_audit_trigger
258	\N	INSERT	alumno	171	\N	{"curp": "TEST89171HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 171, "creado_en": "2026-06-15T20:53:09.597+00:00", "matricula": "TST-SEC-2A-O69G-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.597+00:00", "dia_limite_pago": null, "nombre_completo": "Victoria Garcia Reyes", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.59813+00	\N	Auditoría automática vía trigger fn_audit_trigger
259	\N	INSERT	alumno	172	\N	{"curp": "TEST47308HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 172, "creado_en": "2026-06-15T20:53:09.619+00:00", "matricula": "TST-SEC-2A-UR8H-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.619+00:00", "dia_limite_pago": null, "nombre_completo": "Mia Ramirez Rodriguez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.620005+00	\N	Auditoría automática vía trigger fn_audit_trigger
260	\N	INSERT	alumno	173	\N	{"curp": "TEST64650HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 173, "creado_en": "2026-06-15T20:53:09.642+00:00", "matricula": "TST-SEC-2A-NMRI-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.642+00:00", "dia_limite_pago": null, "nombre_completo": "Sofia Martinez Morales", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.642743+00	\N	Auditoría automática vía trigger fn_audit_trigger
261	\N	INSERT	alumno	174	\N	{"curp": "TEST62446HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 174, "creado_en": "2026-06-15T20:53:09.665+00:00", "matricula": "TST-SEC-3A-24SN-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.665+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Perez Rodriguez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.665659+00	\N	Auditoría automática vía trigger fn_audit_trigger
262	\N	INSERT	alumno	175	\N	{"curp": "TEST60378HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 175, "creado_en": "2026-06-15T20:53:09.69+00:00", "matricula": "TST-SEC-3A-Q9ST-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.69+00:00", "dia_limite_pago": null, "nombre_completo": "Ximena Vazquez Ramirez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.690949+00	\N	Auditoría automática vía trigger fn_audit_trigger
263	\N	INSERT	alumno	176	\N	{"curp": "TEST85195HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 176, "creado_en": "2026-06-15T20:53:09.711+00:00", "matricula": "TST-SEC-3A-B6SD-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.711+00:00", "dia_limite_pago": null, "nombre_completo": "Gael Rodriguez Rodriguez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.711737+00	\N	Auditoría automática vía trigger fn_audit_trigger
264	\N	INSERT	alumno	177	\N	{"curp": "TEST28313HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 177, "creado_en": "2026-06-15T20:53:09.732+00:00", "matricula": "TST-SEC-3A-C3TT-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.732+00:00", "dia_limite_pago": null, "nombre_completo": "Jose Sanchez Lopez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.73241+00	\N	Auditoría automática vía trigger fn_audit_trigger
265	\N	INSERT	alumno	178	\N	{"curp": "TEST3710HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 178, "creado_en": "2026-06-15T20:53:09.755+00:00", "matricula": "TST-SEC-3A-46AQ-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.755+00:00", "dia_limite_pago": null, "nombre_completo": "Valeria Gomez Rodriguez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.755635+00	\N	Auditoría automática vía trigger fn_audit_trigger
266	\N	INSERT	alumno	179	\N	{"curp": "TEST56292HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 179, "creado_en": "2026-06-15T20:53:09.778+00:00", "matricula": "TST-SEC-3A-Q9AY-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.778+00:00", "dia_limite_pago": null, "nombre_completo": "Mia Jimenez Morales", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.778632+00	\N	Auditoría automática vía trigger fn_audit_trigger
267	\N	INSERT	alumno	180	\N	{"curp": "TEST99586HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 180, "creado_en": "2026-06-15T20:53:09.796+00:00", "matricula": "TST-SEC-3A-AIHE-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.796+00:00", "dia_limite_pago": null, "nombre_completo": "Leonardo Lopez Reyes", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.796701+00	\N	Auditoría automática vía trigger fn_audit_trigger
268	\N	INSERT	alumno	181	\N	{"curp": "TEST65585HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 181, "creado_en": "2026-06-15T20:53:09.819+00:00", "matricula": "TST-SEC-3A-1XUZ-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.819+00:00", "dia_limite_pago": null, "nombre_completo": "Isabella Vazquez Garcia", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.819782+00	\N	Auditoría automática vía trigger fn_audit_trigger
269	\N	INSERT	alumno	182	\N	{"curp": "TEST81795HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 182, "creado_en": "2026-06-15T20:53:09.842+00:00", "matricula": "TST-SEC-3A-XESZ-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.842+00:00", "dia_limite_pago": null, "nombre_completo": "Gabriel Morales Garcia", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.843414+00	\N	Auditoría automática vía trigger fn_audit_trigger
270	\N	INSERT	alumno	183	\N	{"curp": "TEST21671HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 183, "creado_en": "2026-06-15T20:53:09.865+00:00", "matricula": "TST-SEC-3A-VM4A-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.865+00:00", "dia_limite_pago": null, "nombre_completo": "Maria Diaz Perez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.865462+00	\N	Auditoría automática vía trigger fn_audit_trigger
271	\N	INSERT	alumno	184	\N	{"curp": "TEST217HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 184, "creado_en": "2026-06-15T20:53:09.888+00:00", "matricula": "TST-PRI-4A-FN46-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.888+00:00", "dia_limite_pago": null, "nombre_completo": "Renata Ramirez Sanchez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.889358+00	\N	Auditoría automática vía trigger fn_audit_trigger
272	\N	INSERT	alumno	185	\N	{"curp": "TEST95802HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 185, "creado_en": "2026-06-15T20:53:09.911+00:00", "matricula": "TST-PRI-4A-7Z47-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.911+00:00", "dia_limite_pago": null, "nombre_completo": "Emiliano Jimenez Jimenez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.911449+00	\N	Auditoría automática vía trigger fn_audit_trigger
273	\N	INSERT	alumno	186	\N	{"curp": "TEST10557HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 186, "creado_en": "2026-06-15T20:53:09.929+00:00", "matricula": "TST-PRI-4A-ZKVZ-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.929+00:00", "dia_limite_pago": null, "nombre_completo": "Sebastian Vazquez Martinez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.929835+00	\N	Auditoría automática vía trigger fn_audit_trigger
274	\N	INSERT	alumno	187	\N	{"curp": "TEST92828HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 187, "creado_en": "2026-06-15T20:53:09.952+00:00", "matricula": "TST-PRI-4A-2U8Z-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.952+00:00", "dia_limite_pago": null, "nombre_completo": "Natalia Reyes Perez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.953124+00	\N	Auditoría automática vía trigger fn_audit_trigger
275	\N	INSERT	alumno	188	\N	{"curp": "TEST49390HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 188, "creado_en": "2026-06-15T20:53:09.978+00:00", "matricula": "TST-PRI-4A-N92Y-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:09.978+00:00", "dia_limite_pago": null, "nombre_completo": "Victoria Flores Lopez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:09.979438+00	\N	Auditoría automática vía trigger fn_audit_trigger
276	\N	INSERT	alumno	189	\N	{"curp": "TEST63991HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 189, "creado_en": "2026-06-15T20:53:10.003+00:00", "matricula": "TST-PRI-4A-LX6E-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.003+00:00", "dia_limite_pago": null, "nombre_completo": "Gael Gonzalez Cruz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.003595+00	\N	Auditoría automática vía trigger fn_audit_trigger
277	\N	INSERT	alumno	190	\N	{"curp": "TEST11874HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 190, "creado_en": "2026-06-15T20:53:10.028+00:00", "matricula": "TST-PRI-4A-E7UB-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.028+00:00", "dia_limite_pago": null, "nombre_completo": "Diego Perez Sanchez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.028819+00	\N	Auditoría automática vía trigger fn_audit_trigger
278	\N	INSERT	alumno	191	\N	{"curp": "TEST31639HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 191, "creado_en": "2026-06-15T20:53:10.049+00:00", "matricula": "TST-PRI-4A-8Y5M-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.049+00:00", "dia_limite_pago": null, "nombre_completo": "Mateo Sanchez Cruz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.049798+00	\N	Auditoría automática vía trigger fn_audit_trigger
279	\N	INSERT	alumno	192	\N	{"curp": "TEST28083HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 192, "creado_en": "2026-06-15T20:53:10.069+00:00", "matricula": "TST-PRI-4A-DDIV-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.069+00:00", "dia_limite_pago": null, "nombre_completo": "Maria Lopez Sanchez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.070141+00	\N	Auditoría automática vía trigger fn_audit_trigger
280	\N	INSERT	alumno	193	\N	{"curp": "TEST36415HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 193, "creado_en": "2026-06-15T20:53:10.096+00:00", "matricula": "TST-PRI-4A-EOJ3-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.096+00:00", "dia_limite_pago": null, "nombre_completo": "Mia Perez Jimenez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.096927+00	\N	Auditoría automática vía trigger fn_audit_trigger
281	\N	INSERT	alumno	194	\N	{"curp": "TEST69634HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 194, "creado_en": "2026-06-15T20:53:10.118+00:00", "matricula": "TST-SEC-5B-SBET-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.118+00:00", "dia_limite_pago": null, "nombre_completo": "Camila Jimenez Ramirez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.118912+00	\N	Auditoría automática vía trigger fn_audit_trigger
282	\N	INSERT	alumno	195	\N	{"curp": "TEST8945HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 195, "creado_en": "2026-06-15T20:53:10.135+00:00", "matricula": "TST-SEC-5B-0DR6-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.135+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Sanchez Diaz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.135541+00	\N	Auditoría automática vía trigger fn_audit_trigger
283	\N	INSERT	alumno	196	\N	{"curp": "TEST72177HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 196, "creado_en": "2026-06-15T20:53:10.159+00:00", "matricula": "TST-SEC-5B-RTFW-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.159+00:00", "dia_limite_pago": null, "nombre_completo": "Thiago Vazquez Martinez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.159745+00	\N	Auditoría automática vía trigger fn_audit_trigger
284	\N	INSERT	alumno	197	\N	{"curp": "TEST86703HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 197, "creado_en": "2026-06-15T20:53:10.181+00:00", "matricula": "TST-SEC-5B-GXTI-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.181+00:00", "dia_limite_pago": null, "nombre_completo": "Victoria Jimenez Lopez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.181388+00	\N	Auditoría automática vía trigger fn_audit_trigger
285	\N	INSERT	alumno	198	\N	{"curp": "TEST71094HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 198, "creado_en": "2026-06-15T20:53:10.2+00:00", "matricula": "TST-SEC-5B-I9Z6-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.2+00:00", "dia_limite_pago": null, "nombre_completo": "Sebastian Gonzalez Jimenez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.200431+00	\N	Auditoría automática vía trigger fn_audit_trigger
286	\N	INSERT	alumno	199	\N	{"curp": "TEST16182HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 199, "creado_en": "2026-06-15T20:53:10.219+00:00", "matricula": "TST-SEC-5B-K2ZV-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.219+00:00", "dia_limite_pago": null, "nombre_completo": "Victoria Vazquez Flores", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.220567+00	\N	Auditoría automática vía trigger fn_audit_trigger
287	\N	INSERT	alumno	200	\N	{"curp": "TEST87507HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 200, "creado_en": "2026-06-15T20:53:10.243+00:00", "matricula": "TST-SEC-5B-F4MB-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.243+00:00", "dia_limite_pago": null, "nombre_completo": "Diego Jimenez Rodriguez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.243672+00	\N	Auditoría automática vía trigger fn_audit_trigger
288	\N	INSERT	alumno	201	\N	{"curp": "TEST63005HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 201, "creado_en": "2026-06-15T20:53:10.262+00:00", "matricula": "TST-SEC-5B-4CSN-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.262+00:00", "dia_limite_pago": null, "nombre_completo": "Valeria Martinez Vazquez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.262152+00	\N	Auditoría automática vía trigger fn_audit_trigger
289	\N	INSERT	alumno	202	\N	{"curp": "TEST89650HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 202, "creado_en": "2026-06-15T20:53:10.285+00:00", "matricula": "TST-SEC-5B-ZZX0-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.285+00:00", "dia_limite_pago": null, "nombre_completo": "Natalia Cruz Flores", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.285357+00	\N	Auditoría automática vía trigger fn_audit_trigger
290	\N	INSERT	alumno	203	\N	{"curp": "TEST69914HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 203, "creado_en": "2026-06-15T20:53:10.303+00:00", "matricula": "TST-SEC-5B-8VKH-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.303+00:00", "dia_limite_pago": null, "nombre_completo": "Maria Morales Ramirez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.303951+00	\N	Auditoría automática vía trigger fn_audit_trigger
291	\N	INSERT	alumno	204	\N	{"curp": "TEST66663HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 204, "creado_en": "2026-06-15T20:53:10.324+00:00", "matricula": "TST-BAC-2A-Y88K-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.324+00:00", "dia_limite_pago": null, "nombre_completo": "Regina Flores Gomez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.324437+00	\N	Auditoría automática vía trigger fn_audit_trigger
292	\N	INSERT	alumno	205	\N	{"curp": "TEST17589HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 205, "creado_en": "2026-06-15T20:53:10.349+00:00", "matricula": "TST-BAC-2A-H15R-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.349+00:00", "dia_limite_pago": null, "nombre_completo": "Thiago Ramirez Ramirez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.350466+00	\N	Auditoría automática vía trigger fn_audit_trigger
293	\N	INSERT	alumno	206	\N	{"curp": "TEST79584HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 206, "creado_en": "2026-06-15T20:53:10.369+00:00", "matricula": "TST-BAC-2A-GAH7-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.369+00:00", "dia_limite_pago": null, "nombre_completo": "Daniel Gonzalez Gomez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.369663+00	\N	Auditoría automática vía trigger fn_audit_trigger
294	\N	INSERT	alumno	207	\N	{"curp": "TEST62808HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 207, "creado_en": "2026-06-15T20:53:10.394+00:00", "matricula": "TST-BAC-2A-S0BY-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.394+00:00", "dia_limite_pago": null, "nombre_completo": "Thiago Morales Martinez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.395043+00	\N	Auditoría automática vía trigger fn_audit_trigger
295	\N	INSERT	alumno	208	\N	{"curp": "TEST23915HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 208, "creado_en": "2026-06-15T20:53:10.418+00:00", "matricula": "TST-BAC-2A-13KQ-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.418+00:00", "dia_limite_pago": null, "nombre_completo": "Jose Ramirez Vazquez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.418687+00	\N	Auditoría automática vía trigger fn_audit_trigger
296	\N	INSERT	alumno	209	\N	{"curp": "TEST94944HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 209, "creado_en": "2026-06-15T20:53:10.446+00:00", "matricula": "TST-BAC-2A-XW4H-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.446+00:00", "dia_limite_pago": null, "nombre_completo": "Santiago Flores Sanchez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.446658+00	\N	Auditoría automática vía trigger fn_audit_trigger
297	\N	INSERT	alumno	210	\N	{"curp": "TEST28996HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 210, "creado_en": "2026-06-15T20:53:10.48+00:00", "matricula": "TST-BAC-2A-JUWE-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.48+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Garcia Ramirez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.481952+00	\N	Auditoría automática vía trigger fn_audit_trigger
298	\N	INSERT	alumno	211	\N	{"curp": "TEST41758HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 211, "creado_en": "2026-06-15T20:53:10.52+00:00", "matricula": "TST-BAC-2A-D9VX-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.52+00:00", "dia_limite_pago": null, "nombre_completo": "Valentina Martinez Flores", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.520956+00	\N	Auditoría automática vía trigger fn_audit_trigger
299	\N	INSERT	alumno	212	\N	{"curp": "TEST41679HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 212, "creado_en": "2026-06-15T20:53:10.549+00:00", "matricula": "TST-BAC-2A-A9C2-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.549+00:00", "dia_limite_pago": null, "nombre_completo": "Jose Rodriguez Perez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.54958+00	\N	Auditoría automática vía trigger fn_audit_trigger
300	\N	INSERT	alumno	213	\N	{"curp": "TEST92460HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 213, "creado_en": "2026-06-15T20:53:10.568+00:00", "matricula": "TST-BAC-2A-TNMT-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.568+00:00", "dia_limite_pago": null, "nombre_completo": "Leonardo Sanchez Vazquez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.568837+00	\N	Auditoría automática vía trigger fn_audit_trigger
301	\N	INSERT	alumno	214	\N	{"curp": "TEST47459HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 214, "creado_en": "2026-06-15T20:53:10.588+00:00", "matricula": "TST-BAC-3B-27K4-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.588+00:00", "dia_limite_pago": null, "nombre_completo": "Matias Morales Gomez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.589417+00	\N	Auditoría automática vía trigger fn_audit_trigger
302	\N	INSERT	alumno	215	\N	{"curp": "TEST22483HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 215, "creado_en": "2026-06-15T20:53:10.616+00:00", "matricula": "TST-BAC-3B-T124-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.616+00:00", "dia_limite_pago": null, "nombre_completo": "Matias Martinez Flores", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.616194+00	\N	Auditoría automática vía trigger fn_audit_trigger
303	\N	INSERT	alumno	216	\N	{"curp": "TEST31505HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 216, "creado_en": "2026-06-15T20:53:10.641+00:00", "matricula": "TST-BAC-3B-PXF4-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.641+00:00", "dia_limite_pago": null, "nombre_completo": "Regina Gomez Diaz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.641707+00	\N	Auditoría automática vía trigger fn_audit_trigger
304	\N	INSERT	alumno	217	\N	{"curp": "TEST49112HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 217, "creado_en": "2026-06-15T20:53:10.663+00:00", "matricula": "TST-BAC-3B-451U-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.663+00:00", "dia_limite_pago": null, "nombre_completo": "Santiago Ramirez Gonzalez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.663272+00	\N	Auditoría automática vía trigger fn_audit_trigger
305	\N	INSERT	alumno	218	\N	{"curp": "TEST32777HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 218, "creado_en": "2026-06-15T20:53:10.686+00:00", "matricula": "TST-BAC-3B-SOPY-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.686+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Morales Diaz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.687132+00	\N	Auditoría automática vía trigger fn_audit_trigger
306	\N	INSERT	alumno	219	\N	{"curp": "TEST74958HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 219, "creado_en": "2026-06-15T20:53:10.705+00:00", "matricula": "TST-BAC-3B-HDGZ-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.705+00:00", "dia_limite_pago": null, "nombre_completo": "Leonardo Rodriguez Jimenez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.705989+00	\N	Auditoría automática vía trigger fn_audit_trigger
307	\N	INSERT	alumno	220	\N	{"curp": "TEST2640HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 220, "creado_en": "2026-06-15T20:53:10.725+00:00", "matricula": "TST-BAC-3B-S2RZ-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.725+00:00", "dia_limite_pago": null, "nombre_completo": "Sebastian Gonzalez Reyes", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.725842+00	\N	Auditoría automática vía trigger fn_audit_trigger
308	\N	INSERT	alumno	221	\N	{"curp": "TEST87162HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 221, "creado_en": "2026-06-15T20:53:10.75+00:00", "matricula": "TST-BAC-3B-MLD8-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.75+00:00", "dia_limite_pago": null, "nombre_completo": "Valeria Lopez Cruz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.75059+00	\N	Auditoría automática vía trigger fn_audit_trigger
309	\N	INSERT	alumno	222	\N	{"curp": "TEST14637HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 222, "creado_en": "2026-06-15T20:53:10.77+00:00", "matricula": "TST-BAC-3B-7ZL3-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.77+00:00", "dia_limite_pago": null, "nombre_completo": "Mateo Cruz Reyes", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.771073+00	\N	Auditoría automática vía trigger fn_audit_trigger
310	\N	INSERT	alumno	223	\N	{"curp": "TEST2246HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 223, "creado_en": "2026-06-15T20:53:10.794+00:00", "matricula": "TST-BAC-3B-GXA9-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.794+00:00", "dia_limite_pago": null, "nombre_completo": "Natalia Garcia Jimenez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.794853+00	\N	Auditoría automática vía trigger fn_audit_trigger
311	\N	INSERT	alumno	224	\N	{"curp": "TEST37213HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 1, "alumno_id": 224, "creado_en": "2026-06-15T20:53:10.818+00:00", "matricula": "TST-PRE-1A-N237-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.818+00:00", "dia_limite_pago": null, "nombre_completo": "Diego Garcia Sanchez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.818745+00	\N	Auditoría automática vía trigger fn_audit_trigger
312	\N	INSERT	alumno	225	\N	{"curp": "TEST31129HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 1, "alumno_id": 225, "creado_en": "2026-06-15T20:53:10.835+00:00", "matricula": "TST-PRE-1A-SMD6-1", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.835+00:00", "dia_limite_pago": null, "nombre_completo": "Victoria Perez Cruz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.835339+00	\N	Auditoría automática vía trigger fn_audit_trigger
313	\N	INSERT	alumno	226	\N	{"curp": "TEST91858HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 1, "alumno_id": 226, "creado_en": "2026-06-15T20:53:10.859+00:00", "matricula": "TST-PRE-1A-GBUY-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.859+00:00", "dia_limite_pago": null, "nombre_completo": "Leonardo Rodriguez Vazquez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.859927+00	\N	Auditoría automática vía trigger fn_audit_trigger
314	\N	INSERT	alumno	227	\N	{"curp": "TEST64027HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 1, "alumno_id": 227, "creado_en": "2026-06-15T20:53:10.885+00:00", "matricula": "TST-PRE-1A-AZ3M-3", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.885+00:00", "dia_limite_pago": null, "nombre_completo": "Renata Morales Martinez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.885853+00	\N	Auditoría automática vía trigger fn_audit_trigger
315	\N	INSERT	alumno	228	\N	{"curp": "TEST83885HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 1, "alumno_id": 228, "creado_en": "2026-06-15T20:53:10.908+00:00", "matricula": "TST-PRE-1A-E2J6-4", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.908+00:00", "dia_limite_pago": null, "nombre_completo": "Thiago Vazquez Sanchez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.909109+00	\N	Auditoría automática vía trigger fn_audit_trigger
316	\N	INSERT	alumno	229	\N	{"curp": "TEST13335HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 1, "alumno_id": 229, "creado_en": "2026-06-15T20:53:10.931+00:00", "matricula": "TST-PRE-1A-VK5X-5", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.931+00:00", "dia_limite_pago": null, "nombre_completo": "Camila Cruz Ramirez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.931619+00	\N	Auditoría automática vía trigger fn_audit_trigger
317	\N	INSERT	alumno	230	\N	{"curp": "TEST44700HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 1, "alumno_id": 230, "creado_en": "2026-06-15T20:53:10.95+00:00", "matricula": "TST-PRE-1A-47GS-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.95+00:00", "dia_limite_pago": null, "nombre_completo": "Isabella Flores Reyes", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.951196+00	\N	Auditoría automática vía trigger fn_audit_trigger
318	\N	INSERT	alumno	231	\N	{"curp": "TEST22661HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 1, "alumno_id": 231, "creado_en": "2026-06-15T20:53:10.974+00:00", "matricula": "TST-PRE-1A-LL48-7", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.974+00:00", "dia_limite_pago": null, "nombre_completo": "Renata Lopez Jimenez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.975079+00	\N	Auditoría automática vía trigger fn_audit_trigger
319	\N	INSERT	alumno	232	\N	{"curp": "TEST7620HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 1, "alumno_id": 232, "creado_en": "2026-06-15T20:53:10.999+00:00", "matricula": "TST-PRE-1A-BS2Y-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.999+00:00", "dia_limite_pago": null, "nombre_completo": "Renata Perez Diaz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:10.999918+00	\N	Auditoría automática vía trigger fn_audit_trigger
320	\N	INSERT	alumno	233	\N	{"curp": "TEST9162HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 1, "alumno_id": 233, "creado_en": "2026-06-15T20:53:11.022+00:00", "matricula": "TST-PRE-1A-2FVB-9", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:11.022+00:00", "dia_limite_pago": null, "nombre_completo": "Victoria Jimenez Reyes", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 20:53:11.023163+00	\N	Auditoría automática vía trigger fn_audit_trigger
321	6	UPDATE	alumno	9	{"curp": "CAHC170305MVZSRM06", "sexo": "F", "estado": "Activo", "nivel_id": 1, "alumno_id": 9, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2022-0003", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "", "actualizado_en": "2026-06-15T04:41:44.330427+00:00", "dia_limite_pago": null, "nombre_completo": "Camila Castro Hernández", "fecha_nacimiento": "2017-03-05", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	{"curp": "CAHC170305MVZSRM06", "sexo": "F", "estado": "Activo", "nivel_id": 1, "alumno_id": 9, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2022-0003", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "", "actualizado_en": "2026-06-15T21:03:40.999671+00:00", "dia_limite_pago": null, "nombre_completo": "Camila Castro Hernández", "fecha_nacimiento": "2017-03-05", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	2026-06-15 21:03:40.999671+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
322	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-15T19:46:48.85+00:00", "actualizado_en": "2026-06-15T19:46:48.858793+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-15T21:05:25.422+00:00", "actualizado_en": "2026-06-15T21:05:25.426008+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-15 21:05:25.426008+00	\N	Auditoría automática vía trigger fn_audit_trigger
323	6	UPDATE	alumno	41	{"curp": "TEST71356HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 41, "creado_en": "2026-06-15T20:52:46.076+00:00", "matricula": "TST-PRI-3A-X7S4-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.076+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Flores Diaz", "fecha_nacimiento": null, "personas_autorizadas": []}	{"curp": "TEST71356HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 41, "creado_en": "2026-06-15T20:52:46.076+00:00", "matricula": "TST-PRI-3A-X7S4-8", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T21:07:31.702328+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Flores Diaz", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 21:07:31.702328+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
324	\N	UPDATE	usuario	11	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-15T09:35:53.448+00:00", "actualizado_en": "2026-06-15T09:35:53.449879+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-15T21:08:35.388+00:00", "actualizado_en": "2026-06-15T21:08:35.393811+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-15 21:08:35.393811+00	\N	Auditoría automática vía trigger fn_audit_trigger
325	\N	UPDATE	usuario	11	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-15T21:08:35.388+00:00", "actualizado_en": "2026-06-15T21:08:35.393811+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-15T21:40:26.767+00:00", "actualizado_en": "2026-06-15T21:40:26.772165+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-15 21:40:26.772165+00	\N	Auditoría automática vía trigger fn_audit_trigger
326	6	UPDATE	alumno	16	{"curp": null, "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 16, "creado_en": "2026-06-14T18:44:45.812+00:00", "matricula": "SDM-2018-0301", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-14T18:44:45.812+00:00", "dia_limite_pago": null, "nombre_completo": "Ana Lucía Hernández", "fecha_nacimiento": null, "personas_autorizadas": []}	{"curp": null, "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 16, "creado_en": "2026-06-14T18:44:45.812+00:00", "matricula": "SDM-2018-0301", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T21:44:34.727426+00:00", "dia_limite_pago": null, "nombre_completo": "Ana Lucía Hernández", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 21:44:34.727426+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
327	6	UPDATE	alumno	16	{"curp": null, "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 16, "creado_en": "2026-06-14T18:44:45.812+00:00", "matricula": "SDM-2018-0301", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T21:44:34.727426+00:00", "dia_limite_pago": null, "nombre_completo": "Ana Lucía Hernández", "fecha_nacimiento": null, "personas_autorizadas": []}	{"curp": null, "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 16, "creado_en": "2026-06-14T18:44:45.812+00:00", "matricula": "SDM-2018-0301", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T21:44:35.55625+00:00", "dia_limite_pago": null, "nombre_completo": "Ana Lucía Hernández", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 21:44:35.55625+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
328	6	UPDATE	alumno	16	{"curp": null, "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 16, "creado_en": "2026-06-14T18:44:45.812+00:00", "matricula": "SDM-2018-0301", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T21:44:35.55625+00:00", "dia_limite_pago": null, "nombre_completo": "Ana Lucía Hernández", "fecha_nacimiento": null, "personas_autorizadas": []}	{"curp": null, "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 16, "creado_en": "2026-06-14T18:44:45.812+00:00", "matricula": "SDM-2018-0301", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T21:46:08.176391+00:00", "dia_limite_pago": null, "nombre_completo": "Ana Lucía Hernández", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-15 21:46:08.176391+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
329	11	UPDATE	alumno	10	{"curp": "CAHA111018HVZSRD01", "sexo": "M", "estado": "Activo", "nivel_id": 3, "alumno_id": 10, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2018-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-12T05:56:10.669773+00:00", "dia_limite_pago": null, "nombre_completo": "Adrián Castro Hernández", "fecha_nacimiento": "2011-10-18", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	{"curp": "CAHA111018HVZSRD01", "sexo": "M", "estado": "Activo", "nivel_id": 3, "alumno_id": 10, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2018-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T22:45:41.923852+00:00", "dia_limite_pago": null, "nombre_completo": "Adrián Castro Hernández", "fecha_nacimiento": "2011-10-18", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	2026-06-15 22:45:41.923852+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
330	\N	UPDATE	usuario	11	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-15T21:40:26.767+00:00", "actualizado_en": "2026-06-15T21:40:26.772165+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-15T23:14:56.595+00:00", "actualizado_en": "2026-06-15T23:14:56.598568+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-15 23:14:56.598568+00	\N	Auditoría automática vía trigger fn_audit_trigger
331	11	INSERT	usuario	17	\N	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T00:23:48.339+00:00", "usuario_id": 17, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-16T00:23:48.339+00:00", "nombre_usuario": "HARRY", "bloqueado_hasta": null, "nombre_completo": "Jose Manuel Fabian Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 00:23:48.331971+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
332	11	INSERT	usuario_rol	20	\N	{"activo": true, "rol_id": 4, "creado_en": "2026-06-16T00:23:48.339+00:00", "usuario_id": 17, "asignado_en": "2026-06-16T00:23:48.339+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-16T00:23:48.339+00:00", "usuario_rol_id": 20}	2026-06-16 00:23:48.331971+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
333	\N	UPDATE	usuario	11	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-15T23:14:56.595+00:00", "actualizado_en": "2026-06-15T23:14:56.598568+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-16T00:24:05.769+00:00", "actualizado_en": "2026-06-16T00:24:05.77243+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 00:24:05.77243+00	\N	Auditoría automática vía trigger fn_audit_trigger
334	\N	UPDATE	usuario	17	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T00:23:48.339+00:00", "usuario_id": 17, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-16T00:23:48.339+00:00", "nombre_usuario": "HARRY", "bloqueado_hasta": null, "nombre_completo": "Jose Manuel Fabian Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T00:23:48.339+00:00", "usuario_id": 17, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-16T00:25:03.965967+00:00", "nombre_usuario": "HARRY", "bloqueado_hasta": null, "nombre_completo": "Jose Manuel Fabian Hernandez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 00:25:03.965967+00	\N	Auditoría automática vía trigger fn_audit_trigger
335	\N	UPDATE	usuario	17	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T00:23:48.339+00:00", "usuario_id": 17, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-16T00:25:03.965967+00:00", "nombre_usuario": "HARRY", "bloqueado_hasta": null, "nombre_completo": "Jose Manuel Fabian Hernandez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T00:23:48.339+00:00", "usuario_id": 17, "eliminado_en": null, "ultimo_acceso": "2026-06-16T00:25:25.435+00:00", "actualizado_en": "2026-06-16T00:25:25.442761+00:00", "nombre_usuario": "HARRY", "bloqueado_hasta": null, "nombre_completo": "Jose Manuel Fabian Hernandez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 00:25:25.442761+00	\N	Auditoría automática vía trigger fn_audit_trigger
336	\N	UPDATE	usuario	11	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-16T00:24:05.769+00:00", "actualizado_en": "2026-06-16T00:24:05.77243+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-16T00:27:34.986+00:00", "actualizado_en": "2026-06-16T00:27:34.987855+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 00:27:34.987855+00	\N	Auditoría automática vía trigger fn_audit_trigger
337	\N	UPDATE	usuario	4	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-15T19:44:47.904991+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T00:33:52.464+00:00", "actualizado_en": "2026-06-16T00:33:52.468863+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 00:33:52.468863+00	\N	Auditoría automática vía trigger fn_audit_trigger
338	\N	UPDATE	usuario	11	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-16T00:27:34.986+00:00", "actualizado_en": "2026-06-16T00:27:34.987855+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-16T00:35:01.065+00:00", "actualizado_en": "2026-06-16T00:35:01.071189+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 00:35:01.071189+00	\N	Auditoría automática vía trigger fn_audit_trigger
339	11	UPDATE	tutor	17	{"rfc": null, "curp": null, "activo": true, "tutorId": 17, "usoCfdi": null, "creadoEn": "2026-06-15T19:44:48.243Z", "telefono": "5552223344", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": null, "actualizadoEn": "2026-06-15T19:44:48.243Z", "regimenFiscal": null, "nombreCompleto": "Ana Ramírez", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": null}	{"rfc": null, "curp": null, "activo": true, "tutorId": 17, "usoCfdi": null, "creadoEn": "2026-06-15T19:44:48.243Z", "telefono": "5552223344", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": null, "actualizadoEn": "2026-06-16T02:10:06.974Z", "regimenFiscal": null, "nombreCompleto": "Ana Ramírez", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": null}	2026-06-16 02:10:06.985+00	127.0.0.1	\N
340	11	UPDATE	tutor	17	{"rfc": null, "curp": null, "activo": true, "tutorId": 17, "usoCfdi": null, "creadoEn": "2026-06-15T19:44:48.243Z", "telefono": "5552223344", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": null, "actualizadoEn": "2026-06-16T02:10:06.974Z", "regimenFiscal": null, "nombreCompleto": "Ana Ramírez", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": null}	{"rfc": null, "curp": null, "activo": true, "tutorId": 17, "usoCfdi": null, "creadoEn": "2026-06-15T19:44:48.243Z", "telefono": "5552223344", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": null, "actualizadoEn": "2026-06-16T02:10:08.503Z", "regimenFiscal": null, "nombreCompleto": "Ana Ramírez", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": null}	2026-06-16 02:10:08.508+00	127.0.0.1	\N
341	\N	UPDATE	usuario	7	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-15T19:06:27.96+00:00", "actualizado_en": "2026-06-15T19:44:47.739873+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T02:20:21.324+00:00", "actualizado_en": "2026-06-16T02:20:21.331778+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 02:20:21.331778+00	\N	Auditoría automática vía trigger fn_audit_trigger
342	7	UPDATE	alumno	210	{"curp": "TEST28996HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 210, "creado_en": "2026-06-15T20:53:10.48+00:00", "matricula": "TST-BAC-2A-JUWE-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:10.48+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Garcia Ramirez", "fecha_nacimiento": null, "personas_autorizadas": []}	{"curp": "TEST28996HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 4, "alumno_id": 210, "creado_en": "2026-06-15T20:53:10.48+00:00", "matricula": "TST-BAC-2A-JUWE-6", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-16T02:26:48.711863+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Garcia Ramire", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-16 02:26:48.711863+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
343	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-15T21:05:25.422+00:00", "actualizado_en": "2026-06-15T21:05:25.426008+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T04:13:09.489+00:00", "actualizado_en": "2026-06-16T04:13:09.501699+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 04:13:09.501699+00	\N	Auditoría automática vía trigger fn_audit_trigger
344	\N	UPDATE	usuario	17	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T00:23:48.339+00:00", "usuario_id": 17, "eliminado_en": null, "ultimo_acceso": "2026-06-16T00:25:25.435+00:00", "actualizado_en": "2026-06-16T00:25:25.442761+00:00", "nombre_usuario": "HARRY", "bloqueado_hasta": null, "nombre_completo": "Jose Manuel Fabian Hernandez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T00:23:48.339+00:00", "usuario_id": 17, "eliminado_en": null, "ultimo_acceso": "2026-06-16T06:51:52.122+00:00", "actualizado_en": "2026-06-16T06:51:52.136691+00:00", "nombre_usuario": "HARRY", "bloqueado_hasta": null, "nombre_completo": "Jose Manuel Fabian Hernandez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 06:51:52.136691+00	\N	Auditoría automática vía trigger fn_audit_trigger
345	\N	UPDATE	usuario	4	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T00:33:52.464+00:00", "actualizado_en": "2026-06-16T00:33:52.468863+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T06:53:51.373+00:00", "actualizado_en": "2026-06-16T06:53:51.380487+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 06:53:51.380487+00	\N	Auditoría automática vía trigger fn_audit_trigger
346	\N	UPDATE	usuario	11	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-16T00:35:01.065+00:00", "actualizado_en": "2026-06-16T00:35:01.071189+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-16T07:23:25.174+00:00", "actualizado_en": "2026-06-16T07:23:25.206475+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 07:23:25.206475+00	\N	Auditoría automática vía trigger fn_audit_trigger
347	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T04:13:09.489+00:00", "actualizado_en": "2026-06-16T04:13:09.501699+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T07:24:11.758+00:00", "actualizado_en": "2026-06-16T07:24:11.762641+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 07:24:11.762641+00	\N	Auditoría automática vía trigger fn_audit_trigger
348	\N	UPDATE	usuario	17	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T00:23:48.339+00:00", "usuario_id": 17, "eliminado_en": null, "ultimo_acceso": "2026-06-16T06:51:52.122+00:00", "actualizado_en": "2026-06-16T06:51:52.136691+00:00", "nombre_usuario": "HARRY", "bloqueado_hasta": null, "nombre_completo": "Jose Manuel Fabian Hernandez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T00:23:48.339+00:00", "usuario_id": 17, "eliminado_en": null, "ultimo_acceso": "2026-06-16T07:24:17.772+00:00", "actualizado_en": "2026-06-16T07:24:17.776294+00:00", "nombre_usuario": "HARRY", "bloqueado_hasta": null, "nombre_completo": "Jose Manuel Fabian Hernandez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 07:24:17.776294+00	\N	Auditoría automática vía trigger fn_audit_trigger
349	\N	UPDATE	usuario	11	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-16T07:23:25.174+00:00", "actualizado_en": "2026-06-16T07:23:25.206475+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-16T07:42:55.777+00:00", "actualizado_en": "2026-06-16T07:42:55.786599+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 07:42:55.786599+00	\N	Auditoría automática vía trigger fn_audit_trigger
350	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T07:24:11.758+00:00", "actualizado_en": "2026-06-16T07:24:11.762641+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:25:21.248+00:00", "actualizado_en": "2026-06-16T08:25:21.260902+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 08:25:21.260902+00	\N	Auditoría automática vía trigger fn_audit_trigger
351	6	INSERT	usuario	18	\N	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T08:34:16.39+00:00", "usuario_id": 18, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-16T08:34:16.39+00:00", "nombre_usuario": "Admin.c", "bloqueado_hasta": null, "nombre_completo": "Admin", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 08:34:16.37666+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
352	6	INSERT	usuario_rol	21	\N	{"activo": true, "rol_id": 1, "creado_en": "2026-06-16T08:34:16.39+00:00", "usuario_id": 18, "asignado_en": "2026-06-16T08:34:16.39+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-16T08:34:16.39+00:00", "usuario_rol_id": 21}	2026-06-16 08:34:16.37666+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
353	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:25:21.248+00:00", "actualizado_en": "2026-06-16T08:25:21.260902+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:36:07.276+00:00", "actualizado_en": "2026-06-16T08:36:07.28056+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 08:36:07.28056+00	\N	Auditoría automática vía trigger fn_audit_trigger
354	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:36:07.276+00:00", "actualizado_en": "2026-06-16T08:36:07.28056+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:36:54.098+00:00", "actualizado_en": "2026-06-16T08:36:54.100518+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 08:36:54.100518+00	\N	Auditoría automática vía trigger fn_audit_trigger
355	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:36:54.098+00:00", "actualizado_en": "2026-06-16T08:36:54.100518+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:37:27.967+00:00", "actualizado_en": "2026-06-16T08:37:27.969568+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 08:37:27.969568+00	\N	Auditoría automática vía trigger fn_audit_trigger
356	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:37:27.967+00:00", "actualizado_en": "2026-06-16T08:37:27.969568+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:38:03.565+00:00", "actualizado_en": "2026-06-16T08:38:03.569439+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 08:38:03.569439+00	\N	Auditoría automática vía trigger fn_audit_trigger
357	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:38:03.565+00:00", "actualizado_en": "2026-06-16T08:38:03.569439+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:41:02.286+00:00", "actualizado_en": "2026-06-16T08:41:02.288331+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 08:41:02.288331+00	\N	Auditoría automática vía trigger fn_audit_trigger
358	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:41:02.286+00:00", "actualizado_en": "2026-06-16T08:41:02.288331+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:42:04.513+00:00", "actualizado_en": "2026-06-16T08:42:04.514202+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 08:42:04.514202+00	\N	Auditoría automática vía trigger fn_audit_trigger
359	\N	UPDATE	usuario	8	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-14T18:44:45.42+00:00", "usuario_id": 8, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-15T19:44:47.794178+00:00", "nombre_usuario": "gestor.admin", "bloqueado_hasta": null, "nombre_completo": "Gestor Administrativo", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-14T18:44:45.42+00:00", "usuario_id": 8, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:47:00.09+00:00", "actualizado_en": "2026-06-16T08:47:00.097226+00:00", "nombre_usuario": "gestor.admin", "bloqueado_hasta": null, "nombre_completo": "Gestor Administrativo", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 08:47:00.097226+00	\N	Auditoría automática vía trigger fn_audit_trigger
360	\N	UPDATE	usuario	3	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-15T20:36:00.113+00:00", "actualizado_en": "2026-06-15T20:36:00.118613+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "laura.rios@sandiego.edu", "telefono": "9211112235", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 3, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:50:56.795+00:00", "actualizado_en": "2026-06-16T08:50:56.80245+00:00", "nombre_usuario": "laura.rios", "bloqueado_hasta": null, "nombre_completo": "Laura Ríos Méndez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 08:50:56.80245+00	\N	Auditoría automática vía trigger fn_audit_trigger
361	\N	UPDATE	usuario	4	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T06:53:51.373+00:00", "actualizado_en": "2026-06-16T06:53:51.380487+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:52:55.516+00:00", "actualizado_en": "2026-06-16T08:52:55.51896+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 08:52:55.51896+00	\N	Auditoría automática vía trigger fn_audit_trigger
362	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:42:04.513+00:00", "actualizado_en": "2026-06-16T08:42:04.514202+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:42:04.513+00:00", "actualizado_en": "2026-06-16T08:54:29.094719+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 1}	2026-06-16 08:54:29.094719+00	\N	Auditoría automática vía trigger fn_audit_trigger
363	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:42:04.513+00:00", "actualizado_en": "2026-06-16T08:54:29.094719+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 1}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:54:35.746+00:00", "actualizado_en": "2026-06-16T08:54:35.747363+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 08:54:35.747363+00	\N	Auditoría automática vía trigger fn_audit_trigger
364	\N	UPDATE	usuario	17	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T00:23:48.339+00:00", "usuario_id": 17, "eliminado_en": null, "ultimo_acceso": "2026-06-16T07:24:17.772+00:00", "actualizado_en": "2026-06-16T07:24:17.776294+00:00", "nombre_usuario": "HARRY", "bloqueado_hasta": null, "nombre_completo": "Jose Manuel Fabian Hernandez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T00:23:48.339+00:00", "usuario_id": 17, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:55:17.368+00:00", "actualizado_en": "2026-06-16T08:55:17.371022+00:00", "nombre_usuario": "HARRY", "bloqueado_hasta": null, "nombre_completo": "Jose Manuel Fabian Hernandez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 08:55:17.371022+00	\N	Auditoría automática vía trigger fn_audit_trigger
365	\N	UPDATE	usuario	11	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-16T07:42:55.777+00:00", "actualizado_en": "2026-06-16T07:42:55.786599+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:57:47.326+00:00", "actualizado_en": "2026-06-16T08:57:47.336259+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 08:57:47.336259+00	\N	Auditoría automática vía trigger fn_audit_trigger
366	6	INSERT	tutor	236	\N	{"rfc": "", "curp": null, "activo": true, "tutorId": 236, "usoCfdi": null, "creadoEn": "2026-06-16T09:04:45.828Z", "telefono": "4564654", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": null, "actualizadoEn": "2026-06-16T09:04:45.828Z", "regimenFiscal": "", "nombreCompleto": "Juan Perez", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": null, "correoElectronico": "fewfew", "correoFacturacion": ""}	2026-06-16 09:04:45.849+00	127.0.0.1	\N
367	6	UPDATE	tutor	3	{"rfc": "AUVC820923P89", "curp": "AUVC820923MVZGSR05", "activo": true, "tutorId": 3, "usoCfdi": null, "creadoEn": "2026-06-12T05:56:10.663Z", "telefono": "9212334455", "direccion": "Calle 5 de Mayo 89, Col. Petrolera, Coatzacoalcos, Ver.", "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "96500", "actualizadoEn": "2026-06-12T05:56:10.663Z", "regimenFiscal": "605", "nombreCompleto": "Carmen Aguilar Vásquez", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": "tarjeta", "correoElectronico": "carmen.aguilar@correo.com", "correoFacturacion": null}	{"rfc": "AUVC820923P89", "curp": "AUVC820923MVZGSR05", "activo": true, "tutorId": 3, "usoCfdi": null, "creadoEn": "2026-06-12T05:56:10.663Z", "telefono": "9212334455", "direccion": "Calle 5 de Mayo 89, Col. Petrolera, Coatzacoalcos, Ver.", "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "96500", "actualizadoEn": "2026-06-16T09:07:16.858Z", "regimenFiscal": "605", "nombreCompleto": "Carmen Aguilar Vásquez", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": "tarjeta", "correoElectronico": "carmen.aguilar@correo.com", "correoFacturacion": null}	2026-06-16 09:07:16.878+00	127.0.0.1	\N
368	6	UPDATE	tutor	3	{"rfc": "AUVC820923P89", "curp": "AUVC820923MVZGSR05", "activo": true, "tutorId": 3, "usoCfdi": null, "creadoEn": "2026-06-12T05:56:10.663Z", "telefono": "9212334455", "direccion": "Calle 5 de Mayo 89, Col. Petrolera, Coatzacoalcos, Ver.", "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "96500", "actualizadoEn": "2026-06-16T09:07:16.858Z", "regimenFiscal": "605", "nombreCompleto": "Carmen Aguilar Vásquez", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": "tarjeta", "correoElectronico": "carmen.aguilar@correo.com", "correoFacturacion": null}	{"rfc": "AUVC820923P89", "curp": "AUVC820923MVZGSR05", "activo": true, "tutorId": 3, "usoCfdi": null, "creadoEn": "2026-06-12T05:56:10.663Z", "telefono": "9212334455", "direccion": "Calle 5 de Mayo 89, Col. Petrolera, Coatzacoalcos, Ver.", "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "96500", "actualizadoEn": "2026-06-16T09:08:33.445Z", "regimenFiscal": "605", "nombreCompleto": "Carmen Aguilar Vásquez", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": "tarjeta", "correoElectronico": "carmen.aguilar@correo.com", "correoFacturacion": null}	2026-06-16 09:08:33.451+00	127.0.0.1	\N
369	11	INSERT	usuario	19	\N	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-16T09:11:54.679+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 09:11:54.667364+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
370	11	INSERT	usuario_rol	22	\N	{"activo": true, "rol_id": 3, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "asignado_en": "2026-06-16T09:11:54.679+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-16T09:11:54.679+00:00", "usuario_rol_id": 22}	2026-06-16 09:11:54.667364+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
371	\N	UPDATE	usuario	19	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-16T09:11:54.679+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:12:11.589+00:00", "actualizado_en": "2026-06-16T09:12:11.595546+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 09:12:11.595546+00	\N	Auditoría automática vía trigger fn_audit_trigger
372	19	INSERT	alumno	234	\N	{"curp": null, "sexo": null, "estado": "Activo", "nivel_id": null, "alumno_id": 234, "creado_en": "2026-06-16T09:14:36.555+00:00", "matricula": "SDM-1234-4569", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-16T09:14:36.555+00:00", "dia_limite_pago": null, "nombre_completo": "Francisco Javier Vivero", "fecha_nacimiento": "2017-07-13", "personas_autorizadas": []}	2026-06-16 09:14:36.545879+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
373	7	INSERT	usuario	20	\N	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:18:53.285+00:00", "usuario_id": 20, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-16T09:18:53.285+00:00", "nombre_usuario": "jessi", "bloqueado_hasta": null, "nombre_completo": "nuevoadmin", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 09:18:53.277069+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
375	6	UPDATE	alumno	10	{"curp": "CAHA111018HVZSRD01", "sexo": "M", "estado": "Activo", "nivel_id": 3, "alumno_id": 10, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2018-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T22:45:41.923852+00:00", "dia_limite_pago": null, "nombre_completo": "Adrián Castro Hernández", "fecha_nacimiento": "2011-10-18", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	{"curp": "CAHA111018HVZSRD01", "sexo": "M", "estado": "Activo", "nivel_id": 3, "alumno_id": 10, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2018-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-16T09:19:29.857047+00:00", "dia_limite_pago": null, "nombre_completo": "Adrián Castro Hernández", "fecha_nacimiento": "2011-10-18", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	2026-06-16 09:19:29.857047+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
376	7	UPDATE	usuario	5	{"activo": true, "correo": "patricia.nunez@sandiego.edu", "telefono": "9211112237", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 5, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-12T05:56:10.412081+00:00", "nombre_usuario": "patricia.nunez", "bloqueado_hasta": null, "nombre_completo": "Patricia Núñez García", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": false, "correo": "patricia.nunez@sandiego.edu", "telefono": "9211112237", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 5, "eliminado_en": "2026-06-16T09:20:33.664+00:00", "ultimo_acceso": null, "actualizado_en": "2026-06-16T09:20:33.659683+00:00", "nombre_usuario": "patricia.nunez", "bloqueado_hasta": null, "nombre_completo": "Patricia Núñez García", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 09:20:33.659683+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
377	\N	UPDATE	usuario	11	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:57:47.326+00:00", "actualizado_en": "2026-06-16T08:57:47.336259+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:21:15.509+00:00", "actualizado_en": "2026-06-16T09:21:15.512146+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 09:21:15.512146+00	\N	Auditoría automática vía trigger fn_audit_trigger
378	7	UPDATE	usuario	5	{"activo": false, "correo": "patricia.nunez@sandiego.edu", "telefono": "9211112237", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 5, "eliminado_en": "2026-06-16T09:20:33.664+00:00", "ultimo_acceso": null, "actualizado_en": "2026-06-16T09:20:33.659683+00:00", "nombre_usuario": "patricia.nunez", "bloqueado_hasta": null, "nombre_completo": "Patricia Núñez García", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "patricia.nunez@sandiego.edu", "telefono": "9211112237", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 5, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-16T09:22:02.046296+00:00", "nombre_usuario": "patricia.nunez", "bloqueado_hasta": null, "nombre_completo": "Patricia Núñez García", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 09:22:02.046296+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
379	7	UPDATE	usuario_rol	4	{"activo": true, "rol_id": 4, "creado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_id": 5, "asignado_en": "2026-06-12T05:56:10.624731+00:00", "asignado_por": 1, "eliminado_en": null, "actualizado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_rol_id": 4}	{"activo": true, "rol_id": 4, "creado_en": "2026-06-12T05:56:10.624731+00:00", "usuario_id": 5, "asignado_en": "2026-06-12T05:56:10.624731+00:00", "asignado_por": 1, "eliminado_en": null, "actualizado_en": "2026-06-16T09:22:02.046296+00:00", "usuario_rol_id": 4}	2026-06-16 09:22:02.046296+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
380	\N	UPDATE	usuario	20	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:18:53.285+00:00", "usuario_id": 20, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-16T09:18:53.285+00:00", "nombre_usuario": "jessi", "bloqueado_hasta": null, "nombre_completo": "nuevoadmin", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:18:53.285+00:00", "usuario_id": 20, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:23:40.413+00:00", "actualizado_en": "2026-06-16T09:23:40.416801+00:00", "nombre_usuario": "jessi", "bloqueado_hasta": null, "nombre_completo": "nuevoadmin", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 09:23:40.416801+00	\N	Auditoría automática vía trigger fn_audit_trigger
381	\N	UPDATE	usuario	7	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T02:20:21.324+00:00", "actualizado_en": "2026-06-16T02:20:21.331778+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:24:53.505+00:00", "actualizado_en": "2026-06-16T09:24:53.512371+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 09:24:53.512371+00	\N	Auditoría automática vía trigger fn_audit_trigger
382	7	UPDATE	usuario	20	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:18:53.285+00:00", "usuario_id": 20, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:23:40.413+00:00", "actualizado_en": "2026-06-16T09:23:40.416801+00:00", "nombre_usuario": "jessi", "bloqueado_hasta": null, "nombre_completo": "nuevoadmin", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": false, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:18:53.285+00:00", "usuario_id": 20, "eliminado_en": "2026-06-16T09:25:01.887+00:00", "ultimo_acceso": "2026-06-16T09:23:40.413+00:00", "actualizado_en": "2026-06-16T09:25:01.880832+00:00", "nombre_usuario": "jessi", "bloqueado_hasta": null, "nombre_completo": "nuevoadmin", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 09:25:01.880832+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
383	\N	UPDATE	usuario	19	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:12:11.589+00:00", "actualizado_en": "2026-06-16T09:12:11.595546+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:27:56.709+00:00", "actualizado_en": "2026-06-16T09:27:56.71262+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 09:27:56.71262+00	\N	Auditoría automática vía trigger fn_audit_trigger
384	\N	UPDATE	usuario	8	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-14T18:44:45.42+00:00", "usuario_id": 8, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:47:00.09+00:00", "actualizado_en": "2026-06-16T08:47:00.097226+00:00", "nombre_usuario": "gestor.admin", "bloqueado_hasta": null, "nombre_completo": "Gestor Administrativo", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-14T18:44:45.42+00:00", "usuario_id": 8, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:28:21.103+00:00", "actualizado_en": "2026-06-16T09:28:21.105591+00:00", "nombre_usuario": "gestor.admin", "bloqueado_hasta": null, "nombre_completo": "Gestor Administrativo", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 09:28:21.105591+00	\N	Auditoría automática vía trigger fn_audit_trigger
385	\N	UPDATE	usuario	19	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:27:56.709+00:00", "actualizado_en": "2026-06-16T09:27:56.71262+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:30:50.41+00:00", "actualizado_en": "2026-06-16T09:30:50.41631+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 09:30:50.41631+00	\N	Auditoría automática vía trigger fn_audit_trigger
386	19	INSERT	pago	14	\N	{"pago_id": 14, "tutor_id": 6, "alumno_id": 10, "fecha_pago": "2026-06-16", "metodo_pago": "efectivo", "monto_total": 1500.00, "observaciones": null, "registrado_en": "2026-06-16T09:32:35.984+00:00", "actualizado_en": "2026-06-16T09:32:35.984+00:00", "registrado_por": 19, "aplicado_a_saldo": false}	2026-06-16 09:32:35.971281+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
387	19	INSERT	pago	15	\N	{"pago_id": 15, "tutor_id": 6, "alumno_id": 10, "fecha_pago": "2026-06-16", "metodo_pago": "efectivo", "monto_total": 4500.00, "observaciones": null, "registrado_en": "2026-06-16T09:33:02.494+00:00", "actualizado_en": "2026-06-16T09:33:02.494+00:00", "registrado_por": 19, "aplicado_a_saldo": false}	2026-06-16 09:33:02.4719+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
388	\N	UPDATE	usuario	8	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-14T18:44:45.42+00:00", "usuario_id": 8, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:28:21.103+00:00", "actualizado_en": "2026-06-16T09:28:21.105591+00:00", "nombre_usuario": "gestor.admin", "bloqueado_hasta": null, "nombre_completo": "Gestor Administrativo", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-14T18:44:45.42+00:00", "usuario_id": 8, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:34:58.539+00:00", "actualizado_en": "2026-06-16T09:34:58.541911+00:00", "nombre_usuario": "gestor.admin", "bloqueado_hasta": null, "nombre_completo": "Gestor Administrativo", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 09:34:58.541911+00	\N	Auditoría automática vía trigger fn_audit_trigger
389	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:54:35.746+00:00", "actualizado_en": "2026-06-16T08:54:35.747363+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:35:03.988+00:00", "actualizado_en": "2026-06-16T09:35:03.988836+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 09:35:03.988836+00	\N	Auditoría automática vía trigger fn_audit_trigger
390	19	INSERT	pago	16	\N	{"pago_id": 16, "tutor_id": 6, "alumno_id": 10, "fecha_pago": "2026-06-16", "metodo_pago": "efectivo", "monto_total": 4500.00, "observaciones": null, "registrado_en": "2026-06-16T09:35:44.348+00:00", "actualizado_en": "2026-06-16T09:35:44.348+00:00", "registrado_por": 19, "aplicado_a_saldo": false}	2026-06-16 09:35:44.337237+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
391	\N	UPDATE	usuario	19	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:30:50.41+00:00", "actualizado_en": "2026-06-16T09:30:50.41631+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:44:11.837+00:00", "actualizado_en": "2026-06-16T09:44:11.84028+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 09:44:11.84028+00	\N	Auditoría automática vía trigger fn_audit_trigger
392	\N	UPDATE	usuario	19	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:44:11.837+00:00", "actualizado_en": "2026-06-16T09:44:11.84028+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:45:09.808+00:00", "actualizado_en": "2026-06-16T09:45:09.80962+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 09:45:09.80962+00	\N	Auditoría automática vía trigger fn_audit_trigger
393	19	INSERT	pago	17	\N	{"pago_id": 17, "tutor_id": 6, "alumno_id": 10, "fecha_pago": "2026-06-16", "metodo_pago": "efectivo", "monto_total": 4500.00, "observaciones": null, "registrado_en": "2026-06-16T09:45:30.73+00:00", "actualizado_en": "2026-06-16T09:45:30.73+00:00", "registrado_por": 19, "aplicado_a_saldo": false}	2026-06-16 09:45:30.720278+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
394	7	UPDATE	usuario	20	{"activo": false, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:18:53.285+00:00", "usuario_id": 20, "eliminado_en": "2026-06-16T09:25:01.887+00:00", "ultimo_acceso": "2026-06-16T09:23:40.413+00:00", "actualizado_en": "2026-06-16T09:25:01.880832+00:00", "nombre_usuario": "jessi", "bloqueado_hasta": null, "nombre_completo": "nuevoadmin", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:18:53.285+00:00", "usuario_id": 20, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:23:40.413+00:00", "actualizado_en": "2026-06-16T09:51:00.023076+00:00", "nombre_usuario": "jessi", "bloqueado_hasta": null, "nombre_completo": "nuevoadmin", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 09:51:00.023076+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
395	7	UPDATE	usuario_rol	23	{"activo": true, "rol_id": 1, "creado_en": "2026-06-16T09:18:53.285+00:00", "usuario_id": 20, "asignado_en": "2026-06-16T09:18:53.285+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-16T09:18:53.285+00:00", "usuario_rol_id": 23}	{"activo": true, "rol_id": 1, "creado_en": "2026-06-16T09:18:53.285+00:00", "usuario_id": 20, "asignado_en": "2026-06-16T09:18:53.285+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-16T09:51:00.023076+00:00", "usuario_rol_id": 23}	2026-06-16 09:51:00.023076+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
396	\N	UPDATE	usuario	19	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:45:09.808+00:00", "actualizado_en": "2026-06-16T09:45:09.80962+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:54:43.054+00:00", "actualizado_en": "2026-06-16T09:54:43.058379+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 09:54:43.058379+00	\N	Auditoría automática vía trigger fn_audit_trigger
397	7	INSERT	pago	18	\N	{"pago_id": 18, "tutor_id": 6, "alumno_id": 10, "fecha_pago": "2026-06-16", "metodo_pago": "efectivo", "monto_total": 4500.00, "observaciones": null, "registrado_en": "2026-06-16T10:00:16.274+00:00", "actualizado_en": "2026-06-16T10:00:16.274+00:00", "registrado_por": 7, "aplicado_a_saldo": false}	2026-06-16 10:00:16.264307+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
398	7	UPDATE	tutor	3	{"rfc": "AUVC820923P89", "curp": "AUVC820923MVZGSR05", "activo": true, "tutorId": 3, "usoCfdi": null, "creadoEn": "2026-06-12T05:56:10.663Z", "telefono": "9212334455", "direccion": "Calle 5 de Mayo 89, Col. Petrolera, Coatzacoalcos, Ver.", "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "96500", "actualizadoEn": "2026-06-16T09:08:33.445Z", "regimenFiscal": "605", "nombreCompleto": "Carmen Aguilar Vásquez", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": "tarjeta", "correoElectronico": "carmen.aguilar@correo.com", "correoFacturacion": null}	{"rfc": "AUVC820923P89", "curp": "AUVC820923MVZGSR05", "activo": true, "tutorId": 3, "usoCfdi": null, "creadoEn": "2026-06-12T05:56:10.663Z", "telefono": "9212334455", "direccion": "Calle 5 de Mayo 89, Col. Petrolera, Coatzacoalcos, Ver.", "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "96500", "actualizadoEn": "2026-06-16T10:04:40.323Z", "regimenFiscal": "605", "nombreCompleto": "Carmen Aguilar Vásquez", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": "tarjeta", "correoElectronico": "carmen.aguilar@correo.com", "correoFacturacion": null}	2026-06-16 10:04:40.34+00	127.0.0.1	\N
399	7	UPDATE	tutor	3	{"rfc": "AUVC820923P89", "curp": "AUVC820923MVZGSR05", "activo": true, "tutorId": 3, "usoCfdi": null, "creadoEn": "2026-06-12T05:56:10.663Z", "telefono": "9212334455", "direccion": "Calle 5 de Mayo 89, Col. Petrolera, Coatzacoalcos, Ver.", "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "96500", "actualizadoEn": "2026-06-16T10:04:40.323Z", "regimenFiscal": "605", "nombreCompleto": "Carmen Aguilar Vásquez", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": "tarjeta", "correoElectronico": "carmen.aguilar@correo.com", "correoFacturacion": null}	{"rfc": "AUVC820923P89", "curp": "AUVC820923MVZGSR05", "activo": true, "tutorId": 3, "usoCfdi": null, "creadoEn": "2026-06-12T05:56:10.663Z", "telefono": "9212334455", "direccion": "Calle 5 de Mayo 89, Col. Petrolera, Coatzacoalcos, Ver.", "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "96500", "actualizadoEn": "2026-06-16T10:04:43.213Z", "regimenFiscal": "605", "nombreCompleto": "Carmen Aguilar Vásquez", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": "tarjeta", "correoElectronico": "carmen.aguilar@correo.com", "correoFacturacion": null}	2026-06-16 10:04:43.221+00	127.0.0.1	\N
400	\N	UPDATE	usuario	11	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:21:15.509+00:00", "actualizado_en": "2026-06-16T09:21:15.512146+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-16T10:04:57.316+00:00", "actualizado_en": "2026-06-16T10:04:57.318294+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 10:04:57.318294+00	\N	Auditoría automática vía trigger fn_audit_trigger
401	\N	UPDATE	usuario	19	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:54:43.054+00:00", "actualizado_en": "2026-06-16T09:54:43.058379+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T10:10:08.152+00:00", "actualizado_en": "2026-06-16T10:10:08.154383+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 10:10:08.154383+00	\N	Auditoría automática vía trigger fn_audit_trigger
402	7	INSERT	tutor	244	\N	{"rfc": "RFDSJEUF", "curp": null, "activo": true, "tutorId": 244, "usoCfdi": null, "creadoEn": "2026-06-16T10:12:18.691Z", "telefono": "", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": null, "actualizadoEn": "2026-06-16T10:12:18.691Z", "regimenFiscal": "nose", "nombreCompleto": "juan vazques", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": null, "correoElectronico": "", "correoFacturacion": ""}	2026-06-16 10:12:18.698+00	127.0.0.1	\N
403	7	UPDATE	tutor	244	{"rfc": "RFDSJEUF", "curp": null, "activo": true, "tutorId": 244, "usoCfdi": null, "creadoEn": "2026-06-16T10:12:18.691Z", "telefono": "", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": null, "actualizadoEn": "2026-06-16T10:12:18.691Z", "regimenFiscal": "nose", "nombreCompleto": "juan vazques", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": null, "correoElectronico": "", "correoFacturacion": ""}	{"rfc": "RFDSJEUF", "curp": null, "activo": true, "tutorId": 244, "usoCfdi": null, "creadoEn": "2026-06-16T10:12:18.691Z", "telefono": "", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": null, "actualizadoEn": "2026-06-16T10:14:34.852Z", "regimenFiscal": "nose", "nombreCompleto": "juan vazques", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": null, "correoElectronico": "", "correoFacturacion": ""}	2026-06-16 10:14:34.86+00	127.0.0.1	\N
404	19	INSERT	tutor	245	\N	{"rfc": "awds", "curp": null, "activo": true, "tutorId": 245, "usoCfdi": "daw", "creadoEn": "2026-06-16T10:18:29.138Z", "telefono": null, "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "awsd", "actualizadoEn": "2026-06-16T10:18:29.138Z", "regimenFiscal": "daws", "nombreCompleto": "Jose", "direccionFiscal": "awsd", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": "daw"}	2026-06-16 10:18:29.145+00	127.0.0.1	\N
405	\N	UPDATE	usuario	17	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T00:23:48.339+00:00", "usuario_id": 17, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:55:17.368+00:00", "actualizado_en": "2026-06-16T08:55:17.371022+00:00", "nombre_usuario": "HARRY", "bloqueado_hasta": null, "nombre_completo": "Jose Manuel Fabian Hernandez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T00:23:48.339+00:00", "usuario_id": 17, "eliminado_en": null, "ultimo_acceso": "2026-06-16T10:26:00.517+00:00", "actualizado_en": "2026-06-16T10:26:00.521203+00:00", "nombre_usuario": "HARRY", "bloqueado_hasta": null, "nombre_completo": "Jose Manuel Fabian Hernandez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 10:26:00.521203+00	\N	Auditoría automática vía trigger fn_audit_trigger
406	\N	UPDATE	usuario	17	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T00:23:48.339+00:00", "usuario_id": 17, "eliminado_en": null, "ultimo_acceso": "2026-06-16T10:26:00.517+00:00", "actualizado_en": "2026-06-16T10:26:00.521203+00:00", "nombre_usuario": "HARRY", "bloqueado_hasta": null, "nombre_completo": "Jose Manuel Fabian Hernandez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T00:23:48.339+00:00", "usuario_id": 17, "eliminado_en": null, "ultimo_acceso": "2026-06-16T10:44:18.92+00:00", "actualizado_en": "2026-06-16T10:44:18.927358+00:00", "nombre_usuario": "HARRY", "bloqueado_hasta": null, "nombre_completo": "Jose Manuel Fabian Hernandez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 10:44:18.927358+00	\N	Auditoría automática vía trigger fn_audit_trigger
407	\N	UPDATE	usuario	4	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T08:52:55.516+00:00", "actualizado_en": "2026-06-16T08:52:55.51896+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T10:52:47.248+00:00", "actualizado_en": "2026-06-16T10:52:47.255504+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 10:52:47.255504+00	\N	Auditoría automática vía trigger fn_audit_trigger
408	7	INSERT	usuario	21	\N	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-16T10:53:00.766+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 10:53:00.757291+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
409	7	INSERT	usuario_rol	24	\N	{"activo": true, "rol_id": 4, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "asignado_en": "2026-06-16T10:53:00.766+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-16T10:53:00.766+00:00", "usuario_rol_id": 24}	2026-06-16 10:53:00.757291+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
410	\N	UPDATE	usuario	21	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-16T10:53:00.766+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T10:53:16.953+00:00", "actualizado_en": "2026-06-16T10:53:16.955815+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 10:53:16.955815+00	\N	Auditoría automática vía trigger fn_audit_trigger
411	\N	UPDATE	usuario	17	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T00:23:48.339+00:00", "usuario_id": 17, "eliminado_en": null, "ultimo_acceso": "2026-06-16T10:44:18.92+00:00", "actualizado_en": "2026-06-16T10:44:18.927358+00:00", "nombre_usuario": "HARRY", "bloqueado_hasta": null, "nombre_completo": "Jose Manuel Fabian Hernandez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T00:23:48.339+00:00", "usuario_id": 17, "eliminado_en": null, "ultimo_acceso": "2026-06-16T10:55:12.345+00:00", "actualizado_en": "2026-06-16T10:55:12.350073+00:00", "nombre_usuario": "HARRY", "bloqueado_hasta": null, "nombre_completo": "Jose Manuel Fabian Hernandez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 10:55:12.350073+00	\N	Auditoría automática vía trigger fn_audit_trigger
420	\N	UPDATE	usuario	11	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-16T10:04:57.316+00:00", "actualizado_en": "2026-06-16T10:04:57.318294+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-16T11:20:40.218+00:00", "actualizado_en": "2026-06-16T11:20:40.223147+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 11:20:40.223147+00	\N	Auditoría automática vía trigger fn_audit_trigger
412	\N	UPDATE	usuario	7	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:24:53.505+00:00", "actualizado_en": "2026-06-16T09:24:53.512371+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:24:53.505+00:00", "actualizado_en": "2026-06-16T10:56:07.19141+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 1}	2026-06-16 10:56:07.19141+00	\N	Auditoría automática vía trigger fn_audit_trigger
413	\N	UPDATE	usuario	7	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:24:53.505+00:00", "actualizado_en": "2026-06-16T10:56:07.19141+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 1}	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:24:53.505+00:00", "actualizado_en": "2026-06-16T10:58:07.039833+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 2}	2026-06-16 10:58:07.039833+00	\N	Auditoría automática vía trigger fn_audit_trigger
414	\N	UPDATE	usuario	7	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:24:53.505+00:00", "actualizado_en": "2026-06-16T10:58:07.039833+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 2}	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:24:53.505+00:00", "actualizado_en": "2026-06-16T10:58:09.747182+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 3}	2026-06-16 10:58:09.747182+00	\N	Auditoría automática vía trigger fn_audit_trigger
415	\N	UPDATE	usuario	7	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:24:53.505+00:00", "actualizado_en": "2026-06-16T10:58:09.747182+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 3}	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T10:58:17.806+00:00", "actualizado_en": "2026-06-16T10:58:17.808345+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 10:58:17.808345+00	\N	Auditoría automática vía trigger fn_audit_trigger
416	\N	UPDATE	usuario	4	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T10:52:47.248+00:00", "actualizado_en": "2026-06-16T10:52:47.255504+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T10:58:19.148+00:00", "actualizado_en": "2026-06-16T10:58:19.151275+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 10:58:19.151275+00	\N	Auditoría automática vía trigger fn_audit_trigger
417	\N	UPDATE	usuario	17	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T00:23:48.339+00:00", "usuario_id": 17, "eliminado_en": null, "ultimo_acceso": "2026-06-16T10:55:12.345+00:00", "actualizado_en": "2026-06-16T10:55:12.350073+00:00", "nombre_usuario": "HARRY", "bloqueado_hasta": null, "nombre_completo": "Jose Manuel Fabian Hernandez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T00:23:48.339+00:00", "usuario_id": 17, "eliminado_en": null, "ultimo_acceso": "2026-06-16T11:04:26.078+00:00", "actualizado_en": "2026-06-16T11:04:26.085877+00:00", "nombre_usuario": "HARRY", "bloqueado_hasta": null, "nombre_completo": "Jose Manuel Fabian Hernandez", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 11:04:26.085877+00	\N	Auditoría automática vía trigger fn_audit_trigger
418	\N	UPDATE	usuario	19	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T10:10:08.152+00:00", "actualizado_en": "2026-06-16T10:10:08.154383+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T11:18:30.464+00:00", "actualizado_en": "2026-06-16T11:18:30.46524+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 11:18:30.46524+00	\N	Auditoría automática vía trigger fn_audit_trigger
419	19	INSERT	tutor	246	\N	{"rfc": "LKJPPPPPPPPPP", "curp": null, "activo": true, "tutorId": 246, "usoCfdi": "aa", "creadoEn": "2026-06-16T11:19:13.242Z", "telefono": null, "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "aaa", "actualizadoEn": "2026-06-16T11:19:13.242Z", "regimenFiscal": "aa", "nombreCompleto": "Harry", "direccionFiscal": "aa", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": "aa"}	2026-06-16 11:19:13.255+00	127.0.0.1	\N
421	\N	UPDATE	usuario	19	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T11:18:30.464+00:00", "actualizado_en": "2026-06-16T11:18:30.46524+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T11:36:46.972+00:00", "actualizado_en": "2026-06-16T11:36:46.975204+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 11:36:46.975204+00	\N	Auditoría automática vía trigger fn_audit_trigger
422	19	INSERT	tutor_alumno	242	\N	{"activo": true, "tutorId": 10, "alumnoId": 234, "creadoEn": "2026-06-16T11:37:21.820Z", "eliminadoEn": null, "puedeRecoger": true, "tipoRelacion": "tutor", "actualizadoEn": "2026-06-16T11:37:21.820Z", "tutorAlumnoId": 242, "recibeNotificaciones": true, "esResponsableFinanciero": false}	2026-06-16 11:37:21.841+00	127.0.0.1	\N
423	\N	UPDATE	usuario	19	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T11:36:46.972+00:00", "actualizado_en": "2026-06-16T11:36:46.975204+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T11:40:13.924+00:00", "actualizado_en": "2026-06-16T11:40:13.926361+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 11:40:13.926361+00	\N	Auditoría automática vía trigger fn_audit_trigger
424	\N	UPDATE	usuario	8	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-14T18:44:45.42+00:00", "usuario_id": 8, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:34:58.539+00:00", "actualizado_en": "2026-06-16T09:34:58.541911+00:00", "nombre_usuario": "gestor.admin", "bloqueado_hasta": null, "nombre_completo": "Gestor Administrativo", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-14T18:44:45.42+00:00", "usuario_id": 8, "eliminado_en": null, "ultimo_acceso": "2026-06-16T11:40:47.061+00:00", "actualizado_en": "2026-06-16T11:40:47.064328+00:00", "nombre_usuario": "gestor.admin", "bloqueado_hasta": null, "nombre_completo": "Gestor Administrativo", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 11:40:47.064328+00	\N	Auditoría automática vía trigger fn_audit_trigger
425	\N	UPDATE	usuario	8	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-14T18:44:45.42+00:00", "usuario_id": 8, "eliminado_en": null, "ultimo_acceso": "2026-06-16T11:40:47.061+00:00", "actualizado_en": "2026-06-16T11:40:47.064328+00:00", "nombre_usuario": "gestor.admin", "bloqueado_hasta": null, "nombre_completo": "Gestor Administrativo", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-14T18:44:45.42+00:00", "usuario_id": 8, "eliminado_en": null, "ultimo_acceso": "2026-06-16T11:41:16.884+00:00", "actualizado_en": "2026-06-16T11:41:16.890591+00:00", "nombre_usuario": "gestor.admin", "bloqueado_hasta": null, "nombre_completo": "Gestor Administrativo", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 11:41:16.890591+00	\N	Auditoría automática vía trigger fn_audit_trigger
426	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T09:35:03.988+00:00", "actualizado_en": "2026-06-16T09:35:03.988836+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T11:41:31.86+00:00", "actualizado_en": "2026-06-16T11:41:31.86557+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 11:41:31.86557+00	\N	Auditoría automática vía trigger fn_audit_trigger
427	6	UPDATE	tutor	246	{"rfc": "LKJPPPPPPPPPP", "curp": null, "activo": true, "tutorId": 246, "usoCfdi": "aa", "creadoEn": "2026-06-16T11:19:13.242Z", "telefono": null, "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "aaa", "actualizadoEn": "2026-06-16T11:19:13.242Z", "regimenFiscal": "aa", "nombreCompleto": "Harry", "direccionFiscal": "aa", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": "aa"}	{"rfc": "LKJPPPPPPPPPP", "curp": null, "activo": true, "tutorId": 246, "usoCfdi": "aa", "creadoEn": "2026-06-16T11:19:13.242Z", "telefono": null, "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "aaa", "actualizadoEn": "2026-06-16T11:45:45.466Z", "regimenFiscal": "aa", "nombreCompleto": "Harry", "direccionFiscal": "aa", "requiereFactura": false, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": "aa"}	2026-06-16 11:45:45.476+00	127.0.0.1	\N
428	6	UPDATE	tutor	246	{"rfc": "LKJPPPPPPPPPP", "curp": null, "activo": true, "tutorId": 246, "usoCfdi": "aa", "creadoEn": "2026-06-16T11:19:13.242Z", "telefono": null, "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "aaa", "actualizadoEn": "2026-06-16T11:45:45.466Z", "regimenFiscal": "aa", "nombreCompleto": "Harry", "direccionFiscal": "aa", "requiereFactura": false, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": "aa"}	{"rfc": "LKJPPPPPPPPPP", "curp": null, "activo": true, "tutorId": 246, "usoCfdi": "aa", "creadoEn": "2026-06-16T11:19:13.242Z", "telefono": null, "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "aaawe", "actualizadoEn": "2026-06-16T11:46:18.858Z", "regimenFiscal": "aa", "nombreCompleto": "Harry", "direccionFiscal": "aa", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": "a@gmail.com"}	2026-06-16 11:46:18.87+00	127.0.0.1	\N
460	\N	UPDATE	usuario	22	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T13:07:38.047+00:00", "usuario_id": 22, "eliminado_en": null, "ultimo_acceso": "2026-06-16T13:08:14.344+00:00", "actualizado_en": "2026-06-16T13:08:14.347322+00:00", "nombre_usuario": "jessy", "bloqueado_hasta": null, "nombre_completo": "jessica gestor", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T13:07:38.047+00:00", "usuario_id": 22, "eliminado_en": null, "ultimo_acceso": "2026-06-16T13:11:42.875+00:00", "actualizado_en": "2026-06-16T13:11:42.877694+00:00", "nombre_usuario": "jessy", "bloqueado_hasta": null, "nombre_completo": "jessica gestor", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 13:11:42.877694+00	\N	Auditoría automática vía trigger fn_audit_trigger
429	6	UPDATE	tutor	246	{"rfc": "LKJPPPPPPPPPP", "curp": null, "activo": true, "tutorId": 246, "usoCfdi": "aa", "creadoEn": "2026-06-16T11:19:13.242Z", "telefono": null, "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "aaawe", "actualizadoEn": "2026-06-16T11:46:18.858Z", "regimenFiscal": "aa", "nombreCompleto": "Harry", "direccionFiscal": "aa", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": "a@gmail.com"}	{"rfc": "LKJPPPPPPPPPP", "curp": null, "activo": true, "tutorId": 246, "usoCfdi": "aa", "creadoEn": "2026-06-16T11:19:13.242Z", "telefono": null, "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "aaawe", "actualizadoEn": "2026-06-16T11:46:29.873Z", "regimenFiscal": "612", "nombreCompleto": "Harry", "direccionFiscal": "aa", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": "a@gmail.com"}	2026-06-16 11:46:29.879+00	127.0.0.1	\N
430	19	UPDATE	tutor	10	{"rfc": "oai", "curp": null, "activo": true, "tutorId": 10, "usoCfdi": "G01", "creadoEn": "2026-06-14T18:44:45.775Z", "telefono": "5552223344", "direccion": "lop", "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "56", "actualizadoEn": "2026-06-15T10:56:37.455Z", "regimenFiscal": "625", "nombreCompleto": "Ana Ramírez", "direccionFiscal": "lopez", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": "lop", "correoFacturacion": "lpp"}	{"rfc": "OAIPPPPPPPPPP", "curp": null, "activo": true, "tutorId": 10, "usoCfdi": "G01", "creadoEn": "2026-06-14T18:44:45.775Z", "telefono": "5552223344", "direccion": "lop", "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "56999", "actualizadoEn": "2026-06-16T11:48:18.945Z", "regimenFiscal": "625", "nombreCompleto": "Ana Ramírez", "direccionFiscal": "lopez", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": "lop", "correoFacturacion": "lpp@"}	2026-06-16 11:48:18.952+00	127.0.0.1	\N
431	19	UPDATE	tutor	10	{"rfc": "OAIPPPPPPPPPP", "curp": null, "activo": true, "tutorId": 10, "usoCfdi": "G01", "creadoEn": "2026-06-14T18:44:45.775Z", "telefono": "5552223344", "direccion": "lop", "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "56999", "actualizadoEn": "2026-06-16T11:48:18.945Z", "regimenFiscal": "625", "nombreCompleto": "Ana Ramírez", "direccionFiscal": "lopez", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": "lop", "correoFacturacion": "lpp@"}	{"rfc": "OAIPPPPPPPPPP", "curp": null, "activo": true, "tutorId": 10, "usoCfdi": "G01", "creadoEn": "2026-06-14T18:44:45.775Z", "telefono": "5552223344", "direccion": "lop", "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "56999", "actualizadoEn": "2026-06-16T11:48:27.903Z", "regimenFiscal": "625", "nombreCompleto": "Ana Ramírez", "direccionFiscal": "lopez", "requiereFactura": false, "tipoPagoHabitual": null, "correoElectronico": "lop", "correoFacturacion": "lpp@"}	2026-06-16 11:48:27.906+00	127.0.0.1	\N
432	6	UPDATE	tutor	20	{"rfc": null, "curp": null, "activo": true, "tutorId": 20, "usoCfdi": null, "creadoEn": "2026-06-15T19:44:48.352Z", "telefono": "5553456789", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": null, "actualizadoEn": "2026-06-15T19:44:48.352Z", "regimenFiscal": null, "nombreCompleto": "Elena Soto", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": null}	{"rfc": null, "curp": null, "activo": true, "tutorId": 20, "usoCfdi": null, "creadoEn": "2026-06-15T19:44:48.352Z", "telefono": "5553456789", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": null, "actualizadoEn": "2026-06-16T11:49:52.905Z", "regimenFiscal": null, "nombreCompleto": "Elena Soto", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": null}	2026-06-16 11:49:52.912+00	127.0.0.1	\N
433	6	UPDATE	tutor	20	{"rfc": null, "curp": null, "activo": true, "tutorId": 20, "usoCfdi": null, "creadoEn": "2026-06-15T19:44:48.352Z", "telefono": "5553456789", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": null, "actualizadoEn": "2026-06-16T11:49:52.905Z", "regimenFiscal": null, "nombreCompleto": "Elena Soto", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": null}	{"rfc": null, "curp": null, "activo": true, "tutorId": 20, "usoCfdi": null, "creadoEn": "2026-06-15T19:44:48.352Z", "telefono": "5553456789", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": null, "actualizadoEn": "2026-06-16T11:50:56.174Z", "regimenFiscal": null, "nombreCompleto": "Elena Soto", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": null}	2026-06-16 11:50:56.179+00	127.0.0.1	\N
434	6	UPDATE	tutor	20	{"rfc": null, "curp": null, "activo": true, "tutorId": 20, "usoCfdi": null, "creadoEn": "2026-06-15T19:44:48.352Z", "telefono": "5553456789", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": null, "actualizadoEn": "2026-06-16T11:50:56.174Z", "regimenFiscal": null, "nombreCompleto": "Elena Soto", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": null}	{"rfc": "FSDFSSSSSSSSS", "curp": null, "activo": true, "tutorId": 20, "usoCfdi": "D05", "creadoEn": "2026-06-15T19:44:48.352Z", "telefono": "5553456789", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "23453", "actualizadoEn": "2026-06-16T11:54:50.299Z", "regimenFiscal": "606", "nombreCompleto": "Elena Soto", "direccionFiscal": "sdgegw", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": "wefewdfwe@"}	2026-06-16 11:54:50.314+00	127.0.0.1	\N
435	6	UPDATE	tutor	13	{"rfc": null, "curp": null, "activo": true, "tutorId": 13, "usoCfdi": null, "creadoEn": "2026-06-14T18:44:45.841Z", "telefono": "5553456789", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": null, "actualizadoEn": "2026-06-14T18:44:45.841Z", "regimenFiscal": null, "nombreCompleto": "Elena Soto", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": null}	{"rfc": "QWDQWDQWDQWD", "curp": null, "activo": true, "tutorId": 13, "usoCfdi": "D05", "creadoEn": "2026-06-14T18:44:45.841Z", "telefono": "5553456789", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "12342", "actualizadoEn": "2026-06-16T11:56:01.382Z", "regimenFiscal": "610", "nombreCompleto": "Elena Soto", "direccionFiscal": "vcasv", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": "vdav@"}	2026-06-16 11:56:01.389+00	127.0.0.1	\N
461	\N	UPDATE	usuario	19	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T12:47:30.092+00:00", "actualizado_en": "2026-06-16T12:47:30.096659+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T13:15:50.569+00:00", "actualizado_en": "2026-06-16T13:15:50.572778+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 13:15:50.572778+00	\N	Auditoría automática vía trigger fn_audit_trigger
436	6	UPDATE	tutor	13	{"rfc": "QWDQWDQWDQWD", "curp": null, "activo": true, "tutorId": 13, "usoCfdi": "D05", "creadoEn": "2026-06-14T18:44:45.841Z", "telefono": "5553456789", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "12342", "actualizadoEn": "2026-06-16T11:56:01.382Z", "regimenFiscal": "610", "nombreCompleto": "Elena Soto", "direccionFiscal": "vcasv", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": "vdav@"}	{"rfc": "QWDQWDQWDQWD", "curp": null, "activo": true, "tutorId": 13, "usoCfdi": "D05", "creadoEn": "2026-06-14T18:44:45.841Z", "telefono": "5553456789", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "12342", "actualizadoEn": "2026-06-16T11:56:02.065Z", "regimenFiscal": "610", "nombreCompleto": "Elena Soto", "direccionFiscal": "vcasv", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": "vdav@"}	2026-06-16 11:56:02.071+00	127.0.0.1	\N
437	19	UPDATE	tutor	10	{"rfc": "OAIPPPPPPPPPP", "curp": null, "activo": true, "tutorId": 10, "usoCfdi": "G01", "creadoEn": "2026-06-14T18:44:45.775Z", "telefono": "5552223344", "direccion": "lop", "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "56999", "actualizadoEn": "2026-06-16T11:48:27.903Z", "regimenFiscal": "625", "nombreCompleto": "Ana Ramírez", "direccionFiscal": "lopez", "requiereFactura": false, "tipoPagoHabitual": null, "correoElectronico": "lop", "correoFacturacion": "lpp@"}	{"rfc": "OAIPPPPPPPPPP", "curp": null, "activo": true, "tutorId": 10, "usoCfdi": "G01", "creadoEn": "2026-06-14T18:44:45.775Z", "telefono": "5552223344", "direccion": "lop", "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "56999", "actualizadoEn": "2026-06-16T11:56:29.140Z", "regimenFiscal": "625", "nombreCompleto": "Ana Ramírez", "direccionFiscal": "lopez", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": "lop", "correoFacturacion": "lpp@"}	2026-06-16 11:56:29.156+00	127.0.0.1	\N
438	19	UPDATE	tutor	10	{"rfc": "OAIPPPPPPPPPP", "curp": null, "activo": true, "tutorId": 10, "usoCfdi": "G01", "creadoEn": "2026-06-14T18:44:45.775Z", "telefono": "5552223344", "direccion": "lop", "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "56999", "actualizadoEn": "2026-06-16T11:56:29.140Z", "regimenFiscal": "625", "nombreCompleto": "Ana Ramírez", "direccionFiscal": "lopez", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": "lop", "correoFacturacion": "lpp@"}	{"rfc": "OAIPPPPPPPPPO", "curp": null, "activo": true, "tutorId": 10, "usoCfdi": "G01", "creadoEn": "2026-06-14T18:44:45.775Z", "telefono": "5552223344", "direccion": "lop", "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "56999", "actualizadoEn": "2026-06-16T11:56:43.718Z", "regimenFiscal": "625", "nombreCompleto": "Ana Ramírez", "direccionFiscal": "lopez", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": "lop", "correoFacturacion": "lpp@"}	2026-06-16 11:56:43.724+00	127.0.0.1	\N
439	19	INSERT	alumno	235	\N	{"curp": null, "sexo": null, "estado": "Activo", "nivel_id": null, "alumno_id": 235, "creado_en": "2026-06-16T12:00:42.523+00:00", "matricula": "SDM-1593-3214", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-16T12:00:42.523+00:00", "dia_limite_pago": null, "nombre_completo": "Lusito Reyes", "fecha_nacimiento": "2016-01-01", "personas_autorizadas": []}	2026-06-16 12:00:42.508808+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
440	7	INSERT	alumno	236	\N	{"curp": "TEST982165HDFRRN01", "sexo": null, "estado": "Activo", "nivel_id": null, "alumno_id": 236, "creado_en": "2026-06-16T12:01:13.68+00:00", "matricula": "SDM-2026-2026", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-16T12:01:13.68+00:00", "dia_limite_pago": null, "nombre_completo": "juanito gutierritos perez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-16 12:01:13.6751+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
441	7	UPDATE	alumno	10	{"curp": "CAHA111018HVZSRD01", "sexo": "M", "estado": "Activo", "nivel_id": 3, "alumno_id": 10, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2018-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-16T09:19:29.857047+00:00", "dia_limite_pago": null, "nombre_completo": "Adrián Castro Hernández", "fecha_nacimiento": "2011-10-18", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	{"curp": "CAHA111018HVZSRD01", "sexo": "M", "estado": "Baja Temporal", "nivel_id": 3, "alumno_id": 10, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2018-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "[BAJA TEMPORAL 16/6/2026]: por gei", "actualizado_en": "2026-06-16T12:02:15.259383+00:00", "dia_limite_pago": null, "nombre_completo": "Adrián Castro Hernández", "fecha_nacimiento": "2011-10-18", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	2026-06-16 12:02:15.259383+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
442	7	UPDATE	alumno	10	{"curp": "CAHA111018HVZSRD01", "sexo": "M", "estado": "Baja Temporal", "nivel_id": 3, "alumno_id": 10, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2018-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "[BAJA TEMPORAL 16/6/2026]: por gei", "actualizado_en": "2026-06-16T12:02:15.259383+00:00", "dia_limite_pago": null, "nombre_completo": "Adrián Castro Hernández", "fecha_nacimiento": "2011-10-18", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	{"curp": "CAHA111018HVZSRD01", "sexo": "M", "estado": "Activo", "nivel_id": 3, "alumno_id": 10, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2018-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "[BAJA TEMPORAL 16/6/2026]: por gei\\n[REACTIVACIÓN 16/6/2026]: porque ya no es gei", "actualizado_en": "2026-06-16T12:02:33.491384+00:00", "dia_limite_pago": null, "nombre_completo": "Adrián Castro Hernández", "fecha_nacimiento": "2011-10-18", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	2026-06-16 12:02:33.491384+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
443	19	UPDATE	alumno	234	{"curp": null, "sexo": null, "estado": "Activo", "nivel_id": null, "alumno_id": 234, "creado_en": "2026-06-16T09:14:36.555+00:00", "matricula": "SDM-1234-4569", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-16T09:14:36.555+00:00", "dia_limite_pago": null, "nombre_completo": "Francisco Javier Vivero", "fecha_nacimiento": "2017-07-13", "personas_autorizadas": []}	{"curp": null, "sexo": null, "estado": "Baja Temporal", "nivel_id": null, "alumno_id": 234, "creado_en": "2026-06-16T09:14:36.555+00:00", "matricula": "SDM-1234-4569", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "[BAJA TEMPORAL 16/6/2026]: Falta mucho", "actualizado_en": "2026-06-16T12:02:37.121307+00:00", "dia_limite_pago": null, "nombre_completo": "Francisco Javier Vivero", "fecha_nacimiento": "2017-07-13", "personas_autorizadas": []}	2026-06-16 12:02:37.121307+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
444	19	UPDATE	alumno	234	{"curp": null, "sexo": null, "estado": "Baja Temporal", "nivel_id": null, "alumno_id": 234, "creado_en": "2026-06-16T09:14:36.555+00:00", "matricula": "SDM-1234-4569", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "[BAJA TEMPORAL 16/6/2026]: Falta mucho", "actualizado_en": "2026-06-16T12:02:37.121307+00:00", "dia_limite_pago": null, "nombre_completo": "Francisco Javier Vivero", "fecha_nacimiento": "2017-07-13", "personas_autorizadas": []}	{"curp": null, "sexo": null, "estado": "Activo", "nivel_id": null, "alumno_id": 234, "creado_en": "2026-06-16T09:14:36.555+00:00", "matricula": "SDM-1234-4569", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "[BAJA TEMPORAL 16/6/2026]: Falta mucho\\n[REACTIVACIÓN 16/6/2026]: Pago mucho dinero", "actualizado_en": "2026-06-16T12:03:16.765953+00:00", "dia_limite_pago": null, "nombre_completo": "Francisco Javier Vivero", "fecha_nacimiento": "2017-07-13", "personas_autorizadas": []}	2026-06-16 12:03:16.765953+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
445	19	UPDATE	alumno	234	{"curp": null, "sexo": null, "estado": "Activo", "nivel_id": null, "alumno_id": 234, "creado_en": "2026-06-16T09:14:36.555+00:00", "matricula": "SDM-1234-4569", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "[BAJA TEMPORAL 16/6/2026]: Falta mucho\\n[REACTIVACIÓN 16/6/2026]: Pago mucho dinero", "actualizado_en": "2026-06-16T12:03:16.765953+00:00", "dia_limite_pago": null, "nombre_completo": "Francisco Javier Vivero", "fecha_nacimiento": "2017-07-13", "personas_autorizadas": []}	{"curp": null, "sexo": null, "estado": "Activo", "nivel_id": 3, "alumno_id": 234, "creado_en": "2026-06-16T09:14:36.555+00:00", "matricula": "SDM-1234-4569", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "[BAJA TEMPORAL 16/6/2026]: Falta mucho\\n[REACTIVACIÓN 16/6/2026]: Pago mucho dinero", "actualizado_en": "2026-06-16T12:07:07.158414+00:00", "dia_limite_pago": null, "nombre_completo": "Francisco Javier Salmones", "fecha_nacimiento": "2017-07-04", "personas_autorizadas": []}	2026-06-16 12:07:07.158414+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
446	7	UPDATE	alumno	10	{"curp": "CAHA111018HVZSRD01", "sexo": "M", "estado": "Activo", "nivel_id": 3, "alumno_id": 10, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2018-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "[BAJA TEMPORAL 16/6/2026]: por gei\\n[REACTIVACIÓN 16/6/2026]: porque ya no es gei", "actualizado_en": "2026-06-16T12:02:33.491384+00:00", "dia_limite_pago": null, "nombre_completo": "Adrián Castro Hernández", "fecha_nacimiento": "2011-10-18", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	{"curp": "CAHA111018HVZSRD01", "sexo": "M", "estado": "Activo", "nivel_id": 3, "alumno_id": 10, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2018-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "[BAJA TEMPORAL 16/6/2026]: por gei\\n[REACTIVACIÓN 16/6/2026]: porque ya no es gei", "actualizado_en": "2026-06-16T12:08:46.984243+00:00", "dia_limite_pago": null, "nombre_completo": "Adrián Castro H", "fecha_nacimiento": "2011-10-18", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	2026-06-16 12:08:46.984243+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
447	19	UPDATE	alumno	10	{"curp": "CAHA111018HVZSRD01", "sexo": "M", "estado": "Activo", "nivel_id": 3, "alumno_id": 10, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2018-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "[BAJA TEMPORAL 16/6/2026]: por gei\\n[REACTIVACIÓN 16/6/2026]: porque ya no es gei", "actualizado_en": "2026-06-16T12:08:46.984243+00:00", "dia_limite_pago": null, "nombre_completo": "Adrián Castro H", "fecha_nacimiento": "2011-10-18", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	{"curp": "CAHA111018HVZSRD01", "sexo": "M", "estado": "Activo", "nivel_id": 4, "alumno_id": 10, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2018-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "[BAJA TEMPORAL 16/6/2026]: por gei\\n[REACTIVACIÓN 16/6/2026]: porque ya no es gei", "actualizado_en": "2026-06-16T12:18:16.709295+00:00", "dia_limite_pago": null, "nombre_completo": "Adrián Castro H", "fecha_nacimiento": "2011-10-18", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	2026-06-16 12:18:16.709295+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
448	19	UPDATE	alumno	10	{"curp": "CAHA111018HVZSRD01", "sexo": "M", "estado": "Activo", "nivel_id": 4, "alumno_id": 10, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2018-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "[BAJA TEMPORAL 16/6/2026]: por gei\\n[REACTIVACIÓN 16/6/2026]: porque ya no es gei", "actualizado_en": "2026-06-16T12:18:16.709295+00:00", "dia_limite_pago": null, "nombre_completo": "Adrián Castro H", "fecha_nacimiento": "2011-10-18", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	{"curp": "CAHA111018HVZSRD01", "sexo": "M", "estado": "Activo", "nivel_id": 4, "alumno_id": 10, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2018-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "[BAJA TEMPORAL 16/6/2026]: por gei\\n[REACTIVACIÓN 16/6/2026]: porque ya no es gei", "actualizado_en": "2026-06-16T12:45:25.308474+00:00", "dia_limite_pago": null, "nombre_completo": "Adrián Castro H", "fecha_nacimiento": "2011-10-18", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	2026-06-16 12:45:25.308474+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
449	6	UPDATE	alumno	136	{"curp": "TEST63288HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 136, "creado_en": "2026-06-15T20:53:08.783+00:00", "matricula": "TST-PRI-5A-X5G2-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:53:08.783+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Reyes Vazquez", "fecha_nacimiento": null, "personas_autorizadas": []}	{"curp": "TEST63288HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 136, "creado_en": "2026-06-15T20:53:08.783+00:00", "matricula": "TST-PRI-5A-X5G2-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-16T12:45:37.178809+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Reyes Vazquez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-16 12:45:37.178809+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
450	6	UPDATE	alumno	136	{"curp": "TEST63288HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 136, "creado_en": "2026-06-15T20:53:08.783+00:00", "matricula": "TST-PRI-5A-X5G2-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-16T12:45:37.178809+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Reyes Vazquez", "fecha_nacimiento": null, "personas_autorizadas": []}	{"curp": "TEST63288HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 136, "creado_en": "2026-06-15T20:53:08.783+00:00", "matricula": "TST-PRI-5A-X5G2-2", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-16T12:45:37.748965+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Reyes Vazquez", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-16 12:45:37.748965+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
451	7	UPDATE	alumno	10	{"curp": "CAHA111018HVZSRD01", "sexo": "M", "estado": "Activo", "nivel_id": 4, "alumno_id": 10, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2018-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "[BAJA TEMPORAL 16/6/2026]: por gei\\n[REACTIVACIÓN 16/6/2026]: porque ya no es gei", "actualizado_en": "2026-06-16T12:45:25.308474+00:00", "dia_limite_pago": null, "nombre_completo": "Adrián Castro H", "fecha_nacimiento": "2011-10-18", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	{"curp": "CAHA111018HVZSRD01", "sexo": "M", "estado": "Activo", "nivel_id": 3, "alumno_id": 10, "creado_en": "2026-06-12T05:56:10.669773+00:00", "matricula": "SDM-2018-0001", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": "[BAJA TEMPORAL 16/6/2026]: por gei\\n[REACTIVACIÓN 16/6/2026]: porque ya no es gei", "actualizado_en": "2026-06-16T12:46:40.191988+00:00", "dia_limite_pago": null, "nombre_completo": "Adrián Castro H", "fecha_nacimiento": "2011-10-18", "personas_autorizadas": [{"nombre": "Miguel Ángel Castro Domínguez", "parentesco": "padre"}]}	2026-06-16 12:46:40.191988+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
452	\N	UPDATE	usuario	19	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T11:40:13.924+00:00", "actualizado_en": "2026-06-16T11:40:13.926361+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T12:47:30.092+00:00", "actualizado_en": "2026-06-16T12:47:30.096659+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 12:47:30.096659+00	\N	Auditoría automática vía trigger fn_audit_trigger
453	\N	UPDATE	usuario	7	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T10:58:17.806+00:00", "actualizado_en": "2026-06-16T10:58:17.808345+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T12:47:30.923+00:00", "actualizado_en": "2026-06-16T12:47:30.925393+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 12:47:30.925393+00	\N	Auditoría automática vía trigger fn_audit_trigger
454	7	INSERT	usuario	22	\N	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T13:07:38.047+00:00", "usuario_id": 22, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-16T13:07:38.047+00:00", "nombre_usuario": "jessy", "bloqueado_hasta": null, "nombre_completo": "jessica gestor", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 13:07:38.041663+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
455	7	INSERT	usuario_rol	25	\N	{"activo": true, "rol_id": 3, "creado_en": "2026-06-16T13:07:38.047+00:00", "usuario_id": 22, "asignado_en": "2026-06-16T13:07:38.047+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-16T13:07:38.047+00:00", "usuario_rol_id": 25}	2026-06-16 13:07:38.041663+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
456	7	UPDATE	usuario	22	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T13:07:38.047+00:00", "usuario_id": 22, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-16T13:07:38.047+00:00", "nombre_usuario": "jessy", "bloqueado_hasta": null, "nombre_completo": "jessica gestor", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T13:07:38.047+00:00", "usuario_id": 22, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-16T13:07:46.665576+00:00", "nombre_usuario": "jessy", "bloqueado_hasta": null, "nombre_completo": "jessica gestor", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 13:07:46.665576+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
457	7	UPDATE	usuario_rol	25	{"activo": true, "rol_id": 3, "creado_en": "2026-06-16T13:07:38.047+00:00", "usuario_id": 22, "asignado_en": "2026-06-16T13:07:38.047+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-16T13:07:38.047+00:00", "usuario_rol_id": 25}	{"activo": true, "rol_id": 3, "creado_en": "2026-06-16T13:07:38.047+00:00", "usuario_id": 22, "asignado_en": "2026-06-16T13:07:38.047+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-16T13:07:46.665576+00:00", "usuario_rol_id": 25}	2026-06-16 13:07:46.665576+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
458	\N	UPDATE	usuario	22	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T13:07:38.047+00:00", "usuario_id": 22, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-16T13:07:46.665576+00:00", "nombre_usuario": "jessy", "bloqueado_hasta": null, "nombre_completo": "jessica gestor", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T13:07:38.047+00:00", "usuario_id": 22, "eliminado_en": null, "ultimo_acceso": "2026-06-16T13:08:14.344+00:00", "actualizado_en": "2026-06-16T13:08:14.347322+00:00", "nombre_usuario": "jessy", "bloqueado_hasta": null, "nombre_completo": "jessica gestor", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 13:08:14.347322+00	\N	Auditoría automática vía trigger fn_audit_trigger
459	\N	UPDATE	usuario	7	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T12:47:30.923+00:00", "actualizado_en": "2026-06-16T12:47:30.925393+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T13:09:19.685+00:00", "actualizado_en": "2026-06-16T13:09:19.688088+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 13:09:19.688088+00	\N	Auditoría automática vía trigger fn_audit_trigger
462	\N	UPDATE	usuario	19	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T13:15:50.569+00:00", "actualizado_en": "2026-06-16T13:15:50.572778+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T13:25:15.404+00:00", "actualizado_en": "2026-06-16T13:25:15.411594+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 13:25:15.411594+00	\N	Auditoría automática vía trigger fn_audit_trigger
463	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T11:41:31.86+00:00", "actualizado_en": "2026-06-16T11:41:31.86557+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T13:25:19.088+00:00", "actualizado_en": "2026-06-16T13:25:19.089853+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 13:25:19.089853+00	\N	Auditoría automática vía trigger fn_audit_trigger
464	22	INSERT	alumno	237	\N	{"curp": null, "sexo": null, "estado": "Activo", "nivel_id": null, "alumno_id": 237, "creado_en": "2026-06-16T13:32:09.363+00:00", "matricula": "SDM-2222-2222", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-16T13:32:09.363+00:00", "dia_limite_pago": null, "nombre_completo": "nuevo alumnodos", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-16 13:32:09.355053+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
465	\N	UPDATE	usuario	7	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T13:09:19.685+00:00", "actualizado_en": "2026-06-16T13:09:19.688088+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T13:32:46.282+00:00", "actualizado_en": "2026-06-16T13:32:46.283893+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 13:32:46.283893+00	\N	Auditoría automática vía trigger fn_audit_trigger
466	\N	UPDATE	usuario	19	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T13:25:15.404+00:00", "actualizado_en": "2026-06-16T13:25:15.411594+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T09:11:54.679+00:00", "usuario_id": 19, "eliminado_en": null, "ultimo_acceso": "2026-06-16T13:37:56.901+00:00", "actualizado_en": "2026-06-16T13:37:56.906103+00:00", "nombre_usuario": "harry.ga", "bloqueado_hasta": null, "nombre_completo": "Harry Hernandez", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 13:37:56.906103+00	\N	Auditoría automática vía trigger fn_audit_trigger
467	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T13:25:19.088+00:00", "actualizado_en": "2026-06-16T13:25:19.089853+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T13:38:01.12+00:00", "actualizado_en": "2026-06-16T13:38:01.124352+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 13:38:01.124352+00	\N	Auditoría automática vía trigger fn_audit_trigger
468	\N	UPDATE	usuario	8	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-14T18:44:45.42+00:00", "usuario_id": 8, "eliminado_en": null, "ultimo_acceso": "2026-06-16T11:41:16.884+00:00", "actualizado_en": "2026-06-16T11:41:16.890591+00:00", "nombre_usuario": "gestor.admin", "bloqueado_hasta": null, "nombre_completo": "Gestor Administrativo", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-14T18:44:45.42+00:00", "usuario_id": 8, "eliminado_en": null, "ultimo_acceso": "2026-06-16T13:38:43.728+00:00", "actualizado_en": "2026-06-16T13:38:43.72986+00:00", "nombre_usuario": "gestor.admin", "bloqueado_hasta": null, "nombre_completo": "Gestor Administrativo", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 13:38:43.72986+00	\N	Auditoría automática vía trigger fn_audit_trigger
469	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T13:38:01.12+00:00", "actualizado_en": "2026-06-16T13:38:01.124352+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T13:39:03.419+00:00", "actualizado_en": "2026-06-16T13:39:03.419951+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 13:39:03.419951+00	\N	Auditoría automática vía trigger fn_audit_trigger
470	\N	UPDATE	usuario	11	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-16T11:20:40.218+00:00", "actualizado_en": "2026-06-16T11:20:40.223147+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-15T09:34:07.899+00:00", "usuario_id": 11, "eliminado_en": null, "ultimo_acceso": "2026-06-16T13:40:30.914+00:00", "actualizado_en": "2026-06-16T13:40:30.917489+00:00", "nombre_usuario": "harry.adm", "bloqueado_hasta": null, "nombre_completo": "jose manuel", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 13:40:30.917489+00	\N	Auditoría automática vía trigger fn_audit_trigger
471	6	UPDATE	alumno	63	{"curp": "TEST37870HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 63, "creado_en": "2026-06-15T20:52:46.532+00:00", "matricula": "TST-PRI-6A-H76B-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-15T20:52:46.532+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Vazquez Reyes", "fecha_nacimiento": null, "personas_autorizadas": []}	{"curp": "TEST37870HDFXXX01", "sexo": null, "estado": "Activo", "nivel_id": 2, "alumno_id": 63, "creado_en": "2026-06-15T20:52:46.532+00:00", "matricula": "TST-PRI-6A-H76B-0", "fecha_baja": null, "motivo_baja": null, "eliminado_en": null, "observaciones": null, "actualizado_en": "2026-06-16T14:34:44.72168+00:00", "dia_limite_pago": null, "nombre_completo": "Alejandro Vazquez Reyes", "fecha_nacimiento": null, "personas_autorizadas": []}	2026-06-16 14:34:44.72168+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
472	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T13:39:03.419+00:00", "actualizado_en": "2026-06-16T13:39:03.419951+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:07:56.422+00:00", "actualizado_en": "2026-06-16T16:07:56.455237+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 16:07:56.455237+00	\N	Auditoría automática vía trigger fn_audit_trigger
473	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:07:56.422+00:00", "actualizado_en": "2026-06-16T16:07:56.455237+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:09:04.808+00:00", "actualizado_en": "2026-06-16T16:09:04.815066+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 16:09:04.815066+00	\N	Auditoría automática vía trigger fn_audit_trigger
474	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:09:04.808+00:00", "actualizado_en": "2026-06-16T16:09:04.815066+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:18:09.213+00:00", "actualizado_en": "2026-06-16T16:18:09.220287+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 16:18:09.220287+00	\N	Auditoría automática vía trigger fn_audit_trigger
475	6	INSERT	usuario	23	\N	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T16:19:18.528+00:00", "usuario_id": 23, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-16T16:19:18.528+00:00", "nombre_usuario": "morales.a", "bloqueado_hasta": null, "nombre_completo": "morales", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 16:19:18.51446+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
476	6	INSERT	usuario_rol	26	\N	{"activo": true, "rol_id": 1, "creado_en": "2026-06-16T16:19:18.528+00:00", "usuario_id": 23, "asignado_en": "2026-06-16T16:19:18.528+00:00", "asignado_por": null, "eliminado_en": null, "actualizado_en": "2026-06-16T16:19:18.528+00:00", "usuario_rol_id": 26}	2026-06-16 16:19:18.51446+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
477	\N	UPDATE	usuario	23	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T16:19:18.528+00:00", "usuario_id": 23, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-16T16:19:18.528+00:00", "nombre_usuario": "morales.a", "bloqueado_hasta": null, "nombre_completo": "morales", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T16:19:18.528+00:00", "usuario_id": 23, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-16T16:22:11.031282+00:00", "nombre_usuario": "morales.a", "bloqueado_hasta": null, "nombre_completo": "morales", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 16:22:11.031282+00	\N	Auditoría automática vía trigger fn_audit_trigger
478	\N	UPDATE	usuario	23	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T16:19:18.528+00:00", "usuario_id": 23, "eliminado_en": null, "ultimo_acceso": null, "actualizado_en": "2026-06-16T16:22:11.031282+00:00", "nombre_usuario": "morales.a", "bloqueado_hasta": null, "nombre_completo": "morales", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T16:19:18.528+00:00", "usuario_id": 23, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:22:17.135+00:00", "actualizado_en": "2026-06-16T16:22:17.143886+00:00", "nombre_usuario": "morales.a", "bloqueado_hasta": null, "nombre_completo": "morales", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 16:22:17.143886+00	\N	Auditoría automática vía trigger fn_audit_trigger
479	\N	UPDATE	usuario	21	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T10:53:16.953+00:00", "actualizado_en": "2026-06-16T10:53:16.955815+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T10:53:16.953+00:00", "actualizado_en": "2026-06-16T16:24:20.478905+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 16:24:20.478905+00	\N	Auditoría automática vía trigger fn_audit_trigger
480	\N	UPDATE	usuario	21	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T10:53:16.953+00:00", "actualizado_en": "2026-06-16T16:24:20.478905+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:24:39.684+00:00", "actualizado_en": "2026-06-16T16:24:39.693794+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 16:24:39.693794+00	\N	Auditoría automática vía trigger fn_audit_trigger
482	\N	UPDATE	usuario	21	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:25:35.973+00:00", "actualizado_en": "2026-06-16T16:25:35.976198+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:26:40.585+00:00", "actualizado_en": "2026-06-16T16:26:40.587688+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 16:26:40.587688+00	\N	Auditoría automática vía trigger fn_audit_trigger
481	\N	UPDATE	usuario	21	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:24:39.684+00:00", "actualizado_en": "2026-06-16T16:24:39.693794+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:25:35.973+00:00", "actualizado_en": "2026-06-16T16:25:35.976198+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 16:25:35.976198+00	\N	Auditoría automática vía trigger fn_audit_trigger
483	\N	UPDATE	usuario	21	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:26:40.585+00:00", "actualizado_en": "2026-06-16T16:26:40.587688+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:29:25.304+00:00", "actualizado_en": "2026-06-16T16:29:25.314249+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 16:29:25.314249+00	\N	Auditoría automática vía trigger fn_audit_trigger
484	\N	UPDATE	usuario	21	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:29:25.304+00:00", "actualizado_en": "2026-06-16T16:29:25.314249+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:31:18.682+00:00", "actualizado_en": "2026-06-16T16:31:18.686092+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 16:31:18.686092+00	\N	Auditoría automática vía trigger fn_audit_trigger
485	\N	UPDATE	usuario	21	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:31:18.682+00:00", "actualizado_en": "2026-06-16T16:31:18.686092+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:32:09.254+00:00", "actualizado_en": "2026-06-16T16:32:09.257896+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 16:32:09.257896+00	\N	Auditoría automática vía trigger fn_audit_trigger
486	\N	UPDATE	usuario	4	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T10:58:19.148+00:00", "actualizado_en": "2026-06-16T10:58:19.151275+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:35:06.843+00:00", "actualizado_en": "2026-06-16T16:35:06.846904+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 16:35:06.846904+00	\N	Auditoría automática vía trigger fn_audit_trigger
487	\N	UPDATE	usuario	4	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:35:06.843+00:00", "actualizado_en": "2026-06-16T16:35:06.846904+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:36:27.403+00:00", "actualizado_en": "2026-06-16T16:36:27.404231+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 16:36:27.404231+00	\N	Auditoría automática vía trigger fn_audit_trigger
488	6	UPDATE	tutor	17	{"rfc": null, "curp": null, "activo": true, "tutorId": 17, "usoCfdi": null, "creadoEn": "2026-06-15T19:44:48.243Z", "telefono": "5552223344", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": null, "actualizadoEn": "2026-06-16T02:10:08.503Z", "regimenFiscal": null, "nombreCompleto": "Ana Ramírez", "direccionFiscal": null, "requiereFactura": false, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": null}	{"rfc": "RFTHNHTGTY123", "curp": null, "activo": true, "tutorId": 17, "usoCfdi": "G03", "creadoEn": "2026-06-15T19:44:48.243Z", "telefono": "5552223344", "direccion": null, "eliminadoEn": null, "saldoAFavor": 0.0, "codigoPostal": "67543", "actualizadoEn": "2026-06-16T16:55:47.620Z", "regimenFiscal": "603", "nombreCompleto": "Ana Ramírez", "direccionFiscal": "niños heroes 157, Adolfo Lopez Mateos", "requiereFactura": true, "tipoPagoHabitual": null, "correoElectronico": null, "correoFacturacion": "dianagf@gmail.com"}	2026-06-16 16:55:47.647+00	127.0.0.1	\N
521	\N	UPDATE	usuario	1	{"activo": true, "correo": "elizabeth@sandiego.edu", "telefono": "9211112233", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 1, "eliminado_en": null, "ultimo_acceso": "2026-06-14T20:29:20.337+00:00", "actualizado_en": "2026-06-14T20:29:20.351631+00:00", "nombre_usuario": "elizabeth.mendoza", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza Castro", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth@sandiego.edu", "telefono": "9211112233", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 1, "eliminado_en": null, "ultimo_acceso": "2026-06-16T18:47:51.028+00:00", "actualizado_en": "2026-06-16T18:47:51.06353+00:00", "nombre_usuario": "elizabeth.mendoza", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza Castro", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 18:47:51.06353+00	\N	Auditoría automática vía trigger fn_audit_trigger
522	\N	UPDATE	usuario	4	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:36:27.403+00:00", "actualizado_en": "2026-06-16T16:36:27.404231+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:36:27.403+00:00", "actualizado_en": "2026-06-16T18:54:16.063702+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 1}	2026-06-16 18:54:16.063702+00	\N	Auditoría automática vía trigger fn_audit_trigger
523	\N	UPDATE	usuario	4	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:36:27.403+00:00", "actualizado_en": "2026-06-16T18:54:16.063702+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 1}	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T18:54:29.455+00:00", "actualizado_en": "2026-06-16T18:54:29.458476+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 18:54:29.458476+00	\N	Auditoría automática vía trigger fn_audit_trigger
524	\N	UPDATE	usuario	4	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T18:54:29.455+00:00", "actualizado_en": "2026-06-16T18:54:29.458476+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T19:10:34.056+00:00", "actualizado_en": "2026-06-16T19:10:34.059436+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 19:10:34.059436+00	\N	Auditoría automática vía trigger fn_audit_trigger
525	4	INSERT	pago	20	\N	{"pago_id": 20, "tutor_id": 89, "alumno_id": 87, "fecha_pago": "2026-06-16", "metodo_pago": "efectivo", "monto_total": 32000.00, "observaciones": null, "registrado_en": "2026-06-16T19:15:35.713+00:00", "actualizado_en": "2026-06-16T19:15:35.713+00:00", "registrado_por": 4, "aplicado_a_saldo": false}	2026-06-16 19:15:35.697426+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
526	4	INSERT	pago	21	\N	{"pago_id": 21, "tutor_id": 89, "alumno_id": 87, "fecha_pago": "2026-06-16", "metodo_pago": "efectivo", "monto_total": 6000.00, "observaciones": "Pago adelantado de colegiaturas (3 meses)", "registrado_en": "2026-06-16T19:16:39.277+00:00", "actualizado_en": "2026-06-16T19:16:39.277+00:00", "registrado_por": 4, "aplicado_a_saldo": false}	2026-06-16 19:16:39.260372+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
527	\N	UPDATE	usuario	1	{"activo": true, "correo": "elizabeth@sandiego.edu", "telefono": "9211112233", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 1, "eliminado_en": null, "ultimo_acceso": "2026-06-16T18:47:51.028+00:00", "actualizado_en": "2026-06-16T18:47:51.06353+00:00", "nombre_usuario": "elizabeth.mendoza", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza Castro", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth@sandiego.edu", "telefono": "9211112233", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 1, "eliminado_en": null, "ultimo_acceso": "2026-06-16T19:17:04.376+00:00", "actualizado_en": "2026-06-16T19:17:04.380699+00:00", "nombre_usuario": "elizabeth.mendoza", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza Castro", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 19:17:04.380699+00	\N	Auditoría automática vía trigger fn_audit_trigger
528	\N	UPDATE	usuario	4	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T19:10:34.056+00:00", "actualizado_en": "2026-06-16T19:10:34.059436+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T19:17:42.597+00:00", "actualizado_en": "2026-06-16T19:17:42.601785+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 19:17:42.601785+00	\N	Auditoría automática vía trigger fn_audit_trigger
529	\N	UPDATE	usuario	1	{"activo": true, "correo": "elizabeth@sandiego.edu", "telefono": "9211112233", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 1, "eliminado_en": null, "ultimo_acceso": "2026-06-16T19:17:04.376+00:00", "actualizado_en": "2026-06-16T19:17:04.380699+00:00", "nombre_usuario": "elizabeth.mendoza", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza Castro", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth@sandiego.edu", "telefono": "9211112233", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 1, "eliminado_en": null, "ultimo_acceso": "2026-06-16T19:36:02.85+00:00", "actualizado_en": "2026-06-16T19:36:02.858604+00:00", "nombre_usuario": "elizabeth.mendoza", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza Castro", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 19:36:02.858604+00	\N	Auditoría automática vía trigger fn_audit_trigger
530	\N	UPDATE	usuario	4	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T19:17:42.597+00:00", "actualizado_en": "2026-06-16T19:17:42.601785+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T19:36:32.496+00:00", "actualizado_en": "2026-06-16T19:36:32.497477+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 19:36:32.497477+00	\N	Auditoría automática vía trigger fn_audit_trigger
531	4	INSERT	pago	22	\N	{"pago_id": 22, "tutor_id": 122, "alumno_id": 120, "fecha_pago": "2026-06-16", "metodo_pago": "efectivo", "monto_total": 8000.00, "observaciones": "Pago adelantado de colegiaturas (2 meses)", "registrado_en": "2026-06-16T19:36:56.929+00:00", "actualizado_en": "2026-06-16T19:36:56.929+00:00", "registrado_por": 4, "aplicado_a_saldo": false}	2026-06-16 19:36:56.917682+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
532	\N	UPDATE	usuario	1	{"activo": true, "correo": "elizabeth@sandiego.edu", "telefono": "9211112233", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 1, "eliminado_en": null, "ultimo_acceso": "2026-06-16T19:36:02.85+00:00", "actualizado_en": "2026-06-16T19:36:02.858604+00:00", "nombre_usuario": "elizabeth.mendoza", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza Castro", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth@sandiego.edu", "telefono": "9211112233", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 1, "eliminado_en": null, "ultimo_acceso": "2026-06-16T19:40:33.813+00:00", "actualizado_en": "2026-06-16T19:40:33.817268+00:00", "nombre_usuario": "elizabeth.mendoza", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza Castro", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 19:40:33.817268+00	\N	Auditoría automática vía trigger fn_audit_trigger
533	1	INSERT	pago	23	\N	{"pago_id": 23, "tutor_id": 44, "alumno_id": 42, "fecha_pago": "2026-06-16", "metodo_pago": "transferencia", "monto_total": 4500.00, "observaciones": null, "registrado_en": "2026-06-16T19:57:26.334+00:00", "actualizado_en": "2026-06-16T19:57:26.334+00:00", "registrado_por": 1, "aplicado_a_saldo": false}	2026-06-16 19:57:26.320437+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
534	1	INSERT	pago	24	\N	{"pago_id": 24, "tutor_id": 6, "alumno_id": 9, "fecha_pago": "2026-06-16", "metodo_pago": "transferencia", "monto_total": 4000.00, "observaciones": null, "registrado_en": "2026-06-16T20:04:39.318+00:00", "actualizado_en": "2026-06-16T20:04:39.318+00:00", "registrado_por": 1, "aplicado_a_saldo": false}	2026-06-16 20:04:39.301625+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
535	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:18:09.213+00:00", "actualizado_en": "2026-06-16T16:18:09.220287+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:18:09.213+00:00", "actualizado_en": "2026-06-16T20:30:57.190216+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 1}	2026-06-16 20:30:57.190216+00	\N	Auditoría automática vía trigger fn_audit_trigger
536	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:18:09.213+00:00", "actualizado_en": "2026-06-16T20:30:57.190216+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 1}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T20:31:07.941+00:00", "actualizado_en": "2026-06-16T20:31:07.944796+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 20:31:07.944796+00	\N	Auditoría automática vía trigger fn_audit_trigger
537	\N	UPDATE	usuario	7	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T13:32:46.282+00:00", "actualizado_en": "2026-06-16T13:32:46.283893+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T21:39:08.251+00:00", "actualizado_en": "2026-06-16T21:39:08.254816+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 21:39:08.254816+00	\N	Auditoría automática vía trigger fn_audit_trigger
538	\N	UPDATE	usuario	21	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:32:09.254+00:00", "actualizado_en": "2026-06-16T16:32:09.257896+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:32:09.254+00:00", "actualizado_en": "2026-06-16T21:43:47.601629+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": true, "intentos_fallidos": 1}	2026-06-16 21:43:47.601629+00	\N	Auditoría automática vía trigger fn_audit_trigger
539	\N	UPDATE	usuario	7	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T21:39:08.251+00:00", "actualizado_en": "2026-06-16T21:39:08.254816+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T21:44:06.672+00:00", "actualizado_en": "2026-06-16T21:44:06.675636+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 21:44:06.675636+00	\N	Auditoría automática vía trigger fn_audit_trigger
540	\N	UPDATE	usuario	21	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:32:09.254+00:00", "actualizado_en": "2026-06-16T21:43:47.601629+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": true, "intentos_fallidos": 1}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:32:09.254+00:00", "actualizado_en": "2026-06-16T21:44:44.802849+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 21:44:44.802849+00	\N	Auditoría automática vía trigger fn_audit_trigger
541	\N	UPDATE	usuario	7	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T21:44:06.672+00:00", "actualizado_en": "2026-06-16T21:44:06.675636+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T21:45:15.663+00:00", "actualizado_en": "2026-06-16T21:45:15.666044+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 21:45:15.666044+00	\N	Auditoría automática vía trigger fn_audit_trigger
542	\N	UPDATE	usuario	21	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T16:32:09.254+00:00", "actualizado_en": "2026-06-16T21:44:44.802849+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": null, "telefono": null, "creado_en": "2026-06-16T10:53:00.766+00:00", "usuario_id": 21, "eliminado_en": null, "ultimo_acceso": "2026-06-16T21:45:41.294+00:00", "actualizado_en": "2026-06-16T21:45:41.297322+00:00", "nombre_usuario": "jess", "bloqueado_hasta": null, "nombre_completo": "jessi admin", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 21:45:41.297322+00	\N	Auditoría automática vía trigger fn_audit_trigger
543	\N	UPDATE	usuario	4	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T19:36:32.496+00:00", "actualizado_en": "2026-06-16T19:36:32.497477+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T21:52:37.288+00:00", "actualizado_en": "2026-06-16T21:52:37.297524+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 21:52:37.297524+00	\N	Auditoría automática vía trigger fn_audit_trigger
544	\N	UPDATE	usuario	1	{"activo": true, "correo": "elizabeth@sandiego.edu", "telefono": "9211112233", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 1, "eliminado_en": null, "ultimo_acceso": "2026-06-16T19:40:33.813+00:00", "actualizado_en": "2026-06-16T19:40:33.817268+00:00", "nombre_usuario": "elizabeth.mendoza", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza Castro", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth@sandiego.edu", "telefono": "9211112233", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 1, "eliminado_en": null, "ultimo_acceso": "2026-06-16T21:53:14.051+00:00", "actualizado_en": "2026-06-16T21:53:14.055764+00:00", "nombre_usuario": "elizabeth.mendoza", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza Castro", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 21:53:14.055764+00	\N	Auditoría automática vía trigger fn_audit_trigger
545	\N	UPDATE	usuario	4	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T21:52:37.288+00:00", "actualizado_en": "2026-06-16T21:52:37.297524+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "mario.sanchez@sandiego.edu", "telefono": "9211112236", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 4, "eliminado_en": null, "ultimo_acceso": "2026-06-16T21:53:32.235+00:00", "actualizado_en": "2026-06-16T21:53:32.239008+00:00", "nombre_usuario": "mario.sanchez", "bloqueado_hasta": null, "nombre_completo": "Mario Sánchez Trejo", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 21:53:32.239008+00	\N	Auditoría automática vía trigger fn_audit_trigger
546	4	INSERT	pago	25	\N	{"pago_id": 25, "tutor_id": 3, "alumno_id": 3, "fecha_pago": "2026-06-16", "metodo_pago": "transferencia", "monto_total": 1500.00, "observaciones": null, "registrado_en": "2026-06-16T21:54:58.946+00:00", "actualizado_en": "2026-06-16T21:54:58.946+00:00", "registrado_por": 4, "aplicado_a_saldo": false}	2026-06-16 21:54:58.929265+00	127.0.0.1	Auditoría automática vía trigger fn_audit_trigger
547	\N	UPDATE	usuario	1	{"activo": true, "correo": "elizabeth@sandiego.edu", "telefono": "9211112233", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 1, "eliminado_en": null, "ultimo_acceso": "2026-06-16T21:53:14.051+00:00", "actualizado_en": "2026-06-16T21:53:14.055764+00:00", "nombre_usuario": "elizabeth.mendoza", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza Castro", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth@sandiego.edu", "telefono": "9211112233", "creado_en": "2026-06-12T05:56:10.412081+00:00", "usuario_id": 1, "eliminado_en": null, "ultimo_acceso": "2026-06-16T21:55:49.115+00:00", "actualizado_en": "2026-06-16T21:55:49.121283+00:00", "nombre_usuario": "elizabeth.mendoza", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza Castro", "debe_cambiar_pwd": true, "intentos_fallidos": 0}	2026-06-16 21:55:49.121283+00	\N	Auditoría automática vía trigger fn_audit_trigger
548	\N	UPDATE	usuario	7	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T21:45:15.663+00:00", "actualizado_en": "2026-06-16T21:45:15.666044+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "maria.dolores@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.41+00:00", "usuario_id": 7, "eliminado_en": null, "ultimo_acceso": "2026-06-16T22:04:55.314+00:00", "actualizado_en": "2026-06-16T22:04:55.318715+00:00", "nombre_usuario": "maria.directora", "bloqueado_hasta": null, "nombre_completo": "María Dolores Vega", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 22:04:55.318715+00	\N	Auditoría automática vía trigger fn_audit_trigger
549	\N	UPDATE	usuario	6	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T20:31:07.941+00:00", "actualizado_en": "2026-06-16T20:31:07.944796+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	{"activo": true, "correo": "elizabeth.mendoza@colegiosandiego.edu.mx", "telefono": null, "creado_en": "2026-06-14T18:44:45.373+00:00", "usuario_id": 6, "eliminado_en": null, "ultimo_acceso": "2026-06-16T22:05:17.093+00:00", "actualizado_en": "2026-06-16T22:05:17.097436+00:00", "nombre_usuario": "elizabeth.admin", "bloqueado_hasta": null, "nombre_completo": "Elizabeth Mendoza", "debe_cambiar_pwd": false, "intentos_fallidos": 0}	2026-06-16 22:05:17.097436+00	\N	Auditoría automática vía trigger fn_audit_trigger
\.


--
-- Data for Name: materia; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.materia (materia_id, nivel_id, clave_sep, nombre, descripcion, horas_semanales, creditos, tipo, cuenta_para_promedio, creado_en, actualizado_en, eliminado_en) FROM stdin;
1	2	PRI-ESP-04	Español	Lectura, escritura y expresión oral	6	6.0	curricular	t	2026-06-12 05:56:10.638145+00	2026-06-12 05:56:10.638145+00	\N
2	2	PRI-MAT-04	Matemáticas	Aritmética, geometría y razonamiento	6	6.0	curricular	t	2026-06-12 05:56:10.638145+00	2026-06-12 05:56:10.638145+00	\N
3	2	PRI-CN-04	Ciencias Naturales	Biología, física y química básicas	4	4.0	curricular	t	2026-06-12 05:56:10.638145+00	2026-06-12 05:56:10.638145+00	\N
4	2	PRI-HIS-04	Historia	México y mundo, énfasis cívico	3	3.0	curricular	t	2026-06-12 05:56:10.638145+00	2026-06-12 05:56:10.638145+00	\N
5	2	PRI-GEO-04	Geografía	Geografía de México y entidades	3	3.0	curricular	t	2026-06-12 05:56:10.638145+00	2026-06-12 05:56:10.638145+00	\N
6	3	SEC-ESP-01	Español	Comprensión lectora y producción de textos	5	5.0	curricular	t	2026-06-12 05:56:10.641359+00	2026-06-12 05:56:10.641359+00	\N
7	3	SEC-MAT-01	Matemáticas	Álgebra, geometría y probabilidad	5	5.0	curricular	t	2026-06-12 05:56:10.641359+00	2026-06-12 05:56:10.641359+00	\N
8	3	SEC-ING-01	Inglés	Inglés como segunda lengua	3	3.0	curricular	t	2026-06-12 05:56:10.641359+00	2026-06-12 05:56:10.641359+00	\N
9	3	SEC-FCE-01	Formación Cívica	Ética y ciudadanía	4	4.0	curricular	t	2026-06-12 05:56:10.641359+00	2026-06-12 05:56:10.641359+00	\N
10	2	\N	Inglés	\N	\N	\N	curricular	t	2026-06-14 18:44:45.53+00	2026-06-14 18:44:45.53+00	\N
11	2	\N	Educación Física	\N	\N	\N	curricular	t	2026-06-14 18:44:45.54+00	2026-06-14 18:44:45.54+00	\N
12	3	\N	Matemáticas III	\N	\N	\N	curricular	t	2026-06-14 18:44:45.555+00	2026-06-14 18:44:45.555+00	\N
13	3	\N	Español III	\N	\N	\N	curricular	t	2026-06-14 18:44:45.565+00	2026-06-14 18:44:45.565+00	\N
14	3	\N	Historia de México	\N	\N	\N	curricular	t	2026-06-14 18:44:45.579+00	2026-06-14 18:44:45.579+00	\N
15	3	\N	Biología	\N	\N	\N	curricular	t	2026-06-14 18:44:45.592+00	2026-06-14 18:44:45.592+00	\N
16	3	\N	Inglés Intermedio	\N	\N	\N	curricular	t	2026-06-14 18:44:45.6+00	2026-06-14 18:44:45.6+00	\N
17	4	\N	Cálculo	\N	\N	\N	curricular	t	2026-06-14 18:44:45.614+00	2026-06-14 18:44:45.614+00	\N
18	4	\N	Física II	\N	\N	\N	curricular	t	2026-06-14 18:44:45.624+00	2026-06-14 18:44:45.624+00	\N
19	4	\N	Química Orgánica	\N	\N	\N	curricular	t	2026-06-14 18:44:45.643+00	2026-06-14 18:44:45.643+00	\N
20	4	\N	Literatura	\N	\N	\N	curricular	t	2026-06-14 18:44:45.656+00	2026-06-14 18:44:45.656+00	\N
21	1	\N	Pelis 1	\N	\N	\N	curricular	t	2026-06-15 20:45:21.309+00	2026-06-15 20:45:21.309+00	\N
22	2	\N	Artes	\N	\N	\N	curricular	t	2026-06-15 21:14:53.008+00	2026-06-15 21:14:53.008+00	\N
23	3	\N	Ciencias	\N	\N	\N	curricular	t	2026-06-15 21:14:53.252+00	2026-06-15 21:14:53.252+00	\N
24	3	\N	Historia	\N	\N	\N	curricular	t	2026-06-15 21:14:53.259+00	2026-06-15 21:14:53.259+00	\N
25	3	\N	Geografía	\N	\N	\N	curricular	t	2026-06-15 21:14:53.269+00	2026-06-15 21:14:53.269+00	\N
26	3	\N	Educación Física	\N	\N	\N	curricular	t	2026-06-15 21:14:53.286+00	2026-06-15 21:14:53.286+00	\N
27	3	\N	Tecnología	\N	\N	\N	curricular	t	2026-06-15 21:14:53.299+00	2026-06-15 21:14:53.299+00	\N
28	3	\N	Formación Cívica y Ética	\N	\N	\N	curricular	t	2026-06-15 21:14:53.314+00	2026-06-15 21:14:53.314+00	\N
29	1	\N	Docker 2	\N	\N	\N	curricular	t	2026-06-16 04:36:52.204+00	2026-06-16 04:36:52.204+00	\N
30	1	\N	Calculo	\N	\N	\N	curricular	t	2026-06-16 04:39:18.678+00	2026-06-16 04:39:18.678+00	\N
31	1	\N	promp	\N	\N	\N	taller	t	2026-06-16 04:46:13.504+00	2026-06-16 04:46:13.504+00	\N
33	1	\N	promp	\N	\N	\N	club	t	2026-06-16 04:54:49.962+00	2026-06-16 04:54:49.962+00	\N
34	1	\N	Pelis 1	\N	\N	\N	club	t	2026-06-16 04:59:28.316+00	2026-06-16 04:59:28.316+00	\N
35	1	\N	Electricidad	\N	\N	\N	club	t	2026-06-16 06:10:11.871+00	2026-06-16 06:10:11.871+00	\N
36	1	\N	Lenguajes	\N	\N	\N	curricular	t	2026-06-16 12:40:56.833+00	2026-06-16 12:40:56.833+00	\N
37	1	\N	Saberes y Pensamiento Científico	\N	\N	\N	curricular	t	2026-06-16 12:40:56.855+00	2026-06-16 12:40:56.855+00	\N
38	1	\N	Ética, Naturaleza y Sociedades	\N	\N	\N	curricular	t	2026-06-16 12:40:56.861+00	2026-06-16 12:40:56.861+00	\N
39	1	\N	De lo Humano y lo Comunitario	\N	\N	\N	curricular	t	2026-06-16 12:40:56.867+00	2026-06-16 12:40:56.867+00	\N
40	1	\N	Inglés	\N	\N	\N	curricular	t	2026-06-16 12:40:56.873+00	2026-06-16 12:40:56.873+00	\N
41	1	\N	Computación	\N	\N	\N	taller	t	2026-06-16 12:40:56.882+00	2026-06-16 12:40:56.882+00	\N
42	1	\N	Educación Física	\N	\N	\N	curricular	t	2026-06-16 12:40:56.889+00	2026-06-16 12:40:56.889+00	\N
43	2	\N	Lenguajes	\N	\N	\N	curricular	t	2026-06-16 12:40:56.98+00	2026-06-16 12:40:56.98+00	\N
44	2	\N	Saberes y Pensamiento Científico	\N	\N	\N	curricular	t	2026-06-16 12:40:56.984+00	2026-06-16 12:40:56.984+00	\N
45	2	\N	Ética, Naturaleza y Sociedades	\N	\N	\N	curricular	t	2026-06-16 12:40:56.99+00	2026-06-16 12:40:56.99+00	\N
46	2	\N	De lo Humano y lo Comunitario	\N	\N	\N	curricular	t	2026-06-16 12:40:56.995+00	2026-06-16 12:40:56.995+00	\N
47	2	\N	Computación	\N	\N	\N	taller	t	2026-06-16 12:40:57.002+00	2026-06-16 12:40:57.002+00	\N
48	3	\N	Biología (Ciencia y Tecnología)	\N	\N	\N	curricular	t	2026-06-16 12:40:57.133+00	2026-06-16 12:40:57.133+00	\N
49	3	\N	Física (Ciencia y Tecnología)	\N	\N	\N	curricular	t	2026-06-16 12:40:57.14+00	2026-06-16 12:40:57.14+00	\N
50	3	\N	Química (Ciencia y Tecnología)	\N	\N	\N	curricular	t	2026-06-16 12:40:57.148+00	2026-06-16 12:40:57.148+00	\N
51	3	\N	Artes	\N	\N	\N	curricular	t	2026-06-16 12:40:57.156+00	2026-06-16 12:40:57.156+00	\N
52	3	\N	Tecnología Informática	\N	\N	\N	taller	t	2026-06-16 12:40:57.162+00	2026-06-16 12:40:57.162+00	\N
53	3	\N	Vida Saludable	\N	\N	\N	curricular	t	2026-06-16 12:40:57.168+00	2026-06-16 12:40:57.168+00	\N
54	3	\N	Educación Financiera	\N	\N	\N	curricular	t	2026-06-16 12:40:57.173+00	2026-06-16 12:40:57.173+00	\N
55	3	\N	Tutoría y Educación Socioemocional	\N	\N	\N	curricular	t	2026-06-16 12:40:57.177+00	2026-06-16 12:40:57.177+00	\N
56	3	\N	Laboratorio de Investigación	\N	\N	\N	curricular	t	2026-06-16 12:40:57.182+00	2026-06-16 12:40:57.182+00	\N
57	3	\N	Taller	\N	\N	\N	taller	t	2026-06-16 12:40:57.187+00	2026-06-16 12:40:57.187+00	\N
58	4	\N	Pensamiento Matemático II	\N	\N	\N	curricular	t	2026-06-16 12:40:57.373+00	2026-06-16 12:40:57.373+00	\N
59	4	\N	Lengua y Comunicación II	\N	\N	\N	curricular	t	2026-06-16 12:40:57.377+00	2026-06-16 12:40:57.377+00	\N
60	4	\N	Inglés II	\N	\N	\N	curricular	t	2026-06-16 12:40:57.382+00	2026-06-16 12:40:57.382+00	\N
61	4	\N	Inglés V	\N	\N	\N	curricular	t	2026-06-16 12:40:57.387+00	2026-06-16 12:40:57.387+00	\N
62	4	\N	Cultura Digital II	\N	\N	\N	curricular	t	2026-06-16 12:40:57.392+00	2026-06-16 12:40:57.392+00	\N
63	4	\N	Ciencias Sociales II	\N	\N	\N	curricular	t	2026-06-16 12:40:57.4+00	2026-06-16 12:40:57.4+00	\N
64	4	\N	Humanidades II	\N	\N	\N	curricular	t	2026-06-16 12:40:57.408+00	2026-06-16 12:40:57.408+00	\N
65	4	\N	Conciencia Histórica	\N	\N	\N	curricular	t	2026-06-16 12:40:57.415+00	2026-06-16 12:40:57.415+00	\N
66	4	\N	Taller de Ciencias I	\N	\N	\N	taller	t	2026-06-16 12:40:57.422+00	2026-06-16 12:40:57.422+00	\N
67	4	\N	Conservación de la Energía	\N	\N	\N	curricular	t	2026-06-16 12:40:57.426+00	2026-06-16 12:40:57.426+00	\N
68	4	\N	Energía de los procesos de la vida diaria	\N	\N	\N	curricular	t	2026-06-16 12:40:57.43+00	2026-06-16 12:40:57.43+00	\N
69	4	\N	Ciencias de la Salud	\N	\N	\N	curricular	t	2026-06-16 12:40:57.435+00	2026-06-16 12:40:57.435+00	\N
70	4	\N	Temas Selectos de Biología	\N	\N	\N	curricular	t	2026-06-16 12:40:57.441+00	2026-06-16 12:40:57.441+00	\N
71	4	\N	Temas Selectos de Física	\N	\N	\N	curricular	t	2026-06-16 12:40:57.446+00	2026-06-16 12:40:57.446+00	\N
72	4	\N	Temas Selectos de Química	\N	\N	\N	curricular	t	2026-06-16 12:40:57.452+00	2026-06-16 12:40:57.452+00	\N
73	4	\N	Cálculo Diferencial	\N	\N	\N	curricular	t	2026-06-16 12:40:57.458+00	2026-06-16 12:40:57.458+00	\N
74	4	\N	Etimologías Grecolatinas	\N	\N	\N	curricular	t	2026-06-16 12:40:57.463+00	2026-06-16 12:40:57.463+00	\N
75	4	\N	Psicología	\N	\N	\N	curricular	t	2026-06-16 12:40:57.472+00	2026-06-16 12:40:57.472+00	\N
76	4	\N	Lógica	\N	\N	\N	curricular	t	2026-06-16 12:40:57.479+00	2026-06-16 12:40:57.479+00	\N
77	4	\N	Educación Física	\N	\N	\N	curricular	t	2026-06-16 12:40:57.486+00	2026-06-16 12:40:57.486+00	\N
78	4	\N	Práctica y Colaboración Ciudadana	\N	\N	\N	curricular	t	2026-06-16 12:40:57.493+00	2026-06-16 12:40:57.493+00	\N
79	4	\N	Educación Integral en Sexualidad y Género	\N	\N	\N	curricular	t	2026-06-16 12:40:57.499+00	2026-06-16 12:40:57.499+00	\N
80	4	\N	Finanzas	\N	\N	\N	curricular	t	2026-06-16 12:40:57.504+00	2026-06-16 12:40:57.504+00	\N
81	4	\N	Ventas y Difusión	\N	\N	\N	curricular	t	2026-06-16 12:40:57.509+00	2026-06-16 12:40:57.509+00	\N
82	4	\N	Danza	\N	\N	\N	taller	t	2026-06-16 12:40:57.514+00	2026-06-16 12:40:57.514+00	\N
83	4	\N	Danza (Currículum Ampliado)	\N	\N	\N	taller	t	2026-06-16 12:40:57.52+00	2026-06-16 12:40:57.52+00	\N
\.


--
-- Data for Name: movimiento_saldo; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.movimiento_saldo (movimiento_id, tutor_id, tipo, monto, pago_id, aplicacion_id, descripcion, creado_por, creado_en, actualizado_en) FROM stdin;
1	12	abono	4500.00	5	\N	Saldo a favor por sobrepago o pago anticipado (otro)	\N	2026-06-14 23:19:57.236+00	2026-06-14 23:19:57.236+00
2	6	abono	46500.00	8	\N	Saldo a favor por sobrepago o pago anticipado (inscripcion)	\N	2026-06-15 04:38:52.226+00	2026-06-15 04:38:52.226+00
3	8	abono	50000000.00	9	\N	Saldo a favor por sobrepago o pago anticipado (colegiatura)	\N	2026-06-15 05:04:51.511+00	2026-06-15 05:04:51.511+00
4	89	abono	30000.00	20	\N	Saldo a favor por sobrepago o pago anticipado (inscripcion)	\N	2026-06-16 19:15:35.751+00	2026-06-16 19:15:35.751+00
\.


--
-- Data for Name: nivel_educativo; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.nivel_educativo (nivel_id, codigo, nombre, rvoe, orden, creado_en, actualizado_en, eliminado_en) FROM stdin;
1	PREESCOLAR	Preescolar	\N	1	2026-06-12 05:56:09.281799+00	2026-06-12 05:56:09.281799+00	\N
2	PRIMARIA	Primaria	\N	2	2026-06-12 05:56:09.281799+00	2026-06-12 05:56:09.281799+00	\N
3	SECUNDARIA	Secundaria	\N	3	2026-06-12 05:56:09.281799+00	2026-06-12 05:56:09.281799+00	\N
4	BACHILLERATO	Bachillerato	\N	4	2026-06-12 05:56:09.281799+00	2026-06-12 05:56:09.281799+00	\N
\.


--
-- Data for Name: notificacion; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.notificacion (notificacion_id, tipo, canal, destinatario_tutor_id, destinatario_email, destinatario_usuario_id, asunto, cuerpo, estado, intentos, error_ultimo, programada_para, enviada_en, alumno_id, calendario_pago_id, creada_en, actualizado_en, eliminado_en) FROM stdin;
7	otro	email	\N	\N	2	Nueva solicitud de beca: undefined	Se ha solicitado una beca "Beca por hermanos" para el alumno undefined. Motivo: N/A	pendiente	0	\N	\N	\N	\N	\N	2026-06-16 13:38:10.213+00	2026-06-16 13:38:10.213+00	\N
8	otro	email	\N	\N	1	Nueva solicitud de beca: undefined	Se ha solicitado una beca "Beca por hermanos" para el alumno undefined. Motivo: N/A	pendiente	0	\N	\N	\N	\N	\N	2026-06-16 13:38:10.227+00	2026-06-16 13:38:10.227+00	\N
9	otro	email	\N	\N	7	Nueva solicitud de beca: undefined	Se ha solicitado una beca "Beca por hermanos" para el alumno undefined. Motivo: N/A	pendiente	0	\N	\N	\N	\N	\N	2026-06-16 13:38:10.23+00	2026-06-16 13:38:10.23+00	\N
10	otro	email	\N	\N	6	Nueva solicitud de beca: undefined	Se ha solicitado una beca "Beca por hermanos" para el alumno undefined. Motivo: N/A	pendiente	0	\N	\N	\N	\N	\N	2026-06-16 13:38:10.234+00	2026-06-16 13:38:10.234+00	\N
11	otro	email	\N	\N	11	Nueva solicitud de beca: undefined	Se ha solicitado una beca "Beca por hermanos" para el alumno undefined. Motivo: N/A	pendiente	0	\N	\N	\N	\N	\N	2026-06-16 13:38:10.238+00	2026-06-16 13:38:10.238+00	\N
12	otro	email	\N	\N	18	Nueva solicitud de beca: undefined	Se ha solicitado una beca "Beca por hermanos" para el alumno undefined. Motivo: N/A	pendiente	0	\N	\N	\N	\N	\N	2026-06-16 13:38:10.244+00	2026-06-16 13:38:10.244+00	\N
13	otro	email	\N	\N	20	Nueva solicitud de beca: undefined	Se ha solicitado una beca "Beca por hermanos" para el alumno undefined. Motivo: N/A	pendiente	0	\N	\N	\N	\N	\N	2026-06-16 13:38:10.25+00	2026-06-16 13:38:10.25+00	\N
14	otro	email	\N	\N	2	Nueva solicitud de beca: undefined	Se ha solicitado una beca "Beca por hermanos" para el alumno undefined. Motivo: AA	pendiente	0	\N	\N	\N	\N	\N	2026-06-16 13:40:20.763+00	2026-06-16 13:40:20.763+00	\N
15	otro	email	\N	\N	1	Nueva solicitud de beca: undefined	Se ha solicitado una beca "Beca por hermanos" para el alumno undefined. Motivo: AA	pendiente	0	\N	\N	\N	\N	\N	2026-06-16 13:40:20.77+00	2026-06-16 13:40:20.77+00	\N
16	otro	email	\N	\N	7	Nueva solicitud de beca: undefined	Se ha solicitado una beca "Beca por hermanos" para el alumno undefined. Motivo: AA	pendiente	0	\N	\N	\N	\N	\N	2026-06-16 13:40:20.775+00	2026-06-16 13:40:20.775+00	\N
17	otro	email	\N	\N	6	Nueva solicitud de beca: undefined	Se ha solicitado una beca "Beca por hermanos" para el alumno undefined. Motivo: AA	pendiente	0	\N	\N	\N	\N	\N	2026-06-16 13:40:20.78+00	2026-06-16 13:40:20.78+00	\N
18	otro	email	\N	\N	11	Nueva solicitud de beca: undefined	Se ha solicitado una beca "Beca por hermanos" para el alumno undefined. Motivo: AA	pendiente	0	\N	\N	\N	\N	\N	2026-06-16 13:40:20.783+00	2026-06-16 13:40:20.783+00	\N
19	otro	email	\N	\N	18	Nueva solicitud de beca: undefined	Se ha solicitado una beca "Beca por hermanos" para el alumno undefined. Motivo: AA	pendiente	0	\N	\N	\N	\N	\N	2026-06-16 13:40:20.785+00	2026-06-16 13:40:20.785+00	\N
20	otro	email	\N	\N	20	Nueva solicitud de beca: undefined	Se ha solicitado una beca "Beca por hermanos" para el alumno undefined. Motivo: AA	pendiente	0	\N	\N	\N	\N	\N	2026-06-16 13:40:20.789+00	2026-06-16 13:40:20.789+00	\N
\.


--
-- Data for Name: pago; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.pago (pago_id, alumno_id, tutor_id, fecha_pago, monto_total, metodo_pago, aplicado_a_saldo, observaciones, registrado_por, registrado_en, actualizado_en) FROM stdin;
1	2	1	2026-09-04	4500.00	transferencia	f	Colegiatura septiembre 2026 - pago puntual (Roberto)	1	2026-06-12 05:56:10.696221+00	2026-06-12 05:56:10.696221+00
2	1	1	2026-10-08	4400.00	deposito	f	Colegiatura octubre 2026 - tardía, recargo $400 (Roberto)	1	2026-06-12 05:56:10.703911+00	2026-06-12 05:56:10.703911+00
3	1	1	2026-11-04	2000.00	efectivo	f	Abono parcial colegiatura noviembre 2026 (Roberto)	3	2026-06-12 05:56:10.712725+00	2026-06-12 05:56:10.712725+00
4	2	2	2026-08-03	4500.00	transferencia	f	Colegiatura agosto 2026 de Diego pagada por Lucía (madre, custodia compartida)	1	2026-06-12 05:56:10.719005+00	2026-06-12 05:56:10.719005+00
5	16	12	2026-06-13	4500.00	efectivo	f	\N	1	2026-06-14 23:19:57.209+00	2026-06-14 23:19:57.209+00
6	1	1	2026-06-15	32000.00	efectivo	f	\N	1	2026-06-15 03:31:31.968+00	2026-06-15 03:31:31.968+00
7	1	1	2026-06-15	2000.00	efectivo	f	Pago adelantado de colegiaturas (1 meses)	1	2026-06-15 03:33:07.621+00	2026-06-15 03:33:07.621+00
8	10	6	2026-06-15	52500.00	efectivo	f	\N	7	2026-06-15 04:38:52.196+00	2026-06-15 04:38:52.196+00
9	12	8	2026-06-15	50000000.00	efectivo	f	\N	7	2026-06-15 05:04:51.48+00	2026-06-15 05:04:51.48+00
10	10	6	2026-06-15	1500.00	efectivo	f	\N	7	2026-06-15 05:07:25.875+00	2026-06-15 05:07:25.875+00
11	10	6	2026-06-15	4500.00	efectivo	f	\N	7	2026-06-15 05:21:22.539+00	2026-06-15 05:21:22.539+00
12	10	6	2026-06-15	4500.00	efectivo	f	\N	7	2026-06-15 05:21:55.182+00	2026-06-15 05:21:55.182+00
13	10	6	2026-06-15	4500.00	efectivo	f	\N	7	2026-06-15 05:48:55.702+00	2026-06-15 05:48:55.702+00
14	10	6	2026-06-16	1500.00	efectivo	f	\N	19	2026-06-16 09:32:35.984+00	2026-06-16 09:32:35.984+00
15	10	6	2026-06-16	4500.00	efectivo	f	\N	19	2026-06-16 09:33:02.494+00	2026-06-16 09:33:02.494+00
16	10	6	2026-06-16	4500.00	efectivo	f	\N	19	2026-06-16 09:35:44.348+00	2026-06-16 09:35:44.348+00
17	10	6	2026-06-16	4500.00	efectivo	f	\N	19	2026-06-16 09:45:30.73+00	2026-06-16 09:45:30.73+00
18	10	6	2026-06-16	4500.00	efectivo	f	\N	7	2026-06-16 10:00:16.274+00	2026-06-16 10:00:16.274+00
20	87	89	2026-06-16	32000.00	efectivo	f	\N	4	2026-06-16 19:15:35.713+00	2026-06-16 19:15:35.713+00
21	87	89	2026-06-16	6000.00	efectivo	f	Pago adelantado de colegiaturas (3 meses)	4	2026-06-16 19:16:39.277+00	2026-06-16 19:16:39.277+00
22	120	122	2026-06-16	8000.00	efectivo	f	Pago adelantado de colegiaturas (2 meses)	4	2026-06-16 19:36:56.929+00	2026-06-16 19:36:56.929+00
23	42	44	2026-06-16	4500.00	transferencia	f	\N	1	2026-06-16 19:57:26.334+00	2026-06-16 19:57:26.334+00
24	9	6	2026-06-16	4000.00	transferencia	f	\N	1	2026-06-16 20:04:39.318+00	2026-06-16 20:04:39.318+00
25	3	3	2026-06-16	1500.00	transferencia	f	\N	4	2026-06-16 21:54:58.946+00	2026-06-16 21:54:58.946+00
\.


--
-- Data for Name: periodo_evaluacion; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.periodo_evaluacion (periodo_id, ciclo_id, nivel_id, tipo, numero, nombre, fecha_inicio, fecha_fin, es_final_ciclo, creado_en, actualizado_en, eliminado_en) FROM stdin;
1	2	2	trimestre	1	Trimestre 1	2026-08-03	2026-11-02	f	2026-06-15 20:32:49.233+00	2026-06-15 20:32:49.233+00	\N
2	2	2	trimestre	3	Trimestre 3	2027-02-03	2027-05-02	f	2026-06-15 20:34:38.57+00	2026-06-15 20:34:38.57+00	\N
89	7	1	trimestre	3	Trimestre 3	2026-12-16	2027-03-15	f	2026-06-16 14:35:19.299+00	2026-06-16 14:35:19.299+00	\N
5	2	2	trimestre	2	Trimestre 2	2026-11-03	2027-02-02	f	2026-06-15 20:34:38.571+00	2026-06-15 20:34:38.571+00	\N
90	7	1	trimestre	1	Trimestre 1	2026-06-16	2026-09-15	f	2026-06-16 14:35:19.299+00	2026-06-16 14:35:19.299+00	\N
11	2	1	trimestre	2	Trimestre 2	2026-11-03	2027-02-02	f	2026-06-15 20:47:09.244+00	2026-06-15 20:47:09.244+00	\N
12	2	1	trimestre	1	Trimestre 1	2026-08-03	2026-11-02	f	2026-06-15 20:47:09.244+00	2026-06-15 20:47:09.244+00	\N
13	2	1	trimestre	3	Trimestre 3	2027-02-03	2027-05-02	f	2026-06-15 20:47:09.257+00	2026-06-15 20:47:09.257+00	\N
14	3	3	trimestre	1	Trimestre 1	2026-08-01	2026-10-31	f	2026-06-15 20:48:19.43+00	2026-06-15 20:48:19.43+00	\N
15	3	4	trimestre	1	Trimestre 1	2026-08-01	2026-10-31	f	2026-06-15 21:47:58.022+00	2026-06-15 21:47:58.022+00	\N
16	3	4	trimestre	2	Trimestre 2	2026-11-01	2027-01-31	f	2026-06-15 21:47:58.022+00	2026-06-15 21:47:58.022+00	\N
17	3	4	trimestre	3	Trimestre 3	2027-02-01	2027-05-01	f	2026-06-15 21:47:58.049+00	2026-06-15 21:47:58.049+00	\N
98	7	1	trimestre	2	Trimestre 2	2026-09-16	2026-12-15	f	2026-06-16 14:35:19.3+00	2026-06-16 14:35:19.3+00	\N
19	2	3	trimestre	2	Trimestre 2	2026-11-03	2027-02-02	f	2026-06-15 22:27:32.268+00	2026-06-15 22:27:32.268+00	\N
20	2	3	trimestre	3	Trimestre 3	2027-02-03	2027-05-02	f	2026-06-15 22:27:32.264+00	2026-06-15 22:27:32.264+00	\N
23	2	3	trimestre	1	Trimestre 1	2026-08-03	2026-11-02	f	2026-06-15 22:27:32.266+00	2026-06-15 22:27:32.266+00	\N
103	7	2	trimestre	1	Trimestre 1	2026-06-16	2026-09-15	f	2026-06-16 14:45:40.866+00	2026-06-16 14:45:40.866+00	\N
102	7	2	trimestre	3	Trimestre 3	2026-12-16	2027-03-15	f	2026-06-16 14:45:40.866+00	2026-06-16 14:45:40.866+00	\N
108	7	2	trimestre	2	Trimestre 2	2026-09-16	2026-12-15	f	2026-06-16 14:45:40.893+00	2026-06-16 14:45:40.893+00	\N
35	3	3	trimestre	3	Trimestre 3	2027-02-01	2027-05-01	f	2026-06-16 00:07:45.147+00	2026-06-16 00:07:45.147+00	\N
36	3	3	trimestre	2	Trimestre 2	2026-11-01	2027-01-31	f	2026-06-16 00:07:45.15+00	2026-06-16 00:07:45.15+00	\N
43	7	3	trimestre	2	Trimestre 2	2026-09-16	2026-12-15	f	2026-06-16 14:33:14.697+00	2026-06-16 14:33:14.697+00	\N
49	7	3	trimestre	1	Trimestre 1	2026-06-16	2026-09-15	f	2026-06-16 14:33:14.696+00	2026-06-16 14:33:14.696+00	\N
53	7	3	trimestre	3	Trimestre 3	2026-12-16	2027-03-15	f	2026-06-16 14:33:14.698+00	2026-06-16 14:33:14.698+00	\N
\.


--
-- Data for Name: plan_pago; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.plan_pago (plan_pago_id, ciclo_id, nombre, meses, monto_mensual, monto_diciembre, descripcion, activo, creado_en, actualizado_en, eliminado_en) FROM stdin;
1	3	Plan 10 meses	10	4000.00	8000.00	\N	t	2026-06-14 18:44:45.459+00	2026-06-14 18:44:45.459+00	\N
2	3	Plan 12 meses	12	3500.00	7000.00	\N	t	2026-06-14 18:44:45.473+00	2026-06-14 18:44:45.473+00	\N
3	3	Pago anual	1	40000.00	40000.00	\N	t	2026-06-14 18:44:45.479+00	2026-06-14 18:44:45.479+00	\N
4	2	Plan 10 meses	10	4000.00	8000.00	\N	t	2026-06-15 20:52:07.902+00	2026-06-15 20:52:07.902+00	\N
\.


--
-- Data for Name: recargo; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.recargo (recargo_id, calendario_pago_id, monto_original, monto_actual, estado, motivo_modificacion, aplicado_en, modificado_por, modificado_en, actualizado_en) FROM stdin;
1	13	400.00	400.00	aplicado	\N	2026-10-06	\N	\N	2026-06-12 05:56:10.703911+00
\.


--
-- Data for Name: rol; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.rol (rol_id, codigo, nombre, descripcion, creado_en, actualizado_en, eliminado_en) FROM stdin;
1	administrador	Administrador	Acceso total al sistema, configuración y seguridad.	2026-06-12 05:56:09.241672+00	2026-06-12 05:56:09.241672+00	\N
2	directora	Directora	Gestión académica y financiera con privilegios de aprobación.	2026-06-12 05:56:09.241672+00	2026-06-12 05:56:09.241672+00	\N
3	empleado	Empleado	Registra pagos, alumnos y datos operativos.	2026-06-12 05:56:09.241672+00	2026-06-12 05:56:09.241672+00	\N
4	docente	Docente	Captura calificaciones y asistencia de sus grupos.	2026-06-12 05:56:09.241672+00	2026-06-12 05:56:09.241672+00	\N
\.


--
-- Data for Name: solicitud_beca; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.solicitud_beca (solicitud_id, alumno_id, beca_id, ciclo_id, motivo, estado, solicitada_por, resuelta_por, observaciones, fecha_solicitud, fecha_resolucion, creado_en, actualizado_en, eliminado_en) FROM stdin;
1	75	4	7		pendiente	19	\N	\N	2026-06-16 13:20:24.183+00	\N	2026-06-16 13:20:24.183+00	2026-06-16 13:20:24.183+00	\N
2	54	2	7		pendiente	19	\N	\N	2026-06-16 13:25:32.472+00	\N	2026-06-16 13:25:32.472+00	2026-06-16 13:25:32.472+00	\N
3	42	6	7		pendiente	19	\N	\N	2026-06-16 13:32:22.089+00	\N	2026-06-16 13:32:22.089+00	2026-06-16 13:32:22.089+00	\N
4	237	6	7	porque si ya acepta	pendiente	22	\N	\N	2026-06-16 13:32:36.586+00	\N	2026-06-16 13:32:36.586+00	2026-06-16 13:32:36.586+00	\N
5	10	2	7		pendiente	19	\N	\N	2026-06-16 13:32:40.316+00	\N	2026-06-16 13:32:40.316+00	2026-06-16 13:32:40.316+00	\N
6	10	1	7		pendiente	19	\N	\N	2026-06-16 13:38:10.152+00	\N	2026-06-16 13:38:10.152+00	2026-06-16 13:38:10.152+00	\N
7	42	1	7	AA	pendiente	19	\N	\N	2026-06-16 13:40:20.739+00	\N	2026-06-16 13:40:20.739+00	2026-06-16 13:40:20.739+00	\N
\.


--
-- Data for Name: tarifa; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.tarifa (tarifa_id, ciclo_id, nivel_id, concepto, monto, descripcion, activa, creado_en, actualizado_en, eliminado_en) FROM stdin;
4	2	2	uniforme	1500.00	Uniforme escolar primaria	t	2026-06-12 05:56:10.653137+00	2026-06-12 05:56:10.653137+00	\N
5	2	3	inscripcion	6000.00	Inscripción anual secundaria	t	2026-06-12 05:56:10.658211+00	2026-06-12 05:56:10.658211+00	\N
6	2	3	colegiatura	4500.00	Colegiatura mensual secundaria	t	2026-06-12 05:56:10.658211+00	2026-06-12 05:56:10.658211+00	\N
7	2	3	material	1500.00	Paquete de materiales secundaria	t	2026-06-12 05:56:10.658211+00	2026-06-12 05:56:10.658211+00	\N
8	2	3	uniforme	1800.00	Uniforme escolar secundaria	t	2026-06-12 05:56:10.658211+00	2026-06-12 05:56:10.658211+00	\N
9	3	2	colegiatura	500.00	\N	t	2026-06-15 04:26:58.027+00	2026-06-15 04:26:58.027+00	\N
10	3	2	inscripcion	600.00	\N	t	2026-06-15 04:26:58.037+00	2026-06-15 04:26:58.037+00	\N
11	3	2	arancel	65.00	\N	t	2026-06-15 04:26:58.041+00	2026-06-15 04:26:58.041+00	\N
12	3	2	material	500.00	\N	t	2026-06-15 04:26:58.044+00	2026-06-15 04:26:58.044+00	\N
2	2	2	colegiatura	4000.00	Colegiatura mensual primaria	t	2026-06-12 05:56:10.653137+00	2026-06-16 12:10:24.759868+00	\N
1	2	2	inscripcion	5000.00	Inscripción anual primaria	t	2026-06-12 05:56:10.653137+00	2026-06-16 12:10:24.759868+00	\N
13	2	2	arancel	500.00	\N	t	2026-06-16 12:10:24.777+00	2026-06-16 12:10:24.777+00	\N
3	2	2	material	1200.00	Paquete de materiales primaria	t	2026-06-12 05:56:10.653137+00	2026-06-16 12:10:24.759868+00	\N
18	7	1	colegiatura	200.00	\N	t	2026-06-16 12:17:51.791+00	2026-06-16 12:17:51.791+00	\N
19	7	1	inscripcion	2000.00	\N	t	2026-06-16 12:17:51.795+00	2026-06-16 12:17:51.795+00	\N
20	7	1	arancel	2000.00	\N	t	2026-06-16 12:17:51.797+00	2026-06-16 12:17:51.797+00	\N
21	7	1	material	2000.00	\N	t	2026-06-16 12:17:51.801+00	2026-06-16 12:17:51.801+00	\N
22	7	3	colegiatura	2000.00	\N	t	2026-06-16 12:18:03.291+00	2026-06-16 12:18:03.291+00	\N
23	7	3	inscripcion	2000.00	\N	t	2026-06-16 12:18:03.294+00	2026-06-16 12:18:03.294+00	\N
24	7	3	arancel	2000.00	\N	t	2026-06-16 12:18:03.299+00	2026-06-16 12:18:03.299+00	\N
25	7	3	material	2000.00	\N	t	2026-06-16 12:18:03.303+00	2026-06-16 12:18:03.303+00	\N
14	7	2	colegiatura	4000.00	\N	t	2026-06-16 12:17:31.898+00	2026-06-16 19:56:14.731634+00	\N
15	7	2	inscripcion	4500.00	\N	t	2026-06-16 12:17:31.904+00	2026-06-16 19:56:14.731634+00	\N
16	7	2	arancel	2500.00	\N	t	2026-06-16 12:17:31.908+00	2026-06-16 19:56:14.731634+00	\N
17	7	2	material	450.00	\N	t	2026-06-16 12:17:31.911+00	2026-06-16 19:56:14.731634+00	\N
\.


--
-- Data for Name: token_revocado; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.token_revocado (id, jti, revocado_en) FROM stdin;
\.


--
-- Data for Name: tutor; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.tutor (tutor_id, nombre_completo, correo_electronico, telefono, direccion, rfc, curp, regimen_fiscal, uso_cfdi, direccion_fiscal, codigo_postal, correo_facturacion, requiere_factura, tipo_pago_habitual, saldo_a_favor, activo, creado_en, actualizado_en, eliminado_en) FROM stdin;
1	Roberto Mendoza Hernández	roberto.mendoza@correo.com	9211223344	Av. Ignacio Zaragoza 1245, Col. Centro, Coatzacoalcos, Ver.	MEHR780815KL2	MEHR780815HVZNRB04	612	G03	Av. Ignacio Zaragoza 1245, Col. Centro, Coatzacoalcos, Ver.	96400	roberto.mendoza@correo.com	t	transferencia	0.00	t	2026-06-12 05:56:10.663608+00	2026-06-12 05:56:10.663608+00	\N
2	Lucía López Vargas	lucia.lopez@correo.com	9211889900	Calle Laurel 156, Col. Las Flores, Coatzacoalcos, Ver.	LOVL850623K94	LOVL850623MVZPRR04	605	\N	\N	96510	\N	f	transferencia	0.00	t	2026-06-12 05:56:10.663608+00	2026-06-12 05:56:10.663608+00	\N
4	Jorge González Ramírez	jorge.gonzalez@correo.com	9213445566	Av. Universidad 567, Col. Brisas del Mar, Coatzacoalcos, Ver.	GORJ750412B71	GORJ750412HVZNMR03	605	\N	\N	96535	\N	f	transferencia	0.00	t	2026-06-12 05:56:10.663608+00	2026-06-12 05:56:10.663608+00	\N
5	Patricia Soto Reyes	patricia.soto@correo.com	9214556677	Calle Cedros 234, Col. Lomas de Barrillas, Coatzacoalcos, Ver.	SORP880706L23	SORP880706MVZTYT09	612	G03	Calle Cedros 234, Col. Lomas de Barrillas, Coatzacoalcos, Ver.	96560	patricia.soto@correo.com	t	deposito	0.00	t	2026-06-12 05:56:10.663608+00	2026-06-12 05:56:10.663608+00	\N
6	Miguel Ángel Castro Domínguez	miguel.castro@correo.com	9215667788	Av. Carranza 1789, Col. Independencia, Coatzacoalcos, Ver.	CADM850217X42	CADM850217HVZSRG01	605	\N	\N	96440	\N	f	efectivo	0.00	t	2026-06-12 05:56:10.663608+00	2026-06-12 05:56:10.663608+00	\N
7	Jorge González	jorge@mail.com	5551234567	\N	GOJL800101XXX	\N	\N	\N	\N	\N	jorge@mail.com	t	\N	0.00	t	2026-06-14 18:44:45.679+00	2026-06-14 18:44:45.679+00	\N
8	Luis Pérez	\N	5559876543	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-14 18:44:45.725+00	2026-06-14 18:44:45.725+00	\N
9	Ramón Fernández	\N	5554567890	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-14 18:44:45.751+00	2026-06-14 18:44:45.751+00	\N
11	Patricia Gómez	\N	5556677889	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-14 18:44:45.794+00	2026-06-14 18:44:45.794+00	\N
12	Roberto Hernández	\N	5557890123	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-14 18:44:45.818+00	2026-06-14 18:44:45.818+00	\N
14	Mario Castro	\N	5556543210	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-14 18:44:45.859+00	2026-06-14 18:44:45.859+00	\N
57	Tutor de Matias	tutor.K694@test.com	5551194769	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.384+00	2026-06-15 20:52:46.384+00	\N
15	Luis Pérez	\N	5559876543	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 19:44:48.106+00	2026-06-15 19:44:48.106+00	\N
16	Ramón Fernández	\N	5554567890	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 19:44:48.216+00	2026-06-15 19:44:48.216+00	\N
18	Patricia Gómez	\N	5556677889	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 19:44:48.268+00	2026-06-15 19:44:48.268+00	\N
19	Roberto Hernández	\N	5557890123	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 19:44:48.305+00	2026-06-15 19:44:48.305+00	\N
21	Mario Castro	\N	5556543210	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 19:44:48.395+00	2026-06-15 19:44:48.395+00	\N
22	Tutor de Mia	tutor.HCE3@test.com	5559939420	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:51:50.05+00	2026-06-15 20:51:50.05+00	\N
23	Tutor de Jose	tutor.BFF4@test.com	5556267231	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:07.937+00	2026-06-15 20:52:07.937+00	\N
24	Tutor de Daniel	tutor.MJHC@test.com	5552589478	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:07.973+00	2026-06-15 20:52:07.973+00	\N
25	Tutor de Valeria	tutor.CEHQ@test.com	5552082998	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:45.677+00	2026-06-15 20:52:45.677+00	\N
26	Tutor de Maria	tutor.8GQB@test.com	5558408063	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:45.715+00	2026-06-15 20:52:45.715+00	\N
27	Tutor de Sebastian	tutor.DBOC@test.com	5552866059	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:45.733+00	2026-06-15 20:52:45.733+00	\N
28	Tutor de Renata	tutor.UA1Y@test.com	5551783462	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:45.759+00	2026-06-15 20:52:45.759+00	\N
29	Tutor de Nicolas	tutor.RZ3Z@test.com	5556612704	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:45.781+00	2026-06-15 20:52:45.781+00	\N
30	Tutor de Isabella	tutor.0UA0@test.com	5553631085	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:45.803+00	2026-06-15 20:52:45.803+00	\N
31	Tutor de Gael	tutor.7KKH@test.com	5552463431	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:45.82+00	2026-06-15 20:52:45.82+00	\N
32	Tutor de Matias	tutor.RBEV@test.com	5558683623	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:45.839+00	2026-06-15 20:52:45.839+00	\N
33	Tutor de Leonardo	tutor.V8J0@test.com	5558856705	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:45.861+00	2026-06-15 20:52:45.861+00	\N
34	Tutor de Emiliano	tutor.IG1Q@test.com	5557235020	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:45.883+00	2026-06-15 20:52:45.883+00	\N
35	Tutor de Mia	tutor.JF45@test.com	5553776658	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:45.901+00	2026-06-15 20:52:45.901+00	\N
36	Tutor de Diego	tutor.6E8Z@test.com	5559539241	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:45.923+00	2026-06-15 20:52:45.923+00	\N
37	Tutor de Regina	tutor.QWKQ@test.com	5553163502	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:45.947+00	2026-06-15 20:52:45.947+00	\N
38	Tutor de Emiliano	tutor.GN3C@test.com	5557393780	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:45.974+00	2026-06-15 20:52:45.974+00	\N
39	Tutor de Diego	tutor.2ZH3@test.com	5555299410	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.002+00	2026-06-15 20:52:46.002+00	\N
40	Tutor de Santiago	tutor.ATQ4@test.com	5551339525	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.021+00	2026-06-15 20:52:46.021+00	\N
41	Tutor de Mateo	tutor.2BAH@test.com	5558078913	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.043+00	2026-06-15 20:52:46.043+00	\N
42	Tutor de Natalia	tutor.S2W0@test.com	5554131374	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.064+00	2026-06-15 20:52:46.064+00	\N
43	Tutor de Alejandro	tutor.X7S4@test.com	5552593962	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.084+00	2026-06-15 20:52:46.084+00	\N
44	Tutor de Alejandro	tutor.2ALP@test.com	5558725758	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.103+00	2026-06-15 20:52:46.103+00	\N
45	Tutor de Renata	tutor.Z01D@test.com	5557342254	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.124+00	2026-06-15 20:52:46.124+00	\N
46	Tutor de Mateo	tutor.XNOJ@test.com	5557152847	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.166+00	2026-06-15 20:52:46.166+00	\N
47	Tutor de Matias	tutor.YLTA@test.com	5552814116	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.187+00	2026-06-15 20:52:46.187+00	\N
48	Tutor de Santiago	tutor.T6IE@test.com	5554166884	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.213+00	2026-06-15 20:52:46.213+00	\N
49	Tutor de Sofia	tutor.53SC@test.com	5551331435	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.229+00	2026-06-15 20:52:46.229+00	\N
50	Tutor de Gabriel	tutor.4C9Z@test.com	5558913113	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.251+00	2026-06-15 20:52:46.251+00	\N
51	Tutor de Mia	tutor.00BT@test.com	5551655832	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.269+00	2026-06-15 20:52:46.269+00	\N
52	Tutor de Isabella	tutor.TK9S@test.com	5559858869	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.289+00	2026-06-15 20:52:46.289+00	\N
53	Tutor de Renata	tutor.K1WR@test.com	5557295338	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.308+00	2026-06-15 20:52:46.308+00	\N
54	Tutor de Valentina	tutor.695I@test.com	5558191895	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.329+00	2026-06-15 20:52:46.329+00	\N
55	Tutor de Valentina	tutor.0QR8@test.com	5551770445	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.347+00	2026-06-15 20:52:46.347+00	\N
56	Tutor de Alejandro	tutor.7N51@test.com	5555402687	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.365+00	2026-06-15 20:52:46.365+00	\N
58	Tutor de Santiago	tutor.G4V5@test.com	5558073532	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.407+00	2026-06-15 20:52:46.407+00	\N
59	Tutor de Victoria	tutor.1RJJ@test.com	5556632978	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.427+00	2026-06-15 20:52:46.427+00	\N
60	Tutor de Camila	tutor.NL13@test.com	5559217731	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.443+00	2026-06-15 20:52:46.443+00	\N
61	Tutor de Leonardo	tutor.BYRC@test.com	5551525701	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.463+00	2026-06-15 20:52:46.463+00	\N
62	Tutor de Renata	tutor.OPL2@test.com	5558316514	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.483+00	2026-06-15 20:52:46.483+00	\N
63	Tutor de Sebastian	tutor.9YCT@test.com	5555716695	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.5+00	2026-06-15 20:52:46.5+00	\N
64	Tutor de Santiago	tutor.G0JK@test.com	5552100463	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.519+00	2026-06-15 20:52:46.519+00	\N
65	Tutor de Alejandro	tutor.H76B@test.com	5558427711	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.538+00	2026-06-15 20:52:46.538+00	\N
66	Tutor de Santiago	tutor.WXK9@test.com	5559085428	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.555+00	2026-06-15 20:52:46.555+00	\N
20	Elena Soto	\N	5553456789	\N	FSDFSSSSSSSSS	\N	606	D05	sdgegw	23453	wefewdfwe@	t	\N	0.00	t	2026-06-15 19:44:48.352+00	2026-06-16 11:54:50.299841+00	\N
13	Elena Soto	\N	5553456789	\N	QWDQWDQWDQWD	\N	610	D05	vcasv	12342	vdav@	t	\N	0.00	t	2026-06-14 18:44:45.841+00	2026-06-16 11:56:02.065855+00	\N
10	Ana Ramírez	lop	5552223344	lop	OAIPPPPPPPPPO	\N	625	G01	lopez	56999	lpp@	t	\N	0.00	t	2026-06-14 18:44:45.775+00	2026-06-16 11:56:43.718816+00	\N
67	Tutor de Natalia	tutor.UPWW@test.com	5557890810	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.574+00	2026-06-15 20:52:46.574+00	\N
68	Tutor de Valentina	tutor.XBLB@test.com	5556303923	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.594+00	2026-06-15 20:52:46.594+00	\N
69	Tutor de Sebastian	tutor.4NSB@test.com	5557803297	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.611+00	2026-06-15 20:52:46.611+00	\N
70	Tutor de Gabriel	tutor.8PUY@test.com	5558298569	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.628+00	2026-06-15 20:52:46.628+00	\N
71	Tutor de Valeria	tutor.6MTV@test.com	5553274159	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.643+00	2026-06-15 20:52:46.643+00	\N
72	Tutor de Renata	tutor.SLP1@test.com	5557084286	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.664+00	2026-06-15 20:52:46.664+00	\N
73	Tutor de Alejandro	tutor.TZ3A@test.com	5554821836	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.69+00	2026-06-15 20:52:46.69+00	\N
74	Tutor de Gabriel	tutor.ELCX@test.com	5558249255	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.711+00	2026-06-15 20:52:46.711+00	\N
75	Tutor de Renata	tutor.5BTC@test.com	5554389277	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.732+00	2026-06-15 20:52:46.732+00	\N
76	Tutor de Daniel	tutor.W0H1@test.com	5551273662	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.752+00	2026-06-15 20:52:46.752+00	\N
77	Tutor de Alejandro	tutor.4PBT@test.com	5553376124	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.772+00	2026-06-15 20:52:46.772+00	\N
78	Tutor de Daniel	tutor.ED7X@test.com	5556859506	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.791+00	2026-06-15 20:52:46.791+00	\N
79	Tutor de Gael	tutor.Y29U@test.com	5554686564	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.809+00	2026-06-15 20:52:46.809+00	\N
80	Tutor de Emiliano	tutor.HSX7@test.com	5557977303	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.825+00	2026-06-15 20:52:46.825+00	\N
81	Tutor de Mia	tutor.JNLP@test.com	5559892002	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.847+00	2026-06-15 20:52:46.847+00	\N
82	Tutor de Thiago	tutor.YKGG@test.com	5554831193	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.867+00	2026-06-15 20:52:46.867+00	\N
83	Tutor de Jose	tutor.3OMS@test.com	5558987632	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.887+00	2026-06-15 20:52:46.887+00	\N
84	Tutor de Thiago	tutor.L1F2@test.com	5555589815	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.903+00	2026-06-15 20:52:46.903+00	\N
85	Tutor de Leonardo	tutor.JXPG@test.com	5554758635	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.921+00	2026-06-15 20:52:46.921+00	\N
86	Tutor de Natalia	tutor.L2P4@test.com	5559733239	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.943+00	2026-06-15 20:52:46.943+00	\N
87	Tutor de Mateo	tutor.Z0YX@test.com	5555200293	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.964+00	2026-06-15 20:52:46.964+00	\N
88	Tutor de Isabella	tutor.56XF@test.com	5556107784	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:46.983+00	2026-06-15 20:52:46.983+00	\N
89	Tutor de Sofia	tutor.HJ6X@test.com	5554202346	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:47+00	2026-06-15 20:52:47+00	\N
90	Tutor de Mateo	tutor.AWQT@test.com	5555481868	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:47.018+00	2026-06-15 20:52:47.018+00	\N
91	Tutor de Gael	tutor.9MOU@test.com	5557086186	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:47.039+00	2026-06-15 20:52:47.039+00	\N
92	Tutor de Matias	tutor.CIJP@test.com	5558355042	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:47.057+00	2026-06-15 20:52:47.057+00	\N
93	Tutor de Gabriel	tutor.1CXL@test.com	5559112569	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:47.076+00	2026-06-15 20:52:47.076+00	\N
94	Tutor de Sebastian	tutor.9B3A@test.com	5558062393	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:47.095+00	2026-06-15 20:52:47.095+00	\N
95	Tutor de Emiliano	tutor.4RXN@test.com	5556456250	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:47.117+00	2026-06-15 20:52:47.117+00	\N
96	Tutor de Ximena	tutor.9BBZ@test.com	5556278543	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:47.136+00	2026-06-15 20:52:47.136+00	\N
97	Tutor de Jose	tutor.SLRT@test.com	5557316527	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:47.153+00	2026-06-15 20:52:47.153+00	\N
98	Tutor de Valentina	tutor.7PAP@test.com	5559205912	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:47.173+00	2026-06-15 20:52:47.173+00	\N
99	Tutor de Ximena	tutor.PMJD@test.com	5554867618	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:47.197+00	2026-06-15 20:52:47.197+00	\N
100	Tutor de Maria	tutor.WX8D@test.com	5551352698	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:47.215+00	2026-06-15 20:52:47.215+00	\N
101	Tutor de Renata	tutor.TZQH@test.com	5559607589	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:47.234+00	2026-06-15 20:52:47.234+00	\N
102	Tutor de Valeria	tutor.3FQF@test.com	5553619771	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:47.25+00	2026-06-15 20:52:47.25+00	\N
103	Tutor de Valeria	tutor.BT91@test.com	5551085472	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:47.271+00	2026-06-15 20:52:47.271+00	\N
104	Tutor de Jose	tutor.I3TU@test.com	5551698162	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:47.296+00	2026-06-15 20:52:47.296+00	\N
105	Tutor de Alejandro	tutor.LBDD@test.com	5558709893	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:52:47.317+00	2026-06-15 20:52:47.317+00	\N
106	Tutor de Leonardo	tutor.NH96@test.com	5559688586	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:07.902+00	2026-06-15 20:53:07.902+00	\N
107	Tutor de Santiago	tutor.UY1Y@test.com	5555794337	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:07.943+00	2026-06-15 20:53:07.943+00	\N
108	Tutor de Isabella	tutor.IIBU@test.com	5556771205	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:07.961+00	2026-06-15 20:53:07.961+00	\N
109	Tutor de Jose	tutor.IF7T@test.com	5555104498	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:07.984+00	2026-06-15 20:53:07.984+00	\N
110	Tutor de Renata	tutor.JBEM@test.com	5554808591	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.006+00	2026-06-15 20:53:08.006+00	\N
111	Tutor de Renata	tutor.PWTA@test.com	5555623778	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.025+00	2026-06-15 20:53:08.025+00	\N
112	Tutor de Isabella	tutor.2LRM@test.com	5559641044	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.048+00	2026-06-15 20:53:08.048+00	\N
113	Tutor de Emiliano	tutor.EA4S@test.com	5557412947	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.098+00	2026-06-15 20:53:08.098+00	\N
114	Tutor de Daniel	tutor.JW6D@test.com	5552339103	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.135+00	2026-06-15 20:53:08.135+00	\N
115	Tutor de Camila	tutor.4Q8E@test.com	5559116298	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.171+00	2026-06-15 20:53:08.171+00	\N
116	Tutor de Santiago	tutor.TOWP@test.com	5557509191	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.2+00	2026-06-15 20:53:08.2+00	\N
117	Tutor de Ximena	tutor.ORLS@test.com	5559782853	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.231+00	2026-06-15 20:53:08.231+00	\N
118	Tutor de Matias	tutor.GHTN@test.com	5556946711	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.256+00	2026-06-15 20:53:08.256+00	\N
119	Tutor de Regina	tutor.LNZE@test.com	5558740446	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.274+00	2026-06-15 20:53:08.274+00	\N
120	Tutor de Maria	tutor.GI3H@test.com	5554455542	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.295+00	2026-06-15 20:53:08.295+00	\N
121	Tutor de Gael	tutor.IFFG@test.com	5551024853	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.314+00	2026-06-15 20:53:08.314+00	\N
122	Tutor de Sofia	tutor.8VUP@test.com	5553849029	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.334+00	2026-06-15 20:53:08.334+00	\N
123	Tutor de Santiago	tutor.MH3E@test.com	5558361350	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.471+00	2026-06-15 20:53:08.471+00	\N
124	Tutor de Mateo	tutor.HT9N@test.com	5551236362	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.495+00	2026-06-15 20:53:08.495+00	\N
125	Tutor de Emiliano	tutor.J52H@test.com	5552270278	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.517+00	2026-06-15 20:53:08.517+00	\N
126	Tutor de Valeria	tutor.QLFQ@test.com	5558900669	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.535+00	2026-06-15 20:53:08.535+00	\N
127	Tutor de Emiliano	tutor.BKU5@test.com	5555519148	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.56+00	2026-06-15 20:53:08.56+00	\N
128	Tutor de Isabella	tutor.ZCXA@test.com	5556294080	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.59+00	2026-06-15 20:53:08.59+00	\N
129	Tutor de Leonardo	tutor.NTLD@test.com	5558010038	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.61+00	2026-06-15 20:53:08.61+00	\N
130	Tutor de Regina	tutor.OBZ8@test.com	5553797430	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.63+00	2026-06-15 20:53:08.63+00	\N
131	Tutor de Regina	tutor.D4PV@test.com	5559317258	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.652+00	2026-06-15 20:53:08.652+00	\N
132	Tutor de Natalia	tutor.8QE3@test.com	5557919096	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.667+00	2026-06-15 20:53:08.667+00	\N
133	Tutor de Thiago	tutor.KKH5@test.com	5558120871	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.687+00	2026-06-15 20:53:08.687+00	\N
134	Tutor de Maria	tutor.B1XL@test.com	5555486344	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.711+00	2026-06-15 20:53:08.711+00	\N
135	Tutor de Ximena	tutor.J3XT@test.com	5557550208	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.725+00	2026-06-15 20:53:08.725+00	\N
136	Tutor de Gael	tutor.6APJ@test.com	5551873922	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.746+00	2026-06-15 20:53:08.746+00	\N
137	Tutor de Gael	tutor.WARF@test.com	5551897622	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.767+00	2026-06-15 20:53:08.767+00	\N
138	Tutor de Alejandro	tutor.X5G2@test.com	5557148255	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.789+00	2026-06-15 20:53:08.789+00	\N
139	Tutor de Gabriel	tutor.KLXC@test.com	5551219685	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.811+00	2026-06-15 20:53:08.811+00	\N
140	Tutor de Alejandro	tutor.SQPU@test.com	5557386677	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.832+00	2026-06-15 20:53:08.832+00	\N
141	Tutor de Daniel	tutor.5YXG@test.com	5551750439	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.854+00	2026-06-15 20:53:08.854+00	\N
142	Tutor de Santiago	tutor.7XHQ@test.com	5556244611	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.876+00	2026-06-15 20:53:08.876+00	\N
143	Tutor de Mateo	tutor.LVTF@test.com	5553443611	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.894+00	2026-06-15 20:53:08.894+00	\N
144	Tutor de Sebastian	tutor.CEX3@test.com	5559484600	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.913+00	2026-06-15 20:53:08.913+00	\N
145	Tutor de Isabella	tutor.UZSQ@test.com	5559812699	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.936+00	2026-06-15 20:53:08.936+00	\N
146	Tutor de Matias	tutor.DCMD@test.com	5554973472	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.962+00	2026-06-15 20:53:08.962+00	\N
147	Tutor de Sebastian	tutor.R8UK@test.com	5554391043	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:08.982+00	2026-06-15 20:53:08.982+00	\N
148	Tutor de Valeria	tutor.7DJ1@test.com	5558473656	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.003+00	2026-06-15 20:53:09.003+00	\N
149	Tutor de Gael	tutor.L86O@test.com	5557557797	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.03+00	2026-06-15 20:53:09.03+00	\N
150	Tutor de Santiago	tutor.JSFS@test.com	5555243401	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.051+00	2026-06-15 20:53:09.051+00	\N
151	Tutor de Natalia	tutor.JO5Q@test.com	5551482918	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.075+00	2026-06-15 20:53:09.075+00	\N
152	Tutor de Renata	tutor.0SES@test.com	5551571624	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.107+00	2026-06-15 20:53:09.107+00	\N
153	Tutor de Gabriel	tutor.L5A6@test.com	5558995972	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.136+00	2026-06-15 20:53:09.136+00	\N
154	Tutor de Daniel	tutor.3J08@test.com	5554902116	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.162+00	2026-06-15 20:53:09.162+00	\N
155	Tutor de Alejandro	tutor.7NIQ@test.com	5554771545	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.191+00	2026-06-15 20:53:09.191+00	\N
156	Tutor de Diego	tutor.WYCB@test.com	5556270590	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.213+00	2026-06-15 20:53:09.213+00	\N
157	Tutor de Thiago	tutor.CVOX@test.com	5556823771	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.233+00	2026-06-15 20:53:09.233+00	\N
158	Tutor de Camila	tutor.E2CB@test.com	5556187555	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.256+00	2026-06-15 20:53:09.256+00	\N
159	Tutor de Santiago	tutor.FB7R@test.com	5551259904	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.279+00	2026-06-15 20:53:09.279+00	\N
160	Tutor de Daniel	tutor.YYK8@test.com	5551247990	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.299+00	2026-06-15 20:53:09.299+00	\N
161	Tutor de Isabella	tutor.CVJH@test.com	5559240372	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.324+00	2026-06-15 20:53:09.324+00	\N
162	Tutor de Mateo	tutor.ZGES@test.com	5557988829	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.349+00	2026-06-15 20:53:09.349+00	\N
163	Tutor de Daniel	tutor.SVGF@test.com	5553535251	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.37+00	2026-06-15 20:53:09.37+00	\N
164	Tutor de Sofia	tutor.3AOO@test.com	5555421024	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.393+00	2026-06-15 20:53:09.393+00	\N
165	Tutor de Alejandro	tutor.MJC6@test.com	5552666828	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.418+00	2026-06-15 20:53:09.418+00	\N
166	Tutor de Leonardo	tutor.AZ9M@test.com	5556929030	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.443+00	2026-06-15 20:53:09.443+00	\N
167	Tutor de Regina	tutor.2879@test.com	5555118520	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.466+00	2026-06-15 20:53:09.466+00	\N
168	Tutor de Regina	tutor.KL0R@test.com	5557127187	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.488+00	2026-06-15 20:53:09.488+00	\N
169	Tutor de Renata	tutor.AJIU@test.com	5551610645	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.512+00	2026-06-15 20:53:09.512+00	\N
170	Tutor de Valeria	tutor.G9GI@test.com	5554778568	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.535+00	2026-06-15 20:53:09.535+00	\N
171	Tutor de Natalia	tutor.PGSZ@test.com	5555946701	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.557+00	2026-06-15 20:53:09.557+00	\N
172	Tutor de Valentina	tutor.WUKU@test.com	5559424310	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.582+00	2026-06-15 20:53:09.582+00	\N
173	Tutor de Victoria	tutor.O69G@test.com	5556867923	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.604+00	2026-06-15 20:53:09.604+00	\N
174	Tutor de Mia	tutor.UR8H@test.com	5552958762	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.624+00	2026-06-15 20:53:09.624+00	\N
175	Tutor de Sofia	tutor.NMRI@test.com	5559234476	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.646+00	2026-06-15 20:53:09.646+00	\N
176	Tutor de Alejandro	tutor.24SN@test.com	5555614573	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.669+00	2026-06-15 20:53:09.669+00	\N
177	Tutor de Ximena	tutor.Q9ST@test.com	5552654762	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.695+00	2026-06-15 20:53:09.695+00	\N
178	Tutor de Gael	tutor.B6SD@test.com	5558124452	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.717+00	2026-06-15 20:53:09.717+00	\N
179	Tutor de Jose	tutor.C3TT@test.com	5555728340	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.739+00	2026-06-15 20:53:09.739+00	\N
180	Tutor de Valeria	tutor.46AQ@test.com	5555277769	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.76+00	2026-06-15 20:53:09.76+00	\N
181	Tutor de Mia	tutor.Q9AY@test.com	5551842683	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.784+00	2026-06-15 20:53:09.784+00	\N
182	Tutor de Leonardo	tutor.AIHE@test.com	5555693753	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.8+00	2026-06-15 20:53:09.8+00	\N
183	Tutor de Isabella	tutor.1XUZ@test.com	5551286280	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.823+00	2026-06-15 20:53:09.823+00	\N
184	Tutor de Gabriel	tutor.XESZ@test.com	5558162394	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.849+00	2026-06-15 20:53:09.849+00	\N
185	Tutor de Maria	tutor.VM4A@test.com	5551816741	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.872+00	2026-06-15 20:53:09.872+00	\N
186	Tutor de Renata	tutor.FN46@test.com	5558884166	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.893+00	2026-06-15 20:53:09.893+00	\N
187	Tutor de Emiliano	tutor.7Z47@test.com	5556487860	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.914+00	2026-06-15 20:53:09.914+00	\N
188	Tutor de Sebastian	tutor.ZKVZ@test.com	5552916446	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.936+00	2026-06-15 20:53:09.936+00	\N
189	Tutor de Natalia	tutor.2U8Z@test.com	5554490885	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.957+00	2026-06-15 20:53:09.957+00	\N
190	Tutor de Victoria	tutor.N92Y@test.com	5552575835	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:09.987+00	2026-06-15 20:53:09.987+00	\N
191	Tutor de Gael	tutor.LX6E@test.com	5551964914	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.01+00	2026-06-15 20:53:10.01+00	\N
192	Tutor de Diego	tutor.E7UB@test.com	5557109703	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.032+00	2026-06-15 20:53:10.032+00	\N
193	Tutor de Mateo	tutor.8Y5M@test.com	5554809940	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.056+00	2026-06-15 20:53:10.056+00	\N
194	Tutor de Maria	tutor.DDIV@test.com	5554613802	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.077+00	2026-06-15 20:53:10.077+00	\N
195	Tutor de Mia	tutor.EOJ3@test.com	5558690024	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.1+00	2026-06-15 20:53:10.1+00	\N
196	Tutor de Camila	tutor.SBET@test.com	5553534007	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.123+00	2026-06-15 20:53:10.123+00	\N
197	Tutor de Alejandro	tutor.0DR6@test.com	5559511593	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.142+00	2026-06-15 20:53:10.142+00	\N
198	Tutor de Thiago	tutor.RTFW@test.com	5556057092	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.163+00	2026-06-15 20:53:10.163+00	\N
199	Tutor de Victoria	tutor.GXTI@test.com	5553437379	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.184+00	2026-06-15 20:53:10.184+00	\N
200	Tutor de Sebastian	tutor.I9Z6@test.com	5559177584	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.206+00	2026-06-15 20:53:10.206+00	\N
201	Tutor de Victoria	tutor.K2ZV@test.com	5554660676	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.225+00	2026-06-15 20:53:10.225+00	\N
202	Tutor de Diego	tutor.F4MB@test.com	5557566567	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.249+00	2026-06-15 20:53:10.249+00	\N
203	Tutor de Valeria	tutor.4CSN@test.com	5558824897	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.265+00	2026-06-15 20:53:10.265+00	\N
204	Tutor de Natalia	tutor.ZZX0@test.com	5559012520	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.288+00	2026-06-15 20:53:10.288+00	\N
205	Tutor de Maria	tutor.8VKH@test.com	5551698182	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.31+00	2026-06-15 20:53:10.31+00	\N
206	Tutor de Regina	tutor.Y88K@test.com	5558631490	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.328+00	2026-06-15 20:53:10.328+00	\N
207	Tutor de Thiago	tutor.H15R@test.com	5556932569	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.354+00	2026-06-15 20:53:10.354+00	\N
208	Tutor de Daniel	tutor.GAH7@test.com	5555683329	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.377+00	2026-06-15 20:53:10.377+00	\N
209	Tutor de Thiago	tutor.S0BY@test.com	5558072317	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.399+00	2026-06-15 20:53:10.399+00	\N
210	Tutor de Jose	tutor.13KQ@test.com	5555727734	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.426+00	2026-06-15 20:53:10.426+00	\N
211	Tutor de Santiago	tutor.XW4H@test.com	5553371782	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.453+00	2026-06-15 20:53:10.453+00	\N
212	Tutor de Alejandro	tutor.JUWE@test.com	5559206717	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.493+00	2026-06-15 20:53:10.493+00	\N
213	Tutor de Valentina	tutor.D9VX@test.com	5555421906	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.526+00	2026-06-15 20:53:10.526+00	\N
214	Tutor de Jose	tutor.A9C2@test.com	5551443420	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.552+00	2026-06-15 20:53:10.552+00	\N
215	Tutor de Leonardo	tutor.TNMT@test.com	5556449791	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.575+00	2026-06-15 20:53:10.575+00	\N
216	Tutor de Matias	tutor.27K4@test.com	5559956418	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.595+00	2026-06-15 20:53:10.595+00	\N
217	Tutor de Matias	tutor.T124@test.com	5559847339	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.62+00	2026-06-15 20:53:10.62+00	\N
218	Tutor de Regina	tutor.PXF4@test.com	5559067723	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.645+00	2026-06-15 20:53:10.645+00	\N
219	Tutor de Santiago	tutor.451U@test.com	5553251644	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.669+00	2026-06-15 20:53:10.669+00	\N
220	Tutor de Alejandro	tutor.SOPY@test.com	5553160587	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.69+00	2026-06-15 20:53:10.69+00	\N
221	Tutor de Leonardo	tutor.HDGZ@test.com	5554344755	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.712+00	2026-06-15 20:53:10.712+00	\N
222	Tutor de Sebastian	tutor.S2RZ@test.com	5555350335	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.73+00	2026-06-15 20:53:10.73+00	\N
223	Tutor de Valeria	tutor.MLD8@test.com	5554220807	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.757+00	2026-06-15 20:53:10.757+00	\N
224	Tutor de Mateo	tutor.7ZL3@test.com	5554596436	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.775+00	2026-06-15 20:53:10.775+00	\N
225	Tutor de Natalia	tutor.GXA9@test.com	5559968719	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.798+00	2026-06-15 20:53:10.798+00	\N
226	Tutor de Diego	tutor.N237@test.com	5554520764	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.822+00	2026-06-15 20:53:10.822+00	\N
227	Tutor de Victoria	tutor.SMD6@test.com	5553141323	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.842+00	2026-06-15 20:53:10.842+00	\N
228	Tutor de Leonardo	tutor.GBUY@test.com	5558127292	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.867+00	2026-06-15 20:53:10.867+00	\N
229	Tutor de Renata	tutor.AZ3M@test.com	5559339041	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.889+00	2026-06-15 20:53:10.889+00	\N
230	Tutor de Thiago	tutor.E2J6@test.com	5556187953	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.912+00	2026-06-15 20:53:10.912+00	\N
231	Tutor de Camila	tutor.VK5X@test.com	5555770215	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.938+00	2026-06-15 20:53:10.938+00	\N
232	Tutor de Isabella	tutor.47GS@test.com	5555943955	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.957+00	2026-06-15 20:53:10.957+00	\N
233	Tutor de Renata	tutor.LL48@test.com	5557763645	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:10.98+00	2026-06-15 20:53:10.98+00	\N
234	Tutor de Renata	tutor.BS2Y@test.com	5556343044	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:11.003+00	2026-06-15 20:53:11.003+00	\N
235	Tutor de Victoria	tutor.2FVB@test.com	5557406176	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	0.00	t	2026-06-15 20:53:11.026+00	2026-06-15 20:53:11.026+00	\N
236	Juan Perez	fewfew	4564654	\N		\N		\N	\N	\N		f	\N	0.00	t	2026-06-16 09:04:45.828+00	2026-06-16 09:04:45.828+00	\N
3	Carmen Aguilar Vásquez	carmen.aguilar@correo.com	9212334455	Calle 5 de Mayo 89, Col. Petrolera, Coatzacoalcos, Ver.	AUVC820923P89	AUVC820923MVZGSR05	605	\N	\N	96500	\N	f	tarjeta	0.00	t	2026-06-12 05:56:10.663608+00	2026-06-16 10:04:43.213844+00	\N
244	juan vazques			\N	RFDSJEUF	\N	nose	\N	\N	\N		f	\N	0.00	t	2026-06-16 10:12:18.691+00	2026-06-16 10:14:34.852899+00	\N
245	Jose	\N	\N	\N	awds	\N	daws	daw	awsd	awsd	daw	t	\N	0.00	t	2026-06-16 10:18:29.138+00	2026-06-16 10:18:29.138+00	\N
246	Harry	\N	\N	\N	LKJPPPPPPPPPP	\N	612	aa	aa	aaawe	a@gmail.com	t	\N	0.00	t	2026-06-16 11:19:13.242+00	2026-06-16 11:46:29.873191+00	\N
17	Ana Ramírez	\N	5552223344	\N	RFTHNHTGTY123	\N	603	G03	niños heroes 157, Adolfo Lopez Mateos	67543	dianagf@gmail.com	t	\N	0.00	t	2026-06-15 19:44:48.243+00	2026-06-16 16:55:47.620344+00	\N
\.


--
-- Data for Name: tutor_alumno; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.tutor_alumno (tutor_alumno_id, tutor_id, alumno_id, tipo_relacion, es_responsable_financiero, puede_recoger, recibe_notificaciones, activo, creado_en, actualizado_en, eliminado_en) FROM stdin;
1	1	1	padre	t	t	t	t	2026-06-12 05:56:10.675132+00	2026-06-12 05:56:10.675132+00	\N
2	1	2	padre	t	t	t	t	2026-06-12 05:56:10.675132+00	2026-06-12 05:56:10.675132+00	\N
3	2	1	madre	f	t	t	t	2026-06-12 05:56:10.675132+00	2026-06-12 05:56:10.675132+00	\N
4	2	2	madre	f	t	t	t	2026-06-12 05:56:10.675132+00	2026-06-12 05:56:10.675132+00	\N
5	3	3	madre	t	t	t	t	2026-06-12 05:56:10.675132+00	2026-06-12 05:56:10.675132+00	\N
6	3	4	madre	t	t	t	t	2026-06-12 05:56:10.675132+00	2026-06-12 05:56:10.675132+00	\N
7	4	5	padre	t	t	t	t	2026-06-12 05:56:10.675132+00	2026-06-12 05:56:10.675132+00	\N
8	5	6	madre	t	t	t	t	2026-06-12 05:56:10.675132+00	2026-06-12 05:56:10.675132+00	\N
9	5	7	madre	t	t	t	t	2026-06-12 05:56:10.675132+00	2026-06-12 05:56:10.675132+00	\N
10	5	8	madre	t	t	t	t	2026-06-12 05:56:10.675132+00	2026-06-12 05:56:10.675132+00	\N
11	6	9	padre	t	t	t	t	2026-06-12 05:56:10.675132+00	2026-06-12 05:56:10.675132+00	\N
12	6	10	padre	t	t	t	t	2026-06-12 05:56:10.675132+00	2026-06-12 05:56:10.675132+00	\N
13	7	11	tutor	t	t	t	t	2026-06-14 18:44:45.69+00	2026-06-14 18:44:45.69+00	\N
14	8	12	tutor	t	t	t	t	2026-06-14 18:44:45.733+00	2026-06-14 18:44:45.733+00	\N
15	9	13	tutor	t	t	t	t	2026-06-14 18:44:45.761+00	2026-06-14 18:44:45.761+00	\N
16	10	14	tutor	t	t	t	t	2026-06-14 18:44:45.78+00	2026-06-14 18:44:45.78+00	\N
17	11	15	tutor	t	t	t	t	2026-06-14 18:44:45.798+00	2026-06-14 18:44:45.798+00	\N
18	12	16	tutor	t	t	t	t	2026-06-14 18:44:45.826+00	2026-06-14 18:44:45.826+00	\N
19	13	17	tutor	t	t	t	t	2026-06-14 18:44:45.845+00	2026-06-14 18:44:45.845+00	\N
20	14	18	tutor	t	t	t	t	2026-06-14 18:44:45.865+00	2026-06-14 18:44:45.865+00	\N
21	15	12	tutor	t	t	t	t	2026-06-15 19:44:48.151+00	2026-06-15 19:44:48.151+00	\N
22	16	13	tutor	t	t	t	t	2026-06-15 19:44:48.233+00	2026-06-15 19:44:48.233+00	\N
23	17	14	tutor	t	t	t	t	2026-06-15 19:44:48.261+00	2026-06-15 19:44:48.261+00	\N
24	18	15	tutor	t	t	t	t	2026-06-15 19:44:48.279+00	2026-06-15 19:44:48.279+00	\N
25	19	16	tutor	t	t	t	t	2026-06-15 19:44:48.324+00	2026-06-15 19:44:48.324+00	\N
26	20	17	tutor	t	t	t	t	2026-06-15 19:44:48.372+00	2026-06-15 19:44:48.372+00	\N
27	21	18	tutor	t	t	t	t	2026-06-15 19:44:48.417+00	2026-06-15 19:44:48.417+00	\N
28	22	20	tutor	t	t	t	t	2026-06-15 20:51:50.062+00	2026-06-15 20:51:50.062+00	\N
29	23	21	tutor	t	t	t	t	2026-06-15 20:52:07.949+00	2026-06-15 20:52:07.949+00	\N
30	24	22	tutor	t	t	t	t	2026-06-15 20:52:07.979+00	2026-06-15 20:52:07.979+00	\N
31	25	23	tutor	t	t	t	t	2026-06-15 20:52:45.687+00	2026-06-15 20:52:45.687+00	\N
32	26	24	tutor	t	t	t	t	2026-06-15 20:52:45.721+00	2026-06-15 20:52:45.721+00	\N
33	27	25	tutor	t	t	t	t	2026-06-15 20:52:45.739+00	2026-06-15 20:52:45.739+00	\N
34	28	26	tutor	t	t	t	t	2026-06-15 20:52:45.764+00	2026-06-15 20:52:45.764+00	\N
35	29	27	tutor	t	t	t	t	2026-06-15 20:52:45.785+00	2026-06-15 20:52:45.785+00	\N
36	30	28	tutor	t	t	t	t	2026-06-15 20:52:45.806+00	2026-06-15 20:52:45.806+00	\N
37	31	29	tutor	t	t	t	t	2026-06-15 20:52:45.827+00	2026-06-15 20:52:45.827+00	\N
38	32	30	tutor	t	t	t	t	2026-06-15 20:52:45.843+00	2026-06-15 20:52:45.843+00	\N
39	33	31	tutor	t	t	t	t	2026-06-15 20:52:45.865+00	2026-06-15 20:52:45.865+00	\N
40	34	32	tutor	t	t	t	t	2026-06-15 20:52:45.889+00	2026-06-15 20:52:45.889+00	\N
41	35	33	tutor	t	t	t	t	2026-06-15 20:52:45.905+00	2026-06-15 20:52:45.905+00	\N
42	36	34	tutor	t	t	t	t	2026-06-15 20:52:45.927+00	2026-06-15 20:52:45.927+00	\N
43	37	35	tutor	t	t	t	t	2026-06-15 20:52:45.952+00	2026-06-15 20:52:45.952+00	\N
44	38	36	tutor	t	t	t	t	2026-06-15 20:52:45.981+00	2026-06-15 20:52:45.981+00	\N
45	39	37	tutor	t	t	t	t	2026-06-15 20:52:46.009+00	2026-06-15 20:52:46.009+00	\N
46	40	38	tutor	t	t	t	t	2026-06-15 20:52:46.027+00	2026-06-15 20:52:46.027+00	\N
47	41	39	tutor	t	t	t	t	2026-06-15 20:52:46.046+00	2026-06-15 20:52:46.046+00	\N
48	42	40	tutor	t	t	t	t	2026-06-15 20:52:46.067+00	2026-06-15 20:52:46.067+00	\N
49	43	41	tutor	t	t	t	t	2026-06-15 20:52:46.09+00	2026-06-15 20:52:46.09+00	\N
50	44	42	tutor	t	t	t	t	2026-06-15 20:52:46.107+00	2026-06-15 20:52:46.107+00	\N
51	45	43	tutor	t	t	t	t	2026-06-15 20:52:46.128+00	2026-06-15 20:52:46.128+00	\N
52	46	44	tutor	t	t	t	t	2026-06-15 20:52:46.175+00	2026-06-15 20:52:46.175+00	\N
53	47	45	tutor	t	t	t	t	2026-06-15 20:52:46.197+00	2026-06-15 20:52:46.197+00	\N
54	48	46	tutor	t	t	t	t	2026-06-15 20:52:46.218+00	2026-06-15 20:52:46.218+00	\N
55	49	47	tutor	t	t	t	t	2026-06-15 20:52:46.235+00	2026-06-15 20:52:46.235+00	\N
56	50	48	tutor	t	t	t	t	2026-06-15 20:52:46.254+00	2026-06-15 20:52:46.254+00	\N
57	51	49	tutor	t	t	t	t	2026-06-15 20:52:46.273+00	2026-06-15 20:52:46.273+00	\N
58	52	50	tutor	t	t	t	t	2026-06-15 20:52:46.296+00	2026-06-15 20:52:46.296+00	\N
59	53	51	tutor	t	t	t	t	2026-06-15 20:52:46.314+00	2026-06-15 20:52:46.314+00	\N
60	54	52	tutor	t	t	t	t	2026-06-15 20:52:46.332+00	2026-06-15 20:52:46.332+00	\N
61	55	53	tutor	t	t	t	t	2026-06-15 20:52:46.35+00	2026-06-15 20:52:46.35+00	\N
62	56	54	tutor	t	t	t	t	2026-06-15 20:52:46.37+00	2026-06-15 20:52:46.37+00	\N
63	57	55	tutor	t	t	t	t	2026-06-15 20:52:46.39+00	2026-06-15 20:52:46.39+00	\N
64	58	56	tutor	t	t	t	t	2026-06-15 20:52:46.411+00	2026-06-15 20:52:46.411+00	\N
65	59	57	tutor	t	t	t	t	2026-06-15 20:52:46.432+00	2026-06-15 20:52:46.432+00	\N
66	60	58	tutor	t	t	t	t	2026-06-15 20:52:46.446+00	2026-06-15 20:52:46.446+00	\N
67	61	59	tutor	t	t	t	t	2026-06-15 20:52:46.466+00	2026-06-15 20:52:46.466+00	\N
68	62	60	tutor	t	t	t	t	2026-06-15 20:52:46.489+00	2026-06-15 20:52:46.489+00	\N
69	63	61	tutor	t	t	t	t	2026-06-15 20:52:46.504+00	2026-06-15 20:52:46.504+00	\N
70	64	62	tutor	t	t	t	t	2026-06-15 20:52:46.523+00	2026-06-15 20:52:46.523+00	\N
71	65	63	tutor	t	t	t	t	2026-06-15 20:52:46.544+00	2026-06-15 20:52:46.544+00	\N
72	66	64	tutor	t	t	t	t	2026-06-15 20:52:46.561+00	2026-06-15 20:52:46.561+00	\N
73	67	65	tutor	t	t	t	t	2026-06-15 20:52:46.579+00	2026-06-15 20:52:46.579+00	\N
74	68	66	tutor	t	t	t	t	2026-06-15 20:52:46.597+00	2026-06-15 20:52:46.597+00	\N
75	69	67	tutor	t	t	t	t	2026-06-15 20:52:46.617+00	2026-06-15 20:52:46.617+00	\N
76	70	68	tutor	t	t	t	t	2026-06-15 20:52:46.632+00	2026-06-15 20:52:46.632+00	\N
77	71	69	tutor	t	t	t	t	2026-06-15 20:52:46.649+00	2026-06-15 20:52:46.649+00	\N
78	72	70	tutor	t	t	t	t	2026-06-15 20:52:46.668+00	2026-06-15 20:52:46.668+00	\N
79	73	71	tutor	t	t	t	t	2026-06-15 20:52:46.697+00	2026-06-15 20:52:46.697+00	\N
80	74	72	tutor	t	t	t	t	2026-06-15 20:52:46.714+00	2026-06-15 20:52:46.714+00	\N
81	75	73	tutor	t	t	t	t	2026-06-15 20:52:46.735+00	2026-06-15 20:52:46.735+00	\N
82	76	74	tutor	t	t	t	t	2026-06-15 20:52:46.76+00	2026-06-15 20:52:46.76+00	\N
83	77	75	tutor	t	t	t	t	2026-06-15 20:52:46.776+00	2026-06-15 20:52:46.776+00	\N
84	78	76	tutor	t	t	t	t	2026-06-15 20:52:46.794+00	2026-06-15 20:52:46.794+00	\N
85	79	77	tutor	t	t	t	t	2026-06-15 20:52:46.815+00	2026-06-15 20:52:46.815+00	\N
86	80	78	tutor	t	t	t	t	2026-06-15 20:52:46.832+00	2026-06-15 20:52:46.832+00	\N
87	81	79	tutor	t	t	t	t	2026-06-15 20:52:46.85+00	2026-06-15 20:52:46.85+00	\N
88	82	80	tutor	t	t	t	t	2026-06-15 20:52:46.87+00	2026-06-15 20:52:46.87+00	\N
89	83	81	tutor	t	t	t	t	2026-06-15 20:52:46.889+00	2026-06-15 20:52:46.889+00	\N
90	84	82	tutor	t	t	t	t	2026-06-15 20:52:46.909+00	2026-06-15 20:52:46.909+00	\N
91	85	83	tutor	t	t	t	t	2026-06-15 20:52:46.925+00	2026-06-15 20:52:46.925+00	\N
92	86	84	tutor	t	t	t	t	2026-06-15 20:52:46.946+00	2026-06-15 20:52:46.946+00	\N
93	87	85	tutor	t	t	t	t	2026-06-15 20:52:46.968+00	2026-06-15 20:52:46.968+00	\N
94	88	86	tutor	t	t	t	t	2026-06-15 20:52:46.986+00	2026-06-15 20:52:46.986+00	\N
95	89	87	tutor	t	t	t	t	2026-06-15 20:52:47.005+00	2026-06-15 20:52:47.005+00	\N
96	90	88	tutor	t	t	t	t	2026-06-15 20:52:47.021+00	2026-06-15 20:52:47.021+00	\N
97	91	89	tutor	t	t	t	t	2026-06-15 20:52:47.043+00	2026-06-15 20:52:47.043+00	\N
98	92	90	tutor	t	t	t	t	2026-06-15 20:52:47.063+00	2026-06-15 20:52:47.063+00	\N
99	93	91	tutor	t	t	t	t	2026-06-15 20:52:47.082+00	2026-06-15 20:52:47.082+00	\N
100	94	92	tutor	t	t	t	t	2026-06-15 20:52:47.099+00	2026-06-15 20:52:47.099+00	\N
101	95	93	tutor	t	t	t	t	2026-06-15 20:52:47.121+00	2026-06-15 20:52:47.121+00	\N
102	96	94	tutor	t	t	t	t	2026-06-15 20:52:47.141+00	2026-06-15 20:52:47.141+00	\N
103	97	95	tutor	t	t	t	t	2026-06-15 20:52:47.16+00	2026-06-15 20:52:47.16+00	\N
104	98	96	tutor	t	t	t	t	2026-06-15 20:52:47.179+00	2026-06-15 20:52:47.179+00	\N
105	99	97	tutor	t	t	t	t	2026-06-15 20:52:47.2+00	2026-06-15 20:52:47.2+00	\N
106	100	98	tutor	t	t	t	t	2026-06-15 20:52:47.222+00	2026-06-15 20:52:47.222+00	\N
107	101	99	tutor	t	t	t	t	2026-06-15 20:52:47.239+00	2026-06-15 20:52:47.239+00	\N
108	102	100	tutor	t	t	t	t	2026-06-15 20:52:47.256+00	2026-06-15 20:52:47.256+00	\N
109	103	101	tutor	t	t	t	t	2026-06-15 20:52:47.275+00	2026-06-15 20:52:47.275+00	\N
110	104	102	tutor	t	t	t	t	2026-06-15 20:52:47.301+00	2026-06-15 20:52:47.301+00	\N
111	105	103	tutor	t	t	t	t	2026-06-15 20:52:47.323+00	2026-06-15 20:52:47.323+00	\N
112	106	104	tutor	t	t	t	t	2026-06-15 20:53:07.917+00	2026-06-15 20:53:07.917+00	\N
113	107	105	tutor	t	t	t	t	2026-06-15 20:53:07.949+00	2026-06-15 20:53:07.949+00	\N
114	108	106	tutor	t	t	t	t	2026-06-15 20:53:07.967+00	2026-06-15 20:53:07.967+00	\N
115	109	107	tutor	t	t	t	t	2026-06-15 20:53:07.988+00	2026-06-15 20:53:07.988+00	\N
116	110	108	tutor	t	t	t	t	2026-06-15 20:53:08.009+00	2026-06-15 20:53:08.009+00	\N
117	111	109	tutor	t	t	t	t	2026-06-15 20:53:08.032+00	2026-06-15 20:53:08.032+00	\N
118	112	110	tutor	t	t	t	t	2026-06-15 20:53:08.053+00	2026-06-15 20:53:08.053+00	\N
119	113	111	tutor	t	t	t	t	2026-06-15 20:53:08.104+00	2026-06-15 20:53:08.104+00	\N
120	114	112	tutor	t	t	t	t	2026-06-15 20:53:08.144+00	2026-06-15 20:53:08.144+00	\N
121	115	113	tutor	t	t	t	t	2026-06-15 20:53:08.181+00	2026-06-15 20:53:08.181+00	\N
122	116	114	tutor	t	t	t	t	2026-06-15 20:53:08.204+00	2026-06-15 20:53:08.204+00	\N
123	117	115	tutor	t	t	t	t	2026-06-15 20:53:08.237+00	2026-06-15 20:53:08.237+00	\N
124	118	116	tutor	t	t	t	t	2026-06-15 20:53:08.262+00	2026-06-15 20:53:08.262+00	\N
125	119	117	tutor	t	t	t	t	2026-06-15 20:53:08.277+00	2026-06-15 20:53:08.277+00	\N
126	120	118	tutor	t	t	t	t	2026-06-15 20:53:08.298+00	2026-06-15 20:53:08.298+00	\N
127	121	119	tutor	t	t	t	t	2026-06-15 20:53:08.32+00	2026-06-15 20:53:08.32+00	\N
128	122	120	tutor	t	t	t	t	2026-06-15 20:53:08.341+00	2026-06-15 20:53:08.341+00	\N
129	123	121	tutor	t	t	t	t	2026-06-15 20:53:08.478+00	2026-06-15 20:53:08.478+00	\N
130	124	122	tutor	t	t	t	t	2026-06-15 20:53:08.498+00	2026-06-15 20:53:08.498+00	\N
131	125	123	tutor	t	t	t	t	2026-06-15 20:53:08.523+00	2026-06-15 20:53:08.523+00	\N
132	126	124	tutor	t	t	t	t	2026-06-15 20:53:08.539+00	2026-06-15 20:53:08.539+00	\N
133	127	125	tutor	t	t	t	t	2026-06-15 20:53:08.563+00	2026-06-15 20:53:08.563+00	\N
134	128	126	tutor	t	t	t	t	2026-06-15 20:53:08.594+00	2026-06-15 20:53:08.594+00	\N
135	129	127	tutor	t	t	t	t	2026-06-15 20:53:08.616+00	2026-06-15 20:53:08.616+00	\N
136	130	128	tutor	t	t	t	t	2026-06-15 20:53:08.634+00	2026-06-15 20:53:08.634+00	\N
137	131	129	tutor	t	t	t	t	2026-06-15 20:53:08.654+00	2026-06-15 20:53:08.654+00	\N
138	132	130	tutor	t	t	t	t	2026-06-15 20:53:08.673+00	2026-06-15 20:53:08.673+00	\N
139	133	131	tutor	t	t	t	t	2026-06-15 20:53:08.691+00	2026-06-15 20:53:08.691+00	\N
140	134	132	tutor	t	t	t	t	2026-06-15 20:53:08.714+00	2026-06-15 20:53:08.714+00	\N
141	135	133	tutor	t	t	t	t	2026-06-15 20:53:08.732+00	2026-06-15 20:53:08.732+00	\N
142	136	134	tutor	t	t	t	t	2026-06-15 20:53:08.75+00	2026-06-15 20:53:08.75+00	\N
143	137	135	tutor	t	t	t	t	2026-06-15 20:53:08.771+00	2026-06-15 20:53:08.771+00	\N
144	138	136	tutor	t	t	t	t	2026-06-15 20:53:08.793+00	2026-06-15 20:53:08.793+00	\N
145	139	137	tutor	t	t	t	t	2026-06-15 20:53:08.818+00	2026-06-15 20:53:08.818+00	\N
146	140	138	tutor	t	t	t	t	2026-06-15 20:53:08.838+00	2026-06-15 20:53:08.838+00	\N
147	141	139	tutor	t	t	t	t	2026-06-15 20:53:08.857+00	2026-06-15 20:53:08.857+00	\N
148	142	140	tutor	t	t	t	t	2026-06-15 20:53:08.879+00	2026-06-15 20:53:08.879+00	\N
149	143	141	tutor	t	t	t	t	2026-06-15 20:53:08.9+00	2026-06-15 20:53:08.9+00	\N
150	144	142	tutor	t	t	t	t	2026-06-15 20:53:08.917+00	2026-06-15 20:53:08.917+00	\N
151	145	143	tutor	t	t	t	t	2026-06-15 20:53:08.941+00	2026-06-15 20:53:08.941+00	\N
152	146	144	tutor	t	t	t	t	2026-06-15 20:53:08.965+00	2026-06-15 20:53:08.965+00	\N
153	147	145	tutor	t	t	t	t	2026-06-15 20:53:08.989+00	2026-06-15 20:53:08.989+00	\N
154	148	146	tutor	t	t	t	t	2026-06-15 20:53:09.011+00	2026-06-15 20:53:09.011+00	\N
155	149	147	tutor	t	t	t	t	2026-06-15 20:53:09.034+00	2026-06-15 20:53:09.034+00	\N
156	150	148	tutor	t	t	t	t	2026-06-15 20:53:09.054+00	2026-06-15 20:53:09.054+00	\N
157	151	149	tutor	t	t	t	t	2026-06-15 20:53:09.083+00	2026-06-15 20:53:09.083+00	\N
158	152	150	tutor	t	t	t	t	2026-06-15 20:53:09.112+00	2026-06-15 20:53:09.112+00	\N
159	153	151	tutor	t	t	t	t	2026-06-15 20:53:09.141+00	2026-06-15 20:53:09.141+00	\N
160	154	152	tutor	t	t	t	t	2026-06-15 20:53:09.166+00	2026-06-15 20:53:09.166+00	\N
161	155	153	tutor	t	t	t	t	2026-06-15 20:53:09.195+00	2026-06-15 20:53:09.195+00	\N
162	156	154	tutor	t	t	t	t	2026-06-15 20:53:09.216+00	2026-06-15 20:53:09.216+00	\N
163	157	155	tutor	t	t	t	t	2026-06-15 20:53:09.239+00	2026-06-15 20:53:09.239+00	\N
164	158	156	tutor	t	t	t	t	2026-06-15 20:53:09.26+00	2026-06-15 20:53:09.26+00	\N
165	159	157	tutor	t	t	t	t	2026-06-15 20:53:09.282+00	2026-06-15 20:53:09.282+00	\N
166	160	158	tutor	t	t	t	t	2026-06-15 20:53:09.31+00	2026-06-15 20:53:09.31+00	\N
167	161	159	tutor	t	t	t	t	2026-06-15 20:53:09.328+00	2026-06-15 20:53:09.328+00	\N
168	162	160	tutor	t	t	t	t	2026-06-15 20:53:09.353+00	2026-06-15 20:53:09.353+00	\N
169	163	161	tutor	t	t	t	t	2026-06-15 20:53:09.377+00	2026-06-15 20:53:09.377+00	\N
170	164	162	tutor	t	t	t	t	2026-06-15 20:53:09.4+00	2026-06-15 20:53:09.4+00	\N
171	165	163	tutor	t	t	t	t	2026-06-15 20:53:09.422+00	2026-06-15 20:53:09.422+00	\N
172	166	164	tutor	t	t	t	t	2026-06-15 20:53:09.45+00	2026-06-15 20:53:09.45+00	\N
173	167	165	tutor	t	t	t	t	2026-06-15 20:53:09.472+00	2026-06-15 20:53:09.472+00	\N
174	168	166	tutor	t	t	t	t	2026-06-15 20:53:09.493+00	2026-06-15 20:53:09.493+00	\N
175	169	167	tutor	t	t	t	t	2026-06-15 20:53:09.517+00	2026-06-15 20:53:09.517+00	\N
176	170	168	tutor	t	t	t	t	2026-06-15 20:53:09.54+00	2026-06-15 20:53:09.54+00	\N
177	171	169	tutor	t	t	t	t	2026-06-15 20:53:09.562+00	2026-06-15 20:53:09.562+00	\N
178	172	170	tutor	t	t	t	t	2026-06-15 20:53:09.585+00	2026-06-15 20:53:09.585+00	\N
179	173	171	tutor	t	t	t	t	2026-06-15 20:53:09.61+00	2026-06-15 20:53:09.61+00	\N
180	174	172	tutor	t	t	t	t	2026-06-15 20:53:09.63+00	2026-06-15 20:53:09.63+00	\N
181	175	173	tutor	t	t	t	t	2026-06-15 20:53:09.649+00	2026-06-15 20:53:09.649+00	\N
182	176	174	tutor	t	t	t	t	2026-06-15 20:53:09.673+00	2026-06-15 20:53:09.673+00	\N
183	177	175	tutor	t	t	t	t	2026-06-15 20:53:09.699+00	2026-06-15 20:53:09.699+00	\N
184	178	176	tutor	t	t	t	t	2026-06-15 20:53:09.723+00	2026-06-15 20:53:09.723+00	\N
185	179	177	tutor	t	t	t	t	2026-06-15 20:53:09.745+00	2026-06-15 20:53:09.745+00	\N
186	180	178	tutor	t	t	t	t	2026-06-15 20:53:09.764+00	2026-06-15 20:53:09.764+00	\N
187	181	179	tutor	t	t	t	t	2026-06-15 20:53:09.787+00	2026-06-15 20:53:09.787+00	\N
188	182	180	tutor	t	t	t	t	2026-06-15 20:53:09.807+00	2026-06-15 20:53:09.807+00	\N
189	183	181	tutor	t	t	t	t	2026-06-15 20:53:09.827+00	2026-06-15 20:53:09.827+00	\N
190	184	182	tutor	t	t	t	t	2026-06-15 20:53:09.853+00	2026-06-15 20:53:09.853+00	\N
191	185	183	tutor	t	t	t	t	2026-06-15 20:53:09.878+00	2026-06-15 20:53:09.878+00	\N
192	186	184	tutor	t	t	t	t	2026-06-15 20:53:09.897+00	2026-06-15 20:53:09.897+00	\N
193	187	185	tutor	t	t	t	t	2026-06-15 20:53:09.918+00	2026-06-15 20:53:09.918+00	\N
194	188	186	tutor	t	t	t	t	2026-06-15 20:53:09.944+00	2026-06-15 20:53:09.944+00	\N
195	189	187	tutor	t	t	t	t	2026-06-15 20:53:09.961+00	2026-06-15 20:53:09.961+00	\N
196	190	188	tutor	t	t	t	t	2026-06-15 20:53:09.993+00	2026-06-15 20:53:09.993+00	\N
197	191	189	tutor	t	t	t	t	2026-06-15 20:53:10.017+00	2026-06-15 20:53:10.017+00	\N
198	192	190	tutor	t	t	t	t	2026-06-15 20:53:10.036+00	2026-06-15 20:53:10.036+00	\N
199	193	191	tutor	t	t	t	t	2026-06-15 20:53:10.06+00	2026-06-15 20:53:10.06+00	\N
200	194	192	tutor	t	t	t	t	2026-06-15 20:53:10.083+00	2026-06-15 20:53:10.083+00	\N
201	195	193	tutor	t	t	t	t	2026-06-15 20:53:10.104+00	2026-06-15 20:53:10.104+00	\N
202	196	194	tutor	t	t	t	t	2026-06-15 20:53:10.126+00	2026-06-15 20:53:10.126+00	\N
203	197	195	tutor	t	t	t	t	2026-06-15 20:53:10.149+00	2026-06-15 20:53:10.149+00	\N
204	198	196	tutor	t	t	t	t	2026-06-15 20:53:10.166+00	2026-06-15 20:53:10.166+00	\N
205	199	197	tutor	t	t	t	t	2026-06-15 20:53:10.187+00	2026-06-15 20:53:10.187+00	\N
206	200	198	tutor	t	t	t	t	2026-06-15 20:53:10.212+00	2026-06-15 20:53:10.212+00	\N
207	201	199	tutor	t	t	t	t	2026-06-15 20:53:10.229+00	2026-06-15 20:53:10.229+00	\N
208	202	200	tutor	t	t	t	t	2026-06-15 20:53:10.252+00	2026-06-15 20:53:10.252+00	\N
209	203	201	tutor	t	t	t	t	2026-06-15 20:53:10.271+00	2026-06-15 20:53:10.271+00	\N
210	204	202	tutor	t	t	t	t	2026-06-15 20:53:10.292+00	2026-06-15 20:53:10.292+00	\N
211	205	203	tutor	t	t	t	t	2026-06-15 20:53:10.316+00	2026-06-15 20:53:10.316+00	\N
212	206	204	tutor	t	t	t	t	2026-06-15 20:53:10.332+00	2026-06-15 20:53:10.332+00	\N
213	207	205	tutor	t	t	t	t	2026-06-15 20:53:10.359+00	2026-06-15 20:53:10.359+00	\N
214	208	206	tutor	t	t	t	t	2026-06-15 20:53:10.383+00	2026-06-15 20:53:10.383+00	\N
215	209	207	tutor	t	t	t	t	2026-06-15 20:53:10.404+00	2026-06-15 20:53:10.404+00	\N
216	210	208	tutor	t	t	t	t	2026-06-15 20:53:10.429+00	2026-06-15 20:53:10.429+00	\N
217	211	209	tutor	t	t	t	t	2026-06-15 20:53:10.463+00	2026-06-15 20:53:10.463+00	\N
218	212	210	tutor	t	t	t	t	2026-06-15 20:53:10.501+00	2026-06-15 20:53:10.501+00	\N
219	213	211	tutor	t	t	t	t	2026-06-15 20:53:10.533+00	2026-06-15 20:53:10.533+00	\N
220	214	212	tutor	t	t	t	t	2026-06-15 20:53:10.556+00	2026-06-15 20:53:10.556+00	\N
221	215	213	tutor	t	t	t	t	2026-06-15 20:53:10.578+00	2026-06-15 20:53:10.578+00	\N
222	216	214	tutor	t	t	t	t	2026-06-15 20:53:10.603+00	2026-06-15 20:53:10.603+00	\N
223	217	215	tutor	t	t	t	t	2026-06-15 20:53:10.627+00	2026-06-15 20:53:10.627+00	\N
224	218	216	tutor	t	t	t	t	2026-06-15 20:53:10.649+00	2026-06-15 20:53:10.649+00	\N
225	219	217	tutor	t	t	t	t	2026-06-15 20:53:10.675+00	2026-06-15 20:53:10.675+00	\N
226	220	218	tutor	t	t	t	t	2026-06-15 20:53:10.694+00	2026-06-15 20:53:10.694+00	\N
227	221	219	tutor	t	t	t	t	2026-06-15 20:53:10.717+00	2026-06-15 20:53:10.717+00	\N
228	222	220	tutor	t	t	t	t	2026-06-15 20:53:10.733+00	2026-06-15 20:53:10.733+00	\N
229	223	221	tutor	t	t	t	t	2026-06-15 20:53:10.761+00	2026-06-15 20:53:10.761+00	\N
230	224	222	tutor	t	t	t	t	2026-06-15 20:53:10.782+00	2026-06-15 20:53:10.782+00	\N
231	225	223	tutor	t	t	t	t	2026-06-15 20:53:10.802+00	2026-06-15 20:53:10.802+00	\N
232	226	224	tutor	t	t	t	t	2026-06-15 20:53:10.825+00	2026-06-15 20:53:10.825+00	\N
233	227	225	tutor	t	t	t	t	2026-06-15 20:53:10.848+00	2026-06-15 20:53:10.848+00	\N
234	228	226	tutor	t	t	t	t	2026-06-15 20:53:10.873+00	2026-06-15 20:53:10.873+00	\N
235	229	227	tutor	t	t	t	t	2026-06-15 20:53:10.894+00	2026-06-15 20:53:10.894+00	\N
236	230	228	tutor	t	t	t	t	2026-06-15 20:53:10.916+00	2026-06-15 20:53:10.916+00	\N
237	231	229	tutor	t	t	t	t	2026-06-15 20:53:10.942+00	2026-06-15 20:53:10.942+00	\N
238	232	230	tutor	t	t	t	t	2026-06-15 20:53:10.964+00	2026-06-15 20:53:10.964+00	\N
239	233	231	tutor	t	t	t	t	2026-06-15 20:53:10.984+00	2026-06-15 20:53:10.984+00	\N
240	234	232	tutor	t	t	t	t	2026-06-15 20:53:11.007+00	2026-06-15 20:53:11.007+00	\N
241	235	233	tutor	t	t	t	t	2026-06-15 20:53:11.029+00	2026-06-15 20:53:11.029+00	\N
242	10	234	tutor	f	t	t	t	2026-06-16 11:37:21.82+00	2026-06-16 11:37:21.82+00	\N
243	36	236	tutor	t	t	t	t	2026-06-16 12:01:13.697+00	2026-06-16 12:01:13.697+00	\N
\.


--
-- Data for Name: usuario; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.usuario (usuario_id, nombre_usuario, nombre_completo, correo, telefono, password_hash, activo, intentos_fallidos, bloqueado_hasta, ultimo_acceso, debe_cambiar_pwd, creado_en, actualizado_en, eliminado_en) FROM stdin;
2	maria.dolores	María Dolores Pérez Rangel	direccion@sandiego.edu	9211112234	$2a$10$JRLQ90pBWRUM4jFN8e2oTevQohBi9fatfIKbz2OeWajoZGlns7NMG	t	0	\N	\N	t	2026-06-12 05:56:10.412081+00	2026-06-12 05:56:10.412081+00	\N
3	laura.rios	Laura Ríos Méndez	laura.rios@sandiego.edu	9211112235	$2a$12$USLekRhKX5T4hKUVe2qGue.QB./1sb0rRjYv8zZ5JHsQHxRy2GXpm	t	0	\N	2026-06-16 08:50:56.795+00	t	2026-06-12 05:56:10.412081+00	2026-06-16 08:50:56.80245+00	\N
19	harry.ga	Harry Hernandez	\N	\N	$2a$10$/O26qR332sVksDPdTQNL1OvPBlpn/RH6xwfXitE6ICNdb/CYDLV.q	t	0	\N	2026-06-16 13:37:56.901+00	f	2026-06-16 09:11:54.679+00	2026-06-16 13:37:56.906103+00	\N
8	gestor.admin	Gestor Administrativo	\N	\N	$2a$12$USLekRhKX5T4hKUVe2qGue.QB./1sb0rRjYv8zZ5JHsQHxRy2GXpm	t	0	\N	2026-06-16 13:38:43.728+00	f	2026-06-14 18:44:45.42+00	2026-06-16 13:38:43.72986+00	\N
11	harry.adm	jose manuel	\N	\N	$2a$10$GuMDvmN.8cQTA6Qu7UlosOCuSnsJIO9pNwGEAxTpD0nI5/sw/oXbS	t	0	\N	2026-06-16 13:40:30.914+00	t	2026-06-15 09:34:07.899+00	2026-06-16 13:40:30.917489+00	\N
5	patricia.nunez	Patricia Núñez García	patricia.nunez@sandiego.edu	9211112237	$2a$10$vodqWB/DKRWv5QLWFisHW.37cOZALm/OyRQPKi62dfOW1BVb0SGPq	t	0	\N	\N	t	2026-06-12 05:56:10.412081+00	2026-06-16 09:22:02.046296+00	\N
17	HARRY	Jose Manuel Fabian Hernandez	\N	\N	$2a$10$KOwUAfwygUD3qhMwO6Tqw.XpvWB4GvHo2NQ/wFYiEosi7RfO3lF7K	t	0	\N	2026-06-16 11:04:26.078+00	t	2026-06-16 00:23:48.339+00	2026-06-16 11:04:26.085877+00	\N
23	morales.a	morales	\N	\N	$2a$10$rSOBuij9i1UT6j0W8xdh2uB1NqrGlq9Xbd8.8oEu5zPhauIbua0rm	t	0	\N	2026-06-16 16:22:17.135+00	t	2026-06-16 16:19:18.528+00	2026-06-16 16:22:17.143886+00	\N
21	jess	jessi admin	\N	\N	$2a$10$wvvjMLq6HI0MYwBnqta27OwNZXZAAalItGmLykZfdlM72teY7zNRe	t	0	\N	2026-06-16 21:45:41.294+00	t	2026-06-16 10:53:00.766+00	2026-06-16 21:45:41.297322+00	\N
18	Admin.c	Admin	\N	\N	$2a$10$vOUf8BtRJl7CZL8GzgQrz.W.3XucWunEYkyIcDIei937gTuH.gtQC	t	0	\N	\N	f	2026-06-16 08:34:16.39+00	2026-06-16 08:34:16.39+00	\N
4	mario.sanchez	Mario Sánchez Trejo	mario.sanchez@sandiego.edu	9211112236	$2a$12$USLekRhKX5T4hKUVe2qGue.QB./1sb0rRjYv8zZ5JHsQHxRy2GXpm	t	0	\N	2026-06-16 21:53:32.235+00	t	2026-06-12 05:56:10.412081+00	2026-06-16 21:53:32.239008+00	\N
20	jessi	nuevoadmin	\N	\N	$2a$10$.9M.3yJaiyX1pMqGy5qyq.xpboZDw3ZkSUOu5gKqoBIVspEYk/VIG	t	0	\N	2026-06-16 09:23:40.413+00	f	2026-06-16 09:18:53.285+00	2026-06-16 09:51:00.023076+00	\N
1	elizabeth.mendoza	Elizabeth Mendoza Castro	elizabeth@sandiego.edu	9211112233	$2a$10$l5dQqSRPy.gUJxf2WQNtq.7.0weUrX1TqOE3hDNWrOsxdc656iUpG	t	0	\N	2026-06-16 21:55:49.115+00	t	2026-06-12 05:56:10.412081+00	2026-06-16 21:55:49.121283+00	\N
7	maria.directora	María Dolores Vega	maria.dolores@colegiosandiego.edu.mx	\N	$2a$12$USLekRhKX5T4hKUVe2qGue.QB./1sb0rRjYv8zZ5JHsQHxRy2GXpm	t	0	\N	2026-06-16 22:04:55.314+00	f	2026-06-14 18:44:45.41+00	2026-06-16 22:04:55.318715+00	\N
6	elizabeth.admin	Elizabeth Mendoza	elizabeth.mendoza@colegiosandiego.edu.mx	\N	$2a$12$USLekRhKX5T4hKUVe2qGue.QB./1sb0rRjYv8zZ5JHsQHxRy2GXpm	t	0	\N	2026-06-16 22:05:17.093+00	f	2026-06-14 18:44:45.373+00	2026-06-16 22:05:17.097436+00	\N
22	jessy	jessica gestor	\N	\N	$2a$10$rcvk4DR9.GkwhzkTLs7L3ezHi20Gk4p5bNJCLwBIhtbOrJmMvwane	t	0	\N	2026-06-16 13:11:42.875+00	f	2026-06-16 13:07:38.047+00	2026-06-16 13:11:42.877694+00	\N
\.


--
-- Data for Name: usuario_permiso_modulo; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.usuario_permiso_modulo (permiso_id, usuario_id, modulo, nivel, activo, creado_en, actualizado_en) FROM stdin;
11	5	tutores	lectura	t	2026-06-16 09:22:13.298+00	2026-06-16 09:22:13.298+00
12	5	calificaciones	escritura	t	2026-06-16 09:22:13.304+00	2026-06-16 09:22:13.304+00
181	4	alumnos	NINGUNO	t	2026-06-16 16:34:49.557+00	2026-06-16 19:36:23.626+00
182	4	tutores	lectura	t	2026-06-16 16:34:49.561+00	2026-06-16 19:36:23.632+00
183	4	pagos	escritura	t	2026-06-16 16:34:49.565+00	2026-06-16 19:36:23.635+00
184	4	becas	NINGUNO	t	2026-06-16 16:34:49.568+00	2026-06-16 19:36:23.638+00
185	4	colegiaturas	NINGUNO	t	2026-06-16 16:34:49.572+00	2026-06-16 19:36:23.642+00
186	4	calificaciones	escritura	t	2026-06-16 16:34:49.575+00	2026-06-16 19:36:23.645+00
187	4	reportes	NINGUNO	t	2026-06-16 16:34:49.578+00	2026-06-16 19:36:23.648+00
188	4	bitacora	NINGUNO	t	2026-06-16 16:34:49.58+00	2026-06-16 19:36:23.651+00
189	4	usuarios	NINGUNO	t	2026-06-16 16:34:49.582+00	2026-06-16 19:36:23.654+00
190	4	configuracion	NINGUNO	t	2026-06-16 16:34:49.584+00	2026-06-16 19:36:23.657+00
1	17	tutores	lectura	t	2026-06-16 00:23:48.378+00	2026-06-16 10:06:57.188+00
93	17	pagos	NINGUNO	t	2026-06-16 10:06:48.248+00	2026-06-16 10:06:57.191+00
94	17	becas	NINGUNO	t	2026-06-16 10:06:48.25+00	2026-06-16 10:06:57.195+00
95	17	colegiaturas	NINGUNO	t	2026-06-16 10:06:48.252+00	2026-06-16 10:06:57.2+00
2	17	calificaciones	escritura	t	2026-06-16 00:23:48.378+00	2026-06-16 10:06:57.204+00
97	17	reportes	NINGUNO	t	2026-06-16 10:06:48.256+00	2026-06-16 10:06:57.207+00
98	17	bitacora	NINGUNO	t	2026-06-16 10:06:48.259+00	2026-06-16 10:06:57.221+00
99	17	usuarios	NINGUNO	t	2026-06-16 10:06:48.261+00	2026-06-16 10:06:57.225+00
100	17	configuracion	NINGUNO	t	2026-06-16 10:06:48.264+00	2026-06-16 10:06:57.23+00
91	17	alumnos	lectura	t	2026-06-16 10:06:48.242+00	2026-06-16 10:06:57.171+00
113	22	alumnos	escritura	t	2026-06-16 13:07:38.087+00	2026-06-16 13:07:59.124+00
114	22	tutores	escritura	t	2026-06-16 13:07:38.087+00	2026-06-16 13:07:59.128+00
115	22	pagos	escritura	t	2026-06-16 13:07:38.087+00	2026-06-16 13:07:59.129+00
116	22	becas	escritura	t	2026-06-16 13:07:38.087+00	2026-06-16 13:07:59.131+00
119	22	colegiaturas	escritura	t	2026-06-16 13:07:38.087+00	2026-06-16 13:07:59.133+00
117	22	calificaciones	escritura	t	2026-06-16 13:07:38.087+00	2026-06-16 13:07:59.135+00
120	22	reportes	lectura	t	2026-06-16 13:07:38.087+00	2026-06-16 13:07:59.137+00
128	22	bitacora	NINGUNO	t	2026-06-16 13:07:59.14+00	2026-06-16 13:07:59.14+00
129	22	usuarios	NINGUNO	t	2026-06-16 13:07:59.141+00	2026-06-16 13:07:59.141+00
118	22	configuracion	escritura	t	2026-06-16 13:07:38.087+00	2026-06-16 13:07:59.142+00
3	19	alumnos	escritura	t	2026-06-16 09:11:54.709+00	2026-06-16 10:06:31.583+00
4	19	tutores	escritura	t	2026-06-16 09:11:54.709+00	2026-06-16 10:06:31.585+00
5	19	pagos	escritura	t	2026-06-16 09:11:54.709+00	2026-06-16 10:06:31.588+00
6	19	becas	escritura	t	2026-06-16 09:11:54.709+00	2026-06-16 10:06:31.59+00
9	19	colegiaturas	escritura	t	2026-06-16 09:11:54.709+00	2026-06-16 10:06:31.591+00
7	19	calificaciones	escritura	t	2026-06-16 09:11:54.709+00	2026-06-16 10:06:31.593+00
10	19	reportes	lectura	t	2026-06-16 09:11:54.709+00	2026-06-16 10:06:31.595+00
20	19	bitacora	NINGUNO	t	2026-06-16 09:30:35.989+00	2026-06-16 10:06:31.597+00
21	19	usuarios	NINGUNO	t	2026-06-16 09:30:35.993+00	2026-06-16 10:06:31.6+00
8	19	configuracion	escritura	t	2026-06-16 09:11:54.709+00	2026-06-16 10:06:31.603+00
131	21	alumnos	escritura	t	2026-06-16 16:25:12.774+00	2026-06-16 21:43:17.845+00
111	21	tutores	escritura	t	2026-06-16 10:53:00.783+00	2026-06-16 21:43:17.853+00
133	21	pagos	escritura	t	2026-06-16 16:25:12.787+00	2026-06-16 21:43:17.856+00
134	21	becas	escritura	t	2026-06-16 16:25:12.79+00	2026-06-16 21:43:17.859+00
135	21	colegiaturas	escritura	t	2026-06-16 16:25:12.793+00	2026-06-16 21:43:17.861+00
112	21	calificaciones	escritura	t	2026-06-16 10:53:00.783+00	2026-06-16 21:43:17.863+00
137	21	reportes	escritura	t	2026-06-16 16:25:12.797+00	2026-06-16 21:43:17.866+00
138	21	bitacora	escritura	t	2026-06-16 16:25:12.8+00	2026-06-16 21:43:17.868+00
139	21	usuarios	escritura	t	2026-06-16 16:25:12.803+00	2026-06-16 21:43:17.87+00
140	21	configuracion	escritura	t	2026-06-16 16:25:12.805+00	2026-06-16 21:43:17.872+00
\.


--
-- Data for Name: usuario_rol; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.usuario_rol (usuario_rol_id, usuario_id, rol_id, asignado_en, asignado_por, activo, creado_en, actualizado_en, eliminado_en) FROM stdin;
1	1	1	2026-06-12 05:56:10.624731+00	1	t	2026-06-12 05:56:10.624731+00	2026-06-12 05:56:10.624731+00	\N
2	2	2	2026-06-12 05:56:10.624731+00	1	t	2026-06-12 05:56:10.624731+00	2026-06-12 05:56:10.624731+00	\N
13	11	1	2026-06-15 09:34:07.899+00	\N	t	2026-06-15 09:34:07.899+00	2026-06-15 09:34:07.899+00	\N
7	6	1	2026-06-14 18:44:45.402+00	\N	t	2026-06-14 18:44:45.402+00	2026-06-15 19:44:47.731587+00	\N
8	7	2	2026-06-14 18:44:45.414+00	\N	t	2026-06-14 18:44:45.414+00	2026-06-15 19:44:47.751601+00	\N
9	8	3	2026-06-14 18:44:45.426+00	\N	t	2026-06-14 18:44:45.426+00	2026-06-15 19:44:47.817774+00	\N
3	3	3	2026-06-12 05:56:10.624731+00	1	t	2026-06-12 05:56:10.624731+00	2026-06-15 19:44:47.854959+00	\N
6	3	4	2026-06-12 05:56:10.624731+00	1	t	2026-06-12 05:56:10.624731+00	2026-06-15 19:44:47.883203+00	\N
5	4	4	2026-06-12 05:56:10.624731+00	1	t	2026-06-12 05:56:10.624731+00	2026-06-15 19:44:47.915054+00	\N
20	17	4	2026-06-16 00:23:48.339+00	\N	t	2026-06-16 00:23:48.339+00	2026-06-16 00:23:48.339+00	\N
21	18	1	2026-06-16 08:34:16.39+00	\N	t	2026-06-16 08:34:16.39+00	2026-06-16 08:34:16.39+00	\N
22	19	3	2026-06-16 09:11:54.679+00	\N	t	2026-06-16 09:11:54.679+00	2026-06-16 09:11:54.679+00	\N
4	5	4	2026-06-12 05:56:10.624731+00	1	t	2026-06-12 05:56:10.624731+00	2026-06-16 09:22:02.046296+00	\N
23	20	1	2026-06-16 09:18:53.285+00	\N	t	2026-06-16 09:18:53.285+00	2026-06-16 09:51:00.023076+00	\N
24	21	4	2026-06-16 10:53:00.766+00	\N	t	2026-06-16 10:53:00.766+00	2026-06-16 10:53:00.766+00	\N
25	22	3	2026-06-16 13:07:38.047+00	\N	t	2026-06-16 13:07:38.047+00	2026-06-16 13:07:46.665576+00	\N
26	23	1	2026-06-16 16:19:18.528+00	\N	t	2026-06-16 16:19:18.528+00	2026-06-16 16:19:18.528+00	\N
\.


--
-- Data for Name: ventana_inscripcion_temprana; Type: TABLE DATA; Schema: public; Owner: sae_admin
--

COPY public.ventana_inscripcion_temprana (ventana_id, ciclo_id, fecha_inicio, fecha_fin, beca_id, activa, creado_en, actualizado_en, eliminado_en) FROM stdin;
\.


--
-- Name: alumno_alumno_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.alumno_alumno_id_seq', 237, true);


--
-- Name: aplicacion_pago_aplicacion_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.aplicacion_pago_aplicacion_id_seq', 41, true);


--
-- Name: asignacion_beca_asignacion_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.asignacion_beca_asignacion_id_seq', 10, true);


--
-- Name: asistencia_asistencia_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.asistencia_asistencia_id_seq', 1, false);


--
-- Name: beca_beca_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.beca_beca_id_seq', 6, true);


--
-- Name: calendario_pago_calendario_pago_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.calendario_pago_calendario_pago_id_seq', 149, true);


--
-- Name: calificacion_calificacion_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.calificacion_calificacion_id_seq', 487, true);


--
-- Name: calificacion_extracurricular_calificacion_extracurricular_i_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.calificacion_extracurricular_calificacion_extracurricular_i_seq', 90, true);


--
-- Name: calificacion_taller_calificacion_taller_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.calificacion_taller_calificacion_taller_id_seq', 69, true);


--
-- Name: ciclo_escolar_ciclo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.ciclo_escolar_ciclo_id_seq', 7, true);


--
-- Name: configuracion_sistema_config_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.configuracion_sistema_config_id_seq', 19, true);


--
-- Name: documento_documento_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.documento_documento_id_seq', 19, true);


--
-- Name: factura_factura_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.factura_factura_id_seq', 1, false);


--
-- Name: grupo_grupo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.grupo_grupo_id_seq', 50, true);


--
-- Name: grupo_materia_grupo_materia_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.grupo_materia_grupo_materia_id_seq', 386, true);


--
-- Name: inscripcion_ciclo_inscripcion_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.inscripcion_ciclo_inscripcion_id_seq', 436, true);


--
-- Name: inscripcion_materia_inscripcion_materia_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.inscripcion_materia_inscripcion_materia_id_seq', 2750, true);


--
-- Name: intento_login_intento_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.intento_login_intento_id_seq', 156, true);


--
-- Name: log_auditoria_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.log_auditoria_log_id_seq', 549, true);


--
-- Name: materia_materia_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.materia_materia_id_seq', 83, true);


--
-- Name: movimiento_saldo_movimiento_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.movimiento_saldo_movimiento_id_seq', 4, true);


--
-- Name: nivel_educativo_nivel_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.nivel_educativo_nivel_id_seq', 4, true);


--
-- Name: notificacion_notificacion_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.notificacion_notificacion_id_seq', 20, true);


--
-- Name: pago_pago_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.pago_pago_id_seq', 25, true);


--
-- Name: periodo_evaluacion_periodo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.periodo_evaluacion_periodo_id_seq', 133, true);


--
-- Name: plan_pago_plan_pago_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.plan_pago_plan_pago_id_seq', 4, true);


--
-- Name: recargo_recargo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.recargo_recargo_id_seq', 1, true);


--
-- Name: rol_rol_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.rol_rol_id_seq', 4, true);


--
-- Name: solicitud_beca_solicitud_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.solicitud_beca_solicitud_id_seq', 7, true);


--
-- Name: tarifa_tarifa_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.tarifa_tarifa_id_seq', 25, true);


--
-- Name: token_revocado_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.token_revocado_id_seq', 1, false);


--
-- Name: tutor_alumno_tutor_alumno_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.tutor_alumno_tutor_alumno_id_seq', 243, true);


--
-- Name: tutor_tutor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.tutor_tutor_id_seq', 246, true);


--
-- Name: usuario_permiso_modulo_permiso_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.usuario_permiso_modulo_permiso_id_seq', 250, true);


--
-- Name: usuario_rol_usuario_rol_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.usuario_rol_usuario_rol_id_seq', 26, true);


--
-- Name: usuario_usuario_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.usuario_usuario_id_seq', 23, true);


--
-- Name: ventana_inscripcion_temprana_ventana_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sae_admin
--

SELECT pg_catalog.setval('public.ventana_inscripcion_temprana_ventana_id_seq', 1, false);


--
-- Name: _prisma_migrations _prisma_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public._prisma_migrations
    ADD CONSTRAINT _prisma_migrations_pkey PRIMARY KEY (id);


--
-- Name: alumno alumno_curp_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.alumno
    ADD CONSTRAINT alumno_curp_key UNIQUE (curp);


--
-- Name: alumno alumno_matricula_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.alumno
    ADD CONSTRAINT alumno_matricula_key UNIQUE (matricula);


--
-- Name: alumno alumno_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.alumno
    ADD CONSTRAINT alumno_pkey PRIMARY KEY (alumno_id);


--
-- Name: aplicacion_pago aplicacion_pago_pago_id_calendario_pago_id_aplicado_a_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.aplicacion_pago
    ADD CONSTRAINT aplicacion_pago_pago_id_calendario_pago_id_aplicado_a_key UNIQUE (pago_id, calendario_pago_id, aplicado_a);


--
-- Name: aplicacion_pago aplicacion_pago_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.aplicacion_pago
    ADD CONSTRAINT aplicacion_pago_pkey PRIMARY KEY (aplicacion_id);


--
-- Name: asignacion_beca asignacion_beca_alumno_id_beca_id_ciclo_id_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.asignacion_beca
    ADD CONSTRAINT asignacion_beca_alumno_id_beca_id_ciclo_id_key UNIQUE (alumno_id, beca_id, ciclo_id);


--
-- Name: asignacion_beca asignacion_beca_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.asignacion_beca
    ADD CONSTRAINT asignacion_beca_pkey PRIMARY KEY (asignacion_id);


--
-- Name: asistencia asistencia_alumno_id_grupo_materia_id_fecha_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.asistencia
    ADD CONSTRAINT asistencia_alumno_id_grupo_materia_id_fecha_key UNIQUE (alumno_id, grupo_materia_id, fecha);


--
-- Name: asistencia asistencia_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.asistencia
    ADD CONSTRAINT asistencia_pkey PRIMARY KEY (asistencia_id);


--
-- Name: beca beca_nombre_beca_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.beca
    ADD CONSTRAINT beca_nombre_beca_key UNIQUE (nombre_beca);


--
-- Name: beca beca_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.beca
    ADD CONSTRAINT beca_pkey PRIMARY KEY (beca_id);


--
-- Name: calendario_pago calendario_pago_alumno_id_ciclo_id_concepto_mes_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.calendario_pago
    ADD CONSTRAINT calendario_pago_alumno_id_ciclo_id_concepto_mes_key UNIQUE (alumno_id, ciclo_id, concepto, mes);


--
-- Name: calendario_pago calendario_pago_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.calendario_pago
    ADD CONSTRAINT calendario_pago_pkey PRIMARY KEY (calendario_pago_id);


--
-- Name: calificacion_extracurricular calificacion_extracurricular_alumno_id_club_periodo_id_cicl_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.calificacion_extracurricular
    ADD CONSTRAINT calificacion_extracurricular_alumno_id_club_periodo_id_cicl_key UNIQUE (alumno_id, club, periodo_id, ciclo_id);


--
-- Name: calificacion_extracurricular calificacion_extracurricular_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.calificacion_extracurricular
    ADD CONSTRAINT calificacion_extracurricular_pkey PRIMARY KEY (calificacion_extracurricular_id);


--
-- Name: calificacion calificacion_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.calificacion
    ADD CONSTRAINT calificacion_pkey PRIMARY KEY (calificacion_id);


--
-- Name: calificacion_taller calificacion_taller_alumno_id_periodo_id_ciclo_id_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.calificacion_taller
    ADD CONSTRAINT calificacion_taller_alumno_id_periodo_id_ciclo_id_key UNIQUE (alumno_id, periodo_id, ciclo_id);


--
-- Name: calificacion_taller calificacion_taller_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.calificacion_taller
    ADD CONSTRAINT calificacion_taller_pkey PRIMARY KEY (calificacion_taller_id);


--
-- Name: ciclo_escolar ciclo_escolar_nombre_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.ciclo_escolar
    ADD CONSTRAINT ciclo_escolar_nombre_key UNIQUE (nombre);


--
-- Name: ciclo_escolar ciclo_escolar_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.ciclo_escolar
    ADD CONSTRAINT ciclo_escolar_pkey PRIMARY KEY (ciclo_id);


--
-- Name: configuracion_sistema configuracion_sistema_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.configuracion_sistema
    ADD CONSTRAINT configuracion_sistema_pkey PRIMARY KEY (config_id);


--
-- Name: documento documento_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.documento
    ADD CONSTRAINT documento_pkey PRIMARY KEY (documento_id);


--
-- Name: factura factura_numero_factura_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.factura
    ADD CONSTRAINT factura_numero_factura_key UNIQUE (numero_factura);


--
-- Name: factura_pago factura_pago_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.factura_pago
    ADD CONSTRAINT factura_pago_pkey PRIMARY KEY (factura_id, pago_id);


--
-- Name: factura factura_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.factura
    ADD CONSTRAINT factura_pkey PRIMARY KEY (factura_id);


--
-- Name: grupo grupo_ciclo_id_nivel_id_grado_seccion_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.grupo
    ADD CONSTRAINT grupo_ciclo_id_nivel_id_grado_seccion_key UNIQUE (ciclo_id, nivel_id, grado, seccion);


--
-- Name: grupo grupo_grupo_id_ciclo_id_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.grupo
    ADD CONSTRAINT grupo_grupo_id_ciclo_id_key UNIQUE (grupo_id, ciclo_id);


--
-- Name: grupo_materia grupo_materia_grupo_id_materia_id_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.grupo_materia
    ADD CONSTRAINT grupo_materia_grupo_id_materia_id_key UNIQUE (grupo_id, materia_id);


--
-- Name: grupo_materia grupo_materia_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.grupo_materia
    ADD CONSTRAINT grupo_materia_pkey PRIMARY KEY (grupo_materia_id);


--
-- Name: grupo grupo_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.grupo
    ADD CONSTRAINT grupo_pkey PRIMARY KEY (grupo_id);


--
-- Name: inscripcion_ciclo inscripcion_ciclo_alumno_id_ciclo_id_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.inscripcion_ciclo
    ADD CONSTRAINT inscripcion_ciclo_alumno_id_ciclo_id_key UNIQUE (alumno_id, ciclo_id);


--
-- Name: inscripcion_ciclo inscripcion_ciclo_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.inscripcion_ciclo
    ADD CONSTRAINT inscripcion_ciclo_pkey PRIMARY KEY (inscripcion_id);


--
-- Name: inscripcion_materia inscripcion_materia_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.inscripcion_materia
    ADD CONSTRAINT inscripcion_materia_pkey PRIMARY KEY (inscripcion_materia_id);


--
-- Name: intento_login intento_login_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.intento_login
    ADD CONSTRAINT intento_login_pkey PRIMARY KEY (intento_id);


--
-- Name: log_auditoria log_auditoria_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.log_auditoria
    ADD CONSTRAINT log_auditoria_pkey PRIMARY KEY (log_id);


--
-- Name: materia materia_nivel_id_nombre_tipo_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.materia
    ADD CONSTRAINT materia_nivel_id_nombre_tipo_key UNIQUE (nivel_id, nombre, tipo);


--
-- Name: materia materia_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.materia
    ADD CONSTRAINT materia_pkey PRIMARY KEY (materia_id);


--
-- Name: movimiento_saldo movimiento_saldo_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.movimiento_saldo
    ADD CONSTRAINT movimiento_saldo_pkey PRIMARY KEY (movimiento_id);


--
-- Name: nivel_educativo nivel_educativo_codigo_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.nivel_educativo
    ADD CONSTRAINT nivel_educativo_codigo_key UNIQUE (codigo);


--
-- Name: nivel_educativo nivel_educativo_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.nivel_educativo
    ADD CONSTRAINT nivel_educativo_pkey PRIMARY KEY (nivel_id);


--
-- Name: notificacion notificacion_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.notificacion
    ADD CONSTRAINT notificacion_pkey PRIMARY KEY (notificacion_id);


--
-- Name: pago pago_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.pago
    ADD CONSTRAINT pago_pkey PRIMARY KEY (pago_id);


--
-- Name: periodo_evaluacion periodo_evaluacion_ciclo_id_nivel_id_daterange_excl; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.periodo_evaluacion
    ADD CONSTRAINT periodo_evaluacion_ciclo_id_nivel_id_daterange_excl EXCLUDE USING gist (ciclo_id WITH =, nivel_id WITH =, daterange(fecha_inicio, fecha_fin, '[]'::text) WITH &&);


--
-- Name: periodo_evaluacion periodo_evaluacion_ciclo_id_nivel_id_tipo_numero_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.periodo_evaluacion
    ADD CONSTRAINT periodo_evaluacion_ciclo_id_nivel_id_tipo_numero_key UNIQUE (ciclo_id, nivel_id, tipo, numero);


--
-- Name: periodo_evaluacion periodo_evaluacion_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.periodo_evaluacion
    ADD CONSTRAINT periodo_evaluacion_pkey PRIMARY KEY (periodo_id);


--
-- Name: plan_pago plan_pago_ciclo_id_nombre_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.plan_pago
    ADD CONSTRAINT plan_pago_ciclo_id_nombre_key UNIQUE (ciclo_id, nombre);


--
-- Name: plan_pago plan_pago_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.plan_pago
    ADD CONSTRAINT plan_pago_pkey PRIMARY KEY (plan_pago_id);


--
-- Name: recargo recargo_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.recargo
    ADD CONSTRAINT recargo_pkey PRIMARY KEY (recargo_id);


--
-- Name: rol rol_codigo_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.rol
    ADD CONSTRAINT rol_codigo_key UNIQUE (codigo);


--
-- Name: rol rol_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.rol
    ADD CONSTRAINT rol_pkey PRIMARY KEY (rol_id);


--
-- Name: solicitud_beca solicitud_beca_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.solicitud_beca
    ADD CONSTRAINT solicitud_beca_pkey PRIMARY KEY (solicitud_id);


--
-- Name: tarifa tarifa_ciclo_id_nivel_id_concepto_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.tarifa
    ADD CONSTRAINT tarifa_ciclo_id_nivel_id_concepto_key UNIQUE (ciclo_id, nivel_id, concepto);


--
-- Name: tarifa tarifa_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.tarifa
    ADD CONSTRAINT tarifa_pkey PRIMARY KEY (tarifa_id);


--
-- Name: token_revocado token_revocado_jti_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.token_revocado
    ADD CONSTRAINT token_revocado_jti_key UNIQUE (jti);


--
-- Name: token_revocado token_revocado_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.token_revocado
    ADD CONSTRAINT token_revocado_pkey PRIMARY KEY (id);


--
-- Name: tutor_alumno tutor_alumno_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.tutor_alumno
    ADD CONSTRAINT tutor_alumno_pkey PRIMARY KEY (tutor_alumno_id);


--
-- Name: tutor_alumno tutor_alumno_tutor_id_alumno_id_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.tutor_alumno
    ADD CONSTRAINT tutor_alumno_tutor_id_alumno_id_key UNIQUE (tutor_id, alumno_id);


--
-- Name: tutor tutor_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.tutor
    ADD CONSTRAINT tutor_pkey PRIMARY KEY (tutor_id);


--
-- Name: tutor tutor_rfc_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.tutor
    ADD CONSTRAINT tutor_rfc_key UNIQUE (rfc);


--
-- Name: configuracion_sistema uq_configuracion_clave_ciclo; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.configuracion_sistema
    ADD CONSTRAINT uq_configuracion_clave_ciclo UNIQUE (clave, ciclo_id);


--
-- Name: usuario usuario_correo_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_correo_key UNIQUE (correo);


--
-- Name: usuario usuario_nombre_usuario_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_nombre_usuario_key UNIQUE (nombre_usuario);


--
-- Name: usuario_permiso_modulo usuario_permiso_modulo_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.usuario_permiso_modulo
    ADD CONSTRAINT usuario_permiso_modulo_pkey PRIMARY KEY (permiso_id);


--
-- Name: usuario usuario_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_pkey PRIMARY KEY (usuario_id);


--
-- Name: usuario_rol usuario_rol_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.usuario_rol
    ADD CONSTRAINT usuario_rol_pkey PRIMARY KEY (usuario_rol_id);


--
-- Name: usuario_rol usuario_rol_usuario_id_rol_id_key; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.usuario_rol
    ADD CONSTRAINT usuario_rol_usuario_id_rol_id_key UNIQUE (usuario_id, rol_id);


--
-- Name: ventana_inscripcion_temprana ventana_inscripcion_temprana_pkey; Type: CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.ventana_inscripcion_temprana
    ADD CONSTRAINT ventana_inscripcion_temprana_pkey PRIMARY KEY (ventana_id);


--
-- Name: calificacion_extracurricular_alumno_id_club_periodo_id_ciclo_id; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE UNIQUE INDEX calificacion_extracurricular_alumno_id_club_periodo_id_ciclo_id ON public.calificacion_extracurricular USING btree (alumno_id, club, periodo_id, ciclo_id);


--
-- Name: idx_alumno_activo_no_eliminado; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE INDEX idx_alumno_activo_no_eliminado ON public.alumno USING btree (estado) WHERE (((estado)::text = 'Activo'::text) AND (eliminado_en IS NULL));


--
-- Name: idx_beca_alumno_estado; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE INDEX idx_beca_alumno_estado ON public.asignacion_beca USING btree (alumno_id, estado) WHERE (eliminado_en IS NULL);


--
-- Name: idx_calendario_pago_estado; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE INDEX idx_calendario_pago_estado ON public.calendario_pago USING btree (alumno_id, estado_cobro) WHERE (eliminado_en IS NULL);


--
-- Name: idx_calendario_pago_vencim; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE INDEX idx_calendario_pago_vencim ON public.calendario_pago USING btree (fecha_vencimiento) WHERE (((estado_cobro)::text <> 'pagado'::text) AND (eliminado_en IS NULL));


--
-- Name: idx_configuracion_clave_global; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE INDEX idx_configuracion_clave_global ON public.configuracion_sistema USING btree (clave) WHERE (ciclo_id IS NULL);


--
-- Name: idx_grupo_materia_docente; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE INDEX idx_grupo_materia_docente ON public.grupo_materia USING btree (docente_id) WHERE (eliminado_en IS NULL);


--
-- Name: idx_inscripcion_ciclo_estado; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE INDEX idx_inscripcion_ciclo_estado ON public.inscripcion_ciclo USING btree (ciclo_id, estado_en_ciclo) WHERE (eliminado_en IS NULL);


--
-- Name: idx_inscripcion_ciclo_grupo; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE INDEX idx_inscripcion_ciclo_grupo ON public.inscripcion_ciclo USING btree (ciclo_id, grupo_id) WHERE (eliminado_en IS NULL);


--
-- Name: idx_inscripcion_estado_financiero; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE INDEX idx_inscripcion_estado_financiero ON public.inscripcion_ciclo USING btree (ciclo_id, estado_financiero) WHERE (((estado_financiero)::text <> 'al_corriente'::text) AND (eliminado_en IS NULL));


--
-- Name: idx_inscripcion_plan_pago; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE INDEX idx_inscripcion_plan_pago ON public.inscripcion_ciclo USING btree (plan_pago_id) WHERE ((plan_pago_id IS NOT NULL) AND (eliminado_en IS NULL));


--
-- Name: idx_notificacion_pendientes; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE INDEX idx_notificacion_pendientes ON public.notificacion USING btree (estado, programada_para) WHERE (((estado)::text = 'pendiente'::text) AND (eliminado_en IS NULL));


--
-- Name: idx_plan_pago_ciclo_activo; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE INDEX idx_plan_pago_ciclo_activo ON public.plan_pago USING btree (ciclo_id) WHERE ((activo = true) AND (eliminado_en IS NULL));


--
-- Name: idx_solicitud_beca_alumno; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE INDEX idx_solicitud_beca_alumno ON public.solicitud_beca USING btree (alumno_id, ciclo_id) WHERE (eliminado_en IS NULL);


--
-- Name: idx_solicitud_beca_pendientes; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE INDEX idx_solicitud_beca_pendientes ON public.solicitud_beca USING btree (fecha_solicitud DESC) WHERE (((estado)::text = 'pendiente'::text) AND (eliminado_en IS NULL));


--
-- Name: idx_tutor_alumno_alumno; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE INDEX idx_tutor_alumno_alumno ON public.tutor_alumno USING btree (alumno_id) WHERE ((activo = true) AND (eliminado_en IS NULL));


--
-- Name: idx_tutor_alumno_responsable; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE INDEX idx_tutor_alumno_responsable ON public.tutor_alumno USING btree (alumno_id) WHERE ((es_responsable_financiero = true) AND (activo = true) AND (eliminado_en IS NULL));


--
-- Name: idx_tutor_alumno_tutor; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE INDEX idx_tutor_alumno_tutor ON public.tutor_alumno USING btree (tutor_id) WHERE ((activo = true) AND (eliminado_en IS NULL));


--
-- Name: idx_tutor_requiere_factura; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE INDEX idx_tutor_requiere_factura ON public.tutor USING btree (requiere_factura) WHERE ((requiere_factura = true) AND (eliminado_en IS NULL));


--
-- Name: idx_usuario_rol_usuario; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE INDEX idx_usuario_rol_usuario ON public.usuario_rol USING btree (usuario_id) WHERE ((activo = true) AND (eliminado_en IS NULL));


--
-- Name: inscripcion_materia_alumno_id_grupo_materia_id_key; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE UNIQUE INDEX inscripcion_materia_alumno_id_grupo_materia_id_key ON public.inscripcion_materia USING btree (alumno_id, grupo_materia_id);


--
-- Name: usuario_permiso_modulo_usuario_id_modulo_key; Type: INDEX; Schema: public; Owner: sae_admin
--

CREATE UNIQUE INDEX usuario_permiso_modulo_usuario_id_modulo_key ON public.usuario_permiso_modulo USING btree (usuario_id, modulo);


--
-- Name: alumno trg_actualizar_timestamp_alumno; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_alumno BEFORE UPDATE ON public.alumno FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: aplicacion_pago trg_actualizar_timestamp_aplicacion_pago; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_aplicacion_pago BEFORE UPDATE ON public.aplicacion_pago FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: asignacion_beca trg_actualizar_timestamp_asignacion_beca; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_asignacion_beca BEFORE UPDATE ON public.asignacion_beca FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: asistencia trg_actualizar_timestamp_asistencia; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_asistencia BEFORE UPDATE ON public.asistencia FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: beca trg_actualizar_timestamp_beca; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_beca BEFORE UPDATE ON public.beca FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: calendario_pago trg_actualizar_timestamp_calendario_pago; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_calendario_pago BEFORE UPDATE ON public.calendario_pago FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: calificacion trg_actualizar_timestamp_calificacion; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_calificacion BEFORE UPDATE ON public.calificacion FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: ciclo_escolar trg_actualizar_timestamp_ciclo_escolar; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_ciclo_escolar BEFORE UPDATE ON public.ciclo_escolar FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: documento trg_actualizar_timestamp_documento; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_documento BEFORE UPDATE ON public.documento FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: factura trg_actualizar_timestamp_factura; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_factura BEFORE UPDATE ON public.factura FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: factura_pago trg_actualizar_timestamp_factura_pago; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_factura_pago BEFORE UPDATE ON public.factura_pago FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: grupo trg_actualizar_timestamp_grupo; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_grupo BEFORE UPDATE ON public.grupo FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: grupo_materia trg_actualizar_timestamp_grupo_materia; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_grupo_materia BEFORE UPDATE ON public.grupo_materia FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: inscripcion_ciclo trg_actualizar_timestamp_inscripcion_ciclo; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_inscripcion_ciclo BEFORE UPDATE ON public.inscripcion_ciclo FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: materia trg_actualizar_timestamp_materia; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_materia BEFORE UPDATE ON public.materia FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: movimiento_saldo trg_actualizar_timestamp_movimiento_saldo; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_movimiento_saldo BEFORE UPDATE ON public.movimiento_saldo FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: nivel_educativo trg_actualizar_timestamp_nivel_educativo; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_nivel_educativo BEFORE UPDATE ON public.nivel_educativo FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: notificacion trg_actualizar_timestamp_notificacion; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_notificacion BEFORE UPDATE ON public.notificacion FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: pago trg_actualizar_timestamp_pago; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_pago BEFORE UPDATE ON public.pago FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: periodo_evaluacion trg_actualizar_timestamp_periodo_evaluacion; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_periodo_evaluacion BEFORE UPDATE ON public.periodo_evaluacion FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: plan_pago trg_actualizar_timestamp_plan_pago; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_plan_pago BEFORE UPDATE ON public.plan_pago FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: recargo trg_actualizar_timestamp_recargo; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_recargo BEFORE UPDATE ON public.recargo FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: rol trg_actualizar_timestamp_rol; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_rol BEFORE UPDATE ON public.rol FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: solicitud_beca trg_actualizar_timestamp_solicitud_beca; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_solicitud_beca BEFORE UPDATE ON public.solicitud_beca FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: tarifa trg_actualizar_timestamp_tarifa; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_tarifa BEFORE UPDATE ON public.tarifa FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: tutor trg_actualizar_timestamp_tutor; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_tutor BEFORE UPDATE ON public.tutor FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: tutor_alumno trg_actualizar_timestamp_tutor_alumno; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_tutor_alumno BEFORE UPDATE ON public.tutor_alumno FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: usuario trg_actualizar_timestamp_usuario; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_usuario BEFORE UPDATE ON public.usuario FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: usuario_rol trg_actualizar_timestamp_usuario_rol; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_usuario_rol BEFORE UPDATE ON public.usuario_rol FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: ventana_inscripcion_temprana trg_actualizar_timestamp_ventana_inscripcion_temprana; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_actualizar_timestamp_ventana_inscripcion_temprana BEFORE UPDATE ON public.ventana_inscripcion_temprana FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_timestamp();


--
-- Name: alumno trg_audit_alumno; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_audit_alumno AFTER INSERT OR DELETE OR UPDATE ON public.alumno FOR EACH ROW EXECUTE FUNCTION public.fn_audit_trigger('alumno_id');


--
-- Name: TRIGGER trg_audit_alumno ON alumno; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TRIGGER trg_audit_alumno ON public.alumno IS 'Audita registro, modificación y baja de expedientes de alumnos.';


--
-- Name: pago trg_audit_pago; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_audit_pago AFTER INSERT OR DELETE OR UPDATE ON public.pago FOR EACH ROW EXECUTE FUNCTION public.fn_audit_trigger('pago_id');


--
-- Name: TRIGGER trg_audit_pago ON pago; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TRIGGER trg_audit_pago ON public.pago IS 'Audita alta, modificación o eliminación de pagos.';


--
-- Name: usuario trg_audit_usuario; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_audit_usuario AFTER INSERT OR DELETE OR UPDATE ON public.usuario FOR EACH ROW EXECUTE FUNCTION public.fn_audit_trigger('usuario_id');


--
-- Name: TRIGGER trg_audit_usuario ON usuario; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TRIGGER trg_audit_usuario ON public.usuario IS 'Audita creación, modificación y desactivación de cuentas. password_hash enmascarado.';


--
-- Name: usuario_rol trg_audit_usuario_rol; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_audit_usuario_rol AFTER INSERT OR DELETE OR UPDATE ON public.usuario_rol FOR EACH ROW EXECUTE FUNCTION public.fn_audit_trigger('usuario_rol_id');


--
-- Name: TRIGGER trg_audit_usuario_rol ON usuario_rol; Type: COMMENT; Schema: public; Owner: sae_admin
--

COMMENT ON TRIGGER trg_audit_usuario_rol ON public.usuario_rol IS 'Audita asignación y retiro de roles. Crítico para trazabilidad de permisos.';


--
-- Name: calificacion trg_validar_ciclo_calificacion; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_validar_ciclo_calificacion BEFORE INSERT OR UPDATE ON public.calificacion FOR EACH ROW EXECUTE FUNCTION public.fn_validar_ciclo_calificacion();


--
-- Name: alumno trg_validar_personas_autorizadas; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_validar_personas_autorizadas BEFORE INSERT OR UPDATE OF personas_autorizadas ON public.alumno FOR EACH ROW EXECUTE FUNCTION public.fn_validar_personas_autorizadas();


--
-- Name: pago trg_validar_tutor_paga; Type: TRIGGER; Schema: public; Owner: sae_admin
--

CREATE TRIGGER trg_validar_tutor_paga BEFORE INSERT OR UPDATE ON public.pago FOR EACH ROW EXECUTE FUNCTION public.fn_validar_tutor_paga_alumno();


--
-- Name: calificacion_taller calificacion_taller_alumno_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.calificacion_taller
    ADD CONSTRAINT calificacion_taller_alumno_id_fkey FOREIGN KEY (alumno_id) REFERENCES public.alumno(alumno_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: calificacion_taller calificacion_taller_ciclo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.calificacion_taller
    ADD CONSTRAINT calificacion_taller_ciclo_id_fkey FOREIGN KEY (ciclo_id) REFERENCES public.ciclo_escolar(ciclo_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: calificacion_taller calificacion_taller_periodo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.calificacion_taller
    ADD CONSTRAINT calificacion_taller_periodo_id_fkey FOREIGN KEY (periodo_id) REFERENCES public.periodo_evaluacion(periodo_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: calificacion_taller calificacion_taller_registrada_por_fkey; Type: FK CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.calificacion_taller
    ADD CONSTRAINT calificacion_taller_registrada_por_fkey FOREIGN KEY (registrada_por) REFERENCES public.usuario(usuario_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: inscripcion_materia inscripcion_materia_alumno_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.inscripcion_materia
    ADD CONSTRAINT inscripcion_materia_alumno_id_fkey FOREIGN KEY (alumno_id) REFERENCES public.alumno(alumno_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: inscripcion_materia inscripcion_materia_grupo_materia_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.inscripcion_materia
    ADD CONSTRAINT inscripcion_materia_grupo_materia_id_fkey FOREIGN KEY (grupo_materia_id) REFERENCES public.grupo_materia(grupo_materia_id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: usuario_permiso_modulo usuario_permiso_modulo_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: sae_admin
--

ALTER TABLE ONLY public.usuario_permiso_modulo
    ADD CONSTRAINT usuario_permiso_modulo_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuario(usuario_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict KBrMb1vbqONtHkfIlIBzmp3EQukntT6twR4BDharCYvBXMJInJ6rpu6g0lbTiov

