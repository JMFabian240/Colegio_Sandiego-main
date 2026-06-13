// Prueba rápida de los endpoints nuevos: login → bitácora → permisos modulos → logout
const https = require('http');

const BASE = 'http://localhost:3000/api/v1';
let token = '';

async function req(method, path, body, tok) {
  return new Promise((resolve, reject) => {
    const url = new URL(BASE + path);
    const data = body ? JSON.stringify(body) : null;
    const opts = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(tok ? { Authorization: `Bearer ${tok}` } : {}),
        ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}),
      },
    };
    const r = https.request(opts, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => resolve({ status: res.statusCode, body: JSON.parse(d || '{}') }));
    });
    r.on('error', reject);
    if (data) r.write(data);
    r.end();
  });
}

async function main() {
  console.log('=== Test endpoints RF-01 a RF-10 ===\n');

  // 1. Login
  const login = await req('POST', '/auth/login', { username: 'elizabeth.mendoza', password: 'Admin2026' });
  console.log(`[1] POST /auth/login → ${login.status} ${login.status === 200 ? '✅' : '❌'}`);
  if (login.body.data?.token) {
    token = login.body.data.token;
    const u = login.body.data.usuario;
    console.log(`    Usuario: ${u.nombre} | Rol: ${u.rol} | ultimoAcceso: ${u.ultimoAcceso ?? '(null)'}`);
  } else {
    console.log('    ⚠️  Sin token, abortando tests de auth.');
    return;
  }

  // 2. GET /bitacora
  const bitacora = await req('GET', '/bitacora?limite=3', null, token);
  console.log(`\n[2] GET /bitacora → ${bitacora.status} ${bitacora.status === 200 ? '✅' : '❌'}`);
  if (bitacora.body.data) {
    console.log(`    Total registros: ${bitacora.body.data.total}`);
    if (bitacora.body.data.datos?.length > 0) {
      const r = bitacora.body.data.datos[0];
      console.log(`    Primer registro: ${r.accion} en ${r.tabla} por ${r.usuario?.nombre}`);
    }
  }

  // 3. GET /permisos/modulos
  const modulos = await req('GET', '/permisos/modulos', null, token);
  console.log(`\n[3] GET /permisos/modulos → ${modulos.status} ${modulos.status === 200 ? '✅' : '❌'}`);
  if (modulos.body.data) {
    console.log(`    Módulos: ${modulos.body.data.join(', ')}`);
  }

  // 4. POST /auth/logout
  const logout = await req('POST', '/auth/logout', null, token);
  console.log(`\n[4] POST /auth/logout → ${logout.status} ${logout.status === 200 ? '✅' : '❌'}`);

  // 5. Verificar que el token quedó revocado
  const afterLogout = await req('GET', '/auth/me', null, token);
  const revocado = afterLogout.status === 401;
  console.log(`\n[5] GET /auth/me con token revocado → ${afterLogout.status} ${revocado ? '✅ (401 esperado)' : '❌ (debería ser 401)'}`);

  console.log('\n=== Fin de pruebas ===');
}

main().catch(e => { console.error('Error:', e.message); process.exit(1); });
