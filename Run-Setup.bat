@echo off
REM ====================================================
REM  Launcher for PC Initializer (PowerShell)
REM ====================================================

REM Check for admin rights and elevate if needed
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\" %*' -Verb RunAs"
    exit /b
)

REM Launch the PowerShell orchestrator
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "Setup-PC.ps1"

if %errorlevel% neq 0 (
    echo.
    echo Execution finished with potential errors.
    pause
)
