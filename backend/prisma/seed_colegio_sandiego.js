const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const crypto = require('crypto');
const bcrypt = require('bcryptjs');

async function main() {
  console.log('Iniciando script de Seed - Colegio San Diego...');

  // ---------------------------------------------------------
  // 1. Limpieza Selectiva (DML) - Sin alterar estructura
  // ---------------------------------------------------------
  console.log('Ejecutando limpieza selectiva de Grupos, Materias y tablas intermedias...');
  
  // Borrar dependencias primero para evitar violaciones de llaves foráneas
  await prisma.asistencia.deleteMany();
  await prisma.calificacionExtracurricular.deleteMany();
  await prisma.calificacionTaller.deleteMany();
  await prisma.calificacion.deleteMany();
  await prisma.inscripcionMateria.deleteMany();
  await prisma.inscripcionCiclo.deleteMany();
  
  // Borrar tablas principales de estructura académica
  await prisma.grupoMateria.deleteMany();
  await prisma.materia.deleteMany();
  await prisma.grupo.deleteMany();
  console.log('Limpieza completada.');

  // ---------------------------------------------------------
  // 2. Consulta de Catálogos Necesarios
  // ---------------------------------------------------------
  const ciclo = await prisma.cicloEscolar.findFirst({ where: { activo: true } });
  if (!ciclo) throw new Error("No hay un ciclo escolar activo. Asegúrate de tener al menos uno.");

  const niveles = await prisma.nivelEducativo.findMany({ orderBy: { orden: 'asc' } });
  if (niveles.length === 0) throw new Error("No hay niveles educativos definidos.");

  // Asegurarnos de que el Rol Docente existe
  let rolDocente = await prisma.rol.findUnique({ where: { codigo: 'DOCENTE' } });
  if (!rolDocente) {
    rolDocente = await prisma.rol.create({ data: { codigo: 'DOCENTE', nombre: 'Docente' } });
  }

  // ---------------------------------------------------------
  // 3. Generación de Docentes, Grupos y Materias
  // ---------------------------------------------------------
  console.log('Generando Niveles, Grados, Grupos y Docentes...');

  const gradosPorNivel = {
    Preescolar: ['1º', '2º', '3º'],
    Primaria: ['1º', '2º', '3º', '4º', '5º', '6º'],
    Secundaria: ['1º', '2º', '3º'],
    Bachillerato: ['I', 'II', 'III', 'IV', 'V', 'VI'] // Semestres
  };

  const getRomano = (num) => {
    const romanos = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];
    return romanos[num - 1] || num.toString();
  };

  const passwordHash = await bcrypt.hash('Docente123!', 10);
  
  // Controladores de secuencias romanas
  const secuenciaMaterias = {};

  for (const nivel of niveles) {
    const nombreNivel = nivel.nombre;
    let tipoNivel = 'Bachillerato';
    if (nombreNivel.toLowerCase().includes('preescolar')) tipoNivel = 'Preescolar';
    else if (nombreNivel.toLowerCase().includes('primaria')) tipoNivel = 'Primaria';
    else if (nombreNivel.toLowerCase().includes('secundaria')) tipoNivel = 'Secundaria';

    const grados = gradosPorNivel[tipoNivel] || ['1º'];
    secuenciaMaterias[tipoNivel] = {};

    for (let i = 0; i < grados.length; i++) {
      const grado = grados[i];
      const gradoNum = i + 1; // 1-based index

      // 3.1 Crear un Docente único por Grupo/Grado
      const docenteUUID = crypto.randomUUID().substring(0, 8);
      const nombreUsuarioDocente = `docente.${tipoNivel.toLowerCase()}.${gradoNum}.${docenteUUID}`;
      
      const nuevoDocente = await prisma.usuario.create({
        data: {
          nombreUsuario: nombreUsuarioDocente,
          nombreCompleto: `Docente ${tipoNivel} ${grado}A`,
          correo: `${nombreUsuarioDocente}@colegiosandiego.edu.mx`,
          passwordHash: passwordHash,
          roles: { create: { rolId: rolDocente.rolId } }
        }
      });

      // 3.2 Crear Grupo
      const grupo = await prisma.grupo.create({
        data: {
          cicloId: ciclo.cicloId,
          nivelId: nivel.nivelId,
          grado: grado,
          seccion: 'A',
          nombre: `${grado} A ${tipoNivel}`,
          docenteTitularId: nuevoDocente.usuarioId,
          cupoMaximo: 30
        }
      });

      // 3.3 Definir Materias según el Nivel y Grado
      let definicionMaterias = [];

      if (tipoNivel === 'Preescolar' || tipoNivel === 'Primaria') {
        definicionMaterias = [
          { base: 'Lenguajes', tipo: 'curricular', cuentaPromedio: true },
          { base: 'Saberes y Pensamiento Científico', tipo: 'curricular', cuentaPromedio: true },
          { base: 'Ética, Naturaleza y Sociedades', tipo: 'curricular', cuentaPromedio: true },
          { base: 'De lo Humano y lo Comunitario', tipo: 'curricular', cuentaPromedio: true },
          { base: 'Inglés', tipo: 'curricular', cuentaPromedio: true },
          { base: 'Computación', tipo: 'taller', cuentaPromedio: false },
          { base: 'Educación Física', tipo: 'club', cuentaPromedio: false }
        ];
      } else if (tipoNivel === 'Secundaria') {
        const comunes = [
          { base: 'Español', tipo: 'curricular', cuentaPromedio: true },
          { base: 'Inglés', tipo: 'curricular', cuentaPromedio: true },
          { base: 'Matemáticas', tipo: 'curricular', cuentaPromedio: true },
          { base: 'Historia', tipo: 'curricular', cuentaPromedio: true },
          { base: 'Formación Cívica y Ética', tipo: 'curricular', cuentaPromedio: true },
          { base: 'Artes', tipo: 'taller', cuentaPromedio: false },
          { base: 'Tecnología Informática', tipo: 'taller', cuentaPromedio: false },
          { base: 'Educación Física', tipo: 'club', cuentaPromedio: false }
        ];
        
        let ciencias = [];
        let adicionales = [];
        if (grado === '1º') {
          ciencias = [{ base: 'Biología', tipo: 'curricular', cuentaPromedio: true }, { base: 'Geografía', tipo: 'curricular', cuentaPromedio: true }];
          adicionales = [{ base: 'Vida Saludable', tipo: 'club', cuentaPromedio: false }];
        } else if (grado === '2º') {
          ciencias = [{ base: 'Física', tipo: 'curricular', cuentaPromedio: true }];
          adicionales = [{ base: 'Vida Saludable', tipo: 'club', cuentaPromedio: false }];
        } else if (grado === '3º') {
          ciencias = [{ base: 'Química', tipo: 'curricular', cuentaPromedio: true }];
        }
        
        definicionMaterias = [...comunes, ...ciencias, ...adicionales];
      } else if (tipoNivel === 'Bachillerato') {
        definicionMaterias = [
          { base: 'Pensamiento Matemático', tipo: 'curricular', cuentaPromedio: true },
          { base: 'Cultura Digital', tipo: 'curricular', cuentaPromedio: true },
          { base: 'Humanidades', tipo: 'curricular', cuentaPromedio: true },
          { base: 'Inglés', tipo: 'curricular', cuentaPromedio: true },
          { base: 'Laboratorio de Ciencias', tipo: 'taller', cuentaPromedio: false }
        ];
      }

      for (const def of definicionMaterias) {
        let nombreMateria = def.base;

        if (def.tipo === 'curricular') {
          let sufijoNum = 1;
          
          if (def.base === 'Inglés') {
            if (tipoNivel === 'Preescolar') {
              sufijoNum = gradoNum;
            } else if (tipoNivel === 'Primaria') {
              sufijoNum = gradoNum + 3;
            } else if (tipoNivel === 'Secundaria') {
              sufijoNum = gradoNum;
            } else if (tipoNivel === 'Bachillerato') {
              sufijoNum = gradoNum;
            }
          } else {
            if (!secuenciaMaterias[tipoNivel][def.base]) {
              secuenciaMaterias[tipoNivel][def.base] = 0;
            }
            secuenciaMaterias[tipoNivel][def.base]++;
            sufijoNum = secuenciaMaterias[tipoNivel][def.base];
          }

          nombreMateria = `${def.base} ${getRomano(sufijoNum)}`;
        }

        let materiaObj = await prisma.materia.findUnique({
          where: {
            nivelId_nombre_tipo: {
              nivelId: nivel.nivelId,
              nombre: nombreMateria,
              tipo: def.tipo
            }
          }
        });

        if (!materiaObj) {
          materiaObj = await prisma.materia.create({
            data: {
              nivelId: nivel.nivelId,
              nombre: nombreMateria,
              tipo: def.tipo,
              cuentaParaPromedio: def.cuentaPromedio,
              horasSemanales: def.tipo === 'curricular' ? 5 : 2,
            }
          });
        }

        await prisma.grupoMateria.create({
          data: {
            grupoId: grupo.grupoId,
            materiaId: materiaObj.materiaId,
            docenteId: nuevoDocente.usuarioId,
            horario: `Lunes a Viernes 08:00 - ${def.tipo === 'curricular' ? '09:00' : '10:00'}`,
            aula: `Salón ${gradoNum}0${tipoNivel.substring(0,1)}`
          }
        });
      }
    }
  }

  // ---------------------------------------------------------
  // 4. Generación de Tutores y 100 Alumnos (Incremental)
  // ---------------------------------------------------------
  console.log('Generando 100 Alumnos y vinculándolos a Tutores...');

  const tutoresCreados = [];
  for (let i = 1; i <= 60; i++) {
    const tutorUUID = crypto.randomUUID().substring(0, 8);
    const tutor = await prisma.tutor.create({
      data: {
        nombreCompleto: `Tutor Genérico ${tutorUUID}`,
        correoElectronico: `tutor.${tutorUUID}@ejemplo.com`,
        telefono: `55${Math.floor(10000000 + Math.random() * 90000000)}`
      }
    });
    tutoresCreados.push(tutor);
  }

  const alumnosNuevos = [];
  const gruposExistentes = await prisma.grupo.findMany();
  if (gruposExistentes.length === 0) throw new Error("No se pudieron crear grupos.");

  let alumnosGenerados = 0;
  let tutorIndex = 0;

  while (alumnosGenerados < 100) {
    const tutorActual = tutoresCreados[tutorIndex];
    const cantidadHijos = Math.min(Math.floor(Math.random() * 4) + 1, 100 - alumnosGenerados);

    for (let h = 0; h < cantidadHijos; h++) {
      const alumnoUUID = crypto.randomUUID().substring(0, 8);
      const grupoAsignado = gruposExistentes[Math.floor(Math.random() * gruposExistentes.length)];
      
      const alumno = await prisma.alumno.create({
        data: {
          matricula: `MAT-${new Date().getFullYear()}-${alumnoUUID}`,
          nombreCompleto: `Alumno ${alumnoUUID} Tutor${tutorActual.tutorId}`,
          nivelId: grupoAsignado.nivelId,
          estado: 'Activo'
        }
      });
      alumnosNuevos.push({ alumno, grupo: grupoAsignado });

      await prisma.tutorAlumno.create({
        data: {
          tutorId: tutorActual.tutorId,
          alumnoId: alumno.alumnoId,
          tipoRelacion: 'tutor',
          esResponsableFinanciero: true
        }
      });

      alumnosGenerados++;
    }
    tutorIndex = (tutorIndex + 1) % tutoresCreados.length;
  }

  // ---------------------------------------------------------
  // 5. Inscripciones, Planes de Pago y Adeudos (25 exactos)
  // ---------------------------------------------------------
  console.log('Inscribiendo alumnos, asignando planes y estableciendo deudores...');

  let plan10 = await prisma.planPago.findFirst({ where: { cicloId: ciclo.cicloId, nombre: '10_MESES' } });
  if (!plan10) plan10 = await prisma.planPago.create({ data: { cicloId: ciclo.cicloId, nombre: '10_MESES', meses: 10, montoMensual: 2000, montoDiciembre: 1000 } });
  
  let plan12 = await prisma.planPago.findFirst({ where: { cicloId: ciclo.cicloId, nombre: '12_MESES' } });
  if (!plan12) plan12 = await prisma.planPago.create({ data: { cicloId: ciclo.cicloId, nombre: '12_MESES', meses: 12, montoMensual: 1800, montoDiciembre: 1800 } });

  const alumnosBarajados = [...alumnosNuevos].sort(() => 0.5 - Math.random());
  const alumnosConAdeudoIds = new Set(alumnosBarajados.slice(0, 25).map(a => a.alumno.alumnoId));

  for (const item of alumnosNuevos) {
    const { alumno, grupo } = item;
    
    const planElegido = Math.random() > 0.5 ? plan10 : plan12;
    const esDeudor = alumnosConAdeudoIds.has(alumno.alumnoId);
    
    await prisma.inscripcionCiclo.create({
      data: {
        alumnoId: alumno.alumnoId,
        cicloId: ciclo.cicloId,
        grupoId: grupo.grupoId,
        planPagoId: planElegido.planPagoId,
        planPago: planElegido.nombre.toLowerCase(),
        estadoFinanciero: esDeudor ? 'aviso_preventivo' : 'al_corriente',
        mesesAdeudo: esDeudor ? 1 : 0
      }
    });

    const grupoMaterias = await prisma.grupoMateria.findMany({ where: { grupoId: grupo.grupoId } });
    for (const gm of grupoMaterias) {
      await prisma.inscripcionMateria.create({
        data: {
          alumnoId: alumno.alumnoId,
          grupoMateriaId: gm.grupoMateriaId
        }
      });
    }
  }

  console.log(`\n===========================================`);
  console.log(`✅ Seed Finalizado Exitosamente`);
  console.log(`   - 100 Alumnos creados e inscritos`);
  console.log(`   - 25 Alumnos marcados con adeudo activo`);
  console.log(`   - Docentes únicos creados por grupo`);
  console.log(`   - Materias asignadas con sufijos romanos`);
  console.log(`===========================================\n`);
}

main()
  .catch((e) => {
    console.error('Error durante el seed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
