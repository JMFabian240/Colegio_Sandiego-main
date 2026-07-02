@echo off
title Iniciando SAE Colegio San Diego
echo ===================================================
echo Iniciando base de datos en Docker...
echo ===================================================
docker compose up -d postgres_sae

echo.
echo ===================================================
echo Iniciando servidor backend y Frontend Antiguo...
echo ===================================================
cd backend
start cmd /k "title Backend SAE && npm run dev"
start "" http://localhost:3000/auth/login.html

echo.
echo ===================================================
echo Iniciando Frontend React (Nuevo)...
echo ===================================================
cd ../frontend-react
start cmd /k "title Frontend React && npm run dev"
start "" http://localhost:5173/login
