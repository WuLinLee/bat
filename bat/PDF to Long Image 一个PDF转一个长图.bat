@echo off
chcp 65001 >nul
setlocal disabledelayedexpansion

for %%I in ("%~dp0..\ffmpeg-gs") do set "TOOLDIR=%%~fI"
if not exist "%TOOLDIR%\gswin64c.exe" set "TOOLDIR=E:\ffmpeg-gs"
set "GS=%TOOLDIR%\gswin64c.exe"
set "FF=%TOOLDIR%\ffmpeg.exe"

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

if not exist "%FF%" (
    echo 找不到 FFmpeg：%FF%
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
        echo #                                          #
        echo #   错误：路径或文件名不能包含半角 %        #
        echo #                                          #
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
        echo #                                          #
        echo #   错误：路径或文件名不能包含半角感叹号 ! #
        echo #                                          #
        echo ############################################
        echo.
        echo 问题文件（完整路径）：
        echo   %%~fA
        echo.
        echo 请把路径或文件名里的半角感叹号去掉或改成全角符号 ！ 再重新拖入。
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

rem 自动查询真实桌面路径（兼容 OneDrive 重定向）
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do set "DESKTOP=%%D"

rem 获取今天的年月日
for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy.MM.dd'"`) do set "TODAY=%%T"

:loop
setlocal disabledelayedexpansion
if "%~1"=="" (
    endlocal
    goto done
)
rem 优先短路径，短路径里没有 % 和 !，可绕过CMD解析坑
set "SRC=%~sf1"
if not exist "%SRC%" set "SRC=%~f1"
if "%SRC%"=="" set "SRC=%~f1"
rem 用短路径还原长文件名，保留 %/! 用于显示
set "CURNAME="
for /f "usebackq delims=" %%N in (`powershell -NoProfile -Command "(Get-Item -LiteralPath '%SRC%').BaseName" 2^>nul`) do set "CURNAME=%%N"
if not defined CURNAME set "CURNAME=%~n1"
if not defined CURNAME set "CURNAME=output"
setlocal enabledelayedexpansion
set "SRC=!SRC!"
set "CURNAME=!CURNAME!"

set "TMPDIR=%TEMP%\pdf_long_!RANDOM!!RANDOM!"
mkdir "!TMPDIR!" 2>nul

echo 正在处理：!CURNAME!

rem ===== 第一步：用 10 DPI 探测页数（最多 51 页）=====
"!GS!" -dNOPAUSE -dBATCH -dFirstPage=1 -dLastPage=51 -sDEVICE=png16m -r10 -dBackgroundColor=16#ffffff -sOutputFile="!TMPDIR!\page-%%03d.png" "!SRC!"

if errorlevel 1 (
    echo   [失败] !CURNAME!
    rmdir /s /q "!TMPDIR!" 2>nul
    endlocal
    endlocal
    shift
    goto loop
)

rem ===== 第二步：数页数 =====
set /a COUNT=0
for %%F in ("!TMPDIR!\page-*.png") do set /a COUNT+=1

if !COUNT!==0 (
    echo   [失败] !CURNAME!
    rmdir /s /q "!TMPDIR!" 2>nul
    endlocal
    endlocal
    shift
    goto loop
)

if !COUNT! gtr 50 (
    echo   [跳过] !CURNAME!  ^(超过 50 页上限^)
    rmdir /s /q "!TMPDIR!" 2>nul
    endlocal
    endlocal
    shift
    goto loop
)

rem ===== 第三步：决定 DPI =====
set "DPI=150"
if !COUNT! leq 30 set "DPI=200"
if !COUNT! leq 10 set "DPI=300"

echo   页数：!COUNT!，DPI：!DPI!

rem ===== 第四步：删掉探测文件，按最终 DPI 重转 =====
rmdir /s /q "!TMPDIR!" 2>nul
mkdir "!TMPDIR!" 2>nul
"!GS!" -dNOPAUSE -dBATCH -sDEVICE=png16m -r!DPI! -dBackgroundColor=16#ffffff -sOutputFile="!TMPDIR!\page-%%03d.png" "!SRC!"
if errorlevel 1 (
    echo   [失败] !CURNAME!
    rmdir /s /q "!TMPDIR!" 2>nul
    endlocal
    endlocal
    shift
    goto loop
)

rem ===== 第五步：获取最大宽度 =====
set "MAXW=0"
for %%F in ("!TMPDIR!\page-*.png") do (
    for /f "usebackq delims=" %%W in (`powershell -NoProfile -Command "Add-Type -AssemblyName System.Drawing; $img=[System.Drawing.Image]::FromFile('%%~fF'); $img.Width; $img.Dispose()"`) do (
        set /a W=%%W
        if !W! gtr !MAXW! set "MAXW=!W!"
    )
)

if !MAXW!==0 (
    echo   [失败] !CURNAME!
    rmdir /s /q "!TMPDIR!" 2>nul
    endlocal
    endlocal
    shift
    goto loop
)

echo   最大宽度：!MAXW! 像素

rem ===== 第六步：构建 FFmpeg 输入和滤镜 =====
set "INPUTS="
for %%F in ("!TMPDIR!\page-*.png") do (
    set "INPUTS=!INPUTS! -i "%%F""
)

set "FILTER="
set /a LAST=COUNT-1
for /l %%I in (0,1,!LAST!) do (
    set "FILTER=!FILTER![%%I:v]pad=!MAXW!:ih:(!MAXW!-iw)/2:0:white[%%Iv];"
)
set "STACK="
for /l %%I in (0,1,!LAST!) do (
    set "STACK=!STACK![%%Iv]"
)
set "FILTER=!FILTER!!STACK!vstack=inputs=!COUNT!"

rem ===== 第七步：生成随机字母，拼接成长图 =====
for /f "usebackq delims=" %%R in (`powershell -NoProfile -Command "$r=New-Object Random; -join ([char]$r.Next(97,123),[char]$r.Next(97,123),[char]$r.Next(97,123))"`) do set "RND=%%R"
set "OUT=!DESKTOP!\长图!COUNT!页 dpi!DPI! !TODAY! !RND!.png"

"!FF!" -y !INPUTS! -filter_complex "!FILTER!" -frames:v 1 -update 1 "!OUT!"

if not exist "!OUT!" (
    echo   [失败] !CURNAME!
) else (
    echo   [成功] !CURNAME!
)

rmdir /s /q "!TMPDIR!" 2>nul
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