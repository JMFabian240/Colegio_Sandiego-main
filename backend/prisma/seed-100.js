'use strict';

require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const NOMBRES = ['Juan', 'Pedro', 'Maria', 'Jose', 'Luis', 'Ana', 'Carlos', 'Laura', 'Carmen', 'Francisco', 'Manuel', 'Marta', 'Lucia', 'Jorge', 'Sofia', 'David', 'Elena', 'Diego', 'Paula', 'Javier', 'Daniela', 'Alejandro', 'Valeria', 'Miguel', 'Isabella', 'Jesus', 'Camila', 'Antonio', 'Andrea', 'Fernando'];
const APELLIDOS = ['Garcia', 'Gonzalez', 'Rodriguez', 'Fernandez', 'Lopez', 'Martinez', 'Sanchez', 'Perez', 'Gomez', 'Martin', 'Jimenez', 'Ruiz', 'Hernandez', 'Diaz', 'Moreno', 'Munoz', 'Alvarez', 'Romero', 'Alonso', 'Gutierrez', 'Navarro', 'Torres', 'Dominguez', 'Vazquez', 'Ramos', 'Gil', 'Ramirez', 'Serrano', 'Blanco', 'Molina'];

function getRandomName() {
  const n1 = NOMBRES[Math.floor(Math.random() * NOMBRES.length)];
  const a1 = APELLIDOS[Math.floor(Math.random() * APELLIDOS.length)];
  const a2 = APELLIDOS[Math.floor(Math.random() * APELLIDOS.length)];
  return `${n1} ${a1} ${a2}`;
}

async function main() {
  console.log('[SEED] Limpiando datos...');
  await prisma.asistencia.deleteMany({});
  await prisma.calificacion.deleteMany({});
  await prisma.inscripcionMateria.deleteMany({});
  await prisma.aplicacionPago.deleteMany({});
  await prisma.pago.deleteMany({});
  await prisma.calendarioPago.deleteMany({});
  await prisma.inscripcionCiclo.deleteMany({});
  await prisma.asignacionBeca.deleteMany({});
  await prisma.solicitudBeca.deleteMany({});
  await prisma.tutorAlumno.deleteMany({});
  await prisma.alumno.deleteMany({});
  await prisma.grupoMateria.deleteMany({});
  await prisma.grupo.deleteMany({});
  await prisma.materia.deleteMany({});

  console.log('[SEED] Obteniendo catálogos...');
  const ciclo = await prisma.cicloEscolar.findFirst({ where: { activo: true } });
  if (!ciclo) throw new Error("No hay ciclo activo");
  
  const niveles = await prisma.nivelEducativo.findMany();
  const plan = await prisma.planPago.findFirst();
  const beca = await prisma.beca.findFirst();

  // 1. Crear Grupos y Materias (15 grados en total)
  console.log('[SEED] Creando 15 grupos y materias...');
  const gradosConfig = [
    { nivel: 'PREESCOLAR', grados: ['1', '2', '3'] },
    { nivel: 'PRIMARIA', grados: ['1', '2', '3', '4', '5', '6'] },
    { nivel: 'SECUNDARIA', grados: ['1', '2', '3'] },
    { nivel: 'BACHILLERATO', grados: ['1', '2', '3'] }
  ];

  let gruposCreados = [];
  for (const conf of gradosConfig) {
    const nivelId = niveles.find(n => n.codigo === conf.nivel).nivelId;
    for (const grado of conf.grados) {
      const grupo = await prisma.grupo.create({
        data: {
          nombre: `${grado}°A ${conf.nivel}`,
          grado: grado,
          seccion: 'A',
          nivelId,
          cicloId: ciclo.cicloId,
          cupoMaximo: 25
        }
      });
      gruposCreados.push(grupo);

      // Crear materia curricular y extracurricular
      const matCur = await prisma.materia.create({ data: { nombre: `Curricular ${grupo.nombre}`, nivelId, cuentaParaPromedio: true } });
      const matExt = await prisma.materia.create({ data: { nombre: `Extra ${grupo.nombre}`, nivelId, cuentaParaPromedio: false, tipo: 'taller' } });
      
      await prisma.grupoMateria.create({ data: { grupoId: grupo.grupoId, materiaId: matCur.materiaId } });
      await prisma.grupoMateria.create({ data: { grupoId: grupo.grupoId, materiaId: matExt.materiaId } });
    }
  }

  // 2. Crear 100 alumnos
  console.log('[SEED] Creando 100 alumnos...');
  const perfiles = [
    ...Array(10).fill({ moroso: 1, becado: false }),
    ...Array(5).fill({ moroso: 3, becado: false }),
    ...Array(5).fill({ moroso: 3, becado: true }),
    ...Array(10).fill({ moroso: 0, becado: true }),
    ...Array(70).fill({ moroso: 0, becado: false })
  ];

  // Randomize array
  perfiles.sort(() => Math.random() - 0.5);

  let hoy = new Date();
  // Asumamos que estamos en el mes 6 (Ej. Febrero si inició en Septiembre)
  let mesActualIndex = 6; 
  
  for (let i = 0; i < 100; i++) {
    const perfil = perfiles[i];
    const grupo = gruposCreados[i % gruposCreados.length];
    const curp = `CURP${100000 + i}`;
    const matricula = `MAT-26-${1000 + i}`;

    const alumno = await prisma.alumno.create({
      data: {
        nombreCompleto: getRandomName(),
        matricula, curp, sexo: 'M',
        nivelId: grupo.nivelId,
        estado: 'Activo'
      }
    });

    const inscripcion = await prisma.inscripcionCiclo.create({
      data: {
        alumnoId: alumno.alumnoId,
        cicloId: ciclo.cicloId,
        grupoId: grupo.grupoId,
        planPagoId: plan.planPagoId
      }
    });

    if (perfil.becado && beca) {
      await prisma.asignacionBeca.create({
        data: {
          alumnoId: alumno.alumnoId,
          becaId: beca.becaId,
          cicloId: ciclo.cicloId,
          estado: 'activa'
        }
      });
    }

    // Inscribir a las materias del grupo
    const gms = await prisma.grupoMateria.findMany({ where: { grupoId: grupo.grupoId } });
    for (const gm of gms) {
      await prisma.inscripcionMateria.create({
        data: { alumnoId: alumno.alumnoId, grupoMateriaId: gm.grupoMateriaId }
      });
    }

    // Generar calendario de pagos
    // 10 mensualidades
    for (let mes = 1; mes <= 10; mes++) {
      let montoOriginal = Number(plan.montoMensual);
      if (perfil.becado) montoOriginal = montoOriginal * 0.5;

      let fechaVenc = new Date(hoy.getFullYear() - (mes > mesActualIndex ? 0 : 1), (mes - 1 + 8) % 12, 10);
      let estadoCobro = 'pendiente';
      let montoPagado = 0;
      let montoRecargo = 0;
      let liquidadoAt = null;
      let pagado = false;

      // Calcular estado basado en perfil moroso
      if (mes < mesActualIndex - perfil.moroso) {
        // Debería estar pagado
        estadoCobro = 'pagado';
        montoPagado = montoOriginal;
        liquidadoAt = new Date(fechaVenc);
        liquidadoAt.setDate(liquidadoAt.getDate() - 2); // pagó 2 días antes
        pagado = true;
      } else if (mes < mesActualIndex) {
        // Es un mes que debía pagar y no pagó -> Vencido (Moroso)
        estadoCobro = 'vencido';
        montoRecargo = 400; // Recargo fijo
      }

      const cal = await prisma.calendarioPago.create({
        data: {
          alumnoId: alumno.alumnoId,
          cicloId: ciclo.cicloId,
          concepto: 'colegiatura',
          mes: `Mes ${mes}`,
          fechaVencimiento: fechaVenc,
          montoOriginal,
          montoPagado,
          montoRecargo,
          estadoCobro,
          liquidadoAt
        }
      });

      if (pagado) {
        const p = await prisma.pago.create({
          data: {
            alumnoId: alumno.alumnoId,
            montoTotal: montoPagado,
            metodoPago: 'transferencia',
            fechaPago: liquidadoAt
          }
        });
        await prisma.aplicacionPago.create({
          data: {
            pagoId: p.pagoId,
            calendarioPagoId: cal.calendarioPagoId,
            montoAplicado: montoPagado,
            aplicadoA: 'capital'
          }
        });
      }
    }
  }

  console.log('[SEED] ¡100 alumnos generados con éxito!');
}

main()
  .catch(e => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
