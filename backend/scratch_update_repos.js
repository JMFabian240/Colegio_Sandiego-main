const fs = require('fs');

const repositories = [
  'src/repositories/alumnos/alumnos.repository.js',
  'src/repositories/pagos/pagos.repository.js',
  'src/repositories/becas/becas.repository.js',
  'src/repositories/calificaciones/calificaciones.repository.js'
];

repositories.forEach(repoPath => {
  if (!fs.existsSync(repoPath)) return;
  let code = fs.readFileSync(repoPath, 'utf8');

  if (!code.includes('withAudit')) {
    code = "const { withAudit } = require('../../utils/audit.utils');\n" + code;
  }

  // Helper to wrap function
  const wrapFunction = (fnName, params, originalSig) => {
    const startStr = `async function ${fnName}(${originalSig}) {`;
    const auditSig = originalSig ? `${originalSig}, auditCtx = {}` : `auditCtx = {}`;
    const replacement = `async function ${fnName}(${auditSig}) { return withAudit(auditCtx.usuarioId, auditCtx.ip, async (tx) => {`;
    
    // Replace the signature
    let parts = code.split(startStr);
    if (parts.length === 2) {
      // Find the end of the function (since they are usually the last blocks, we find the next 'async function' or 'module.exports')
      const beforeStr = parts[0];
      const afterStr = parts[1];
      
      // We also need to replace `prisma.` with `tx.` inside the function body!
      // But only inside the function body.
      let endIdx = afterStr.indexOf('\nasync function ');
      if (endIdx === -1) endIdx = afterStr.indexOf('\nmodule.exports');
      if (endIdx === -1) endIdx = afterStr.length;
      
      let body = afterStr.substring(0, endIdx);
      let remainder = afterStr.substring(endIdx);
      
      body = body.replace(/prisma\./g, 'tx.');
      
      // Add closing brace before remainder
      body = body + '});\n';
      
      code = beforeStr + replacement + body + remainder;
      console.log(`Wrapped ${fnName} in ${repoPath}`);
    } else {
      console.log(`Could not find exact signature for ${fnName} in ${repoPath}. Looked for: ${startStr}`);
    }
  };

  if (repoPath.includes('alumnos')) {
    wrapFunction('create', 'datos', 'datos');
    wrapFunction('update', 'id, datos', 'id, datos');
    wrapFunction('softDelete', 'id', 'id');
  } else if (repoPath.includes('pagos')) {
    wrapFunction('create', 'datos', 'datos');
    // Pagos has findMany, create. We just need create. Let me verify the methods.
  } else if (repoPath.includes('becas')) {
    wrapFunction('create', 'datos', 'datos');
    wrapFunction('update', 'id, datos', 'id, datos');
  } else if (repoPath.includes('calificaciones')) {
    wrapFunction('upsertMany', 'calificaciones', 'calificaciones');
  }

  fs.writeFileSync(repoPath, code);
});
