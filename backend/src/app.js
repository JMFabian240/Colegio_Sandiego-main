/**
 * SAE Colegio San Diego — Configuración Express
 * Aplica todos los middlewares globales y monta el router principal.
 */

'use strict';

const express = require('express');
const helmet  = require('helmet');
const cors    = require('cors');
const morgan  = require('morgan');
const path    = require('path');
const rateLimit = require('express-rate-limit');

const config        = require('./config/env');
const router        = require('./routes');
const errorHandler  = require('./middleware/error.middleware');

const app = express();

// ── Seguridad ─────────────────────────────────────────────────
app.use(
  helmet({
    // Permite servir el frontend estático con sus CDN scripts
    contentSecurityPolicy: false,
  })
);

// ── CORS (LAN local — dinámico) ──────────────────────────────
// Permite orígenes explícitos del .env + cualquier IP de la subred local.
const os = require('os');

/**
 * Retorna true si la IP del origin pertenece a la subred LAN del servidor.
 * Compara el prefijo /24 (primeros 3 octetos) de la IP del servidor.
 */
function esOrigenLAN(origin) {
  if (!origin) return false;
  try {
    const url     = new URL(origin);
    const host    = url.hostname;
    const ifaces  = os.networkInterfaces();
    for (const name of Object.keys(ifaces)) {
      for (const iface of ifaces[name]) {
        if (iface.family === 'IPv4' && !iface.internal) {
          // Comparar /24: primeros 3 octetos
          const prefijo = iface.address.split('.').slice(0, 3).join('.');
          if (host.startsWith(prefijo + '.')) return true;
        }
      }
    }
  } catch { /* ignore parse errors */ }
  return false;
}

const corsOptions = (req, callback) => {
  const origin = req.header('Origin');
  let allow = false;

  if (!origin) {
    allow = true;
  } else {
    try {
      const requestedHost = req.headers['x-forwarded-host'] || req.get('host');
      const url = new URL(origin);
      
      // Permitir si el origen coincide con el host solicitado (mismo dominio/túnel)
      if (url.host === requestedHost) {
        allow = true;
      } else if (config.cors.origin.includes(origin)) {
        allow = true;
      } else if (esOrigenLAN(origin)) {
        allow = true;
      } else if (url.hostname.endsWith('.loca.lt') || url.hostname.endsWith('.ngrok-free.app')) {
        allow = true;
      }
    } catch {
      allow = false;
    }
  }

  if (allow) {
    callback(null, {
      origin: true,
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
      credentials: true,
    });
  } else {
    callback(new Error(`CORS: origen no permitido — ${origin}`));
  }
};

app.use(cors(corsOptions));

// ── Rate Limiting ─────────────────────────────────────────────
const limiter = rateLimit({
  windowMs: config.security.rateLimitWindowMs,
  max: config.security.rateLimitMaxRequests,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    ok: false,
    message: 'Demasiadas solicitudes. Intenta de nuevo en 15 minutos.',
  },
});
// app.use('/api', limiter); // Deshabilitado a petición del usuario

// ── Rate Limit estricto para auth ────────────────────────────
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: {
    ok: false,
    message: 'Demasiados intentos de inicio de sesión. Intenta en 15 minutos.',
  },
});
// app.use('/api/v1/auth', authLimiter); // Deshabilitado a petición del usuario

// ── Parsers ───────────────────────────────────────────────────
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true }));

// ── Logs ──────────────────────────────────────────────────────
if (config.env !== 'test') {
  app.use(morgan(config.log.level));
}

// ── /config.js dinámico: inyecta IP del servidor a los nodos satélite ────────
// Los clientes de la LAN cargan este script y obtienen la IP real del servidor.
// El script detecta automáticamente la primera IPv4 no-loopback disponible.
app.get('/config.js', (req, res) => {
  const host = req.headers['x-forwarded-host'] || req.get('host');
  const protocol = req.headers['x-forwarded-proto'] || req.protocol;

  const ifaces = os.networkInterfaces();
  let   serverIP = '127.0.0.1';

  for (const name of Object.keys(ifaces)) {
    for (const iface of ifaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        serverIP = iface.address;
        break;
      }
    }
  }

  res.setHeader('Content-Type', 'application/javascript; charset=utf-8');
  res.setHeader('Cache-Control', 'no-cache, no-store');
  res.send(
`/* SAE — Configuración dinámica generada por el servidor (${new Date().toISOString()}) */
window.SAE_CONFIG = {
  API_BASE:  '${protocol}://${host}/api/v1',
  SERVER_IP: '${serverIP}',
  PORT:      ${config.port},
  VERSION:   '2.0.0',
};
console.log('[SAE] Servidor:', '${host}');`
  );
});

// ── Frontend React (dist compilado) ──────────────────────────
// Sirve el build de Vite/React en la raíz. Debe ir ANTES del legacy.
//
// path.resolve desde backend/src/app.js:
//   __dirname      = .../Colegio_Sandiego-main/backend/src
//   ../../frontend-react/dist = .../Colegio_Sandiego-main/frontend-react/dist
const reactDistPath  = path.resolve(__dirname, '..', '..', 'frontend-react', 'dist');
const frontendPath   = path.resolve(__dirname, '..', '..', 'frontend');

app.use(
  express.static(reactDistPath, {
    index: 'index.html',
    extensions: ['html'],
  })
);

// ── Frontend legacy (paneles HTML clásicos) ───────────────────
// Sirve los archivos HTML originales bajo sus mismas URLs.
app.use(
  express.static(frontendPath, {
    index: false,
    extensions: ['html'],
  })
);

// ── Accesos directos explícitos a paneles legacy ──────────────
app.get('/panel',   (req, res) => res.sendFile(path.join(frontendPath, 'panel.html')));
app.get('/admin',   (req, res) => res.redirect('/panel.html'));
app.get('/gestor',  (req, res) => res.redirect('/panel.html'));
app.get('/maestra', (req, res) => res.redirect('/panel.html'));

// ── Rutas API ─────────────────────────────────────────────────
app.use('/api/v1', router);

// ── Health check ──────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({
    ok: true,
    sistema: 'SAE Colegio San Diego',
    version: '2.0.0',
    entorno: config.env,
    timestamp: new Date().toISOString(),
  });
});

// ── 404 para rutas API no encontradas ────────────────────────
app.use('/api', (req, res) => {
  res.status(404).json({
    ok: false,
    message: `Ruta API no encontrada: ${req.method} ${req.originalUrl}`,
  });
});

// ── SPA Fallback (React Router) ───────────────────────────────
// Cualquier ruta desconocida que NO sea /api ni un archivo estático
// se delega al index.html de React para que el router de cliente la maneje.
app.get('*', (req, res) => {
  res.sendFile(path.join(reactDistPath, 'index.html'));
});

// ── Manejador de errores global ───────────────────────────────
app.use(errorHandler);

module.exports = app;
