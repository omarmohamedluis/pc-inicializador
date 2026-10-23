@echo off
title Configurar Token de GitHub (USB)
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\src\Set-GitHubToken.ps1"
