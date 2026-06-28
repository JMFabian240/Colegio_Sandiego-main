
  document.addEventListener('alpine:init', () => {
    Alpine.data('app', () => ({

      // ── Estado de UI ────────────────────────────────────────────────────────
      view: 'dashboard',
      modal: null,
      modalBecaActiva: false,
      modalUsuario: false,
      modalNuevoAlumno: false,
      modalConfirmEliminar: false,
      _usuarioAEliminar: { idx: null, id: null, nombre: '' },
      modalResetPassword: false,
      _resetTarget: { id: null, nombre: '' },
      _resetNuevaPassword: '',
      verInactivos: false,
      cargando: false,

      // ── Rol del usuario ────────────────────────────────────────────────────
      rol: window.saeApi.getUsuario()?.rol || 'MAESTRA',
      permisos: window.saeApi.getUsuario()?.permisos || {},
      esAdmin()       { return this.rol === 'ADMIN' || this.rol === 'Administrador'; },
      esGestor()      { return this.rol === 'GESTOR' || this.rol === 'Gestor'; },
      esMaestra()     { return this.rol === 'MAESTRA' || this.rol === 'Docente'; },
      tieneFinanzas() { return this.esAdmin() || this.esGestor(); },
      tienePermiso(modulo, nivel) {
        if (this.esAdmin()) return true;
        const p = this.permisos[modulo];
        if (!p || p === 'NINGUNO') return false;
        if (nivel === 'lectura') return p === 'lectura' || p === 'escritura';
        if (nivel === 'escritura') return p === 'escritura';
        return false;
      },

      // ── Reportes ──────────────────────────────────────────────────────────────
      reporteActivo: 'corte',
reporteCorte: null,
      reporteIngresos: null,
      cicloSeleccionadoIngresos: '',
      reporteDeudores: null,
      reporteFacturables: null,

      // ── Búsquedas ───────────────────────────────────────────────────────────
      busquedaAlumno: '',
      filtroNivel: '',
      filtroGrado: '',
      filtroSeccion: '',
      busquedaUsuario: '',
      filtroRolUsuario: '',
      busquedaAlumnoBeca: '',
      alumnosBecaFiltrados: [],
      busquedaCalif: '',
      periodoCalif: 'Trimestre 1',

      // ── Calificaciones ──────────────────────────────────────────────────────
      alumnoSeleccionadoCalif: false,
      alumnoActualCalif: null,
      materiasAlumno: [], esPreescolar: false,
      

      // ── Ficha alumno & Directorio ───────────────────────────────────────────
      alumnoSeleccionado: false,
      alumnoActualFicha: null,
      historialPagosAlumno: [],
      historialPagosTutor: [],
      estadoCuentaAlumno: [],
      tabAlumno: 'academicos',
      
      filtroEstadoAlumno: '',
      tabDirectorio: 'alumnos',
      tabAlumnoFicha: 'academicos',
      previewPlanCalendario: [],
      previewPlanMeses: null,
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
      alumnoFichaEditable: {},
      
      modalNuevoTutor: false,
      nuevoTutorData: { nombreCompleto: '', telefono: '', correoElectronico: '', rfc: '', regimenFiscal: '', correoFacturacion: '', requiereFactura: false },
      
      modalVincularTutor: false,
      busquedaVincularTutor: '',
      tutoresParaVincular: [],

      // ── Formularios ─────────────────────────────────────────────────────────
      nuevaBeca:      { alumnoId: null, tipo: 'Beca por hermanos (15%)' },
      nuevoUsuario:   { nombre: '', rol: 'Estándar (Maestra)' },
      nuevoPago:      { 
        alumnoId: null, 
        alumno: '', 
        concepto: 'Colegiatura', 
        monto: '', 
        fecha: new Date().toISOString().split('T')[0],
        becaInfo: null,
        tipoPago: 'normal',
        mesesAdelantar: 1
      },
      pagoAdeudos:    [],
      recargoEditando: null,
      formRecargo: { montoNuevo: '', motivo: '' },
      pagoCalculando: false,
      reciboGenerado: null,
      nuevoAlumnoData:{ nombre: '', matricula: '', curp: '', nivel: '', grado: '', grupoId: null, padre: '', telefono: '', tutorId: null },
      erroresNuevoAlumno: {},
      
      // ── Ciclo Escolar y Tarifas (RF-30) ─────────────────────────────────────
      modalNuevoCiclo: false,
      nuevoCicloData: { nombre: '', activo: true },
      ciclosDisponibles: [],
      nivelesDisponiblesAPI: [],
      configTarifas: {
        cicloId: '',
        nivelId: '',
        cicloActivo: false,
        conceptos: {
          colegiatura: '',
          inscripcion: '',
          aranceles: '',
          material_didactico: ''
        }
      },
      sugerenciasTutor: [],

      // ── Autocomplete pago ───────────────────────────────────────────────────
      busquedaPagoAlumno: '',
      pagoCoincidencias: [],
      mostrarSugerenciasPago: false,

      // ── Bitácora ────────────────────────────────────────────────────────────
      bitacoraLogs: [],
      bitacoraPagina: 1, bitacoraTotal: 0, bitacoraPaginas: 1, limitBitacora: 20,

      // ── Permisos ────────────────────────────────────────────────────────────
      todosModulos: [],
      listaUsuariosPermisos: [],
      usuarioPermisosActivo: null,
      permisosEditando: {},

      // ── Grupos ──────────────────────────────────────────────────────────────
      grupoExpandido: null,
      modalGrupo: false,
      grupoEditando: false,
      grupoTemp: { id: null, nivel: '', grado: '', seccion: '', titular: '', materias: [] },
      abrirModalNuevoGrupo() {
        this.grupoEditando = false;
        this.grupoTemp = { id: null, nivel: '', grado: '', seccion: '', titular: '', materias: [] };
        this.modalGrupo = true;
        this.$nextTick(() => { if (window.lucide) window.lucide.createIcons(); });
      },
      abrirModalEditarGrupo(g) {
        this.grupoEditando = true;
        this.grupoTemp = {
          id: g.id,
          nivel: g.nivel || '',
          grado: g.grado || '',
          seccion: g.seccion || '',
          titular: g.titular || '',
          materias: g.materias ? JSON.parse(JSON.stringify(g.materias)) : []
        };
        this.modalGrupo = true;
        this.$nextTick(() => { if (window.lucide) window.lucide.createIcons(); });
      },
      agregarMateriaGrupo() {
        this.grupoTemp.materias.push({ materia: '', docente: '', horario: '', aula: '' });
        this.$nextTick(() => { if (window.lucide) window.lucide.createIcons(); });
      },
      eliminarMateriaGrupo(idx) {
        this.grupoTemp.materias.splice(idx, 1);
      },
      async guardarGrupoCRUD() {
        if (!this.grupoTemp.nivel || !this.grupoTemp.grado || !this.grupoTemp.seccion) {
          return window.saeApi.toast('advertencia', 'Nivel, Grado y Sección son obligatorios');
        }
        const payload = {
          nombre: `${this.grupoTemp.grado}°${this.grupoTemp.seccion} ${this.grupoTemp.nivel}`,
          nivel: this.grupoTemp.nivel.toUpperCase(),
          grado: this.grupoTemp.grado,
          seccion: this.grupoTemp.seccion,
          titular: this.grupoTemp.titular,
          materias: this.grupoTemp.materias.map(m => ({
             nombre: m.nombre || m.materia,
             docente: m.docente,
             horario: m.horario,
             aula: m.aula
          })).filter(m => m.nombre && m.nombre.trim() !== '')
        };
        
        let res;
        if (this.grupoEditando) {
          res = await window.saeApi.grupos.actualizar(this.grupoTemp.id, payload);
        } else {
          res = await window.saeApi.grupos.crear(payload);
        }
        
        if (res.ok) {
          window.saeApi.toast('exito', `Grupo ${this.grupoEditando ? 'actualizado' : 'creado'} correctamente`);
          this.modalGrupo = false;
          this._cargarGruposAPI();
        } else {
          window.saeApi.toast('error', res.message || 'Error al guardar grupo');
        }
      },
      async eliminarGrupoCRUD(id) {
        if (!confirm('¿Estás seguro de eliminar este grupo? Esta acción lo ocultará del sistema.')) return;
        const res = await window.saeApi.grupos.eliminar(id);
        if (res.ok) {
          window.saeApi.toast('exito', 'Grupo eliminado');
          this._cargarGruposAPI();
        } else {
          window.saeApi.toast('error', res.message || 'Error al eliminar grupo');
        }
      },

      // ── Datos (se cargan desde API) ─────────────────────────────────────────
      pagosRegistrados: [],
      listaUsuarios:    [],
      listaAlumnos:     [],
      alumnosFiltrados: [],
      alumnosCoincidencias: [],
      gruposData:       [],

      // ── Dashboard ────────────────────────────────────────────────────────────
      _dashboardCargado: false,
      dashSummary: { ingresosHoy: 0, alumnos: 0, deudores: 0, becasActivas: 0 },
      dashUltimosPagos: [],

      // ── Paginación alumnos ────────────────────────────────────────────────
      paginaAlumnos: 1, limitAlumnos: 20, totalAlumnos: 0, paginasAlumnos: 1,
      // ── Paginación pagos ──────────────────────────────────────────────────
      paginaPagos: 1, limitPagos: 25, totalPagos: 0, paginasPagos: 1,

      // ── Computed ────────────────────────────────────────────────────────────
      get fechaActual() {
        return new Date().toLocaleDateString('es-MX', {
          weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
        }).replace(/^\w/, c => c.toUpperCase());
      },
      get viewLabel() {
        const labels = {
          dashboard: 'Dashboard', pagos: 'Pagos', deudores: 'Deudores',
          alumnos: 'Alumnos', grupos: 'Grupos & Materias', calificaciones: 'Calificaciones',
          becas: 'Becas', cicloEscolar: 'Ciclo escolar', usuarios: 'Usuarios', reportes: 'Reportes',
          bitacora: 'Bitácora del Sistema', permisos: 'Permisos Granulares'
        };
        return labels[this.view] || this.view;
      },
      get nivelesDisponibles() {
        return ['Preescolar', 'Primaria', 'Secundaria', 'Bachillerato'];
      },
      get gradosDisponiblesFiltro() {
        if (!this.filtroNivel) return [];
        const nivel = this.filtroNivel.toUpperCase();
        if (nivel === 'PREESCOLAR' || nivel === 'SECUNDARIA') return ['1', '2', '3'];
        if (nivel === 'PRIMARIA' || nivel === 'BACHILLERATO') return ['1', '2', '3', '4', '5', '6'];
        return ['1', '2', '3'];
      },
      get seccionesDisponiblesFiltro() {
        if (!this.filtroNivel || !this.filtroGrado) return [];
        const nivel = this.filtroNivel.toUpperCase();
        return [...new Set(this.gruposData.filter(g => g.nivel && g.nivel.toUpperCase() === nivel && g.grado === this.filtroGrado).map(g => g.seccion))].filter(Boolean);
      },
      get gradosDisponiblesNuevo() {
        if (!this.nuevoAlumnoData.nivel) return [];
        const nivel = this.nuevoAlumnoData.nivel.toUpperCase();
        if (nivel === 'PREESCOLAR' || nivel === 'SECUNDARIA') return ['1', '2', '3'];
        if (nivel === 'PRIMARIA' || nivel === 'BACHILLERATO') return ['1', '2', '3', '4', '5', '6'];
        return ['1', '2', '3'];
      },
      get gruposDisponiblesNuevo() {
        if (!this.nuevoAlumnoData.nivel || !this.nuevoAlumnoData.grado) return [];
        const nivel = this.nuevoAlumnoData.nivel.toUpperCase();
        return this.gruposData.filter(g => g.nivel && g.nivel.toUpperCase() === nivel && g.grado === this.nuevoAlumnoData.grado);
      },
      get gradosDisponiblesFicha() {
        if (!this.alumnoFichaEditable || !this.alumnoFichaEditable.nivel) return [];
        const nivel = this.alumnoFichaEditable.nivel.toUpperCase();
        if (nivel === 'PREESCOLAR' || nivel === 'SECUNDARIA') return ['1', '2', '3'];
        if (nivel === 'PRIMARIA' || nivel === 'BACHILLERATO') return ['1', '2', '3', '4', '5', '6'];
        return ['1', '2', '3'];
      },
      get gruposDisponiblesFicha() {
        if (!this.alumnoFichaEditable || !this.alumnoFichaEditable.nivel || !this.alumnoFichaEditable.grado) return [];
        const nivel = this.alumnoFichaEditable.nivel.toUpperCase();
        return this.gruposData.filter(g => g.nivel && g.nivel.toUpperCase() === nivel && g.grado === this.alumnoFichaEditable.grado);
      },

      // ── Carga inicial de datos ───────────────────────────────────────────────
      async _cargarAlumnosAPI(pagina, q) {
        const p   = pagina || this.paginaAlumnos;
        const params = { page: p, limit: this.limitAlumnos, q };
        if (this.filtroEstadoAlumno) params.estado = this.filtroEstadoAlumno;
        const res = await window.saeApi.alumnos.listar(params);
        if (res.ok) {
          const lista = res.pagination ? res.data : (Array.isArray(res.data) ? res.data : []);
          this.listaAlumnos     = lista.map(window.saeApi.mapAlumno);
          this.filtrarAlumnos();
          if (res.pagination) {
            this.paginaAlumnos  = res.pagination.page;
            this.totalAlumnos   = res.pagination.total;
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

      async _cargarGruposAPI() {
        const res = await window.saeApi.grupos.listar();
        if (res.ok && res.data) {
          this.gruposData = res.data.map(window.saeApi.mapGrupo);
        } else if (!res.offline) {
          window.saeApi.toast('error', res.message || 'Error al cargar grupos.');
        }
      },

      async _cargarPagosAPI(pagina) {
        const p   = pagina || this.paginaPagos;
        const res = await window.saeApi.pagos.listar({ page: p, limit: this.limitPagos });
        if (res.ok) {
          const lista = res.pagination ? res.data : (Array.isArray(res.data) ? res.data : []);
          this.pagosRegistrados = lista.map(window.saeApi.mapPago);
          if (res.pagination) {
            this.paginaPagos  = res.pagination.page;
            this.totalPagos   = res.pagination.total;
            this.paginasPagos = res.pagination.pages;
          }
        }
      },
      async _irPaginaPagos(p) {
        if (p < 1 || p > this.paginasPagos) return;
        await this._cargarPagosAPI(p);
      },

      async _cargarUsuariosAPI() {
        const res = await window.saeApi.usuarios.listar(this.verInactivos);
        if (res.ok && res.data) {
          this.listaUsuarios = res.data.map(u => ({ id: u.id, nombre: u.nombre, username: u.username, rol: u.rol, activo: u.activo }));
        }
      },

      async _cargarDashboard() {
        // Métricas desde datos ya en memoria
        this.dashSummary.alumnos  = this.listaAlumnos.length;
        this.dashSummary.deudores = this.listaAlumnos.filter(a => (a.mesesAdeudo || 0) > 0).length;
        // Ingresos del día actual (desde pagos filtrados por fecha)
        const hoy  = new Date().toISOString().slice(0, 10);
        const resP = await window.saeApi.pagos.listar({ fechaDesde: hoy, fechaHasta: hoy });
        if (resP.ok) {
          const lista = Array.isArray(resP.data) ? resP.data : [];
          const mapeados = lista.map(window.saeApi.mapPago);
          this.dashSummary.ingresosHoy = mapeados.reduce((s, p) => s + (Number(p.monto) || 0), 0);
          this.dashUltimosPagos        = mapeados.slice(0, 5);
        }
        // Becas activas
        const resB = await window.saeApi.becas.listar();
        if (resB.ok && resB.data) {
          this.dashSummary.becasActivas = resB.data.length;
        }
      },

      // ── Bitácora ─────────────────────────────────────────────────────────────
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

      // ── Permisos ─────────────────────────────────────────────────────────────
      async cargarPermisos() {
        // 1. Cargar la lista de módulos
        if (this.todosModulos.length === 0) {
          const resMod = await window.saeApi.permisos.modulos();
          if (resMod.ok) this.todosModulos = resMod.data;
        }
        
        // 2. Cargar usuarios GESTOR y MAESTRA (incluyendo inactivos para RF-02 Flujo Alterno A)
        const resUsu = await window.saeApi.usuarios.listar(true);
        if (resUsu.ok) {
          this.listaUsuariosPermisos = resUsu.data.filter(u => u.rol === 'GESTOR' || u.rol === 'MAESTRA');
        }
      },
      async seleccionarUsuarioPermisos(u) {
        if (this.todosModulos.length === 0) {
          const resMod = await window.saeApi.permisos.modulos();
          if (resMod.ok) this.todosModulos = resMod.data;
        }
        this.usuarioPermisosActivo = u;
        
        // Inicializar con predeterminados según el rol
        const perms = {};
        this.todosModulos.forEach(m => {
          if (u.rol === 'Docente' || u.rol === 'MAESTRA') {
            if (m === 'tutores') perms[m] = 'lectura';
            else if (m === 'calificaciones') perms[m] = 'escritura';
            else perms[m] = 'NINGUNO';
          } else if (u.rol === 'Gestor' || u.rol === 'GESTOR') {
            if (['alumnos', 'tutores', 'pagos', 'becas', 'calificaciones', 'configuracion', 'colegiaturas'].includes(m)) perms[m] = 'escritura';
            else if (m === 'reportes') perms[m] = 'lectura';
            else perms[m] = 'NINGUNO';
          } else {
            perms[m] = 'NINGUNO';
          }
        });
        
        // Cargar permisos del servidor
        const res = await window.saeApi.permisos.obtenerUsuario(u.id);
        if (res.ok && res.data && res.data.length > 0) {
          // Si tiene configuracion guardada, usarla en vez de los defaults
          const permsGuardados = {};
          this.todosModulos.forEach(m => permsGuardados[m] = 'NINGUNO');
          res.data.forEach(p => {
            permsGuardados[p.modulo] = p.nivel;
          });
          this.permisosEditando = permsGuardados;
        } else {
          // Si está vacío, cargar los predeterminados en la UI (listos para ser guardados)
          this.permisosEditando = perms;
        }
      },
      async guardarPermisosUsuario(usuarioId) {
        // Convertir el objeto { modulo: "NIVEL" } a un array
        const permisos = Object.keys(this.permisosEditando)
          .filter(mod => this.permisosEditando[mod] !== 'NINGUNO')
          .map(mod => ({ modulo: mod, nivel: this.permisosEditando[mod] }));
          
        const res = await window.saeApi.permisos.actualizar({ usuarioId, permisos });
        if (res.ok) {
          window.saeApi.toast('exito', 'Permisos actualizados correctamente');
        } else {
          window.saeApi.toast('error', res.message || 'Error al guardar permisos');
        }
      },


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
        } catch (e) {
          window.saeApi.toast('error', 'Error al cargar perfil del tutor');
        }
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
          } else {
            window.saeApi.toast('error', res?.message || 'Error al guardar');
          }
        } catch(e) { window.saeApi.toast('error', 'Error de red'); }
      },
      async guardarCambiosTutor() {
        // También validar aquí por si guardan desde el botón principal
        if (this.tutorFichaEditable.requiereFactura) {
          let errores = [];
          const rfc = this.tutorFichaEditable.rfc || '';
          if (rfc.length < 12 || rfc.length > 13) errores.push('El RFC debe tener 12 o 13 caracteres');
          if (!this.tutorFichaEditable.regimenFiscal) errores.push('Falta seleccionar el Régimen Fiscal');
          if (!this.tutorFichaEditable.usoCfdi) errores.push('Falta seleccionar el Uso de CFDI');
          const cp = this.tutorFichaEditable.codigoPostal || '';
          if (cp.length !== 5) errores.push('El Código Postal debe tener 5 dígitos');
          const dir = this.tutorFichaEditable.direccionFiscal || '';
          if (dir.trim() === '') errores.push('Falta la Dirección Fiscal');
          const email = this.tutorFichaEditable.correoFacturacion || '';
          if (!email.includes('@')) errores.push('El correo de facturación es inválido');

          if (errores.length > 0) {
            this.errorFacturacion = true;
            window.saeApi.toast('error', errores[0]);
            return;
          }
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
          } else {
            window.saeApi.toast('error', res?.message || 'Error al guardar');
          }
        } catch (e) {
          window.saeApi.toast('error', 'Error de red al actualizar tutor');
        }
      },
      async guardarFacturacionTutor() {
        if (this.tutorFichaEditable.requiereFactura) {
          let errores = [];
          const rfc = this.tutorFichaEditable.rfc || '';
          if (rfc.length < 12 || rfc.length > 13) errores.push('El RFC debe tener 12 o 13 caracteres');
          if (!this.tutorFichaEditable.regimenFiscal) errores.push('Falta seleccionar el Régimen Fiscal');
          if (!this.tutorFichaEditable.usoCfdi) errores.push('Falta seleccionar el Uso de CFDI');
          const cp = this.tutorFichaEditable.codigoPostal || '';
          if (cp.length !== 5) errores.push('El Código Postal debe tener 5 dígitos');
          const dir = this.tutorFichaEditable.direccionFiscal || '';
          if (dir.trim() === '') errores.push('Falta la Dirección Fiscal');
          const email = this.tutorFichaEditable.correoFacturacion || '';
          if (!email.includes('@')) errores.push('El correo de facturación es inválido');

          if (errores.length > 0) {
            this.errorFacturacion = true;
            window.saeApi.toast('error', errores[0]);
            return;
          }
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
            setTimeout(() => { if(window.lucide) window.lucide.createIcons(); }, 150);
          } else {
            window.saeApi.toast('error', res?.message || 'Error al guardar facturación');
          }
        } catch (e) {
          window.saeApi.toast('error', 'Error de red al actualizar facturación');
        }
      },
      abrirModalPagoDesdeAlumno(al) {
        this.alumnoActualFicha = al;
        this.abrirModalPago();
        setTimeout(() => {
          this.seleccionarPagoAlumno(al);
        }, 50);
      },
      abrirModalVincularTutor() {
        this.busquedaVincularTutor = '';
        this.tutoresParaVincular = [];
        this.modalVincularTutor = true;
      },
      async buscarTutorParaVincular() {
        const q = this.busquedaVincularTutor.toLowerCase();
        if (q.length < 3) {
          this.tutoresParaVincular = [];
          return;
        }
        try {
          const res = await window.saeApi.tutores.listar({ q: q, limit: 5 });
          if (res && res.ok && Array.isArray(res.data)) {
            this.tutoresParaVincular = res.data;
          }
        } catch (e) {
          console.error(e);
          this.tutoresParaVincular = [];
        }
      },
      async confirmarVinculacionTutor(tutor) {
        try {
          const payload = { alumnoId: this.alumnoActualFicha.id, tipoRelacion: 'tutor', esResponsableFinanciero: false };
          const res = await window.saeApi.tutores.vincular(tutor.tutorId, payload);
          if (res && res.ok) {
            window.saeApi.toast('exito', 'Tutor vinculado correctamente');
            this.modalVincularTutor = false;
            this.seleccionarAlumnoFicha(this.alumnoActualFicha); // recargar ficha
          } else {
            window.saeApi.toast('error', res?.message || 'Error al vincular');
          }
        } catch(e) { window.saeApi.toast('error', 'Error de red'); }
      },
      async _cargarEstadoCuentaConsolidado() {
          if (!this.tutorActualFicha) return;
          try {
            // Obtenemos los alumnos del tutor
            const alumnosIds = this.tutorActualFicha.alumnos.map(a => a.alumno.alumnoId);
            if (!alumnosIds.length) {
              this.estadoCuentaConsolidado = [];
              this.totalDeudaConsolidada = 0;
              return;
            }

            // Llamamos al endpoint calendario con múltiples alumnos si se puede, 
            // sino hacemos fetch manual para cada uno. (Aquí simplificamos haciéndolo por cada uno)
            let deudas = [];
            for(const aId of alumnosIds) {
               const res = await window.saeApi.pagos.calendario({ alumnoId: aId, estadoCobro: 'pendiente,parcial' });
               if(res.ok && res.data) {
                 deudas.push(...res.data.map(d => ({...d, alumno: this.tutorActualFicha.alumnos.find(x=>x.alumno.alumnoId===aId).alumno })));
               }
            }
            
            this.estadoCuentaConsolidado = deudas.sort((a,b) => new Date(a.fechaVencimiento) - new Date(b.fechaVencimiento));
            this.totalDeudaConsolidada = this.estadoCuentaConsolidado.reduce((sum, item) => sum + Number(item.saldoPendiente || 0), 0);
            
            setTimeout(() => { if(window.lucide) window.lucide.createIcons(); }, 150);
          } catch(e) {
            console.error(e);
          }
        },
        abrirModalPagoConsolidado() {
          this.pagoConsolidadoTemp = { metodo: 'efectivo', comprobante: null, abonos: {} };
          // Por defecto asignamos abonos automáticos para liquidar todo o podemos dejar que el usuario asigne
          for(const item of this.estadoCuentaConsolidado) {
             this.pagoConsolidadoTemp.abonos[item.calendarioPagoId] = item.saldoPendiente;
          }
          this.modalPagoConsolidado = true;
        },
        async procesarPagoConsolidado() {
           const abonosArray = [];
           let suma = 0;
           for(const key in this.pagoConsolidadoTemp.abonos) {
              const monto = Number(this.pagoConsolidadoTemp.abonos[key]);
              if(monto > 0) {
                 abonosArray.push({ calendarioPagoId: Number(key), montoAbonado: monto });
                 suma += monto;
              }
           }
           if(suma <= 0) return window.saeApi.toast('error', 'El monto a pagar debe ser mayor a 0');

           try {
             this.cargando = true;
             // Primero registramos el pago
             const res = await fetch(`/api/v1/pagos/consolidado`, {
               method: 'POST',
               headers: { 'Authorization': 'Bearer ' + localStorage.getItem('token'), 'Content-Type': 'application/json' },
               body: JSON.stringify({ tutorId: this.tutorActualFicha.tutorId, abonos: abonosArray, metodoPago: this.pagoConsolidadoTemp.metodo })
             }).then(r => r.json());

             if(!res.ok) throw new Error(res.message);

             // Subir comprobante si hay
             if(this.pagoConsolidadoTemp.comprobante && res.data?.pagoId) {
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
           } catch(e) {
             window.saeApi.toast('error', e.message);
           } finally {
             this.cargando = false;
           }
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
      async _cargarTutoresDelAlumno(id) {
        try {
          const res = await window.saeApi.alumnos.obtener(id);
          if (res && res.ok) {
            this.tutoresAlumnoFicha = res.data.padresOriginal || [];
          }
        } catch (e) {
          console.error(e);
        }
      },
      async _cargarPagosAlumnoFicha() {
        if (!this.alumnoActualFicha) return;
        try {
          const res = await window.saeApi.pagos.listar({ alumnoId: this.alumnoActualFicha.id });
          if (res && res.ok) {
            // Check if paginated or flat array
            this.historialPagosAlumno = res.pagination ? res.data : (Array.isArray(res.data) ? res.data : []);
            // Give lucide icons a moment to render for new elements
            setTimeout(() => { if(window.lucide) window.lucide.createIcons(); }, 150);
          }
        } catch (e) {
          console.error('Error loading payment history:', e);
        }
      },
      async _cargarEstadoCuentaAlumnoFicha() {
        if (!this.alumnoActualFicha) return;
        try {
          const [resCal, resPagos] = await Promise.all([
            window.saeApi.pagos.calendario({ alumnoId: this.alumnoActualFicha.id }),
            window.saeApi.pagos.listar({ alumnoId: this.alumnoActualFicha.id })
          ]);
          
          let datos = [];
          if (resCal && resCal.ok) {
            let calData = Array.isArray(resCal.data) ? resCal.data : [];
            const hoy = new Date().toISOString().split('T')[0];
            calData = calData.map(d => {
              if (d.estadoCobro === 'pagado' || Number(d.saldoPendiente) === 0) {
                d.estadoCalc = 'PAGADO';
              } else if (d.fechaVencimiento < hoy) {
                d.estadoCalc = 'VENCIDO';
              } else {
                d.estadoCalc = 'PENDIENTE';
              }
              d.timelineId = 'cal_' + d.calendarioPagoId;
              return d;
            });
            datos = datos.concat(calData);
          }
          
          if (resPagos && resPagos.ok) {
            let pagosData = resPagos.pagination ? resPagos.data : (Array.isArray(resPagos.data) ? resPagos.data : []);
            let pagosSinCalendario = pagosData.filter(p => !p.aplicaciones || p.aplicaciones.length === 0);
            pagosSinCalendario = pagosSinCalendario.map(p => {
              return {
                timelineId: 'pago_' + p.id,
                concepto: p.concepto || 'Pago',
                mes: '',
                fechaVencimiento: p.fecha.split('T')[0],
                montoOriginal: p.monto,
                montoPagado: p.monto,
                saldoPendiente: 0,
                estadoCalc: 'PAGADO',
                estadoCobro: 'pagado'
              };
            });
            datos = datos.concat(pagosSinCalendario);
          }
          
          datos.sort((a,b) => new Date(a.fechaVencimiento) - new Date(b.fechaVencimiento));
          this.estadoCuentaAlumno = datos;
          setTimeout(() => { if(window.lucide) window.lucide.createIcons(); }, 150);
        } catch (e) {
          console.error('Error loading estado de cuenta:', e);
        }
      },
      async _cargarPagosTutorFicha() {
        if (!this.tutorActualFicha?.alumnos || this.tutorActualFicha.alumnos.length === 0) {
          this.historialPagosTutor = [];
          return;
        }
        try {
          let todosLosPagos = [];
          for (let al of this.tutorActualFicha.alumnos) {
            const res = await window.saeApi.pagos.listar({ alumnoId: al.alumnoId });
            if (res && res.ok) {
              const pagosAlumno = res.pagination ? res.data : (Array.isArray(res.data) ? res.data : []);
              pagosAlumno.forEach(p => { p.alumnoNombre = al.alumno?.nombreCompleto || 'Alumno' });
              todosLosPagos = todosLosPagos.concat(pagosAlumno);
            }
          }
          // Sort by date descending
          todosLosPagos.sort((a,b) => new Date(b.fecha) - new Date(a.fecha));
          this.historialPagosTutor = todosLosPagos;
          
          setTimeout(() => { if(window.lucide) window.lucide.createIcons(); }, 150);
        } catch (e) {
          console.error('Error loading tutor payment history:', e);
        }
      },
      async subirComprobanteHistorial(pagoId, event) {
        const file = event.target.files[0];
        if (!file) return;
        try {
          const res = await window.saeApi.pagos.subirComprobante(pagoId, file);
          if (res && res.ok) {
            window.saeApi.toast('exito', 'Comprobante subido correctamente');
            this._cargarPagosAlumnoFicha();
          } else {
            window.saeApi.toast('error', res?.message || 'Error al subir comprobante');
          }
        } catch (e) {
          console.error(e);
          window.saeApi.toast('error', 'Error de red al subir comprobante');
        } finally {
          event.target.value = '';
        }
      },
      async guardarCambiosAlumno() {
        // Simplified academic edit
        try {
          const payload = {
            nombre: this.alumnoFichaEditable.nombre,
            curp: this.alumnoFichaEditable.curp,
            estado: this.alumnoFichaEditable.estado,
            // observaciones was mistakenly overwritten by autorizados before
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
        } catch (e) {
          window.saeApi.toast('error', 'Error de red');
        }
      },
      async cambiarEstadoAlumno(nuevoEstado, motivoExterno) {
        let observacionesExtra = '';
        if (motivoExterno) {
          observacionesExtra = `[${nuevoEstado.toUpperCase()} ${new Date().toLocaleDateString()}]: ${motivoExterno.trim()}`;
        } else if (nuevoEstado === 'Activo' && this.alumnoActualFicha.estado !== 'Activo') {
          const motivo = prompt('Por favor, ingresa el motivo de la reactivación (ej. acuerdo de pago, convenio institucional):');
          if (motivo === null) return;
          if (motivo.trim() === '') {
            window.saeApi.toast('error', 'El motivo de reactivación es obligatorio.');
            return;
          }
          observacionesExtra = `[REACTIVACIÓN ${new Date().toLocaleDateString()}]: ${motivo.trim()}`;
        } else if (nuevoEstado !== 'Activo' && nuevoEstado !== this.alumnoActualFicha.estado) {
          const motivo = prompt(`Por favor, ingresa el motivo para cambiar a ${nuevoEstado}:`);
          if (motivo === null) return;
          if (motivo.trim() === '') {
            window.saeApi.toast('error', `El motivo para cambiar a ${nuevoEstado} es obligatorio.`);
            return;
          }
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
        } catch (e) {
          window.saeApi.toast('error', 'Error de red');
        }
      },
      confirmarBajaDefinitiva() {
        const motivo = prompt('Por favor, ingresa el motivo para la Baja Definitiva:');
        if (motivo === null) return;
        if (motivo.trim() === '') {
          window.saeApi.toast('error', 'El motivo de la Baja Definitiva es obligatorio.');
          return;
        }
        if (confirm('¿Estás seguro de dar BAJA DEFINITiva a este alumno? Esta acción cerrará su expediente y lo ocultará de la vista principal.')) {
          this.cambiarEstadoAlumno('Baja Definitiva', motivo);
        }
      },

      filtrarAlumnosBeca() {
        const q = this.busquedaAlumnoBeca.toLowerCase();
        if (q.trim() === '') {
          this.alumnosBecaFiltrados = [];
          return;
        }
        this.alumnosBecaFiltrados = this.listaAlumnos.filter(a =>
          a.nombre.toLowerCase().includes(q) ||
          a.matricula.toLowerCase().includes(q)
        );
      },
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

      // ── Reportes Financieros ───────────────────────────────────────────────
      async cargarReporteCorte() {
        try {
          const res = await window.saeApi.reportes.corteCaja();
          if (res && res.ok) this.reporteCorte = res.data;
        } catch (e) { console.error('Error cargando corte de caja', e); }
      },
      async cargarReporteIngresos() {
        try {
          const res = await window.saeApi.reportes.ingresosMensuales(this.cicloSeleccionadoIngresos);
          if (res && res.ok) this.reporteIngresos = res.data;
        } catch (e) { console.error('Error cargando ingresos', e); }
      },
      async cargarReporteDeudores() {
        try {
          const res = await window.saeApi.reportes.deudores();
          if (res && res.ok) this.reporteDeudores = res.data;
        } catch (e) { console.error('Error cargando deudores', e); }
      },
      async cargarReporteFacturables() {
        try {
          const res = await window.saeApi.reportes.facturables();
          if (res && res.ok) this.reporteFacturables = res.data;
        } catch (e) { console.error('Error cargando facturables', e); }
      },

      _descargarCSV(filename, content) {
        const blob = new Blob(['\uFEFF' + content], { type: 'text/csv;charset=utf-8;' }); 
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.setAttribute('href', url);
        link.setAttribute('download', filename);
        link.style.visibility = 'hidden';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
      },
      exportarCorteCSV() {
        if (!this.reporteCorte || !this.reporteCorte.pagos || this.reporteCorte.pagos.length === 0) return window.saeApi.toast('advertencia', 'No hay datos para exportar.');
        const encabezados = ['Alumno', 'Matrícula', 'Método', 'Registrado por', 'Monto'];
        const filas = this.reporteCorte.pagos.map(p => [
          `"${p.alumno}"`, `"${p.matricula}"`, `"${p.metodoPago}"`, `"${p.registradoPor}"`, p.monto
        ]);
        const csvContent = [encabezados.join(','), ...filas.map(f => f.join(','))].join('\n');
        this._descargarCSV(`Corte_Caja_${this.reporteCorte.fecha || 'hoy'}.csv`, csvContent);
      },
      exportarIngresosCSV() {
        if (!this.reporteIngresos || !this.reporteIngresos.meses) return window.saeApi.toast('advertencia', 'No hay datos para exportar.');
        const encabezados = ['Mes', 'Monto'];
        const filas = Object.entries(this.reporteIngresos.meses).map(([mes, monto]) => [
          `"${mes}"`, monto
        ]);
        const csvContent = [encabezados.join(','), ...filas.map(f => f.join(','))].join('\n');
        this._descargarCSV(`Ingresos_Mensuales_${this.reporteIngresos.anio || 'anio'}.csv`, csvContent);
      },
      exportarDeudoresCSV() {
        if (!this.reporteDeudores || this.reporteDeudores.length === 0) return window.saeApi.toast('advertencia', 'No hay datos para exportar.');
        const encabezados = ['Alumno', 'Matrícula', 'Nivel', 'Meses Adeudo', 'Monto Total', 'Sanción'];
        const filas = this.reporteDeudores.map(d => [
          `"${d.nombre}"`, `"${d.matricula}"`, `"${d.nivel}"`, d.mesesAdeudo, d.montoTotal, `"${d.sancion}"`
        ]);
        const csvContent = [encabezados.join(','), ...filas.map(f => f.join(','))].join('\n');
        this._descargarCSV(`Lista_Deudores.csv`, csvContent);
      },
      exportarFacturablesCSV() {
        if (!this.reporteFacturables || this.reporteFacturables.length === 0) return window.saeApi.toast('advertencia', 'No hay datos para exportar.');
        const encabezados = ['Nombre', 'RFC', 'Régimen', 'Correo Facturación', 'Hijos'];
        const filas = this.reporteFacturables.map(t => [
          `"${t.nombreCompleto}"`, `"${t.rfc || 'Sin RFC'}"`, `"${t.regimenFiscal || ''}"`, `"${t.correoFacturacion || t.correoElectronico || ''}"`, `"${(t.hijos || []).map(h=>h.nombre).join('; ')}"`
        ]);
        const csvContent = [encabezados.join(','), ...filas.map(f => f.join(','))].join('\n');
        this._descargarCSV(`Padres_Facturables.csv`, csvContent);
      },

      // ── Alumnos ─────────────────────────────────────────────────────────────
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

        const csvContent = [
          encabezados.join(','),
          ...filas.map(fila => fila.join(','))
        ].join('\n');

        const blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' }); 
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.setAttribute('href', url);
        link.setAttribute('download', `Directorio_Alumnos_${new Date().toISOString().slice(0,10)}.csv`);
        link.style.visibility = 'hidden';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
      },
      getUsuariosFiltrados() {
        const q = this.busquedaUsuario.toLowerCase();
        const rol = this.filtroRolUsuario.toLowerCase();
        return this.listaUsuarios.filter(u => {
          const matchBusqueda = u.nombre.toLowerCase().includes(q) || (u.username && u.username.toLowerCase().includes(q));
          const matchRol = !rol || u.rol.toLowerCase() === rol;
          return matchBusqueda && matchRol;
        });
      },
      get becaAlumnoFicha() {
        if (!this.alumnoActualFicha) return null;
        return this.becasAsignadas.find(b => b.alumnoId === this.alumnoActualFicha.id);
      },
      seleccionarAlumnoFicha(al) {
        window.saeApi.alumnos.obtener(al.id).then(async res => {
          if (res && res.ok && res.data) {
            this.alumnoActualFicha = res.data;
            this.alumnoActualFicha.padresLista = res.data.padres || [];
            this.alumnoFichaEditable = {
              nombre: res.data.nombre,
              curp: res.data.curp,
              estado: res.data.estado || 'Activo',
              autorizados: typeof res.data.personasAutorizadas === 'string' ? res.data.personasAutorizadas : (res.data.autorizados || ''),
              fechaNacimiento: res.data.fechaNacimiento ? res.data.fechaNacimiento.split('T')[0] : '',
              nivel: (res.data.nivel || res.data.grupo?.nivel || '').toUpperCase(),
              grado: res.data.grupo?.grado ? String(res.data.grupo.grado) : '',
              grupoId: res.data.grupoId || ''
            };
            this.tutoresAlumnoFicha = [];
            this.historialPagosAlumno = [];
            this.alumnoSeleccionado = true;
            this.tabAlumnoFicha = 'academicos';
            // Asegurarse de tener las becas cargadas
            if (this.becasAsignadas.length === 0) this.cargarBecasAsignadas();
              
              // Cargar Boleta Virtual
              this.historialAcademico = [];
              this.promedioGeneralFicha = null;
              if (al.grupoId) {
                  const grupoRes = await window.saeApi.grupos.obtener(al.grupoId);
                  if (grupoRes.ok && grupoRes.data && grupoRes.data.materias) {
                      const esPre = (grupoRes.data.nivel === 'PREESCOLAR' || (al.nivel && al.nivel.toUpperCase() === 'PREESCOLAR'));
                      let sumGral = 0, countGral = 0;
                      
                      const materiasArr = grupoRes.data.materias.map(m => ({
                          id: m.id, nombre: m.materia, T1: {v:'', t:''}, T2: {v:'', t:''}, T3: {v:'', t:''}, prom: null
                      }));
                      
                      const calRes = await window.saeApi.calificaciones.porAlumno(al.id, undefined);
                      if (calRes.ok && calRes.data) {
                          calRes.data.forEach(c => {
                             const mat = materiasArr.find(x => x.id === c.grupoMateriaId);
                             if(mat) {
                                 const k = c.periodo.numero === 1 ? 'T1' : c.periodo.numero === 2 ? 'T2' : 'T3';
                                 mat[k].v = c.valor || '';
                                 mat[k].t = c.textoObservacion || '';
                             }
                          });
                      }
                      
                      materiasArr.forEach(mat => {
                         if(esPre) { mat.prom = 'N/A'; }
                         else {
                             let s = 0, c = 0;
                             if(mat.T1.v !== '') { s += parseFloat(mat.T1.v); c++; }
                             if(mat.T2.v !== '') { s += parseFloat(mat.T2.v); c++; }
                             if(mat.T3.v !== '') { s += parseFloat(mat.T3.v); c++; }
                             if(c>0) {
                                mat.prom = (s/c).toFixed(1);
                                sumGral += parseFloat(mat.prom);
                                countGral++;
                             } else {
                                mat.prom = '-';
                             }
                         }
                      });
                      
                      this.historialAcademico = materiasArr;
                      this.promedioGeneralFicha = esPre ? 'N/A' : (countGral > 0 ? (sumGral/countGral).toFixed(1) : '-');
                  }
              }
            } else {
            console.error('Error al obtener expediente', res);
            window.saeApi.toast('error', res?.message || 'Error al cargar el expediente del alumno.');
          }
        }).catch(err => {
          console.error('Error de red al obtener expediente', err);
          window.saeApi.toast('error', 'Error de comunicación con el servidor.');
        });
      },
      openNuevoAlumno() {
        this.modalNuevoAlumno = true;
      },
      
      // ── Planes de Pago (RF-31) ──────────────────────────────────────────────────
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
        } finally {
          this.cargando = false;
        }
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
            // Opcional: Recargar el expediente del alumno
            this.seleccionarAlumnoFicha({ id: this.alumnoActualFicha.id });
          } else {
            window.saeApi.toast('error', res.message || 'Error al asignar el plan.');
          }
        } catch (e) {
          console.error(e);
          window.saeApi.toast('error', 'Error al asignar el plan.');
        } finally {
          this.cargando = false;
        }
      },

      initNuevoAlumno() {
        this.nuevoAlumnoData  = { nombre: '', matricula: '', curp: '', grupoId: null, padre: '', telefono: '', tutorId: null, fechaNacimiento: '', personasAutorizadas: '' };
        this.erroresNuevoAlumno = {};
        this.sugerenciasTutor = [];
      },
      async buscarTutorAutocomplete() {
        if (!this.nuevoAlumnoData.padre || this.nuevoAlumnoData.padre.length < 3) {
          this.sugerenciasTutor = [];
          if(this.nuevoAlumnoData.tutorId) {
            // El usuario editó el texto, desvincular el ID
            this.nuevoAlumnoData.tutorId = null;
            this.nuevoAlumnoData.telefono = '';
          }
          return;
        }
        
        // Si el texto actual es exactamente igual al tutor seleccionado, no buscar
        if(this.nuevoAlumnoData.tutorId) return;

        try {
          const res = await window.saeApi.tutores.listar({ q: this.nuevoAlumnoData.padre, limit: 5 });
          if (res && res.ok && Array.isArray(res.data)) {
            this.sugerenciasTutor = res.data;
          }
        } catch (e) { console.error(e); }
      },
      seleccionarTutorSugerido(tut) {
        this.nuevoAlumnoData.tutorId = tut.tutorId;
        this.nuevoAlumnoData.padre = tut.nombreCompleto;
        this.nuevoAlumnoData.telefono = tut.telefono || '';
        this.sugerenciasTutor = [];
      },
      async guardarNuevoAlumno() {
        // Validación de campos requeridos
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
          nombre:    this.nuevoAlumnoData.nombre,
          matricula: this.nuevoAlumnoData.matricula,
          curp:      this.nuevoAlumnoData.curp || undefined,
          fechaNacimiento: this.nuevoAlumnoData.fechaNacimiento || undefined,
          autorizadosRecoger: this.nuevoAlumnoData.personasAutorizadas || undefined,
          grupoId:   this.nuevoAlumnoData.grupoId ? Number(this.nuevoAlumnoData.grupoId) : undefined,
          padres:    this.nuevoAlumnoData.padre
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

      // ── Calificaciones ───────────────────────────────────────────────────────
      buscarAlumnoCalif() {
          const q = this.busquedaCalif.toLowerCase();
          const nivel = this.filtroCalifNivel;
          const grado = this.filtroCalifGrado;
          const grupo = this.filtroCalifGrupo;
          
          if (q.length > 1 || nivel) {
            this.alumnosCoincidencias = this.listaAlumnos.filter(a => {
              const matchBusqueda = !q || a.nombre.toLowerCase().includes(q) || a.matricula.toLowerCase().includes(q);
              const matchNivel = !nivel || (a.nivel && a.nivel.toUpperCase() === nivel.toUpperCase());
              const matchGrado = !grado || a.grado === grado;
              const matchSeccion = !grupo || a.seccion === grupo;
              return matchBusqueda && matchNivel && matchGrado && matchSeccion;
            });
          } else {
            this.alumnosCoincidencias = [];
          }
        },
      async seleccionarAlumnoCalif(al) {
        this.alumnoActualCalif      = al;
        this.alumnoSeleccionadoCalif = true;
        this.materiasAlumno = []; this.esPreescolar = false;
        
        this.busquedaCalif          = '';



        // Cargar materias del grupo para obtener IDs
          if (al.grupoId) {
            const grupoRes = await window.saeApi.grupos.obtener(al.grupoId);
            if (grupoRes.ok && grupoRes.data && grupoRes.data.materias) {
                this.esPreescolar = (grupoRes.data.nivel === 'PREESCOLAR' || (al.nivel && al.nivel.toUpperCase() === 'PREESCOLAR'));
                grupoRes.data.materias.forEach(m => {
                  this.materiasAlumno.push({ id: m.id, nombre: m.materia, T1: {v:'', t:''}, T2: {v:'', t:''}, T3: {v:'', t:''}, prom: null });
                });
              }

            const calRes  = await window.saeApi.calificaciones.porAlumno(al.id, undefined);
            if (calRes.ok && calRes.data) {
              calRes.data.forEach(c => {
                  const mat = this.materiasAlumno.find(m => m.id === c.grupoMateriaId);
                  if (mat) {
                    const k = c.periodo.numero === 1 ? 'T1' : c.periodo.numero === 2 ? 'T2' : 'T3';
                    mat[k].v = c.valor || '';
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
               if(this.esPreescolar) { mat.prom = 'N/A'; }
               else {
                   let s = 0, c = 0;
                   if(mat.T1.v !== '') { s += parseFloat(mat.T1.v); c++; }
                   if(mat.T2.v !== '') { s += parseFloat(mat.T2.v); c++; }
                   if(mat.T3.v !== '') { s += parseFloat(mat.T3.v); c++; }
                   if(c>0) {
                      mat.prom = (s/c).toFixed(1);
                      sumGral += parseFloat(mat.prom);
                      countGral++;
                   } else {
                      mat.prom = '-';
                   }
               }
           });
           this.promedioGeneralCalif = this.esPreescolar ? 'N/A' : (countGral > 0 ? (sumGral/countGral).toFixed(1) : '-');
        },
      async guardarCalificacion() {
        if (!this.alumnoActualCalif || !this.alumnoActualCalif.id) {
          window.saeApi.toast('error', 'No hay alumno seleccionado.');
          return;
        }
        const periodosArr = ['TRIMESTRE_1', 'TRIMESTRE_2', 'TRIMESTRE_3'];
          const lote = [];
          
          for (const mat of this.materiasAlumno) {
            if (this.esPreescolar) {
               ['T1','T2','T3'].forEach((t, i) => {
                  const obs = (mat[t].t || '').trim();
                  if (obs) {
                      lote.push({ alumnoId: this.alumnoActualCalif.id, grupoMateriaId: mat.id, periodo: periodosArr[i], valor: null, textoObservacion: obs, tipoEvaluacion: 'cualitativa' });
                  }
               });
            } else {
               ['T1','T2','T3'].forEach((t, i) => {
                  const val = parseFloat(mat[t].v);
                  if (!isNaN(val) && val >= 0 && val <= 10) {
                      lote.push({ alumnoId: this.alumnoActualCalif.id, grupoMateriaId: mat.id, periodo: periodosArr[i], valor: val, tipoEvaluacion: 'numerica' });
                  }
               });
            }
          }

          if (lote.length === 0) {
          window.saeApi.toast('advertencia', 'No hay calificaciones válidas para guardar. Verifica que el alumno tenga grupo y materias asignadas.');
          return;
        }

        const res = await window.saeApi.calificaciones.guardarLote(lote);
        if (res.ok) {
          this.alumnoSeleccionadoCalif = false;
          window.saeApi.toast('exito', `${lote.length} calificación(es) guardada(s) para ${this.alumnoActualCalif.nombre}.`);
        } else {
            window.saeApi.toast('error', res.message || 'Error al guardar calificaciones.');
        }
      },

      // ── Becas ────────────────────────────────────────────────────────────────
      catalogoBecas:  [],
      becasAsignadas: [],
      solicitudesBeca: [],
      nuevaBeca: { alumnoId: null, becaId: null, porcentajeManual: null, motivo: '', nombreAlumno: '' },
      modalBeca: false,
      sugerenciasBeca: [],

      modalNuevoTipoBeca: false,
      nuevoTipoBecaData: { nombreBeca: '', criterio: '', porcentaje: '' },
      erroresBeca: { nombre: false, criterio: false, porcentaje: false },
      async cargarCatalogoBecas() {
        const res = await window.saeApi.becas.catalogo.listar();
        if (res.ok) this.catalogoBecas = res.data;
      },
      openModalNuevoTipoBeca() {
        this.nuevoTipoBecaData = { becaId: null, nombreBeca: '', criterio: '', porcentaje: '' };
        this.erroresBeca = { nombre: false, criterio: false, porcentaje: false };
        this.modalNuevoTipoBeca = true;
      },
      editarTipoBeca(beca) {
        this.nuevoTipoBecaData = { 
          becaId: beca.becaId, 
          nombreBeca: beca.nombreBeca, 
          criterio: beca.criterio, 
          porcentaje: beca.porcentaje 
        };
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

        if (hasError) {
          window.saeApi.toast('error', 'Todos los campos son obligatorios. El porcentaje debe ser un valor entre 1 y 100');
          return;
        }

        try {
          const payload = {
            nombreBeca: this.nuevoTipoBecaData.nombreBeca,
            criterio: this.nuevoTipoBecaData.criterio,
            porcentaje: p
          };
          
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
          } else {
            window.saeApi.toast('error', res?.message || 'Error al guardar beca');
          }
        } catch (e) {
          window.saeApi.toast('error', 'Error de red al guardar beca');
        }
      },
      async cargarBecasAsignadas() {
        const res = await window.saeApi.becas.listar();
        if (res.ok) this.becasAsignadas = res.data;
        if (this.esAdmin()) {
          this.cargarSolicitudesBeca();
        }
      },
      async cargarSolicitudesBeca() {
        try {
          const res = await window.saeApi.becas.listarSolicitudes();
          if (res && res.data) {
            this.solicitudesBeca = res.data.filter(s => s.estado === 'PENDIENTE');
          }
        } catch (e) { console.error(e); }
      },
      abrirModalBeca() {
        this.modalBecaActiva = true;
        this.nuevaBeca       = { alumnoId: null, becaId: null, observaciones: '' };
        this.busquedaAlumnoBeca = '';
        this.alumnosBecaFiltrados = [];
        this.cargarCatalogoBecas();
      },
      abrirModalBecaDesdeAlumno(alumno) {
        this.abrirModalBeca();
        this.nuevaBeca.alumnoId = alumno.id;
        this.busquedaAlumnoBeca = alumno.nombre + ' (' + alumno.matricula + ')';
      },
      async asignarBeca() {
        if (!this.nuevaBeca.alumnoId) {
          window.saeApi.toast('advertencia', 'Selecciona un alumno de la lista.');
          return;
        }
        if (!this.nuevaBeca.becaId) {
          window.saeApi.toast('advertencia', 'Selecciona un tipo de beca del catálogo.');
          return;
        }
        if (!this.tienePermiso('becas', 'escritura')) {
          window.saeApi.toast('error', 'No tienes permisos para asignar becas.');
          return;
        }

        const alumnoObj = this.listaAlumnos.find(a => a.id === Number(this.nuevaBeca.alumnoId));
        const becaObj = this.catalogoBecas.find(b => b.becaId === Number(this.nuevaBeca.becaId));
        const payload = {
          alumnoId: Number(this.nuevaBeca.alumnoId),
          becaId: Number(this.nuevaBeca.becaId),
          motivo: this.nuevaBeca.observaciones || ''
        };

        const res = await window.saeApi.becas.asignar(payload);
        if (res.ok) {
          this.modalBecaActiva = false;
          this.cargarBecasAsignadas(); // Refresh list
          window.saeApi.toast('exito', `Beca asignada a ${alumnoObj?.nombre || 'alumno'}.`);
          // Recargar ficha si está abierta
          if (this.alumnoActualFicha && this.alumnoActualFicha.id === payload.alumnoId) {
            this.seleccionarAlumnoFicha(this.alumnoActualFicha);
          }
        } else {
          window.saeApi.toast('error', res.message || 'Error al asignar beca.');
        }
      },
      async retirarBeca(becaAsignada) {
        const motivo = prompt('Ingresa el motivo del retiro de la beca (Obligatorio):');
        if (motivo === null) return; // cancelado
        if (!motivo.trim()) {
          window.saeApi.toast('advertencia', 'El motivo del retiro es obligatorio.');
          return;
        }

        if (!this.tienePermiso('becas', 'escritura')) {
          window.saeApi.toast('error', 'No tienes permisos para retirar becas.');
          return;
        }

        const res = await window.saeApi.becas.retirar(becaAsignada.id, { motivoRetiro: motivo.trim() });
        if (res.ok) {
          window.saeApi.toast('exito', 'Beca retirada correctamente. La colegiatura se actualizará al 100% a partir del siguiente periodo.');
          this.cargarBecasAsignadas();
          // Actualizar ficha de alumno si está abierta
          if (this.alumnoActualFicha && this.alumnoActualFicha.id === becaAsignada.alumnoId) {
            this.seleccionarAlumnoFicha(this.alumnoActualFicha);
          }
        } else {
          window.saeApi.toast('error', res.message || 'Error al retirar beca.');
        }
      },

      // ── Autocomplete de pago ─────────────────────────────────────────────────
      abrirModalPago() {
        this.modal               = 'pago';
        this.busquedaPagoAlumno  = '';
        this.pagoCoincidencias   = [];
        this.mostrarSugerenciasPago = false;
        this.nuevoPago           = { alumno: '', alumnoId: null, concepto: 'Colegiatura', monto: '', fecha: new Date().toISOString().slice(0,10), becaInfo: null, tipoPago: 'normal', mesesAdelantar: 1 };
      },
      filtrarPagoAlumnos() {
        const q = this.busquedaPagoAlumno.trim().toLowerCase();
        if (!q) {
          this.pagoCoincidencias      = [];
          this.mostrarSugerenciasPago = false;
          this.nuevoPago.alumno       = '';
          this.nuevoPago.alumnoId     = null;
          return;
        }
        this.pagoCoincidencias      = this.listaAlumnos
          .filter(a => a.nombre.toLowerCase().includes(q) || a.matricula.toLowerCase().includes(q))
          .slice(0, 8);
        this.mostrarSugerenciasPago = true;
        if (this.nuevoPago.alumno && this.busquedaPagoAlumno !== this.nuevoPago.alumno) {
          this.nuevoPago.alumno   = '';
          this.nuevoPago.alumnoId = null;
        }
      },
      limpiarSeleccionPago() {
        this.busquedaPagoAlumno = '';
        this.nuevoPago.alumno = '';
        this.nuevoPago.alumnoId = null;
        this.nuevoPago.monto = '';
        this.nuevoPago.concepto = 'Colegiatura';
        this.pagoAdeudos = [];
        this.mostrarSugerenciasPago = false;
        this.$nextTick(() => { lucide.createIcons(); });
      },
      async seleccionarPagoAlumno(al) {
        this.nuevoPago.alumno       = al.nombre;
        this.nuevoPago.alumnoId     = al.id;
        this.busquedaPagoAlumno     = al.nombre;
        this.mostrarSugerenciasPago = false;
        this.pagoCoincidencias      = [];
        this.pagoAdeudos            = [];
        
        // Fetch pending debts (Estado de Cuenta)
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
            // Sum up total debt as suggested amount
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
            // Default to first concept if applicable
            if (res.data.length > 0) {
              const firstA = res.data[0];
              const cMap = { 'COLEGIATURA': 'Colegiatura', 'INSCRIPCION': 'Inscripción', 'MATERIAL_DIDACTICO': 'Material didáctico', 'UNIFORME': 'Uniforme' };
              const mappedC = cMap[firstA.concepto.toUpperCase()];
              if (mappedC) this.nuevoPago.concepto = mappedC;
            }
          }
        } catch (e) {
          console.error(e);
        } finally {
          this.pagoCalculando = false;
        }
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
        
        let montoMensual = 0;
        if (this.alumnoPagoInfo?.planPago?.montoMensual) {
           montoMensual = Number(this.alumnoPagoInfo.planPago.montoMensual);
        }
        
        const colegiaturas = this.pagoAdeudos.filter(a => a.concepto.toLowerCase() === 'colegiatura');
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
        } else {
          this.nuevoPago.monto = '';
        }
      },
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
        if (esCero && !confirm('¿Estás seguro de condonar totalmente este recargo?')) {
          return;
        }

        const res = await window.saeApi.pagos.modificarRecargo(this.recargoEditando.recargoId, {
          montoNuevo: Number(this.formRecargo.montoNuevo),
          motivo: this.formRecargo.motivo
        });

        if (res.ok) {
          window.saeApi.toast('exito', res.message);
          this.recargoEditando = null;
          // Refrescar adeudos del alumno actual
          if (this.nuevoPago.alumnoId) {
             const al = this.pagoCoincidencias.find(x => x.id === this.nuevoPago.alumnoId) || this.listaAlumnos.find(x => x.id === this.nuevoPago.alumnoId) || { id: this.nuevoPago.alumnoId, nombre: this.nuevoPago.alumno };
             this.seleccionarPagoAlumno(al);
          }
          lucide.createIcons();
        } else {
          window.saeApi.toast('error', res.message || 'Error al modificar el recargo.');
        }
      },
      async agregarPago() {
        if (!this.nuevoPago.alumnoId) {
          window.saeApi.toast('advertencia', 'Selecciona un alumno de la lista de sugerencias.');
          return;
        }
        if (!this.nuevoPago.monto) {
          window.saeApi.toast('advertencia', 'Ingresa el monto del pago.');
          return;
        }
        const concepto = window.saeApi.CONCEPTO_MAP[this.nuevoPago.concepto] || 'OTRO';
        let res;
        
        if (this.nuevoPago.tipoPago === 'adelantado') {
          res = await window.saeApi.pagos.adelantado({
            alumnoId:  this.nuevoPago.alumnoId,
            meses:     parseInt(this.nuevoPago.mesesAdelantar),
            metodoPago: 'efectivo',
            fecha:     this.nuevoPago.fecha,
            monto:     parseFloat(this.nuevoPago.monto)
          });
          this.nuevoPago.concepto = `Adelanto de ${this.nuevoPago.mesesAdelantar} meses`;
        } else {
          res = await window.saeApi.pagos.registrar({
            alumnoId:  this.nuevoPago.alumnoId,
            concepto,
            monto:     parseFloat(this.nuevoPago.monto),
            fecha:     this.nuevoPago.fecha,
          });
        }
        if (res.ok) {
          const pagoId = res.data.pagoId || res.data.id;
          const fileInput = document.getElementById('comprobanteInputPago');
          let comprobanteMsj = '';
          
          if (fileInput && fileInput.files && fileInput.files.length > 0) {
            const uploadRes = await window.saeApi.pagos.subirComprobante(pagoId, fileInput.files[0]);
            if (!uploadRes.ok) {
              window.saeApi.toast('advertencia', 'Pago registrado, pero falló la subida del comprobante.');
            } else {
              comprobanteMsj = ' con comprobante adjunto';
            }
          }
          
          this.pagosRegistrados.unshift(window.saeApi.mapPago(res.data));
          
          // Generar recibo visual
          this.reciboGenerado = {
            id: pagoId || Math.floor(Math.random() * 10000),
            alumno: this.nuevoPago.alumno,
            concepto: this.nuevoPago.concepto,
            fecha: new Date().toLocaleString('es-MX'),
            monto: parseFloat(this.nuevoPago.monto).toFixed(2)
          };
          
          window.saeApi.toast('exito', `Pago de $${this.nuevoPago.monto} registrado para ${this.nuevoPago.alumno}${comprobanteMsj}.`);
          
          // Actualizar datos para que se quite de deudores y se sume al dashboard
          if (typeof this.cargarAlumnos === 'function') this.cargarAlumnos();
          if (typeof this._cargarDashboard === 'function') this._cargarDashboard();
          
          // Reset fields for the next form interaction
          this.nuevoPago.alumno = '';
          this.nuevoPago.alumnoId = null;
          this.nuevoPago.monto = '';
          this.nuevoPago.tipoPago = 'normal';
          this.nuevoPago.mesesAdelantar = 1;
          this.busquedaPagoAlumno = '';
          this.pagoAdeudos = [];
          if (fileInput) fileInput.value = '';
        } else {
          window.saeApi.toast('error', res.message || 'Error al registrar pago.');
        }
      },
      imprimirRecibo() {
        window.print();
      },

      // ── Usuarios ─────────────────────────────────────────────────────────────
      async agregarUsuario() {
        if (!this.nuevoUsuario.nombre || !this.nuevoUsuario.rol || !this.nuevoUsuario.password || !this.nuevoUsuario.username) {
          window.saeApi.toast('advertencia', 'Todos los campos (nombre, usuario, rol y contraseña) son obligatorios.');
          return;
        }
        
        const rol = window.saeApi.ROL_MAP[this.nuevoUsuario.rol] || 'MAESTRA';
        const res = await window.saeApi.usuarios.crear({
          nombre:   this.nuevoUsuario.nombre,
          username: this.nuevoUsuario.username,
          password: this.nuevoUsuario.password,
          rol,
        });
        
        if (res.ok) {
          this.listaUsuarios.push({ id: res.data.id, nombre: res.data.nombre, rol: res.data.rol });
          window.saeApi.toast('exito', `Cuenta para ${res.data.nombre} creada exitosamente con el rol de ${this.nuevoUsuario.rol}.`);
          this.modalUsuario = false;
          // Limpiar el formulario
          this.nuevoUsuario = { nombre: '', username: '', password: '', rol: '' };
        } else {
          // El backend responderá con status 409 si el usuario ya existe
          window.saeApi.toast('error', res.message || 'Error al crear usuario.');
        }
      },
      eliminarUsuario(idx) {
        const u = this.listaUsuarios[idx];
        if (!u || !u.id) return;
        // Abre el modal de confirmación — NO elimina de inmediato
        this._usuarioAEliminar = { idx, id: u.id, nombre: u.nombre };
        this.modalConfirmEliminar = true;
      },

      // ── Métodos para Tarifas y Ciclos (RF-30) ───────────────────────────────
      async crearCiclo() {
        if (!this.nuevoCicloData.nombre) return;
        this.cargando = true;
        try {
          const res = await window.saeApi.fetchApi('/tarifas/ciclos', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(this.nuevoCicloData)
          });
          if (res.ok) {
            window.saeApi.toast('exito', 'Ciclo creado exitosamente.');
            this.modalNuevoCiclo = false;
            this.nuevoCicloData = { nombre: '', activo: true };
            await this.cargarCiclosYTarifas(); // Recargar la lista
          } else {
            window.saeApi.toast('error', res.message || 'Error al crear ciclo');
          }
        } catch (e) {
          console.error(e);
          window.saeApi.toast('error', 'Ocurrió un error inesperado.');
        } finally {
          this.cargando = false;
        }
      },
      async cargarCiclosYTarifas() {
        try {
          const res = await window.saeApi.fetchApi('/tarifas/ciclos');
          if (res.ok) {
            this.ciclosDisponibles = res.data;
          }
          const resN = await window.saeApi.fetchApi('/tarifas/niveles');
          if (resN.ok) {
            this.nivelesDisponiblesAPI = resN.data;
          }
        } catch (e) {
          console.error(e);
        }
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
               if (t.concepto === 'colegiatura') this.configTarifas.conceptos.colegiatura = t.monto;
               if (t.concepto === 'inscripcion') this.configTarifas.conceptos.inscripcion = t.monto;
               if (t.concepto === 'arancel') this.configTarifas.conceptos.arancel = t.monto;
               if (t.concepto === 'material') this.configTarifas.conceptos.material = t.monto;
             });
          }
        } catch (e) {
          console.error(e);
        } finally {
          this.cargando = false;
        }
      },
      async guardarTarifas() {
        const confirmacion = confirm("¿Está seguro que desea guardar esta configuración de montos para el ciclo escolar seleccionado?");
        if (!confirmacion) return;

        const conceptosArray = [];
        for (const [key, val] of Object.entries(this.configTarifas.conceptos)) {
          if (!val || Number(val) <= 0) {
            window.saeApi.toast('error', `El monto para ${key} es inválido. Debe ser mayor a 0.`);
            return;
          }
          conceptosArray.push({ concepto: key, monto: Number(val) });
        }

        this.cargando = true;
        try {
          const res = await window.saeApi.fetchApi('/tarifas', {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
               cicloId: this.configTarifas.cicloId,
               nivelId: this.configTarifas.nivelId,
               tarifas: conceptosArray
            })
          });
          if (res.ok) {
            window.saeApi.toast('exito', 'Configuración de tarifas guardada correctamente.');
            await this.cargarTarifas();
          } else {
            window.saeApi.toast('error', res.message || 'Error al guardar las tarifas.');
          }
        } catch (e) {
          console.error(e);
          window.saeApi.toast('error', 'Ocurrió un error inesperado al guardar.');
        } finally {
          this.cargando = false;
        }
      },

      abrirResetPassword(user) {
        this._resetTarget      = { id: user.id, nombre: user.nombre };
        this._resetNuevaPassword = '';
        this.modalResetPassword  = true;
      },
      async confirmarResetPassword() {
        if (!this._resetNuevaPassword || this._resetNuevaPassword.length < 6) {
          window.saeApi.toast('advertencia', 'La contraseña debe tener al menos 6 caracteres.');
          return;
        }
        const res = await window.saeApi.usuarios.resetPassword(this._resetTarget.id, this._resetNuevaPassword);
        this.modalResetPassword = false;
        if (res.ok) {
          // Cargar datos del dashboard si tiene algún permiso financiero/admin
          if (this.tienePermiso('pagos', 'lectura') || this.esGestor()) {
            this._cargarDashboard();
            this.cargarReporteCorte();
            this.cargarReporteIngresos();
            this.cargarReporteDeudores();
          }
          window.saeApi.toast('exito', `Contraseña de "${this._resetTarget.nombre}" restablecida. El usuario deberá cambiarla al iniciar sesión.`);
        } else {
          window.saeApi.toast('error', res.message || 'Error al restablecer la contraseña.');
        }
        this._resetNuevaPassword = '';
      },
      async confirmarEliminarUsuario() {
        const { idx, id, nombre } = this._usuarioAEliminar;
        this.modalConfirmEliminar = false;
        const res = await window.saeApi.usuarios.eliminar(id);
        if (res.ok) {
          this.listaUsuarios.splice(idx, 1);
          window.saeApi.toast('exito', `Usuario "${nombre}" eliminado.`);
        } else {
          window.saeApi.toast('error', res.message || 'Error al eliminar usuario.');
        }
        this._usuarioAEliminar = { idx: null, id: null, nombre: '' };
      },
      async reactivarUsuario(id) {
        const res = await window.saeApi.usuarios.reactivar(id);
        if (res.ok) {
          window.saeApi.toast('exito', `El usuario ha sido reactivado exitosamente.`);
          await this._cargarUsuariosAPI();
          // Update permissions tab if necessary
          if (this.view === 'permisos') {
            await this.cargarPermisos();
            const usr = this.listaUsuariosPermisos.find(u => u.id === id);
            if (usr) await this.seleccionarUsuarioPermisos(usr);
          }
        } else {
          window.saeApi.toast('error', res.message || 'Error al reactivar usuario.');
        }
      },

      // ── PDF (usa datos ya cargados en memoria) ───────────────────────────────
      async generarPDF(tipo) {
        const { jsPDF } = window.jspdf;
        const doc       = new jsPDF();
        doc.setFontSize(16); doc.setTextColor(0, 51, 102);
        doc.text(`Colegio San Diego · Reporte ${tipo}`, 20, 20);
        doc.setFontSize(11); doc.setTextColor(0, 0, 0);
        if (tipo === 'pagos') {
          doc.text('Listado de pagos:', 20, 40);
          this.pagosRegistrados.forEach((p, i) =>
            doc.text(`${p.alumno} — $${p.monto} (${p.fecha})`, 20, 50 + i * 8)
          );
        } else if (tipo === 'alumnos') {
          doc.text('Directorio escolar:', 20, 40);
          this.listaAlumnos.forEach((a, i) =>
            doc.text(`${a.nombre} — ${a.grupo} — ${a.padre}`, 20, 50 + i * 8)
          );
        } else if (tipo === 'becas') {
          doc.text('Becas activas: 15% hermanos, 20% excelencia, 10% temprana', 20, 40);
        }
        doc.save(`reporte_${tipo}.pdf`);
      },
      descargarCicloConfig() {
        window.saeApi.toast('info', 'Configuración del ciclo exportada correctamente.');
      },

      // ── Init ─────────────────────────────────────────────────────────────────
      async init() {
        const safeIcons = () => {
          if (typeof lucide !== 'undefined') lucide.createIcons();
        };

        // Actualizar título de la página según el rol
        document.title = `SAE · Colegio San Diego | ${this.esAdmin() ? 'Administrador' : this.esGestor() ? 'Gestor' : 'Docente'}`;

        // Carga inicial: grupos siempre se necesitan
        const cargasIniciales = [this._cargarGruposAPI()];

        // Alumnos: para ADMIN, GESTOR o cualquier usuario con permiso de alumnos
        if (this.tienePermiso('alumnos', 'lectura')) {
          cargasIniciales.push(this._cargarAlumnosAPI());
        }

        await Promise.all(cargasIniciales);

        // Cargar datos del dashboard si tiene algún permiso financiero/admin
        if (this.tienePermiso('pagos', 'lectura') || this.esGestor()) {
          this._cargarDashboard();
        }

        // Carga lazy por módulo al navegar
        this.$watch('view', async (newView) => {
          this.$nextTick(safeIcons);
          if (newView === 'dashboard' && (this.tienePermiso('pagos', 'lectura') || this.esGestor())) await this._cargarDashboard();
          if (newView === 'pagos'    && this.pagosRegistrados.length === 0) await this._cargarPagosAPI();
          if (newView === 'usuarios' && this.listaUsuarios.length    === 0 && this.esAdmin()) await this._cargarUsuariosAPI();
        });

        this.$watch('grupoExpandido', () => this.$nextTick(safeIcons));
        this.$nextTick(safeIcons);
      },
    }));
  });
