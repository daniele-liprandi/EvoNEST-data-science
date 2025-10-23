@echo off
REM EvoNEST Data Science Setup Script for Windows
REM Double-click this file to run the setup

echo ========================================================
echo   EvoNEST Data Science Environment Setup
echo ========================================================
echo.

REM Check if PowerShell is available (it should be on all modern Windows)
where powershell >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo Running PowerShell setup script...
    echo.
    powershell -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
) else (
    echo ERROR: PowerShell not found!
    echo Please install PowerShell or use setup.ps1 directly.
    pause
    exit /b 1
)

pause
