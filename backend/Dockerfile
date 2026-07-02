# ============================================================
# SAE Colegio San Diego — Dockerfile Multi-stage
# Node.js 20 LTS · imagen mínima · PostgreSQL 16
# ============================================================

FROM node:20-alpine AS base
# Instalar dependencias del sistema para Prisma y PostgreSQL client
RUN apk add --no-cache openssl postgresql-client

# ── 1. Construir el Frontend ─────────────────────────────────
FROM base AS frontend-builder
WORKDIR /frontend-react
COPY frontend-react/package*.json ./
RUN npm ci
COPY frontend-react/ ./
RUN npm run build

# ── 2. Dependencias del Backend ──────────────────────────────
FROM base AS backend-deps
WORKDIR /backend
COPY backend/package*.json ./
RUN npm ci --omit=dev

# ── 3. Construcción final (Producción) ────────────────────────
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production

# Copiar dependencias y código del backend
COPY --from=backend-deps /backend/node_modules ./node_modules
COPY backend/ ./

# Copiar build del frontend a la raíz del contenedor para que coincida con path.resolve
COPY --from=frontend-builder /frontend-react/dist /frontend-react/dist

# Crear directorio de backups y transferir propiedad al usuario node (hardening)
RUN mkdir -p /app/backups && chown -R node:node /app /frontend-react

# Hardening: ejecutar el proceso Node como usuario no-root
USER node

# Generar Prisma Client para el entorno de producción (como usuario node)
RUN npx prisma generate

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "src/server.js"]
