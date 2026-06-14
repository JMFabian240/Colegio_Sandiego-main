ALTER TABLE solicitud_beca ADD COLUMN IF NOT EXISTS tipo_solicitud VARCHAR(15) DEFAULT 'asignacion' NOT NULL;
