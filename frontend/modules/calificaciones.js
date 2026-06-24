/**
 * modules/calificaciones.js
 * Calificaciones mixin: curriculares, extracurriculares, taller, exportar boleta PDF
 */
function calificacionesMixin() {
  return {
    // ── Estado ───────────────────────────────────────────────────────────────
    busquedaCalif: '',
    periodoCalif: 'Trimestre 1',
    filtroCalifNivel: '',
    filtroCalifGrado: '',
    filtroCalifGrupo: '',
    alumnoSeleccionadoCalif: false,
    alumnoActualCalif: null,
    materiasAlumno: [],
    esPreescolar: false,
    clubesAlumno: [],
    historialExtraAlumno: [],
    tipoEvaluacionCalif: 'curricular',
    tallerAlumno: { nombre: 'Taller', T1: { v: '', orig: null, califId: null }, T2: { v: '', orig: null, califId: null }, T3: { v: '', orig: null, califId: null } },
    promedioGeneralCalif: null,

    // ── Búsqueda de alumno ───────────────────────────────────────────────────
    async buscarAlumnoCalif() {
      const q = this.busquedaCalif.toLowerCase();
      const nivel = this.filtroCalifNivel;
      const grado = this.filtroCalifGrado;
      const grupo = this.filtroCalifGrupo;
      const params = {};
      if (q) params.q = q;
      if (nivel) params.nivel = nivel.toUpperCase();
      if (grado) params.grado = grado;
      if (grupo) params.seccion = grupo;
      const res = await window.saeApi.alumnos.listar(params);
      if (res.ok) {
        const data = res.pagination ? res.data : (Array.isArray(res.data) ? res.data : []);
        this.alumnosCoincidencias = data.map(window.saeApi.mapAlumno);
      } else { this.alumnosCoincidencias = []; }
    },

    async seleccionarAlumnoCalif(al) {
      this.alumnoActualCalif = al;
      this.alumnoSeleccionadoCalif = true;
      this.materiasAlumno = []; this.esPreescolar = false;
      this.clubesAlumno = [];
      if (al.materiasExtra && al.materiasExtra.length > 0) {
        al.materiasExtra.filter(m => m.tipo === 'club').forEach(m => {
          this.clubesAlumno.push({ id: m.materia, nombre: m.materia, T1: { v: '', orig: null, califId: null }, T2: { v: '', orig: null, califId: null }, T3: { v: '', orig: null, califId: null }, prom: '-' });
        });
      }
      this.tallerAlumno = { nombre: 'Taller', T1: { v: '', orig: null, califId: null }, T2: { v: '', orig: null, califId: null }, T3: { v: '', orig: null, califId: null } };
      const tieneTaller = al.materiasExtra && al.materiasExtra.find(m => m.tipo === 'taller');
      if (tieneTaller) { this.tallerAlumno.nombre = tieneTaller.materia; }
      this.busquedaCalif = '';
      this.cargarHistorialExtra();
      this.cargarHistorialTaller();
      if (al.grupoId) {
        const grupoRes = await window.saeApi.grupos.obtener(al.grupoId);
        if (grupoRes.ok && grupoRes.data && grupoRes.data.materias) {
          this.esPreescolar = (grupoRes.data.nivel === 'PREESCOLAR' || (al.nivel && al.nivel.toUpperCase() === 'PREESCOLAR'));
          grupoRes.data.materias
            .filter(m => m.tipo === 'curricular' || !m.tipo)
            .forEach(m => {
              this.materiasAlumno.push({ id: m.id, nombre: m.materia, tipo: m.tipo || 'curricular', T1: { v: '', t: '', califId: null }, T2: { v: '', t: '', califId: null }, T3: { v: '', t: '', califId: null }, prom: null });
            });
        }
        const calRes = await window.saeApi.calificaciones.porAlumno(al.id, undefined);
        if (calRes.ok && calRes.data) {
          calRes.data.forEach(c => {
            const mat = this.materiasAlumno.find(m => m.id === c.grupoMateriaId);
            if (mat) {
              const k = String(c.periodo).includes('1') ? 'T1' : String(c.periodo).includes('2') ? 'T2' : 'T3';
              mat[k].v = (c.valor !== null && c.valor !== undefined) ? c.valor : '';
              mat[k].t = c.textoObservacion || '';
            }
          });
        }
        this.recalcularPromediosCalif();
      }
    },

    recalcularPromediosCalif() {
      let sumGral = 0; let countGral = 0;
      this.materiasAlumno.forEach(mat => {
        if (this.esPreescolar) { mat.prom = 'N/A'; }
        else {
          let s = 0, c = 0;
          ['T1', 'T2', 'T3'].forEach(t => {
            if (mat[t].v !== '') {
              let v = parseFloat(mat[t].v);
              if (v > 10) { mat[t].v = 10; v = 10; }
              if (v < 0) { mat[t].v = 0; v = 0; }
              s += v; c++;
            }
          });
          if (c > 0) { mat.prom = (s / c).toFixed(1); sumGral += parseFloat(mat.prom); countGral++; }
          else { mat.prom = '-'; }
        }
      });
      this.promedioGeneralCalif = this.esPreescolar ? 'N/A' : (countGral > 0 ? (sumGral / countGral).toFixed(1) : '-');
    },

    async guardarCalificacion() {
      if (!this.alumnoActualCalif || !this.alumnoActualCalif.id) { window.saeApi.toast('error', 'No hay alumno seleccionado.'); return; }
      const periodosArr = ['TRIMESTRE_1', 'TRIMESTRE_2', 'TRIMESTRE_3'];
      const lote = [];
      for (const mat of this.materiasAlumno) {
        if (this.esPreescolar) {
          ['T1', 'T2', 'T3'].forEach((t, i) => {
            const obs = (mat[t].t || '').trim();
            if (obs) { lote.push({ alumnoId: this.alumnoActualCalif.id, grupoMateriaId: mat.id, periodo: periodosArr[i], valor: null, textoObservacion: obs, tipoEvaluacion: 'observacion' }); }
          });
        } else {
          ['T1', 'T2', 'T3'].forEach((t, i) => {
            const val = parseFloat(mat[t].v);
            if (!isNaN(val) && val >= 0 && val <= 10) {
              lote.push({ alumnoId: this.alumnoActualCalif.id, grupoMateriaId: mat.id, periodo: periodosArr[i], valor: val, tipoEvaluacion: 'numerica' });
            }
          });
        }
      }
      if (lote.length === 0) { window.saeApi.toast('advertencia', 'No hay calificaciones válidas para guardar. Verifica que el alumno tenga grupo y materias asignadas.'); return; }
      const res = await window.saeApi.calificaciones.guardarLote(lote);
      if (res.ok) { window.saeApi.toast('exito', `${lote.length} calificación(es) guardada(s) para ${this.alumnoActualCalif.nombre}.`); }
      else { window.saeApi.toast('error', res.message || 'Error al guardar calificaciones.'); }
    },

    // ── Extracurriculares ─────────────────────────────────────────────────────
    async cargarHistorialExtra() {
      if (!this.alumnoActualCalif) return;
      try {
        const res = await window.saeApi.calificacionesExtra.porAlumno(this.alumnoActualCalif.id);
        if (res && res.data) {
          this.historialExtraAlumno = res.data;
          this.clubesAlumno.forEach(club => {
            club.T1 = { v: '', orig: null, califId: null };
            club.T2 = { v: '', orig: null, califId: null };
            club.T3 = { v: '', orig: null, califId: null };
            club.prom = '-';
          });
          res.data.forEach(c => {
            const club = this.clubesAlumno.find(x => x.id === c.club);
            if (club) {
              const num = c.periodo?.numero;
              let key = null;
              if (num === 1) key = 'T1'; if (num === 2) key = 'T2'; if (num === 3) key = 'T3';
              if (key) { club[key].v = c.valorNumerico; club[key].orig = c.valorNumerico; club[key].califId = c.calificacionExtracurricularId; }
            }
          });
          this.recalcularPromediosExtra();
        }
      } catch (e) { console.error(e); }
    },
    recalcularPromediosExtra() {
      this.clubesAlumno.forEach(club => {
        let s = 0, c = 0;
        ['T1', 'T2', 'T3'].forEach(t => {
          if (club[t].v !== '') {
            let v = parseFloat(club[t].v);
            if (v > 10) { club[t].v = 10; v = 10; }
            if (v < 0) { club[t].v = 0; v = 0; }
            s += v; c++;
          }
        });
        if (c > 0) { club.prom = (s / c).toFixed(1); } else { club.prom = '-'; }
      });
    },
    async guardarCalificacionExtraLote() {
      if (!this.alumnoActualCalif) return;
      const promesas = [];
      for (const club of this.clubesAlumno) {
        ['T1', 'T2', 'T3'].forEach((t, i) => {
          const valStr = club[t].v;
          if (valStr !== '') {
            const val = parseFloat(valStr);
            if (!isNaN(val) && val >= 0 && val <= 10) {
              if (club[t].califId) {
                if (val !== club[t].orig) { promesas.push(window.saeApi.calificacionesExtra.modificar(club[t].califId, { valorNumerico: val, motivo: 'Actualización en lote desde panel' })); }
              } else {
                promesas.push(window.saeApi.calificacionesExtra.registrar({ alumnoId: this.alumnoActualCalif.id, club: club.id, numeroTrimestre: i + 1, valorNumerico: val }));
              }
            }
          }
        });
      }
      if (promesas.length === 0) { window.saeApi.toast('advertencia', 'No hay calificaciones para guardar o no se detectaron cambios.'); return; }
      try {
        const resultados = await Promise.all(promesas);
        const errores = resultados.filter(r => r && (!r.success && !r.ok));
        if (errores.length > 0) { window.saeApi.toast('error', errores[0].message || 'Error al guardar algunas calificaciones.'); }
        else { window.saeApi.toast('exito', 'Calificaciones de clubes guardadas correctamente.'); }
        await this.cargarHistorialExtra();
      } catch (e) { window.saeApi.toast('error', 'Hubo un error de conexión al guardar calificaciones.'); await this.cargarHistorialExtra(); }
    },
    async abrirModalModificarExtra(c) {
      const nuevaCalif = prompt(`Modificar calificación para ${c.club}\nValor actual: ${c.valorNumerico}\nIngrese nueva calificación (0-10):`, c.valorNumerico);
      if (nuevaCalif === null) return;
      const valor = parseFloat(nuevaCalif);
      if (isNaN(valor) || valor < 0 || valor > 10) { window.saeApi.toast('advertencia', 'Calificación inválida.'); return; }
      const motivo = prompt('Motivo de la modificación:');
      if (!motivo || motivo.trim() === '') { window.saeApi.toast('advertencia', 'Debe proporcionar un motivo.'); return; }
      try {
        const res = await window.saeApi.calificacionesExtra.modificar(c.calificacionExtracurricularId, { valorNumerico: valor, motivo: motivo.trim() });
        if (res.ok || res.success) { window.saeApi.toast('exito', 'Calificación modificada correctamente.'); await this.cargarHistorialExtra(); }
        else { window.saeApi.toast('error', res.message || 'Error al modificar.'); }
      } catch (e) { window.saeApi.toast('error', e.message || 'Error al modificar.'); }
    },

    // ── Taller ────────────────────────────────────────────────────────────────
    async cargarHistorialTaller() {
      if (!this.alumnoActualCalif) return;
      try {
        const res = await window.saeApi.calificacionesTaller.porAlumno(this.alumnoActualCalif.id);
        if (res && res.data) {
          const currentNombre = this.tallerAlumno.nombre || 'Taller';
          this.tallerAlumno = { nombre: currentNombre, T1: { v: '', orig: null, califId: null }, T2: { v: '', orig: null, califId: null }, T3: { v: '', orig: null, califId: null } };
          res.data.forEach(c => {
            const num = c.periodo?.numero;
            let key = null;
            if (num === 1) key = 'T1'; if (num === 2) key = 'T2'; if (num === 3) key = 'T3';
            if (key) { this.tallerAlumno[key].v = c.valorCualitativo || ''; this.tallerAlumno[key].orig = c.valorCualitativo || ''; this.tallerAlumno[key].califId = c.calificacionTallerId; }
          });
        }
      } catch (e) { console.error(e); }
    },
    async guardarCalificacionTallerLote() {
      if (!this.alumnoActualCalif) return;
      const promesas = [];
      ['T1', 'T2', 'T3'].forEach((t, i) => {
        const valStr = this.tallerAlumno[t].v;
        if (valStr !== '') {
          if (this.tallerAlumno[t].califId) {
            if (valStr !== this.tallerAlumno[t].orig) { promesas.push(window.saeApi.calificacionesTaller.modificar(this.tallerAlumno[t].califId, { valorCualitativo: valStr, motivo: 'Actualización en lote desde panel' })); }
          } else { promesas.push(window.saeApi.calificacionesTaller.registrar({ alumnoId: this.alumnoActualCalif.id, numeroTrimestre: i + 1, valorCualitativo: valStr })); }
        }
      });
      if (promesas.length === 0) { window.saeApi.toast('advertencia', 'No hay calificaciones de Taller para guardar o no se detectaron cambios.'); return; }
      try {
        const resultados = await Promise.all(promesas);
        const errores = resultados.filter(r => r && (!r.success && !r.ok));
        if (errores.length > 0) { window.saeApi.toast('error', errores[0].message || 'Error al guardar calificaciones de Taller.'); }
        else { window.saeApi.toast('exito', 'Calificaciones de Taller guardadas correctamente.'); }
        await this.cargarHistorialTaller();
      } catch (e) { window.saeApi.toast('error', 'Hubo un error de conexión al guardar calificaciones de Taller.'); await this.cargarHistorialTaller(); }
    },
    calcularEvaluacionTaller() {
      const t = this.tallerAlumno;
      if (!t) return '-';
      const vals = [t?.T1?.v, t?.T2?.v, t?.T3?.v].filter(x => x === 'A' || x === 'NA');
      if (vals.length === 0) return '-';
      const countA = vals.filter(x => x === 'A').length;
      const countNA = vals.filter(x => x === 'NA').length;
      return countA >= countNA ? 'A' : 'NA';
    },
  };
}
