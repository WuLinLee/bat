@echo off
chcp 65001 >nul

if "%~1"=="" (
    echo.
    echo Please DRAG one or more audio files / folders onto this bat file.
    echo Do not double-click it.
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0诊断.ps1" %*

echo.
pause