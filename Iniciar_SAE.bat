@echo off
title Iniciando SAE Colegio San Diego
echo ===================================================
echo Iniciando base de datos en Docker...
echo ===================================================
docker compose up -d postgres_sae

echo.
echo ===================================================
echo Iniciando servidor backend...
echo ===================================================
cd backend
start "" http://localhost:3000/auth/login.html
npm.cmd start
