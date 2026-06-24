/**
 * modules/app.js
 * Alpine.js app bootstrap: merges all mixins into the 'app' component.
 * This file must be loaded LAST, after all other module scripts.
 */
document.addEventListener('alpine:init', () => {
  Alpine.data('app', () => {
    return Object.assign(
      {},
      coreMixin(),
      dashboardMixin(),
      alumnosMixin(),
      tutoresMixin(),
      pagosMixin(),
      becasMixin(),
      calificacionesMixin(),
      gruposMixin(),
      usuariosMixin(),
      cicloMixin(),
      reportesMixin(),
      bitacoraMixin(),
      historialMixin(),
      boletaMixin(),
      {
        // ── Override init to call the coreMixin init ───────────────────────
        // Alpine will call this automatically on component mount.
        // coreMixin.init() already has the full init logic.
      }
    );
  });
});
