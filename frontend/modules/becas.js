/**
 * modules/becas.js
 * Becas mixin: catálogo, asignaciones, asignar, retirar, filtros, tipos de beca
 */
function becasMixin() {
  return {
    // ── Estado ───────────────────────────────────────────────────────────────
    catalogoBecas: [],
    becasAsignadas: [],
    solicitudesBeca: [],
    nuevaBeca: { alumnoId: null, becaId: null, porcentajeManual: null, motivo: '', nombreAlumno: '' },
    modalBeca: false,
    sugerenciasBeca: [],
    busquedaAlumnoBeca: '',
    alumnosBecaFiltrados: [],

    // ── Modal tipo beca ──────────────────────────────────────────────────────
    modalNuevoTipoBeca: false,
    nuevoTipoBecaData: { nombreBeca: '', criterio: '', porcentaje: '' },
    erroresBeca: { nombre: false, criterio: false, porcentaje: false },

    // ── API ──────────────────────────────────────────────────────────────────
    async cargarCatalogoBecas() {
      const res = await window.saeApi.becas.catalogo.listar();
      if (res.ok) this.catalogoBecas = res.data;
    },
    async cargarBecasAsignadas() {
      const res = await window.saeApi.becas.listar();
      if (res.ok) this.becasAsignadas = res.data;
      if (this.esAdmin()) { this.cargarSolicitudesBeca(); }
    },
    async cargarSolicitudesBeca() {
      try {
        const res = await window.saeApi.becas.listarSolicitudes();
        if (res && res.data) {
          this.solicitudesBeca = res.data.filter(s => s.estado === 'PENDIENTE');
        }
      } catch (e) { console.error(e); }
    },

    // ── Modal de tipo de beca ─────────────────────────────────────────────────
    openModalNuevoTipoBeca() {
      this.nuevoTipoBecaData = { becaId: null, nombreBeca: '', criterio: '', porcentaje: '' };
      this.erroresBeca = { nombre: false, criterio: false, porcentaje: false };
      this.modalNuevoTipoBeca = true;
    },
    editarTipoBeca(beca) {
      this.nuevoTipoBecaData = { becaId: beca.becaId, nombreBeca: beca.nombreBeca, criterio: beca.criterio, porcentaje: beca.porcentaje };
      this.erroresBeca = { nombre: false, criterio: false, porcentaje: false };
      this.modalNuevoTipoBeca = true;
    },
    async guardarNuevoTipoBeca() {
      let hasError = false;
      this.erroresBeca = { nombre: false, criterio: false, porcentaje: false };
      if (!this.nuevoTipoBecaData.nombreBeca.trim()) { this.erroresBeca.nombre = true; hasError = true; }
      if (!this.nuevoTipoBecaData.criterio) { this.erroresBeca.criterio = true; hasError = true; }
      const p = parseFloat(this.nuevoTipoBecaData.porcentaje);
      if (isNaN(p) || p < 1 || p > 100) { this.erroresBeca.porcentaje = true; hasError = true; }
      if (hasError) { window.saeApi.toast('error', 'Todos los campos son obligatorios. El porcentaje debe ser un valor entre 1 y 100'); return; }
      try {
        const payload = { nombreBeca: this.nuevoTipoBecaData.nombreBeca, criterio: this.nuevoTipoBecaData.criterio, porcentaje: p };
        let res;
        if (this.nuevoTipoBecaData.becaId) {
          res = await window.saeApi.becas.catalogo.actualizar(this.nuevoTipoBecaData.becaId, payload);
        } else {
          res = await window.saeApi.becas.catalogo.crear(payload);
        }
        if (res && res.ok) {
          window.saeApi.toast('exito', this.nuevoTipoBecaData.becaId ? 'Tipo de beca actualizado correctamente' : 'Tipo de beca registrado correctamente');
          this.modalNuevoTipoBeca = false;
          this.cargarCatalogoBecas();
        } else { window.saeApi.toast('error', res?.message || 'Error al guardar beca'); }
      } catch (e) { window.saeApi.toast('error', 'Error de red al guardar beca'); }
    },

    // ── Modal asignación de beca ──────────────────────────────────────────────
    abrirModalBeca() {
      this.modalBecaActiva = true;
      this.nuevaBeca = { alumnoId: null, becaId: null, observaciones: '' };
      this.busquedaAlumnoBeca = '';
      this.alumnosBecaFiltrados = [];
      this.cargarCatalogoBecas();
    },
    abrirModalBecaDesdeAlumno(alumno) {
      this.abrirModalBeca();
      this.nuevaBeca.alumnoId = alumno.id;
      this.busquedaAlumnoBeca = alumno.nombre + ' (' + alumno.matricula + ')';
    },
    filtrarAlumnosBeca() {
      const q = this.busquedaAlumnoBeca.toLowerCase();
      if (q.trim() === '') { this.alumnosBecaFiltrados = []; return; }
      this.alumnosBecaFiltrados = this.listaAlumnos.filter(a =>
        a.nombre.toLowerCase().includes(q) || a.matricula.toLowerCase().includes(q)
      );
    },

    // ── Asignar / Retirar ─────────────────────────────────────────────────────
    async asignarBeca() {
      if (!this.nuevaBeca.alumnoId) { window.saeApi.toast('advertencia', 'Selecciona un alumno de la lista.'); return; }
      if (!this.nuevaBeca.becaId) { window.saeApi.toast('advertencia', 'Selecciona un tipo de beca del catálogo.'); return; }
      if (!this.tienePermiso('becas', 'escritura')) { window.saeApi.toast('error', 'No tienes permisos para asignar becas.'); return; }
      const alumnoObj = this.listaAlumnos.find(a => a.id === Number(this.nuevaBeca.alumnoId));
      const payload = { alumnoId: Number(this.nuevaBeca.alumnoId), becaId: Number(this.nuevaBeca.becaId), motivo: this.nuevaBeca.observaciones || '' };
      const res = await window.saeApi.becas.asignar(payload);
      if (res.ok) {
        this.modalBecaActiva = false;
        this.cargarBecasAsignadas();
        window.saeApi.toast('exito', `Beca asignada a ${alumnoObj?.nombre || 'alumno'}.`);
        if (this.alumnoActualFicha && this.alumnoActualFicha.id === payload.alumnoId) {
          this.seleccionarAlumnoFicha(this.alumnoActualFicha);
        }
      } else { window.saeApi.toast('error', res.message || 'Error al asignar beca.'); }
    },
    async retirarBeca(becaAsignada) {
      const motivo = prompt('Ingresa el motivo del retiro de la beca (Obligatorio):');
      if (motivo === null) return;
      if (!motivo.trim()) { window.saeApi.toast('advertencia', 'El motivo del retiro es obligatorio.'); return; }
      if (!this.tienePermiso('becas', 'escritura')) { window.saeApi.toast('error', 'No tienes permisos para retirar becas.'); return; }
      const res = await window.saeApi.becas.retirar(becaAsignada.id, { motivoRetiro: motivo.trim() });
      if (res.ok) {
        window.saeApi.toast('exito', 'Beca retirada correctamente. La colegiatura se actualizará al 100% a partir del siguiente periodo.');
        this.cargarBecasAsignadas();
        if (this.alumnoActualFicha && this.alumnoActualFicha.id === becaAsignada.alumnoId) {
          this.seleccionarAlumnoFicha(this.alumnoActualFicha);
        }
      } else { window.saeApi.toast('error', res.message || 'Error al retirar beca.'); }
    },
  };
}
