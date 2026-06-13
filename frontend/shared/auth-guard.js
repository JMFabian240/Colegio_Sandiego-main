/**
 * SAE Colegio San Diego — Auth Guard
 *
 * Protege cada panel: si no hay token válido en localStorage, redirige
 * de forma inmediata a /auth/login.html antes de que Alpine.js inicialice.
 *
 * Incluir en el <head> de cada panel, ANTES del script de Alpine.js.
 *
 * Expone: window.saeLogout()
 */

(function () {
  'use strict';

  var TOKEN_KEY   = 'sae_token';
  var USUARIO_KEY = 'sae_usuario';

  function limpiarSesion() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USUARIO_KEY);
  }

  var token = localStorage.getItem(TOKEN_KEY);

  // Sin token → login
  if (!token) {
    window.location.replace('/auth/login.html');
  } else {
    // Verificar expiración del JWT (sin criptografía — el servidor valida la firma)
    try {
      var partes   = token.split('.');
      var payload  = JSON.parse(atob(partes[1]));
      var ahora    = Math.floor(Date.now() / 1000);

      if (payload.exp && ahora > payload.exp) {
        limpiarSesion();
        window.location.replace('/auth/login.html');
      }
    } catch (e) {
      // Token malformado
      limpiarSesion();
      window.location.replace('/auth/login.html');
    }
  }

  // Helper de logout global — disponible desde cualquier panel
  window.saeLogout = async function () {
    var currentToken = localStorage.getItem(TOKEN_KEY);
    if (currentToken) {
      try {
        var base = (window.SAE_CONFIG && window.SAE_CONFIG.API_BASE) ? window.SAE_CONFIG.API_BASE : window.location.origin + '/api/v1';
        await fetch(base + '/auth/logout', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ' + currentToken
          }
        });
      } catch (e) {
        console.error('Error al hacer logout en el backend', e);
      }
    }
    limpiarSesion();
    window.location.replace('/auth/login.html');
  };

}());
