const fs = require('fs');
const content = fs.readFileSync('../frontend/admin_panel.html', 'utf8');

const STATE_ADDITIONS = `
      // ── Directorio Escolar (Alumnos y Tutores) ──────────────────────────────
      tabDirectorio: 'alumnos',
      tabAlumnoFicha: 'academicos',
      busquedaTutor: '',
      tutoresRegistrados: [],
      tutoresFiltrados: [],
      tutorSeleccionado: false,
      tutorActualFicha: null,
      tutorFichaEditable: {},
      alumnoFichaEditable: {},
`;

// Insert the new state variables
let newContent = content.replace(
  `      // ── Módulo: Alumnos ──`,
  STATE_ADDITIONS + `\n      // ── Módulo: Alumnos ──`
);

const METHODS_ADDITIONS = `
      // ── Directorio Escolar (Tutores) ─────────────────────────────────────────
      async _cargarTutoresAPI() {
        try {
          const res = await window.saeApi.tutores.listar();
          if (res && res.ok && res.data) {
            this.tutoresRegistrados = res.data;
            this.filtrarTutores();
          }
        } catch (e) {
          console.error(e);
        }
      },
      filtrarTutores() {
        const q = this.busquedaTutor.toLowerCase();
        this.tutoresFiltrados = this.tutoresRegistrados.filter(t =>
          (t.nombreCompleto || '').toLowerCase().includes(q) ||
          (t.rfc || '').toLowerCase().includes(q) ||
          (t.correoElectronico || '').toLowerCase().includes(q)
        );
      },
      async seleccionarTutorFicha(tut) {
        try {
          const res = await window.saeApi.tutores.obtener(tut.tutorId || tut.id);
          if (res && res.ok && res.data) {
            this.tutorActualFicha = res.data;
            this.tutorFichaEditable = { ...res.data };
            this.tutorSeleccionado = true;
          }
        } catch (e) {
          window.saeApi.toast('error', 'Error al cargar perfil del tutor');
        }
      },
      openNuevoTutor() {
        // Here we could open a modal for creating a new tutor
        window.saeApi.toast('info', 'Por implementar: Modal Alta Tutor');
      },
      async guardarCambiosTutor() {
        try {
          const payload = {
            nombreCompleto: this.tutorFichaEditable.nombreCompleto,
            telefono: this.tutorFichaEditable.telefono,
            correoElectronico: this.tutorFichaEditable.correoElectronico,
            rfc: this.tutorFichaEditable.rfc,
            regimenFiscal: this.tutorFichaEditable.regimenFiscal,
            correoFacturacion: this.tutorFichaEditable.correoFacturacion,
            requiereFactura: this.tutorFichaEditable.requiereFactura,
          };
          const res = await window.saeApi.tutores.actualizar(this.tutorActualFicha.tutorId, payload);
          if (res && res.ok) {
            window.saeApi.toast('exito', 'Perfil del tutor actualizado');
            this._cargarTutoresAPI();
          } else {
            window.saeApi.toast('error', res?.message || 'Error al guardar');
          }
        } catch (e) {
          window.saeApi.toast('error', 'Error de red al actualizar tutor');
        }
      },
      abrirModalPagoDesdeAlumno(al) {
        // Simulates selecting a student and opening the payment modal
        this.alumnoActualFicha = al;
        this.abrirModalPago();
      },
      abrirModalVincularTutor() {
        // Will be implemented to link an existing tutor via modal
        window.saeApi.toast('info', 'Por implementar: Modal Vincular Tutor');
      },
      async desvincularTutor(tutorId) {
        if (!confirm('¿Seguro que deseas desvincular este tutor del alumno?')) return;
        try {
          const res = await window.saeApi.tutores.desvincular(tutorId, this.alumnoActualFicha.id);
          if (res && res.ok) {
            window.saeApi.toast('exito', 'Tutor desvinculado');
            this.seleccionarAlumnoFicha(this.alumnoActualFicha); // Reload
          } else {
            window.saeApi.toast('error', res?.message || 'Error al desvincular');
          }
        } catch (e) {
          window.saeApi.toast('error', 'Error de red');
        }
      },
      async guardarCambiosAlumno() {
        // Simplified academic edit
        try {
          const payload = {
            nombre: this.alumnoFichaEditable.nombre,
            curp: this.alumnoFichaEditable.curp,
            estado: this.alumnoFichaEditable.estado,
            observaciones: this.alumnoFichaEditable.autorizados // Using as authorized persons
          };
          const res = await window.saeApi.alumnos.actualizar(this.alumnoActualFicha.id, payload);
          if (res && res.ok) {
            window.saeApi.toast('exito', 'Expediente actualizado');
            this._cargarAlumnosAPI();
          } else {
            window.saeApi.toast('error', res?.message || 'Error al actualizar');
          }
        } catch (e) {
          window.saeApi.toast('error', 'Error de red');
        }
      },
      async confirmarBajaAlumno() {
        if (!confirm('¿Estás seguro de dar de BAJA DEFINITIVA a este alumno?')) return;
        try {
          const res = await window.saeApi.alumnos.eliminar(this.alumnoActualFicha.id);
          if (res && res.ok) {
            window.saeApi.toast('exito', 'Alumno dado de baja definitivamente');
            this.alumnoSeleccionado = false;
            this._cargarAlumnosAPI();
          } else {
            window.saeApi.toast('error', res?.message || 'Error al dar de baja');
          }
        } catch (e) {
          window.saeApi.toast('error', 'Error de red');
        }
      },
`;

newContent = newContent.replace(
  `      // ── Alumnos ─────────────────────────────────────────────────────────────`,
  METHODS_ADDITIONS + `\n      // ── Alumnos ─────────────────────────────────────────────────────────────`
);

// We need to patch seleccionarAlumnoFicha to map padresLista
const oldSeleccionar = `
      seleccionarAlumnoFicha(al) {
        this.alumnoActualFicha = al;
        this.alumnoSeleccionado = true;
        this.tabAlumno = 'academicos';
      },`;

const newSeleccionar = `
      seleccionarAlumnoFicha(al) {
        // Ensure we fetch fresh data via API
        window.saeApi.alumnos.obtener(al.id).then(res => {
          if (res && res.ok && res.data) {
            this.alumnoActualFicha = res.data;
            this.alumnoActualFicha.padresLista = res.data.padres || [];
            this.alumnoFichaEditable = {
              nombre: res.data.nombre,
              curp: res.data.curp,
              estado: res.data.estado || 'Activo',
              autorizados: typeof res.data.personasAutorizadas === 'string' ? res.data.personasAutorizadas : (res.data.autorizados || '')
            };
            this.alumnoSeleccionado = true;
            this.tabAlumnoFicha = 'academicos';
          }
        });
      },`;

newContent = newContent.replace(oldSeleccionar, newSeleccionar);

fs.writeFileSync('../frontend/admin_panel.html', newContent);
console.log('Patched admin_panel.html successfully!');
