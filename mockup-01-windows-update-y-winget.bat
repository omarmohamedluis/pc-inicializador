@echo off
REM =========================================================
REM MOCKUP Script 1: Windows Update + Winget Setup
REM =========================================================
REM Simula sin hacer cambios reales
REM =========================================================

setlocal enabledelayedexpansion

set "LOG_FILE=%USERPROFILE%\Desktop\install.log.MOCKUP"

cls
echo.
echo ============================================
echo [MOCKUP] SCRIPT 1: WINDOWS UPDATE + WINGET
echo ============================================
echo.

echo [%date% %time%] [MOCKUP] ============================================================ >> "!LOG_FILE!"
echo [%date% %time%] [MOCKUP] INICIANDO SCRIPT 1: WINDOWS UPDATE + WINGET >> "!LOG_FILE!"
echo [%date% %time%] [MOCKUP] ============================================================ >> "!LOG_FILE!"

REM =========================================================
REM PASO 1: Windows Update (Simulado)
REM =========================================================
cls
echo.
echo [MOCKUP] [1/2] Iniciando Windows Update...
echo.
echo Simulando descarga e instalacion...
echo.

echo [%date% %time%] [MOCKUP] Iniciando Windows Update >> "!LOG_FILE!"

REM Simular progreso
for /l %%i in (1,1,5) do (
    echo [MOCKUP] Windows Update - descargando actualizaciones... %%i/5
    timeout /t 1 /nobreak
)

echo.
echo [OK] Windows Update completado (SIMULADO)
echo [%date% %time%] [MOCKUP] Windows Update completado >> "!LOG_FILE!"

REM =========================================================
REM PASO 2: Winget Setup (Simulado)
REM =========================================================
cls
echo.
echo [MOCKUP] [2/2] Configurando/Actualizando winget...
echo.

echo [%date% %time%] [MOCKUP] Actualizando Winget >> "!LOG_FILE!"

REM Simular progreso
for /l %%i in (1,1,3) do (
    echo [MOCKUP] Winget - configurando... %%i/3
    timeout /t 1 /nobreak
)

echo.
echo [OK] Winget configurado (SIMULADO)
echo [%date% %time%] [MOCKUP] Winget configurado >> "!LOG_FILE!"

echo.
echo.
echo ============================================
echo [MOCKUP] PASO 1 COMPLETADO
echo ============================================
echo.
echo Siguiente paso:
echo   1. OPCIONAL: Reinicia el PC
echo   2. Luego ejecuta: Script 2 - Instalar Software
echo.
echo El registro de simulacion esta en:
echo   !LOG_FILE!
echo.

set /p reinicio="[MOCKUP] Deseas simular reinicio? (S/N): "

echo [%date% %time%] [MOCKUP] Paso 1 finalizado >> "!LOG_FILE!"

timeout /t 1 /nobreak
exit /b 0
