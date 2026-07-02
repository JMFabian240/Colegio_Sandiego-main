@echo off
title SAE Colegio San Diego - Servidor LAN
echo ==================================================================
echo   Iniciando el despliegue del Sistema SAE en Docker (LAN)...
echo ==================================================================
echo.
echo [1/3] Levantando contenedores (Construyendo Backend y Frontend)...
docker compose up -d --build

echo.
echo [2/3] Esperando a que la base de datos se inicialice (20s)...
timeout /t 20 /nobreak >nul

echo.
echo [3/3] Ejecutando configuracion inicial (Seed)...
docker compose exec -u node sae-backend npx prisma db seed

echo.
echo ==================================================================
echo   ¡Despliegue completado exitosamente!
echo   El sistema esta disponible en: http://localhost:3000
echo   (Los equipos en la red local pueden acceder por la IP de esta PC)
echo ==================================================================
echo Abriendo en el navegador...
start "" http://localhost:3000
pause
