@echo off
chcp 65001 >nul
setlocal disabledelayedexpansion

if "%~1"=="" (
    echo 请把 Word 文件（.doc/.docx）拖到本文件上使用。
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
        echo 如需强制跳过检查并继续转换，请输入 000 后按回车
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
        echo 如需强制跳过检查并继续转换，请输入 000 后按回车
        echo 直接按回车将退出程序
        set /p "BYPASS=请输入: "
        call :CheckBypass || exit /b
        goto bypass_check
    )
)
goto after_bypass
:bypass_check
echo.
echo 已选择跳过检查，继续转换（若转换失败请改名后重试）...
:after_bypass
rem ==============================================

rem ========== 转换前提示 ==========
cls
powershell -NoProfile -Command "Write-Host ''; Write-Host '############################################' -ForegroundColor Yellow; Write-Host '#   即将开始 Word 转 PDF' -ForegroundColor Yellow; Write-Host '############################################' -ForegroundColor Yellow; Write-Host ''; Write-Host '注意：转换过程中会启动 Word 程序' -ForegroundColor Cyan; Write-Host ''; Write-Host '如果正在编辑 Word 文档' -ForegroundColor Cyan; Write-Host '请先保存并关闭' -ForegroundColor Cyan; Write-Host '否则未保存内容可能会丢失' -ForegroundColor Red; Write-Host ''; Write-Host '按任意键继续，或直接关闭本窗口取消' -ForegroundColor Green"
pause >nul
rem ================================

rem 自动查询真实桌面路径（兼容 OneDrive 重定向）
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do set "DESKTOP=%%D"

:loop
if "%~1"=="" goto done

set "SRC=%~f1"
set "DST=%DESKTOP%\%~n1.pdf"

rem ========== 检查同名 PDF ==========
if exist "%DST%" (
    powershell -NoProfile -Command "Write-Host ''; Write-Host '############################################' -ForegroundColor Yellow; Write-Host '#   警告：桌面已存在同名 PDF' -ForegroundColor Yellow; Write-Host '############################################' -ForegroundColor Yellow; Write-Host ''; Write-Host ('源文件：%~nx1') -ForegroundColor Cyan; Write-Host ('目标文件：%~n1.pdf') -ForegroundColor Cyan"
    choice /c YN /m "是否覆盖？(Y=覆盖 / N=跳过)"
    if errorlevel 2 (
        echo   [跳过] %~nx1
        shift
        goto loop
    )
)
rem ================================

echo 正在转换：%~nx1

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $word=New-Object -ComObject Word.Application; $word.Visible=$false; $word.DisplayAlerts=0; try{$word.Options.ConfirmConversions=$false}catch{}; $doc=$word.Documents.Open($env:SRC,$false,$true,$false); $doc.ExportAsFixedFormat($env:DST,17,$false,0,0,0,0,0,$true,$true,0,$true,$true,$false); $doc.Close($false); $word.Quit();"

if not exist "%DST%" (
    echo   [失败] %~nx1
) else (
    echo   [成功] %~nx1
)

shift
goto loop

:done
echo.
echo 全部完成！PDF 已输出到桌面。
pause
exit /b

:CheckBypass
if "%BYPASS%"=="000" exit /b 0
pause
exit /b 1
