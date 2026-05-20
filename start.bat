@echo off
 
set "scriptPath=%~dp0\setup.ps1"

powershell -Command ^
    "Start-Process pwsh -ArgumentList '-NoProfile','-ExecutionPolicy Bypass','-NoExit','-Command & ''%scriptPath%'' '"