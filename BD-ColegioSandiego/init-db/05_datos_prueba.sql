-- =====================================================================
-- 05_datos_prueba.sql  (v5 - alineado con esquema v5)
-- SAE - Colegio San Diego | Datos sintéticos para validación
--
-- Cambios respecto a v4:
--   * Rename aplicado: tabla "tutor" y columna "tutor_id" en todas las
--     referencias (antes "padre" y "padre_id").
--   * Las nuevas columnas actualizado_en y eliminado_en se llenan
--     automáticamente por DEFAULT (now() y NULL respectivamente);
--     no requieren INSERT explícito.
--   * La tabla rol y otras Categoría B ya no tienen columna "activo".
--
-- Ambientación: Coatzacoalcos, Veracruz (LADA 921, CP 96400-96599, CURP VZ).
-- Caso 1 integrado: Roberto y Lucía Mendoza, custodia compartida.
-- =====================================================================

-- =====================================================================
-- BLOQUE 1  Ciclos escolares
-- =====================================================================
INSERT INTO ciclo_escolar (nombre, fecha_inicio, fecha_fin, activo) VALUES
    ('2025-2026', '2025-08-04', '2026-07-10', FALSE),
    ('2026-2027', '2026-08-03', '2027-07-09', TRUE)
ON CONFLICT (nombre) DO NOTHING;

-- =====================================================================
-- BLOQUE 2  Usuarios + Roles N:M
-- =====================================================================
INSERT INTO usuario (nombre_usuario, nombre_completo, correo, telefono,
                     password_hash, debe_cambiar_pwd) VALUES
    ('elizabeth.mendoza', 'Elizabeth Mendoza Castro',  'elizabeth@sandiego.edu',
     '9211112233', crypt('sandiego2026', gen_salt('bf', 10)), TRUE),
    ('maria.dolores',     'María Dolores Pérez Rangel','direccion@sandiego.edu',
     '9211112234', crypt('sandiego2026', gen_salt('bf', 10)), TRUE),
    ('laura.rios',        'Laura Ríos Méndez',         'laura.rios@sandiego.edu',
     '9211112235', crypt('sandiego2026', gen_salt('bf', 10)), TRUE),
    ('mario.sanchez',     'Mario Sánchez Trejo',       'mario.sanchez@sandiego.edu',
     '9211112236', crypt('sandiego2026', gen_salt('bf', 10)), TRUE),
    ('patricia.nunez',    'Patricia Núñez García',     'patricia.nunez@sandiego.edu',
     '9211112237', crypt('sandiego2026', gen_salt('bf', 10)), TRUE)
ON CONFLICT (nombre_usuario) DO NOTHING;

INSERT INTO usuario_rol (usuario_id, rol_id, asignado_por)
SELECT u.usuario_id, r.rol_id,
       (SELECT usuario_id FROM usuario WHERE nombre_usuario = 'elizabeth.mendoza')
FROM (VALUES
    ('elizabeth.mendoza', 'administrador'),
    ('maria.dolores',     'directora'),
    ('laura.rios',        'empleado'),
    ('laura.rios',        'docente'),
    ('mario.sanchez',     'docente'),
    ('patricia.nunez',    'docente')
) AS a(nombre_usuario, codigo_rol)
JOIN usuario u ON u.nombre_usuario = a.nombre_usuario
JOIN rol     r ON r.codigo         = a.codigo_rol
ON CONFLICT (usuario_id, rol_id) DO NOTHING;

-- =====================================================================
-- BLOQUE 3  Grupos del ciclo activo
-- =====================================================================
WITH ciclo_activo AS (SELECT ciclo_id FROM ciclo_escolar  WHERE nombre = '2026-2027'),
     nivel_pri    AS (SELECT nivel_id FROM nivel_educativo WHERE codigo = 'PRIMARIA'),
     nivel_sec    AS (SELECT nivel_id FROM nivel_educativo WHERE codigo = 'SECUNDARIA'),
     u_laura      AS (SELECT usuario_id FROM usuario WHERE nombre_usuario = 'laura.rios'),
     u_mario      AS (SELECT usuario_id FROM usuario WHERE nombre_usuario = 'mario.sanchez'),
     u_paty       AS (SELECT usuario_id FROM usuario WHERE nombre_usuario = 'patricia.nunez')
INSERT INTO grupo (ciclo_id, nivel_id, grado, seccion, nombre, docente_titular_id, cupo_maximo)
SELECT (SELECT ciclo_id FROM ciclo_activo), (SELECT nivel_id FROM nivel_pri), '2', 'A', '2°A Primaria',   (SELECT usuario_id FROM u_laura), 25 UNION ALL
SELECT (SELECT ciclo_id FROM ciclo_activo), (SELECT nivel_id FROM nivel_pri), '3', 'A', '3°A Primaria',   (SELECT usuario_id FROM u_laura), 25 UNION ALL
SELECT (SELECT ciclo_id FROM ciclo_activo), (SELECT nivel_id FROM nivel_pri), '4', 'A', '4°A Primaria',   (SELECT usuario_id FROM u_laura), 25 UNION ALL
SELECT (SELECT ciclo_id FROM ciclo_activo), (SELECT nivel_id FROM nivel_pri), '5', 'A', '5°A Primaria',   (SELECT usuario_id FROM u_paty),  25 UNION ALL
SELECT (SELECT ciclo_id FROM ciclo_activo), (SELECT nivel_id FROM nivel_pri), '6', 'A', '6°A Primaria',   (SELECT usuario_id FROM u_paty),  25 UNION ALL
SELECT (SELECT ciclo_id FROM ciclo_activo), (SELECT nivel_id FROM nivel_sec), '1', 'A', '1°A Secundaria', (SELECT usuario_id FROM u_mario), 30 UNION ALL
SELECT (SELECT ciclo_id FROM ciclo_activo), (SELECT nivel_id FROM nivel_sec), '2', 'A', '2°A Secundaria', (SELECT usuario_id FROM u_mario), 30 UNION ALL
SELECT (SELECT ciclo_id FROM ciclo_activo), (SELECT nivel_id FROM nivel_sec), '3', 'A', '3°A Secundaria', (SELECT usuario_id FROM u_mario), 30
ON CONFLICT (ciclo_id, nivel_id, grado, seccion) DO NOTHING;

-- =====================================================================
-- BLOQUE 4  Materias y grupo_materia
-- =====================================================================
INSERT INTO materia (nivel_id, clave_sep, nombre, descripcion, horas_semanales, creditos, tipo)
SELECT (SELECT nivel_id FROM nivel_educativo WHERE codigo='PRIMARIA'),
       clave_sep, nombre, descripcion, hrs, creds, 'curricular'
FROM (VALUES
    ('PRI-ESP-04', 'Español',           'Lectura, escritura y expresión oral',     6, 6.0),
    ('PRI-MAT-04', 'Matemáticas',       'Aritmética, geometría y razonamiento',    6, 6.0),
    ('PRI-CN-04',  'Ciencias Naturales','Biología, física y química básicas',      4, 4.0),
    ('PRI-HIS-04', 'Historia',          'México y mundo, énfasis cívico',          3, 3.0),
    ('PRI-GEO-04', 'Geografía',         'Geografía de México y entidades',         3, 3.0)
) AS m(clave_sep, nombre, descripcion, hrs, creds)
ON CONFLICT (nivel_id, nombre, tipo) DO NOTHING;

INSERT INTO materia (nivel_id, clave_sep, nombre, descripcion, horas_semanales, creditos, tipo)
SELECT (SELECT nivel_id FROM nivel_educativo WHERE codigo='SECUNDARIA'),
       clave_sep, nombre, descripcion, hrs, creds, 'curricular'
FROM (VALUES
    ('SEC-ESP-01', 'Español',          'Comprensión lectora y producción de textos', 5, 5.0),
    ('SEC-MAT-01', 'Matemáticas',      'Álgebra, geometría y probabilidad',          5, 5.0),
    ('SEC-ING-01', 'Inglés',           'Inglés como segunda lengua',                 3, 3.0),
    ('SEC-FCE-01', 'Formación Cívica', 'Ética y ciudadanía',                         4, 4.0)
) AS m(clave_sep, nombre, descripcion, hrs, creds)
ON CONFLICT (nivel_id, nombre, tipo) DO NOTHING;

INSERT INTO grupo_materia (grupo_id, materia_id, docente_id, horario, aula)
SELECT g.grupo_id, m.materia_id,
       (SELECT usuario_id FROM usuario WHERE nombre_usuario = 'laura.rios'),
       'Lun-Vie 8:00-9:30', 'Aula 12'
FROM grupo g
JOIN materia m ON m.nivel_id = g.nivel_id
WHERE g.nombre = '4°A Primaria' AND m.tipo = 'curricular'
  AND m.nivel_id = (SELECT nivel_id FROM nivel_educativo WHERE codigo='PRIMARIA')
ON CONFLICT (grupo_id, materia_id) DO NOTHING;

INSERT INTO grupo_materia (grupo_id, materia_id, docente_id, horario, aula)
SELECT g.grupo_id, m.materia_id,
       (SELECT usuario_id FROM usuario WHERE nombre_usuario = 'mario.sanchez'),
       'Lun-Vie 9:30-11:00', 'Aula 21'
FROM grupo g
JOIN materia m ON m.nivel_id = g.nivel_id
WHERE g.nombre = '1°A Secundaria' AND m.tipo = 'curricular'
  AND m.nivel_id = (SELECT nivel_id FROM nivel_educativo WHERE codigo='SECUNDARIA')
ON CONFLICT (grupo_id, materia_id) DO NOTHING;

-- =====================================================================
-- BLOQUE 5  Tarifas
-- =====================================================================
INSERT INTO tarifa (ciclo_id, nivel_id, concepto, monto, descripcion)
SELECT (SELECT ciclo_id FROM ciclo_escolar  WHERE nombre = '2026-2027'),
       (SELECT nivel_id FROM nivel_educativo WHERE codigo = 'PRIMARIA'),
       concepto, monto, descripcion
FROM (VALUES
    ('inscripcion', 5000.00, 'Inscripción anual primaria'),
    ('colegiatura', 4000.00, 'Colegiatura mensual primaria'),
    ('material',    1200.00, 'Paquete de materiales primaria'),
    ('uniforme',    1500.00, 'Uniforme escolar primaria')
) AS t(concepto, monto, descripcion)
ON CONFLICT (ciclo_id, nivel_id, concepto) DO NOTHING;

INSERT INTO tarifa (ciclo_id, nivel_id, concepto, monto, descripcion)
SELECT (SELECT ciclo_id FROM ciclo_escolar  WHERE nombre = '2026-2027'),
       (SELECT nivel_id FROM nivel_educativo WHERE codigo = 'SECUNDARIA'),
       concepto, monto, descripcion
FROM (VALUES
    ('inscripcion', 6000.00, 'Inscripción anual secundaria'),
    ('colegiatura', 4500.00, 'Colegiatura mensual secundaria'),
    ('material',    1500.00, 'Paquete de materiales secundaria'),
    ('uniforme',    1800.00, 'Uniforme escolar secundaria')
) AS t(concepto, monto, descripcion)
ON CONFLICT (ciclo_id, nivel_id, concepto) DO NOTHING;

-- =====================================================================
-- BLOQUE 6  Tutores (6: 5 originales + Lucía del Caso 1)
-- =====================================================================
INSERT INTO tutor (nombre_completo, rfc, curp, correo_electronico, telefono,
                   direccion, direccion_fiscal, codigo_postal,
                   regimen_fiscal, uso_cfdi, correo_facturacion,
                   requiere_factura, tipo_pago_habitual) VALUES
    -- Roberto Mendoza Hernández (padre de Sofía y Diego, ex-esposo de Lucía)
    ('Roberto Mendoza Hernández',
     'MEHR780815KL2', 'MEHR780815HVZNRB04',
     'roberto.mendoza@correo.com', '9211223344',
     'Av. Ignacio Zaragoza 1245, Col. Centro, Coatzacoalcos, Ver.',
     'Av. Ignacio Zaragoza 1245, Col. Centro, Coatzacoalcos, Ver.',
     '96400', '612', 'G03',
     'roberto.mendoza@correo.com', TRUE, 'transferencia'),

    -- Lucía López Vargas (madre de Sofía y Diego, custodia compartida — Caso 1)
    ('Lucía López Vargas',
     'LOVL850623K94', 'LOVL850623MVZPRR04',
     'lucia.lopez@correo.com', '9211889900',
     'Calle Laurel 156, Col. Las Flores, Coatzacoalcos, Ver.',
     NULL, '96510', '605', NULL, NULL, FALSE, 'transferencia'),

    ('Carmen Aguilar Vásquez',
     'AUVC820923P89', 'AUVC820923MVZGSR05',
     'carmen.aguilar@correo.com', '9212334455',
     'Calle 5 de Mayo 89, Col. Petrolera, Coatzacoalcos, Ver.',
     NULL, '96500', '605', NULL, NULL, FALSE, 'tarjeta'),

    ('Jorge González Ramírez',
     'GORJ750412B71', 'GORJ750412HVZNMR03',
     'jorge.gonzalez@correo.com', '9213445566',
     'Av. Universidad 567, Col. Brisas del Mar, Coatzacoalcos, Ver.',
     NULL, '96535', '605', NULL, NULL, FALSE, 'transferencia'),

    ('Patricia Soto Reyes',
     'SORP880706L23', 'SORP880706MVZTYT09',
     'patricia.soto@correo.com', '9214556677',
     'Calle Cedros 234, Col. Lomas de Barrillas, Coatzacoalcos, Ver.',
     'Calle Cedros 234, Col. Lomas de Barrillas, Coatzacoalcos, Ver.',
     '96560', '612', 'G03',
     'patricia.soto@correo.com', TRUE, 'deposito'),

    ('Miguel Ángel Castro Domínguez',
     'CADM850217X42', 'CADM850217HVZSRG01',
     'miguel.castro@correo.com', '9215667788',
     'Av. Carranza 1789, Col. Independencia, Coatzacoalcos, Ver.',
     NULL, '96440', '605', NULL, NULL, FALSE, 'efectivo')
ON CONFLICT (rfc) DO NOTHING;

-- =====================================================================
-- BLOQUE 7  Alumnos
-- =====================================================================
INSERT INTO alumno (matricula, curp, nombre_completo, fecha_nacimiento, sexo,
                    nivel_id, dia_limite_pago, personas_autorizadas) VALUES
    ('SDM-2022-0001', 'MELS170512MVZNPF01',
     'Sofía Mendoza López', '2017-05-12', 'F',
     (SELECT nivel_id FROM nivel_educativo WHERE codigo='PRIMARIA'), NULL,
     '[{"nombre":"Roberto Mendoza Hernández","parentesco":"padre"},{"nombre":"Lucía López Vargas","parentesco":"madre"}]'::jsonb),

    ('SDM-2020-0001', 'MELD140315HVZNPG07',
     'Diego Mendoza López', '2014-03-15', 'M',
     (SELECT nivel_id FROM nivel_educativo WHERE codigo='SECUNDARIA'), NULL,
     '[{"nombre":"Roberto Mendoza Hernández","parentesco":"padre"},{"nombre":"Lucía López Vargas","parentesco":"madre"}]'::jsonb),

    ('SDM-2023-0001', 'ROAV180220MVZMGL05',
     'Valeria Romero Aguilar', '2018-02-20', 'F',
     (SELECT nivel_id FROM nivel_educativo WHERE codigo='PRIMARIA'), NULL,
     '[{"nombre":"Carmen Aguilar Vásquez","parentesco":"madre"}]'::jsonb),

    ('SDM-2021-0001', 'ROAS150408HVZMGB02',
     'Sebastián Romero Aguilar', '2015-04-08', 'M',
     (SELECT nivel_id FROM nivel_educativo WHERE codigo='PRIMARIA'), NULL,
     '[{"nombre":"Carmen Aguilar Vásquez","parentesco":"madre"}]'::jsonb),

    ('SDM-2019-0001', 'GORJ130715HVZNZR03',
     'Jorge Andrés González Ruiz', '2013-07-15', 'M',
     (SELECT nivel_id FROM nivel_educativo WHERE codigo='SECUNDARIA'), 10,
     '[{"nombre":"Jorge González Ramírez","parentesco":"padre"}]'::jsonb),

    ('SDM-2024-0001', 'SOPD190422MVZTRN08',
     'Daniela Soto Pérez', '2019-04-22', 'F',
     (SELECT nivel_id FROM nivel_educativo WHERE codigo='PRIMARIA'), NULL,
     '[{"nombre":"Patricia Soto Reyes","parentesco":"madre"}]'::jsonb),

    ('SDM-2022-0002', 'SOPN160830MVZTRT02',
     'Natalia Soto Pérez', '2016-08-30', 'F',
     (SELECT nivel_id FROM nivel_educativo WHERE codigo='PRIMARIA'), NULL,
     '[{"nombre":"Patricia Soto Reyes","parentesco":"madre"}]'::jsonb),

    ('SDM-2020-0002', 'SOPE140111HVZTRM05',
     'Emiliano Soto Pérez', '2014-01-11', 'M',
     (SELECT nivel_id FROM nivel_educativo WHERE codigo='SECUNDARIA'), NULL,
     '[{"nombre":"Patricia Soto Reyes","parentesco":"madre"}]'::jsonb),

    ('SDM-2022-0003', 'CAHC170305MVZSRM06',
     'Camila Castro Hernández', '2017-03-05', 'F',
     (SELECT nivel_id FROM nivel_educativo WHERE codigo='PRIMARIA'), NULL,
     '[{"nombre":"Miguel Ángel Castro Domínguez","parentesco":"padre"}]'::jsonb),

    ('SDM-2018-0001', 'CAHA111018HVZSRD01',
     'Adrián Castro Hernández', '2011-10-18', 'M',
     (SELECT nivel_id FROM nivel_educativo WHERE codigo='SECUNDARIA'), NULL,
     '[{"nombre":"Miguel Ángel Castro Domínguez","parentesco":"padre"}]'::jsonb)
ON CONFLICT (matricula) DO NOTHING;

-- =====================================================================
-- BLOQUE 8  Tutor-Alumno (N:M, 12 vínculos: 10 base + 2 Caso 1 Lucía)
-- =====================================================================
INSERT INTO tutor_alumno (tutor_id, alumno_id, tipo_relacion,
                          es_responsable_financiero, puede_recoger, recibe_notificaciones)
SELECT
    (SELECT tutor_id  FROM tutor  WHERE rfc = t.rfc),
    (SELECT alumno_id FROM alumno WHERE matricula = t.matricula),
    t.tipo_relacion, t.es_resp_fin, t.puede_recoger, t.recibe_notif
FROM (VALUES
    -- Caso 1: Sofía y Diego con DOS tutores (padre responsable + madre acompañante)
    ('MEHR780815KL2', 'SDM-2022-0001', 'padre', TRUE,  TRUE, TRUE),
    ('MEHR780815KL2', 'SDM-2020-0001', 'padre', TRUE,  TRUE, TRUE),
    ('LOVL850623K94', 'SDM-2022-0001', 'madre', FALSE, TRUE, TRUE),
    ('LOVL850623K94', 'SDM-2020-0001', 'madre', FALSE, TRUE, TRUE),
    -- Resto: un solo tutor responsable financiero por alumno
    ('AUVC820923P89', 'SDM-2023-0001', 'madre', TRUE, TRUE, TRUE),
    ('AUVC820923P89', 'SDM-2021-0001', 'madre', TRUE, TRUE, TRUE),
    ('GORJ750412B71', 'SDM-2019-0001', 'padre', TRUE, TRUE, TRUE),
    ('SORP880706L23', 'SDM-2024-0001', 'madre', TRUE, TRUE, TRUE),
    ('SORP880706L23', 'SDM-2022-0002', 'madre', TRUE, TRUE, TRUE),
    ('SORP880706L23', 'SDM-2020-0002', 'madre', TRUE, TRUE, TRUE),
    ('CADM850217X42', 'SDM-2022-0003', 'padre', TRUE, TRUE, TRUE),
    ('CADM850217X42', 'SDM-2018-0001', 'padre', TRUE, TRUE, TRUE)
) AS t(rfc, matricula, tipo_relacion, es_resp_fin, puede_recoger, recibe_notif)
ON CONFLICT (tutor_id, alumno_id) DO NOTHING;

-- =====================================================================
-- BLOQUE 9  Inscripciones al ciclo activo
-- =====================================================================
INSERT INTO inscripcion_ciclo (alumno_id, ciclo_id, grupo_id, plan_pago, fecha_ingreso, estado_en_ciclo)
SELECT
    (SELECT alumno_id FROM alumno WHERE matricula = m.matricula),
    (SELECT ciclo_id  FROM ciclo_escolar WHERE nombre = '2026-2027'),
    (SELECT grupo_id  FROM grupo
        WHERE nombre = m.grupo
          AND ciclo_id = (SELECT ciclo_id FROM ciclo_escolar WHERE nombre = '2026-2027')),
    m.plan, '2026-08-03', 'activa'
FROM (VALUES
    ('SDM-2022-0001', '4°A Primaria',   '12_meses'),
    ('SDM-2020-0001', '1°A Secundaria', '12_meses'),
    ('SDM-2023-0001', '3°A Primaria',   '10_meses'),
    ('SDM-2021-0001', '6°A Primaria',   '10_meses'),
    ('SDM-2019-0001', '2°A Secundaria', '10_meses'),
    ('SDM-2024-0001', '2°A Primaria',   '10_meses'),
    ('SDM-2022-0002', '5°A Primaria',   '10_meses'),
    ('SDM-2020-0002', '1°A Secundaria', '10_meses'),
    ('SDM-2022-0003', '4°A Primaria',   '12_meses'),
    ('SDM-2018-0001', '3°A Secundaria', '12_meses')
) AS m(matricula, grupo, plan)
ON CONFLICT (alumno_id, ciclo_id) DO NOTHING;

-- =====================================================================
-- BLOQUE 10  Asignación de becas
-- =====================================================================
INSERT INTO asignacion_beca (alumno_id, beca_id, ciclo_id, asignada_por)
SELECT
    (SELECT alumno_id FROM alumno WHERE matricula = b.matricula),
    (SELECT beca_id   FROM beca   WHERE nombre_beca = b.beca),
    (SELECT ciclo_id  FROM ciclo_escolar WHERE nombre = '2026-2027'),
    (SELECT usuario_id FROM usuario WHERE nombre_usuario = 'elizabeth.mendoza')
FROM (VALUES
    ('SDM-2024-0001', 'Beca por hermanos'),
    ('SDM-2022-0002', 'Beca por hermanos'),
    ('SDM-2020-0002', 'Beca por hermanos'),
    ('SDM-2020-0001', 'Excelencia académica')
) AS b(matricula, beca)
ON CONFLICT (alumno_id, beca_id, ciclo_id) DO NOTHING;

-- =====================================================================
-- BLOQUE 11  Calendario de pagos (Diego y Sofía)
-- =====================================================================
INSERT INTO calendario_pago (alumno_id, ciclo_id, concepto, mes, fecha_vencimiento, monto_original)
SELECT
    (SELECT alumno_id FROM alumno WHERE matricula = 'SDM-2020-0001'),
    (SELECT ciclo_id  FROM ciclo_escolar WHERE nombre = '2026-2027'),
    'colegiatura', mes, fecha_venc, 4500.00
FROM (VALUES
    ('agosto',     '2026-08-05'::date), ('septiembre', '2026-09-05'::date),
    ('octubre',    '2026-10-05'::date), ('noviembre',  '2026-11-05'::date),
    ('diciembre',  '2026-12-05'::date), ('enero',      '2027-01-05'::date),
    ('febrero',    '2027-02-05'::date), ('marzo',      '2027-03-05'::date),
    ('abril',      '2027-04-05'::date), ('mayo',       '2027-05-05'::date)
) AS m(mes, fecha_venc)
ON CONFLICT (alumno_id, ciclo_id, concepto, mes) DO NOTHING;

INSERT INTO calendario_pago (alumno_id, ciclo_id, concepto, mes, fecha_vencimiento, monto_original)
SELECT
    (SELECT alumno_id FROM alumno WHERE matricula = 'SDM-2022-0001'),
    (SELECT ciclo_id  FROM ciclo_escolar WHERE nombre = '2026-2027'),
    'colegiatura', mes, fecha_venc, 4000.00
FROM (VALUES
    ('agosto',     '2026-08-05'::date), ('septiembre', '2026-09-05'::date),
    ('octubre',    '2026-10-05'::date), ('noviembre',  '2026-11-05'::date),
    ('diciembre',  '2026-12-05'::date), ('enero',      '2027-01-05'::date),
    ('febrero',    '2027-02-05'::date), ('marzo',      '2027-03-05'::date),
    ('abril',      '2027-04-05'::date), ('mayo',       '2027-05-05'::date)
) AS m(mes, fecha_venc)
ON CONFLICT (alumno_id, ciclo_id, concepto, mes) DO NOTHING;

-- =====================================================================
-- BLOQUE 12  Pagos transaccionales con auditoría
-- =====================================================================

-- Pago 1: Diego, septiembre, puntual, registra Elizabeth (usuario 1)
BEGIN;
SET LOCAL "sae.usuario_id"   = '1';
SET LOCAL "sae.direccion_ip" = '127.0.0.1';

WITH nuevo_pago AS (
    INSERT INTO pago (alumno_id, tutor_id, fecha_pago, monto_total, metodo_pago,
                      observaciones, registrado_por)
    SELECT
        (SELECT alumno_id FROM alumno WHERE matricula = 'SDM-2020-0001'),
        (SELECT tutor_id  FROM tutor  WHERE rfc = 'MEHR780815KL2'),
        '2026-09-04', 4500.00, 'transferencia',
        'Colegiatura septiembre 2026 - pago puntual (Roberto)',
        (SELECT usuario_id FROM usuario WHERE nombre_usuario = 'elizabeth.mendoza')
    RETURNING pago_id
)
INSERT INTO aplicacion_pago (pago_id, calendario_pago_id, monto_aplicado, aplicado_a)
SELECT np.pago_id, cp.calendario_pago_id, 4500.00, 'capital'
FROM nuevo_pago np, calendario_pago cp
WHERE cp.alumno_id = (SELECT alumno_id FROM alumno WHERE matricula = 'SDM-2020-0001')
  AND cp.concepto = 'colegiatura' AND cp.mes = 'septiembre';

UPDATE calendario_pago
SET monto_pagado = 4500.00, estado_cobro = 'pagado',
    liquidado_at = '2026-09-04 10:30:00-06'
WHERE alumno_id = (SELECT alumno_id FROM alumno WHERE matricula = 'SDM-2020-0001')
  AND concepto = 'colegiatura' AND mes = 'septiembre';
COMMIT;

-- Pago 2: Sofía, octubre con recargo $400, registra Elizabeth
BEGIN;
SET LOCAL "sae.usuario_id"   = '1';
SET LOCAL "sae.direccion_ip" = '127.0.0.1';

UPDATE calendario_pago
SET monto_recargo = 400.00
WHERE alumno_id = (SELECT alumno_id FROM alumno WHERE matricula = 'SDM-2022-0001')
  AND concepto = 'colegiatura' AND mes = 'octubre';

INSERT INTO recargo (calendario_pago_id, monto_original, monto_actual, estado, aplicado_en)
SELECT calendario_pago_id, 400.00, 400.00, 'aplicado', '2026-10-06'
FROM calendario_pago
WHERE alumno_id = (SELECT alumno_id FROM alumno WHERE matricula = 'SDM-2022-0001')
  AND concepto = 'colegiatura' AND mes = 'octubre';

WITH nuevo_pago AS (
    INSERT INTO pago (alumno_id, tutor_id, fecha_pago, monto_total, metodo_pago,
                      observaciones, registrado_por)
    SELECT
        (SELECT alumno_id FROM alumno WHERE matricula = 'SDM-2022-0001'),
        (SELECT tutor_id  FROM tutor  WHERE rfc = 'MEHR780815KL2'),
        '2026-10-08', 4400.00, 'deposito',
        'Colegiatura octubre 2026 - tardía, recargo $400 (Roberto)',
        (SELECT usuario_id FROM usuario WHERE nombre_usuario = 'elizabeth.mendoza')
    RETURNING pago_id
)
INSERT INTO aplicacion_pago (pago_id, calendario_pago_id, monto_aplicado, aplicado_a)
SELECT np.pago_id, cp.calendario_pago_id, monto, tipo
FROM nuevo_pago np, calendario_pago cp,
     (VALUES (4000.00, 'capital'), (400.00, 'recargo')) AS d(monto, tipo)
WHERE cp.alumno_id = (SELECT alumno_id FROM alumno WHERE matricula = 'SDM-2022-0001')
  AND cp.concepto = 'colegiatura' AND cp.mes = 'octubre';

UPDATE calendario_pago
SET monto_pagado = 4400.00, estado_cobro = 'pagado',
    liquidado_at = '2026-10-08 14:15:00-06'
WHERE alumno_id = (SELECT alumno_id FROM alumno WHERE matricula = 'SDM-2022-0001')
  AND concepto = 'colegiatura' AND mes = 'octubre';
COMMIT;

-- Pago 3: Sofía, noviembre, abono parcial $2000, registra Laura (usuario 3)
BEGIN;
SET LOCAL "sae.usuario_id"   = '3';
SET LOCAL "sae.direccion_ip" = '127.0.0.1';

WITH nuevo_pago AS (
    INSERT INTO pago (alumno_id, tutor_id, fecha_pago, monto_total, metodo_pago,
                      observaciones, registrado_por)
    SELECT
        (SELECT alumno_id FROM alumno WHERE matricula = 'SDM-2022-0001'),
        (SELECT tutor_id  FROM tutor  WHERE rfc = 'MEHR780815KL2'),
        '2026-11-04', 2000.00, 'efectivo',
        'Abono parcial colegiatura noviembre 2026 (Roberto)',
        (SELECT usuario_id FROM usuario WHERE nombre_usuario = 'laura.rios')
    RETURNING pago_id
)
INSERT INTO aplicacion_pago (pago_id, calendario_pago_id, monto_aplicado, aplicado_a)
SELECT np.pago_id, cp.calendario_pago_id, 2000.00, 'capital'
FROM nuevo_pago np, calendario_pago cp
WHERE cp.alumno_id = (SELECT alumno_id FROM alumno WHERE matricula = 'SDM-2022-0001')
  AND cp.concepto = 'colegiatura' AND cp.mes = 'noviembre';

UPDATE calendario_pago
SET monto_pagado = 2000.00, estado_cobro = 'parcial'
WHERE alumno_id = (SELECT alumno_id FROM alumno WHERE matricula = 'SDM-2022-0001')
  AND concepto = 'colegiatura' AND mes = 'noviembre';
COMMIT;

-- Pago 4: Caso 1 — Lucía paga agosto de Diego. Demuestra N:M en acción.
BEGIN;
SET LOCAL "sae.usuario_id"   = '1';
SET LOCAL "sae.direccion_ip" = '127.0.0.1';

WITH nuevo_pago AS (
    INSERT INTO pago (alumno_id, tutor_id, fecha_pago, monto_total, metodo_pago,
                      observaciones, registrado_por)
    SELECT
        (SELECT alumno_id FROM alumno WHERE matricula = 'SDM-2020-0001'),
        (SELECT tutor_id  FROM tutor  WHERE rfc = 'LOVL850623K94'),
        '2026-08-03', 4500.00, 'transferencia',
        'Colegiatura agosto 2026 de Diego pagada por Lucía (madre, custodia compartida)',
        (SELECT usuario_id FROM usuario WHERE nombre_usuario = 'elizabeth.mendoza')
    RETURNING pago_id
)
INSERT INTO aplicacion_pago (pago_id, calendario_pago_id, monto_aplicado, aplicado_a)
SELECT np.pago_id, cp.calendario_pago_id, 4500.00, 'capital'
FROM nuevo_pago np, calendario_pago cp
WHERE cp.alumno_id = (SELECT alumno_id FROM alumno WHERE matricula = 'SDM-2020-0001')
  AND cp.concepto = 'colegiatura' AND cp.mes = 'agosto';

UPDATE calendario_pago
SET monto_pagado = 4500.00, estado_cobro = 'pagado',
    liquidado_at = '2026-08-03 09:00:00-06'
WHERE alumno_id = (SELECT alumno_id FROM alumno WHERE matricula = 'SDM-2020-0001')
  AND concepto = 'colegiatura' AND mes = 'agosto';
COMMIT;

-- =====================================================================
-- BLOQUE 13  Verificación final
-- =====================================================================
DO $$
DECLARE
    v_ciclos      INT; v_usuarios INT; v_roles_asig INT; v_tutores INT;
    v_alumnos     INT; v_vinculos  INT; v_grupos     INT; v_inscrip INT;
    v_pagos       INT; v_calend    INT; v_logs       INT;
BEGIN
    SELECT COUNT(*) INTO v_ciclos      FROM ciclo_escolar;
    SELECT COUNT(*) INTO v_usuarios    FROM usuario;
    SELECT COUNT(*) INTO v_roles_asig  FROM usuario_rol;
    SELECT COUNT(*) INTO v_tutores     FROM tutor;
    SELECT COUNT(*) INTO v_alumnos     FROM alumno;
    SELECT COUNT(*) INTO v_vinculos    FROM tutor_alumno;
    SELECT COUNT(*) INTO v_grupos      FROM grupo;
    SELECT COUNT(*) INTO v_inscrip     FROM inscripcion_ciclo;
    SELECT COUNT(*) INTO v_pagos       FROM pago;
    SELECT COUNT(*) INTO v_calend      FROM calendario_pago;
    SELECT COUNT(*) INTO v_logs        FROM log_auditoria;

    RAISE NOTICE '====== Datos de prueba v5 cargados (Coatzacoalcos, Ver.) ======';
    RAISE NOTICE 'Ciclos:                %', v_ciclos;
    RAISE NOTICE 'Usuarios:              %', v_usuarios;
    RAISE NOTICE 'Asignaciones rol:      %', v_roles_asig;
    RAISE NOTICE 'Tutores:               % (incluye a Lucía López del Caso 1)', v_tutores;
    RAISE NOTICE 'Alumnos:               %', v_alumnos;
    RAISE NOTICE 'Vínculos tutor-alumno: % (12 esperados: 10 base + 2 de Lucía)', v_vinculos;
    RAISE NOTICE 'Grupos:                %', v_grupos;
    RAISE NOTICE 'Inscripciones:         %', v_inscrip;
    RAISE NOTICE 'Calendarios de pago:   %', v_calend;
    RAISE NOTICE 'Pagos:                 % (4 esperados: 3 base + 1 de Lucía)', v_pagos;
    RAISE NOTICE 'Entradas log_auditoria: %', v_logs;
    RAISE NOTICE '==============================================================';
END $$;

-- =====================================================================
-- FIN del archivo 05_datos_prueba.sql v5
-- =====================================================================
