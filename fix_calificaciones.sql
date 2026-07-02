CREATE TABLE calificacion_taller (
    calificacion_taller_id SERIAL PRIMARY KEY,
    alumno_id INT NOT NULL REFERENCES alumno(alumno_id) ON DELETE RESTRICT,
    periodo_id INT NOT NULL REFERENCES periodo_evaluacion(periodo_id) ON DELETE RESTRICT,
    ciclo_id INT NOT NULL REFERENCES ciclo_escolar(ciclo_id) ON DELETE RESTRICT,
    valor_cualitativo VARCHAR(5),
    modificada_motivo TEXT,
    registrada_por INT REFERENCES usuario(usuario_id) ON DELETE SET NULL,
    registrada_en TIMESTAMPTZ DEFAULT now(),
    actualizado_en TIMESTAMPTZ DEFAULT now(),
    UNIQUE(alumno_id, periodo_id, ciclo_id)
);

CREATE TABLE calificacion_extracurricular (
    calificacion_extracurricular_id SERIAL PRIMARY KEY,
    alumno_id INT NOT NULL REFERENCES alumno(alumno_id) ON DELETE RESTRICT,
    club VARCHAR(50) NOT NULL,
    periodo_id INT NOT NULL REFERENCES periodo_evaluacion(periodo_id) ON DELETE RESTRICT,
    ciclo_id INT NOT NULL REFERENCES ciclo_escolar(ciclo_id) ON DELETE RESTRICT,
    valor_numerico NUMERIC(4,2),
    modificada_motivo TEXT,
    registrada_por INT REFERENCES usuario(usuario_id) ON DELETE SET NULL,
    registrada_en TIMESTAMPTZ DEFAULT now(),
    actualizado_en TIMESTAMPTZ DEFAULT now(),
    UNIQUE(alumno_id, club, periodo_id, ciclo_id)
);
