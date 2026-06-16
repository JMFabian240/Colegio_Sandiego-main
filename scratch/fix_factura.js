const fs = require('fs');
['frontend/admin_panel.html', 'frontend/panel.html'].forEach(file => {
  let c = fs.readFileSync(file, 'utf8');
  c = c.replace(/ :readonly="!editandoFacturacionTutor"/g, '');
  c = c.replace(/ :disabled="!editandoFacturacionTutor"/g, '');
  c = c.replace(/<button class="btn-outline flex items-center mr-2" x-show="!editandoFacturacionTutor"[\s\S]*?Modificar Datos Fiscales<\/button>/g, '');
  c = c.replace(/x-show="editandoFacturacionTutor"/g, 'x-show="tutorFichaEditable.requiereFactura"');
  fs.writeFileSync(file, c);
});
console.log('Done!');
