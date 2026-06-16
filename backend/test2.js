const { findById } = require('./src/repositories/alumnos/alumnos.repository');
findById(13).then(console.dir).catch(console.error).finally(() => process.exit(0));
