@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: ⚙️ PORTABLE NODE.JS BOOTSTRAPPER (SMART LAUNCHER)
:: ============================================================================

:: Default Parameter: -r (Run Mode)
:: -r : Auto-detect projects in 'workspace/', cd into it, and npm run dev.
::      If no projects found, it safely falls back to 'workspace/' shell.
set "PARAM=-r"

:: ============================================================================
:: 🚫 SYSTEM LOGIC ENGINE (ห้ามแก้ไขโค้ดตั้งแต่บรรทัดนี้เป็นต้นไป)
:: ============================================================================

set "PYTHONUTF8=1"
set "SCRIPT_ROOT=%~dp0"
set "SETUP_PS1=%SCRIPT_ROOT%setup.ps1"

:: Override PARAM if user explicitly passes CLI arguments (e.g. start.bat -e)
if not "%~1"=="" set "PARAM=%*"

:: Launch setup.ps1 and pass control over to PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -NoExit -Command "& '%SETUP_PS1%' %PARAM%"