/**
 * modules/tutores.js
 * Tutores mixin: directorio tutores, ficha, facturación, vinculación, consolidado
 */
function tutoresMixin() {
  return {
    // ── Estado ───────────────────────────────────────────────────────────────
    busquedaTutor: '',
    filtroFacturacionTutor: '',
    tutoresRegistrados: [],
    tutoresFiltrados: [],
    tutorSeleccionado: false,
    tutorActualFicha: null,
    tutorFichaEditable: {},
    errorFacturacion: false,
    editandoInfoTutor: false,
    editandoFacturacionTutor: false,
    historialPagosTutor: [],
    estadoCuentaConsolidado: [],
    totalDeudaConsolidada: 0,
    modalPagoConsolidado: false,
    pagoConsolidadoTemp: { metodo: 'transferencia', comprobante: null, abonos: {} },

    // ── Nuevo tutor ──────────────────────────────────────────────────────────
    modalNuevoTutor: false,
    nuevoTutorData: { nombreCompleto: '', telefono: '', correoElectronico: '', rfc: '', regimenFiscal: '', correoFacturacion: '', requiereFactura: false },

    // ── Vinculación alumno desde tutor ───────────────────────────────────────
    modalVincularAlumno: false,
    busquedaVincularAlumno: '',
    alumnosParaVincular: [],

    // ── API ──────────────────────────────────────────────────────────────────
    async _cargarTutoresAPI() {
      try {
        const res = await window.saeApi.tutores.listar();
        if (res && res.ok && res.data) {
          this.tutoresRegistrados = res.data;
          this.filtrarTutores();
        }
      } catch (e) { console.error(e); }
    },
    filtrarTutores() {
      const q = this.busquedaTutor.toLowerCase();
      this.tutoresFiltrados = this.tutoresRegistrados.filter(t => {
        const matchQ = (t.nombreCompleto || '').toLowerCase().includes(q) ||
          (t.rfc || '').toLowerCase().includes(q) ||
          (t.correoElectronico || '').toLowerCase().includes(q);
        const matchF = this.filtroFacturacionTutor === '' ||
          (this.filtroFacturacionTutor === 'si' && t.requiereFactura) ||
          (this.filtroFacturacionTutor === 'no' && !t.requiereFactura);
        return matchQ && matchF;
      });
    },
    async seleccionarTutorFicha(tut) {
      try {
        const res = await window.saeApi.tutores.obtener(tut.tutorId || tut.id);
        if (res && res.ok && res.data) {
          this.tutorActualFicha = res.data;
          this.tutorFichaEditable = { ...res.data };
          this.tutorSeleccionado = true;
        }
      } catch (e) { window.saeApi.toast('error', 'Error al cargar perfil del tutor'); }
    },
    openNuevoTutor() {
      this.nuevoTutorData = { nombreCompleto: '', telefono: '', correoElectronico: '', rfc: '', regimenFiscal: '', correoFacturacion: '', requiereFactura: false };
      this.modalNuevoTutor = true;
    },
    async guardarNuevoTutor() {
      if (!this.nuevoTutorData.nombreCompleto) {
        window.saeApi.toast('advertencia', 'El nombre del tutor es obligatorio');
        return;
      }
      try {
        const res = await window.saeApi.tutores.crear(this.nuevoTutorData);
        if (res && res.ok) {
          window.saeApi.toast('exito', 'Tutor registrado correctamente');
          this.modalNuevoTutor = false;
          this._cargarTutoresAPI();
        } else { window.saeApi.toast('error', res?.message || 'Error al guardar'); }
      } catch (e) { window.saeApi.toast('error', 'Error de red'); }
    },
    _validarFacturacion() {
      let errores = [];
      const rfc = this.tutorFichaEditable.rfc || '';
      if (rfc.length < 12 || rfc.length > 13) errores.push('El RFC debe tener 12 o 13 caracteres');
      if (!this.tutorFichaEditable.regimenFiscal) errores.push('Falta seleccionar el Régimen Fiscal');
      if (!this.tutorFichaEditable.usoCfdi) errores.push('Falta seleccionar el Uso de CFDI');
      const cp = this.tutorFichaEditable.codigoPostal || '';
      if (cp.length !== 5) errores.push('El Código Postal debe tener 5 dígitos');
      if (!(this.tutorFichaEditable.direccionFiscal || '').trim()) errores.push('Falta la Dirección Fiscal');
      if (!(this.tutorFichaEditable.correoFacturacion || '').includes('@')) errores.push('El correo de facturación es inválido');
      return errores;
    },
    async guardarCambiosTutor() {
      if (this.tutorFichaEditable.requiereFactura) {
        const errores = this._validarFacturacion();
        if (errores.length > 0) { this.errorFacturacion = true; window.saeApi.toast('error', errores[0]); return; }
      }
      this.errorFacturacion = false;
      try {
        const payload = {
          nombreCompleto: this.tutorFichaEditable.nombreCompleto,
          telefono: this.tutorFichaEditable.telefono,
          correoElectronico: this.tutorFichaEditable.correoElectronico,
          direccion: this.tutorFichaEditable.direccion,
          rfc: this.tutorFichaEditable.rfc,
          regimenFiscal: this.tutorFichaEditable.regimenFiscal,
          usoCfdi: this.tutorFichaEditable.usoCfdi,
          direccionFiscal: this.tutorFichaEditable.direccionFiscal,
          codigoPostal: this.tutorFichaEditable.codigoPostal,
          correoFacturacion: this.tutorFichaEditable.correoFacturacion,
          requiereFactura: this.tutorFichaEditable.requiereFactura,
        };
        const res = await window.saeApi.tutores.actualizar(this.tutorActualFicha.tutorId, payload);
        if (res && res.ok) {
          window.saeApi.toast('exito', 'Informacion modificada correctamente');
          this.editandoInfoTutor = false;
          this._cargarTutoresAPI();
        } else { window.saeApi.toast('error', res?.message || 'Error al guardar'); }
      } catch (e) { window.saeApi.toast('error', 'Error de red al actualizar tutor'); }
    },
    async guardarFacturacionTutor() {
      if (this.tutorFichaEditable.requiereFactura) {
        const errores = this._validarFacturacion();
        if (errores.length > 0) { this.errorFacturacion = true; window.saeApi.toast('error', errores[0]); return; }
      }
      this.errorFacturacion = false;
      try {
        const payload = {
          nombreCompleto: this.tutorFichaEditable.nombreCompleto,
          telefono: this.tutorFichaEditable.telefono,
          correoElectronico: this.tutorFichaEditable.correoElectronico,
          direccion: this.tutorFichaEditable.direccion,
          rfc: this.tutorFichaEditable.rfc,
          regimenFiscal: this.tutorFichaEditable.regimenFiscal,
          usoCfdi: this.tutorFichaEditable.usoCfdi,
          direccionFiscal: this.tutorFichaEditable.direccionFiscal,
          codigoPostal: this.tutorFichaEditable.codigoPostal,
          correoFacturacion: this.tutorFichaEditable.correoFacturacion,
          requiereFactura: this.tutorFichaEditable.requiereFactura,
        };
        const res = await window.saeApi.tutores.actualizar(this.tutorActualFicha.tutorId, payload);
        if (res && res.ok) {
          window.saeApi.toast('exito', 'Datos fiscales modificado correctamente');
          this.editandoFacturacionTutor = false;
          this._cargarTutoresAPI();
          setTimeout(() => { if (window.lucide) window.lucide.createIcons(); }, 150);
        } else { window.saeApi.toast('error', res?.message || 'Error al guardar facturación'); }
      } catch (e) { window.saeApi.toast('error', 'Error de red al actualizar facturación'); }
    },

    // ── Vinculación ──────────────────────────────────────────────────────────
    abrirModalVincularAlumno() {
      this.busquedaVincularAlumno = '';
      this.alumnosParaVincular = [];
      this.modalVincularAlumno = true;
    },
    async buscarAlumnoParaVincular() {
      const q = this.busquedaVincularAlumno.toLowerCase();
      if (q.length < 3) { this.alumnosParaVincular = []; return; }
      try {
        const res = await window.saeApi.alumnos.listar({ q: q, limit: 5 });
        if (res && res.ok && Array.isArray(res.data)) { this.alumnosParaVincular = res.data; }
      } catch (e) { console.error(e); this.alumnosParaVincular = []; }
    },
    async confirmarVinculacionAlumno(alumno) {
      try {
        const payload = { alumnoId: alumno.id, tipoRelacion: 'tutor', esResponsableFinanciero: false };
        const res = await window.saeApi.tutores.vincular(this.tutorActualFicha.tutorId, payload);
        if (res && res.ok) {
          window.saeApi.toast('exito', 'Alumno vinculado correctamente');
          this.modalVincularAlumno = false;
          this.seleccionarTutorFicha(this.tutorActualFicha);
        } else { window.saeApi.toast('error', res?.message || 'Error al vincular alumno'); }
      } catch (e) { window.saeApi.toast('error', 'Error de red al vincular'); }
    },
    async desvincularAlumno(alumnoId) {
      if (!confirm('¿Estás seguro de desvincular este alumno de este tutor?')) return;
      try {
        const res = await window.saeApi.tutores.desvincular(this.tutorActualFicha.tutorId, alumnoId);
        if (res && res.ok) {
          window.saeApi.toast('exito', 'Alumno desvinculado');
          this.seleccionarTutorFicha(this.tutorActualFicha);
        } else { window.saeApi.toast('error', res?.message || 'Error al desvincular'); }
      } catch (e) { window.saeApi.toast('error', 'Error de red'); }
    },
    abrirModalVincularTutor() {
      this.busquedaVincularTutor = '';
      this.tutoresParaVincular = [];
      this.modalVincularTutor = true;
    },
    async buscarTutorParaVincular() {
      const q = this.busquedaVincularTutor.toLowerCase();
      if (q.length < 3) { this.tutoresParaVincular = []; return; }
      try {
        const res = await window.saeApi.tutores.listar({ q: q, limit: 5 });
        if (res && res.ok && Array.isArray(res.data)) { this.tutoresParaVincular = res.data; }
      } catch (e) { console.error(e); this.tutoresParaVincular = []; }
    },
    async confirmarVinculacionTutor(tutor) {
      try {
        const payload = { alumnoId: this.alumnoActualFicha.id, tipoRelacion: 'tutor', esResponsableFinanciero: false };
        const res = await window.saeApi.tutores.vincular(tutor.tutorId, payload);
        if (res && res.ok) {
          window.saeApi.toast('exito', 'Tutor vinculado correctamente');
          this.modalVincularTutor = false;
          this.seleccionarAlumnoFicha(this.alumnoActualFicha);
        } else { window.saeApi.toast('error', res?.message || 'Error al vincular'); }
      } catch (e) { window.saeApi.toast('error', 'Error de red'); }
    },
    async desvincularTutor(tutorId) {
      if (!confirm('¿Seguro que deseas desvincular este tutor del alumno?')) return;
      try {
        const res = await window.saeApi.tutores.desvincular(tutorId, this.alumnoActualFicha.id);
        if (res && res.ok) {
          window.saeApi.toast('exito', 'Tutor desvinculado');
          this.seleccionarAlumnoFicha(this.alumnoActualFicha);
        } else { window.saeApi.toast('error', res?.message || 'Error al desvincular'); }
      } catch (e) { window.saeApi.toast('error', 'Error de red'); }
    },

    // ── Estado de cuenta consolidado ─────────────────────────────────────────
    async _cargarEstadoCuentaConsolidado() {
      if (!this.tutorActualFicha) return;
      try {
        const alumnosIds = this.tutorActualFicha.alumnos.map(a => a.alumno.alumnoId);
        if (!alumnosIds.length) { this.estadoCuentaConsolidado = []; this.totalDeudaConsolidada = 0; return; }
        let deudas = [];
        for (const aId of alumnosIds) {
          const res = await window.saeApi.pagos.calendario({ alumnoId: aId, estadoCobro: 'pendiente,parcial' });
          if (res.ok && res.data) {
            deudas.push(...res.data.map(d => ({ ...d, alumno: this.tutorActualFicha.alumnos.find(x => x.alumno.alumnoId === aId).alumno })));
          }
        }
        this.estadoCuentaConsolidado = deudas.sort((a, b) => new Date(a.fechaVencimiento) - new Date(b.fechaVencimiento));
        this.totalDeudaConsolidada = this.estadoCuentaConsolidado.reduce((sum, item) => sum + Number(item.saldoPendiente || 0), 0);
        setTimeout(() => { if (window.lucide) window.lucide.createIcons(); }, 150);
      } catch (e) { console.error(e); }
    },
    abrirModalPagoConsolidado() {
      this.pagoConsolidadoTemp = { metodo: 'transferencia', comprobante: null, abonos: {} };
      for (const item of this.estadoCuentaConsolidado) {
        this.pagoConsolidadoTemp.abonos[item.calendarioPagoId] = item.saldoPendiente;
      }
      this.modalPagoConsolidado = true;
    },
    async procesarPagoConsolidado() {
      const abonosArray = [];
      let suma = 0;
      for (const key in this.pagoConsolidadoTemp.abonos) {
        const monto = Number(this.pagoConsolidadoTemp.abonos[key]);
        if (monto > 0) { abonosArray.push({ calendarioPagoId: Number(key), montoAbonado: monto }); suma += monto; }
      }
      if (suma <= 0) return window.saeApi.toast('error', 'El monto a pagar debe ser mayor a 0');
      try {
        this.cargando = true;
        const res = await fetch(`/api/v1/pagos/consolidado`, {
          method: 'POST',
          headers: { 'Authorization': 'Bearer ' + localStorage.getItem('token'), 'Content-Type': 'application/json' },
          body: JSON.stringify({ tutorId: this.tutorActualFicha.tutorId, abonos: abonosArray, metodoPago: this.pagoConsolidadoTemp.metodo })
        }).then(r => r.json());
        if (!res.ok) throw new Error(res.message);
        if (this.pagoConsolidadoTemp.comprobante && res.data?.pagoId) {
          const formData = new FormData();
          formData.append('comprobante', this.pagoConsolidadoTemp.comprobante);
          await fetch(`/api/v1/pagos/${res.data.pagoId}/comprobante`, {
            method: 'POST',
            headers: { 'Authorization': 'Bearer ' + localStorage.getItem('token') },
            body: formData
          });
        }
        window.saeApi.toast('exito', 'Pago consolidado registrado');
        this.modalPagoConsolidado = false;
        this._cargarEstadoCuentaConsolidado();
      } catch (e) {
        window.saeApi.toast('error', e.message);
      } finally { this.cargando = false; }
    },
  };
}
