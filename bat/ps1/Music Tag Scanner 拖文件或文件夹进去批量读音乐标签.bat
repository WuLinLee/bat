@echo off
chcp 65001 >nul
setlocal EnableExtensions

if "%~1"=="" (
    echo.
    echo Please DRAG files or folders onto this bat file.
    echo Do not double-click it.
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0读标签.ps1" %*

echo.
echo Exit code: %errorlevel%
pause >nul