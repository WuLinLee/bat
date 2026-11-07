@echo off
chcp 65001 >nul
setlocal disabledelayedexpansion

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
set "PYSCRIPT=%TEMP%\pdf_split_%RANDOM%.py"
if exist "%TMPLIST%" del "%TMPLIST%"
if exist "%PYSCRIPT%" del "%PYSCRIPT%"

rem 在 disabledelayedexpansion 下写入路径，防止 ! 和 % 被 CMD 截断
>>"%TMPLIST%" echo %~f1

for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do set "DESKTOP=%%D"

> "%PYSCRIPT%" echo import sys, os
>>"%PYSCRIPT%" echo from datetime import datetime
>>"%PYSCRIPT%" echo import pikepdf
>>"%PYSCRIPT%" echo from pikepdf import Pdf
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
>>"%PYSCRIPT%" echo pdf_path = files[0]
>>"%PYSCRIPT%" echo desktop = sys.argv[2]
>>"%PYSCRIPT%" echo.
>>"%PYSCRIPT%" echo src = Pdf.open(pdf_path)
>>"%PYSCRIPT%" echo total = len(src.pages)
>>"%PYSCRIPT%" echo.
>>"%PYSCRIPT%" echo print()
>>"%PYSCRIPT%" echo print(f'  文件：{os.path.basename(pdf_path)}')
>>"%PYSCRIPT%" echo print(f'  总页数：{total}')
>>"%PYSCRIPT%" echo print()
>>"%PYSCRIPT%" echo print('  输入页码范围，空格分隔，每个范围生成一个 PDF')
>>"%PYSCRIPT%" echo print('  例1：1-3 4-9 10-17')
>>"%PYSCRIPT%" echo print('  例2：1-5 8-11 10-16 18-33 可跳过 可重叠')
>>"%PYSCRIPT%" echo print()
>>"%PYSCRIPT%" echo.
>>"%PYSCRIPT%" echo while True:
>>"%PYSCRIPT%" echo     user_input = input('请输入范围: ').strip()
>>"%PYSCRIPT%" echo     if not user_input:
>>"%PYSCRIPT%" echo         print('  请输入至少一个范围')
>>"%PYSCRIPT%" echo         continue
>>"%PYSCRIPT%" echo     parts = user_input.split()
>>"%PYSCRIPT%" echo     ranges = []
>>"%PYSCRIPT%" echo     ok = True
>>"%PYSCRIPT%" echo     for r in parts:
>>"%PYSCRIPT%" echo         try:
>>"%PYSCRIPT%" echo             if '-' in r:
>>"%PYSCRIPT%" echo                 a, b = r.split('-', 1)
>>"%PYSCRIPT%" echo                 start = int(a)
>>"%PYSCRIPT%" echo                 end = int(b)
>>"%PYSCRIPT%" echo             else:
>>"%PYSCRIPT%" echo                 start = end = int(r)
>>"%PYSCRIPT%" echo         except ValueError:
>>"%PYSCRIPT%" echo             print(f'  格式错误：{r}')
>>"%PYSCRIPT%" echo             ok = False
>>"%PYSCRIPT%" echo             break
>>"%PYSCRIPT%" echo         if start ^< 1 or end ^< 1 or start ^> total or end ^> total:
>>"%PYSCRIPT%" echo             print(f'  页码超出范围：{r}  必须在 1 到 {total} 之间')
>>"%PYSCRIPT%" echo             ok = False
>>"%PYSCRIPT%" echo             break
>>"%PYSCRIPT%" echo         if start ^> end:
>>"%PYSCRIPT%" echo             print(f'  起始页大于结束页：{r}')
>>"%PYSCRIPT%" echo             ok = False
>>"%PYSCRIPT%" echo             break
>>"%PYSCRIPT%" echo         ranges.append((start, end))
>>"%PYSCRIPT%" echo     if ok and ranges:
>>"%PYSCRIPT%" echo         break
>>"%PYSCRIPT%" echo.
>>"%PYSCRIPT%" echo base = os.path.splitext(os.path.basename(pdf_path))[0]
>>"%PYSCRIPT%" echo now = datetime.now()
>>"%PYSCRIPT%" echo timestamp = now.strftime('%%Y.%%m.%%d %%H.%%M')
>>"%PYSCRIPT%" echo.
>>"%PYSCRIPT%" echo print()
>>"%PYSCRIPT%" echo print(f'  共生成 {len(ranges)} 个 PDF：')
>>"%PYSCRIPT%" echo print()
>>"%PYSCRIPT%" echo.
>>"%PYSCRIPT%" echo for (start, end) in ranges:
>>"%PYSCRIPT%" echo     if start == end:
>>"%PYSCRIPT%" echo         page_str = f'({start})'
>>"%PYSCRIPT%" echo     else:
>>"%PYSCRIPT%" echo         page_str = f'({start}-{end})'
>>"%PYSCRIPT%" echo     out = os.path.join(desktop, f'{base} {page_str} {timestamp}.pdf')
>>"%PYSCRIPT%" echo     if os.path.exists(out):
>>"%PYSCRIPT%" echo         print(f'    已存在：{os.path.basename(out)}')
>>"%PYSCRIPT%" echo         answer = input('    覆盖？(Y=覆盖 / 其他=跳过): ').strip().lower()
>>"%PYSCRIPT%" echo         if not answer == 'y':
>>"%PYSCRIPT%" echo             print(f'    跳过：{os.path.basename(out)}')
>>"%PYSCRIPT%" echo             continue
>>"%PYSCRIPT%" echo     out_pdf = Pdf.new()
>>"%PYSCRIPT%" echo     for i in range(start - 1, end):
>>"%PYSCRIPT%" echo         out_pdf.pages.append(src.pages[i])
>>"%PYSCRIPT%" echo     out_pdf.save(out)
>>"%PYSCRIPT%" echo     print(f'    {os.path.basename(out)}')
>>"%PYSCRIPT%" echo.
>>"%PYSCRIPT%" echo src.close()
>>"%PYSCRIPT%" echo print()
>>"%PYSCRIPT%" echo print('  完成')

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