/**
 * modules/pagos.js
 * Pagos mixin: registro de pagos, autocomplete, adeudos, recargos, recibo, modal pago
 */
function pagosMixin() {
  return {
    // ── Estado ───────────────────────────────────────────────────────────────
    pagosRegistrados: [],
    paginaPagos: 1, limitPagos: 25, totalPagos: 0, paginasPagos: 1,
    nuevoPago: {
      alumnoId: null, alumno: '', concepto: 'Colegiatura', monto: '',
      fecha: new Date().toISOString().split('T')[0], becaInfo: null,
      tipoPago: 'normal', mesesAdelantar: 1
    },
    pagoAdeudos: [],
    recargoEditando: null,
    formRecargo: { montoNuevo: '', motivo: '' },
    pagoCalculando: false,
    reciboGenerado: null,
    alumnoPagoInfo: null,

    // ── Autocomplete pago ────────────────────────────────────────────────────
    busquedaPagoAlumno: '',
    pagoCoincidencias: [],
    mostrarSugerenciasPago: false,

    // ── API ──────────────────────────────────────────────────────────────────
    async _cargarPagosAPI(pagina) {
      const p = pagina || this.paginaPagos;
      const res = await window.saeApi.pagos.listar({ page: p, limit: this.limitPagos });
      if (res.ok) {
        const lista = res.pagination ? res.data : (Array.isArray(res.data) ? res.data : []);
        this.pagosRegistrados = lista.map(window.saeApi.mapPago);
        if (res.pagination) {
          this.paginaPagos = res.pagination.page;
          this.totalPagos = res.pagination.total;
          this.paginasPagos = res.pagination.pages;
        }
      }
    },
    async _irPaginaPagos(p) {
      if (p < 1 || p > this.paginasPagos) return;
      await this._cargarPagosAPI(p);
    },

    // ── Modal de pago ────────────────────────────────────────────────────────
    abrirModalPago() {
      this.modal = 'pago';
      this.busquedaPagoAlumno = '';
      this.pagoCoincidencias = [];
      this.mostrarSugerenciasPago = false;
      this.nuevoPago = {
        alumno: '', alumnoId: null, concepto: 'Colegiatura', monto: '',
        fecha: new Date().toISOString().slice(0, 10), becaInfo: null,
        tipoPago: 'normal', mesesAdelantar: 1, metodoPago: 'transferencia'
      };
    },
    abrirModalPagoDesdeAlumno(al) {
      this.alumnoActualFicha = al;
      this.abrirModalPago();
      setTimeout(() => { this.seleccionarPagoAlumno(al); }, 50);
    },
    async filtrarPagoAlumnos() {
      const q = this.busquedaPagoAlumno.trim().toLowerCase();
      if (!q) {
        this.pagoCoincidencias = []; this.mostrarSugerenciasPago = false;
        this.nuevoPago.alumno = ''; this.nuevoPago.alumnoId = null;
        return;
      }
      try {
        const res = await window.saeApi.alumnos.listar({ q: q, limit: 10 });
        if (res.ok) {
          const data = res.pagination ? res.data : (Array.isArray(res.data) ? res.data : []);
          this.pagoCoincidencias = data.map(window.saeApi.mapAlumno);
        } else { this.pagoCoincidencias = []; }
      } catch (e) { this.pagoCoincidencias = []; }
      this.mostrarSugerenciasPago = true;
      if (this.nuevoPago.alumno && this.busquedaPagoAlumno !== this.nuevoPago.alumno) {
        this.nuevoPago.alumno = ''; this.nuevoPago.alumnoId = null;
      }
    },
    limpiarSeleccionPago() {
      this.busquedaPagoAlumno = ''; this.nuevoPago.alumno = ''; this.nuevoPago.alumnoId = null;
      this.nuevoPago.monto = ''; this.nuevoPago.concepto = 'Colegiatura';
      this.pagoAdeudos = []; this.mostrarSugerenciasPago = false;
      this.$nextTick(() => { lucide.createIcons(); });
    },
    async seleccionarPagoAlumno(al) {
      this.nuevoPago.alumno = al.nombre;
      this.nuevoPago.alumnoId = al.id;
      this.busquedaPagoAlumno = al.nombre;
      this.mostrarSugerenciasPago = false;
      this.pagoCoincidencias = [];
      this.pagoAdeudos = [];
      this.pagoCalculando = true;
      try {
        this.alumnoPagoInfo = null;
        this.nuevoPago.becaInfo = null;
        const alRes = await window.saeApi.alumnos.obtener(al.id);
        if (alRes.ok && alRes.data) {
          this.alumnoPagoInfo = alRes.data;
          if (alRes.data.beca) {
            this.nuevoPago.becaInfo = { nombre: alRes.data.beca.nombreBeca, porcentaje: Number(alRes.data.beca.porcentaje) };
          }
        }
        const res = await window.saeApi.pagos.calendario({ alumnoId: al.id, estadoCobro: 'pendiente' });
        if (res.ok && res.data) {
          this.pagoAdeudos = res.data;
          let total = 0;
          res.data.forEach(d => {
            let deuda = Number(d.montoOriginal) + Number(d.montoRecargo) - Number(d.montoPagado);
            if (d.concepto === 'colegiatura' && this.nuevoPago.becaInfo) {
              const descuento = (deuda * this.nuevoPago.becaInfo.porcentaje) / 100;
              deuda -= descuento;
            }
            total += Math.max(0, deuda);
          });
          this.nuevoPago.monto = total.toFixed(2);
          if (res.data.length > 0) {
            const firstA = res.data[0];
            const cMap = { 'COLEGIATURA': 'Colegiatura', 'INSCRIPCION': 'Inscripción', 'MATERIAL_DIDACTICO': 'Material didáctico', 'UNIFORME': 'Uniforme' };
            const mappedC = cMap[firstA.concepto.toUpperCase()];
            if (mappedC) this.nuevoPago.concepto = mappedC;
          }
        }
      } catch (e) { console.error(e); }
      finally { this.pagoCalculando = false; }
    },
    seleccionarAdeudoIndividual(adeudo) {
      const cMap = { 'COLEGIATURA': 'Colegiatura', 'INSCRIPCION': 'Inscripción', 'MATERIAL': 'Material Didáctico', 'UNIFORME': 'Uniforme' };
      this.nuevoPago.concepto = cMap[adeudo.concepto.toUpperCase()] || 'Colegiatura';
      let deuda = Number(adeudo.montoOriginal) + Number(adeudo.montoRecargo) - Number(adeudo.montoPagado);
      if (adeudo.concepto === 'colegiatura' && this.nuevoPago.becaInfo) {
        const descuento = (deuda * this.nuevoPago.becaInfo.porcentaje) / 100;
        deuda -= descuento;
      }
      this.nuevoPago.monto = deuda.toFixed(2);
    },
    calcularAdelanto() {
      if (!this.nuevoPago.alumnoId) return;
      const numMeses = parseInt(this.nuevoPago.mesesAdelantar) || 1;
      const colegiaturas = this.pagoAdeudos.filter(a => a.concepto.toLowerCase() === 'colegiatura');
      let montoMensual = 0;
      if (colegiaturas.length > 0) { montoMensual = Number(colegiaturas[0].montoOriginal); }
      const aAdelantar = colegiaturas.slice(0, numMeses);
      let total = 0;
      for (const deud of aAdelantar) {
        let cobro = Number(deud.montoOriginal);
        const recargo = Number(deud.montoRecargo) || 0;
        const pagado = Number(deud.montoPagado) || 0;
        let deuda = Math.max(0, (cobro + recargo) - pagado);
        if (this.nuevoPago.becaInfo) {
          const descuento = (deuda * this.nuevoPago.becaInfo.porcentaje) / 100;
          deuda -= descuento;
        }
        total += deuda;
      }
      const faltantes = numMeses - aAdelantar.length;
      if (faltantes > 0 && montoMensual > 0) {
        let cuotaFaltante = montoMensual;
        if (this.nuevoPago.becaInfo) {
          const descuento = (cuotaFaltante * this.nuevoPago.becaInfo.porcentaje) / 100;
          cuotaFaltante -= descuento;
        }
        total += (faltantes * cuotaFaltante);
      }
      this.nuevoPago.monto = total.toFixed(2);
    },
    autofillMonto() {
      if (!this.pagoAdeudos || this.pagoAdeudos.length === 0) return;
      if (this.nuevoPago.concepto === 'Total') {
        let total = 0;
        this.pagoAdeudos.forEach(d => {
          let deuda = Number(d.montoOriginal) + Number(d.montoRecargo) - Number(d.montoPagado);
          if (d.concepto === 'colegiatura' && this.nuevoPago.becaInfo) {
            const descuento = (deuda * this.nuevoPago.becaInfo.porcentaje) / 100;
            deuda -= descuento;
          }
          total += Math.max(0, deuda);
        });
        this.nuevoPago.monto = total.toFixed(2);
        return;
      }
      const normalize = (str) => str.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toUpperCase();
      const selConcepto = normalize(this.nuevoPago.concepto);
      const adeudosDelConcepto = this.pagoAdeudos.filter(a => {
        const dbConcepto = normalize(a.concepto);
        if (selConcepto.includes('MATERIAL') && dbConcepto.includes('MATERIAL')) return true;
        if (selConcepto.includes('INSCRIPCION') && dbConcepto.includes('INSCRIPCION')) return true;
        if (selConcepto.includes('UNIFORME') && dbConcepto.includes('UNIFORME')) return true;
        if (selConcepto.includes('COLEGIATURA') && dbConcepto.includes('COLEGIATURA')) return true;
        return dbConcepto === selConcepto;
      });
      if (adeudosDelConcepto.length > 0) {
        let total = 0;
        adeudosDelConcepto.forEach(d => {
          let deuda = Number(d.montoOriginal) + Number(d.montoRecargo) - Number(d.montoPagado);
          if (d.concepto === 'colegiatura' && this.nuevoPago.becaInfo) {
            const descuento = (deuda * this.nuevoPago.becaInfo.porcentaje) / 100;
            deuda -= descuento;
          }
          total += Math.max(0, deuda);
        });
        this.nuevoPago.monto = total.toFixed(2);
      } else { this.nuevoPago.monto = ''; }
    },

    // ── Recargos ─────────────────────────────────────────────────────────────
    iniciarEdicionRecargo(recargo) {
      this.recargoEditando = recargo;
      this.formRecargo.montoNuevo = recargo.montoActual;
      this.formRecargo.motivo = recargo.motivoModificacion || '';
    },
    async guardarRecargo() {
      if (!this.formRecargo.motivo || this.formRecargo.motivo.trim().length < 3) {
        window.saeApi.toast('advertencia', 'El motivo de la modificación es obligatorio.');
        return;
      }
      if (this.formRecargo.montoNuevo === '' || Number(this.formRecargo.montoNuevo) < 0) {
        window.saeApi.toast('advertencia', 'Ingresa un monto válido.');
        return;
      }
      const esCero = Number(this.formRecargo.montoNuevo) === 0;
      if (esCero && !confirm('¿Estás seguro de condonar totalmente este recargo?')) { return; }
      const res = await window.saeApi.pagos.modificarRecargo(this.recargoEditando.recargoId, {
        montoNuevo: Number(this.formRecargo.montoNuevo), motivo: this.formRecargo.motivo
      });
      if (res.ok) {
        window.saeApi.toast('exito', res.message);
        this.recargoEditando = null;
        if (this.nuevoPago.alumnoId) {
          const al = this.pagoCoincidencias.find(x => x.id === this.nuevoPago.alumnoId) || this.listaAlumnos.find(x => x.id === this.nuevoPago.alumnoId) || { id: this.nuevoPago.alumnoId, nombre: this.nuevoPago.alumno };
          this.seleccionarPagoAlumno(al);
        }
        lucide.createIcons();
      } else { window.saeApi.toast('error', res.message || 'Error al modificar el recargo.'); }
    },

    // ── Registrar pago ───────────────────────────────────────────────────────
    async agregarPago() {
      if (!this.nuevoPago.alumnoId) { window.saeApi.toast('advertencia', 'Selecciona un alumno de la lista de sugerencias.'); return; }
      if (!this.nuevoPago.monto) { window.saeApi.toast('advertencia', 'Ingresa el monto del pago.'); return; }
      const concepto = window.saeApi.CONCEPTO_MAP[this.nuevoPago.concepto] || 'OTRO';
      let res;
      if (this.nuevoPago.tipoPago === 'adelantado') {
        res = await window.saeApi.pagos.adelantado({
          alumnoId: this.nuevoPago.alumnoId, meses: parseInt(this.nuevoPago.mesesAdelantar),
          metodoPago: this.nuevoPago.metodoPago, fecha: this.nuevoPago.fecha, monto: parseFloat(this.nuevoPago.monto)
        });
        this.nuevoPago.concepto = `Adelanto de ${this.nuevoPago.mesesAdelantar} meses`;
      } else {
        res = await window.saeApi.pagos.registrar({
          alumnoId: this.nuevoPago.alumnoId, concepto, monto: parseFloat(this.nuevoPago.monto),
          fecha: this.nuevoPago.fecha, metodoPago: this.nuevoPago.metodoPago,
        });
      }
      if (res.ok) {
        const pagoId = res.data.pagoId || res.data.id;
        const fileInput = document.getElementById('comprobanteInputPago');
        let comprobanteMsj = '';
        if (fileInput && fileInput.files && fileInput.files.length > 0) {
          const uploadRes = await window.saeApi.pagos.subirComprobante(pagoId, fileInput.files[0]);
          if (!uploadRes.ok) { window.saeApi.toast('advertencia', 'Pago registrado, pero falló la subida del comprobante.'); }
          else { comprobanteMsj = ' con comprobante adjunto'; }
        }
        this.pagosRegistrados.unshift(window.saeApi.mapPago(res.data));
        this.reciboGenerado = {
          id: pagoId || Math.floor(Math.random() * 10000), alumno: this.nuevoPago.alumno,
          concepto: this.nuevoPago.concepto, fecha: new Date().toLocaleString('es-MX'),
          monto: parseFloat(this.nuevoPago.monto).toFixed(2)
        };
        window.saeApi.toast('exito', `Pago de $${this.nuevoPago.monto} registrado para ${this.nuevoPago.alumno}${comprobanteMsj}.`);
        if (typeof this.cargarAlumnos === 'function') this.cargarAlumnos();
        if (typeof this._cargarDashboard === 'function') this._cargarDashboard();
        this.nuevoPago.alumno = ''; this.nuevoPago.alumnoId = null; this.nuevoPago.monto = '';
        this.nuevoPago.tipoPago = 'normal'; this.nuevoPago.mesesAdelantar = 1;
        this.busquedaPagoAlumno = ''; this.pagoAdeudos = [];
        if (fileInput) fileInput.value = '';
      } else { window.saeApi.toast('error', res.message || 'Error al registrar pago.'); }
    },
    imprimirRecibo() { window.print(); },
  };
}
