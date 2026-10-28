@echo off&cd /d %~dp0
if not exist tcping.exe (echo 程序同目录缺少tcping.exe 请解压后再运行&pause>nul&exit)
if not "%1"=="" title 通过多窗口实现多线程，扫描完成自动关闭&call :扫描 %* & exit
Setlocal enabledelayedexpansion
>temp.txt echo ----扫描结果----


rem 如需同时扫描多个端口，用空格隔开
set 端口=2333
set 超时=0.2
color e0&mode con cols=60 lines=30
title 扫描局域网IP指定端口并打开（通过多窗口实现多线程）
ipconfig|find "IPv4"


:多线程
for /f "tokens=2 delims=:" %%z in ('ipconfig^|find "IPv4"') do (
  for %%y in (%端口%) do (
    start "" "%~0" %%z %%y 0 49
    start "" "%~0" %%z %%y 50 99
    start "" "%~0" %%z %%y 100 149
    start "" "%~0" %%z %%y 150 199
    start "" "%~0" %%z %%y 200 255
))
echo 按任意键列出扫描结果
pause>nul
more temp.txt


:输入框
set 输入=
set /p 输入=----按enter刷新，或输入指定端口号扫描（1-65536）:
if "%输入%"=="" goto 多线程
set /a 输入=输入+0
if %输入% LEQ 0 goto 输入框
if %输入% GEQ 65536 goto 输入框
set 端口=%输入%
goto 多线程


:扫描
for /f "tokens=1-3 delims=." %%a in ("%1") do (
  for /l %%d in (%3,1,%4) do (
    tcping -n 1 -w %超时% %%a.%%b.%%c.%%d %2 | find "Port is open" && call :打开 %%a.%%b.%%c.%%d %2
))
exit /b


:打开
if %2==80 start "" http://%1:%2
if %2==7860 start "" http://%1:%2
if %2==2333 start "" http://%1:%2
if %2==21 start explorer.exe ftp://%1:%2
if %2==2121 start explorer.exe ftp://%1:%2
if %2==3721 start explorer.exe ftp://%1:%2
>>temp.txt echo %1:%2
exit /b