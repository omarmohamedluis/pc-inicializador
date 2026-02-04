@echo off
REM =========================================================
REM MOCKUP Script 2: Instalar Software desde install.json
REM =========================================================
REM Simula sin instalar nada realmente
REM =========================================================

setlocal enabledelayedexpansion

set "LOG_FILE=%USERPROFILE%\Desktop\install.log.MOCKUP"
set "SCRIPT_DIR=%~dp0"
set "INSTALL_JSON=%SCRIPT_DIR%install.json"

cls
echo.
echo ============================================
echo [MOCKUP] SCRIPT 2: INSTALAR SOFTWARE
echo ============================================
echo.
echo Leyendo lista de paquetes desde install.json
echo.

if not exist "!INSTALL_JSON!" (
    echo ERROR: No se encontro install.json
    pause
    exit /b 1
)

echo [%date% %time%] [MOCKUP] ============================================================ >> "!LOG_FILE!"
echo [%date% %time%] [MOCKUP] INICIANDO SCRIPT 2: INSTALAR SOFTWARE >> "!LOG_FILE!"
echo [%date% %time%] [MOCKUP] ============================================================ >> "!LOG_FILE!"

REM =========================================================
REM EXTRAER PAQUETES DE install.json (Simulado)
REM =========================================================
set "TEMP_PACKAGES=%SCRIPT_DIR%temp_packages.txt"
del /f /q "!TEMP_PACKAGES!" >nul 2>&1

echo [%date% %time%] [MOCKUP] Procesando install.json >> "!LOG_FILE!"
echo Leyendo paquetes desde install.json...

REM Usar PowerShell para extraer los PackageIdentifier del JSON
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$json = Get-Content '!INSTALL_JSON!' | ConvertFrom-Json; " ^
    "$packages = $json.Sources[0].Packages; " ^
    "foreach ($pkg in $packages) { if ($pkg.PackageIdentifier) { Add-Content '!TEMP_PACKAGES!' $pkg.PackageIdentifier } }"

if not exist "!TEMP_PACKAGES!" (
    echo ERROR: No se pudo procesar install.json
    pause
    exit /b 1
)

REM Contar total de paquetes
for /f %%C in ('find /c /v "" "!TEMP_PACKAGES!"') do set TOTAL=%%C

echo.
echo [MOCKUP] Se encontraron !TOTAL! paquetes en install.json
echo.
echo ===============================================
echo [MOCKUP] Iniciando simulacion de instalacion...
echo ===============================================
echo.
pause

REM =========================================================
REM SIMULAR INSTALACION DE PAQUETES
REM =========================================================
cls
echo.
echo ===============================================
echo [MOCKUP] INSTALANDO !TOTAL! PAQUETES (SIMULADO)
echo ===============================================
echo.

set contador=0
set exitosos=0
set fallidos=0

for /f "tokens=*" %%P in ('type "!TEMP_PACKAGES!"') do (
    set /a contador+=1
    set "PACKAGE=%%P"
    
    echo [%date% %time%] [MOCKUP] [!contador!/%TOTAL%] Simulando instalacion de !PACKAGE! >> "!LOG_FILE!"
    
    REM Mostrar encabezado de instalacion
    echo.
    echo [!contador!/%TOTAL%] =====================================
    echo [MOCKUP] Instalando: !PACKAGE!
    echo =====================================
    
    REM Simular progreso
    timeout /t 1 /nobreak
    
    if !contador! equ 3 (
        REM Simular un fallo ocasional
        echo [!] Problema durante simulacion - continuando...
        echo [%date% %time%] [MOCKUP] [!] Fallo simulado en !PACKAGE! >> "!LOG_FILE!"
        set /a fallidos+=1
    ) else (
        set /a exitosos+=1
        echo [OK] Simulado correctamente
        echo [%date% %time%] [MOCKUP] [OK] !PACKAGE! simulado correctamente >> "!LOG_FILE!"
    )
)

REM Limpiar archivo temporal
del /f /q "!TEMP_PACKAGES!" >nul 2>&1

REM =========================================================
REM RESUMEN FINAL
REM =========================================================
cls
echo.
echo ===============================================
echo [MOCKUP] SIMULACION COMPLETADA
echo ===============================================
echo.
echo Resultados:
echo   Exitosos:  !exitosos!/%TOTAL%
echo   Fallidos:  !fallidos!/%TOTAL%
echo.

if !fallidos! equ 0 (
    echo [OK] Todos los paquetes se simularon correctamente
) else (
    echo [!] Algunos paquetes tuvieron problemas simulados
    echo    Revisa el log para detalles
)

echo.
echo Ubicaciones automaticas de accesos directos:
echo   - Escritorio (para aplicaciones con acceso directo)
echo   - Menu Inicio ^> Programas
echo   - Taskbar (algunos se anclan automaticamente)
echo.
echo Archivo de registro:
echo   !LOG_FILE!
echo.
echo [%date% %time%] [MOCKUP] Simulacion completada - Exitosos: !exitosos! Fallidos: !fallidos! / %TOTAL% >> "!LOG_FILE!"
echo [%date% %time%] [MOCKUP] ============================================================ >> "!LOG_FILE!"

echo.
echo [MOCKUP] NOTA: Esta fue una simulacion, no se instalo nada
echo.
echo Presiona una tecla para finalizar...
pause >nul
