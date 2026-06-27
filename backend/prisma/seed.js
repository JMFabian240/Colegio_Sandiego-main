/**
 * SAE — Seed de Base de Datos (PostgreSQL v6)
 * Carga datos iniciales para desarrollo y pruebas.
 *
 * Ejecutar con: npm run db:seed   (o npx prisma db seed)
 *
 * IMPORTANTE: Este seed asume que los SQL de init-db ya corrieron vía Docker
 * (01_esquema_base.sql, 02_configuracion.sql, 03_roles.sql ...).
 * El seed Prisma complementa con datos de prueba Prisma-nativos.
 * Si la BD está vacía, el seed crea todo desde cero.
 */

'use strict';

require('dotenv').config();

const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient({
  log: process.env.NODE_ENV === 'development' ? ['warn', 'error'] : ['error'],
});

async function main() {
  console.log('\n[SEED] ═══════════════════════════════════════════════');
  console.log('[SEED] Iniciando seed PostgreSQL v6 — SAE Colegio San Diego');
  console.log('[SEED] ═══════════════════════════════════════════════\n');

  const passwordHash = await bcrypt.hash('sandiego', 8);

  // ── 1. Niveles educativos ─────────────────────────────────────
  console.log('[SEED] [1/7] Niveles educativos...');
  const nivelesData = [
    { codigo: 'PREESCOLAR', nombre: 'Preescolar', orden: 1 },
    { codigo: 'PRIMARIA', nombre: 'Primaria', orden: 2 },
    { codigo: 'SECUNDARIA', nombre: 'Secundaria', orden: 3 },
    { codigo: 'BACHILLERATO', nombre: 'Bachillerato', orden: 4 },
  ];

  const niveles = [];
  for (const nd of nivelesData) {
    const nivel = await prisma.nivelEducativo.upsert({
      where: { codigo: nd.codigo },
      update: {},
      create: nd,
    });
    niveles.push(nivel);
  }
  const nivelMap = Object.fromEntries(niveles.map(n => [n.codigo, n]));
  console.log(`[SEED]   ✓ ${niveles.length} niveles`);

  // ── 2. Roles del sistema ──────────────────────────────────────
  console.log('[SEED] [2/7] Roles del sistema...');
  const rolesData = [
    { codigo: 'administrador', nombre: 'Administrador', descripcion: 'Acceso total al sistema' },
    { codigo: 'directora', nombre: 'Directora', descripcion: 'Dirección académica' },
    { codigo: 'empleado', nombre: 'Empleado', descripcion: 'Gestión administrativa' },
    { codigo: 'docente', nombre: 'Docente', descripcion: 'Registro de calificaciones' },
  ];

  const roles = [];
  for (const rd of rolesData) {
    const rol = await prisma.rol.upsert({
      where: { codigo: rd.codigo },
      update: {},
      create: rd,
    });
    roles.push(rol);
  }
  const rolMap = Object.fromEntries(roles.map(r => [r.codigo, r]));
  console.log(`[SEED]   ✓ ${roles.length} roles`);

  // ── 3. Configuración del sistema ──────────────────────────────
  console.log('[SEED] [3/7] Configuración del sistema...');
  // Nota: @@unique([clave, cicloId]) — no podemos usar upsert con clave sola.
  // Usamos findFirst + create para idempotencia.
  const configuraciones = [
    { clave: 'recargo_colegiatura_monto', valor: '400', tipoDato: 'int', descripcion: 'Monto del recargo por pago tardío de colegiatura (MXN)' },
    { clave: 'recargo_dia_tope_mes', valor: '5', tipoDato: 'int', descripcion: 'Día límite del mes para pago sin recargo' },
    { clave: 'baja_temporal_meses_adeudo', valor: '3', tipoDato: 'int', descripcion: 'Meses de adeudo para baja temporal automática' },
    { clave: 'login_max_intentos', valor: '5', tipoDato: 'int', descripcion: 'Máximo de intentos de login fallidos antes de bloqueo' },
    { clave: 'login_minutos_bloqueo', valor: '30', tipoDato: 'int', descripcion: 'Minutos de bloqueo tras superar intentos máximos' },
    { clave: 'backup_retener_dias', valor: '30', tipoDato: 'int', descripcion: 'Días de retención de respaldos automáticos' },
    { clave: 'sistema_nombre', valor: 'SAE Colegio San Diego', tipoDato: 'string', descripcion: 'Nombre del sistema' },
    { clave: 'sistema_version', valor: '2.0.0', tipoDato: 'string', descripcion: 'Versión del sistema' },
  ];

  for (const cfg of configuraciones) {
    // Buscar config global (cicloId null) con esa clave
    const existente = await prisma.configuracionSistema.findFirst({
      where: { clave: cfg.clave, cicloId: null },
    });
    if (!existente) {
      await prisma.configuracionSistema.create({ data: { ...cfg, cicloId: null } });
    }
  }
  console.log(`[SEED]   ✓ ${configuraciones.length} parámetros de configuración`);

  // ── 4. Usuarios del sistema ───────────────────────────────────
  console.log('[SEED] [4/7] Usuarios y roles...');

  const usuariosData = [
    { nombreUsuario: 'elizabeth.mendoza', nombreCompleto: 'Elizabeth Mendoza', correo: 'elizabeth.mendoza@colegiosandiego.edu.mx', roles: ['administrador'] },
    { nombreUsuario: 'maria.dolores', nombreCompleto: 'María Dolores Vega', correo: 'maria.dolores@colegiosandiego.edu.mx', roles: ['directora'] },
    { nombreUsuario: 'patricia.nunez', nombreCompleto: 'Patricia Núñez', correo: null, roles: ['empleado'] },
    { nombreUsuario: 'laura.rios', nombreCompleto: 'Laura Ríos', correo: 'laura.rios@colegiosandiego.edu.mx', roles: ['empleado', 'docente'] },
    { nombreUsuario: 'mario.sanchez', nombreCompleto: 'Mario Sánchez', correo: 'mario.sanchez@colegiosandiego.edu.mx', roles: ['docente'] },
  ];

  const usuarioMap = {};
  for (const ud of usuariosData) {
    const usuario = await prisma.usuario.upsert({
      where: { nombreUsuario: ud.nombreUsuario },
      update: {
        passwordHash,
        activo: true,
        intentosFallidos: 0,
        bloqueadoHasta: null
      },
      create: {
        nombreUsuario: ud.nombreUsuario,
        nombreCompleto: ud.nombreCompleto,
        correo: ud.correo,
        passwordHash,
        activo: true,
      },
    });
    usuarioMap[ud.nombreUsuario] = usuario;

    // Asignar roles
    for (const codigoRol of ud.roles) {
      const rolReg = rolMap[codigoRol];
      if (rolReg) {
        await prisma.usuarioRol.upsert({
          where: { usuarioId_rolId: { usuarioId: usuario.usuarioId, rolId: rolReg.rolId } },
          update: { activo: true },
          create: { usuarioId: usuario.usuarioId, rolId: rolReg.rolId, activo: true },
        });
      }
    }
  }
  console.log(`[SEED]   ✓ ${usuariosData.length} usuarios con roles`);

  // ── 5. Ciclo escolar y planes de pago ─────────────────────────
  console.log('[SEED] [5/7] Ciclo escolar y planes de pago...');

  const ciclo = await prisma.cicloEscolar.upsert({
    where: { nombre: 'Ciclo 2026-2027' },
    update: { activo: true },
    create: {
      nombre: 'Ciclo 2026-2027',
      fechaInicio: new Date('2026-08-01'),
      fechaFin: new Date('2027-07-31'),
      activo: true,
    },
  });

  // Planes de pago (montoMensual y montoDiciembre son requeridos en el schema)
  const planesData = [
    { nombre: 'Plan 10 meses', meses: 10, montoMensual: 4000, montoDiciembre: 8000 },
    { nombre: 'Plan 12 meses', meses: 12, montoMensual: 3500, montoDiciembre: 7000 },
    { nombre: 'Pago anual', meses: 1, montoMensual: 40000, montoDiciembre: 40000 },
  ];

  const planes = [];
  for (const pd of planesData) {
    const plan = await prisma.planPago.upsert({
      where: { cicloId_nombre: { cicloId: ciclo.cicloId, nombre: pd.nombre } },
      update: {},
      create: {
        cicloId: ciclo.cicloId,
        nombre: pd.nombre,
        meses: pd.meses,
        montoMensual: pd.montoMensual,
        montoDiciembre: pd.montoDiciembre,
        activo: true,
      },
    });
    planes.push(plan);
  }
  console.log(`[SEED]   ✓ Ciclo ${ciclo.nombre}, ${planes.length} planes de pago`);

  // ── 6. Grupos y materias ──────────────────────────────────────
  console.log('[SEED] [6/7] Grupos y materias...');

  // Grupos con grado+seccion (requeridos por el schema PostgreSQL)
  const gruposData = [
    {
      nombre: '4°A Primaria', grado: '4', seccion: 'A',
      nivelCodigo: 'PRIMARIA',
      titularNombreUsuario: 'laura.rios',
      materias: [
        { nombre: 'Matemáticas', docenteNombreUsuario: 'laura.rios', horario: 'Lun-Vie 8:00-9:00', aula: 'A-101' },
        { nombre: 'Español', docenteNombreUsuario: 'laura.rios', horario: 'Lun-Vie 9:00-10:00', aula: 'A-101' },
        { nombre: 'Ciencias Naturales', docenteNombreUsuario: 'laura.rios', horario: 'Lun-Mié 10:30-11:30', aula: 'A-101' },
        { nombre: 'Inglés', docenteNombreUsuario: null, horario: 'Mar-Jue 11:30-12:30', aula: 'C-301' },
        { nombre: 'Educación Física', docenteNombreUsuario: null, horario: 'Vie 12:00-13:00', aula: 'Cancha' },
      ],
    },
    {
      nombre: '5°B Secundaria', grado: '5', seccion: 'B',
      nivelCodigo: 'SECUNDARIA',
      titularNombreUsuario: 'mario.sanchez',
      materias: [
        { nombre: 'Matemáticas III', docenteNombreUsuario: 'mario.sanchez', horario: 'Lun-Mié-Vie 7:30-8:30', aula: 'S-205' },
        { nombre: 'Español III', docenteNombreUsuario: null, horario: 'Mar-Jue 8:30-9:30', aula: 'S-205' },
        { nombre: 'Historia de México', docenteNombreUsuario: null, horario: 'Lun-Mié 9:30-10:30', aula: 'S-205' },
        { nombre: 'Biología', docenteNombreUsuario: null, horario: 'Mar-Jue 10:30-11:30', aula: 'Lab-B' },
        { nombre: 'Inglés Intermedio', docenteNombreUsuario: null, horario: 'Vie 9:30-11:00', aula: 'C-301' },
      ],
    },
    {
      nombre: '2° Bachillerato A', grado: '2', seccion: 'A',
      nivelCodigo: 'BACHILLERATO',
      titularNombreUsuario: null,
      materias: [
        { nombre: 'Cálculo', docenteNombreUsuario: null, horario: 'Lun-Mié-Vie 7:00-8:00', aula: 'B-101' },
        { nombre: 'Física II', docenteNombreUsuario: null, horario: 'Mar-Jue 8:00-9:30', aula: 'Lab-F' },
      ],
    },
    {
      nombre: '3° Bachillerato B', grado: '3', seccion: 'B',
      nivelCodigo: 'BACHILLERATO',
      titularNombreUsuario: null,
      materias: [
        { nombre: 'Química Orgánica', docenteNombreUsuario: null, horario: 'Lun-Mié 7:00-8:30', aula: 'Lab-Q' },
        { nombre: 'Literatura', docenteNombreUsuario: null, horario: 'Mar-Jue 9:00-10:00', aula: 'B-203' },
      ],
    },
  ];

  const grupoMap = {};
  for (const gd of gruposData) {
    const nivelReg = nivelMap[gd.nivelCodigo];
    const titularReg = gd.titularNombreUsuario ? usuarioMap[gd.titularNombreUsuario] : null;

    // Upsert grupo por nombre + ciclo
    let grupo = await prisma.grupo.findFirst({
      where: { nombre: gd.nombre, cicloId: ciclo.cicloId, eliminadoEn: null },
    });

    if (!grupo) {
      grupo = await prisma.grupo.create({
        data: {
          nombre: gd.nombre,
          grado: gd.grado,
          seccion: gd.seccion,
          nivelId: nivelReg.nivelId,
          cicloId: ciclo.cicloId,
          docenteTitularId: titularReg?.usuarioId ?? null,
        },
      });
    }

    grupoMap[gd.nombre] = grupo;

    // Crear materias del grupo
    for (const mat of gd.materias) {
      // Upsert materia en catálogo (unique: nivelId + nombre + tipo)
      let materiaReg = await prisma.materia.findFirst({
        where: { nombre: mat.nombre, nivelId: nivelReg.nivelId, eliminadoEn: null },
      });
      if (!materiaReg) {
        materiaReg = await prisma.materia.create({
          data: {
            nombre: mat.nombre,
            nivelId: nivelReg.nivelId,
            cuentaParaPromedio: true,
          },
        });
      }

      const docenteReg = mat.docenteNombreUsuario ? usuarioMap[mat.docenteNombreUsuario] : null;

      // Upsert grupoMateria (unique: grupoId + materiaId)
      const existente = await prisma.grupoMateria.findFirst({
        where: { grupoId: grupo.grupoId, materiaId: materiaReg.materiaId, eliminadoEn: null },
      });
      if (!existente) {
        await prisma.grupoMateria.create({
          data: {
            grupoId: grupo.grupoId,
            materiaId: materiaReg.materiaId,
            docenteId: docenteReg?.usuarioId ?? null,
            horario: mat.horario ?? null,
            aula: mat.aula ?? null,
          },
        });
      }
    }
  }
  console.log(`[SEED]   ✓ ${Object.keys(grupoMap).length} grupos con materias`);

  // ── 7. Alumnos, tutores e inscripciones ───────────────────────
  console.log('[SEED] [7/7] Alumnos, tutores e inscripciones...');

  const alumnosData = [
    {
      nombre: 'María González Ruiz', matricula: 'SDM-2020-0089', curp: 'GORM140322MDFXXX01',
      nivelCodigo: 'PRIMARIA', grupoNombre: '4°A Primaria',
      tutor: {
        nombre: 'Jorge González', telefono: '5551234567', email: 'jorge@mail.com',
        rfc: 'GOJL800101XXX', correoFacturacion: 'jorge@mail.com'
      },
    },
    {
      nombre: 'Juan Pérez Morales', matricula: 'SDM-2020-0123', curp: 'PEMJ140522HDFXXX01',
      nivelCodigo: 'PRIMARIA', grupoNombre: '4°A Primaria',
      tutor: { nombre: 'Luis Pérez', telefono: '5559876543' },
    },
    {
      nombre: 'Carlos Fernández López', matricula: 'SDM-2019-0412', curp: 'FELC190815HDFXXX01',
      nivelCodigo: 'SECUNDARIA', grupoNombre: '5°B Secundaria',
      tutor: { nombre: 'Ramón Fernández', telefono: '5554567890' },
    },
    {
      nombre: 'Sofía Ramírez Cruz', matricula: 'SDM-2021-0055', curp: null,
      nivelCodigo: 'PRIMARIA', grupoNombre: '4°A Primaria',
      tutor: { nombre: 'Ana Ramírez', telefono: '5552223344' },
    },
    {
      nombre: 'Miguel Torres Gómez', matricula: 'SDM-2022-0099', curp: null,
      nivelCodigo: 'SECUNDARIA', grupoNombre: '5°B Secundaria',
      tutor: { nombre: 'Patricia Gómez', telefono: '5556677889' },
    },
    {
      nombre: 'Ana Lucía Hernández', matricula: 'SDM-2018-0301', curp: null,
      nivelCodigo: 'BACHILLERATO', grupoNombre: '2° Bachillerato A',
      tutor: { nombre: 'Roberto Hernández', telefono: '5557890123' },
    },
    {
      nombre: 'Diego Martínez Soto', matricula: 'SDM-2018-0344', curp: null,
      nivelCodigo: 'BACHILLERATO', grupoNombre: '3° Bachillerato B',
      tutor: { nombre: 'Elena Soto', telefono: '5553456789' },
    },
    {
      nombre: 'Valentina Castro Ruiz', matricula: 'SDM-2019-0277', curp: null,
      nivelCodigo: 'BACHILLERATO', grupoNombre: '2° Bachillerato A',
      tutor: { nombre: 'Mario Castro', telefono: '5556543210' },
    },
  ];

  let alumnosCreados = 0;
  for (const ad of alumnosData) {
    const nivelReg = nivelMap[ad.nivelCodigo];
    const grupoReg = grupoMap[ad.grupoNombre];

    // Upsert alumno
    let alumno = await prisma.alumno.findFirst({ where: { matricula: ad.matricula } });
    if (!alumno) {
      alumno = await prisma.alumno.create({
        data: {
          nombreCompleto: ad.nombre,
          matricula: ad.matricula,
          curp: ad.curp ?? null,
          nivelId: nivelReg.nivelId,
          estado: 'Activo',
        },
      });
      alumnosCreados++;
    }

    // Upsert tutor (buscar por RFC si existe, sino crear)
    let tutor = null;
    if (ad.tutor.rfc) {
      tutor = await prisma.tutor.findFirst({ where: { rfc: ad.tutor.rfc, eliminadoEn: null } });
    }
    if (!tutor) {
      tutor = await prisma.tutor.create({
        data: {
          nombreCompleto: ad.tutor.nombre,
          correoElectronico: ad.tutor.email ?? null,
          telefono: ad.tutor.telefono ?? null,
          rfc: ad.tutor.rfc ?? null,
          correoFacturacion: ad.tutor.correoFacturacion ?? null,
          requiereFactura: !!(ad.tutor.correoFacturacion),
        },
      });
    }

    // Vincular tutor-alumno (unique: tutorId + alumnoId)
    const vinculo = await prisma.tutorAlumno.findFirst({
      where: { tutorId: tutor.tutorId, alumnoId: alumno.alumnoId },
    });
    if (!vinculo) {
      await prisma.tutorAlumno.create({
        data: {
          tutorId: tutor.tutorId,
          alumnoId: alumno.alumnoId,
          tipoRelacion: 'tutor',
          esResponsableFinanciero: true,
          puedeRecoger: true,
          recibeNotificaciones: true,
        },
      });
    }

    // Inscripción en ciclo activo (unique: alumnoId + cicloId)
    if (grupoReg) {
      const inscripcion = await prisma.inscripcionCiclo.findFirst({
        where: { alumnoId: alumno.alumnoId, cicloId: ciclo.cicloId },
      });
      if (!inscripcion) {
        await prisma.inscripcionCiclo.create({
          data: {
            alumnoId: alumno.alumnoId,
            cicloId: ciclo.cicloId,
            grupoId: grupoReg.grupoId,
            planPagoId: planes[0].planPagoId, // Plan 10 meses por defecto
            estadoEnCiclo: 'activa',
            estadoFinanciero: 'al_corriente',
          },
        });
      }
    }
  }

  console.log(`[SEED]   ✓ ${alumnosCreados} alumnos nuevos, ${alumnosData.length} procesados`);

  // ── Resumen final ─────────────────────────────────────────────
  console.log('\n[SEED] ╔══════════════════════════════════════════════════╗');
  console.log('[SEED] ║   SEED COMPLETADO CORRECTAMENTE                  ║');
  console.log('[SEED] ║                                                  ║');
  console.log('[SEED] ║   Credenciales de acceso:                        ║');
  console.log('[SEED] ║   ADMIN    → elizabeth.admin  / sandiego2026     ║');
  console.log('[SEED] ║   ADMIN    → maria.directora  / sandiego2026     ║');
  console.log('[SEED] ║   GESTOR   → gestor.admin     / sandiego2026     ║');
  console.log('[SEED] ║   MAESTRA  → laura.rios       / sandiego2026     ║');
  console.log('[SEED] ║   MAESTRA  → mario.sanchez    / sandiego2026     ║');
  console.log('[SEED] ╚══════════════════════════════════════════════════╝\n');
}

main()
  .catch((e) => {
    console.error('\n[SEED ERROR]', e.message);
    console.error(e.stack);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
