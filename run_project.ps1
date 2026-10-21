# Script de Arranque Rapido para TurismoUQ (Backend Spring Boot + Frontend Angular)

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Iniciando Proyecto Integrador: TurismoUQ" -ForegroundColor Green
Write-Host "Oracle Database XE 21c -> Spring Boot 3 -> Angular" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

# 1. Iniciar Backend en segundo plano
Write-Host "`n[1/2] Iniciando Backend Spring Boot en puerto 8080..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PSScriptRoot\backend'; .\mvnw.cmd spring-boot:run"

# Esperar 4 segundos
Start-Sleep -Seconds 4

# 2. Iniciar Frontend en segundo plano
Write-Host "[2/2] Iniciando Frontend Angular en http://localhost:4200..." -ForegroundColor Cyan
$env:PATH = "C:\Program Files\nodejs;$env:PATH"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$env:PATH = 'C:\Program Files\nodejs;`$env:PATH'; cd '$PSScriptRoot\frontend'; & 'C:\Program Files\nodejs\npm.cmd' start"

Write-Host "`nListo! Abre tu navegador en: http://localhost:4200" -ForegroundColor Yellow
Write-Host "API Backend disponible en: http://localhost:8080/api" -ForegroundColor Yellow
