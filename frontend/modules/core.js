/**
 * modules/core.js
 * Core mixin: UI state, role/permissions, init, notifications, saeLogout
 */
function coreMixin() {
  return {
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
    notificaciones: [],
    notificacionesNoLeidas: 0,
    _viewCache: {},

    // ── Rol del usuario ────────────────────────────────────────────────────
    rol: window.saeApi.getUsuario()?.rol || 'MAESTRA',
    permisos: window.saeApi.getUsuario()?.permisos || {},
    esAdmin() { return this.rol === 'ADMIN' || this.rol === 'Administrador'; },
    esGestor() { return this.rol === 'GESTOR' || this.rol === 'Gestor'; },
    esMaestra() { return this.rol === 'MAESTRA' || this.rol === 'Docente'; },
    tieneFinanzas() { return this.esAdmin() || this.esGestor(); },
    tienePermiso(modulo, nivel) {
      if (this.esAdmin()) return true;
      const p = this.permisos[modulo];
      if (!p || p === 'NINGUNO') return false;
      if (nivel === 'lectura') return p === 'lectura' || p === 'escritura';
      if (nivel === 'escritura') return p === 'escritura';
      return false;
    },

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
        bitacora: 'Bitácora del Sistema', permisos: 'Permisos Granulares', historialAcademico: 'Historial Académico'
      };
      return labels[this.view] || this.view;
    },
    get nivelesDisponibles() {
      return ['Preescolar', 'Primaria', 'Secundaria', 'Bachillerato'];
    },

    // ── Notificaciones ───────────────────────────────────────────────────────
    async cargarNotificaciones() {
      if (!window.saeApi || !window.saeApi.getToken()) return;
      try {
        const res = await fetch('/api/v1/notificaciones', {
          headers: { 'Authorization': 'Bearer ' + window.saeApi.getToken() }
        });
        const data = await res.json();
        if (res.ok && data.data) {
          this.notificaciones = data.data.notificaciones || [];
          this.notificacionesNoLeidas = data.data.noLeidas || 0;
        }
      } catch (err) { console.error(err); }
    },
    async marcarNotificacionLeida(id) {
      if (!window.saeApi || !window.saeApi.getToken()) return;
      try {
        await fetch('/api/v1/notificaciones/' + id + '/leida', {
          method: 'PATCH',
          headers: { 'Authorization': 'Bearer ' + window.saeApi.getToken() }
        });
        await this.cargarNotificaciones();
      } catch (err) { console.error(err); }
    },

    // ── Logout ───────────────────────────────────────────────────────────────
    saeLogout() {
      if (window.saeApi) {
        window.saeApi.clearSession();
      }
      window.location.replace('/auth/login.html');
    },

    // ── Init ─────────────────────────────────────────────────────────────────
    async init() {
      // 1. Validar autenticación
      const vc = document.getElementById('view-container');
      if(vc) vc.innerHTML = '<div class="p-6">Iniciando aplicación...</div>';

      const usuarioObj = window.saeApi ? window.saeApi.getUsuario() : null;
      const token = window.saeApi ? window.saeApi.getToken() : null;

      if (!usuarioObj || !token) {
        window.location.href = '/auth/login.html';
        return;
      }

      this.usuarioLogueado = usuarioObj;
      this.userRole = this.usuarioLogueado.rol || '';
      
      try {
        if (this.usuarioLogueado && this.usuarioLogueado.permisos) {
          if (typeof this.usuarioLogueado.permisos === 'string') {
            this.permisos = JSON.parse(this.usuarioLogueado.permisos);
          } else {
            this.permisos = this.usuarioLogueado.permisos;
          }
        }
      } catch (e) {
        this.permisos = {};
      }

      if(vc) vc.innerHTML = '<div class="p-6">Cargando datos iniciales...</div>';

      try {
        // Carga inicial: grupos siempre se necesitan
        const cargasIniciales = [this._cargarGruposAPI()];

        // Alumnos: para ADMIN, GESTOR o cualquier usuario con permiso de alumnos
        if (this.tienePermiso('alumnos', 'lectura')) {
          cargasIniciales.push(this._cargarAlumnosAPI());
        }

        cargasIniciales.push(this.cargarNotificaciones());

        await Promise.all(cargasIniciales);
        if(vc) vc.innerHTML = '<div class="p-6">Datos cargados. Iniciando Dashboard...</div>';
      } catch(err) {
        if(vc) vc.innerHTML = `<div class="p-6 text-red-500">Error en Promise.all: ${err.message}</div>`;
        return;
      }

      setInterval(() => this.cargarNotificaciones(), 60000);

      try {
        // Cargar datos del dashboard si tiene algún permiso financiero/admin
        if (this.tienePermiso('pagos', 'lectura') || this.esGestor()) {
          this._cargarDashboard();
        }
      } catch(err) {
        if(vc) vc.innerHTML = `<div class="p-6 text-red-500">Error cargando dashboard: ${err.message}</div>`;
      }

      try {
        // Carga de la vista inicial
        if(vc) vc.innerHTML = '<div class="p-6">Llamando _loadView...</div>';
        await this._loadView(this.view);
      } catch(err) {
        if(vc) vc.innerHTML = `<div class="p-6 text-red-500">Error en _loadView: ${err.message}</div>`;
      }

      // Carga lazy por módulo al navegar
      this.$watch('view', async (newView) => {
        const safeIcons = () => {
          if (typeof lucide !== 'undefined') lucide.createIcons();
        };
        await this._loadView(newView);
        this.$nextTick(safeIcons);
        if (newView === 'dashboard' && (this.tienePermiso('pagos', 'lectura') || this.esGestor())) await this._cargarDashboard();
        if (newView === 'pagos' && this.pagosRegistrados.length === 0) await this._cargarPagosAPI();
        if (newView === 'usuarios' && this.listaUsuarios.length === 0 && this.esAdmin()) await this._cargarUsuariosAPI();
        if (newView === 'becas' && this.becasAsignadas.length === 0) {
          await this.cargarBecasAsignadas();
          await this.cargarCatalogoBecas();
        }
      });

      this.$watch('grupoExpandido', () => this.$nextTick(safeIcons));
      this.$nextTick(safeIcons);
    },

    // ── Vistas dinámicas ─────────────────────────────────────────────────────
    async _loadView(name) {
      if (!this._viewCache[name]) {
        try {
          const res = await fetch(`/views/${name}.html?v=` + new Date().getTime());
          if (res.ok) {
            this._viewCache[name] = await res.text();
          } else {
            this._viewCache[name] = `<div class="p-6 text-center text-gray-500">Error al cargar la vista: ${name}</div>`;
          }
        } catch (e) {
          this._viewCache[name] = `<div class="p-6 text-center text-red-500">Error de conexión al cargar la vista: ${e.message}</div>`;
        }
      }
      
      const container = document.getElementById('view-container');
      if (container) {
        try {
          container.innerHTML = this._viewCache[name];
          this.$nextTick(() => { 
            try {
              if (window.lucide) window.lucide.createIcons();
            } catch(err) {
              console.error("Lucide error:", err);
            }
          });
        } catch(e) {
          container.innerHTML = `<div class="p-6 text-red-500">Error interno renderizando la vista: ${e.message}</div>`;
        }
      } else {
        alert("CRITICAL ERROR: view-container not found in DOM!");
        console.error("CRITICAL ERROR: view-container not found in DOM!");
      }
    },
  };
}
