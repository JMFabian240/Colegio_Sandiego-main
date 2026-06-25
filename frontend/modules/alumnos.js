/**
 * modules/alumnos.js
 * Alumnos mixin: directorio, ficha, CRUD, filtros, exportar, planes de pago
 */
function alumnosMixin() {
  return {
    // ── Estado ───────────────────────────────────────────────────────────────
    listaAlumnos: [],
    alumnosFiltrados: [],
    alumnosCoincidencias: [],
    busquedaAlumno: '',
    filtroNivel: '',
    filtroGrado: '',
    filtroSeccion: '',
    filtroEstadoAlumno: '',
    paginaAlumnos: 1, limitAlumnos: 20, totalAlumnos: 0, paginasAlumnos: 1,

    // ── Ficha alumno ─────────────────────────────────────────────────────────
    alumnoSeleccionado: false,
    alumnoActualFicha: null,
    alumnoFichaEditable: {},
    tabAlumnoFicha: 'academicos',
    tabAlumno: 'academicos',
    tabDirectorio: 'alumnos',
    historialPagosAlumno: [],
    historialCalendarioAlumno: [],
    estadoCuentaAlumno: [],
    historialAcademico: [],
    historialExtraBoleta: [],
    historialTallerBoleta: [],
    promedioGeneralFicha: null,
    tutoresAlumnoFicha: [],
    previewPlanCalendario: [],
    previewPlanMeses: null,

    // ── Nuevo alumno ─────────────────────────────────────────────────────────
    modalNuevoAlumno: false,
    nuevoAlumnoData: { nombre: '', matricula: '', curp: '', grupoId: null, padre: '', telefono: '', tutorId: null, fechaNacimiento: '', personasAutorizadas: '', nivel: '', grado: '' },
    erroresNuevoAlumno: {},
    sugerenciasTutor: [],

    // ── Vinculación tutor desde alumno ───────────────────────────────────────
    modalVincularTutor: false,
    busquedaVincularTutor: '',
    tutoresParaVincular: [],

    // ── Computed ─────────────────────────────────────────────────────────────
    get gradosDisponiblesFiltro() {
      if (!this.filtroNivel) return [];
      const nivel = this.filtroNivel.toUpperCase();
      if (nivel === 'PREESCOLAR') return ['1', '2', '3'];
      return ['1', '2', '3', '4', '5', '6'];
    },
    get seccionesDisponiblesFiltro() {
      if (!this.filtroNivel || !this.filtroGrado) return [];
      return ['A', 'B', 'C', 'D', 'E', 'F'];
    },
    get gradosDisponiblesNuevo() {
      if (!this.nuevoAlumnoData.nivel) return [];
      const nivel = this.nuevoAlumnoData.nivel.toUpperCase();
      if (nivel === 'PREESCOLAR') return ['1', '2', '3'];
      return ['1', '2', '3', '4', '5', '6'];
    },
    get gruposDisponiblesNuevo() {
      if (!this.nuevoAlumnoData.nivel || !this.nuevoAlumnoData.grado) return [];
      const nivel = this.nuevoAlumnoData.nivel.toUpperCase();
      return this.gruposData.filter(g => g.nivel && g.nivel.toUpperCase() === nivel && String(g.grado) === String(this.nuevoAlumnoData.grado));
    },
    get gradosDisponiblesFicha() {
      if (!this.alumnoFichaEditable || !this.alumnoFichaEditable.nivel) return [];
      const nivel = this.alumnoFichaEditable.nivel.toUpperCase();
      if (nivel === 'PREESCOLAR') return ['1', '2', '3'];
      return ['1', '2', '3', '4', '5', '6'];
    },
    get gruposDisponiblesFicha() {
      if (!this.alumnoFichaEditable || !this.alumnoFichaEditable.nivel || !this.alumnoFichaEditable.grado) return [];
      const nivel = this.alumnoFichaEditable.nivel.toUpperCase();
      return this.gruposData.filter(g => g.nivel && g.nivel.toUpperCase() === nivel && String(g.grado) === String(this.alumnoFichaEditable.grado));
    },
    get becaAlumnoFicha() {
      if (!this.alumnoActualFicha) return null;
      return this.becasAsignadas.find(b => b.alumnoId === this.alumnoActualFicha.id);
    },

    // ── API ──────────────────────────────────────────────────────────────────
    async _cargarAlumnosAPI(pagina, q) {
      const p = pagina || this.paginaAlumnos;
      const query = q !== undefined ? q : this.busquedaAlumno;
      const params = { page: p, limit: this.limitAlumnos, q: query };
      if (this.filtroEstadoAlumno && this.filtroEstadoAlumno !== 'Todos') {
        params.estado = this.filtroEstadoAlumno;
      }
      if (this.filtroNivel) params.nivel = this.filtroNivel.toUpperCase();
      if (this.filtroGrado) params.grado = this.filtroGrado;
      if (this.filtroSeccion) params.seccion = this.filtroSeccion;

      const res = await window.saeApi.alumnos.listar(params);
      if (res.ok) {
        const lista = res.pagination ? res.data : (Array.isArray(res.data) ? res.data : []);
        this.listaAlumnos = lista.map(window.saeApi.mapAlumno);
        this.filtrarAlumnos();
        if (typeof this.buscarAlumnoCalif === 'function') this.buscarAlumnoCalif();
        if (res.pagination) {
          this.paginaAlumnos = res.pagination.page;
          this.totalAlumnos = res.pagination.total;
          this.paginasAlumnos = res.pagination.pages;
        }
      } else if (!res.offline) {
        window.saeApi.toast('error', res.message || 'Error al cargar alumnos.');
      }
    },
    async _irPaginaAlumnos(p) {
      if (p < 1 || p > this.paginasAlumnos) return;
      await this._cargarAlumnosAPI(p);
    },

    // ── Directorio ───────────────────────────────────────────────────────────
    cargarAlumnos() {
      this.alumnosFiltrados = [...this.listaAlumnos];
    },
    filtrarAlumnos() {
      const q = this.busquedaAlumno.toLowerCase();
      const nivel = this.filtroNivel;
      const grado = this.filtroGrado;
      const seccion = this.filtroSeccion;

      this.alumnosFiltrados = this.listaAlumnos.filter(a => {
        const matchBusqueda = a.nombre.toLowerCase().includes(q) || a.matricula.includes(this.busquedaAlumno);
        const matchNivel = !nivel || (a.nivel && a.nivel.toUpperCase() === nivel.toUpperCase());
        const matchGrado = !grado || a.grado === grado;
        const matchSeccion = !seccion || a.seccion === seccion;
        return matchBusqueda && matchNivel && matchGrado && matchSeccion;
      });
    },
    exportarAlumnosCSV() {
      if (!this.alumnosFiltrados || this.alumnosFiltrados.length === 0) {
        window.saeApi.toast('advertencia', 'No hay alumnos para exportar con estos filtros.');
        return;
      }
      const encabezados = ['Matrícula', 'Nombre Completo', 'Nivel', 'Grupo', 'Estado', 'Tutor Principal', 'Teléfono Tutor'];
      
      const filas = this.alumnosFiltrados.map(a => [
        a.matricula || '',
        `"${a.nombre || ''}"`,
        a.nivel || '',
        a.grupo || '',
        a.estado || 'Activo',
        `"${a.padre || ''}"`,
        a.telefono || ''
      ]);
      const csvContent = [encabezados.join(','), ...filas.map(fila => fila.join(','))].join('\n');
      const blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.setAttribute('href', url);
      link.setAttribute('download', `Directorio_Alumnos_${new Date().toISOString().slice(0, 10)}.csv`);
      link.style.visibility = 'hidden';
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    },
    
    procesarCSVAlumnos(event) {
      const file = event.target.files[0];
      if (!file) return;
      
      window.saeApi.toast('info', 'Procesando archivo CSV...');
      
      Papa.parse(file, {
        header: true,
        skipEmptyLines: true,
        complete: async (results) => {
          try {
            const alumnos = results.data.map(row => ({
              nombre: row['Nombre Completo'] || row['Nombre'] || '',
              matricula: row['Matrícula'] || row['Matricula'] || '',
              curp: row['CURP'] || '',
              padre: row['Tutor Principal'] || row['Padre'] || '',
              telefono: row['Teléfono Tutor'] || row['Teléfono'] || '',
              nivel: row['Nivel'] || '',
            })).filter(a => a.nombre && a.matricula);

            if (alumnos.length === 0) {
              window.saeApi.toast('error', 'No se encontraron alumnos válidos en el CSV');
              return;
            }

            const res = await window.saeApi.fetchApi('/importacion/alumnos', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ alumnos })
            });
            const data = res; // saeApi.fetchApi already returns parsed json if successful
            
            if (res.ok && data.success) {
              window.saeApi.toast('exito', `Se importaron ${data.data.exitosos} alumnos correctamente.`);
              this._cargarAlumnosAPI(1);
            } else {
              window.saeApi.toast('error', data.message || 'Error al importar alumnos');
            }
          } catch (error) {
            console.error('Error importando:', error);
            window.saeApi.toast('error', 'Error al procesar el archivo CSV.');
          } finally {
            event.target.value = '';
          }
        },
        error: (err) => {
          window.saeApi.toast('error', 'No se pudo leer el archivo CSV');
          event.target.value = '';
        }
      });
    },

    // ── Ficha alumno ─────────────────────────────────────────────────────────
    seleccionarAlumnoFicha(al) {
      window.saeApi.alumnos.obtener(al.id).then(async res => {
        if (res && res.ok && res.data) {
          this.alumnoActualFicha = res.data;
          this.alumnoActualFicha.padresLista = res.data.padres || [];
          let rawNivel = (res.data.nivel || res.data.grupo?.nivel || '');
          let nivelFormateado = rawNivel ? rawNivel.charAt(0).toUpperCase() + rawNivel.slice(1).toLowerCase() : '';

          this.alumnoFichaEditable = {
            nombre: res.data.nombre,
            curp: res.data.curp,
            estado: res.data.estado || 'Activo',
            autorizados: typeof res.data.personasAutorizadas === 'string' ? res.data.personasAutorizadas : (res.data.autorizados || ''),
            fechaNacimiento: res.data.fechaNacimiento ? res.data.fechaNacimiento.split('T')[0] : '',
            nivel: nivelFormateado,
            grado: res.data.grupo?.grado ? String(res.data.grupo.grado) : '',
            grupoId: res.data.grupoId || ''
          };
          this.tutoresAlumnoFicha = [];
          this.historialPagosAlumno = [];
          this.alumnoSeleccionado = true;
          this.tabAlumnoFicha = (this.alumnoActualFicha && this.alumnoActualFicha.id === al.id) ? this.tabAlumnoFicha : 'academicos';
          if (this.becasAsignadas.length === 0) this.cargarBecasAsignadas();

          // Cargar Boleta Virtual
          this.historialAcademico = [];
          this.promedioGeneralFicha = null;
          if (al.grupoId) {
            const grupoRes = await window.saeApi.grupos.obtener(al.grupoId);
            if (grupoRes.ok && grupoRes.data && grupoRes.data.materias) {
              const esPre = (grupoRes.data.nivel === 'PREESCOLAR' || (al.nivel && al.nivel.toUpperCase() === 'PREESCOLAR'));
              let sumGral = 0, countGral = 0;
              const materiasArr = grupoRes.data.materias
                .filter(m => m.tipo === 'curricular' || !m.tipo)
                .map(m => ({
                  id: m.id, nombre: m.materia, tipo: m.tipo || 'curricular', T1: { v: '', t: '' }, T2: { v: '', t: '' }, T3: { v: '', t: '' }, prom: null
                }));
              const calRes = await window.saeApi.calificaciones.porAlumno(al.id, undefined);
              if (calRes.ok && calRes.data) {
                calRes.data.forEach(c => {
                  const mat = materiasArr.find(x => x.id === c.grupoMateriaId);
                  if (mat) {
                    const k = String(c.periodo).includes('1') ? 'T1' : String(c.periodo).includes('2') ? 'T2' : 'T3';
                    mat[k].v = (c.valor !== null && c.valor !== undefined) ? c.valor : '';
                    mat[k].t = c.textoObservacion || '';
                  }
                });
              }
              materiasArr.forEach(mat => {
                if (esPre) { mat.prom = 'N/A'; }
                else {
                  let s = 0, c = 0;
                  if (mat.T1.v !== '') { s += parseFloat(mat.T1.v); c++; }
                  if (mat.T2.v !== '') { s += parseFloat(mat.T2.v); c++; }
                  if (mat.T3.v !== '') { s += parseFloat(mat.T3.v); c++; }
                  if (c > 0) { mat.prom = (s / c).toFixed(1); sumGral += parseFloat(mat.prom); countGral++; }
                  else { mat.prom = '-'; }
                }
              });
              this.historialAcademico = materiasArr;
              this.promedioGeneralFicha = esPre ? 'N/A' : (countGral > 0 ? (sumGral / countGral).toFixed(1) : '-');
            }
          }

          // Cargar extracurriculares
          this.historialExtraBoleta = [];
          try {
            const resExtra = await window.saeApi.calificacionesExtra.porAlumno(al.id);
            const clubesMap = {};
            if (al.materiasExtra && al.materiasExtra.length > 0) {
              al.materiasExtra.filter(m => m.tipo === 'club').forEach(m => {
                clubesMap[m.materia] = { id: m.materia, nombre: m.materia, T1: { v: '' }, T2: { v: '' }, T3: { v: '' }, prom: '-' };
              });
            }
            if (resExtra && resExtra.data) {
              resExtra.data.forEach(c => {
                if (!clubesMap[c.club]) {
                  clubesMap[c.club] = { id: c.club, nombre: c.club, T1: { v: '' }, T2: { v: '' }, T3: { v: '' }, prom: '-' };
                }
                const p = c.periodoId;
                let key = null;
                if (p === 1 || String(c.periodo?.nombre).includes('1')) key = 'T1';
                if (p === 2 || String(c.periodo?.nombre).includes('2')) key = 'T2';
                if (p === 3 || String(c.periodo?.nombre).includes('3')) key = 'T3';
                if (key) { clubesMap[c.club][key].v = c.valorNumerico; }
              });
            }
            this.historialExtraBoleta = Object.values(clubesMap).map(club => {
              let s = 0, c = 0;
              if (club.T1.v !== '') { s += parseFloat(club.T1.v); c++; }
              if (club.T2.v !== '') { s += parseFloat(club.T2.v); c++; }
              if (club.T3.v !== '') { s += parseFloat(club.T3.v); c++; }
              if (c > 0) club.prom = (s / c).toFixed(1);
              return club;
            });
          } catch (e) { console.error('Error al cargar extracurriculares:', e); }

          // Cargar taller
          this.historialTallerBoleta = [];
          try {
            const resTaller = await window.saeApi.calificacionesTaller.porAlumno(al.id);
            let nombreTaller = 'Taller';
            const tieneTallerAsignado = al.materiasExtra && al.materiasExtra.some(m => m.tipo === 'taller');
            if (tieneTallerAsignado) {
              const tallerAsignado = al.materiasExtra.find(m => m.tipo === 'taller');
              nombreTaller = tallerAsignado.materia;
            }
            if ((resTaller && resTaller.data && resTaller.data.length > 0) || tieneTallerAsignado) {
              const tallerObj = { id: 'taller', nombre: nombreTaller, T1: { v: '' }, T2: { v: '' }, T3: { v: '' } };
              if (resTaller && resTaller.data) {
                resTaller.data.forEach(c => {
                  const num = c.periodo?.numero;
                  let key = null;
                  if (num === 1) key = 'T1'; if (num === 2) key = 'T2'; if (num === 3) key = 'T3';
                  if (key) { tallerObj[key].v = c.valorCualitativo; }
                });
              }
              const vals = [tallerObj.T1.v, tallerObj.T2.v, tallerObj.T3.v].filter(x => x === 'A' || x === 'NA');
              const countA = vals.filter(x => x === 'A').length;
              const countNA = vals.filter(x => x === 'NA').length;
              tallerObj.eval = vals.length > 0 ? (countA >= countNA ? 'A' : 'NA') : '-';
              this.historialTallerBoleta = [tallerObj];
            }
          } catch (e) { console.error('Error al cargar taller:', e); }

        } else {
          console.error('Error al obtener expediente', res);
          window.saeApi.toast('error', res?.message || 'Error al cargar el expediente del alumno.');
        }
      }).catch(err => {
        console.error('Error de red al obtener expediente', err);
        window.saeApi.toast('error', 'Error de comunicación con el servidor.');
      });
    },

    async guardarCambiosAlumno() {
      try {
        const payload = {
          nombre: this.alumnoFichaEditable.nombre,
          curp: this.alumnoFichaEditable.curp,
          estado: this.alumnoFichaEditable.estado,
          fechaNacimiento: this.alumnoFichaEditable.fechaNacimiento,
          nivel: this.alumnoFichaEditable.nivel,
          grupoId: this.alumnoFichaEditable.grupoId || null
        };
        const res = await window.saeApi.alumnos.actualizar(this.alumnoActualFicha.id, payload);
        if (res && res.ok) {
          window.saeApi.toast('exito', 'Expediente actualizado');
          this._cargarAlumnosAPI();
        } else {
          window.saeApi.toast('error', res?.message || 'Error al actualizar');
        }
      } catch (e) { window.saeApi.toast('error', 'Error de red'); }
    },

    async cambiarEstadoAlumno(nuevoEstado, motivoExterno) {
      let observacionesExtra = '';
      if (motivoExterno) {
        observacionesExtra = `[${nuevoEstado.toUpperCase()} ${new Date().toLocaleDateString()}]: ${motivoExterno.trim()}`;
      } else if (nuevoEstado === 'Activo' && this.alumnoActualFicha.estado !== 'Activo') {
        const motivo = prompt('Por favor, ingresa el motivo de la reactivación:');
        if (motivo === null) return;
        if (motivo.trim() === '') { window.saeApi.toast('error', 'El motivo de reactivación es obligatorio.'); return; }
        observacionesExtra = `[REACTIVACIÓN ${new Date().toLocaleDateString()}]: ${motivo.trim()}`;
      } else if (nuevoEstado !== 'Activo' && nuevoEstado !== this.alumnoActualFicha.estado) {
        const motivo = prompt(`Por favor, ingresa el motivo para cambiar a ${nuevoEstado}:`);
        if (motivo === null) return;
        if (motivo.trim() === '') { window.saeApi.toast('error', `El motivo para cambiar a ${nuevoEstado} es obligatorio.`); return; }
        observacionesExtra = `[${nuevoEstado.toUpperCase()} ${new Date().toLocaleDateString()}]: ${motivo.trim()}`;
      } else {
        if (!confirm(`¿Estás seguro de cambiar el estado a ${nuevoEstado}?`)) return;
      }
      try {
        const payload = { estado: nuevoEstado };
        if (observacionesExtra) {
          payload.observaciones = (this.alumnoActualFicha.observaciones ? this.alumnoActualFicha.observaciones + '\n' : '') + observacionesExtra;
        }
        const res = await window.saeApi.alumnos.actualizar(this.alumnoActualFicha.id, payload);
        if (res && res.ok) {
          window.saeApi.toast('exito', `Estado actualizado a ${nuevoEstado}`);
          this.alumnoSeleccionado = false;
          this.alumnoActualFicha = null;
          this._cargarAlumnosAPI();
        } else {
          window.saeApi.toast('error', res?.message || 'Error al cambiar estado');
        }
      } catch (e) { window.saeApi.toast('error', 'Error de red'); }
    },

    confirmarBajaDefinitiva() {
      const motivo = prompt('Por favor, ingresa el motivo para la Baja Definitiva:');
      if (motivo === null) return;
      if (motivo.trim() === '') { window.saeApi.toast('error', 'El motivo de la Baja Definitiva es obligatorio.'); return; }
      if (confirm('¿Estás seguro de dar BAJA DEFINITIVA a este alumno? Esta acción cerrará su expediente y lo ocultará de la vista principal.')) {
        this.cambiarEstadoAlumno('Baja Definitiva', motivo);
      }
    },

    async _cargarPagosAlumnoFicha() {
      if (!this.alumnoActualFicha) return;
      try {
        const res = await window.saeApi.pagos.listar({ alumnoId: this.alumnoActualFicha.id });
        const resCal = await window.saeApi.pagos.calendario({ alumnoId: this.alumnoActualFicha.id });
        if (res && res.ok) {
          this.historialPagosAlumno = res.pagination ? res.data : (Array.isArray(res.data) ? res.data : []);
        }
        if (resCal && resCal.ok) {
          this.historialCalendarioAlumno = Array.isArray(resCal.data) ? resCal.data : [];
          this.historialCalendarioAlumno.sort((a, b) => new Date(a.fechaVencimiento) - new Date(b.fechaVencimiento));
        }
        setTimeout(() => { if (window.lucide) window.lucide.createIcons(); }, 150);
      } catch (e) { console.error('Error loading payment history:', e); }
    },

    async _cargarTutoresDelAlumno(id) {
      try {
        const res = await window.saeApi.alumnos.obtener(id);
        if (res && res.ok) { this.tutoresAlumnoFicha = res.data.padresOriginal || []; }
      } catch (e) { console.error(e); }
    },

    async subirComprobanteHistorial(pagoId, event) {
      const file = event.target.files[0];
      if (!file) return;
      try {
        const res = await window.saeApi.pagos.subirComprobante(pagoId, file);
        if (res && res.ok) {
          window.saeApi.toast('exito', 'Comprobante subido correctamente');
          if (this.tabDirectorio === 'tutores') { this._cargarPagosTutor(); }
          else { this._cargarPagosAlumnoFicha(); }
        } else { window.saeApi.toast('error', res?.message || 'Error al subir comprobante'); }
      } catch (e) {
        console.error(e);
        window.saeApi.toast('error', 'Error de red al subir comprobante');
      } finally { event.target.value = ''; }
    },

    openNuevoAlumno() { this.modalNuevoAlumno = true; },

    initNuevoAlumno() {
      this.nuevoAlumnoData = { nombre: '', matricula: '', curp: '', grupoId: null, padre: '', telefono: '', tutorId: null, fechaNacimiento: '', personasAutorizadas: '' };
      this.erroresNuevoAlumno = {};
      this.sugerenciasTutor = [];
    },
    async buscarTutorAutocomplete() {
      if (!this.nuevoAlumnoData.padre || this.nuevoAlumnoData.padre.length < 3) {
        this.sugerenciasTutor = [];
        if (this.nuevoAlumnoData.tutorId) { this.nuevoAlumnoData.tutorId = null; this.nuevoAlumnoData.telefono = ''; }
        return;
      }
      if (this.nuevoAlumnoData.tutorId) return;
      try {
        const res = await window.saeApi.tutores.listar({ q: this.nuevoAlumnoData.padre, limit: 5 });
        if (res && res.ok && Array.isArray(res.data)) { this.sugerenciasTutor = res.data; }
      } catch (e) { console.error(e); }
    },
    seleccionarTutorSugerido(tut) {
      this.nuevoAlumnoData.tutorId = tut.tutorId;
      this.nuevoAlumnoData.padre = tut.nombreCompleto;
      this.nuevoAlumnoData.telefono = tut.telefono || '';
      this.sugerenciasTutor = [];
    },
    async guardarNuevoAlumno() {
      this.erroresNuevoAlumno = {
        nombre: !this.nuevoAlumnoData.nombre,
        matricula: !this.nuevoAlumnoData.matricula,
        grupoId: !this.nuevoAlumnoData.grupoId
      };
      if (Object.values(this.erroresNuevoAlumno).some(v => v)) {
        window.saeApi.toast('advertencia', 'Por favor, completa los campos requeridos marcados en rojo.');
        return;
      }
      const payload = {
        nombre: this.nuevoAlumnoData.nombre,
        matricula: this.nuevoAlumnoData.matricula,
        curp: this.nuevoAlumnoData.curp || undefined,
        fechaNacimiento: this.nuevoAlumnoData.fechaNacimiento || undefined,
        autorizadosRecoger: this.nuevoAlumnoData.personasAutorizadas || undefined,
        grupoId: this.nuevoAlumnoData.grupoId ? Number(this.nuevoAlumnoData.grupoId) : undefined,
        padres: this.nuevoAlumnoData.padre
          ? [{ nombre: this.nuevoAlumnoData.padre, telefono: this.nuevoAlumnoData.telefono || null, esTutor: true, tutorId: this.nuevoAlumnoData.tutorId }]
          : [],
      };
      const res = await window.saeApi.alumnos.crear(payload);
      if (res.ok) {
        this.listaAlumnos.push(window.saeApi.mapAlumno(res.data));
        this.alumnosFiltrados = [...this.listaAlumnos];
        this.modalNuevoAlumno = false;
        window.saeApi.toast('exito', 'Alumno registrado correctamente');
      } else {
        window.saeApi.toast('error', res.message || 'Error al registrar alumno.');
      }
    },

    // ── Planes de Pago ───────────────────────────────────────────────────────
    async previsualizarPlanPago(meses) {
      if (!this.alumnoActualFicha) return;
      this.cargando = true;
      try {
        const res = await window.saeApi.fetchApi(`/alumnos/${this.alumnoActualFicha.id}/planes/preview?meses=${meses}`);
        if (res.ok && res.data) {
          this.previewPlanCalendario = res.data.calendario;
          this.previewPlanMeses = meses;
        } else {
          window.saeApi.toast('error', res.message || 'Error al generar la previsualización');
        }
      } catch (e) {
        console.error(e);
        window.saeApi.toast('error', 'Error al procesar la solicitud.');
      } finally { this.cargando = false; }
    },
    async asignarPlanPagoConfirmar() {
      if (!this.alumnoActualFicha || !this.previewPlanMeses) return;
      this.cargando = true;
      try {
        const res = await window.saeApi.fetchApi(`/alumnos/${this.alumnoActualFicha.id}/planes`, {
          method: 'POST',
          body: JSON.stringify({ meses: this.previewPlanMeses })
        });
        if (res.ok) {
          window.saeApi.toast('exito', `Plan de ${this.previewPlanMeses} meses asignado correctamente.`);
          this.previewPlanCalendario = [];
          this.previewPlanMeses = null;
          this.seleccionarAlumnoFicha({ id: this.alumnoActualFicha.id });
        } else {
          window.saeApi.toast('error', res.message || 'Error al asignar el plan.');
        }
      } catch (e) {
        console.error(e);
        window.saeApi.toast('error', 'Error al asignar el plan.');
      } finally { this.cargando = false; }
    },

    // ── Cierre de ciclo ──────────────────────────────────────────────────────
    async ejecutarCierreCiclo() {
      if (!confirm('¿ESTÁS ABSOLUTAMENTE SEGURO de ejecutar el Cierre de Ciclo Escolar?\n\nEsta operación promoverá a los alumnos, egresará a quienes terminen su nivel, y retendrá a los deudores.')) return;
      try {
        window.saeApi.toast('info', 'Ejecutando cierre de ciclo... Por favor espera.');
        const res = await window.saeApi.fetchApi('/alumnos/cierre-ciclo', { method: 'POST' });
        if (res && res.ok) {
          const result = res.data;
          alert(`Cierre de ciclo completado con éxito:\n\n- Ciclo Cerrado: ${result.cicloCerrado}\n- Promovidos: ${result.promovidos}\n- Egresados: ${result.egresados}\n- Retenidos (Deudores): ${result.retenidos}`);
          window.location.reload();
        } else {
          window.saeApi.toast('error', res?.message || 'Error al ejecutar cierre de ciclo');
        }
      } catch (e) {
        console.error(e);
        window.saeApi.toast('error', 'Error de red o timeout');
      }
    },
  };
}
