@echo off
REM =========================================================
REM Script 2: Instalar Software desde install.json
REM =========================================================
REM Lee dinamicamente de install.json
REM Soporta n paquetes sin hardcoding
REM Debe ejecutarse como ADMINISTRADOR
REM Reutilizable - instala/actualiza paquetes segun .json
REM =========================================================

setlocal enabledelayedexpansion

REM Verificar si se ejecuta como administrador
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo ERROR: Este script necesita permisos de ADMINISTRADOR
    echo Por favor, ejecute como administrador (click derecho - Ejecutar como administrador)
    echo.
    pause
    exit /b 1
)

set "LOG_FILE=%USERPROFILE%\Desktop\install.log"
set "SCRIPT_DIR=%~dp0"
set "INSTALL_JSON=%SCRIPT_DIR%install.json"

cls
echo.
echo ============================================
echo SCRIPT 2: INSTALAR SOFTWARE
echo ============================================
echo.
echo Leyendo lista de paquetes desde install.json
echo.

REM Verificar que install.json existe
if not exist "!INSTALL_JSON!" (
    echo ERROR: No se encontro install.json
    echo Ubicacion esperada: !INSTALL_JSON!
    echo [%date% %time%] ERROR: install.json no encontrado >> "!LOG_FILE!"
    pause
    exit /b 1
)

echo [%date% %time%] ============================================================ >> "!LOG_FILE!"
echo [%date% %time%] INICIANDO SCRIPT 2: INSTALAR SOFTWARE >> "!LOG_FILE!"
echo [%date% %time%] ============================================================ >> "!LOG_FILE!"

REM Verificar que winget esta disponible
winget --version >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: winget no esta disponible
    echo Asegurate de ejecutar primero el Script 1
    echo [%date% %time%] ERROR: winget no disponible >> "!LOG_FILE!"
    pause
    exit /b 1
)

REM =========================================================
REM EXTRAER PAQUETES DE install.json
REM =========================================================
set "TEMP_PACKAGES=%SCRIPT_DIR%temp_packages.txt"
del /f /q "!TEMP_PACKAGES!" >nul 2>&1

echo [%date% %time%] Procesando install.json >> "!LOG_FILE!"
echo Leyendo paquetes desde install.json...

REM Usar PowerShell para extraer los PackageIdentifier del JSON
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$json = Get-Content '!INSTALL_JSON!' | ConvertFrom-Json; " ^
    "$packages = $json.Sources[0].Packages; " ^
    "foreach ($pkg in $packages) { if ($pkg.PackageIdentifier) { Add-Content '!TEMP_PACKAGES!' $pkg.PackageIdentifier } }"

if not exist "!TEMP_PACKAGES!" (
    echo ERROR: No se pudo procesar install.json
    echo [%date% %time%] ERROR: Fallo al procesar install.json >> "!LOG_FILE!"
    pause
    exit /b 1
)

REM Contar total de paquetes
for /f %%C in ('find /c /v "" "!TEMP_PACKAGES!"') do set TOTAL=%%C

echo.
echo Se encontraron %TOTAL% paquetes en install.json
echo.
echo ===============================================
echo Iniciando instalacion...
echo Algunos pueden tardar bastante tiempo
echo ===============================================
echo.
pause

REM =========================================================
REM INSTALAR PAQUETES
REM =========================================================
cls
echo.
echo ===============================================
echo INSTALANDO %TOTAL% PAQUETES
echo ===============================================
echo.

set contador=0
set exitosos=0
set fallidos=0

for /f "tokens=*" %%P in ('type "!TEMP_PACKAGES!"') do (
    set /a contador+=1
    set "PACKAGE=%%P"
    
    echo [%date% %time%] [!contador!/%TOTAL%] Instalando !PACKAGE! >> "!LOG_FILE!"
    
    REM Mostrar encabezado de instalacion
    echo.
    echo [!contador!/%TOTAL%] =====================================
    echo Instalando: !PACKAGE!
    echo =====================================
    
    REM Instalar paquete - MOSTRAR OUTPUT EN TIEMPO REAL (sin >nul)
    winget install -e --id !PACKAGE! --accept-package-agreements --accept-source-agreements --no-upgrade 2>&1 >> "!LOG_FILE!"
    
    if !errorLevel! equ 0 (
        set /a exitosos+=1
        echo [OK] Instalado correctamente
        echo [%date% %time%] [OK] !PACKAGE! instalado correctamente >> "!LOG_FILE!"
    ) else (
        set /a fallidos+=1
        echo [!] Problema durante instalacion - continuando...
        echo [%date% %time%] [!] Fallo en !PACKAGE! >> "!LOG_FILE!"
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
echo INSTALACION COMPLETADA
echo ===============================================
echo.
echo Resultados:
echo   Exitosos:  !exitosos!/%TOTAL%
echo   Fallidos:  !fallidos!/%TOTAL%
echo.

if !fallidos! equ 0 (
    echo [OK] Todos los paquetes se instalaron correctamente
) else (
    echo [!] Algunos paquetes tuvieron problemas, pero continuamos
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
echo [%date% %time%] Instalacion completada - Exitosos: !exitosos! Fallidos: !fallidos! / %TOTAL% >> "!LOG_FILE!"
echo [%date% %time%] ============================================================ >> "!LOG_FILE!"

echo.
echo NOTA IMPORTANTE:
echo Si se instalaron componentes criticos como:
echo   - .NET SDK, runtimes de Visual C++
echo   - Drivers o codecs
echo.
echo Es RECOMENDABLE reiniciar el PC antes de continuar
echo.
echo Presiona una tecla para finalizar...
pause >nul
