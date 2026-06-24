# Reversión a Arquitectura Original (Docker + Node.js)

Dada la complejidad y los problemas de red asociados con el empaquetado del binario completo (Electron + PostgreSQL), hemos decidido volver a la arquitectura cliente-servidor clásica que se tenía antes.

## Propósito del Cambio

- Eliminar la dependencia de un instalador `.exe` pesado (Electron).
- Volver a usar Docker para aislar la base de datos limpiamente, o permitir instalación nativa.
- Levantar el entorno local usando los comandos clásicos (`npm start`, `npx prisma db push`).

> [!WARNING]
> Anteriormente descubrimos que **ya tienes ocupado el puerto 5432** en tu computadora (probablemente por otro PostgreSQL).
> He ajustado el `docker-compose.yml` y el `.env` para que usen el puerto **5433** por defecto, evitando así conflictos.

## Proposed Changes

### Backend

- [x] **`backend/.env`**: Se ajustará la variable de entorno `DATABASE_URL` para conectarse a `localhost:5433` mediante el usuario original `sae_admin`.
- [x] **`backend/src/server.js`**: Se eliminará el bloque de código que forzaba el "auto-seed" al iniciar el backend compilado.
- [x] **`docker-compose.yml`**: Nos aseguraremos de que el puerto expuesto del contenedor de postgres mapée del `5432` interno al `5433` externo de tu PC.

### Directorios y Archivos Muertos
- La carpeta `electron-app/` y todos sus archivos (`main.js`, binarios, instaladores) quedan depreciados. No afectan al sistema y podemos ignorarlos o eliminarlos más adelante.

## Verification Plan

### Manual Verification
Te indicaré cómo encender tu base de datos y tu servidor con 3 simples comandos:
1. `docker-compose up -d postgres_sae` (para arrancar la base de datos).
2. `npx prisma db push` y `npm run seed` (para crear las tablas e inyectar usuarios).
3. `npm run dev` (para correr el backend en modo desarrollo o `npm start` para producción).
