@echo off
REM =========================================================
REM Script 0: MAESTRO - Orquestador de instalacion
REM =========================================================
REM Este script controla todo el flujo de instalacion
REM Es reutilizable indefinidamente
REM Puede re-ejecutarse en cualquier momento para:
REM   - Ejecutar Windows Updates
REM   - Instalar/actualizar paquetes desde install.json
REM   - Clonar/actualizar repositorios desde repos.json
REM =========================================================

setlocal enabledelayedexpansion

REM =========================================================
REM VERIFICAR PERMISOS DE ADMINISTRADOR
REM =========================================================
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo ============================================
    echo ELEVANDO PERMISOS A ADMINISTRADOR
    echo ============================================
    echo.
    echo Este script necesita ejecutarse como ADMINISTRADOR
    echo Se va a relanzar con permisos elevados...
    echo.
    timeout /t 3 /nobreak
    
    REM Relanzar como administrador en nueva ventana
    powershell -Command "Start-Process cmd -ArgumentList '/k \"\"%~f0\" %*\"' -Verb RunAs" 2>nul
    exit /b 0
)

REM =========================================================
REM INICIALIZACION
REM =========================================================
title PC Inicializador - Maestro
color 0A

set "SCRIPT_DIR=%~dp0"
set "LOG_FILE=%USERPROFILE%\Desktop\install.log"
set "INSTALL_JSON=%SCRIPT_DIR%install.json"
set "REPOS_JSON=%SCRIPT_DIR%repos.json"

REM Crear log si no existe
if not exist "!LOG_FILE!" (
    (
        echo.
        echo ===============================================
        echo  INICIALIZADOR PC - REGISTRO DE INSTALACION
        echo ===============================================
        echo  Fecha: %date% %time%
        echo ===============================================
        echo.
    ) > "!LOG_FILE!"
)

REM =========================================================
REM VALIDAR DEPENDENCIAS CRITICAS
REM =========================================================
:VALIDAR_DEPENDENCIAS
set "DEPS_OK=1"
set "WARNINGS=0"

echo.
echo Validando dependencias...
echo.

REM Verificar Git
git --version >nul 2>&1
if %errorLevel% neq 0 (
    set "DEPS_OK=0"
    echo [ADVERTENCIA] Git no esta instalado
    echo   - Necesario para: Opcion 3 (Repositorios)
    echo   - Instalalo desde: https://git-scm.com/download/win
    echo.
    set /a WARNINGS+=1
)

REM Verificar Winget
winget --version >nul 2>&1
if %errorLevel% neq 0 (
    set "DEPS_OK=0"
    echo [ADVERTENCIA] Winget no esta instalado
    echo   - Necesario para: Opcion 1 y 2 (Windows Update y Software)
    echo   - Se puede instalar ejecutando Opcion 1 primero
    echo.
    set /a WARNINGS+=1
)

if "!DEPS_OK!"=="1" (
    echo [OK] Todas las dependencias validadas
    echo.
    goto MENU
) else (
    echo.
    if "!WARNINGS!"=="1" (
        echo Tienes 1 dependencia pendiente.
    ) else (
        echo Tienes !WARNINGS! dependencias pendientes.
    )
    echo.
    echo [RECOMENDACION] Ejecuta primero la OPCION 1 para instalar dependencias
    echo.
    pause
    echo.
)

REM =========================================================
REM MENU PRINCIPAL - Elegir que ejecutar
REM =========================================================
:MENU
cls
echo.
echo ===============================================
echo  PC INICIALIZADOR
echo ===============================================
echo.
echo Elige una opcion:
echo.
echo   1 - Windows Update + Setup Winget (Paso 1)
echo   2 - Instalar/Actualizar Software (Paso 2)
echo   3 - Clonar Repositorios GitHub (Paso 3)
echo   4 - Ejecutar TODOS los pasos (1, 2, 3)
echo   5 - Ver log de instalacion
echo   0 - Salir
echo.
set /p opcion="Selecciona una opcion [0-5]: "

REM =========================================================
REM PROCESAR SELECCION
REM =========================================================
if "!opcion!"=="0" (
    echo.
    echo [%date% %time%] Usuario cancelo la ejecucion >> "!LOG_FILE!"
    exit /b 0
)

if "!opcion!"=="5" (
    echo.
    echo [%date% %time%] Abriendo log de instalacion >> "!LOG_FILE!"
    start notepad "!LOG_FILE!"
    timeout /t 2 /nobreak
    goto :MENU
)

if "!opcion!"=="4" (
    set "PASO=1"
    goto :EJECUTAR_PASO
)

if "!opcion!"=="1" (
    set "PASO=1"
    goto :EJECUTAR_PASO
)

if "!opcion!"=="2" (
    set "PASO=2"
    goto :EJECUTAR_PASO
)

if "!opcion!"=="3" (
    set "PASO=3"
    goto :EJECUTAR_PASO
)

REM Opcion invalida
echo.
echo ERROR: Opcion invalida
timeout /t 2 /nobreak
goto :MENU

REM =========================================================
REM EJECUTAR PASOS
REM =========================================================
:EJECUTAR_PASO

if "!PASO!"=="1" (
    echo [%date% %time%] === EJECUTANDO PASO 1: WINDOWS UPDATE + WINGET === >> "!LOG_FILE!"
    echo.
    echo ===============================================
    echo PASO 1: WINDOWS UPDATE + WINGET SETUP
    echo ===============================================
    echo.
    echo Necesita permisos de ADMINISTRADOR
    echo.
    pause
    call "!SCRIPT_DIR!01-windows-update-y-winget.bat"
    
    if !errorLevel! neq 0 (
        echo.
        echo [ERROR] El Script 1 termino con error
        echo Revisa el log: !LOG_FILE!
        echo.
        pause
    ) else (
        echo.
        echo [OK] Script 1 completado exitosamente
        echo.
        timeout /t 2 /nobreak
    )
    
    REM Si solo ejecuto paso 1, volver al menu
    if "!opcion!"=="1" goto :MENU
)

if "!PASO!"=="2" (
    REM Validar que winget este disponible antes de instalar software
    winget --version >nul 2>&1
    if !errorLevel! neq 0 (
        echo.
        echo [ERROR] Winget no esta disponible
        echo.
        echo Opciones para resolver:
        echo   1. Ejecuta primero la OPCION 1 (Windows Update + Winget)
        echo   2. Instala winget manualmente desde Microsoft Store
        echo.
        pause
        goto :MENU
    )
    
    echo [%date% %time%] === EJECUTANDO PASO 2: INSTALAR SOFTWARE === >> "!LOG_FILE!"
    echo.
    echo ===============================================
    echo PASO 2: INSTALAR/ACTUALIZAR SOFTWARE
    echo ===============================================
    echo.
    echo Necesita permisos de ADMINISTRADOR
    echo Los paquetes se leeran desde: install.json
    echo.
    pause
    call "!SCRIPT_DIR!02-instalar-software.bat"
    
    if !errorLevel! neq 0 (
        echo.
        echo [ERROR] El Script 2 termino con error
        echo Revisa el log: !LOG_FILE!
        echo.
        pause
    ) else (
        echo.
        echo [OK] Script 2 completado exitosamente
        echo.
        timeout /t 2 /nobreak
    )
    
    if "!opcion!"=="2" goto :MENU
)

if "!PASO!"=="3" (
    REM Validar que git este disponible antes de clonar repos
    git --version >nul 2>&1
    if !errorLevel! neq 0 (
        echo.
        echo [ERROR] Git no esta disponible
        echo.
        echo Opciones para resolver:
        echo   1. Descarga Git desde: https://git-scm.com/download/win
        echo   2. Instala el instalador .exe y reinicia la terminal
        echo.
        pause
        goto :MENU
    )
    
    echo [%date% %time%] === EJECUTANDO PASO 3: CLONAR REPOSITORIOS === >> "!LOG_FILE!"
    echo.
    echo ===============================================
    echo PASO 3: CLONAR/ACTUALIZAR REPOSITORIOS
    echo ===============================================
    echo.
    echo Los repositorios se leeran desde: repos.json
    echo Necesitaras un GitHub Personal Access Token
    echo.
    pause
    call "!SCRIPT_DIR!03-descargar-repositorios.bat"
    
    if !errorLevel! neq 0 (
        echo.
        echo [ERROR] El Script 3 termino con error
        echo Revisa el log: !LOG_FILE!
        echo.
        pause
    ) else (
        echo.
        echo [OK] Script 3 completado exitosamente
        echo.
        timeout /t 2 /nobreak
    )
    
    if "!opcion!"=="3" goto :MENU
)

REM Si fue opcion 4 (todos), continuar con proximo paso
if "!PASO!"=="1" (
    set "PASO=2"
    echo.
    echo ===============================================
    echo PASO 1 COMPLETADO - Continuando con Paso 2...
    echo ===============================================
    timeout /t 3 /nobreak
    goto :EJECUTAR_PASO
)

if "!PASO!"=="2" (
    set "PASO=3"
    echo.
    echo ===============================================
    echo PASO 2 COMPLETADO - Continuando con Paso 3...
    echo ===============================================
    timeout /t 3 /nobreak
    goto :EJECUTAR_PASO
)

if "!PASO!"=="3" (
    cls
    echo.
    echo ===============================================
    echo ===============================================
    echo.
    echo       TODOS LOS PASOS COMPLETADOS!
    echo.
    echo ===============================================
    echo ===============================================
    echo.
    echo Resumen:
    echo   [OK] Paso 1: Windows Update + Winget
    echo   [OK] Paso 2: Software Instalado
    echo   [OK] Paso 3: Repositorios Descargados
    echo.
    echo El log completo esta en:
    echo   !LOG_FILE!
    echo.
    echo.
    pause
    
    echo [%date% %time%] =============================================== >> "!LOG_FILE!"
    echo [%date% %time%] TODOS LOS PASOS COMPLETADOS EXITOSAMENTE >> "!LOG_FILE!"
    echo [%date% %time%] =============================================== >> "!LOG_FILE!"
    
    start notepad "!LOG_FILE!"
    goto :MENU
)

goto :MENU
