CREATE TABLE inscripcion_materia (
    inscripcion_materia_id SERIAL PRIMARY KEY,
    alumno_id INT NOT NULL REFERENCES alumno(alumno_id) ON DELETE CASCADE,
    grupo_materia_id INT NOT NULL REFERENCES grupo_materia(grupo_materia_id) ON DELETE CASCADE,
    creado_en TIMESTAMPTZ DEFAULT now(),
    UNIQUE(alumno_id, grupo_materia_id)
);
