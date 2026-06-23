const { app, BrowserWindow, Menu } = require('electron');
const path = require('path');

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    show: false, // Ocultar hasta que cargue para evitar parpadeos
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false
    }
  });

  // Ocultar el menú superior (Archivo, Editar, etc) para que parezca una app nativa
  Menu.setApplicationMenu(null);

  // Cargar la pantalla de inicio local donde se pide la IP del servidor
  mainWindow.loadFile('index.html');

  mainWindow.once('ready-to-show', () => {
    mainWindow.maximize();
    mainWindow.show();
  });
}

app.whenReady().then(() => {
  createWindow();

  app.on('activate', function () {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', function () {
  if (process.platform !== 'darwin') app.quit();
});
