@echo off
chcp 65001 >nul
setlocal disabledelayedexpansion
for %%I in ("%~dp0..\ffmpeg-gs\pikepdf-tools.exe") do set "PIKEPDF=%%~fI"
if not exist "%PIKEPDF%" set "PIKEPDF=E:\ffmpeg-gs\pikepdf-tools.exe"
if not exist "%PIKEPDF%" (
    echo 找不到 pikepdf-tools.exe。请确认 ffmpeg-gs 文件夹已下载完整。
    pause
    exit /b
)


if "%~1"=="" (
    echo 请把 PDF 文件拖到本文件上使用。
    pause
    exit /b
)

rem ========== 检查路径和文件名是否含危险字符 ==========
for %%A in (%*) do (
    echo "%%~fA" | findstr /c:"%%" >nul
    if not errorlevel 1 (
        cls
        echo.
        echo ############################################
        echo #   错误：路径或文件名不能包含半角 %        #
        echo ############################################
        echo.
        echo 问题文件（完整路径）：
        echo   %%~fA
        echo.
        echo 请把路径或文件名里的半角 % 去掉或改名，再重新拖入。
        echo.
        echo 如需强制跳过检查并继续，请输入 000 后按回车
        echo 直接按回车将退出程序
        set /p "BYPASS=请输入: "
        call :CheckBypass || exit /b
        goto bypass_check
    )
    echo "%%~fA" | findstr /c:"!" >nul
    if not errorlevel 1 (
        cls
        echo.
        echo ############################################
        echo #   错误：路径或文件名不能包含感叹号 !     #
        echo ############################################
        echo.
        echo 问题文件（完整路径）：
        echo   %%~fA
        echo.
        echo 请把路径或文件名里的感叹号去掉或改成全角 ！ 再重新拖入。
        echo.
        echo 如需强制跳过检查并继续，请输入 000 后按回车
        echo 直接按回车将退出程序
        set /p "BYPASS=请输入: "
        call :CheckBypass || exit /b
        goto bypass_check
    )
)
goto after_bypass
:bypass_check
echo.
echo 已选择跳过检查，继续执行（若处理失败请改名后重试）...
:after_bypass
rem ==============================================

if "%~2" neq "" (
    echo.
    echo   警告：本脚本一次只处理一个 PDF
    echo   只处理第一个文件：%~nx1
    echo.
)

set "TMPLIST=%TEMP%\pdf_split_%RANDOM%.txt"
if exist "%TMPLIST%" del "%TMPLIST%"

rem 在 disabledelayedexpansion 下写入路径，防止 ! 和 %% 被 CMD 截断
>>"%TMPLIST%" echo %~f1

for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do set "DESKTOP=%%D"

"%PIKEPDF%" split "%TMPLIST%" "%DESKTOP%"
if errorlevel 1 (
    echo.
    echo   拆分失败：请检查 PDF 文件是否损坏或被占用。
)

del "%TMPLIST%" 2>nul
pause
exit /b

:CheckBypass
if "%BYPASS%"=="000" exit /b 0
pause
exit /b 1