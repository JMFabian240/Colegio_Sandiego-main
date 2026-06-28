const jwt = require('jsonwebtoken');
const token = jwt.sign({ id: 1, rol: 'ADMIN' }, 'desarrollo_sae_colegio_sandiego_2026_secret_local', { expiresIn: '1h', issuer: 'sae-sandiego' });
console.log(token);
