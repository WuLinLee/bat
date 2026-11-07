@echo off
chcp 65001 >nul
setlocal disabledelayedexpansion

set "FF=E:\ffmpeg-gs\ffmpeg.exe"

if "%~1"=="" (
    echo 请把音频文件或文件夹拖到本文件上使用。
    pause
    exit /b
)

if not exist "%FF%" (
    echo 找不到 ffmpeg.exe：%FF%
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
echo 已选择跳过检查，继续执行（若转码失败请改名后重试）...
:after_bypass
rem ==============================================

rem ========== 检查是否有文件夹 ==========
set "HAS_DIR=0"
for %%A in (%*) do (
    if exist "%%~A\" set "HAS_DIR=1"
)

rem ========== 选择是否复制图片 ==========
if "%HAS_DIR%"=="0" goto no_dir

powershell -NoProfile -Command "Write-Host ''; Write-Host '========== 附加选项 ==========' -ForegroundColor Cyan; Write-Host ''; Write-Host '  1. 只转音频 + cue/log + MP3' -ForegroundColor White; Write-Host '  2. 转音频 + cue/log + MP3 + 图片' -ForegroundColor White; Write-Host ''"
choice /c 12 /n /m "请选择 (1/2): "
if errorlevel 2 (
    set "COPY_IMG=1"
    set "MODE_TEXT=音频 + cue/log + MP3 + 图片"
    goto opt_ok
)
set "COPY_IMG=0"
set "MODE_TEXT=音频 + cue/log + MP3"
goto opt_ok

:no_dir
set "COPY_IMG=0"
set "MODE_TEXT=只转音频（全是文件，跳过附加选项）"

:opt_ok
echo.
echo   已选择：%MODE_TEXT%
echo.

set "TMPLIST=%TEMP%\audio_list_%RANDOM%.txt"
if exist "%TMPLIST%" del "%TMPLIST%"

:collect
if "%~1"=="" goto run
>>"%TMPLIST%" echo "%~f1"
shift
goto collect

:run
setlocal enabledelayedexpansion
set "FLAC_LIST=%TMPLIST%"
set "FF_PATH=%FF%"
set "COPY_IMG_ENV=%COPY_IMG%"

powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $ErrorActionPreference='Continue'; $ff=$env:FF_PATH; $copyImg = ($env:COPY_IMG_ENV -eq '1'); $items=@(Get-Content -LiteralPath $env:FLAC_LIST -Encoding UTF8 | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_.Trim([char]34) }); $total_ok=0; $total_skip=0; $total_fail=0; $total_img=0; $total_side=0; $total_mp3=0; $fail_list=@(); $imgExts=@('.jpg','.jpeg','.png','.webp','.bmp','.gif','.tif','.tiff'); function Convert-One($src,$dest){ if(Test-Path -LiteralPath $dest){ return 'skip' }; $tmp=[System.IO.Path]::GetTempFileName(); & $ff -hide_banner -loglevel error -i $src 2>$tmp | Out-Null; $hasCover=(Select-String -Path $tmp -Pattern 'Video:' -Quiet); Remove-Item $tmp -Force -EA SilentlyContinue; if($hasCover){ & $ff -y -hide_banner -loglevel error -i $src -map 0:a -map 0:v:0 -c:a libmp3lame -b:a 320k -c:v mjpeg -q:v 4 -vf 'scale=min(600\,iw):-1' -id3v2_version 3 $dest 2>$null } else { & $ff -y -hide_banner -loglevel error -i $src -vn -c:a libmp3lame -b:a 320k $dest 2>$null }; if(Test-Path -LiteralPath $dest){ return 'ok' } else { return 'fail' } }; function Get-OutDir($srcFile,$srcRoot,$outRoot){ $rel=$srcFile.Substring($srcRoot.Length).TrimStart('\'); $rd=Split-Path $rel -Parent; if($rd){ $dd=Join-Path $outRoot $rd } else { $dd=$outRoot }; New-Item -ItemType Directory -Path $dd -Force | Out-Null; return $dd }; foreach($item in $items){ if(-not (Test-Path -LiteralPath $item)){ continue }; $it=Get-Item -LiteralPath $item; if($it.PSIsContainer){ $src=$it.FullName.TrimEnd('\'); $parent=Split-Path $src -Parent; $name=Split-Path $src -Leaf; if($copyImg){ $outRoot=Join-Path $parent ($name + '_MP3_IMG') } else { $outRoot=Join-Path $parent ($name + '_MP3') }; New-Item -ItemType Directory -Path $outRoot -Force | Out-Null; Write-Host ''; Write-Host ('文件夹 ' + $src) -ForegroundColor Cyan; Write-Host ('输出   ' + $outRoot) -ForegroundColor Cyan; $audio=@(Get-ChildItem -LiteralPath $src -Recurse -File | Where-Object { $_.Extension -match '^\.(flac|tak|mka)$' }); $side=@(Get-ChildItem -LiteralPath $src -Recurse -File | Where-Object { $_.Extension -match '^\.(cue|log)$' }); $mp3s=@(Get-ChildItem -LiteralPath $src -Recurse -File | Where-Object { $_.Extension -match '^\.mp3$' }); $imgs=@(); if($copyImg){ $imgs=@(Get-ChildItem -LiteralPath $src -Recurse -File | Where-Object { $imgExts -contains $_.Extension.ToLower() }) }; if($audio.Count -gt 0){ Write-Host ('  共 ' + $audio.Count + ' 个音频') -ForegroundColor Yellow }; if($mp3s.Count -gt 0){ Write-Host ('  共 ' + $mp3s.Count + ' 个 MP3') -ForegroundColor Gray }; if($side.Count -gt 0){ Write-Host ('  共 ' + $side.Count + ' 个 cue/log') -ForegroundColor Gray }; if($imgs.Count -gt 0){ Write-Host ('  共 ' + $imgs.Count + ' 个图片') -ForegroundColor Gray }; Write-Host ''; $i=0; foreach($f in $audio){ $i++; $dd=Get-OutDir $f.FullName $src $outRoot; $dest=Join-Path $dd ($f.BaseName + '.mp3'); Write-Host ('  [' + $i + '/' + $audio.Count + '] ' + $f.Name) -NoNewline; $r=Convert-One $f.FullName $dest; if($r -eq 'ok'){ Write-Host '  [成功]' -ForegroundColor Green; $total_ok++ } elseif($r -eq 'skip'){ Write-Host '  [跳过]' -ForegroundColor DarkGray; $total_skip++ } else { Write-Host '  [失败]' -ForegroundColor Red; $total_fail++; $fail_list += $f.FullName } }; foreach($f in $mp3s){ $dd=Get-OutDir $f.FullName $src $outRoot; $dest=Join-Path $dd $f.Name; if(-not (Test-Path -LiteralPath $dest)){ Copy-Item -LiteralPath $f.FullName -Destination $dest -Force; $total_mp3++ } }; foreach($f in $side){ $dd=Get-OutDir $f.FullName $src $outRoot; $dest=Join-Path $dd $f.Name; if(-not (Test-Path -LiteralPath $dest)){ Copy-Item -LiteralPath $f.FullName -Destination $dest -Force; $total_side++ } }; foreach($f in $imgs){ $dd=Get-OutDir $f.FullName $src $outRoot; $dest=Join-Path $dd $f.Name; if(-not (Test-Path -LiteralPath $dest)){ Copy-Item -LiteralPath $f.FullName -Destination $dest -Force; $total_img++ } } } else { $ext=$it.Extension.ToLower(); if($ext -eq '.mp3'){ Write-Host ''; Write-Host ('跳过 MP3（不转换） ' + $it.Name) -ForegroundColor DarkGray; continue }; if($ext -notmatch '^\.(flac|tak|mka)$'){ Write-Host ''; Write-Host ('跳过 不支持 ' + $it.Name) -ForegroundColor DarkGray; continue }; $dest=Join-Path $it.DirectoryName ($it.BaseName + '.mp3'); Write-Host ''; Write-Host ($it.Name) -NoNewline; $r=Convert-One $it.FullName $dest; if($r -eq 'ok'){ Write-Host '  [成功]' -ForegroundColor Green; $total_ok++ } elseif($r -eq 'skip'){ Write-Host '  [跳过]' -ForegroundColor DarkGray; $total_skip++ } else { Write-Host '  [失败]' -ForegroundColor Red; $total_fail++; $fail_list += $it.FullName } } }; Write-Host ''; Write-Host '============================================' -ForegroundColor Cyan; Write-Host ('  成功 ' + $total_ok + ' 个') -ForegroundColor Green; Write-Host ('  跳过 ' + $total_skip + ' 个') -ForegroundColor DarkGray; if($total_fail -gt 0){ Write-Host ('  失败 ' + $total_fail + ' 个') -ForegroundColor Red; foreach($f in $fail_list){ Write-Host ('    - ' + $f) -ForegroundColor Red } }; Write-Host ('  MP3 复制 ' + $total_mp3 + ' 个') -ForegroundColor Cyan; Write-Host ('  cue/log 复制 ' + $total_side + ' 个') -ForegroundColor Cyan; if($copyImg){ Write-Host ('  图片复制 ' + $total_img + ' 个') -ForegroundColor Cyan }; Write-Host '============================================' -ForegroundColor Cyan; [Console]::Out.Flush() }"

del "%TMPLIST%" 2>nul
pause
exit /b

:CheckBypass
if "%BYPASS%"=="000" exit /b 0
pause
exit /b 1