CREATE TABLE IF NOT EXISTS public.inscripcion_materia (
    inscripcion_materia_id SERIAL PRIMARY KEY,
    alumno_id INTEGER NOT NULL REFERENCES public.alumno(alumno_id) ON DELETE CASCADE,
    grupo_materia_id INTEGER NOT NULL REFERENCES public.grupo_materia(grupo_materia_id) ON DELETE CASCADE,
    creado_en TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    UNIQUE(alumno_id, grupo_materia_id)
);

ALTER TABLE public.calificacion ADD CONSTRAINT calificacion_alumno_id_grupo_materia_id_periodo_id_key UNIQUE (alumno_id, grupo_materia_id, periodo_id);
