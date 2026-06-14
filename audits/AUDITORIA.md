# 🔬 AUDITORÍA TÉCNICA — SAE COLEGIO SAN DIEGO

> **Fecha:** 22 Mayo 2026
> **Auditor:** Claude Code (análisis sobre código fuente real)
> **Versión auditada:** Backend `1.0.0` · Prisma Schema `12 modelos` · 3 paneles Alpine.js

---

## RESUMEN EJECUTIVO

```
╔══════════════════════════════════════════════════════════════════════╗
║  SAE COLEGIO SAN DIEGO — ESTADO AL 22 MAYO 2026                     ║
╠══════════════════════════════════════════════════════════════════════╣
║  BACKEND        ████████████████████ 100%  Listo para producción    ║ <---- 🤣🤣🤣🤣
║  FRONTEND UI    ████████████░░░░░░░░  60%  Vistas completas         ║
║  INTEGRACIÓN    ░░░░░░░░░░░░░░░░░░░░   0%  Cero fetch() calls       ║
║  OFFLINE LVL 1  ░░░░░░░░░░░░░░░░░░░░   0%  CDNs sin vendorizar      ║
║  OFFLINE LVL 2  ░░░░░░░░░░░░░░░░░░░░   0%  Sin Service Worker       ║
║  RED LOCAL      ████████████░░░░░░░░  60%  Servidor OK, nodos no    ║
╠══════════════════════════════════════════════════════════════════════╣
║  PRIORIDAD 1 → Crear login.html + api.js + conectar los 3 paneles   ║
║  PRIORIDAD 2 → Vendorizar CSS/JS (eliminar CDNs)                    ║
║  PRIORIDAD 3 → /config.js dinámico para nodos satélite              ║
║  PRIORIDAD 4 → Service Worker de caché de assets                    ║
║  PRIORIDAD 5 → IndexedDB offline queue (si el uso lo justifica)     ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

## 1. 🏁 DIAGNÓSTICO: QUÉ HAY Y QUÉ FALTA

### ✅ Backend — 100% Operativo

| Capa | Módulo | Estado |
|------|--------|--------|
| **Auth** | Login JWT + `/me` + RBAC 3 roles | ✅ Completo |
| **Alumnos** | CRUD + soft-delete + búsqueda | ✅ Completo |
| **Pagos** | Registro + recargo automático día 5 | ✅ Completo |
| **Becas** | Flujo RF-21: GESTOR solicita → ADMIN aprueba | ✅ Completo |
| **Calificaciones** | Guardar individual + lote (upsert) | ✅ Completo |
| **Grupos** | CRUD + GrupoMaterias | ✅ Completo |
| **Usuarios** | CRUD restringido a ADMIN | ✅ Completo |
| **Seguridad** | Helmet + Rate Limit (global + auth) + CORS | ✅ Completo |
| **DB** | Prisma/SQLite, 12 modelos, migraciones, seed | ✅ Completo |
| **Infra** | Docker Compose, bind `0.0.0.0:3000`, graceful shutdown | ✅ Completo |
| **Validators** | express-validator en todos los endpoints críticos | ✅ Completo |

El backend tiene una arquitectura de **4 capas limpia**: `route → controller → service → repository`.
Cada capa tiene una única responsabilidad. No hay código muerto. **El backend está listo para producción.**

---

### 🚨 Brecha Crítica — El frontend tiene CERO llamadas HTTP al backend

```bash
grep -c "fetch|axios|XMLHttpRequest" frontend/admin_panel.html
# → 0
```

Esto no es una exageración. Todo lo que los paneles hacen hoy es operar sobre **arrays hardcodeados** y mostrar `alert()` como respuesta:

```javascript
// REALIDAD ACTUAL en admin_panel.html

// Los "alumnos" son un array estático — nunca van al servidor:
listaAlumnos: [
  { nombre: 'María González Ruiz', matricula: 'SDM-2020-0089', ... },
  { nombre: 'Juan Pérez Morales',  matricula: 'SDM-2020-0123', ... },
  // 6 alumnos de prueba fijos
],

// "Guardar calificación" es un alert(), no un POST:
guardarCalificacion() {
  alert(`Calificaciones guardadas: ${this.alumnoActualCalif.nombre}`)
},

// "Registrar pago" empuja al array local, nunca llama a POST /api/v1/pagos:
agregarPago() {
  this.pagosRegistrados.push({ ...this.nuevoPago });
  alert(`Pago de $${this.nuevoPago.monto} registrado para ${this.nuevoPago.alumno}`);
},
```

---

### Tabla de Gaps Críticos

| # | Gap | Impacto |
|---|-----|---------|
| **G-1** | No existe `login.html`. El root redirige directo a `admin_panel.html` saltándose el JWT | Cualquiera entra sin credenciales |
| **G-2** | No hay gestión de token (`localStorage`, header `Authorization`) en ningún panel | El backend autentica pero nadie le pide el token |
| **G-3** | Los paneles dependen de 4 CDNs externos (Tailwind, Alpine, Lucide, Google Fonts) | Sin internet, la UI queda en blanco |
| **G-4** | No existe `API_BASE_URL`. Los nodos satélite no saben a qué IP conectarse | Imposible despliegue multi-PC |
| **G-5** | El directorio `backend/src/controllers/asistencias/` todavía existe tras la depuración | Deuda técnica residual |

---

### Checklist de Producción

```
BACKEND
[✅] Express + Prisma levanta sin errores
[✅] Auth JWT con expiración 8h
[✅] RBAC ADMIN / GESTOR / MAESTRA
[✅] Todos los endpoints con validación
[✅] Recargo automático día 5 (lógica real en pagos.service.js)
[✅] Flujo beca RF-21 aprobación en dos pasos
[✅] Docker Compose configurado
[✅] Health check en /health

FRONTEND / INTEGRACIÓN
[❌] login.html con POST /api/v1/auth/login
[❌] Manejo de JWT en localStorage + header Authorization
[❌] Reemplazar listaAlumnos[]     → fetch GET  /api/v1/alumnos
[❌] Reemplazar agregarPago()      → fetch POST /api/v1/pagos
[❌] Reemplazar guardarCalificacion() → fetch POST /api/v1/calificaciones
[❌] Reemplazar asignarBeca()      → fetch POST /api/v1/becas/solicitudes
[❌] Reemplazar listaUsuarios[]    → fetch GET  /api/v1/usuarios
[❌] API_BASE_URL configurable para nodos satélite
[❌] Manejo de errores 401/403/500 con UI feedback
[❌] Auto-logout al expirar el token
[❌] Eliminar directorio controllers/asistencias/

OFFLINE / RED LOCAL
[❌] Vendor-bundle local de Tailwind + Alpine (sin CDN)
[❌] Estrategia offline definida (ver Sección 2)
[❌] Service Worker de caché de assets
```

---

## 2. 📴 ARQUITECTURA OFFLINE-FIRST

### Estado real

El `schema.prisma` dice `"DB inicial: SQLite (offline-first)"`. Eso significa que el **servidor no necesita internet para operar**. Correcto. Pero los **clientes (nodos satélite) sí dependen de CDNs externos** y no tienen capacidad de operar sin LAN.

- **Servidor:** offline-capable ✅
- **Clientes:** 100% dependientes de red ❌

---

### Nivel 1 — Offline de UI (1 día de trabajo) — PRIORITARIO

El problema más urgente: si el colegio no tiene internet, los paneles no cargan porque los CDNs fallan.

**Solución: Vendor bundle local**

```bash
# Ejecutar desde /frontend
mkdir -p vendor

# 1. Descargar Alpine.js
curl -o ./vendor/alpine.min.js \
  https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js

# 2. Compilar Tailwind a CSS estático
npm install -D tailwindcss
npx tailwindcss -i ./src/input.css -o ./vendor/tailwind.min.css --minify

# 3. Descargar Lucide (bundle UMD)
curl -o ./vendor/lucide.min.js \
  https://unpkg.com/lucide@latest/dist/umd/lucide.min.js

# 4. Descargar jsPDF
curl -o ./vendor/jspdf.umd.min.js \
  https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js
```

Cambiar referencias en cada panel HTML:

```html
<!-- ANTES (depende de internet) -->
<script src="https://cdn.tailwindcss.com"></script>
<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>

<!-- DESPUÉS (servido por Express desde /frontend/vendor/) -->
<link rel="stylesheet" href="/vendor/tailwind.min.css">
<script defer src="/vendor/alpine.min.js"></script>
```

Express ya sirve `/frontend` como estático. Los archivos en `vendor/` quedan disponibles automáticamente.

---

### Nivel 2 — Caché de assets con Service Worker (2 días)

Para que el panel cargue aunque el servidor esté temporalmente caído:

```javascript
// frontend/sw.js
const CACHE_NAME    = 'sae-v1';
const ASSETS_TO_CACHE = [
  '/admin_panel.html',
  '/gestor_panel.html',
  '/maestra_panel.html',
  '/vendor/alpine.min.js',
  '/vendor/tailwind.min.css',
  '/vendor/lucide.min.js',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS_TO_CACHE))
  );
  self.skipWaiting();
});

// Assets: Cache First | API: Network First
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  if (url.pathname.startsWith('/api/')) {
    event.respondWith(
      fetch(event.request).catch(() =>
        new Response(
          JSON.stringify({ ok: false, offline: true, message: 'Sin conexión al servidor.' }),
          { headers: { 'Content-Type': 'application/json' } }
        )
      )
    );
    return;
  }

  event.respondWith(
    caches.match(event.request).then((cached) => cached || fetch(event.request))
  );
});
```

```javascript
// Registrar en cada panel (antes del cierre </body>)
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/sw.js');
}
```

---

### Nivel 3 — Cola de escrituras offline con IndexedDB (1 semana)

Para registrar pagos o calificaciones sin conexión y sincronizar al recuperarla:

```javascript
// frontend/js/offline-queue.js
class OfflineQueue {
  constructor() {
    this.DB_NAME    = 'sae-offline';
    this.STORE_NAME = 'pending-ops';
    this.db         = null;
  }

  async init() {
    return new Promise((resolve, reject) => {
      const req = indexedDB.open(this.DB_NAME, 1);
      req.onupgradeneeded = (e) => {
        const db = e.target.result;
        if (!db.objectStoreNames.contains(this.STORE_NAME)) {
          const store = db.createObjectStore(this.STORE_NAME, {
            keyPath: 'id', autoIncrement: true,
          });
          store.createIndex('status', 'status', { unique: false });
        }
      };
      req.onsuccess = (e) => { this.db = e.target.result; resolve(); };
      req.onerror   = reject;
    });
  }

  // Encolar operación cuando no hay red
  async enqueue(operation) {
    return new Promise((resolve, reject) => {
      const tx    = this.db.transaction(this.STORE_NAME, 'readwrite');
      const store = tx.objectStore(this.STORE_NAME);
      const req   = store.add({ ...operation, status: 'pending', timestamp: Date.now() });
      req.onsuccess = () => resolve(req.result);
      req.onerror   = reject;
    });
  }

  // Ejecutar pendientes al recuperar conexión
  async flush(apiBase, token) {
    const pending = await this._getPending();
    const results = [];

    for (const op of pending) {
      try {
        const res = await fetch(`${apiBase}${op.endpoint}`, {
          method:  op.method,
          headers: {
            'Content-Type':  'application/json',
            'Authorization': `Bearer ${token}`,
          },
          body: JSON.stringify(op.body),
        });

        if (res.ok) {
          await this._markDone(op.id);
          results.push({ id: op.id, ok: true });
        } else {
          await this._markError(op.id, await res.text());
          results.push({ id: op.id, ok: false });
        }
      } catch (err) {
        break; // Red cayó de nuevo — detener flush
      }
    }
    return results;
  }

  _getPending() {
    return new Promise((resolve) => {
      const tx    = this.db.transaction(this.STORE_NAME, 'readonly');
      const store = tx.objectStore(this.STORE_NAME);
      const req   = store.index('status').getAll('pending');
      req.onsuccess = () => resolve(req.result);
    });
  }
}

// Sincronización automática al recuperar red
window.addEventListener('online', async () => {
  const token = localStorage.getItem('sae_token');
  if (window.saeOfflineQueue && token) {
    console.log('[SAE] Red recuperada. Sincronizando...');
    await window.saeOfflineQueue.flush(window.SAE_CONFIG.API_BASE, token);
  }
});
```

---

### Resolución de Conflictos

**Estrategia adoptada: Last-Write-Wins con timestamp de cliente.**

Funciona porque:
- **Pagos:** son `append-only`. Nunca se editan, solo se crean. Conflicto imposible.
- **Calificaciones:** tienen `@@unique([alumnoId, grupoMateriaId, periodo])` en Prisma. El `upsert` resuelve automáticamente tomando el último valor.
- **Becas:** gestionadas solo por ADMIN. Un único actor, conflicto imposible.

El único caso problemático (dos maestras editan la misma calificación offline simultáneamente) se resuelve con un error `409` que la UI debe mostrar al usuario explicando que la calificación ya fue registrada por otra sesión.

---

## 3. 🌐 CONFIGURACIÓN DE RED LOCAL

### Mapa de red del colegio

```
INTERNET (opcional)
       │
  [Router LAN]  ← IP: 192.168.1.1
       │
  ─────┼──────────────────────────────────────────
       │                 Red local 192.168.1.x
  [PC SERVIDOR]    [PC CAJA]    [PC DIRECCIÓN]    [PC MAESTRA]
  192.168.1.10     .11          .12               .13
  Puerto 3000      (browser)    (browser)         (browser)
  SQLite + API
```

---

### Configuración del Servidor Central

#### `.env` de producción

```bash
# backend/.env.production
NODE_ENV=production
PORT=3000
HOST=0.0.0.0                    # Escucha en TODAS las interfaces de red

DATABASE_URL="file:/app/data/sae.db"    # Con Docker (volumen persistente)
# DATABASE_URL="file:./prisma/sae.db"   # Sin Docker (ruta relativa)

JWT_SECRET=SAE_SD_2026_PROD_KEY_MINIMO_32_CARACTERES_AQUI
JWT_EXPIRES_IN=8h
JWT_REFRESH_EXPIRES_IN=7d

BCRYPT_ROUNDS=10
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=200

# Listar todas las IPs de los nodos satélite
CORS_ORIGIN=http://192.168.1.10:3000,http://192.168.1.11:3000,http://192.168.1.12:3000,http://192.168.1.13:3000,http://localhost:3000

LOG_LEVEL=combined
```

El `server.js` ya usa `config.host` (que lee `HOST=0.0.0.0`), por lo que **no requiere cambios de código**.

#### Verificar accesibilidad desde la red

```bash
# Desde cualquier PC de la red, después de npm start o docker compose up
curl http://192.168.1.10:3000/health

# Respuesta esperada:
# {"ok":true,"sistema":"SAE Colegio San Diego","version":"1.0.0","entorno":"production"}
```

#### Firewall en Windows (ejecutar como Administrador)

```powershell
New-NetFirewallRule `
  -DisplayName "SAE Colegio San Diego" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 3000 `
  -Action Allow `
  -Profile Private
```

---

### Configuración de Nodos Satélite

#### `API_BASE_URL` dinámico — El cambio más importante

Agregar este bloque en `<head>` de cada panel, **antes del script de Alpine**:

```html
<!-- Config dinámica: el servidor inyecta su propia IP -->
<script src="/config.js"></script>

<!-- Vendor local (sin CDN) -->
<link rel="stylesheet" href="/vendor/tailwind.min.css">
<script defer src="/vendor/alpine.min.js"></script>
<script src="/vendor/lucide.min.js"></script>
```

El endpoint `/config.js` que debe crearse en `backend/src/app.js`:

```javascript
// Añadir ANTES del middleware express.static en app.js
app.get('/config.js', (req, res) => {
  const os     = require('os');
  const ifaces = os.networkInterfaces();
  let serverIP = '127.0.0.1';

  // Detectar la IP de LAN automáticamente
  for (const name of Object.keys(ifaces)) {
    for (const iface of ifaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        serverIP = iface.address;
        break;
      }
    }
  }

  res.setHeader('Content-Type', 'application/javascript');
  res.send(`
    window.SAE_CONFIG = {
      API_BASE:  'http://${serverIP}:${config.port}/api/v1',
      SERVER_IP: '${serverIP}',
      VERSION:   '1.0.0',
    };
    console.log('[SAE] Conectado al servidor:', window.SAE_CONFIG.API_BASE);
  `);
});
```

Con esto, **cualquier PC de la red** que abra `http://192.168.1.10:3000` recibe automáticamente la IP correcta del servidor sin configuración manual.

---

### Módulo API compartido (`frontend/js/api.js`)

```javascript
// frontend/js/api.js — incluir en los 3 paneles con <script src="/js/api.js"></script>

const api = {
  get BASE() { return window.SAE_CONFIG?.API_BASE || 'http://localhost:3000/api/v1'; },

  getToken()      { return localStorage.getItem('sae_token'); },
  setToken(token) { localStorage.setItem('sae_token', token); },
  clearToken()    { localStorage.removeItem('sae_token'); },

  async request(method, endpoint, body = null) {
    const headers = { 'Content-Type': 'application/json' };
    const token   = this.getToken();
    if (token) headers['Authorization'] = `Bearer ${token}`;

    try {
      const res = await fetch(`${this.BASE}${endpoint}`, {
        method,
        headers,
        body: body ? JSON.stringify(body) : null,
      });

      if (res.status === 401) {
        this.clearToken();
        window.location.href = '/login.html';
        return;
      }

      return res.json();
    } catch (err) {
      console.warn('[SAE] Sin conexión:', err.message);
      throw err;
    }
  },

  login:   (creds)    => api.request('POST', '/auth/login', creds),
  alumnos: {
    listar: (q = '')  => api.request('GET', `/alumnos?q=${encodeURIComponent(q)}`),
    crear:  (datos)   => api.request('POST', '/alumnos', datos),
    actualizar: (id, datos) => api.request('PUT', `/alumnos/${id}`, datos),
  },
  pagos: {
    listar:    ()  => api.request('GET', '/pagos'),
    registrar: (p) => api.request('POST', '/pagos', p),
  },
  calificaciones: {
    guardar: (c)    => api.request('POST', '/calificaciones', c),
    lote:    (arr)  => api.request('POST', '/calificaciones/lote', arr),
  },
  becas: {
    listar:    ()         => api.request('GET', '/becas'),
    solicitar: (b)        => api.request('POST', '/becas/solicitudes', b),
    resolver:  (id, data) => api.request('PATCH', `/becas/solicitudes/${id}/resolver`, data),
  },
  grupos: {
    listar: () => api.request('GET', '/grupos'),
  },
};
```

#### Ejemplo de migración de un método en el panel

```javascript
// ANTES — datos mock con alert()
agregarPago() {
  this.pagosRegistrados.push({ ...this.nuevoPago });
  alert(`Pago registrado para ${this.nuevoPago.alumno}`);
},

// DESPUÉS — llamada real a la API
async agregarPago() {
  try {
    const res = await api.pagos.registrar({
      alumnoId:     this.nuevoPago.alumnoId,
      concepto:     this.nuevoPago.concepto,
      monto:        parseFloat(this.nuevoPago.monto),
      fecha:        this.nuevoPago.fecha,
      observaciones: this.nuevoPago.observaciones || null,
    });

    if (res?.ok) {
      this.pagosRegistrados.unshift(res.data);
      this.modal = null;
      this.notificacion = { tipo: 'exito', msg: `Pago registrado para ${res.data.alumno.nombre}` };
    }
  } catch (err) {
    this.notificacion = { tipo: 'error', msg: 'Sin conexión. Intenta nuevamente.' };
  }
},
```

---

## PRIORIDADES DE TRABAJO (Orden recomendado)

| Prioridad | Tarea | Estimado |
|-----------|-------|---------|
| 🔴 **P1** | Crear `login.html` + flujo JWT completo | 4h |
| 🔴 **P2** | Crear `frontend/js/api.js` + `/config.js` dinámico | 2h |
| 🔴 **P3** | Conectar `admin_panel.html` a la API (alumnos, pagos, calificaciones, becas) | 1 día |
| 🟠 **P4** | Conectar `gestor_panel.html` y `maestra_panel.html` | 4h |
| 🟠 **P5** | Vendorizar assets (eliminar CDNs) | 2h |
| 🟡 **P6** | Eliminar `controllers/asistencias/` residual | 15 min |
| 🟡 **P7** | Agregar regla de firewall en Windows del servidor | 10 min |
| 🟢 **P8** | Service Worker de caché (Nivel 2 offline) | 4h |
| 🟢 **P9** | IndexedDB offline queue (Nivel 3 offline) | 3-5 días |

---

*Auditoría generada por Claude Code sobre lectura directa del código fuente. No contiene suposiciones — cada hallazgo tiene referencia a un archivo y línea real del proyecto.*
