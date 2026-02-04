@echo off
REM =========================================================
REM Script 3: Descargar Repositorios GitHub
REM =========================================================
REM Lee dinamicamente de repos.json
REM Soporta n repositorios privados con autenticacion token
REM NO necesita permisos de administrador
REM Reutilizable - clona/actualiza repos existentes
REM =========================================================

setlocal enabledelayedexpansion

cls
echo.
echo ============================================
echo SCRIPT 3: DESCARGAR REPOSITORIOS GITHUB
echo ============================================
echo.

set "LOG_FILE=%USERPROFILE%\Desktop\install.log"
set "REPOS_DIR=%USERPROFILE%\Desktop\repositorios"
set "SCRIPT_DIR=%~dp0"
set "REPOS_JSON=%SCRIPT_DIR%repos.json"

echo [%date% %time%] ============================================================ >> "!LOG_FILE!"
echo [%date% %time%] INICIANDO SCRIPT 3: DESCARGAR REPOSITORIOS GITHUB >> "!LOG_FILE!"
echo [%date% %time%] ============================================================ >> "!LOG_FILE!"

REM Verificar si Git esta instalado
git --version >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Git no esta instalado
    echo.
    echo Asegurate de:
    echo   1. Ejecutar el Script 1 (Windows Update + Winget)
    echo   2. Ejecutar el Script 2 (Instalar Software)
    echo.
    echo Git deberia estar incluido en los paquetes instalados
    echo.
    echo [%date% %time%] ERROR: Git no esta disponible >> "!LOG_FILE!"
    pause
    exit /b 1
)

REM Verificar que repos.json existe
if not exist "!REPOS_JSON!" (
    echo ERROR: No se encontro repos.json
    echo Ubicacion esperada: !REPOS_JSON!
    echo [%date% %time%] ERROR: repos.json no encontrado >> "!LOG_FILE!"
    pause
    exit /b 1
)

echo [%date% %time%] repos.json encontrado - iniciando clonacion >> "!LOG_FILE!"

REM =========================================================
REM AUTENTICACION PARA REPOS PRIVADOS
REM =========================================================
echo.
echo ============================================
echo AUTENTICACION GITHUB - REPOSITORIOS PRIVADOS
echo ============================================
echo.

REM Verificar si ya existe el token en la variable de entorno
if defined GITHUB_TOKEN (
    echo [OK] Token de GitHub detectado
    echo [%date% %time%] Token de GitHub encontrado en variable de entorno >> "!LOG_FILE!"
    goto TOKEN_OK
)

REM Bucle para pedir token
:PEDIR_TOKEN
echo.
echo Necesitas un token personal de GitHub para repos privados
echo.
echo Como obtenerlo:
echo   1. Ve a: https://github.com/settings/tokens
echo   2. Click en "Generate new token (classic)"
echo   3. Dale permisos: repo, read:user
echo   4. Copia el token y pegalo aqui
echo.
echo El token debe tener entre 20 y 100 caracteres
echo.
set /p GITHUB_TOKEN="Ingresa tu token de GitHub: "

if "!GITHUB_TOKEN!"=="" (
    echo.
    echo [ADVERTENCIA] Token vacio - Intenta de nuevo
    echo [%date% %time%] Intento fallido: Token vacio >> "!LOG_FILE!"
    timeout /t 2 /nobreak
    cls
    goto PEDIR_TOKEN
)

REM Validar longitud del token
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
    echo Token ingresado tiene: !TOKEN_LEN! caracteres
    echo [%date% %time%] Intento fallido: Token muy corto (!TOKEN_LEN! caracteres) >> "!LOG_FILE!"
    timeout /t 2 /nobreak
    cls
    set "GITHUB_TOKEN="
    goto PEDIR_TOKEN
)

echo [%date% %time%] Token proporcionado - configurando credenciales Git >> "!LOG_FILE!"

REM Configurar Git con las credenciales
git config --global credential.helper store
(
    echo https://!GITHUB_TOKEN!:x-oauth-basic@github.com
) >> "%USERPROFILE%\.git-credentials" 2>nul

:TOKEN_OK

REM Crear carpeta de repositorios en el escritorio
if not exist "!REPOS_DIR!" (
    echo [%date% %time%] Creando carpeta de repositorios >> "!LOG_FILE!"
    mkdir "!REPOS_DIR!"
    echo Carpeta creada: !REPOS_DIR!
)

echo.
echo Los repositorios se descargaran en:
echo !REPOS_DIR!
echo.
echo Leyendo repos.json...
echo [%date% %time%] Leyendo configuracion desde repos.json >> "!LOG_FILE!"

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
    echo [%date% %time%] ERROR: Fallo al procesar repos.json >> "!LOG_FILE!"
    pause
    exit /b 1
)

REM Contar total de repos
for /f %%C in ('find /c /v "" "!TEMP_REPOS!"') do set TOTAL_REPOS=%%C

echo.
echo Se encontraron !TOTAL_REPOS! repositorios en repos.json
echo.
echo ===============================================
echo Iniciando descarga/actualizacion...
echo ===============================================
echo.
pause

REM =========================================================
REM CLONAR/ACTUALIZAR REPOSITORIOS
REM =========================================================
set "REPOS_DESCARGADOS=0"
set "REPOS_FALLIDOS=0"
set "CONTADOR=0"

cls
echo.
echo ===============================================
echo DESCARGANDO !TOTAL_REPOS! REPOSITORIOS
echo ===============================================
echo.

for /f "tokens=1,2 delims=|" %%A in ('type "!TEMP_REPOS!"') do (
    set /a CONTADOR+=1
    set "REPO_URL=%%A"
    set "REPO_NAME=%%B"
    set "REPO_PATH=!REPOS_DIR!\!REPO_NAME!"
    
    echo [%date% %time%] [!CONTADOR!/%TOTAL_REPOS%] Procesando: !REPO_NAME! >> "!LOG_FILE!"
    echo.
    echo [!CONTADOR!/%TOTAL_REPOS%] =====================================
    
    if exist "!REPO_PATH!" (
        echo Actualizando: !REPO_NAME!
        echo [%date% %time%]     Repositorio existe - actualizando... >> "!LOG_FILE!"
        echo     [*] Actualizando...
        cd /d "!REPO_PATH!"
        git pull >nul 2>&1
        if !errorLevel! equ 0 (
            echo [%date% %time%]     OK - Actualizado correctamente >> "!LOG_FILE!"
            echo     [OK] Actualizado correctamente
            set /a REPOS_DESCARGADOS+=1
        ) else (
            echo [%date% %time%]     ERROR - Fallo al actualizar >> "!LOG_FILE!"
            echo     [ERROR] Fallo al actualizar
            set /a REPOS_FALLIDOS+=1
        )
    ) else (
        echo Clonando: !REPO_NAME!
        echo [%date% %time%]     Clonando nuevo repositorio... >> "!LOG_FILE!"
        echo     [*] Clonando...
        git clone "!REPO_URL!" "!REPO_PATH!" >nul 2>&1
        if !errorLevel! equ 0 (
            echo [%date% %time%]     OK - Clonado correctamente >> "!LOG_FILE!"
            echo     [OK] Clonado correctamente
            set /a REPOS_DESCARGADOS+=1
        ) else (
            echo [%date% %time%]     ERROR - Fallo al clonar >> "!LOG_FILE!"
            echo     [ERROR] Fallo al clonar
            set /a REPOS_FALLIDOS+=1
        )
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
echo DESCARGA DE REPOSITORIOS COMPLETADA
echo ===============================================
echo.
echo Resultados:
echo   Exitosos/Actualizados: !REPOS_DESCARGADOS!/%TOTAL_REPOS%
echo   Fallidos: !REPOS_FALLIDOS!/%TOTAL_REPOS%
echo.

if !REPOS_FALLIDOS! equ 0 (
    echo [OK] Todos los repositorios se procesaron correctamente
) else (
    echo [!] Algunos repositorios tuvieron problemas
    echo    Revisa el log para detalles
)

echo.
echo Ubicacion de repositorios:
echo   !REPOS_DIR!
echo.
echo Archivo de registro:
echo   !LOG_FILE!
echo.
echo [%date% %time%] Descargados/Actualizados: !REPOS_DESCARGADOS! ^| Fallidos: !REPOS_FALLIDOS! / %TOTAL_REPOS% >> "!LOG_FILE!"
echo [%date% %time%] ============================================================ >> "!LOG_FILE!"

echo.
echo Presiona una tecla para finalizar...
pause >nul

cd /d "!SCRIPT_DIR!"
