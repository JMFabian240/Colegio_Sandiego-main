## Identidad del Proyecto
- Nombre: SAE (Sistema Administrativo Escolar)
- Propósito: Sistema de gestión escolar para registro de pagos, gestión de alumnos, tutores y calificaciones del Colegio San Diego.
- Distribución: Cliente de escritorio (Electron) y aplicación web (LAN) apoyada por un servidor Node.js y base de datos PostgreSQL.

## Stack Tecnológico
- **Frontend (`frontend-react/`)**: React 19, Vite, TypeScript, TailwindCSS v4, Zustand, Axios, React Router, Recharts.
- **Backend (`backend/`)**: Node.js, Express, Prisma ORM, JWT, express-validator, Vitest.
- **Base de Datos (`BD-ColegioSandiego/`)**: PostgreSQL.
- **Escritorio (`electron-app/`)**: Electron v30, Electron Builder.

## Arquitectura de Paquetes
- `frontend-react/` → SPA construida con Vite, se comunica vía API REST con el backend.
- `backend/` → API REST en Express, provee endpoints HTTP, contiene la lógica de negocio y usa Prisma para conectar con PostgreSQL.
- `BD-ColegioSandiego/` → Scripts SQL, backups e inicialización del esquema de la base de datos PostgreSQL.
- `electron-app/` → Cliente instalable de escritorio que provee una ventana para el Frontend.

## Flujo de Datos
Usuario → UI React (Zustand)
       → Axios (Peticiones HTTP/REST)
       → Express Backend (Rutas + Controladores)
       → Prisma ORM
       → PostgreSQL Base de Datos

## Convenciones de Código
- **Frontend**: TypeScript estricto, uso de TailwindCSS para estilos, componentes funcionales en PascalCase (`MiComponente.tsx`).
- **Backend**: JavaScript/Node.js, rutas bien separadas de los controladores, validación de datos de entrada con `express-validator`.
- Variables y funciones auxiliares en `camelCase`.
- Archivos en `kebab-case` para utilidades y rutas.

## Organización de Archivos y Directorios
- **Priorizar el Orden:** Mantener una estructura limpia tanto en código como en documentación.
- **Creación de Directorios:** Agrupar archivos relacionados en subdirectorios (ej. `controllers`, `routes`, `validators` en backend; `components`, `hooks`, `store` en frontend).

## Reglas por Capa
- **Frontend**: NUNCA importar o intentar conectarse a la base de datos o Prisma directamente. Toda obtención de datos se hace a través de Axios.
- **Backend**: TODA comunicación con la base de datos va por medio de Prisma (`prisma/schema.prisma`).
- **Electron**: No incluir lógica de negocio, solo orquesta la ventana del cliente.

## Reglas de Base de Datos
- Toda modificación de estructura se define en `backend/prisma/schema.prisma`.
- Nunca modificar la estructura de la base de datos productiva sin crear su respectiva migración (`prisma migrate dev`).
- Scripts crudos (como dumps y backups) deben residir en `BD-ColegioSandiego/` o `backend/scripts/`.

## Documentación
- **Docs-First**: Toda funcionalidad sustancial debe estar documentada en `/docs` antes o a la par de su implementación.
- **Ingeniería Inversa**: Al editar código antiguo no documentado, reconstruir sus requerimientos y flujos.
- En caso de existir artefactos en `docs/design/`, consultarlos antes de programar.

## Uso de Skills y Herramientas
- Consultar las skills disponibles y personalizadas del proyecto.
- Seguir el orden lógico de requerimientos → diseño → código al crear features grandes.

## Prohibiciones
- No instalar dependencias (npm) sin avisar y consultar primero.
- No eliminar archivos de forma destructiva sin confirmar con el usuario.
- No cambiar la estructura de carpetas (frontend/backend) sin un plan justificado.
- No mezclar lógica de negocio del servidor dentro del Frontend React.
- No exponer rutas privadas del Backend sin validación de JWT.
- No subir archivos `.env`, `.env.local` o binarios y ejecutables (`node_modules`) al repositorio.
