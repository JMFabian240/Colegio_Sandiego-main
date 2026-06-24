/**
 * modules/bitacora.js
 * Bitácora del sistema mixin: logs, paginación, exportar PDF
 */
function bitacoraMixin() {
  return {
    // ── Estado ───────────────────────────────────────────────────────────────
    bitacoraLogs: [],
    bitacoraPagina: 1, bitacoraTotal: 0, bitacoraPaginas: 1, limitBitacora: 20,

    // ── API ──────────────────────────────────────────────────────────────────
    async cargarBitacora(pagina) {
      const p = pagina || 1;
      const res = await window.saeApi.bitacora.listar(p, this.limitBitacora);
      if (res.ok && res.data) {
        this.bitacoraLogs = res.data.datos || [];
        this.bitacoraPagina = res.data.pagina || 1;
        this.bitacoraTotal = res.data.total || 0;
        this.bitacoraPaginas = Math.ceil(res.data.total / this.limitBitacora) || 1;
        if (pagina === undefined) window.saeApi.toast('success', 'Bitácora actualizada');
      } else if (!res.offline) {
        window.saeApi.toast('error', res.message || 'Error al cargar bitácora');
      }
    },
    exportarBitacoraPDF() {
      const url = window.saeApi.bitacora.exportarURL('pdf');
      window.open(url, '_blank');
    },
  };
}
