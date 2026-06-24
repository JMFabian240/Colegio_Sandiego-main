/**
 * modules/historial.js
 * Historial académico completo mixin (RF-64)
 */
function historialMixin() {
  return {
    // ── Estado ───────────────────────────────────────────────────────────────
    busquedaHistorialQuery: '',
    filtroHistorialNivel: '',
    filtroHistorialGrado: '',
    filtroHistorialGrupo: '',
    resultadosBusquedaHistorial: [],
    alumnoHistorialSeleccionado: null,
    historialAcademicoCompleto: [],

    // ── Filtros ───────────────────────────────────────────────────────────────
    filtrarAlumnosHistorial() {
      let filtrados = this.listaAlumnos;
      const q = this.busquedaHistorialQuery.trim().toLowerCase();
      if (q) {
        filtrados = filtrados.filter(al =>
          al.nombre.toLowerCase().includes(q) ||
          (al.matricula && al.matricula.toLowerCase().includes(q)) ||
          (al.curp && al.curp.toLowerCase().includes(q))
        );
      }
      if (this.filtroHistorialNivel) {
        filtrados = filtrados.filter(a => a.nivel && a.nivel.toUpperCase() === this.filtroHistorialNivel.toUpperCase());
      }
      if (this.filtroHistorialGrado) {
        filtrados = filtrados.filter(a => a.grado == this.filtroHistorialGrado);
      }
      if (this.filtroHistorialGrupo) {
        filtrados = filtrados.filter(a => {
          const gr = typeof a.grupo === 'object' ? a.grupo?.seccion : a.grupoActual;
          return gr && gr.toUpperCase() === this.filtroHistorialGrupo.toUpperCase();
        });
      }
      this.resultadosBusquedaHistorial = filtrados;
    },

    // ── Selección alumno ──────────────────────────────────────────────────────
    async seleccionarAlumnoHistorial(al) {
      this.alumnoHistorialSeleccionado = al;
      this.busquedaHistorialQuery = al.nombre;
      this.resultadosBusquedaHistorial = [];
      this.historialAcademicoCompleto = [];
      try {
        const res = await window.saeApi.fetchApi(`/alumnos/${al.id}/historial-academico`);
        if (res && res.ok && res.data) {
          const historialFormateado = res.data.historial.map(ciclo => {
            const matMap = {};
            if (ciclo.curriculares) {
              ciclo.curriculares.forEach(c => {
                if (!matMap[c.materia]) {
                  matMap[c.materia] = { materia: c.materia, periodo: ciclo.ciclo.nombre, suma: 0, conteo: 0, valorCualitativo: c.valorCualitativo, tipoEvaluacion: c.tipoEvaluacion };
                }
                if (c.tipoEvaluacion === 'numerica' && c.valorNumerico !== null) {
                  matMap[c.materia].suma += parseFloat(c.valorNumerico);
                  matMap[c.materia].conteo += 1;
                }
              });
            }
            const curricularesPromedio = Object.values(matMap).map(m => {
              if (m.tipoEvaluacion === 'numerica') {
                m.promedio = m.conteo > 0 ? (m.suma / m.conteo).toFixed(1) : '-';
              } else { m.promedio = m.valorCualitativo || '-'; }
              return m;
            });
            const talleresSet = {};
            if (ciclo.talleres) {
              ciclo.talleres.forEach(t => { talleresSet[t.taller] = { taller: t.taller, periodo: ciclo.ciclo.nombre, valorCualitativo: t.valorCualitativo }; });
            }
            const extraSet = {};
            if (ciclo.extracurriculares) {
              ciclo.extracurriculares.forEach(ex => { extraSet[ex.club] = { club: ex.club, periodo: ciclo.ciclo.nombre, valorNumerico: ex.valorNumerico }; });
            }
            return { ciclo: ciclo.ciclo, curriculares: curricularesPromedio, talleres: Object.values(talleresSet), extracurriculares: Object.values(extraSet) };
          });
          this.historialAcademicoCompleto = historialFormateado;
        } else if (res && !res.ok) {
          throw new Error(res.message || 'Error desconocido');
        }
      } catch (e) {
        console.error(e);
        window.saeApi.toast('error', `Error: ${e.message}`);
      }
    },
  };
}
