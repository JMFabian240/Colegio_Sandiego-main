const http = require('http');

async function loginAndFetch() {
  // Login
  const loginData = JSON.stringify({ correoElectronico: 'elizabeth.admin', contrasena: 'sandiego2026' });
  
  const loginReq = http.request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/v1/auth/login',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': loginData.length
    }
  }, (res) => {
    let body = '';
    res.on('data', d => body += d);
    res.on('end', () => {
      const auth = JSON.parse(body);
      const token = auth.data.token;
      
      // Fetch Alumnos
      const fetchReq = http.request({
        hostname: 'localhost',
        port: 3000,
        path: '/api/v1/alumnos?nivel=BACHILLERATO',
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${token}`
        }
      }, (res2) => {
        let body2 = '';
        res2.on('data', d => body2 += d);
        res2.on('end', () => {
          const result = JSON.parse(body2);
          console.log(`API returned ok: ${result.ok}`);
          if (result.ok) {
            console.log(`Data length: ${result.data ? result.data.length : 'undefined'}`);
          } else {
            console.log(`Error: ${result.message}`);
          }
        });
      });
      fetchReq.end();
    });
  });
  
  loginReq.write(loginData);
  loginReq.end();
}

loginAndFetch();
