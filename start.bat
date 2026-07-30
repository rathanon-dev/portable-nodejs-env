@echo off
set "scriptPath=%~dp0setup.ps1"
 
powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File "%scriptPath%" -r