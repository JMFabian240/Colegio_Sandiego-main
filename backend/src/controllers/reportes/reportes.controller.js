'use strict';

const prisma = require('../../config/database');

/**
 * GET /api/v1/reportes/corte-caja
 * Pagos registrados HOY, con totales por concepto y método de pago.
 */
async function corteCaja(req, res, next) {
  try {
    const hoy = new Date();
    hoy.setHours(0, 0, 0, 0);
    const manana = new Date(hoy);
    manana.setDate(manana.getDate() + 1);

    const pagos = await prisma.pago.findMany({
      where: {
        registradoEn: { gte: hoy, lt: manana },
      },
      include: {
        alumno: { select: { nombreCompleto: true, matricula: true } },
        registradoPorUsuario: { select: { nombreCompleto: true } },
      },
      orderBy: { registradoEn: 'desc' },
    });

    // Totales por método de pago
    const porMetodo = {};
    const porConcepto = {};
    let total = 0;

    for (const p of pagos) {
      const monto = Number(p.montoTotal);
      total += monto;
      porMetodo[p.metodoPago] = (porMetodo[p.metodoPago] || 0) + monto;
      // Concepto: usar las aplicaciones si existen, sino genérico
      const concepto = 'Pago General';
      porConcepto[concepto] = (porConcepto[concepto] || 0) + monto;
    }

    res.json({
      ok: true,
      data: {
        fecha: hoy.toISOString().slice(0, 10),
        pagos: pagos.map(p => ({
          pagoId: p.pagoId,
          alumno: p.alumno?.nombreCompleto || 'N/A',
          matricula: p.alumno?.matricula || '',
          monto: Number(p.montoTotal),
          metodoPago: p.metodoPago,
          registradoPor: p.registradoPorUsuario?.nombreCompleto || 'Sistema',
          hora: p.registradoEn,
          observaciones: p.observaciones,
        })),
        resumen: { total, porMetodo, porConcepto },
        cantidadPagos: pagos.length,
      },
    });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/reportes/ingresos-mensuales
 * Ingresos agrupados por mes del año actual.
 */
async function ingresosMensuales(req, res, next) {
  try {
    const anio = req.query.anio || new Date().getFullYear();
    const inicioAnio = new Date(`${anio}-01-01`);
    const finAnio = new Date(`${Number(anio) + 1}-01-01`);

    const pagos = await prisma.pago.findMany({
      where: {
        registradoEn: { gte: inicioAnio, lt: finAnio },
      },
      select: { montoTotal: true, registradoEn: true },
    });

    // Agrupar por mes
    const meses = {};
    const nombresMeses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    nombresMeses.forEach((m, i) => { meses[m] = 0; });

    for (const p of pagos) {
      const mesIdx = new Date(p.registradoEn).getMonth();
      meses[nombresMeses[mesIdx]] += Number(p.montoTotal);
    }

    const totalAnual = Object.values(meses).reduce((s, v) => s + v, 0);

    res.json({
      ok: true,
      data: { anio: Number(anio), meses, totalAnual },
    });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/reportes/deudores
 * Lista de alumnos con adeudos pendientes.
 */
async function deudores(req, res, next) {
  try {
    const calendarios = await prisma.calendarioPago.findMany({
      where: {
        estadoCobro: { in: ['pendiente', 'parcial'] },
        eliminadoEn: null,
        fechaVencimiento: { lt: new Date() },
      },
      include: {
        alumno: {
          select: { alumnoId: true, nombreCompleto: true, matricula: true, estado: true,
                    nivel: { select: { nombre: true } } },
        },
      },
      orderBy: { fechaVencimiento: 'asc' },
    });

    // Agrupar por alumno
    const porAlumno = {};
    for (const cal of calendarios) {
      const key = cal.alumnoId;
      if (!porAlumno[key]) {
        porAlumno[key] = {
          alumnoId: cal.alumno.alumnoId,
          nombre: cal.alumno.nombreCompleto,
          matricula: cal.alumno.matricula,
          nivel: cal.alumno.nivel?.nombre || '',
          estado: cal.alumno.estado,
          mesesAdeudo: 0,
          montoTotal: 0,
          detalle: [],
        };
      }
      porAlumno[key].mesesAdeudo++;
      porAlumno[key].montoTotal += Number(cal.saldoPendiente);
      porAlumno[key].detalle.push({
        mes: cal.mes,
        concepto: cal.concepto,
        saldo: Number(cal.saldoPendiente),
        fechaVencimiento: cal.fechaVencimiento,
      });
    }

    const lista = Object.values(porAlumno).sort((a, b) => b.mesesAdeudo - a.mesesAdeudo);

    // Aplicar sanciones
    for (const alumno of lista) {
      if (alumno.mesesAdeudo >= 3) alumno.sancion = 'Baja temporal';
      else if (alumno.mesesAdeudo >= 2) alumno.sancion = 'Examen restringido';
      else alumno.sancion = 'Aviso preventivo';
    }

    res.json({ ok: true, data: lista });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/reportes/facturables
 * Tutores con requiereFactura = true y sus datos fiscales.
 */
async function facturables(req, res, next) {
  try {
    const tutores = await prisma.tutor.findMany({
      where: { requiereFactura: true, eliminadoEn: null },
      select: {
        tutorId: true,
        nombreCompleto: true,
        rfc: true,
        regimenFiscal: true,
        usoCfdi: true,
        direccionFiscal: true,
        codigoPostal: true,
        correoFacturacion: true,
        correoElectronico: true,
        telefono: true,
        alumnos: {
          select: { alumno: { select: { nombreCompleto: true, matricula: true } } },
        },
      },
      orderBy: { nombreCompleto: 'asc' },
    });

    const lista = tutores.map(t => ({
      ...t,
      hijos: t.alumnos.map(a => ({
        nombre: a.alumno.nombreCompleto,
        matricula: a.alumno.matricula,
      })),
      alumnos: undefined,
    }));

    res.json({ ok: true, data: lista });
  } catch (err) { next(err); }
}

module.exports = { corteCaja, ingresosMensuales, deudores, facturables };
