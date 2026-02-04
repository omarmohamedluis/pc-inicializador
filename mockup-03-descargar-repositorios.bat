@echo off
REM =========================================================
REM MOCKUP Script 3: Descargar Repositorios GitHub
REM =========================================================
REM Simula sin clonar nada realmente
REM =========================================================

setlocal enabledelayedexpansion

cls
echo.
echo ============================================
echo [MOCKUP] SCRIPT 3: REPOSITORIOS GITHUB
echo ============================================
echo.

set "LOG_FILE=%USERPROFILE%\Desktop\install.log.MOCKUP"
set "REPOS_DIR=%USERPROFILE%\Desktop\repositorios"
set "SCRIPT_DIR=%~dp0"
set "REPOS_JSON=%SCRIPT_DIR%repos.json"

echo [%date% %time%] [MOCKUP] ============================================================ >> "!LOG_FILE!"
echo [%date% %time%] [MOCKUP] INICIANDO SCRIPT 3: DESCARGAR REPOSITORIOS GITHUB >> "!LOG_FILE!"
echo [%date% %time%] [MOCKUP] ============================================================ >> "!LOG_FILE!"

REM Verificar que repos.json existe
if not exist "!REPOS_JSON!" (
    echo ERROR: No se encontro repos.json
    echo [%date% %time%] [MOCKUP] ERROR: repos.json no encontrado >> "!LOG_FILE!"
    pause
    exit /b 1
)

echo [%date% %time%] [MOCKUP] repos.json encontrado >> "!LOG_FILE!"

REM =========================================================
REM AUTENTICACION GITHUB (Simulado)
REM =========================================================
echo.
echo ============================================
echo [MOCKUP] AUTENTICACION GITHUB
echo ============================================
echo.

REM Verificar si ya existe el token
if defined GITHUB_TOKEN (
    echo [OK] Token de GitHub detectado (SIMULADO)
    echo [%date% %time%] [MOCKUP] Token detectado >> "!LOG_FILE!"
    goto TOKEN_OK
)

REM Pedir token para simular
:PEDIR_TOKEN
echo.
echo [MOCKUP] Necesitas un token personal de GitHub para repos privados
echo.
set /p GITHUB_TOKEN="[MOCKUP] Ingresa tu token (minimo 20 caracteres): "

if "!GITHUB_TOKEN!"=="" (
    echo.
    echo [ADVERTENCIA] Token vacio - Intenta de nuevo
    echo [%date% %time%] [MOCKUP] Intento fallido: Token vacio >> "!LOG_FILE!"
    timeout /t 2 /nobreak
    cls
    goto PEDIR_TOKEN
)

REM Validar longitud
set "TOKEN_LEN=0"
for /L %%A in (0,1,200) do (
    if "!GITHUB_TOKEN:~%%A,1!"=="" (
        set "TOKEN_LEN=%%A"
        goto TOKEN_LEN_OK
    )
)

:TOKEN_LEN_OK
if !TOKEN_LEN! lss 20 (
    echo.
    echo [ADVERTENCIA] Token muy corto - debe tener al menos 20 caracteres
    echo [%date% %time%] [MOCKUP] Intento fallido: Token corto (!TOKEN_LEN! caracteres) >> "!LOG_FILE!"
    timeout /t 2 /nobreak
    cls
    set "GITHUB_TOKEN="
    goto PEDIR_TOKEN
)

echo [%date% %time%] [MOCKUP] Token proporcionado - configurando (SIMULADO) >> "!LOG_FILE!"

:TOKEN_OK

REM Crear carpeta de repositorios
if not exist "!REPOS_DIR!" (
    echo [%date% %time%] [MOCKUP] Creando carpeta de repositorios >> "!LOG_FILE!"
    mkdir "!REPOS_DIR!"
)

echo.
echo Los repositorios se descargaran en:
echo !REPOS_DIR!
echo.
echo Leyendo repos.json...
echo [%date% %time%] [MOCKUP] Leyendo configuracion desde repos.json >> "!LOG_FILE!"

REM =========================================================
REM PROCESAR repos.json CON POWERSHELL
REM =========================================================
set "TEMP_REPOS=%SCRIPT_DIR%temp_repos.txt"
del /f /q "!TEMP_REPOS!" >nul 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$json = Get-Content '!REPOS_JSON!' | ConvertFrom-Json; " ^
    "$repos = $json.repositories; " ^
    "foreach ($repo in $repos) { if ($repo.url -and $repo.name) { $url = $repo.url.Trim(); $name = $repo.name.Trim(); if (-not $url.EndsWith('.git')) { $url += '.git' }; Add-Content '!TEMP_REPOS!' \"$url|$name\" } }"

if not exist "!TEMP_REPOS!" (
    echo ERROR: No se pudo procesar repos.json
    echo [%date% %time%] [MOCKUP] ERROR: Fallo al procesar repos.json >> "!LOG_FILE!"
    pause
    exit /b 1
)

REM Contar total de repos
for /f %%C in ('find /c /v "" "!TEMP_REPOS!"') do set TOTAL_REPOS=%%C

echo.
echo [MOCKUP] Se encontraron !TOTAL_REPOS! repositorios en repos.json
echo.
echo ===============================================
echo [MOCKUP] Iniciando simulacion de descarga...
echo ===============================================
echo.
pause

REM =========================================================
REM SIMULAR CLONACION/ACTUALIZACION DE REPOSITORIOS
REM =========================================================
set "REPOS_DESCARGADOS=0"
set "REPOS_FALLIDOS=0"
set "CONTADOR=0"

cls
echo.
echo ===============================================
echo [MOCKUP] DESCARGANDO !TOTAL_REPOS! REPOSITORIOS (SIMULADO)
echo ===============================================
echo.

for /f "tokens=1,2 delims=|" %%A in ('type "!TEMP_REPOS!"') do (
    set /a CONTADOR+=1
    set "REPO_URL=%%A"
    set "REPO_NAME=%%B"
    set "REPO_PATH=!REPOS_DIR!\!REPO_NAME!"
    
    echo [%date% %time%] [MOCKUP] [!CONTADOR!/%TOTAL_REPOS%] Procesando: !REPO_NAME! >> "!LOG_FILE!"
    echo.
    echo [!CONTADOR!/%TOTAL_REPOS%] =====================================
    
    if exist "!REPO_PATH!" (
        echo [MOCKUP] Actualizando: !REPO_NAME!
        echo [%date% %time%] [MOCKUP] Repositorio existe - simulando actualizacion >> "!LOG_FILE!"
        echo     [*] Actualizando...
        
        timeout /t 2 /nobreak
        
        echo [OK] Simulado correctamente
        echo [%date% %time%] [MOCKUP] [OK] !REPO_NAME! actualizado (SIMULADO) >> "!LOG_FILE!"
        set /a REPOS_DESCARGADOS+=1
    ) else (
        echo [MOCKUP] Clonando: !REPO_NAME!
        echo [%date% %time%] [MOCKUP] Clonando nuevo repositorio (SIMULADO) >> "!LOG_FILE!"
        echo     [*] Clonando...
        
        timeout /t 2 /nobreak
        
        echo [OK] Simulado correctamente
        echo [%date% %time%] [MOCKUP] [OK] !REPO_NAME! clonado (SIMULADO) >> "!LOG_FILE!"
        set /a REPOS_DESCARGADOS+=1
    )
    echo.
)

REM Limpiar archivo temporal
del /f /q "!TEMP_REPOS!" >nul 2>&1

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
echo   Exitosos/Actualizados: !REPOS_DESCARGADOS!/%TOTAL_REPOS%
echo   Fallidos: !REPOS_FALLIDOS!/%TOTAL_REPOS%
echo.

if !REPOS_FALLIDOS! equ 0 (
    echo [OK] Todos los repositorios se simularon correctamente
) else (
    echo [!] Algunos repositorios tuvieron problemas simulados
)

echo.
echo Ubicacion de repositorios:
echo   !REPOS_DIR!
echo.
echo Archivo de registro:
echo   !LOG_FILE!
echo.
echo [%date% %time%] [MOCKUP] Descargados/Actualizados: !REPOS_DESCARGADOS! ^| Fallidos: !REPOS_FALLIDOS! / %TOTAL_REPOS% >> "!LOG_FILE!"
echo [%date% %time%] [MOCKUP] ============================================================ >> "!LOG_FILE!"

echo.
echo [MOCKUP] NOTA: Esta fue una simulacion, no se clono nada
echo.
echo Presiona una tecla para finalizar...
pause >nul
