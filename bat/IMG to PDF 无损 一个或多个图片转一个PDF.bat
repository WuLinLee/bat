@echo off
chcp 65001 >nul
setlocal disabledelayedexpansion

for %%I in ("%~dp0..\ffmpeg-gs") do set "TOOLDIR=%%~fI"
if not exist "%TOOLDIR%\img2pdf.exe" set "TOOLDIR=E:\ffmpeg-gs"
set "IMG2PDF=%TOOLDIR%\img2pdf.exe"

if "%~1"=="" (
    echo 请把一张或多张图片拖到本文件上使用。
    pause
    exit /b
)

if not exist "%IMG2PDF%" (
    echo 找不到 img2pdf.exe：%IMG2PDF%
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
        echo #   错误：路径或文件名不能包含感叹号 !     #
        echo #                                          #
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
echo 已选择跳过检查，继续执行（若合成失败请改名后重试）...
:after_bypass
rem ==============================================

set "TMPLIST=%TEMP%\img2pdf_list_%RANDOM%.txt"
if exist "%TMPLIST%" del "%TMPLIST%"

:loop
if "%~1"=="" goto run
>>"%TMPLIST%" echo %~f1
shift
goto loop

:run
set "IMG2PDF_EXE=%IMG2PDF%"
set "IMG2PDF_LIST=%TMPLIST%"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $files=@(Get-Content -LiteralPath $env:IMG2PDF_LIST -Encoding UTF8); if($files.Count -eq 0){Write-Host '没有文件'; exit 1}; Write-Host ''; Write-Host '已拖入的文件：'; Write-Host ''; for($i=0;$i -lt $files.Count;$i++){Write-Host ('  ['+($i+1)+'] '+[System.IO.Path]::GetFileName($files[$i]))}; Write-Host ''; $userInput=Read-Host '请输入顺序（如 2 4 6 3 1 10，空格分隔，直接回车=默认顺序）'; if([string]::IsNullOrWhiteSpace($userInput)){$order=1..$files.Count}else{$order=@($userInput -split '\s+' | Where-Object {$_ -match '^\d+$'} | ForEach-Object {[int]$_})}; $sorted=@(); foreach($n in $order){if($n -ge 1 -and $n -le $files.Count){$sorted+=$files[$n-1]}}; if($sorted.Count -eq 0){Write-Host '顺序无效'; exit 1}; Write-Host ''; Write-Host '请选择页面尺寸：'; Write-Host '  1 = A4（打印用，210mm x 297mm）'; Write-Host '  2 = 16:9（屏幕用，横版宽屏）'; Write-Host '  0 = 不统一，每页跟图片一样大（默认）'; Write-Host ''; $sizeChoice=Read-Host '输入数字（直接回车 = 0 原尺寸）'; if([string]::IsNullOrWhiteSpace($sizeChoice)){$sizeChoice='0'}; switch($sizeChoice){'1'{$pageArgs=@('--pagesize','A4','--fit','into'); $sizeSuffix='A4'} '2'{$pageArgs=@('--pagesize','32cmx18cm','--fit','into'); $sizeSuffix='16比9'} '0'{$pageArgs=@(); $sizeSuffix='原尺寸'} default{$pageArgs=@(); $sizeSuffix='原尺寸'}}; $count=$sorted.Count; $rand=-join ((97..122) | Get-Random -Count 3 | ForEach-Object {[char]$_}); $desktop=[Environment]::GetFolderPath('Desktop'); $now=Get-Date; $datePart=$now.ToString('yyyy.MM.dd'); $timePart=$now.ToString('HH.mm'); $out=Join-Path $desktop ('合并输出'+$count+'张 '+$datePart+' '+$timePart+' '+$sizeSuffix+' '+$rand+'.pdf'); Write-Host ''; Write-Host ('正在生成：'+$out); & $env:IMG2PDF_EXE @sorted @pageArgs -o $out; if($LASTEXITCODE -eq 0){Write-Host ('完成：'+$out)}else{Write-Host '转换失败'}"

del "%TMPLIST%" 2>nul
pause
exit /b

:CheckBypass
if "%BYPASS%"=="000" exit /b 0
pause
exit /b 1