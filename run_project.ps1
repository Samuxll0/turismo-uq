# Script de Arranque Rapido para TurismoUQ (Backend Spring Boot + Frontend Angular)

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Iniciando Proyecto Integrador: TurismoUQ" -ForegroundColor Green
Write-Host "Oracle Database XE 21c -> Spring Boot 3 -> Angular" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

# 0. Liberar puerto 8080 si hay un proceso previo
$puerto8080 = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
if ($puerto8080) {
    Write-Host "Liberando puerto 8080 ocupado por proceso previo PID $($puerto8080.OwningProcess)..." -ForegroundColor Yellow
    Stop-Process -Id $puerto8080.OwningProcess -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# 1. Iniciar Backend en segundo plano
Write-Host "`n[1/2] Iniciando Backend Spring Boot en puerto 8080..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PSScriptRoot\backend'; .\mvnw.cmd spring-boot:run"

# Esperar a que el backend este listo en el puerto 8080
Write-Host "Esperando a que el backend inicialice el pool Hikari y JPA en el puerto 8080..." -ForegroundColor DarkGray
$maxAttempts = 30
$attempt = 0
while ($attempt -lt $maxAttempts) {
    Start-Sleep -Seconds 1
    $conn = Test-NetConnection -ComputerName localhost -Port 8080 -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($conn) {
        Write-Host "Backend listo y respondiendo en http://localhost:8080" -ForegroundColor Green
        break
    }
    $attempt++
}

# 2. Iniciar Frontend en segundo plano
Write-Host "`n[2/2] Iniciando Frontend Angular en http://localhost:4200..." -ForegroundColor Cyan
$env:PATH = "C:\Program Files\nodejs;$env:PATH"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$env:PATH = 'C:\Program Files\nodejs;`$env:PATH'; cd '$PSScriptRoot\frontend'; & 'C:\Program Files\nodejs\npm.cmd' start"

Write-Host "`nListo! Abre tu navegador en: http://localhost:4200" -ForegroundColor Yellow
Write-Host "API Backend disponible en: http://localhost:8080/api" -ForegroundColor Yellow
