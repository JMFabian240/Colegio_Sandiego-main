const fs = require('fs');
const path = require('path');

const fileNames = ['panel.html', 'maestra_panel.html', 'gestor_panel.html'];

function parseTemplates(html) {
  const templates = {};
  let pos = 0;

  while (true) {
    const startIdx = html.indexOf('<template x-if="view===', pos);
    if (startIdx === -1) break;

    const nameStart = html.indexOf("'", startIdx) + 1;
    const nameEnd = html.indexOf("'", nameStart);
    const viewName = html.substring(nameStart, nameEnd);

    const firstTagEnd = html.indexOf('>', startIdx) + 1;

    let depth = 1;
    let curr = firstTagEnd;
    
    while (depth > 0 && curr < html.length) {
      const nextOpen = html.indexOf('<template', curr);
      const nextClose = html.indexOf('</template>', curr);

      if (nextClose === -1) break; // error

      if (nextOpen !== -1 && nextOpen < nextClose) {
        depth++;
        curr = nextOpen + 9;
      } else {
        depth--;
        if (depth === 0) {
          templates[viewName] = html.substring(firstTagEnd, nextClose).trim();
          pos = nextClose + 11;
          break;
        }
        curr = nextClose + 11;
      }
    }
  }

  // Also extract modales if possible
  return templates;
}

const viewsDir = path.join(__dirname, 'views');
if (!fs.existsSync(viewsDir)) {
  fs.mkdirSync(viewsDir);
}

// 1. Parse panel.html (admin/gestor mainly)
const panelHtml = fs.readFileSync(path.join(__dirname, 'panel.html'), 'utf-8');
const adminViews = parseTemplates(panelHtml);

// 2. Parse maestra_panel.html
const maestraHtml = fs.readFileSync(path.join(__dirname, 'maestra_panel.html'), 'utf-8');
const maestraViews = parseTemplates(maestraHtml);

// 3. Parse gestor_panel.html
const gestorHtml = fs.readFileSync(path.join(__dirname, 'gestor_panel.html'), 'utf-8');
const gestorViews = parseTemplates(gestorHtml);

const allViewNames = new Set([...Object.keys(adminViews), ...Object.keys(maestraViews)]);

for (const name of allViewNames) {
  let content = '';

  if (name === 'dashboard') {
    content += `<div class="space-y-5">\n`;
    content += `  <!-- Dashboard financiero (ADMIN y GESTOR) -->\n`;
    content += `  <template x-if="tieneFinanzas()">\n    <div>\n${adminViews[name]}\n    </div>\n  </template>\n\n`;
    if (maestraViews[name]) {
      content += `  <!-- Dashboard Docente -->\n`;
      content += `  <template x-if="esMaestra()">\n    <div>\n${maestraViews[name]}\n    </div>\n  </template>\n`;
    }
    content += `</div>`;
  } else if (name === 'alumnos') {
    content += `  <!-- Alumnos ADMIN/GESTOR -->\n`;
    content += `  <template x-if="tienePermiso('alumnos', 'lectura') && !esMaestra()">\n    <div>\n${adminViews[name]}\n    </div>\n  </template>\n\n`;
    if (maestraViews[name]) {
      content += `  <!-- Alumnos Docente -->\n`;
      content += `  <template x-if="esMaestra()">\n    <div>\n${maestraViews[name]}\n    </div>\n  </template>\n`;
    }
  } else {
    // Default to panel.html view
    content = adminViews[name] || maestraViews[name];
  }

  fs.writeFileSync(path.join(viewsDir, `${name}.html`), content);
  console.log(`Extracted view: ${name}`);
}

console.log("Done extracting views.");
