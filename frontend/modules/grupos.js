/**
 * modules/grupos.js
 * Grupos mixin: CRUD grupos, CRUD materias, asignación alumnos, filtros, autocomplete docente
 */
function gruposMixin() {
  return {
    // ── Estado ───────────────────────────────────────────────────────────────
    gruposData: [],
    grupoExpandido: null,
    tabGruposMaterias: 'grupos',
    filtroGruposNivel: '',
    filtroGruposGrado: '',
    filtroGruposGrupo: '',
    filtroMateriasTipo: '',
    filtroGruposDocente: '',
    todosLosGruposClonacion: [],
    
    // ── Promocion ────────────────────────────────────────────────────────────
    modalPromover: false,
    grupoOrigenPromocion: null,
    promocionDestinoId: '',
    alumnosPromocionList: [],
    alumnosSeleccionadosPromocion: [],
    seleccionarTodosPromocion: true,
    gruposDestinoDisponibles: [],

    // ── Modal Grupo ──────────────────────────────────────────────────────────
    modalGrupo: false,
    grupoEditando: false,
    grupoTemp: { id: null, nivel: '', grado: '', seccion: '', titular: '', materias: [], clonarDesdeGrupoId: '' },
    busquedaTitularModal: '',
    resultadosTitularModal: [],
    mostrarDropdownTitularModal: false,

    // ── Modal Materia ────────────────────────────────────────────────────────
    modalMateria: false,
    materiaEditandoIndex: null,
    materiaEditandoGrupoId: null,
    diasSemana: ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab'],
    nuevaMateria: { nombre: '', docente: '', horario: '', aula: '', grado: '', grupo: '', nivel: '', dias: [], horaInicio: '', horaFin: '', tipo: 'curricular' },
    busquedaDocenteMateria: '',
    resultadosDocenteMateria: [],
    mostrarDropdownDocenteMateria: false,

    // ── Filtro docente ───────────────────────────────────────────────────────
    busquedaDocenteFiltro: '',
    resultadosDocenteFiltro: [],
    mostrarDropdownDocenteFiltro: false,

    // ── Modal asignación alumnos ─────────────────────────────────────────────
    modalAsignarAlumnos: false,
    materiaActualAsignacion: null,
    alumnosAsignacionDisponibles: [],
    alumnosAsignacionSeleccionados: [],
    busquedaAsignacion: '',

    // ── Computed ─────────────────────────────────────────────────────────────
    get gradosDisponiblesFiltroGrupos() {
      if (!this.filtroGruposNivel) return [];
      const nivel = this.filtroGruposNivel.toUpperCase();
      if (nivel === 'PREESCOLAR') return ['1', '2', '3'];
      return ['1', '2', '3', '4', '5', '6'];
    },
    get seccionesDisponiblesFiltroGrupos() {
      if (!this.filtroGruposNivel || !this.filtroGruposGrado) return [];
      return ['A', 'B', 'C', 'D', 'E', 'F'];
    },

    // ── API ──────────────────────────────────────────────────────────────────
    async _cargarGruposAPI() {
      const res = await window.saeApi.grupos.listar();
      if (res.ok && res.data) {
        this.gruposData = res.data.map(window.saeApi.mapGrupo);
        this.$nextTick(() => { if (window.lucide) window.lucide.createIcons(); });
      } else if (!res.offline) {
        window.saeApi.toast('error', res.message || 'Error al cargar grupos.');
      }
    },

    // ── Filtros ───────────────────────────────────────────────────────────────
    gruposFiltradosList() {
      return this.gruposData.filter(g => {
        const mNivel = !this.filtroGruposNivel || g.nivel.toLowerCase() === this.filtroGruposNivel.toLowerCase();
        const mGrado = !this.filtroGruposGrado || g.grado.toString() === this.filtroGruposGrado.toString();
        const mGrupo = !this.filtroGruposGrupo || g.seccion.toLowerCase() === this.filtroGruposGrupo.toLowerCase();
        const qDocente = this.filtroGruposDocente.toLowerCase();
        const mDocente = !qDocente || (g.titular && g.titular.toLowerCase().includes(qDocente));
        return mNivel && mGrado && mGrupo && mDocente;
      });
    },
    materiasFiltradasList() {
      const list = [];
      const qDocente = this.filtroGruposDocente.toLowerCase();
      this.gruposData.forEach(g => {
        const mNivel = !this.filtroGruposNivel || g.nivel.toLowerCase() === this.filtroGruposNivel.toLowerCase();
        const mGrado = !this.filtroGruposGrado || g.grado.toString() === this.filtroGruposGrado.toString();
        const mGrupo = !this.filtroGruposGrupo || g.seccion.toLowerCase() === this.filtroGruposGrupo.toLowerCase();
        if (mNivel && mGrado && mGrupo && g.materias) {
          g.materias.forEach((m, index) => {
            const matTipo = m.tipo || 'curricular';
            if (!this.filtroMateriasTipo || matTipo === this.filtroMateriasTipo) {
              if (qDocente) { if (!m.docente || !m.docente.toLowerCase().includes(qDocente)) return; }
              list.push({ ...m, grupoId: g.id, nivel: g.nivel, grado: g.grado, seccion: g.seccion, originalIndex: index });
            }
          });
        }
      });
      return list;
    },
    gradosDisponiblesPorNivel(nivelSelect) {
      const n = (nivelSelect || '').toUpperCase();
      if (n === 'PREESCOLAR') return ['1', '2', '3'];
      return ['1', '2', '3', '4', '5', '6'];
    },
    seccionesDisponiblesPorNivelYGrado(nivelStr, gradoStr) {
      if (!nivelStr || !gradoStr) return [];
      const n = nivelStr.toUpperCase();
      return [...new Set(this.gruposData.filter(g => g.nivel && g.nivel.toUpperCase() === n && String(g.grado) === String(gradoStr)).map(g => g.seccion))].filter(Boolean);
    },

    // ── Autocomplete docente ──────────────────────────────────────────────────
    async buscarDocenteAutocomplete(query) {
      if (!query || query.trim().length < 2) return [];
      const res = await window.saeApi.usuarios.listar({ rol: 'MAESTRA' });
      if (res.ok) {
        return res.data.filter(u => u.nombre.toLowerCase().includes(query.trim().toLowerCase()));
      }
      return [];
    },
    async buscarDocenteFiltroInput() {
      if (this.busquedaDocenteFiltro.length < 2) {
        this.resultadosDocenteFiltro = [];
        this.filtroGruposDocente = this.busquedaDocenteFiltro;
        return;
      }
      this.resultadosDocenteFiltro = await this.buscarDocenteAutocomplete(this.busquedaDocenteFiltro);
      this.mostrarDropdownDocenteFiltro = true;
      this.filtroGruposDocente = this.busquedaDocenteFiltro;
    },
    seleccionarDocenteFiltro(docente) {
      this.busquedaDocenteFiltro = docente.nombre;
      this.filtroGruposDocente = docente.nombre;
      this.mostrarDropdownDocenteFiltro = false;
    },
    async buscarDocenteMateriaInput() {
      if (this.busquedaDocenteMateria.length < 2) { this.resultadosDocenteMateria = []; return; }
      this.resultadosDocenteMateria = await this.buscarDocenteAutocomplete(this.busquedaDocenteMateria);
      this.mostrarDropdownDocenteMateria = true;
    },
    async buscarTitularModalInput() {
      if (this.busquedaTitularModal.length < 2) { this.resultadosTitularModal = []; return; }
      this.resultadosTitularModal = await this.buscarDocenteAutocomplete(this.busquedaTitularModal);
      this.mostrarDropdownTitularModal = true;
    },

    // ── Grupos CRUD ──────────────────────────────────────────────────────────
    async abrirModalNuevoGrupo() {
      this.grupoEditando = false;
      this.grupoTemp = { id: null, nivel: '', grado: '', seccion: '', titular: '', materias: [], clonarDesdeGrupoId: '' };
      this.busquedaTitularModal = ''; this.resultadosTitularModal = [];
      
      // Cargar grupos para clonar (todos los ciclos)
      const res = await window.saeApi.grupos.listar({ todos: true });
      if (res.ok && res.data) {
        this.todosLosGruposClonacion = res.data;
      }
      
      this.modalGrupo = true;
      this.$nextTick(() => { if (window.lucide) window.lucide.createIcons(); });
    },
    abrirModalEditarGrupo(g) {
      this.grupoEditando = true;
      this.grupoTemp = {
        id: g.id,
        nivel: g.nivel ? g.nivel.charAt(0).toUpperCase() + g.nivel.slice(1).toLowerCase() : '',
        grado: g.grado || '', seccion: g.seccion || '', titular: g.titular || '',
        materias: g.materias ? JSON.parse(JSON.stringify(g.materias)) : []
      };
      this.busquedaTitularModal = g.titular || ''; this.resultadosTitularModal = [];
      this.modalGrupo = true;
      this.$nextTick(() => { if (window.lucide) window.lucide.createIcons(); });
    },
    agregarMateriaGrupo() {
      this.grupoTemp.materias.push({ materia: '', docente: '', horario: '', aula: '' });
      this.$nextTick(() => { if (window.lucide) window.lucide.createIcons(); });
    },
    eliminarMateriaGrupo(idx) { this.grupoTemp.materias.splice(idx, 1); },
    async guardarGrupoCRUD() {
      if (!this.grupoTemp.nivel || !this.grupoTemp.grado || !this.grupoTemp.seccion) {
        return window.saeApi.toast('advertencia', 'Nivel, Grado y Sección son obligatorios');
      }
      const payload = {
        nombre: `${this.grupoTemp.grado}°${this.grupoTemp.seccion} ${this.grupoTemp.nivel}`,
        nivel: this.grupoTemp.nivel.toUpperCase(), grado: this.grupoTemp.grado,
        seccion: this.grupoTemp.seccion, titular: this.grupoTemp.titular,
        materias: this.grupoTemp.materias.map(m => ({ nombre: m.nombre || m.materia, docente: m.docente, horario: m.horario, aula: m.aula })).filter(m => m.nombre && m.nombre.trim() !== '')
      };
      let res;
      if (this.grupoEditando) { res = await window.saeApi.grupos.actualizar(this.grupoTemp.id, payload); }
      else { res = await window.saeApi.grupos.crear(payload); }
      if (res.ok) { window.saeApi.toast('exito', `Grupo ${this.grupoEditando ? 'actualizado' : 'creado'} correctamente`); this.modalGrupo = false; this._cargarGruposAPI(); }
      else { window.saeApi.toast('error', res.message || 'Error al guardar grupo'); }
    },
    async eliminarGrupoCRUD(id) {
      if (!confirm('¿Estás seguro de eliminar este grupo? Esta acción lo ocultará del sistema.')) return;
      const res = await window.saeApi.grupos.eliminar(id);
      if (res.ok) { window.saeApi.toast('exito', 'Grupo eliminado'); this._cargarGruposAPI(); }
      else { window.saeApi.toast('error', res.message || 'Error al eliminar grupo'); }
    },
    
    // ── Clonación y Promoción ───────────────────────────────────────────────
    async cargarMateriasParaClonar() {
      const gId = this.grupoTemp.clonarDesdeGrupoId;
      if (!gId) return;
      const grupo = this.todosLosGruposClonacion.find(g => g.id == gId);
      if (!grupo) return;
      
      const res = await window.saeApi.grupos.obtener(gId);
      if (res.ok && res.data) {
        this.grupoTemp.materias = res.data.materias.map(m => ({
          nombre: m.materia || m.nombre,
          docente: '', // Limpiar docente
          horario: m.horario, // O limpiar horario también? Dejémoslo.
          aula: m.aula
        }));
        window.saeApi.toast('exito', `Se cargaron ${this.grupoTemp.materias.length} materias plantilla.`);
      }
    },
    
    async abrirModalPromover(grupo) {
      this.grupoOrigenPromocion = grupo;
      this.promocionDestinoId = '';
      this.alumnosSeleccionadosPromocion = [];
      
      // Obtener alumnos del grupo origen
      const token = localStorage.getItem('sae_token');
      const resAlumnos = await fetch(`/api/v1/alumnos?grupoId=${grupo.id}&limit=1000`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const dataAlumnos = await resAlumnos.json();
      if (dataAlumnos.ok) {
        this.alumnosPromocionList = dataAlumnos.data;
        this.alumnosSeleccionadosPromocion = this.alumnosPromocionList.map(a => a.id);
        this.seleccionarTodosPromocion = true;
      }
      
      // Obtener grupos destino (del ciclo activo)
      const resGrupos = await window.saeApi.grupos.listar({});
      if (resGrupos.ok) {
        this.gruposDestinoDisponibles = resGrupos.data.filter(g => g.id !== grupo.id);
      }
      
      this.modalPromover = true;
    },
    
    toggleTodosPromocion() {
      if (this.seleccionarTodosPromocion) {
        this.alumnosSeleccionadosPromocion = this.alumnosPromocionList.map(a => a.id);
      } else {
        this.alumnosSeleccionadosPromocion = [];
      }
    },
    
    async ejecutarPromocion() {
      if (!this.promocionDestinoId) {
        return window.saeApi.toast('advertencia', 'Debes seleccionar un grupo destino.');
      }
      if (this.alumnosSeleccionadosPromocion.length === 0) {
        return window.saeApi.toast('advertencia', 'Debes seleccionar al menos un alumno.');
      }
      
      const token = localStorage.getItem('sae_token');
      try {
        const res = await fetch(`/api/v1/grupos/${this.grupoOrigenPromocion.id}/promover`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
          body: JSON.stringify({
            destinoGrupoId: this.promocionDestinoId,
            alumnosIds: this.alumnosSeleccionadosPromocion
          })
        });
        const data = await res.json();
        
        if (res.ok && data.success) {
          window.saeApi.toast('exito', data.message || 'Alumnos promovidos correctamente.');
          this.modalPromover = false;
          this._cargarGruposAPI();
        } else {
          window.saeApi.toast('error', data.message || 'Error al promover alumnos.');
        }
      } catch (err) {
        console.error(err);
        window.saeApi.toast('error', 'Ocurrió un error en la solicitud.');
      }
    },
    async vincularTitularGrupo(grupo, queryInput) {
      let nombreDocente = null;
      if (queryInput && queryInput.trim() !== '') {
        const docentes = await this.buscarDocenteAutocomplete(queryInput);
        const existe = docentes.find(d => d.nombre.toLowerCase() === queryInput.trim().toLowerCase());
        if (!existe) { return window.saeApi.toast('error', 'El usuario ingresado no existe o no es Docente.'); }
        nombreDocente = existe.nombre;
      }
      const res = await window.saeApi.grupos.actualizar(grupo.id, { titular: nombreDocente });
      if (res.ok) { grupo.titular = nombreDocente || ''; window.saeApi.toast('exito', nombreDocente ? 'Docente vinculado correctamente al grupo.' : 'Docente removido correctamente.'); this._cargarGruposAPI(); }
      else { window.saeApi.toast('error', res.message || 'Error al actualizar titular'); }
    },

    // ── Materias CRUD ────────────────────────────────────────────────────────
    abrirModalNuevaMateria() {
      this.materiaEditandoIndex = null; this.materiaEditandoGrupoId = null;
      this.nuevaMateria = { nombre: '', docente: '', horario: '', aula: '', grado: '', grupo: '', nivel: '', dias: [], horaInicio: '', horaFin: '', tipo: 'curricular' };
      this.busquedaDocenteMateria = ''; this.resultadosDocenteMateria = [];
      this.modalMateria = true;
      this.$nextTick(() => { if (window.lucide) window.lucide.createIcons(); });
    },
    abrirModalEditarMateria(materia) {
      this.materiaEditandoIndex = materia.originalIndex;
      this.materiaEditandoGrupoId = materia.grupoId;
      let diasParsed = [], hInicio = '', hFin = '';
      if (materia.horario) {
        const parts = materia.horario.split(' ');
        const horas = parts[parts.length - 1];
        if (horas && horas.includes('-')) { hInicio = horas.split('-')[0]; hFin = horas.split('-')[1]; }
        diasParsed = this.diasSemana.filter(d => materia.horario.includes(d));
      }
      this.nuevaMateria = { nombre: materia.materia || materia.nombre, docente: materia.docente, horario: materia.horario, aula: materia.aula, grado: materia.grado.toString(), grupo: materia.seccion, nivel: materia.nivel, dias: diasParsed, horaInicio: hInicio, horaFin: hFin, tipo: materia.tipo || 'curricular' };
      this.busquedaDocenteMateria = materia.docente || '';
      this.resultadosDocenteMateria = [];
      this.modalMateria = true;
      this.$nextTick(() => { if (window.lucide) window.lucide.createIcons(); });
    },
    toggleDiaMateria(dia) {
      if (this.nuevaMateria.dias.includes(dia)) { this.nuevaMateria.dias = this.nuevaMateria.dias.filter(d => d !== dia); }
      else { this.nuevaMateria.dias.push(dia); }
    },
    async guardarMateriaModal() {
      const { nombre, docente, aula, grado, grupo, nivel, dias, horaInicio, horaFin, tipo } = this.nuevaMateria;
      const esCurricular = tipo === 'curricular';
      if (!nombre || !docente || !grado || !nivel) return window.saeApi.toast('advertencia', 'Nombre, Docente, Nivel y Grado son obligatorios.');
      if (esCurricular && !grupo) return window.saeApi.toast('advertencia', 'La Sección es obligatoria para materias curriculares.');
      const docentes = await this.buscarDocenteAutocomplete(docente);
      const existe = docentes.find(d => d.nombre.toLowerCase() === docente.trim().toLowerCase());
      if (!existe) { return window.saeApi.toast('error', 'El docente ingresado no existe o no tiene el rol correcto (Docente).'); }
      let horarioString = '';
      if (dias.length > 0 && horaInicio && horaFin) { horarioString = `${dias.join(', ')} ${horaInicio}-${horaFin}`; }
      let grupoTarget;
      if (esCurricular) {
        grupoTarget = this.gruposData.find(g => g.grado.toString() === grado.toString() && g.seccion.toLowerCase() === grupo.toLowerCase() && g.nivel.toLowerCase() === nivel.toLowerCase());
      } else {
        grupoTarget = this.gruposData.find(g => g.grado.toString() === grado.toString() && g.nivel.toLowerCase() === nivel.toLowerCase());
      }
      if (!grupoTarget) return window.saeApi.toast('error', 'No se encontró un grupo en el sistema con ese Nivel, Grado y/o Sección.');
      const materiaObjeto = { nombre, docente: existe.nombre, horario: horarioString || this.nuevaMateria.horario, aula, tipo: tipo || 'curricular' };
      if (this.materiaEditandoIndex !== null) {
        if (this.materiaEditandoGrupoId === grupoTarget.id) {
          const materiasActuales = grupoTarget.materias.map(m => ({ nombre: m.materia || m.nombre, docente: m.docente, horario: m.horario, aula: m.aula, tipo: m.tipo || 'curricular' }));
          materiasActuales[this.materiaEditandoIndex] = materiaObjeto;
          const res = await window.saeApi.grupos.actualizar(grupoTarget.id, { materias: materiasActuales });
          if (!res.ok) return window.saeApi.toast('error', res.message || 'Error al actualizar materia.');
        } else {
          const grupoViejo = this.gruposData.find(g => g.id === this.materiaEditandoGrupoId);
          if (grupoViejo) {
            const materiasViejas = grupoViejo.materias.map(m => ({ nombre: m.materia || m.nombre, docente: m.docente, horario: m.horario, aula: m.aula, tipo: m.tipo || 'curricular' })).filter((_, i) => i !== this.materiaEditandoIndex);
            await window.saeApi.grupos.actualizar(grupoViejo.id, { materias: materiasViejas });
          }
          const materiasNuevas = grupoTarget.materias ? grupoTarget.materias.map(m => ({ nombre: m.materia || m.nombre, docente: m.docente, horario: m.horario, aula: m.aula, tipo: m.tipo || 'curricular' })) : [];
          materiasNuevas.push(materiaObjeto);
          const res2 = await window.saeApi.grupos.actualizar(grupoTarget.id, { materias: materiasNuevas });
          if (!res2.ok) return window.saeApi.toast('error', res2.message || 'Error al mover materia.');
        }
      } else {
        const materiasActuales = grupoTarget.materias ? grupoTarget.materias.map(m => ({ nombre: m.materia || m.nombre, docente: m.docente, horario: m.horario, aula: m.aula, tipo: m.tipo || 'curricular' })) : [];
        materiasActuales.push(materiaObjeto);
        const res = await window.saeApi.grupos.actualizar(grupoTarget.id, { materias: materiasActuales });
        if (!res.ok) return window.saeApi.toast('error', res.message || 'Error al guardar materia.');
      }
      window.saeApi.toast('exito', `Materia ${this.materiaEditandoIndex !== null ? 'actualizada' : 'creada y vinculada'} correctamente.`);
      this.modalMateria = false;
      this._cargarGruposAPI();
    },
    async eliminarMateriaCRUD(materia) {
      const confirmar = confirm(`¿Estás seguro de que deseas eliminar la materia ${materia.materia || materia.nombre} asignada al docente ${materia.docente || 'sin asignar'}?`);
      if (!confirmar) return;
      const grupoTarget = this.gruposData.find(g => g.id === materia.grupoId);
      if (!grupoTarget) return window.saeApi.toast('error', 'No se encontró el grupo al que pertenece esta materia.');
      const materiasActuales = grupoTarget.materias.map(m => ({ nombre: m.materia || m.nombre, docente: m.docente, horario: m.horario, aula: m.aula, tipo: m.tipo || 'curricular' })).filter((_, index) => index !== materia.originalIndex);
      const res = await window.saeApi.grupos.actualizar(grupoTarget.id, { materias: materiasActuales });
      if (res.ok) { window.saeApi.toast('exito', 'Materia eliminada correctamente.'); this._cargarGruposAPI(); }
      else { window.saeApi.toast('error', res.message || 'Error al eliminar materia.'); }
    },

    // ── Asignación de alumnos ─────────────────────────────────────────────────
    async abrirModalAsignarAlumnos(materia) {
      this.materiaActualAsignacion = materia;
      this.busquedaAsignacion = ''; this.alumnosAsignacionDisponibles = []; this.alumnosAsignacionSeleccionados = [];
      this.modalAsignarAlumnos = true;
      this.$nextTick(() => { if (window.lucide) window.lucide.createIcons(); });
      const params = { estado: 'Activo', nivel: materia.nivel, grado: materia.grado };
      const resAlumnos = await window.saeApi.alumnos.listar(params);
      if (resAlumnos.ok) {
        const arr = Array.isArray(resAlumnos.data) ? resAlumnos.data : (resAlumnos.data?.data || []);
        this.alumnosAsignacionDisponibles = arr.map(window.saeApi.mapAlumno);
      }
      const resAsignados = await window.saeApi.fetchApi(`/grupos/materias/${materia.id}/alumnos`);
      if (resAsignados.ok && resAsignados.data) {
        this.alumnosAsignacionSeleccionados = resAsignados.data.map(a => Number(a.id || a.alumnoId));
      }
    },
    toggleSeleccionAlumnoAsignacion(id) {
      const numId = Number(id);
      const index = this.alumnosAsignacionSeleccionados.indexOf(numId);
      if (index > -1) { this.alumnosAsignacionSeleccionados.splice(index, 1); }
      else { this.alumnosAsignacionSeleccionados.push(numId); }
    },
    async guardarAsignacionAlumnos() {
      const res = await window.saeApi.fetchApi(`/grupos/materias/${this.materiaActualAsignacion.id}/alumnos`, {
        method: 'PUT', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ alumnosIds: this.alumnosAsignacionSeleccionados })
      });
      if (res.ok) { window.saeApi.toast('exito', 'Alumnos asignados correctamente.'); this.modalAsignarAlumnos = false; }
      else { window.saeApi.toast('error', res.message || 'Error al asignar alumnos.'); }
    },
    alumnosAsignacionFiltrados() {
      const q = this.busquedaAsignacion.toLowerCase();
      return this.alumnosAsignacionDisponibles.filter(a =>
        !q || (a.nombre && a.nombre.toLowerCase().includes(q)) || (a.nombreCompleto && a.nombreCompleto.toLowerCase().includes(q)) || (a.matricula && a.matricula.toLowerCase().includes(q))
      );
    },
  };
}
