@echo off
REM EvoNEST Data Science Setup Script for Windows
REM Double-click this file to run the setup
REM Command-line usage: setup.bat [/uninstall]

echo ========================================================
echo   EvoNEST Data Science Environment Setup
echo ========================================================
echo.

REM Check if PowerShell is available (it should be on all modern Windows)
where powershell >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo Running PowerShell setup script...
    echo.
    
    REM Pass /uninstall parameter if provided
    REM Using -ExecutionPolicy Bypass to allow running unsigned scripts (e.g., from GitHub zip downloads)
    if "%1"=="/uninstall" (
        powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0setup.ps1" -Uninstall
    ) else (
        powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0setup.ps1"
    )
) else (
    echo ERROR: PowerShell not found!
    echo Please install PowerShell or use setup.ps1 directly.
    pause
    exit /b 1
)

pause
