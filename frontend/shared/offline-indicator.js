/**
 * SAE Colegio San Diego — Indicador de conectividad LAN
 *
 * Muestra un indicador discreto (punto de color en el header) cuando el
 * servidor SAE no responde. No usa alertas ni bloquea la UI.
 *
 * Estrategia:
 *   - Sondea GET /health cada 30 segundos
 *   - Si falla → inyecta un chip rojo "Sin servidor" en el DOM
 *   - Si recupera → elimina el chip
 *   - También reacciona a navigator.onLine (pérdida de red del SO)
 *
 * Uso: incluir en <head> DESPUÉS de /config.js y /shared/api.js:
 *   <script src="/shared/offline-indicator.js"></script>
 */

(function () {
  'use strict';

  var CHIP_ID       = 'sae-offline-chip';
  var INTERVALO_MS  = 30000;   // 30 segundos entre sondeos
  var _intervalo    = null;
  var _estaOffline  = false;

  // ── Crear o eliminar el chip de estado ──────────────────────

  function mostrarChip() {
    if (document.getElementById(CHIP_ID)) return;

    var chip = document.createElement('div');
    chip.id  = CHIP_ID;
    chip.style.cssText = [
      'position:fixed', 'top:12px', 'right:16px', 'z-index:9998',
      'display:flex', 'align-items:center', 'gap:6px',
      'background:#FEF2F2', 'border:1px solid #FCA5A5',
      'color:#CC0000', 'font-size:0.75rem', 'font-weight:600',
      'padding:4px 10px', 'border-radius:20px',
      'box-shadow:0 2px 8px rgba(204,0,0,0.15)',
      'pointer-events:none',
    ].join(';');

    var punto = document.createElement('span');
    punto.style.cssText = 'width:7px;height:7px;border-radius:50%;background:#CC0000;animation:sae-parpadeo 1.2s infinite';
    chip.appendChild(punto);
    chip.appendChild(document.createTextNode(' Sin servidor'));
    document.body.appendChild(chip);

    // Animación de parpadeo (solo si no existe ya)
    if (!document.getElementById('sae-offline-style')) {
      var style = document.createElement('style');
      style.id  = 'sae-offline-style';
      style.textContent = '@keyframes sae-parpadeo{0%,100%{opacity:1}50%{opacity:.35}}';
      document.head.appendChild(style);
    }
  }

  function ocultarChip() {
    var chip = document.getElementById(CHIP_ID);
    if (chip) chip.remove();
  }

  // ── Sondeo al endpoint /health ───────────────────────────────

  function verificarConectividad() {
    var base = (window.SAE_CONFIG && window.SAE_CONFIG.API_BASE)
      ? window.SAE_CONFIG.API_BASE.replace('/api/v1', '')
      : '';

    fetch(base + '/health', { method: 'GET', cache: 'no-store' })
      .then(function (res) {
        if (res.ok) {
          if (_estaOffline) {
            _estaOffline = false;
            ocultarChip();
          }
        } else {
          ponerOffline();
        }
      })
      .catch(function () {
        ponerOffline();
      });
  }

  function ponerOffline() {
    if (!_estaOffline) {
      _estaOffline = true;
      mostrarChip();
    }
  }

  // ── Reaccionar a eventos del navegador ───────────────────────

  window.addEventListener('offline', function () {
    ponerOffline();
  });

  window.addEventListener('online', function () {
    // Cuando el SO reporta "online", confirmar con un sondeo real
    verificarConectividad();
  });

  // ── Iniciar cuando el DOM esté listo ─────────────────────────

  function iniciar() {
    verificarConectividad();
    _intervalo = setInterval(verificarConectividad, INTERVALO_MS);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', iniciar);
  } else {
    iniciar();
  }

}());
