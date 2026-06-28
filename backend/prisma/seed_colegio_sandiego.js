require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { fakerES_MX: faker } = require('@faker-js/faker');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

function getRomano(num) {
  const romanos = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"];
  return romanos[num] || num.toString();
}

function normalizeUsername(firstName, lastName) {
  const clean = (str) => str.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]/g, "");
  return `${clean(firstName)}.${clean(lastName)}`;
}

async function main() {
  console.log('Iniciando inyección de datos (Seed) con Lógica Financiera Estricta...');

  // 1. Limpieza Selectiva DML
  console.log('Limpiando datos previos...');
  await prisma.asistencia.deleteMany();
  await prisma.calificacionExtracurricular.deleteMany();
  await prisma.calificacionTaller.deleteMany();
  await prisma.calificacion.deleteMany();
  await prisma.asignacionBeca.deleteMany();
  await prisma.inscripcionMateria.deleteMany();
  await prisma.inscripcionCiclo.deleteMany();
  await prisma.tutorAlumno.deleteMany();

  await prisma.grupoMateria.deleteMany();
  await prisma.materia.deleteMany();
  await prisma.grupo.deleteMany();

  await prisma.periodoEvaluacion.deleteMany({
    where: { ciclo: { activo: false } }
  });

  await prisma.cicloEscolar.deleteMany({
    where: { activo: false }
  });

  await prisma.calendarioPago.deleteMany();
  await prisma.alumno.deleteMany();
  await prisma.tutor.deleteMany();
  await prisma.planPago.deleteMany();
  await prisma.beca.deleteMany();

  // 2. Obtener Catálogos Base
  const niveles = await prisma.nivelEducativo.findMany();
  const ciclo = await prisma.cicloEscolar.findFirst({ where: { activo: true } });

  if (!ciclo) throw new Error("No hay un ciclo escolar activo.");

  let rolDocente = await prisma.rol.findUnique({ where: { codigo: 'DOCENTE' } });
  if (!rolDocente) rolDocente = await prisma.rol.create({ data: { codigo: 'DOCENTE', nombre: 'Docente' } });

  const configuracionNiveles = [
    { codigo: 'PREESCOLAR', grados: ['1', '2', '3'], materias: [{ base: 'Lenguajes', tipo: 'curricular' }, { base: 'Saberes', tipo: 'curricular' }, { base: 'Inglés', tipo: 'curricular' }] },
    { codigo: 'PRIMARIA', grados: ['1', '2', '3', '4', '5', '6'], materias: [{ base: 'Lenguajes', tipo: 'curricular' }, { base: 'Matemáticas', tipo: 'curricular' }, { base: 'Inglés', tipo: 'curricular' }] },
    { codigo: 'SECUNDARIA', grados: ['1', '2', '3'], materias: [{ base: 'Español', tipo: 'curricular' }, { base: 'Inglés', tipo: 'curricular' }, { base: 'Matemáticas', tipo: 'curricular' }, { base: 'Artes', tipo: 'taller' }] },
    { codigo: 'BACHILLERATO', grados: ['1', '2', '3', '4', '5', '6'], materias: [{ base: 'Pensamiento Matemático', tipo: 'curricular' }, { base: 'Inglés', tipo: 'curricular' }, { base: 'Ciencias Experimentales', tipo: 'curricular' }, { base: 'Humanidades', tipo: 'curricular' }, { base: 'Computación', tipo: 'taller' }] }
  ];

  // 3. Crear Periodos de Evaluación para el ciclo activo (si no existen)
  console.log('Verificando Periodos de Evaluación para ciclo activo...');
  const periodosActivos = [];
  for (const nivel of niveles) {
    let p1 = await prisma.periodoEvaluacion.findFirst({ where: { cicloId: ciclo.cicloId, nivelId: nivel.nivelId, numero: 1 } });
    if (!p1) {
      const cStart = new Date(ciclo.fechaInicio);
      const cEnd = new Date(ciclo.fechaFin);
      const dates = [
        { start: cStart, end: new Date(cStart.getFullYear(), cStart.getMonth() + 3, 15) },
        { start: new Date(cStart.getFullYear(), cStart.getMonth() + 3, 16), end: new Date(cStart.getFullYear(), cStart.getMonth() + 7, 15) },
        { start: new Date(cStart.getFullYear(), cStart.getMonth() + 7, 16), end: cEnd }
      ];
      for (let p = 1; p <= 3; p++) {
        await prisma.periodoEvaluacion.create({
          data: {
            cicloId: ciclo.cicloId,
            nivelId: nivel.nivelId,
            tipo: 'trimestre',
            numero: p,
            nombre: `Trimestre ${p}`,
            fechaInicio: dates[p - 1].start,
            fechaFin: dates[p - 1].end,
            esFinalCiclo: p === 3
          }
        });
      }
    }
    const perNivel = await prisma.periodoEvaluacion.findMany({ where: { cicloId: ciclo.cicloId, nivelId: nivel.nivelId } });
    periodosActivos.push(...perNivel);
  }

  // 3.1 Crear Planes de Pago
  console.log('Creando Planes de Pago...');
  const planesPago = [];
  for (const meses of [10, 12]) {
    const plan = await prisma.planPago.create({
      data: {
        cicloId: ciclo.cicloId,
        nombre: `Plan ${meses} Meses`,
        meses: meses,
        montoMensual: 2500.00,
        montoDiciembre: meses === 10 ? 0 : 2500.00
      }
    });
    planesPago.push(plan);
  }

  // 3.2 Crear Becas
  console.log('Creando Becas...');
  const becasData = [
    { nombreBeca: 'Académica de Excelencia', criterio: 'calificacion', porcentaje: 50.00 },
    { nombreBeca: 'Deportiva Elite', criterio: 'otro', porcentaje: 30.00 },
    { nombreBeca: 'Mérito Cultural', criterio: 'otro', porcentaje: 25.00 }
  ];
  const becas = [];
  for (const b of becasData) {
    const beca = await prisma.beca.create({ data: b });
    becas.push(beca);
  }

  const passwordHash = bcrypt.hashSync("sandiego", 10);

  /* 
  // --- INICIO: Crear usuarios adicionales ---
   console.log('Creando usuarios fijos solicitados...');
   const rolesParaCrear = ['ADMINISTRADOR', 'EMPLEADO', 'DOCENTE'];
   const rolDict = {};
   
   for (const rCode of rolesParaCrear) {
     let rDB = await prisma.rol.findUnique({ where: { codigo: rCode } });
     if (!rDB) {
       rDB = await prisma.rol.create({ data: { codigo: rCode, nombre: rCode.charAt(0) + rCode.slice(1).toLowerCase() } });
     }
     rolDict[rCode] = rDB;
   }
 
   const usuariosEspeciales = [
     { nombreCompleto: 'Elizabeth Mendoza Castro', nombreUsuario: 'elizabeth.mendoza', roles: ['ADMINISTRADOR'] },
     { nombreCompleto: 'María Dolores Pérez Rangel', nombreUsuario: 'maria.dolores', roles: ['ADMINISTRADOR'] },
     { nombreCompleto: 'Laura Ríos Méndez', nombreUsuario: 'laura.rios', roles: ['EMPLEADO', 'DOCENTE'] },
     { nombreCompleto: 'Mario Sánchez Trejo', nombreUsuario: 'mario.sanchez', roles: ['DOCENTE'] },
     { nombreCompleto: 'Patricia Núñez García', nombreUsuario: 'patricia.nunez', roles: ['DOCENTE'] },
     { nombreCompleto: 'jose manuel', nombreUsuario: 'harry.adm', roles: ['ADMINISTRADOR'] },
     { nombreCompleto: 'jessica admin', nombreUsuario: 'jessy', roles: ['ADMINISTRADOR'] }
   ];
 
   for (const u of usuariosEspeciales) {
     let uDB = await prisma.usuario.findUnique({ where: { nombreUsuario: u.nombreUsuario } });
     if (!uDB) {
       uDB = await prisma.usuario.create({
         data: {
           nombreUsuario: u.nombreUsuario,
           nombreCompleto: u.nombreCompleto,
           passwordHash: passwordHash,
           activo: true
         }
       });
     } else {
       uDB = await prisma.usuario.update({
         where: { usuarioId: uDB.usuarioId },
         data: { nombreCompleto: u.nombreCompleto, passwordHash: passwordHash }
       });
     }
 
     for (const r of u.roles) {
       const rolTarget = rolDict[r];
       if (rolTarget) {
         const ur = await prisma.usuarioRol.findFirst({
           where: { usuarioId: uDB.usuarioId, rolId: rolTarget.rolId }
         });
         if (!ur) {
           await prisma.usuarioRol.create({
             data: { usuarioId: uDB.usuarioId, rolId: rolTarget.rolId }
           });
         }
       }
     }
   }
   // --- FIN: Crear usuarios adicionales ---
 */
  const gruposCreados = [];
  const gmActuales = {};

  console.log('Generando Docentes, Grupos y Materias (Sufijos Romanos)...');
  for (const config of configuracionNiveles) {
    const nivelDB = niveles.find(n => n.codigo === config.codigo);
    if (!nivelDB) continue;

    for (let gIndex = 0; gIndex < config.grados.length; gIndex++) {
      const grado = config.grados[gIndex];
      const numeroGrado = gIndex + 1; // 1-based

      const fName = faker.person.firstName();
      const lName = faker.person.lastName();
      let username = normalizeUsername(fName, lName);
      let existe = await prisma.usuario.findUnique({ where: { nombreUsuario: username } });
      if (existe) username = username + Math.floor(Math.random() * 100);

      const docente = await prisma.usuario.create({
        data: {
          nombreUsuario: username,
          nombreCompleto: `${fName} ${lName}`,
          correo: faker.internet.email({ firstName: fName, lastName: lName }),
          telefono: faker.phone.number({ style: 'national' }),
          passwordHash: passwordHash,
          roles: { create: { rolId: rolDocente.rolId } }
        }
      });

      const grupo = await prisma.grupo.create({
        data: {
          cicloId: ciclo.cicloId,
          nivelId: nivelDB.nivelId,
          grado: grado,
          seccion: 'A',
          nombre: `${grado}º A - ${nivelDB.nombre}`,
          docenteTitularId: docente.usuarioId,
          cupoMaximo: 30
        }
      });
      gruposCreados.push(grupo);

      for (const def of config.materias) {
        let sufijo = getRomano(numeroGrado);
        if (def.base === 'Inglés' && config.codigo === 'PRIMARIA') sufijo = getRomano(numeroGrado + 3);

        const nombreMateria = def.tipo === 'curricular' ? `${def.base} ${sufijo}`.trim() : def.base;

        let materia = await prisma.materia.findUnique({
          where: { nivelId_nombre_tipo: { nivelId: nivelDB.nivelId, nombre: nombreMateria, tipo: def.tipo } }
        });
        if (!materia) {
          materia = await prisma.materia.create({
            data: {
              nivelId: nivelDB.nivelId,
              nombre: nombreMateria,
              tipo: def.tipo,
              cuentaParaPromedio: def.tipo === 'curricular',
              horasSemanales: def.tipo === 'curricular' ? 5 : 2
            }
          });
        }

        const gm = await prisma.grupoMateria.create({
          data: {
            grupoId: grupo.grupoId,
            materiaId: materia.materiaId,
            docenteId: docente.usuarioId,
            horario: '08:00 - 10:00',
            aula: `Salón ${grado}A`
          }
        });

        if (!gmActuales[grupo.grupoId]) gmActuales[grupo.grupoId] = [];
        gmActuales[grupo.grupoId].push(gm);
      }
    }
  }

  // 4. Tutores (1 a 4 Hijos, 25% con datos fiscales)
  console.log('Generando Tutores...');
  const capacidadesTutores = [];
  let totalHijos = 0;
  while (totalHijos < 100) {
    let cap = faker.number.int({ min: 1, max: 4 });
    if (totalHijos + cap > 100) {
      cap = 100 - totalHijos;
    }
    capacidadesTutores.push(cap);
    totalHijos += cap;
  }
  const totalTutores = capacidadesTutores.length;
  const numFiscales = Math.round(totalTutores * 0.25);

  const tutores = [];
  for (let i = 0; i < totalTutores; i++) {
    const isFiscal = i < numFiscales; // Los primeros N tendrán datos fiscales
    const tData = {
      nombreCompleto: faker.person.fullName(),
      correoElectronico: faker.internet.email(),
      telefono: faker.phone.number({ style: 'national' }),
      direccion: faker.location.streetAddress()
    };
    if (isFiscal) {
      tData.rfc = faker.helpers.replaceSymbols('????######???').toUpperCase();
      tData.regimenFiscal = "616";
      tData.codigoPostal = faker.location.zipCode('#####');
      tData.direccionFiscal = tData.direccion;
      tData.requiereFactura = true;
    }
    const tutor = await prisma.tutor.create({ data: tData });
    tutores.push({ dbTutor: tutor, cap: capacidadesTutores[i], asignados: 0 });
  }
  tutores.sort(() => Math.random() - 0.5); // Mezclar para distribuir aleatoriamente los fiscales

  // Segmentación Financiera Matemática Estricta
  const estadosFinancieros = [];
  for (let i = 0; i < 25; i++) estadosFinancieros.push({ grupoFinanciero: 1, adeudo_activo: true, mesesAdeudo: 1, beca: false });
  for (let i = 0; i < 20; i++) estadosFinancieros.push({ grupoFinanciero: 2, adeudo_activo: false, mesesAdeudo: 0, beca: true });
  for (let i = 0; i < 5; i++) estadosFinancieros.push({ grupoFinanciero: 3, adeudo_activo: true, mesesAdeudo: 3, beca: true });
  for (let i = 0; i < 5; i++) estadosFinancieros.push({ grupoFinanciero: 4, adeudo_activo: true, mesesAdeudo: 3, beca: false });
  for (let i = 0; i < 45; i++) estadosFinancieros.push({ grupoFinanciero: 5, adeudo_activo: false, mesesAdeudo: 0, beca: false });
  estadosFinancieros.sort(() => Math.random() - 0.5); // Barajar una sola vez

  // 5. Alumnos (Distribución Equitativa)
  console.log('Generando 100 Alumnos y Asignando Segmentación Financiera...');
  const alumnosData = [];
  let alumnoIdCount = 1;
  let tutorIndex = 0;

  for (let gIdx = 0; gIdx < gruposCreados.length; gIdx++) {
    const grupo = gruposCreados[gIdx];
    const cantidadAlumnos = gIdx < 10 ? 6 : 5;

    for (let a = 0; a < cantidadAlumnos; a++) {
      const fName = faker.person.firstName();
      const lName = faker.person.lastName();

      const alumno = await prisma.alumno.create({
        data: {
          matricula: `MAT-${new Date().getFullYear()}-${alumnoIdCount.toString().padStart(4, '0')}`,
          curp: faker.helpers.replaceSymbols('????######??????##').toUpperCase(),
          nombreCompleto: `${fName} ${lName}`,
          fechaNacimiento: faker.date.birthdate({ min: 4, max: 18, mode: 'age' }),
          sexo: Math.random() > 0.5 ? 'M' : 'F',
          nivelId: grupo.nivelId,
          estado: 'Activo'
        }
      });

      // Asignar Tutor
      let t = tutores[tutorIndex];
      while (t.asignados >= t.cap) {
        tutorIndex++;
        t = tutores[tutorIndex];
      }
      await prisma.tutorAlumno.create({
        data: { tutorId: t.dbTutor.tutorId, alumnoId: alumno.alumnoId, esResponsableFinanciero: true }
      });
      t.asignados++;

      const estadoFinancieroPop = estadosFinancieros.pop();
      const planPagoAsignado = planesPago[Math.floor(Math.random() * planesPago.length)];

      let estadoFinancieroDB = 'al_corriente';
      if (estadoFinancieroPop.mesesAdeudo === 1) estadoFinancieroDB = 'aviso_preventivo';
      if (estadoFinancieroPop.mesesAdeudo === 3) estadoFinancieroDB = 'examen_restringido';

      // Inscripcion Ciclo
      const inscripcion = await prisma.inscripcionCiclo.create({
        data: {
          alumnoId: alumno.alumnoId,
          cicloId: ciclo.cicloId,
          grupoId: grupo.grupoId,
          estadoEnCiclo: 'activa',
          estadoFinanciero: estadoFinancieroDB,
          mesesAdeudo: estadoFinancieroPop.mesesAdeudo,
          planPagoId: planPagoAsignado.planPagoId
        }
      });

      if (estadoFinancieroPop.mesesAdeudo > 0) {
        for (let m = 1; m <= estadoFinancieroPop.mesesAdeudo; m++) {
          const pastDate = new Date();
          pastDate.setMonth(pastDate.getMonth() - m);
          await prisma.calendarioPago.create({
            data: {
              alumnoId: alumno.alumnoId,
              cicloId: ciclo.cicloId,
              concepto: 'colegiatura',
              mes: `Mes -${m}`,
              fechaVencimiento: pastDate,
              montoOriginal: planPagoAsignado.montoMensual,
              montoPagado: 0,
              montoRecargo: 0,
              estadoCobro: 'pendiente'
            }
          });
        }
      }

      // Asignar Beca si corresponde
      if (estadoFinancieroPop.beca) {
        const becaSeleccionada = becas[Math.floor(Math.random() * becas.length)];
        await prisma.asignacionBeca.create({
          data: {
            alumnoId: alumno.alumnoId,
            becaId: becaSeleccionada.becaId,
            cicloId: ciclo.cicloId
          }
        });
      }

      // Inscripcion Materia
      const gmList = gmActuales[grupo.grupoId] || [];
      for (const gm of gmList) {
        await prisma.inscripcionMateria.create({
          data: { alumnoId: alumno.alumnoId, grupoMateriaId: gm.grupoMateriaId }
        });
      }

      alumnosData.push({ alumno, grupo, gmList });
      alumnoIdCount++;
    }
  }

  // 6. Calificaciones Actuales (50% de los alumnos)
  console.log('Asignando Calificaciones Actuales (50% de la población)...');
  const alumnosCalificar = [...alumnosData].sort(() => Math.random() - 0.5).slice(0, 50);

  for (const { alumno, grupo, gmList } of alumnosCalificar) {
    const periodosGrupo = periodosActivos.filter(p => p.nivelId === grupo.nivelId);
    if (periodosGrupo.length === 0) continue;

    const p = periodosGrupo[0];

    for (const gm of gmList) {
      await prisma.calificacion.create({
        data: {
          alumnoId: alumno.alumnoId,
          grupoMateriaId: gm.grupoMateriaId,
          periodoId: p.periodoId,
          valorNumerico: Number((Math.random() * (10 - 5) + 5).toFixed(1)),
          tipoEvaluacion: 'numerica',
          cuentaParaPromedio: true
        }
      });
    }
  }

  // 7. Historial Denso para Bachillerato Semestre VI
  console.log('Generando Historial Denso (17 ciclos pasados) para alumnos de 6to Semestre...');
  const alumnosSexto = alumnosData.filter(a => a.grupo.grado === 'VI' && a.grupo.nivelId === niveles.find(n => n.codigo === 'BACHILLERATO')?.nivelId);

  if (alumnosSexto.length > 0) {
    const ordenGrados = [
      { nivel: 'PREESCOLAR', grado: '1' }, { nivel: 'PREESCOLAR', grado: '2' }, { nivel: 'PREESCOLAR', grado: '3' },
      { nivel: 'PRIMARIA', grado: '1' }, { nivel: 'PRIMARIA', grado: '2' }, { nivel: 'PRIMARIA', grado: '3' },
      { nivel: 'PRIMARIA', grado: '4' }, { nivel: 'PRIMARIA', grado: '5' }, { nivel: 'PRIMARIA', grado: '6' },
      { nivel: 'SECUNDARIA', grado: '1' }, { nivel: 'SECUNDARIA', grado: '2' }, { nivel: 'SECUNDARIA', grado: '3' },
      { nivel: 'BACHILLERATO', grado: 'I' }, { nivel: 'BACHILLERATO', grado: 'II' }, { nivel: 'BACHILLERATO', grado: 'III' },
      { nivel: 'BACHILLERATO', grado: 'IV' }, { nivel: 'BACHILLERATO', grado: 'V' }
    ];

    const startYear = new Date(ciclo.fechaInicio).getFullYear() - ordenGrados.length;

    for (let i = 0; i < ordenGrados.length; i++) {
      const { nivel, grado } = ordenGrados[i];
      const nivelDB = niveles.find(n => n.codigo === nivel);
      const yearStr = `${startYear + i}-${startYear + i + 1}`;

      let c = await prisma.cicloEscolar.create({
        data: {
          nombre: yearStr,
          fechaInicio: new Date(`${startYear + i}-08-15`),
          fechaFin: new Date(`${startYear + i + 1}-07-15`),
          activo: false
        }
      });

      const pDates = [
        { start: new Date(`${startYear + i}-08-15`), end: new Date(`${startYear + i}-11-15`) },
        { start: new Date(`${startYear + i}-11-16`), end: new Date(`${startYear + i + 1}-03-15`) },
        { start: new Date(`${startYear + i + 1}-03-16`), end: new Date(`${startYear + i + 1}-07-15`) }
      ];
      const periodosPasados = [];
      for (let p = 1; p <= 3; p++) {
        const per = await prisma.periodoEvaluacion.create({
          data: {
            cicloId: c.cicloId,
            nivelId: nivelDB.nivelId,
            tipo: 'trimestre',
            numero: p,
            nombre: `Trimestre ${p}`,
            fechaInicio: pDates[p - 1].start,
            fechaFin: pDates[p - 1].end,
            esFinalCiclo: p === 3
          }
        });
        periodosPasados.push(per);
      }

      const grupoPasado = await prisma.grupo.create({
        data: {
          cicloId: c.cicloId,
          nivelId: nivelDB.nivelId,
          grado: grado,
          seccion: 'A',
          nombre: `${grado}º A - ${nivelDB.nombre} (H)`,
          cupoMaximo: 30
        }
      });

      const config = configuracionNiveles.find(cf => cf.codigo === nivel);
      const gmPasadas = [];

      // Compute correct Roman Suffix for past classes
      // We must calculate its gIndex based on the degree.
      const gIndex = config.grados.indexOf(grado);
      const numeroGrado = gIndex + 1;

      for (const def of config.materias) {
        let sufijo = getRomano(numeroGrado);
        if (def.base === 'Inglés' && config.codigo === 'PRIMARIA') sufijo = getRomano(numeroGrado + 3);

        const nombreMateria = def.tipo === 'curricular' ? `${def.base} ${sufijo}`.trim() : def.base;

        let materia = await prisma.materia.findUnique({
          where: { nivelId_nombre_tipo: { nivelId: nivelDB.nivelId, nombre: nombreMateria, tipo: def.tipo } }
        });
        if (!materia) {
          materia = await prisma.materia.create({
            data: { nivelId: nivelDB.nivelId, nombre: nombreMateria, tipo: def.tipo, cuentaParaPromedio: def.tipo === 'curricular', horasSemanales: def.tipo === 'curricular' ? 5 : 2 }
          });
        }

        const gm = await prisma.grupoMateria.create({
          data: { grupoId: grupoPasado.grupoId, materiaId: materia.materiaId }
        });
        gmPasadas.push(gm);
      }

      for (const a of alumnosSexto) {
        await prisma.inscripcionCiclo.create({
          data: {
            alumnoId: a.alumno.alumnoId,
            cicloId: c.cicloId,
            grupoId: grupoPasado.grupoId,
            estadoEnCiclo: 'activa',
            estadoFinanciero: 'al_corriente',
            mesesAdeudo: 0
          }
        });

        for (const gm of gmPasadas) {
          await prisma.inscripcionMateria.create({
            data: { alumnoId: a.alumno.alumnoId, grupoMateriaId: gm.grupoMateriaId }
          });

          for (const per of periodosPasados) {
            await prisma.calificacion.create({
              data: {
                alumnoId: a.alumno.alumnoId,
                grupoMateriaId: gm.grupoMateriaId,
                periodoId: per.periodoId,
                valorNumerico: Number((Math.random() * (10 - 6) + 6).toFixed(1)),
                tipoEvaluacion: 'numerica',
                cuentaParaPromedio: true
              }
            });
          }
        }
      }
    }
  }

  console.log('¡Inyección de datos completada con éxito!');
}

main().catch(e => {
  console.error(e);
  process.exit(1);
}).finally(async () => {
  await prisma.$disconnect();
});
