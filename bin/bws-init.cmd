@echo off
REM bws-init - Windows command wrapper
REM This file allows running bws-init from Windows command prompt

setlocal

REM Get the directory of this script
set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%.."

REM Check if running in WSL is available
where wsl >nul 2>nul
if %ERRORLEVEL% == 0 (
    REM Use WSL to run the bash version
    wsl bash "%SCRIPT_DIR%bws-init" %*
) else (
    REM Fall back to PowerShell version
    powershell -ExecutionPolicy Bypass -File "%ROOT_DIR%\src\bws-init.ps1" %*
)

endlocal