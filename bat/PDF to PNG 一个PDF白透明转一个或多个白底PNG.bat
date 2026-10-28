@echo off
chcp 65001 >nul
setlocal disabledelayedexpansion

for %%I in ("%~dp0..\ffmpeg-gs") do set "TOOLDIR=%%~fI"
if not exist "%TOOLDIR%\gswin64c.exe" set "TOOLDIR=E:\ffmpeg-gs"
set "GS=%TOOLDIR%\gswin64c.exe"
set "PIKEPDF=%TOOLDIR%\pikepdf-tools.exe"

if "%~1"=="" (
    echo 请把 PDF 文件拖到本文件上使用。
    pause
    exit /b
)

if not exist "%GS%" (
    echo 找不到 Ghostscript：%GS%
    pause
    exit /b
)

if not exist "%PIKEPDF%" (
    echo 找不到 pikepdf-tools.exe：%PIKEPDF%
    echo 请确认仓库内 ffmpeg-gs 文件夹已下载完整。
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
echo 已选择跳过检查，继续执行（若转换失败请改名后重试）...
:after_bypass
setlocal enabledelayedexpansion
rem ==============================================

for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do set "DESKTOP=%%D"

rem --- 修复：用disabled捕获首个文件，避免 !/% 在enabled下截断 ---
set "TOTAL=?"
setlocal disabledelayedexpansion
set "SRC_TMP=%~sf1"
if not exist "%SRC_TMP%" set "SRC_TMP=%~f1"
if "%SRC_TMP%"=="" set "SRC_TMP=%~f1"
set "TOTAL_TMP="
for /f "usebackq delims=" %%T in (`"%PIKEPDF%" pagecount "%SRC_TMP%" 2^>nul`) do set "TOTAL_TMP=%%T"
if defined TOTAL_TMP (
    endlocal & set "TOTAL=%TOTAL_TMP%"
) else (
    endlocal & set "TOTAL=?"
)

powershell -NoProfile -Command "Write-Host ''; Write-Host ('  此 PDF 共 ' + '!TOTAL!' + ' 页') -ForegroundColor Cyan; Write-Host ''; Write-Host '========== 转换模式 ==========' -ForegroundColor Cyan; Write-Host ''; Write-Host '  直接回车  指定页码转 PNG（默认）' -ForegroundColor White; Write-Host '  输入 2    全部页转 PNG' -ForegroundColor White; Write-Host ''"
set "CH="
set /p "CH=请选择（直接回车=指定页码）: "
if "!CH!"=="2" (
    set "MODE=1"
    goto loop
)
set "MODE=2"
goto ask_pages

:ask_pages
powershell -NoProfile -Command "Write-Host ''; Write-Host '  输入要转换的页码 用空格分隔' -ForegroundColor White; Write-Host '  比如 2 4 21 6' -ForegroundColor Gray; Write-Host ''"
set "PAGES="
set /p "PAGES=请输入页码: "
if "!PAGES!"=="" (
    echo   没有输入页码 退出
    pause
    exit /b
)

:loop
setlocal disabledelayedexpansion
if "%~1"=="" (
    endlocal
    goto done
)
rem 优先短路径，短路径无 %/! 完美绕过CMD解析
set "CURFILE=%~sf1"
if not exist "%CURFILE%" set "CURFILE=%~f1"
if "%CURFILE%"=="" set "CURFILE=%~f1"
rem 用PowerShell从短路径还原长文件名，保留 %/! 用于输出文件名
set "CURNAME="
for /f "usebackq delims=" %%N in (`powershell -NoProfile -Command "(Get-Item -LiteralPath '%CURFILE%').BaseName" 2^>nul`) do set "CURNAME=%%N"
if not defined CURNAME set "CURNAME=%~sn1"
if not defined CURNAME set "CURNAME=%~n1"
if not defined CURNAME set "CURNAME=output"

setlocal enabledelayedexpansion
set "CURFILE=!CURFILE!"
set "CURNAME=!CURNAME!"

if "!MODE!"=="1" (
    echo.
    echo 正在转换（全部页）：!CURNAME!
    echo 输入: !CURFILE!
    "!GS!" -dNOPAUSE -dBATCH -sDEVICE=png16m -r300 -dBackgroundColor=16#ffffff -sOutputFile="!DESKTOP!\!CURNAME!-300dpi-%%03d.png" "!CURFILE!"
    if errorlevel 1 echo   [失败] !CURNAME! ^(可能图片被占用或路径含特殊符号^)
) else (
    echo.
    echo 正在转换（指定页）：!CURNAME!
    set "TOTAL=0"
    for /f "usebackq delims=" %%T in (`"%PIKEPDF%" pagecount "!CURFILE!" 2^>nul`) do set "TOTAL=%%T"
    if "!TOTAL!"=="0" (
        echo   无法读取页数 跳过此文件
    ) else (
        echo   此 PDF 共 !TOTAL! 页
        echo.
        for %%P in (!PAGES!) do (
            if %%P GTR !TOTAL! (
                echo   第 %%P 页超出范围 跳过
            ) else (
                echo   正在转 第 %%P 页
                "!GS!" -dNOPAUSE -dBATCH -dFirstPage=%%P -dLastPage=%%P -sDEVICE=png16m -r300 -dBackgroundColor=16#ffffff -sOutputFile="!DESKTOP!\!CURNAME!-300dpi-%%P.png" "!CURFILE!"
                if errorlevel 1 echo     [失败] 第 %%P 页
            )
        )
    )
)
endlocal
endlocal
shift
goto loop

:done
echo.
echo 全部完成！
pause
exit /b

:CheckBypass
if "%BYPASS%"=="000" exit /b 0
pause
exit /b 1