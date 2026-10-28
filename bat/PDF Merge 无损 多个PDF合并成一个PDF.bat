@echo off
chcp 65001 >nul
setlocal disabledelayedexpansion

if "%~1"=="" (
    echo 请把多个 PDF 文件拖到本文件上使用。
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

set "TMPLIST=%TEMP%\pdf_merge_%RANDOM%.txt"
set "PYSCRIPT=%TEMP%\pdf_merge_%RANDOM%.py"
if exist "%TMPLIST%" del "%TMPLIST%"
if exist "%PYSCRIPT%" del "%PYSCRIPT%"

:loop
if "%~1"=="" goto run
>>"%TMPLIST%" echo %~f1
shift
goto loop

:run

for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do set "DESKTOP=%%D"

> "%PYSCRIPT%" echo import sys, os, random
>>"%PYSCRIPT%" echo from datetime import datetime
>>"%PYSCRIPT%" echo import pikepdf
>>"%PYSCRIPT%" echo from pikepdf import Pdf, Array
>>"%PYSCRIPT%" echo.
>>"%PYSCRIPT%" echo try:
>>"%PYSCRIPT%" echo     sys.stdout.reconfigure(encoding='utf-8')
>>"%PYSCRIPT%" echo except Exception:
>>"%PYSCRIPT%" echo     pass
>>"%PYSCRIPT%" echo.
>>"%PYSCRIPT%" echo with open(sys.argv[1], 'r', encoding='utf-8') as f:
>>"%PYSCRIPT%" echo     files = [line.rstrip('\n') for line in f if line.strip()]
>>"%PYSCRIPT%" echo.
>>"%PYSCRIPT%" echo if not files:
>>"%PYSCRIPT%" echo     print('没有文件')
>>"%PYSCRIPT%" echo     sys.exit(1)
>>"%PYSCRIPT%" echo.
>>"%PYSCRIPT%" echo print()
>>"%PYSCRIPT%" echo print('已拖入的文件：')
>>"%PYSCRIPT%" echo print()
>>"%PYSCRIPT%" echo for i, f in enumerate(files):
>>"%PYSCRIPT%" echo     try:
>>"%PYSCRIPT%" echo         _n = len(Pdf.open(f).pages)
>>"%PYSCRIPT%" echo     except Exception:
>>"%PYSCRIPT%" echo         _n = '?'
>>"%PYSCRIPT%" echo     print(f'  [{i+1}] {os.path.basename(f)}  （{_n}页）')
>>"%PYSCRIPT%" echo print()
>>"%PYSCRIPT%" echo user_input = input('请输入顺序（如 2 4 6 3 1 10，空格分隔，直接回车=默认顺序）: ').strip()
>>"%PYSCRIPT%" echo.
>>"%PYSCRIPT%" echo if not user_input:
>>"%PYSCRIPT%" echo     order = list(range(1, len(files)+1))
>>"%PYSCRIPT%" echo else:
>>"%PYSCRIPT%" echo     order = []
>>"%PYSCRIPT%" echo     for x in user_input.split():
>>"%PYSCRIPT%" echo         try:
>>"%PYSCRIPT%" echo             n = int(x)
>>"%PYSCRIPT%" echo             if 1 ^<= n ^<= len(files):
>>"%PYSCRIPT%" echo                 order.append(n)
>>"%PYSCRIPT%" echo         except ValueError:
>>"%PYSCRIPT%" echo             pass
>>"%PYSCRIPT%" echo.
>>"%PYSCRIPT%" echo if not order:
>>"%PYSCRIPT%" echo     print('顺序无效')
>>"%PYSCRIPT%" echo     sys.exit(1)
>>"%PYSCRIPT%" echo.
>>"%PYSCRIPT%" echo sorted_files = [files[n-1] for n in order]
>>"%PYSCRIPT%" echo.
>>"%PYSCRIPT%" echo print()
>>"%PYSCRIPT%" echo print('请选择合并模式：')
>>"%PYSCRIPT%" echo print('  1 = 不改变任何东西（保持原样）')
>>"%PYSCRIPT%" echo print('  2 = 统一页面宽度（内容自动缩放）')
>>"%PYSCRIPT%" echo print()
>>"%PYSCRIPT%" echo mode = input('输入数字（默认1）: ').strip()
>>"%PYSCRIPT%" echo if not mode:
>>"%PYSCRIPT%" echo     mode = '1'
>>"%PYSCRIPT%" echo.
>>"%PYSCRIPT%" echo out_pdf = Pdf.new()
>>"%PYSCRIPT%" echo.
>>"%PYSCRIPT%" echo if mode == '2':
>>"%PYSCRIPT%" echo     max_width = 0
>>"%PYSCRIPT%" echo     for f in sorted_files:
>>"%PYSCRIPT%" echo         src = Pdf.open(f)
>>"%PYSCRIPT%" echo         for page in src.pages:
>>"%PYSCRIPT%" echo             w = float(page.MediaBox[2]) - float(page.MediaBox[0])
>>"%PYSCRIPT%" echo             if w ^> max_width:
>>"%PYSCRIPT%" echo                 max_width = w
>>"%PYSCRIPT%" echo         src.close()
>>"%PYSCRIPT%" echo     print(f'  最大宽度：{max_width:.1f} pt')
>>"%PYSCRIPT%" echo     for f in sorted_files:
>>"%PYSCRIPT%" echo         src = Pdf.open(f)
>>"%PYSCRIPT%" echo         for page in src.pages:
>>"%PYSCRIPT%" echo             w = float(page.MediaBox[2]) - float(page.MediaBox[0])
>>"%PYSCRIPT%" echo             h = float(page.MediaBox[3]) - float(page.MediaBox[1])
>>"%PYSCRIPT%" echo             contents = page.obj['/Contents']
>>"%PYSCRIPT%" echo             if isinstance(contents, Array):
>>"%PYSCRIPT%" echo                 parts = []
>>"%PYSCRIPT%" echo                 for s in contents:
>>"%PYSCRIPT%" echo                     parts.append(s.read_bytes())
>>"%PYSCRIPT%" echo                 original = b'\n'.join(parts)
>>"%PYSCRIPT%" echo             else:
>>"%PYSCRIPT%" echo                 original = contents.read_bytes()
>>"%PYSCRIPT%" echo             out_pdf.pages.append(page)
>>"%PYSCRIPT%" echo             new_page = out_pdf.pages[-1]
>>"%PYSCRIPT%" echo             if w ^< max_width:
>>"%PYSCRIPT%" echo                 scale = max_width / w
>>"%PYSCRIPT%" echo                 new_content = b'q ' + f'{scale:.6f} 0 0 {scale:.6f} 0 0 cm\n'.encode() + original + b'\nQ\n'
>>"%PYSCRIPT%" echo                 new_page.obj['/Contents'] = out_pdf.make_stream(new_content)
>>"%PYSCRIPT%" echo                 new_page.MediaBox = Array([0, 0, max_width, h * scale])
>>"%PYSCRIPT%" echo         src.close()
>>"%PYSCRIPT%" echo else:
>>"%PYSCRIPT%" echo     for f in sorted_files:
>>"%PYSCRIPT%" echo         src = Pdf.open(f)
>>"%PYSCRIPT%" echo         for page in src.pages:
>>"%PYSCRIPT%" echo             out_pdf.pages.append(page)
>>"%PYSCRIPT%" echo         src.close()
>>"%PYSCRIPT%" echo.
>>"%PYSCRIPT%" echo desktop = sys.argv[2]
>>"%PYSCRIPT%" echo now = datetime.now()
>>"%PYSCRIPT%" echo timestamp = now.strftime('%%Y.%%m.%%d %%H.%%M')
>>"%PYSCRIPT%" echo rand = ''.join(random.choices('abcdefghijklmnopqrstuvwxyz', k=4))
>>"%PYSCRIPT%" echo out = os.path.join(desktop, f'合并输出{len(sorted_files)}个 {timestamp} {rand}.pdf')
>>"%PYSCRIPT%" echo out_pdf.save(out)
>>"%PYSCRIPT%" echo print()
>>"%PYSCRIPT%" echo print(f'完成：{out}')

python "%PYSCRIPT%" "%TMPLIST%" "%DESKTOP%"
if errorlevel 1 (
    echo.
    echo   失败：请确认已安装 Python 和 pikepdf
)

del "%TMPLIST%" 2>nul
del "%PYSCRIPT%" 2>nul
pause
exit /b

:CheckBypass
if "%BYPASS%"=="000" exit /b 0
pause
exit /b 1