/**
 * SAE Colegio San Diego — Cliente API Compartido
 *
 * Responsabilidad única: proveer acceso tipado y centralizado a todos los
 * endpoints del backend. Ningún panel debe hacer fetch() directamente.
 *
 * Expone: window.saeApi
 *
 * Dependencia: window.SAE_CONFIG (inyectado por /config.js antes de este script)
 * Dependencia: window.saeLogout  (inyectado por auth-guard.js)
 */

(function (global) {
  'use strict';

  // ── Base URL ────────────────────────────────────────────────────────────────
  function getBase() {
    if (global.SAE_CONFIG && global.SAE_CONFIG.API_BASE) {
      return global.SAE_CONFIG.API_BASE;
    }
    return global.location.origin + '/api/v1';
  }

  // ── Token / Sesión ──────────────────────────────────────────────────────────
  var TOKEN_KEY    = 'sae_token';
  var USUARIO_KEY  = 'sae_usuario';
  var _refreshing  = false;   // semáforo: evita múltiples refresh simultáneos

  function getToken()          { return localStorage.getItem(TOKEN_KEY); }
  function setToken(t)         { localStorage.setItem(TOKEN_KEY, t); }
  function clearSession()      { localStorage.removeItem(TOKEN_KEY); localStorage.removeItem(USUARIO_KEY); }
  function getUsuario()        { try { return JSON.parse(localStorage.getItem(USUARIO_KEY)); } catch (e) { return null; } }
  function setUsuario(u)       { localStorage.setItem(USUARIO_KEY, JSON.stringify(u)); }

  /**
   * Retorna true si el token JWT expira en menos de `minutosUmbral` minutos.
   * Retorna false si no hay token o si el formato es inválido.
   */
  function tokenProximoAExpirar(minutosUmbral) {
    var token = getToken();
    if (!token) return false;
    try {
      var payload = JSON.parse(atob(token.split('.')[1]));
      if (!payload.exp) return false;
      var segundosRestantes = payload.exp - Math.floor(Date.now() / 1000);
      return segundosRestantes < minutosUmbral * 60;
    } catch (e) { return false; }
  }

  /**
   * Intenta renovar el token silenciosamente.
   * Retorna true si tuvo éxito, false si falló.
   */
  async function intentarRefresh() {
    if (_refreshing) return false;
    _refreshing = true;
    try {
      var token = getToken();
      if (!token) return false;
      var res = await fetch(getBase() + '/auth/refresh', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token },
      });
      if (!res.ok) return false;
      var data = await res.json();
      if (data.ok && data.data && data.data.token) {
        setToken(data.data.token);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      _refreshing = false;
    }
  }

  // ── Fetch con autenticación automática y refresh silencioso ─────────────────
  async function request(method, endpoint, body) {
    // Renovación proactiva: si el token expira en < 15 min, refrescar antes de la petición
    if (tokenProximoAExpirar(15) && endpoint !== '/auth/refresh') {
      await intentarRefresh();
    }

    var headers = { 'Content-Type': 'application/json' };
    var token   = getToken();
    if (token) headers['Authorization'] = 'Bearer ' + token;

    var opts = { method: method, headers: headers, cache: 'no-cache' };
    if (body !== undefined && body !== null) {
      opts.body = JSON.stringify(body);
    }

    var res;
    try {
      res = await fetch(getBase() + endpoint, opts);
    } catch (networkErr) {
      return { ok: false, offline: true, message: 'Sin conexión al servidor SAE. Verifica la red.' };
    }

    // Si recibimos 401 y no estamos ya en el endpoint de refresh, intentar refresh reactivo
    if (res.status === 401 && endpoint !== '/auth/refresh') {
      var refreshOk = await intentarRefresh();
      if (refreshOk) {
        // Reintentar la petición original con el nuevo token
        headers['Authorization'] = 'Bearer ' + getToken();
        try {
          res = await fetch(getBase() + endpoint, { method: method, headers: headers, body: opts.body });
        } catch (e) {
          return { ok: false, offline: true, message: 'Sin conexión al servidor SAE.' };
        }
      }
      // Si el segundo intento también da 401 (o el refresh falló) → redirect login
      if (res.status === 401) {
        clearSession();
        global.location.replace('/auth/login.html');
        return { ok: false, message: 'Sesión expirada. Redirigiendo al login...' };
      }
    }

    var data;
    try {
      data = await res.json();
    } catch (e) {
      data = { ok: false, message: 'Respuesta inválida del servidor.' };
    }
    return data;
  }

  // ── Módulo: Auth ────────────────────────────────────────────────────────────
  var auth = {
    login: function (creds) { return request('POST', '/auth/login', creds); },
    me:    function ()      { return request('GET',  '/auth/me'); },
  };

  // ── Módulo: Alumnos ─────────────────────────────────────────────────────────
  var alumnos = {
    /**
     * listar(filtros?)
     * filtros puede ser:
     *   - undefined          → GET /alumnos  (sin filtros)
     *   - string             → GET /alumnos?q=... (backward compat)
     *   - { q, grupoId, nivel, estado, page, limit }  → con paginación opt-in
     */
    listar: function (filtros) {
      var params = new URLSearchParams();
      if (typeof filtros === 'string' && filtros) {
        params.set('q', filtros);
      } else if (filtros && typeof filtros === 'object') {
        if (filtros.q)       params.set('q',       filtros.q);
        if (filtros.grupoId) params.set('grupoId', filtros.grupoId);
        if (filtros.nivel)   params.set('nivel',   filtros.nivel);
        if (filtros.estado)  params.set('estado',  filtros.estado);
        if (filtros.page)    params.set('page',    filtros.page);
        if (filtros.limit)   params.set('limit',   filtros.limit);
      }
      var qs = params.toString();
      return request('GET', '/alumnos' + (qs ? '?' + qs : ''));
    },
    obtener:    function (id)       { return request('GET',    '/alumnos/' + id); },
    crear:      function (datos)    { return request('POST',   '/alumnos', datos); },
    actualizar: function (id, data) { return request('PUT',    '/alumnos/' + id, data); },
    eliminar:   function (id)       { return request('DELETE', '/alumnos/' + id); },
    promedio:   function (id, opts) {
      var params = new URLSearchParams();
      if (opts && opts.periodoId) params.set('periodoId', opts.periodoId);
      if (opts && opts.periodo)   params.set('periodo',   opts.periodo);
      var qs = params.toString();
      return request('GET', '/calificaciones/promedio/' + id + (qs ? '?' + qs : ''));
    },
  };

  // ── Módulo: Tutores ─────────────────────────────────────────────────────────
  var tutores = {
    listar: function(filtros) {
      var params = new URLSearchParams();
      if (filtros && typeof filtros === 'object') {
        if (filtros.q) params.set('q', filtros.q);
        if (filtros.page) params.set('page', filtros.page);
        if (filtros.limit) params.set('limit', filtros.limit);
      }
      var qs = params.toString();
      return request('GET', '/tutores' + (qs ? '?' + qs : ''));
    },
    obtener:    function (id)       { return request('GET',    '/tutores/' + id); },
    crear:      function (datos)    { return request('POST',   '/tutores', datos); },
    actualizar: function (id, data) { return request('PUT',    '/tutores/' + id, data); },
    eliminar:   function (id)       { return request('DELETE', '/tutores/' + id); },
    vincular:   function (id, data) { return request('POST',   '/tutores/' + id + '/vincular', data); },
    desvincular:function (id, alumnoId) { return request('DELETE', '/tutores/' + id + '/desvincular/' + alumnoId); },
  };

  // ── Módulo: Pagos ───────────────────────────────────────────────────────────
  var pagos = {
    listar: function (filtros) {
      var params = new URLSearchParams();
      if (filtros) {
        if (filtros.alumnoId) params.set('alumnoId', filtros.alumnoId);
        if (filtros.concepto) params.set('concepto', filtros.concepto);
        if (filtros.fechaDesde) params.set('fechaDesde', filtros.fechaDesde);
        if (filtros.fechaHasta) params.set('fechaHasta', filtros.fechaHasta);
      }
      var qs = params.toString();
      return request('GET', '/pagos' + (qs ? '?' + qs : ''));
    },
    obtener:   function (id)    { return request('GET',  '/pagos/' + id); },
    registrar: function (datos) { return request('POST', '/pagos', datos); },
    adelantado: function (datos) { return request('POST', '/pagos/adelantado', datos); },
    modificarRecargo: function (id, datos) { return request('PATCH', '/pagos/recargos/' + id, datos); },
    calendario: function(filtros) {
      var params = new URLSearchParams();
      if (filtros) {
        if (filtros.alumnoId) params.set('alumnoId', filtros.alumnoId);
        if (filtros.cicloId) params.set('cicloId', filtros.cicloId);
        if (filtros.estadoCobro) params.set('estadoCobro', filtros.estadoCobro);
      }
      var qs = params.toString();
      return request('GET', '/pagos/calendario' + (qs ? '?' + qs : ''));
    },
    subirComprobante: async function(pagoId, file) {
      if (tokenProximoAExpirar(15)) await intentarRefresh();
      var formData = new FormData();
      formData.append('comprobante', file);
      try {
        var token = getToken();
        var res = await fetch(getBase() + '/pagos/' + pagoId + '/comprobante', {
          method: 'POST',
          headers: { 'Authorization': 'Bearer ' + token },
          body: formData
        });
        return await res.json();
      } catch(e) {
        return { ok: false, message: 'Error de red al subir comprobante.' };
      }
    },
    descargarComprobante: function(pagoId) {
      return getBase() + '/pagos/' + pagoId + '/comprobante?token=' + getToken();
    }
  };

  // ── Módulo: Becas ───────────────────────────────────────────────────────────
  var becas = {
    listar:            function ()          { return request('GET',    '/becas'); },
    listarSolicitudes: function ()          { return request('GET',    '/becas/solicitudes'); },
    solicitar:         function (datos)     { return request('POST',   '/becas/solicitudes', datos); },
    resolver:          function (id, datos) { return request('PATCH',  '/becas/solicitudes/' + id + '/resolver', datos); },
    desactivar:        function (id)        { return request('DELETE', '/becas/' + id); },
    asignar:           function (datos)     { return request('POST',   '/becas/asignar', datos); },
    retirar:           function (id, datos) { return request('POST',   '/becas/asignaciones/' + id + '/retirar', datos); },
    catalogo: {
      listar:     function ()          { return request('GET',    '/becas/catalogo'); },
      crear:      function (datos)     { return request('POST',   '/becas/catalogo', datos); },
      actualizar: function (id, datos) { return request('PATCH',  '/becas/catalogo/' + id, datos); },
      eliminar:   function (id)        { return request('DELETE', '/becas/catalogo/' + id); },
    }
  };

  // ── Módulo: Calificaciones ──────────────────────────────────────────────────
  var calificaciones = {
    listar: function (filtros) {
      var params = new URLSearchParams();
      if (filtros) {
        if (filtros.alumnoId)       params.set('alumnoId', filtros.alumnoId);
        if (filtros.grupoId)        params.set('grupoId', filtros.grupoId);
        if (filtros.grupoMateriaId) params.set('grupoMateriaId', filtros.grupoMateriaId);
        if (filtros.periodo)        params.set('periodo', filtros.periodo);
      }
      var qs = params.toString();
      return request('GET', '/calificaciones' + (qs ? '?' + qs : ''));
    },
    porAlumno: function (alumnoId, periodo) {
      var qs = periodo ? '?periodo=' + periodo : '';
      return request('GET', '/calificaciones/alumno/' + alumnoId + qs);
    },
    guardar:     function (datos)  { return request('POST', '/calificaciones', datos); },
    guardarLote: function (lista)  { return request('POST', '/calificaciones/lote', { calificaciones: lista }); },
  };

  // ── Módulo: Grupos ──────────────────────────────────────────────────────────
  var grupos = {
    listar:     function (nivel)       { return request('GET',  '/grupos' + (nivel ? '?nivel=' + nivel : '')); },
    obtener:    function (id)          { return request('GET',  '/grupos/' + id); },
    crear:      function (datos)       { return request('POST', '/grupos', datos); },
    actualizar: function (id, datos)   { return request('PUT',  '/grupos/' + id, datos); },
    eliminar:   function (id)          { return request('DELETE', '/grupos/' + id); },
  };

  // ── Módulo: Usuarios (Solo ADMIN) ───────────────────────────────────────────
  var usuarios = {
    listar: function(incluirInactivos = false) {
      return request('GET', '/usuarios' + (incluirInactivos ? '?incluirInactivos=true' : ''));
    },
    obtener:         function (id)          { return request('GET',    '/usuarios/' + id); },
    crear: function(datos) {
      return request('POST', '/usuarios', datos);
    },
    actualizar:      function (id, datos)   { return request('PUT',    '/usuarios/' + id, datos); },
    eliminar: function(id) {
      return request('DELETE', '/usuarios/' + id);
    },
    reactivar: function(id) {
      return request('PUT', '/usuarios/' + id + '/reactivar');
    },
    resetPassword: function(id, nuevaPassword) {
      return request('PATCH', '/auth/usuarios/' + id + '/reset-password', { nuevaPassword });
    },
  };

  // ── Módulo: Bitácora ────────────────────────────────────────────────────────
  var bitacora = {
    listar: function(page, limit) {
      var qs = '?pagina=' + (page || 1) + '&limite=' + (limit || 50);
      return request('GET', '/bitacora' + qs);
    },
    exportarURL: function(formato) {
      var token = getToken();
      return getBase() + '/bitacora/exportar?formato=' + (formato || 'pdf') + '&token=' + token;
    }
  };

  // ── Módulo: Permisos ────────────────────────────────────────────────────────
  var permisos = {
    modulos: function() { return request('GET', '/permisos/modulos'); },
    obtenerUsuario: function(usuarioId) { return request('GET', '/permisos/usuarios/' + usuarioId); },
    actualizar: function(datos) { return request('PUT', '/permisos/usuarios/' + datos.usuarioId, datos); }
  };

  // ── Módulo: Configuración ───────────────────────────────────────────────────
  var configuracion = {
    listar: function() { return request('GET', '/configuracion'); },
    actualizar: function(configs) { return request('PUT', '/configuracion', { configs: configs }); },
  };

  // ── Módulo: Reportes ────────────────────────────────────────────────────────
  var reportes = {
    corteCaja: function() { return request('GET', '/reportes/corte-caja'); },
    ingresosMensuales: function(cicloId) { return request('GET', '/reportes/ingresos-mensuales' + (cicloId ? '?cicloId=' + cicloId : '')); },
    deudores: function() { return request('GET', '/reportes/deudores'); },
    facturables: function() { return request('GET', '/reportes/facturables'); },
  };

  // ── fetchApi: acceso directo a endpoints con auth ───────────────────────────
  async function fetchApi(endpoint, opts) {
    if (tokenProximoAExpirar(15) && endpoint !== '/auth/refresh') {
      await intentarRefresh();
    }
    var headers = opts && opts.headers ? opts.headers : {};
    if (!headers['Content-Type'] && !(opts && opts.body instanceof FormData)) {
      headers['Content-Type'] = 'application/json';
    }
    var token = getToken();
    if (token) headers['Authorization'] = 'Bearer ' + token;
    var fetchOpts = Object.assign({}, opts || {}, { headers: headers });
    var res = await fetch(getBase() + endpoint, fetchOpts);
    if (res.status === 401) {
      clearSession();
      global.location.replace('/auth/login.html');
      return null;
    }
    return res.json();
  }

  // ── Mappers: API → formato frontend ────────────────────────────────────────

  /**
   * Adapta un alumno de la API al formato esperado por los templates Alpine.
   * Extrae grupo.nombre como string y primer padre como campos planos.
   */
  function mapAlumno(a) {
    var primerPadre = (a.padres && a.padres.length > 0) ? a.padres[0] : null;
    var nivelStr = a.nivel || (a.grupo ? a.grupo.nivel : null);
    var gradoStr = (a.grupo && a.grupo.grado) ? a.grupo.grado.toString() : null;
    var seccionStr = a.grupo ? a.grupo.seccion : null;
    return {
      id:               a.id || a.alumnoId,
      grupoId:          a.grupoId,
      nombre:           a.nombre || a.nombreCompleto,
      matricula:        a.matricula,
      curp:             a.curp || '',
      activo:           a.activo,
      estado:           a.estado,
      nivel:            nivelStr,
      grado:            gradoStr,
      seccion:          seccionStr,
      fechaNacimiento:  a.fechaNacimiento,
      sexo:             a.sexo,
      diaLimitePago:    a.diaLimitePago,
      observaciones:    a.observaciones,
      personasAutorizadas: a.personasAutorizadas,
      grupo:            a.grupo ? a.grupo.nombre : 'Sin grupo asignado',
      padre:            primerPadre ? primerPadre.nombre : 'No registrado',
      telefono:         primerPadre ? (primerPadre.telefono || 'N/D') : 'N/D',
      email:            primerPadre ? (primerPadre.email || '') : '',
      autorizados:      a.autorizadosRecoger || 'Padres o tutores registrados',
      correoFacturacion:a.correoFacturacion || '',
      rfc:              a.rfc || '',
      regimenFiscal:    a.regimenFiscal || '',
      // Datos financieros para dashboard y deudores
      estadoPago:       a.estadoPago  || null,
      mesesAdeudo:      a.mesesAdeudo || 0,
    };
  }

  /**
   * Adapta un grupo de la API al formato esperado (incluye _count.alumnos).
   */
  function mapGrupo(g) {
    return {
      id:      g.id,
      nombre:  g.nombre,
      nivel:   g.nivel,
      grado:   g.grado,
      seccion: g.seccion,
      titular: g.titular,
      activo:  g.activo,
      alumnos: (g._count && g._count.alumnos) ? g._count.alumnos : 0,
      materias: g.materias || [],
    };
  }

  /**
   * Adapta un pago de la API al formato plano del frontend.
   * fecha viene como ISO string — extrae solo YYYY-MM-DD.
   */
  function mapPago(p) {
    return {
      id:       p.id,
      alumno:   p.alumno ? p.alumno.nombre : '—',
      alumnoId: p.alumnoId,
      concepto: p.concepto,
      fecha:    p.fecha ? p.fecha.slice(0, 10) : '',
      monto:    p.monto,
      recargo:  p.tieneRecargo,
      metodoPago: p.metodoPago || '',
      documentos: p.documentos || [],
    };
  }

  // ── Constantes de mapeo UI → API ────────────────────────────────────────────

  var CONCEPTO_MAP = {
    'Colegiatura':         'COLEGIATURA',
    'Inscripción':         'INSCRIPCION',
    'Material didáctico':  'MATERIAL_DIDACTICO',
    'Uniforme':            'UNIFORME',
    'Otro':                'OTRO',
  };

  var PERIODO_MAP = {
    'Trimestre 1': 'TRIMESTRE_1',
    'Trimestre 2': 'TRIMESTRE_2',
    'Trimestre 3': 'TRIMESTRE_3',
  };

  var TIPO_BECA_MAP = {
    'Beca por hermanos (15%)':    'HERMANOS',
    'Excelencia académica (20%)': 'EXCELENCIA',
    'Inscripción temprana (10%)': 'INSCRIPCION_TEMPRANA',
  };

  var ROL_MAP = {
    'Administrador':           'ADMIN',
    'Gestor administrativo':   'GESTOR',
    'Docente':                 'MAESTRA',
    'Estándar (Maestra)':      'MAESTRA',
    'Gestor':                  'GESTOR',
  };

  // ── Toast UI (no requiere cambios en HTML) ──────────────────────────────────
  function toast(tipo, msg) {
    var colores = {
      exito:       '#059669',
      error:       '#CC0000',
      advertencia: '#D97706',
      info:        '#003366',
    };
    var el = document.createElement('div');
    el.style.cssText = [
      'position:fixed', 'bottom:1.5rem', 'left:1.5rem', 'z-index:9999',
      'padding:0.8rem 1.25rem', 'border-radius:0.75rem',
      'font-size:0.875rem', 'font-weight:500', 'color:white',
      'max-width:340px', 'box-shadow:0 4px 16px rgba(0,0,0,0.18)',
      'transition:opacity 0.3s',
      'background:' + (colores[tipo] || colores.info),
    ].join(';');
    el.textContent = msg;
    document.body.appendChild(el);
    setTimeout(function () {
      el.style.opacity = '0';
      setTimeout(function () { el.remove(); }, 300);
    }, 4000);
  }

  // ── Exposición global ────────────────────────────────────────────────────────
  global.saeApi = {
    // Sesión
    getToken: getToken, setToken: setToken, clearSession: clearSession,
    getUsuario: getUsuario, setUsuario: setUsuario,
    // Módulos
    auth: auth, alumnos: alumnos, tutores: tutores, pagos: pagos, becas: becas,
    calificaciones: calificaciones, grupos: grupos, usuarios: usuarios,
    bitacora: bitacora, permisos: permisos, configuracion: configuracion,
    reportes: reportes,
    // Fetch directo
    fetchApi: fetchApi,
    // Mappers
    mapAlumno: mapAlumno, mapGrupo: mapGrupo, mapPago: mapPago,
    // Constantes
    CONCEPTO_MAP: CONCEPTO_MAP, PERIODO_MAP: PERIODO_MAP,
    TIPO_BECA_MAP: TIPO_BECA_MAP, ROL_MAP: ROL_MAP,
    // UI
    toast: toast,
  };

}(window));
