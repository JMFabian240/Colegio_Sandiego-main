# Creación de Aplicación Nativa con Tauri y PostgreSQL Portable

Este plan describe la arquitectura y los pasos necesarios para convertir el sistema Colegio San Diego en una aplicación de escritorio nativa utilizando Tauri, empaquetando el backend de Node.js como un proceso secundario (Sidecar) e incluyendo PostgreSQL en formato portable.

## User Review Required

> [!WARNING]
> **Requisito Faltante Detectado:** He revisado tu sistema y **no tienes instalado Rust (`cargo`)**.
> Tauri utiliza Rust por debajo, y es un requisito estricto para poder compilar la aplicación. Para continuar con esta opción, necesitas:
> 1. Instalar Rust desde [https://rustup.rs/](https://rustup.rs/).
> 2. Instalar las Herramientas de Compilación de C++ para el escritorio de Windows (disponibles a través de Visual Studio Installer).
> 
> **¿Deseas instalar estos requisitos tú mismo para que podamos continuar con Tauri, o prefieres que implemente esta misma arquitectura de (PostgreSQL Portable + Node Backend) pero utilizando el contenedor de Electron que ya tienes creado?**

## Open Questions

> [!IMPORTANT]
> - **Puerto de Base de Datos:** ¿Prefieres que Postgres corra en un puerto fijo (ej. 5432) o deberíamos asignar uno dinámico para evitar conflictos si la computadora ya tiene otro Postgres instalado?
> - **Tamaño del Proyecto:** Incluir PostgreSQL Portable añadirá ~80MB al peso del instalador (y ocupará ~250MB extraídos). ¿Esto es aceptable para el proyecto?
> - **Contraseñas iniciales:** Cuando arranquemos la base de datos por primera vez (initdb), se creará un usuario `postgres` sin contraseña por defecto, o podemos asignarle una fija interna.

## Proposed Changes

La arquitectura se compondrá de tres partes empaquetadas juntas:
1. El Frontend web renderizado por **WebView2**.
2. El Backend compilado a ejecutable `.exe` con **`pkg`**.
3. El motor de base de datos **PostgreSQL para Windows** (Binarios Zip).

### 1. Compilación del Backend
Modificaremos el backend para que pueda ser un ejecutable independiente:
- Instalaremos `pkg` (`npm install -g pkg`).
- Se creará un script de compilación para empaquetar `server.js` y el Prisma Client (engine) en un solo archivo binario `backend-windows.exe`.

### 2. Descarga de PostgreSQL Portable
No incluiremos los binarios en el control de versiones pesado. 
- Crearemos un script `.ps1` (PowerShell) o `.js` que, al ejecutarse en modo desarrollo, descargue los binarios `.zip` de PostgreSQL 16 para Windows y los extraiga en una carpeta `src-tauri/bin/pgsql`.

### 3. Configuración de Tauri (`/tauri-app`)
Crearemos un nuevo proyecto de Tauri desde cero.
- En `tauri.conf.json`:
  - `build.distDir`: apuntará a tu carpeta `../frontend`.
  - `bundle.externalBin`: registraremos nuestro ejecutable del backend.
  - `bundle.resources`: incluiremos la carpeta de binarios de `pgsql`.

### 4. Orquestación en Rust (Tauri Backend)
Escribiremos el código nativo (en `main.rs`) que hará la magia cuando el usuario haga doble clic en el ícono del colegio:
- **Verificación de DB:** Comprobar si existe la carpeta de datos en `%APPDATA%/SAE/data`.
- **Inicialización:** Si no existe, ejecutar `bin/pgsql/bin/initdb.exe -D <ruta> -U postgres`.
- **Arranque de DB:** Ejecutar `bin/pgsql/bin/pg_ctl.exe start -D <ruta>`.
- **Arranque de Sidecar:** Iniciar el ejecutable de Node.js (que conectará al postgres recién levantado).
- **Cierre Elegante:** Escuchar el evento de cierre de ventana, detener el sidecar y ejecutar `pg_ctl.exe stop` para apagar la base de datos de forma segura.

## Verification Plan

### Manual Verification
1. Compilar el backend con `pkg`.
2. Descargar los binarios e inicializar el servidor de desarrollo de Tauri (`cargo tauri dev`).
3. Verificar en el Administrador de Tareas que `postgres.exe` y `backend-windows.exe` se inician como procesos hijos de Tauri.
4. Cerrar la ventana y verificar que no queden procesos huérfanos de postgres bloqueando los puertos.
5. Generar el instalador `.msi` o `.exe` y probar la instalación limpia en el equipo.
