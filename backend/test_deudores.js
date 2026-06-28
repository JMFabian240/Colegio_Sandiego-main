require('dotenv').config({path: '../.env'});
const { deudores } = require('./src/controllers/reportes/reportes.controller.js');

async function main() {
  const req = {};
  const res = {
    json: (data) => console.log('Success:', data.data.length, 'records returned.'),
    status: (code) => ({ json: (err) => console.error('Error', code, err) })
  };
  
  await deudores(req, res, console.error);
}

main();
