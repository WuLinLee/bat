@echo off
chcp 65001 >nul

for %%I in ("%~dp0..\ffmpeg-gs") do set "TOOLDIR=%%~fI"
if not exist "%TOOLDIR%\ffmpeg.exe" set "TOOLDIR=E:\ffmpeg-gs"
set "FF=%TOOLDIR%\ffmpeg.exe"

if "%~1"=="" (
    echo 请把视频文件拖到本文件上使用。
    pause
    exit /b
)

if not exist "%FF%" (
    echo 找不到 ffmpeg.exe：%FF%
    pause
    exit /b
)

rem ========== 检查路径和文件名是否含危险字符 ==========
setlocal disabledelayedexpansion
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
echo 已选择跳过检查，继续执行（若转码失败请改名后重试）...
:after_bypass
setlocal enabledelayedexpansion
rem ==============================================

rem ========== 输出格式 ==========
powershell -NoProfile -Command "Write-Host ''; Write-Host '========== 输出格式 ==========' -ForegroundColor Cyan; Write-Host ''; Write-Host '  1. MKV    支持全部编码和字幕' -ForegroundColor White; Write-Host '  2. MP4    兼容性好 适合手机和播放器' -ForegroundColor White; Write-Host ''"
choice /c 12 /n /m "请选择 (1/2): "
if errorlevel 2 (
    set "FMTEXT=MP4"
    set "EXT=.mp4"
    set "FMT_MODE=mp4"
    goto fmt_ok
)
if errorlevel 1 (
    set "FMTEXT=MKV"
    set "EXT=.mkv"
    set "FMT_MODE=mkv"
    goto fmt_ok
)
echo 无效选择，退出
pause
exit /b

:fmt_ok
echo.
echo   已选择输出格式：!FMTEXT!
echo.

rem ========== 视频编码 ==========
powershell -NoProfile -Command "Write-Host '========== 视频编码 ==========' -ForegroundColor Cyan; Write-Host ''; Write-Host '  1. 复制    无损 保持原编码' -ForegroundColor White; Write-Host '  2. H264    libx264 重新编码' -ForegroundColor White; Write-Host '  3. H265    libx265 重新编码' -ForegroundColor White; Write-Host ''"
choice /c 123 /n /m "请选择 (1/2/3): "
if errorlevel 3 (
    set "VCODE=-c:v libx265 -crf 28"
    if "!FMT_MODE!"=="mp4" set "VCODE=-c:v libx265 -crf 28 -tag:v hvc1"
    set "VTEXT=H265"
    goto video_ok
)
if errorlevel 2 (
    set "VCODE=-c:v libx264 -crf 23"
    set "VTEXT=H264"
    goto video_ok
)
if errorlevel 1 (
    set "VCODE=-c:v copy"
    set "VTEXT=复制"
    goto video_ok
)
echo 无效选择，退出
pause
exit /b

:video_ok
echo.
echo   已选择视频：!VTEXT!
echo.

rem ========== 音轨 ==========
rem --- 修复：用 disabled 捕获带 ! 的路径，再用 !VAR! 传给 ffmpeg ---
set "TMPINFO=%TEMP%\ffinfo_%RANDOM%.txt"
setlocal disabledelayedexpansion
set "SRC_PROBE=%~sf1"
if not exist "%SRC_PROBE%" set "SRC_PROBE=%~f1"
if "%SRC_PROBE%"=="" set "SRC_PROBE=%~f1"
setlocal enabledelayedexpansion
"!FF!" -i "!SRC_PROBE!" 2>"%TMPINFO%"
endlocal
endlocal

powershell -NoProfile -Command "Write-Host '========== 选择音轨 ==========' -ForegroundColor Cyan; Write-Host ''"
set /a IDX=0
for /f "tokens=*" %%L in ('findstr /c:"Audio:" "%TMPINFO%"') do (
    set /a IDX+=1
    echo   !IDX!. %%L
)
echo.
if !IDX!==0 (
    echo   未检测到音轨信息 使用默认第一条
    set "AINDEX=0"
    set "AIDXSHOW=1"
    goto audio_ok
)
set /p "USRIDX=选择音轨编号 (默认1): "
if "!USRIDX!"=="" set "USRIDX=1"
set /a AINDEX=!USRIDX!-1
set "AIDXSHOW=!USRIDX!"

:audio_ok
echo.
echo   已选择音轨：第 !AIDXSHOW! 条
echo.

rem ========== 音频编码 ==========
if "!FMT_MODE!"=="mkv" goto audio_menu_mkv
goto audio_menu_mp4

:audio_menu_mkv
powershell -NoProfile -Command "Write-Host '========== 音频编码 ==========' -ForegroundColor Cyan; Write-Host ''; Write-Host '  1. 复制    无损 支持所有格式' -ForegroundColor White; Write-Host '  2. AAC     192k 有损' -ForegroundColor White; Write-Host '  3. MP3     192k 有损' -ForegroundColor White; Write-Host '  4. AC3     192k 有损' -ForegroundColor White; Write-Host ''; Write-Host '  MKV 支持 FLAC DTS 等无损格式' -ForegroundColor Green; Write-Host '  推荐选 1 复制 音质零损失' -ForegroundColor Green; Write-Host ''"
choice /c 1234 /n /m "请选择 (1/2/3/4): "
if errorlevel 4 (
    set "ACODE=-map 0:a:!AINDEX! -c:a ac3 -b:a 192k"
    set "ATEXT=AC3"
    goto audio_codec_ok
)
if errorlevel 3 (
    set "ACODE=-map 0:a:!AINDEX! -c:a libmp3lame -b:a 192k"
    set "ATEXT=MP3"
    goto audio_codec_ok
)
if errorlevel 2 (
    set "ACODE=-map 0:a:!AINDEX! -c:a aac -b:a 192k"
    set "ATEXT=AAC"
    goto audio_codec_ok
)
if errorlevel 1 (
    set "ACODE=-map 0:a:!AINDEX! -c:a copy"
    set "ATEXT=复制"
    goto audio_codec_ok
)
echo 无效选择，退出
pause
exit /b

:audio_menu_mp4
powershell -NoProfile -Command "Write-Host '========== 音频编码 ==========' -ForegroundColor Cyan; Write-Host ''; Write-Host '  1. AAC    192k' -ForegroundColor White; Write-Host '  2. MP3    192k' -ForegroundColor White; Write-Host '  3. AC3    192k' -ForegroundColor White; Write-Host '  4. 复制   保持原编码' -ForegroundColor White; Write-Host ''; Write-Host '  注意 FLAC 和 DTS 格式 MP4 不支持' -ForegroundColor Yellow; Write-Host '  选复制可能失败 请改选 AAC' -ForegroundColor Yellow; Write-Host ''"
choice /c 1234 /n /m "请选择 (1/2/3/4): "
if errorlevel 4 (
    set "ACODE=-map 0:a:!AINDEX! -c:a copy"
    set "ATEXT=复制"
    goto audio_codec_ok
)
if errorlevel 3 (
    set "ACODE=-map 0:a:!AINDEX! -c:a ac3 -b:a 192k"
    set "ATEXT=AC3"
    goto audio_codec_ok
)
if errorlevel 2 (
    set "ACODE=-map 0:a:!AINDEX! -c:a libmp3lame -b:a 192k"
    set "ATEXT=MP3"
    goto audio_codec_ok
)
if errorlevel 1 (
    set "ACODE=-map 0:a:!AINDEX! -c:a aac -b:a 192k"
    set "ATEXT=AAC"
    goto audio_codec_ok
)
echo 无效选择，退出
pause
exit /b

:audio_codec_ok
echo.
echo   已选择音频编码：!ATEXT!
echo.

rem ========== 探测字幕类型 ==========
set "TEXTSUB_MAP="
set /a SUBIDX=0
set /a TEXTCOUNT=0
set /a GRAPHCOUNT=0
for /f "tokens=*" %%L in ('findstr /c:"Subtitle:" "%TMPINFO%"') do (
    echo %%L | findstr /i /c:"hdmv_pgs" /c:"dvd_subtitle" /c:"dvb_subtitle" /c:"xsub" >nul
    if errorlevel 1 (
        set "TEXTSUB_MAP=!TEXTSUB_MAP! -map 0:s:!SUBIDX!"
        set /a TEXTCOUNT+=1
    ) else (
        set /a GRAPHCOUNT+=1
    )
    set /a SUBIDX+=1
)
del "%TMPINFO%" 2>nul

rem ========== 字幕 ==========
if "!FMT_MODE!"=="mkv" goto sub_menu_mkv
goto sub_menu_mp4

:sub_menu_mkv
powershell -NoProfile -Command "Write-Host '========== 字幕 ==========' -ForegroundColor Cyan; Write-Host ''"
powershell -NoProfile -Command "Write-Host ('  文本字幕：!TEXTCOUNT! 条') -ForegroundColor White; Write-Host ('  图形字幕：!GRAPHCOUNT! 条') -ForegroundColor White"
echo.
powershell -NoProfile -Command "Write-Host '  1. 保留全部字幕 包括图形字幕' -ForegroundColor White; Write-Host '  2. 删除全部字幕' -ForegroundColor White; Write-Host ''; Write-Host '  MKV 支持 PGS ASS 等所有字幕格式' -ForegroundColor Green; Write-Host ''"
choice /c 12 /n /m "请选择 (1/2): "
if errorlevel 2 (
    set "SCODE=-sn"
    set "STEXT=删除全部"
    goto sub_ok
)
if errorlevel 1 (
    if !SUBIDX!==0 (
        echo.
        echo   没有字幕 自动删除
        set "SCODE=-sn"
        set "STEXT=删除全部"
        goto sub_ok
    )
    set "SCODE=-map 0:s? -c:s copy"
    set "STEXT=保留全部 !SUBIDX! 条"
    goto sub_ok
)
echo 无效选择，退出
pause
exit /b

:sub_menu_mp4
powershell -NoProfile -Command "Write-Host '========== 字幕 ==========' -ForegroundColor Cyan; Write-Host ''"
powershell -NoProfile -Command "Write-Host ('  文本字幕：!TEXTCOUNT! 条') -ForegroundColor White; Write-Host ('  图形字幕：!GRAPHCOUNT! 条   MP4 不支持 自动跳过') -ForegroundColor Yellow"
echo.
powershell -NoProfile -Command "Write-Host '  1. 保留文本字幕' -ForegroundColor White; Write-Host '  2. 删除全部字幕' -ForegroundColor White; Write-Host ''"
choice /c 12 /n /m "请选择 (1/2): "
if errorlevel 2 (
    set "SCODE=-sn"
    set "STEXT=删除全部"
    goto sub_ok
)
if errorlevel 1 (
    if !TEXTCOUNT!==0 (
        echo.
        echo   没有文本字幕 自动删除全部
        set "SCODE=-sn"
        set "STEXT=删除全部"
        goto sub_ok
    )
    set "SCODE=!TEXTSUB_MAP! -c:s mov_text"
    set "STEXT=保留文本字幕 !TEXTCOUNT! 条"
    goto sub_ok
)
echo 无效选择，退出
pause
exit /b

:sub_ok
echo.
echo   已选择字幕：!STEXT!
echo.

rem ========== 确认 ==========
powershell -NoProfile -Command "Write-Host '========== 确认 ==========' -ForegroundColor Cyan; Write-Host ''; Write-Host ('  输出格式：!FMTEXT!') -ForegroundColor White; Write-Host ('  视频：!VTEXT!') -ForegroundColor White; Write-Host ('  音轨：第 !AIDXSHOW! 条') -ForegroundColor White; Write-Host ('  音频编码：!ATEXT!') -ForegroundColor White; Write-Host ('  字幕：!STEXT!') -ForegroundColor White; Write-Host ''; Write-Host ('  输出到源文件同目录 文件名加 -转码!EXT!') -ForegroundColor Gray; Write-Host ''; Write-Host '  按任意键开始转换 或关闭窗口取消...' -ForegroundColor Green"
pause >nul

:loop
setlocal disabledelayedexpansion
if "%~1"=="" (
  endlocal
  goto done
)
rem 优先短路径，短路径没有 % 和 !，可绕过CMD解析坑
set "SRC=%~sf1"
if not exist "%SRC%" set "SRC=%~f1"
if "%SRC%"=="" set "SRC=%~f1"
set "OUTBASE=%~sdpn1"
if not exist "%OUTBASE%" set "OUTBASE=%~dpn1"
if "%OUTBASE%"=="" set "OUTBASE=%~dpn1"
set "INNAME=%~nx1"
setlocal enabledelayedexpansion
set "SRC=!SRC!"
set "OUTBASE=!OUTBASE!"
set "INNAME=!INNAME!"
set "OUT=!OUTBASE!-转码!EXT!"
if exist "!OUT!" del "!OUT!" 2>nul
echo.
echo 正在转码：!INNAME!
echo 输入路径: !SRC!
"!FF!" -y -i "!SRC!" -map 0:v:0 !ACODE! !SCODE! !VCODE! "!OUT!"
if not exist "!OUT!" (
    echo   [失败] !INNAME!
) else (
    echo   [成功] !INNAME!
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