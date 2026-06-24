# SAE — Sistema Administrativo Escolar
## Colegio San Diego | v2.0.0 (PostgreSQL 16)

Sistema offline-first para administración escolar en red LAN.

---

## Requisitos

| Herramienta | Versión mínima |
|-------------|---------------|
| Node.js     | 18.x          |
| Docker      | 24.x          |
| Docker Compose | v2.x       |

---

## Instalación rápida

> Para ejecutar el proyecto en equipos del equipo de desarrollo, usar primero
> `docs/GUIA_EJECUCION_EQUIPO.md`. Esa guía incluye pasos para Windows,
> `npm.cmd`, Docker/PostgreSQL local y errores comunes.

### 1. Clonar y configurar variables de entorno

```bash
cd backend
cp .env.example .env
# Editar .env: JWT_SECRET mínimo 32 caracteres
```

### 2. Levantar PostgreSQL con Docker

```bash
# Desde la raíz del proyecto:
docker compose up -d postgres_sae

# Verificar que la BD está lista (healthcheck):
docker compose ps
```

Docker ejecuta automáticamente los scripts de `BD-ColegioSandiego/init-db/`:
- `01_esquema_base.sql` → crea las 30 tablas
- `02_configuracion.sql` → parámetros del sistema
- `03_roles.sql` → roles (si existe)
- `04_datos_iniciales.sql` → datos base (si existe)

### 3. Configurar Prisma y cargar datos de prueba

```bash
cd backend
npm install
npm run db:generate    # genera el Prisma Client
npm run db:baseline    # marca la migración init como aplicada
npm run db:seed        # carga usuarios, ciclo, grupos, alumnos de prueba
```

### 4. Arrancar el backend

```bash
npm run dev     # modo desarrollo con nodemon
# ó
npm start       # producción
```

El servidor estará disponible en: `http://localhost:3000`

---

## Credenciales de prueba

| Rol     | Usuario            | Contraseña   |
|---------|-------------------|---------------|
| ADMIN   | elizabeth.mendoza | sandiego2026 |
| ADMIN   | maria.dolores     | sandiego2026 |
| GESTOR  | laura.rios        | sandiego2026 |
| MAESTRA | mario.sanchez     | sandiego2026 |
| MAESTRA | patricia.nunez    | sandiego2026 |
## Uso en red LAN

Para acceder desde otras computadoras de la red:

1. El servidor detecta automáticamente su IP LAN
2. Los clientes cargan `http://<IP-SERVIDOR>:3000/config.js` 
   que inyecta `window.SAE_CONFIG.API_BASE` con la IP real
3. CORS acepta automáticamente cualquier origen de la misma subred `/24`

**Verificar IP del servidor:**
```bash
# El endpoint /health devuelve información del servidor
curl http://localhost:3000/health
```

## Acceso desde Internet (Túnel Cloudflare)

Para exponer el sistema temporalmente a internet de forma segura sin configurar puertos en el router:

```bash
cd backend
npm run tunnel
```

Esto generará una URL pública temporal (ej: `https://xxxx.trycloudflare.com`) que podrás compartir. El sistema detectará automáticamente que está corriendo bajo Cloudflare y ajustará el CORS y las rutas de la API de forma transparente.

---

## Scripts disponibles

```bash
# Desarrollo
npm run dev              # nodemon con recarga automática
npm run db:studio        # Prisma Studio (explorador visual de BD)

# Base de datos
npm run db:generate      # genera Prisma Client desde schema.prisma
npm run db:migrate       # crea nueva migración (desarrollo)
npm run db:deploy        # aplica migraciones pendientes (producción)
npm run db:baseline      # marca migración init_postgresql como aplicada (1ra vez)
npm run db:setup         # generate + baseline + seed (setup completo inicial)
npm run db:seed          # carga datos de prueba
npm run db:push          # sincroniza schema sin historial (dev rápido)
npm run db:reset         # PELIGROSO: reset completo (solo desarrollo)

# Respaldos
npm run db:backup        # crea respaldo SQL con timestamp
npm run db:backup -- --label=previo-actualizacion
npm run db:restore       # restaura respaldo (requiere confirmación)
npm run db:restore -- --list  # lista respaldos disponibles

# Calidad
npm test                 # ejecuta tests (Vitest)
npm run lint             # ESLint
npm run format           # Prettier
```

---

## Arquitectura

```
colegio-sandiego/
├── BD-ColegioSandiego/        # Definición PostgreSQL v6
│   ├── ERD_SAE.md             # Diagrama entidad-relación
│   ├── init-db/               # Scripts SQL de inicialización Docker
│   │   ├── 01_esquema_base.sql
│   │   └── 02_configuracion.sql
│   └── docker-compose.yml
│
├── backend/
│   ├── prisma/
│   │   ├── schema.prisma      # Modelos Prisma (PostgreSQL v6, 30 tablas)
│   │   ├── seed.js            # Datos iniciales de prueba
│   │   └── migrations/        # Historial de migraciones
│   │
│   ├── scripts/
│   │   ├── db-backup.js       # Script de respaldo
│   │   ├── db-restore.js      # Script de restauración
│   │   └── db-reset.js        # Reset completo (solo dev)
│   │
│   └── src/
│       ├── config/            # env.js, database.js
│       ├── controllers/       # Una carpeta por módulo
│       ├── middleware/        # auth, error, rbac, validate
│       ├── repositories/      # Capa de datos (Prisma queries)
│       ├── routes/            # Express router
│       ├── services/          # Lógica de negocio
│       └── utils/             # hash, jwt, constants, response
│
├── docs/
│   └── DB_MIGRATION_ANALYSIS.md   # Análisis de migración SQLite → PostgreSQL
│
├── frontend/                  # Paneles HTML existentes (sin modificar)
│   ├── admin_panel.html
│   ├── gestor_panel.html
│   └── maestra_panel.html
│
└── docker-compose.yml         # Orquestación PostgreSQL + Backend
```

---

## Base de datos PostgreSQL v6

### Tablas principales (30 en total)

| Bloque        | Tablas |
|---------------|--------|
| Seguridad     | usuario, rol, usuario_rol |
| Catálogos     | nivel_educativo, ciclo_escolar |
| Académico     | grupo, materia, grupo_materia, periodo_evaluacion |
| Comunidad     | tutor, alumno, tutor_alumno |
| Inscripciones | plan_pago, inscripcion_ciclo |
| Resultados    | calificacion, asistencia |
| Finanzas      | tarifa, calendario_pago, pago, aplicacion_pago, recargo, movimiento_saldo |
| Facturación   | factura, factura_pago |
| Becas         | beca, solicitud_beca, asignacion_beca |
| Soporte       | ventana_inscripcion_temprana, documento, notificacion |
| Auditoría     | intento_login, log_auditoria, configuracion_sistema |

### Mapeo de roles

| Código BD            | Rol de sistema |
|---------------------|----------------|
| administrador        | ADMIN          |
| directora            | ADMIN          |
| empleado             | GESTOR         |
| docente              | MAESTRA        |

---

## Proceso de deploy en producción

```bash
# 1. En el servidor, levantar PostgreSQL
docker compose up -d postgres_sae

# 2. Instalar dependencias
cd backend && npm ci --production

# 3. Generar Prisma Client
npm run db:generate

# 4. Marcar baseline (solo la primera vez)
npm run db:baseline

# 5. Si hay migraciones nuevas, aplicarlas
npm run db:deploy

# 6. Seed inicial (solo la primera vez)
npm run db:seed

# 7. Arrancar servidor
NODE_ENV=production npm start
```

---

## Respaldos automáticos

El sistema puede configurarse para respaldos automáticos:

```bash
# Respaldo manual con etiqueta
npm run db:backup -- --label=antes-actualizacion

# Los últimos 10 respaldos se conservan automáticamente
# Ubicación: ./backups/sae_backup_YYYY-MM-DD_HH-MM-SS.sql
```

---

## Variables de entorno

Ver `.env.example` para la lista completa. Las más importantes:

```env
DATABASE_URL=postgresql://sae_admin:SaeColegio2026@localhost:5432/sae_colegio_san_diego
JWT_SECRET=tu-secreto-aqui-minimo-32-caracteres
PORT=3000
NODE_ENV=development
CORS_ORIGIN=http://localhost:3000,http://192.168.1.100:3000
```
