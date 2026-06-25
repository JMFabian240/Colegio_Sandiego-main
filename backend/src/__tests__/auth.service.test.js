/**
 * SAE — Test: auth.service.js — login()
 *
 * Casos cubiertos:
 *   - Login exitoso → retorna { token, usuario, redirectTo }
 *   - Usuario no encontrado → 401
 *   - Contraseña incorrecta → 401 + llama registrarFallo
 *   - Cuenta bloqueada (bloqueadoHasta en el futuro) → 423
 *   - Login exitoso limpia fallos (limpiarFallos llamado)
 *   - redirectTo correcto según rol
 *
 * Estrategia de mock: vi.spyOn() puro.
 * auth.service.js NO destructura sus imports → spyOn intercepta correctamente.
 */

'use strict';

process.env.JWT_SECRET   = 'test-secret-key-para-vitest-minimo-32-chars';
process.env.DATABASE_URL = 'postgresql://test:test@localhost:5432/test';
process.env.NODE_ENV     = 'test';

// Cargar módulos reales — ninguno conecta a BD en el require
const authRepo    = require('../repositories/auth/auth.repository');
const hashUtils   = require('../utils/hash.utils');
const jwtUtils    = require('../utils/jwt.utils');
const prisma      = require('../config/database');
const authService = require('../services/auth/auth.service');

// ── Fixtures ───────────────────────────────────────────────────
const usuarioMock = {
  id:               1,
  nombre:           'Admin Test',
  username:         'admin.test',
  password:         '$2b$10$hashedpassword',
  rol:              'ADMIN',
  activo:           true,
  bloqueadoHasta:   null,
  intentosFallidos: 0,
};

describe('auth.service — login()', () => {
  beforeEach(() => {
    // Todos los módulos se requieren como objeto completo (sin destructurar) en auth.service →
    // vi.spyOn intercepta correctamente al reemplazar la propiedad en el objeto exportado.
    vi.spyOn(prisma.configuracionSistema, 'findFirst').mockImplementation(({ where }) => {
      if (where.clave === 'login_max_intentos')    return Promise.resolve({ valor: '5' });
      if (where.clave === 'login_minutos_bloqueo') return Promise.resolve({ valor: '30' });
      return Promise.resolve(null);
    });

    vi.spyOn(authRepo, 'registrarIntento').mockResolvedValue({});
    vi.spyOn(authRepo, 'registrarFallo').mockResolvedValue({});
    vi.spyOn(authRepo, 'limpiarFallos').mockResolvedValue({});
    vi.spyOn(jwtUtils, 'generateToken').mockReturnValue('mock.jwt.token');
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  // ── Login exitoso ──────────────────────────────────────────

  test('login exitoso → retorna token y usuario sin password', async () => {
    vi.spyOn(authRepo, 'findByUsername').mockResolvedValue(usuarioMock);
    vi.spyOn(hashUtils, 'comparePassword').mockResolvedValue(true);

    const result = await authService.login('admin.test', 'Contraseña123', '192.168.1.5', 'TestAgent');

    expect(result).toHaveProperty('token', 'mock.jwt.token');
    expect(result).toHaveProperty('usuario');
    expect(result.usuario).not.toHaveProperty('password');
    expect(result.usuario).not.toHaveProperty('bloqueadoHasta');
    expect(result.usuario).not.toHaveProperty('intentosFallidos');
  });

  test('login exitoso ADMIN → redirectTo /panel.html', async () => {
    vi.spyOn(authRepo, 'findByUsername').mockResolvedValue({ ...usuarioMock, rol: 'ADMIN' });
    vi.spyOn(hashUtils, 'comparePassword').mockResolvedValue(true);

    const result = await authService.login('admin.test', 'Contraseña123');
    expect(result.redirectTo).toBe('/panel.html');
  });

  test('login exitoso GESTOR → redirectTo /panel.html', async () => {
    vi.spyOn(authRepo, 'findByUsername').mockResolvedValue({ ...usuarioMock, rol: 'GESTOR' });
    vi.spyOn(hashUtils, 'comparePassword').mockResolvedValue(true);

    const result = await authService.login('gestor.test', 'Contraseña123');
    expect(result.redirectTo).toBe('/panel.html');
  });

  test('login exitoso MAESTRA → redirectTo /panel.html', async () => {
    vi.spyOn(authRepo, 'findByUsername').mockResolvedValue({ ...usuarioMock, rol: 'MAESTRA' });
    vi.spyOn(hashUtils, 'comparePassword').mockResolvedValue(true);

    const result = await authService.login('maestra.test', 'Contraseña123');
    expect(result.redirectTo).toBe('/panel.html');
  });

  test('login exitoso llama limpiarFallos', async () => {
    vi.spyOn(authRepo, 'findByUsername').mockResolvedValue(usuarioMock);
    vi.spyOn(hashUtils, 'comparePassword').mockResolvedValue(true);

    await authService.login('admin.test', 'Contraseña123');

    expect(authRepo.limpiarFallos).toHaveBeenCalledWith(usuarioMock.id);
  });

  test('login exitoso registra intento exitoso', async () => {
    vi.spyOn(authRepo, 'findByUsername').mockResolvedValue(usuarioMock);
    vi.spyOn(hashUtils, 'comparePassword').mockResolvedValue(true);

    await authService.login('admin.test', 'Contraseña123', '10.0.0.1', 'Chrome');

    expect(authRepo.registrarIntento).toHaveBeenCalledWith(
      expect.objectContaining({ exitoso: true, usuarioId: usuarioMock.id })
    );
  });

  // ── Usuario no encontrado ─────────────────────────────────

  test('usuario no encontrado → lanza 401', async () => {
    vi.spyOn(authRepo, 'findByUsername').mockResolvedValue(null);
    const compareSpy = vi.spyOn(hashUtils, 'comparePassword');

    await expect(
      authService.login('inexistente', 'Cualquier123')
    ).rejects.toMatchObject({ statusCode: 401 });

    expect(compareSpy).not.toHaveBeenCalled();
  });

  // ── Contraseña incorrecta ────────────────────────────────

  test('contraseña incorrecta → lanza 401', async () => {
    vi.spyOn(authRepo, 'findByUsername').mockResolvedValue(usuarioMock);
    vi.spyOn(hashUtils, 'comparePassword').mockResolvedValue(false);

    await expect(
      authService.login('admin.test', 'MalContraseña')
    ).rejects.toMatchObject({ statusCode: 401 });
  });

  test('contraseña incorrecta → llama registrarFallo con maxIntentos y minutosBloqueo', async () => {
    vi.spyOn(authRepo, 'findByUsername').mockResolvedValue(usuarioMock);
    vi.spyOn(hashUtils, 'comparePassword').mockResolvedValue(false);

    await authService.login('admin.test', 'MalContraseña').catch(() => {});

    expect(authRepo.registrarFallo).toHaveBeenCalledWith(
      usuarioMock.id,
      5,
      30
    );
  });

  test('contraseña incorrecta → no llama limpiarFallos', async () => {
    vi.spyOn(authRepo, 'findByUsername').mockResolvedValue(usuarioMock);
    vi.spyOn(hashUtils, 'comparePassword').mockResolvedValue(false);

    await authService.login('admin.test', 'MalContraseña').catch(() => {});

    expect(authRepo.limpiarFallos).not.toHaveBeenCalled();
  });

  // ── Cuenta bloqueada ─────────────────────────────────────

  test('cuenta bloqueada → lanza 423', async () => {
    const futuro = new Date(Date.now() + 20 * 60 * 1000); // +20 min
    vi.spyOn(authRepo, 'findByUsername').mockResolvedValue({
      ...usuarioMock,
      bloqueadoHasta: futuro,
      intentosFallidos: 5,
    });
    const compareSpy = vi.spyOn(hashUtils, 'comparePassword');

    await expect(
      authService.login('admin.test', 'Cualquier')
    ).rejects.toMatchObject({ statusCode: 423 });

    expect(compareSpy).not.toHaveBeenCalled();
  });

  test('bloqueo ya expirado → permite intentar contraseña', async () => {
    const pasado = new Date(Date.now() - 5 * 60 * 1000); // -5 min (ya pasó)
    vi.spyOn(authRepo, 'findByUsername').mockResolvedValue({
      ...usuarioMock,
      bloqueadoHasta: pasado,
    });
    vi.spyOn(hashUtils, 'comparePassword').mockResolvedValue(true);

    const result = await authService.login('admin.test', 'Contraseña123');
    expect(result).toHaveProperty('token');
  });
});
