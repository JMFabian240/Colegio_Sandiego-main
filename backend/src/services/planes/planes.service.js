'use strict';

const prisma = require('../../config/database');
const { withAudit } = require('../../utils/audit.utils');

const NOMBRES_MESES = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
];

async function obtenerTarifas(cicloId, nivelId) {
  const tarifas = await prisma.tarifa.findMany({
    where: { cicloId, nivelId }
  });
  
  const mapa = {};
  for (const t of tarifas) {
    mapa[t.concepto] = Number(t.monto);
  }
  return mapa;
}

async function previsualizarPlan(alumnoId, meses) {
  if (meses !== 10 && meses !== 12) {
    throw Object.assign(new Error('El plan debe ser de 10 o 12 meses.'), { statusCode: 400 });
  }

  const alumno = await prisma.alumno.findUnique({
    where: { alumnoId: Number(alumnoId) },
    include: { nivel: true }
  });

  if (!alumno) throw Object.assign(new Error('Alumno no encontrado.'), { statusCode: 404 });
  if (!alumno.nivelId) throw Object.assign(new Error('El alumno no tiene un nivel educativo definido.'), { statusCode: 400 });

  const ciclo = await prisma.cicloEscolar.findFirst({
    where: { activo: true }
  });
  if (!ciclo) throw Object.assign(new Error('No hay ciclo escolar activo.'), { statusCode: 400 });

  // Revisar si ya tiene un plan
  const inscripcion = await prisma.inscripcionCiclo.findFirst({
    where: { alumnoId: Number(alumnoId), cicloId: ciclo.cicloId }
  });

  if (inscripcion && inscripcion.planPagoId) {
    // Si la inscripción ya tiene asignado un plan...
    throw Object.assign(new Error('El alumno ya tiene un plan asignado para este ciclo.'), { statusCode: 400 });
  }

  // Obtener tarifas
  const tarifas = await obtenerTarifas(ciclo.cicloId, alumno.nivelId);
  if (!tarifas.colegiatura) throw Object.assign(new Error('No están configuradas las tarifas de colegiatura.'), { statusCode: 400 });

  const startYear = ciclo.fechaInicio.getFullYear();
  const nextYear = startYear + 1;
  const mesInicio = ciclo.fechaInicio.getMonth(); // 0-indexed

  // Vamos a generar los meses escolares estándar: Septiembre (8) a Junio (5) para 10 meses
  // Septiembre a Agosto (7) para 12 meses
  let indicesMeses = [];
  if (meses === 10) {
    indicesMeses = [8, 9, 10, 11, 0, 1, 2, 3, 4, 5];
  } else {
    indicesMeses = [8, 9, 10, 11, 1, 2, 3, 4, 5, 6, 7];
  }

  const calendario = [];

  // Agregar inscripción, arancel, material (si existen) al inicio de septiembre (o fecha de inicio)
  const fechaInicioVencimiento = new Date(startYear, 8, 10); // 10 de Septiembre
  ['inscripcion', 'arancel', 'material'].forEach(concepto => {
    if (tarifas[concepto] && tarifas[concepto] > 0) {
      calendario.push({
        concepto: concepto,
        mes: 'inicio',
        fechaVencimiento: fechaInicioVencimiento,
        montoOriginal: tarifas[concepto]
      });
    }
  });

  // Generar mensualidades
  for (const m of indicesMeses) {
    const year = m >= 8 ? startYear : nextYear;
    // Vencimiento el día 10 del mes
    const fechaVenc = new Date(Date.UTC(year, m, 10));
    
    // Calcular monto equivalente para que el total anual sea igual (10 * tarifa)
    let monto = tarifas.colegiatura;
    if (meses === 12) {
      // Repartir el costo de 10 meses entre los 12 meses
      monto = Number(((tarifas.colegiatura * 10) / 12).toFixed(2));
      // Diciembre (mes 11) se cobra doble porque incluye Enero
      if (m === 11) {
        monto = monto * 2;
      }
    }

    calendario.push({
      concepto: 'colegiatura',
      mes: NOMBRES_MESES[m],
      fechaVencimiento: fechaVenc,
      montoOriginal: monto
    });
  }

  return { ciclo, calendario, tarifas };
}

async function asignarPlan(alumnoId, meses, usuarioId) {
  const { ciclo, calendario } = await previsualizarPlan(alumnoId, meses);

  return withAudit(usuarioId, 'IP_AQUI', async (tx) => {
    // Verificar o crear inscripcion_ciclo
    let inscripcion = await tx.inscripcionCiclo.findFirst({
      where: { alumnoId: Number(alumnoId), cicloId: ciclo.cicloId }
    });

    const alumno = await tx.alumno.findUnique({ where: { alumnoId: Number(alumnoId) } });

    // Vamos a usar planPago (el string) por simplicidad, dado el esquema (default "10_meses")
    const planString = meses === 12 ? '12_meses' : '10_meses';

    if (!inscripcion) {
      throw Object.assign(new Error('El alumno no tiene una inscripción activa en este ciclo. Asigne un grupo primero.'), { statusCode: 400 });
    } else {
      // Si existe inscripción, pero ya generamos calendarios antes y queremos evitar duplicidad:
      const calendariosExistentes = await tx.calendarioPago.count({
        where: { alumnoId: Number(alumnoId), cicloId: ciclo.cicloId }
      });

      if (calendariosExistentes > 0) {
        throw Object.assign(new Error('El alumno ya tiene un calendario de pagos generado.'), { statusCode: 400 });
      }

      inscripcion = await tx.inscripcionCiclo.update({
        where: { inscripcionId: inscripcion.inscripcionId },
        data: { planPago: planString }
      });
    }

    // Insertar el calendario de pagos
    const records = calendario.map(c => ({
      alumnoId: Number(alumnoId),
      cicloId: ciclo.cicloId,
      concepto: c.concepto,
      mes: c.mes,
      fechaVencimiento: c.fechaVencimiento,
      montoOriginal: c.montoOriginal,
      montoPagado: 0,
      montoRecargo: 0,
      estadoCobro: 'pendiente'
    }));

    await tx.calendarioPago.createMany({ data: records });

    return { success: true, message: `Plan de ${meses} meses asignado correctamente.` };
  });
}

module.exports = {
  previsualizarPlan,
  asignarPlan
};
