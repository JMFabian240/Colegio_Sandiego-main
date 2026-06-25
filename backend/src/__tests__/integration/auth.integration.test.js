/**
 * SAE — Test de integración HTTP: Auth + RBAC + Alumnos
 *
 * Qué se prueba:
 *   POST /api/v1/auth/login
 *     - Body válido + credenciales correctas → 200 con {token, usuario, redirectTo}
 *     - Body válido + usuario no existe → 401
 *     - Body válido + contraseña incorrecta → 401
 *     - Body inválido (username vacío) → 422 (validate middleware)
 *   POST /api/v1/auth/refresh
 *     - Token válido en header → 200 con nuevo token
 *     - Sin header Authorization → 401
 *   GET /api/v1/auth/me
 *     - Token válido + usuario activo → 200 con perfil
 *     - Sin token → 401 (authenticate middleware)
 *   PATCH /api/v1/auth/usuarios/:id/reset-password
 *     - Token ADMIN + body válido → 200 (soloAdmin autoriza)
 *     - Token GESTOR → 403 (soloAdmin deniega)
 *   GET /api/v1/alumnos (RBAC)
 *     - Sin token → 401
 *     - Token MAESTRA → 403 (authorize deniega rol no permitido)
 *     - Token ADMIN → 200 (service mockeado)
 *
 * Estrategia:
 *   - App Express real (mismo objeto exportado en producción)
 *   - supertest para requests HTTP en memoria (sin puerto real)
 *   - vi.spyOn() en servicios para evitar conexión a PostgreSQL
 *   - Rate limiter respetado: ≤9 llamadas a /api/v1/auth por suite
 */

'use strict';

// Env debe estar lista antes que cualquier require
process.env.JWT_SECRET   = 'test-secret-key-para-vitest-minimo-32-chars';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.NODE_ENV     = 'test';

const request          = require('supertest');
const app              = require('../../app');
const authService      = require('../../services/auth/auth.service');
const alumnosService   = require('../../services/alumnos/alumnos.service');
const { generateToken }= require('../../utils/jwt.utils');

// ── Fixtures ──────────────────────────────────────────────────
const usuarioAdminMock = {
  id:       1,
  nombre:   'Admin Test',
  username: 'admin.test',
  rol:      'ADMIN',
};

const usuarioGestorMock = {
  id:  2,
  rol: 'GESTOR',
};

const tokenAdmin  = generateToken(usuarioAdminMock);
const tokenGestor = generateToken({ ...usuarioGestorMock, nombre: 'Gestor', username: 'gestor.test' });
const tokenMaestra= generateToken({ id: 3, nombre: 'Maestra', username: 'maestra.test', rol: 'MAESTRA' });

// ═══════════════════════════════════════════════════════════════
// BLOQUE 1 — POST /api/v1/auth/login
// ═══════════════════════════════════════════════════════════════
describe('Integration — POST /api/v1/auth/login', () => {
  afterEach(() => vi.restoreAllMocks());

  test('body válido + credenciales correctas → 200 con token y usuario', async () => {
    vi.spyOn(authService, 'login').mockResolvedValue({
      token:      'mock.access.token',
      usuario:    usuarioAdminMock,
      redirectTo: '/panel.html',
    });

    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ username: 'admin.test', password: 'Contraseña123' });

    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.data).toHaveProperty('token');
    expect(res.body.data).toHaveProperty('usuario');
    expect(res.body.data).toHaveProperty('redirectTo');
  });

  test('body válido + usuario inexistente → 401', async () => {
    vi.spyOn(authService, 'login').mockRejectedValue(
      Object.assign(new Error('Credenciales incorrectas.'), { statusCode: 401 })
    );

    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ username: 'noexiste', password: 'Cualquier123' });

    expect(res.status).toBe(401);
    expect(res.body.ok).toBe(false);
  });

  test('body válido + contraseña incorrecta → 401', async () => {
    vi.spyOn(authService, 'login').mockRejectedValue(
      Object.assign(new Error('Credenciales incorrectas.'), { statusCode: 401 })
    );

    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ username: 'admin.test', password: 'MalaContraseña' });

    expect(res.status).toBe(401);
    expect(res.body.ok).toBe(false);
  });

  test('body inválido (username vacío) → 422 sin llamar al service', async () => {
    const loginSpy = vi.spyOn(authService, 'login');

    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ username: '', password: 'Contraseña123' });

    expect(res.status).toBe(422);
    expect(res.body.ok).toBe(false);
    expect(loginSpy).not.toHaveBeenCalled();
  });
});

// ═══════════════════════════════════════════════════════════════
// BLOQUE 2 — POST /api/v1/auth/refresh
// ═══════════════════════════════════════════════════════════════
describe('Integration — POST /api/v1/auth/refresh', () => {
  // No mockeamos jwtUtils: el refresh es pure logic, no llama a BD

  test('token válido en header → 200 con nuevo token', async () => {
    const res = await request(app)
      .post('/api/v1/auth/refresh')
      .set('Authorization', `Bearer ${tokenAdmin}`);

    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.data).toHaveProperty('token');
    expect(typeof res.body.data.token).toBe('string');
  });

  test('sin header Authorization → 401', async () => {
    const res = await request(app).post('/api/v1/auth/refresh');
    expect(res.status).toBe(401);
    expect(res.body.ok).toBe(false);
  });
});

// ═══════════════════════════════════════════════════════════════
// BLOQUE 3 — GET /api/v1/auth/me
// ═══════════════════════════════════════════════════════════════
describe('Integration — GET /api/v1/auth/me', () => {
  afterEach(() => vi.restoreAllMocks());

  test('token válido + usuario activo en BD → 200 con perfil', async () => {
    vi.spyOn(authService, 'findUsuarioActivo').mockResolvedValue({ usuarioId: 1 });

    const res = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${tokenAdmin}`);

    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.data).toHaveProperty('id', 1);
    expect(res.body.data).toHaveProperty('rol', 'ADMIN');
  });

  test('sin token → 401 (authenticate bloquea)', async () => {
    const res = await request(app).get('/api/v1/auth/me');
    expect(res.status).toBe(401);
    expect(res.body.ok).toBe(false);
  });
});

// ═══════════════════════════════════════════════════════════════
// BLOQUE 4 — PATCH /api/v1/auth/usuarios/:id/reset-password
// ═══════════════════════════════════════════════════════════════
describe('Integration — PATCH /api/v1/auth/usuarios/:id/reset-password (RBAC)', () => {
  afterEach(() => vi.restoreAllMocks());

  test('token ADMIN + body válido → 200', async () => {
    vi.spyOn(authService, 'resetPassword').mockResolvedValue({
      id:           1,
      nombre:       'Admin Test',
      username:     'admin.test',
      debeCambiarPwd: true,
    });

    const res = await request(app)
      .patch('/api/v1/auth/usuarios/1/reset-password')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({ nuevaPassword: 'NuevaClave123' });

    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
  });

  test('token GESTOR → 403 (soloAdmin deniega acceso)', async () => {
    const res = await request(app)
      .patch('/api/v1/auth/usuarios/1/reset-password')
      .set('Authorization', `Bearer ${tokenGestor}`)
      .send({ nuevaPassword: 'NuevaClave123' });

    expect(res.status).toBe(403);
    expect(res.body.ok).toBe(false);
  });
});

// ═══════════════════════════════════════════════════════════════
// BLOQUE 5 — GET /api/v1/alumnos (RBAC con ruta real)
// ═══════════════════════════════════════════════════════════════
describe('Integration — GET /api/v1/alumnos (RBAC)', () => {
  afterEach(() => vi.restoreAllMocks());

  test('sin token → 401 (authenticate bloquea)', async () => {
    const res = await request(app).get('/api/v1/alumnos');
    expect(res.status).toBe(401);
    expect(res.body.ok).toBe(false);
  });

  test('token MAESTRA → 403 (authorize deniega; solo ADMIN/GESTOR)', async () => {
    const res = await request(app)
      .get('/api/v1/alumnos')
      .set('Authorization', `Bearer ${tokenMaestra}`);

    expect(res.status).toBe(403);
    expect(res.body.ok).toBe(false);
  });

  test('token ADMIN → 200 con array de alumnos', async () => {
    vi.spyOn(alumnosService, 'listar').mockResolvedValue([
      { id: 1, nombre: 'Alumno Test', matricula: 'TST-001' },
    ]);

    const res = await request(app)
      .get('/api/v1/alumnos')
      .set('Authorization', `Bearer ${tokenAdmin}`);

    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(Array.isArray(res.body.data)).toBe(true);
  });

  test('token GESTOR → 200 (GESTOR tiene permiso sobre alumnos)', async () => {
    vi.spyOn(alumnosService, 'listar').mockResolvedValue([]);

    const res = await request(app)
      .get('/api/v1/alumnos')
      .set('Authorization', `Bearer ${tokenGestor}`);

    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
  });
});
