/**
 * modules/reportes.js
 * Reportes financieros mixin: corte de caja, ingresos, deudores, facturables, PDF, CSV
 */
function reportesMixin() {
  return {
    // ── Estado ───────────────────────────────────────────────────────────────
    reporteActivo: 'corte',
    reporteCorte: null,
    reporteIngresos: null,
    cicloSeleccionadoIngresos: '',
    reporteDeudores: null,
    reporteFacturables: null,

    // ── API ──────────────────────────────────────────────────────────────────
    async cargarReporteCorte() {
      try {
        const res = await window.saeApi.reportes.corteCaja();
        if (res && res.ok) this.reporteCorte = res.data;
      } catch (e) { console.error('Error cargando corte de caja', e); }
    },
    async cargarReporteIngresos() {
      try {
        const res = await window.saeApi.reportes.ingresosMensuales(this.cicloSeleccionadoIngresos);
        if (res && res.ok) this.reporteIngresos = res.data;
      } catch (e) { console.error('Error cargando ingresos', e); }
    },
    async cargarReporteDeudores() {
      try {
        const res = await window.saeApi.reportes.deudores();
        if (res && res.ok) this.reporteDeudores = res.data;
      } catch (e) { console.error('Error cargando deudores', e); }
    },
    async cargarReporteFacturables() {
      try {
        const res = await window.saeApi.reportes.facturables();
        if (res && res.ok) this.reporteFacturables = res.data;
      } catch (e) { console.error('Error cargando facturables', e); }
    },

    // ── CSV utils ────────────────────────────────────────────────────────────
    _descargarCSV(filename, content) {
      const blob = new Blob(['\uFEFF' + content], { type: 'text/csv;charset=utf-8;' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.setAttribute('href', url); link.setAttribute('download', filename);
      link.style.visibility = 'hidden';
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    },
    exportarCorteCSV() {
      if (!this.reporteCorte || !this.reporteCorte.pagos || this.reporteCorte.pagos.length === 0) return window.saeApi.toast('advertencia', 'No hay datos para exportar.');
      const encabezados = ['Alumno', 'Matrícula', 'Método', 'Registrado por', 'Monto'];
      const filas = this.reporteCorte.pagos.map(p => [`"${p.alumno}"`, `"${p.matricula}"`, `"${p.metodoPago}"`, `"${p.registradoPor}"`, p.monto]);
      const csvContent = [encabezados.join(','), ...filas.map(f => f.join(','))].join('\n');
      this._descargarCSV(`Corte_Caja_${this.reporteCorte.fecha || 'hoy'}.csv`, csvContent);
    },
    exportarIngresosCSV() {
      if (!this.reporteIngresos || !this.reporteIngresos.meses) return window.saeApi.toast('advertencia', 'No hay datos para exportar.');
      const encabezados = ['Mes', 'Monto'];
      const filas = Object.entries(this.reporteIngresos.meses).map(([mes, monto]) => [`"${mes}"`, monto]);
      const csvContent = [encabezados.join(','), ...filas.map(f => f.join(','))].join('\n');
      this._descargarCSV(`Ingresos_Mensuales_${this.reporteIngresos.anio || 'anio'}.csv`, csvContent);
    },
    exportarDeudoresCSV() {
      if (!this.reporteDeudores || this.reporteDeudores.length === 0) return window.saeApi.toast('advertencia', 'No hay datos para exportar.');
      const encabezados = ['Alumno', 'Matrícula', 'Nivel', 'Meses Adeudo', 'Monto Total', 'Sanción'];
      const filas = this.reporteDeudores.map(d => [`"${d.nombre}"`, `"${d.matricula}"`, `"${d.nivel}"`, d.mesesAdeudo, d.montoTotal, `"${d.sancion}"`]);
      const csvContent = [encabezados.join(','), ...filas.map(f => f.join(','))].join('\n');
      this._descargarCSV(`Lista_Deudores.csv`, csvContent);
    },
    exportarFacturablesCSV() {
      if (!this.reporteFacturables || this.reporteFacturables.length === 0) return window.saeApi.toast('advertencia', 'No hay datos para exportar.');
      const encabezados = ['Nombre', 'RFC', 'Régimen', 'Correo Facturación', 'Hijos'];
      const filas = this.reporteFacturables.map(t => [`"${t.nombreCompleto}"`, `"${t.rfc || 'Sin RFC'}"`, `"${t.regimenFiscal || ''}"`, `"${t.correoFacturacion || t.correoElectronico || ''}"`, `"${(t.hijos || []).map(h => h.nombre).join('; ')}"`]);
      const csvContent = [encabezados.join(','), ...filas.map(f => f.join(','))].join('\n');
      this._descargarCSV(`Padres_Facturables.csv`, csvContent);
    },

    // ── PDF ───────────────────────────────────────────────────────────────────
    async generarPDF(tipo) {
      const { jsPDF } = window.jspdf;
      const doc = new jsPDF();
      doc.setFontSize(16); doc.setTextColor(0, 51, 102);
      doc.text(`Colegio San Diego · Reporte ${tipo}`, 20, 20);
      doc.setFontSize(11); doc.setTextColor(0, 0, 0);
      if (tipo === 'pagos') {
        doc.text('Listado de pagos:', 20, 40);
        this.pagosRegistrados.forEach((p, i) => doc.text(`${p.alumno} — $${p.monto} (${p.fecha})`, 20, 50 + i * 8));
      } else if (tipo === 'alumnos') {
        doc.text('Directorio escolar:', 20, 40);
        this.listaAlumnos.forEach((a, i) => doc.text(`${a.nombre} — ${a.grupo} — ${a.padre}`, 20, 50 + i * 8));
      } else if (tipo === 'becas') {
        doc.text('Becas activas: 15% hermanos, 20% excelencia, 10% temprana', 20, 40);
      }
      doc.save(`reporte_${tipo}.pdf`);
    },
  };
}
