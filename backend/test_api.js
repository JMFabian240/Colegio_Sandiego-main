const http = require('http');

const data = JSON.stringify({ username: 'elizabeth.mendoza', password: 'sandiego2026' });

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/api/v1/auth/login',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

const req = http.request(options, res => {
  let body = '';
  res.on('data', d => body += d);
  res.on('end', () => {
    console.log(body);
    const json = JSON.parse(body);
    const token = json.data.accessToken;

    http.get('http://localhost:3000/api/v1/alumnos?limit=200', { headers: { 'Authorization': `Bearer ${token}` } }, res2 => {
      let body2 = '';
      res2.on('data', d => body2 += d);
      res2.on('end', () => {
        try {
          const json2 = JSON.parse(body2);
          console.log('Total alumnos retornados:', json2.data.length);
        } catch (e) {
          console.log('Error parseando alumnos:', body2.substring(0, 500));
        }
      });
    });
  });
});

req.write(data);
req.end();
