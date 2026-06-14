const calendarioPagoRepository = require('../../repositories/pagos/calendarioPago.repository');
const prisma = require('../../config/database');

/**
 * SAE — Calendario de Pagos Service
 */

/**
 * Recalcula el montoOriginal de todas las colegiaturas de un alumno en el ciclo activo,
 * basándose en su plan de pagos y el porcentaje total de las becas que tenga activas.
 * 
 * Si el monto pagado ya supera el nuevo monto con descuento, el saldo a favor
 * no se maneja explícitamente aquí, el saldoPendiente bajará (puede quedar negativo).
 * El frontend deberá manejarlo como "Saldo a favor".
 */
async function recalcularPorBeca(alumnoId, cicloId = null) {
  if (!cicloId) {
    const cicloActivo = await prisma.cicloEscolar.findFirst({ where: { activo: true } });
    if (!cicloActivo) return { exito: false, error: 'No hay ciclo activo' };
    cicloId = cicloActivo.cicloId;
  }
  // 1. Obtener la inscripción para saber el Plan de Pago
  const inscripcion = await calendarioPagoRepository.findInscripcion(alumnoId, cicloId);
  if (!inscripcion || !inscripcion.planDepago) {
    // Si no hay inscripción con plan de pago en este ciclo, no se puede recalcular
    return;
  }
  
  const planPago = inscripcion.planDepago;

  // 2. Obtener todas las becas activas para sumar el porcentaje de descuento
  const asignaciones = await calendarioPagoRepository.findBecasActivas(alumnoId, cicloId);
  let descuentoTotal = 0;
  asignaciones.forEach(asig => {
    if (asig.beca && asig.beca.porcentaje) {
      descuentoTotal += Number(asig.beca.porcentaje);
    }
  });

  // Limitar descuento máximo al 100%
  if (descuentoTotal > 100) descuentoTotal = 100;
  const factorPago = 1 - (descuentoTotal / 100);

  // 3. Obtener todas las colegiaturas del alumno
  const colegiaturas = await calendarioPagoRepository.findColegiaturasByAlumno(alumnoId, cicloId);

  // 4. Actualizar cada colegiatura
  for (const col of colegiaturas) {
    let baseAmount = Number(planPago.montoMensual);
    // Verificar si es mes doble (Diciembre u otro configurado)
    // Asumiremos que si el montoOriginal original es el doble, usamos el montoDiciembre.
    // Una forma más precisa es ver si col.mes incluye 'diciembre' (depende de cómo se generó)
    if (col.mes && col.mes.toLowerCase().includes('dici')) {
      baseAmount = Number(planPago.montoDiciembre);
    } else if (Number(col.montoOriginal) >= Number(planPago.montoDiciembre) * 0.9 && planPago.montoDiciembre > planPago.montoMensual) {
       // fallback para detectar si la cuota original era la de diciembre
       baseAmount = Number(planPago.montoDiciembre);
    }

    const nuevoMonto = baseAmount * factorPago;
    
    // Solo actualizamos si el monto original cambia (para ahorrar queries)
    if (Number(col.montoOriginal) !== nuevoMonto) {
      await calendarioPagoRepository.updateMontoOriginal(col.calendarioPagoId, nuevoMonto);
    }
  }

  return { exito: true, colegiaturasAfectadas: colegiaturas.length, descuentoTotal };
}

/**
 * Genera el calendario de pagos (colegiaturas) para una inscripción.
 * Aplica prorrateo si el ingreso es tardío.
 */
async function generarCalendario(inscripcionId) {
  const inscripcion = await calendarioPagoRepository.findInscripcionById(inscripcionId);
  if (!inscripcion || !inscripcion.planDepago || !inscripcion.ciclo) {
    throw new Error('Inscripción inválida o sin plan de pagos asignado.');
  }

  const { ciclo, planDepago: plan, fechaIngreso, esIngresoTardio, alumnoId, cicloId } = inscripcion;
  
  // Obtener día límite de pago (idealmente del alumno, pero por ahora usamos un default 5)
  // Como no traemos al alumno completo aquí, usaremos 5 o lo que esté en config
  const diaTopeGlobal = 5; 

  const dataToInsert = [];
  const fechaInicioCiclo = new Date(ciclo.fechaInicio);
  
  // Nombres de meses para el registro
  const nombresMeses = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];

  for (let i = 0; i < plan.meses; i++) {
    // Calculamos el mes/año que corresponde a esta cuota
    // Asumimos que el ciclo empieza en el mes de `fechaInicioCiclo`
    const fechaCuota = new Date(fechaInicioCiclo.getFullYear(), fechaInicioCiclo.getMonth() + i, 1);
    
    // Si es ingreso tardío, verificar si la fecha de la cuota ya pasó completamente
    // Comparamos el "fin del mes de la cuota" contra la "fecha de ingreso"
    const finDeMesCuota = new Date(fechaCuota.getFullYear(), fechaCuota.getMonth() + 1, 0);
    
    if (esIngresoTardio && finDeMesCuota < fechaIngreso) {
      // Omitir meses completamente pasados
      continue;
    }

    let monto = Number(plan.montoMensual);
    // Verificamos si es diciembre para aplicar la tarifa de diciembre
    if (fechaCuota.getMonth() === 11) { // 11 es Diciembre
      monto = Number(plan.montoDiciembre);
    }

    // Prorrateo si la fecha de ingreso cae EXACTAMENTE dentro de este mes
    if (esIngresoTardio && fechaIngreso.getMonth() === fechaCuota.getMonth() && fechaIngreso.getFullYear() === fechaCuota.getFullYear()) {
      const diasEnMes = finDeMesCuota.getDate();
      const diasRestantes = diasEnMes - fechaIngreso.getDate() + 1;
      monto = monto * (diasRestantes / diasEnMes);
      // Redondear a 2 decimales
      monto = Math.round(monto * 100) / 100;
    }

    const fechaVencimiento = new Date(fechaCuota.getFullYear(), fechaCuota.getMonth(), diaTopeGlobal);
    
    dataToInsert.push({
      alumnoId,
      cicloId,
      concepto: 'Colegiatura',
      mes: nombresMeses[fechaCuota.getMonth()],
      fechaVencimiento,
      montoOriginal: monto,
    });
  }

  // Insertar en lote
  if (dataToInsert.length > 0) {
    await calendarioPagoRepository.createCalendarioBatch(dataToInsert);
    // Despues de generar, aplicamos posibles becas que ya tuviera activas
    await recalcularPorBeca(alumnoId, cicloId);
  }

  return { exito: true, generadas: dataToInsert.length };
}

/**
 * Maneja la baja o reactivación financiera.
 * Si esBaja = true, elimina las cuotas futuras no pagadas.
 * Si esBaja = false (reactivación), habría que regenerar lo faltante,
 * pero generalmente se hace llamando de nuevo a generarCalendario o una lógica específica.
 */
async function gestionarBajaTemporal(alumnoId, cicloId, esBaja) {
  if (esBaja) {
    const hoy = new Date();
    // Eliminar colegiaturas con vencimiento > hoy y montoPagado == 0
    await calendarioPagoRepository.deleteColegiaturasFuturas(alumnoId, cicloId, hoy);
    return { exito: true, mensaje: 'Cuotas futuras eliminadas por baja' };
  } else {
    // Para reactivación, por ahora retornamos éxito. 
    // La regeneración requeriría saber desde qué mes regenerar.
    // Un enfoque simple: se llama a generarCalendario() con una nueva inscripción "esIngresoTardio = true".
    return { exito: true, mensaje: 'Reactivación requiere generar nuevas cuotas' };
  }
}

module.exports = {
  recalcularPorBeca,
  generarCalendario,
  gestionarBajaTemporal,
};
