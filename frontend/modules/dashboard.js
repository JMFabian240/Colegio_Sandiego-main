/**
 * modules/dashboard.js
 * Dashboard mixin: stats, deudores, últimos pagos
 */
function dashboardMixin() {
  return {
    // ── Estado ───────────────────────────────────────────────────────────────
    _dashboardCargado: false,
    dashSummary: { ingresosHoy: 0, alumnos: 0, deudores: 0, becasActivas: 0 },
    dashUltimosPagos: [],
    dashDeudores: [],

    // ── Carga ────────────────────────────────────────────────────────────────
    async _cargarDashboard() {
      const newSummary = { ingresosHoy: 0, alumnos: 0, deudores: 0, becasActivas: 0 };
      try {
        // Total de alumnos activos
        const resAlum = await window.saeApi.alumnos.listar({ estado: 'Activo', limit: 1, page: 1 });
        if (resAlum && resAlum.ok && resAlum.pagination) {
          newSummary.alumnos = resAlum.pagination.total;
        } else if (resAlum && resAlum.ok && Array.isArray(resAlum.data)) {
          newSummary.alumnos = resAlum.data.length;
        }

        // Deudores activos (usando el reporte oficial)
        const resDeud = await window.saeApi.reportes.deudores();
        if (resDeud && resDeud.ok && Array.isArray(resDeud.data)) {
          this.dashDeudores = resDeud.data;
          newSummary.deudores = resDeud.data.length;
        } else {
          this.dashDeudores = [];
        }
      } catch (error) {
        console.error('Error cargando dashboard stats:', error);
      }

      try {
        // Ingresos del día actual (desde pagos filtrados por fecha)
        const hoy = new Date().toISOString().slice(0, 10);
        const resP = await window.saeApi.pagos.listar({ fechaDesde: hoy, fechaHasta: hoy });
        if (resP.ok) {
          const lista = Array.isArray(resP.data) ? resP.data : [];
          const mapeados = lista.map(window.saeApi.mapPago);
          newSummary.ingresosHoy = mapeados.reduce((s, p) => s + (Number(p.monto) || 0), 0);
          this.dashUltimosPagos = mapeados.slice(0, 5);
        }

        // Becas activas
        const resB = await window.saeApi.becas.listar();
        if (resB.ok && resB.data) {
          newSummary.becasActivas = resB.data.length;
        }
      } catch (error) {
        console.error('Error cargando ingresos/becas stats:', error);
      }

      this.dashSummary = newSummary;
    },
  };
}
