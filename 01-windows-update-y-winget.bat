@echo off
REM =========================================================
REM Script 1: Windows Update + Winget Setup
REM =========================================================
REM Este script debe ejecutarse como ADMINISTRADOR
REM Actualiza Windows y configura winget
REM =========================================================

setlocal enabledelayedexpansion

REM Verificar si se ejecuta como administrador
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo ERROR: Este script necesita permisos de ADMINISTRADOR
    echo Por favor, ejecute como administrador (click derecho ^> Ejecutar como administrador)
    echo.
    pause
    exit /b 1
)

set "LOG_FILE=%USERPROFILE%\Desktop\install.log"

cls
echo.
echo ============================================
echo SCRIPT 1: WINDOWS UPDATE ^+ WINGET SETUP
echo ============================================
echo.
echo Este script va a:
echo   1. Ejecutar Windows Update
echo   2. Configurar/actualizar winget
echo.
echo IMPORTANTE: Despues se puede reiniciar el PC
echo.
pause

REM =========================================================
REM PASO 1: Windows Update
REM =========================================================
cls
echo.
echo [1/2] Iniciando Windows Update...
echo.
echo Esto puede tardar varios minutos...
echo.

echo [%date% %time%] Iniciando Windows Update >> "!LOG_FILE!"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "if (-not (Get-Module PSWindowsUpdate -ListAvailable)) { Install-Module PSWindowsUpdate -Force -SkipPublisherCheck -Confirm:$false } ; Import-Module PSWindowsUpdate ; Get-WindowsUpdate -AcceptAll -Install" >> "!LOG_FILE!" 2>&1

if %errorLevel% equ 0 (
    echo.
    echo [OK] Windows Update completado
    echo [%date% %time%] Windows Update completado >> "!LOG_FILE!"
) else (
    echo.
    echo [ADVERTENCIA] Hubo un problema con Windows Update, pero continuamos
    echo [%date% %time%] Advertencia en Windows Update >> "!LOG_FILE!"
)

echo.
pause

REM =========================================================
REM PASO 2: Actualizar Winget
REM =========================================================
cls
echo.
echo [2/2] Configurando/Actualizando winget...
echo.

echo [%date% %time%] Actualizando Winget >> "!LOG_FILE!"
REM Actualizar winget a la ultima version
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Add-AppxPackage -RegisterByFamilyName -MainPackage" >> "!LOG_FILE!" 2>&1

REM Esperar a que winget este listo
timeout /t 5 /nobreak

echo [OK] Winget configurado
echo [%date% %time%] Winget configurado >> "!LOG_FILE!"

echo.
echo.
echo ============================================
echo PASO 1 COMPLETADO
echo ============================================
echo.
echo Siguiente paso:
echo   1. OPCIONAL pero RECOMENDADO: Reinicia el PC
echo      (especialmente si se instalo mucho)
echo   2. Luego ejecuta: Script 2 - Instalar Software
echo.

set /p reinicio="Deseas reiniciar el PC ahora? (S/N): "
if /i "%reinicio%"=="S" (
    echo.
    echo El PC se reiniciara en 60 segundos...
    echo Puedes presionar CTRL+C para cancelar
    echo.
    timeout /t 60
    shutdown /r /t 30 /c "Reinicio solicitado por script"
) else (
    echo.
    echo OK, el PC NO sera reiniciado
    echo Cuando estes listo, ejecuta el Script 2
    echo.
)

pause
