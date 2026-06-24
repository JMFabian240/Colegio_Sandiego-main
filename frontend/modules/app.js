/**
 * modules/app.js
 * Alpine.js app bootstrap: merges all mixins into the 'app' component.
 * This file must be loaded LAST, after all other module scripts.
 */
document.addEventListener('alpine:init', () => {
  Alpine.data('app', () => {
    const mixins = [
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
      {}
    ];

    const appState = {};
    mixins.forEach(mixin => {
      Object.defineProperties(appState, Object.getOwnPropertyDescriptors(mixin));
    });
    return appState;
  });
});
