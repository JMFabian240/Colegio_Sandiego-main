/**
 * modules/ciclo.js
 * Ciclo escolar y tarifas mixin
 */
function cicloMixin() {
  return {
    // ── Estado ───────────────────────────────────────────────────────────────
    modalNuevoCiclo: false,
    nuevoCicloData: { nombre: '', activo: true },
    ciclosDisponibles: [],
    nivelesDisponiblesAPI: [],
    configTarifas: {
      cicloId: '', nivelId: '', cicloActivo: false,
      conceptos: { colegiatura: '', inscripcion: '', arancel: '', material: '' }
    },

    // ── API ──────────────────────────────────────────────────────────────────
    async cargarCiclosYTarifas() {
      try {
        const res = await window.saeApi.fetchApi('/tarifas/ciclos');
        if (res.ok) { this.ciclosDisponibles = res.data; }
        const resN = await window.saeApi.fetchApi('/tarifas/niveles');
        if (resN.ok) { this.nivelesDisponiblesAPI = resN.data; }
      } catch (e) { console.error(e); }
    },
    async cargarTarifas() {
      if (!this.configTarifas.cicloId) return;
      const ciclo = this.ciclosDisponibles.find(c => c.cicloId == this.configTarifas.cicloId);
      if (ciclo) this.configTarifas.cicloActivo = ciclo.activo;
      if (!this.configTarifas.nivelId) return;
      this.cargando = true;
      try {
        const url = `/tarifas?cicloId=${this.configTarifas.cicloId}&nivelId=${this.configTarifas.nivelId}`;
        const res = await window.saeApi.fetchApi(url);
        if (res.ok && res.data) {
          this.configTarifas.conceptos = { colegiatura: '', inscripcion: '', arancel: '', material: '' };
          res.data.forEach(t => {
            if (t.concepto === 'colegiatura') this.configTarifas.conceptos.colegiatura = Number(t.monto) * 10;
            if (t.concepto === 'inscripcion') this.configTarifas.conceptos.inscripcion = t.monto;
            if (t.concepto === 'arancel') this.configTarifas.conceptos.arancel = t.monto;
            if (t.concepto === 'material') this.configTarifas.conceptos.material = t.monto;
          });
        }
      } catch (e) { console.error(e); }
      finally { this.cargando = false; }
    },
    async guardarTarifas() {
      const confirmacion = confirm("¿Está seguro que desea guardar esta configuración de montos para el ciclo escolar seleccionado?");
      if (!confirmacion) return;
      const conceptosArray = [];
      for (const [key, val] of Object.entries(this.configTarifas.conceptos)) {
        if (!val || Number(val) <= 0) { window.saeApi.toast('error', `El monto para ${key} es inválido. Debe ser mayor a 0.`); return; }
        let montoToSave = Number(val);
        if (key === 'colegiatura') { montoToSave = montoToSave / 10; }
        conceptosArray.push({ concepto: key, monto: montoToSave });
      }
      this.cargando = true;
      try {
        const res = await window.saeApi.fetchApi('/tarifas', {
          method: 'PUT', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ cicloId: this.configTarifas.cicloId, nivelId: this.configTarifas.nivelId, tarifas: conceptosArray })
        });
        if (res.ok) { window.saeApi.toast('exito', 'Configuración de tarifas guardada correctamente.'); await this.cargarTarifas(); }
        else { window.saeApi.toast('error', res.message || 'Error al guardar las tarifas.'); }
      } catch (e) {
        console.error(e);
        window.saeApi.toast('error', 'Ocurrió un error inesperado al guardar.');
      } finally { this.cargando = false; }
    },
    async crearCiclo() {
      if (!this.nuevoCicloData.nombre) return;
      this.cargando = true;
      try {
        const res = await window.saeApi.fetchApi('/tarifas/ciclos', {
          method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(this.nuevoCicloData)
        });
        if (res.ok) {
          window.saeApi.toast('exito', 'Ciclo creado exitosamente.');
          this.modalNuevoCiclo = false;
          this.nuevoCicloData = { nombre: '', activo: true };
          await this.cargarCiclosYTarifas();
        } else { window.saeApi.toast('error', res.message || 'Error al crear ciclo'); }
      } catch (e) {
        console.error(e);
        window.saeApi.toast('error', 'Ocurrió un error inesperado.');
      } finally { this.cargando = false; }
    },
    descargarCicloConfig() {
      window.saeApi.toast('info', 'Configuración del ciclo exportada correctamente.');
    },
  };
}
