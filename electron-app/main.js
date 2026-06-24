const { app, BrowserWindow, dialog } = require('electron');
const path = require('path');
const { spawn, execSync } = require('child_process');
const fs = require('fs');
const http = require('http');

let mainWindow;
let backendProcess;
let postgresProcess;

// Rutas de binarios dependiendo si estamos en dev o en prod (empaquetado)
const isDev = !app.isPackaged;
const baseBinPath = isDev 
  ? path.join(__dirname, 'bin')
  : path.join(process.resourcesPath, 'bin');

const pgBinPath = path.join(baseBinPath, 'pgsql', 'bin');
const initdbPath = path.join(pgBinPath, 'initdb.exe');
const pgctlPath = path.join(pgBinPath, 'pg_ctl.exe');
const psqlPath = path.join(pgBinPath, 'psql.exe');
const backendExePath = path.join(baseBinPath, 'backend-windows.exe');

// Directorio de datos de PostgreSQL en AppData
const userDataPath = app.getPath('userData'); // ej: AppData/Roaming/sae-colegio-sandiego
const dbDataPath = path.join(userDataPath, 'pgdata');

async function initDatabase() {
  console.log('Verificando base de datos en:', dbDataPath);
  let isNewDB = false;
  
  if (!fs.existsSync(dbDataPath)) {
    console.log('Inicializando cluster de base de datos...');
    try {
      execSync(`"${initdbPath}" -D "${dbDataPath}" -U postgres -E UTF8`, { stdio: 'inherit' });
      console.log('Cluster inicializado correctamente.');
      isNewDB = true;
    } catch (err) {
      console.error('Error inicializando base de datos:', err);
      dialog.showErrorBox('Error de Base de Datos', 'No se pudo inicializar la base de datos local.');
      app.quit();
      return { success: false, isNewDB: false };
    }
  }
  return { success: true, isNewDB };
}

function startDatabase() {
  return new Promise((resolve, reject) => {
    console.log('Iniciando PostgreSQL...');
    try {
      execSync(`"${pgctlPath}" start -D "${dbDataPath}" -w -t 60`, { stdio: 'inherit' });
      console.log('PostgreSQL iniciado correctamente.');
      resolve();
    } catch (err) {
      console.error('Error iniciando PostgreSQL:', err);
      try {
        const status = execSync(`"${pgctlPath}" status -D "${dbDataPath}"`).toString();
        if (status.includes('server is running')) {
          console.log('PostgreSQL ya estaba corriendo.');
          resolve();
          return;
        }
      } catch (e) {}
      
      dialog.showErrorBox('Error de Base de Datos', 'No se pudo iniciar el servicio de PostgreSQL local.');
      app.quit();
      reject(err);
    }
  });
}

function stopDatabase() {
  console.log('Deteniendo PostgreSQL...');
  try {
    execSync(`"${pgctlPath}" stop -D "${dbDataPath}" -m fast`, { stdio: 'inherit' });
    console.log('PostgreSQL detenido correctamente.');
  } catch (err) {
    console.error('Error deteniendo PostgreSQL:', err);
  }
}

function startBackend() {
  console.log('Iniciando Backend Node.js...');
  
  // Asignamos la cadena de conexion local
  const env = {
    ...process.env,
    DATABASE_URL: 'postgresql://postgres@localhost:5432/postgres?schema=public',
    PORT: '3000',
    NODE_ENV: 'production'
  };

  backendProcess = spawn(backendExePath, [], { env, stdio: 'pipe' });

  backendProcess.stdout.on('data', (data) => console.log(`[BACKEND]: ${data}`));
  backendProcess.stderr.on('data', (data) => console.error(`[BACKEND ERR]: ${data}`));

  backendProcess.on('close', (code) => {
    console.log(`Backend cerrado con codigo ${code}`);
  });
}

function waitForBackend(url, timeout = 30000) {
  return new Promise((resolve, reject) => {
    const startTime = Date.now();
    const interval = setInterval(() => {
      if (Date.now() - startTime > timeout) {
        clearInterval(interval);
        reject(new Error('Timeout esperando al backend'));
        return;
      }
      const req = http.get(url, (res) => {
        if (res.statusCode === 200) {
          clearInterval(interval);
          resolve();
        }
      });
      req.on('error', () => {}); // Ignorar errores de conexion rechazada mientras arranca
    }, 1000);
  });
}

async function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 800,
    show: false,
    autoHideMenuBar: true,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true
    }
  });

  mainWindow.once('ready-to-show', () => {
    mainWindow.maximize();
    mainWindow.show();
  });

  // Mostramos una ventana de carga inicial si lo deseamos, o simplemente esperamos
  // mainWindow.loadFile('loading.html'); // opcional

  try {
    const dbInitResult = await initDatabase();
    if (!dbInitResult.success) return;
    
    await startDatabase();
    
    // Si la base de datos es nueva, ejecutamos el script de creación de esquema
    if (dbInitResult.isNewDB) {
      console.log('Aplicando esquema inicial a la base de datos...');
      try {
        const initSqlPath = path.join(baseBinPath, 'init.sql');
        execSync(`"${psqlPath}" -U postgres -d postgres -f "${initSqlPath}"`, { stdio: 'inherit' });
        console.log('Esquema aplicado correctamente.');
      } catch (err) {
        console.error('Error aplicando esquema:', err);
      }
    }

    // Iniciar backend
    startBackend();

    console.log('Esperando a que el backend esté disponible...');
    await waitForBackend('http://localhost:3000/health');
    console.log('Backend disponible. Cargando UI...');

    mainWindow.loadURL('http://localhost:3000/');
  } catch (error) {
    console.error('Error durante la orquestación:', error);
    dialog.showErrorBox('Error Fatal', 'No se pudo iniciar el servidor local.');
  }
}

app.whenReady().then(() => {
  createWindow();

  app.on('activate', function () {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('will-quit', () => {
  if (backendProcess) {
    backendProcess.kill();
  }
  stopDatabase();
});

app.on('window-all-closed', function () {
  if (process.platform !== 'darwin') app.quit();
});
