/**
 * modules/usuarios.js
 * Usuarios mixin: CRUD usuarios, permisos granulares, reset password
 */
function usuariosMixin() {
  return {
    // ── Estado ───────────────────────────────────────────────────────────────
    listaUsuarios: [],
    busquedaUsuario: '',
    filtroRolUsuario: '',
    nuevoUsuario: { nombre: '', username: '', password: '', rol: '' },

    // ── Permisos ─────────────────────────────────────────────────────────────
    todosModulos: [],
    listaUsuariosPermisos: [],
    usuarioPermisosActivo: null,
    permisosEditando: {},

    // ── Computed ─────────────────────────────────────────────────────────────
    getUsuariosFiltrados() {
      const q = this.busquedaUsuario.toLowerCase();
      const rol = this.filtroRolUsuario.toLowerCase();
      return this.listaUsuarios.filter(u => {
        const matchBusqueda = u.nombre.toLowerCase().includes(q) || (u.username && u.username.toLowerCase().includes(q));
        const matchRol = !rol || u.rol.toLowerCase() === rol;
        return matchBusqueda && matchRol;
      });
    },

    // ── API ──────────────────────────────────────────────────────────────────
    async _cargarUsuariosAPI() {
      const res = await window.saeApi.usuarios.listar(this.verInactivos);
      if (res.ok && res.data) {
        this.listaUsuarios = res.data.map(u => ({ id: u.id, nombre: u.nombre, username: u.username, rol: u.rol, activo: u.activo }));
      }
    },

    // ── CRUD usuarios ────────────────────────────────────────────────────────
    async agregarUsuario() {
      if (!this.nuevoUsuario.nombre || !this.nuevoUsuario.rol || !this.nuevoUsuario.password || !this.nuevoUsuario.username) {
        window.saeApi.toast('advertencia', 'Todos los campos (nombre, usuario, rol y contraseña) son obligatorios.');
        return;
      }
      const rol = window.saeApi.ROL_MAP[this.nuevoUsuario.rol] || 'MAESTRA';
      const res = await window.saeApi.usuarios.crear({ nombre: this.nuevoUsuario.nombre, username: this.nuevoUsuario.username, password: this.nuevoUsuario.password, rol });
      if (res.ok) {
        this.listaUsuarios.push({ id: res.data.id, nombre: res.data.nombre, rol: res.data.rol });
        window.saeApi.toast('exito', `Cuenta para ${res.data.nombre} creada exitosamente con el rol de ${this.nuevoUsuario.rol}.`);
        this.modalUsuario = false;
        this.nuevoUsuario = { nombre: '', username: '', password: '', rol: '' };
      } else {
        window.saeApi.toast('error', res.message || 'Error al crear usuario.');
      }
    },
    eliminarUsuario(idx) {
      const u = this.listaUsuarios[idx];
      if (!u || !u.id) return;
      this._usuarioAEliminar = { idx, id: u.id, nombre: u.nombre };
      this.modalConfirmEliminar = true;
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
        if (this.view === 'permisos') {
          await this.cargarPermisos();
          const usr = this.listaUsuariosPermisos.find(u => u.id === id);
          if (usr) await this.seleccionarUsuarioPermisos(usr);
        }
      } else {
        window.saeApi.toast('error', res.message || 'Error al reactivar usuario.');
      }
    },

    // ── Reset Password ────────────────────────────────────────────────────────
    abrirResetPassword(user) {
      this._resetTarget = { id: user.id, nombre: user.nombre };
      this._resetNuevaPassword = '';
      this.modalResetPassword = true;
    },
    async confirmarResetPassword() {
      if (!this._resetNuevaPassword || this._resetNuevaPassword.length < 6) {
        window.saeApi.toast('advertencia', 'La contraseña debe tener al menos 6 caracteres.');
        return;
      }
      const res = await window.saeApi.usuarios.resetPassword(this._resetTarget.id, this._resetNuevaPassword);
      this.modalResetPassword = false;
      if (res.ok) {
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

    // ── Permisos granulares ──────────────────────────────────────────────────
    async cargarPermisos() {
      if (this.todosModulos.length === 0) {
        const resMod = await window.saeApi.permisos.modulos();
        if (resMod.ok) this.todosModulos = resMod.data;
      }
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
        } else if (u.rol === 'Administrador' || u.rol === 'ADMIN') {
          perms[m] = 'escritura';
        } else { perms[m] = 'NINGUNO'; }
      });
      const res = await window.saeApi.permisos.obtenerUsuario(u.id);
      if (res.ok && res.data && res.data.length > 0) {
        const permsGuardados = {};
        this.todosModulos.forEach(m => permsGuardados[m] = 'NINGUNO');
        res.data.forEach(p => { permsGuardados[p.modulo] = p.nivel; });
        this.permisosEditando = permsGuardados;
      } else {
        this.permisosEditando = perms;
      }
    },
    restaurarPermisosPorDefecto() {
      if (!this.usuarioPermisosActivo) return;
      const u = this.usuarioPermisosActivo;
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
        } else if (u.rol === 'Administrador' || u.rol === 'ADMIN') {
          perms[m] = 'escritura';
        } else { perms[m] = 'NINGUNO'; }
      });
      this.permisosEditando = perms;
    },
    async guardarPermisosUsuario(usuarioId) {
      const permisos = Object.keys(this.permisosEditando).map(mod => ({ modulo: mod, nivel: this.permisosEditando[mod] }));
      const res = await window.saeApi.permisos.actualizar({ usuarioId, permisos });
      if (res.ok) { window.saeApi.toast('exito', 'Permisos actualizados correctamente'); }
      else { window.saeApi.toast('error', res.message || 'Error al guardar permisos'); }
    },
  };
}
