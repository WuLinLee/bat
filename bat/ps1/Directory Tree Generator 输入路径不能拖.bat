@echo off
chcp 65001 >nul
title Directory Tree Generator v5.5
setlocal EnableExtensions

echo ==========================================
echo       Directory Tree Generator v5.5
echo ==========================================
echo.

rem ============================================
rem  [1] Self-check: detect leftover temp files
rem ============================================
:CHECK_LEFTOVERS
set "LEFTOVERS=0"
for %%F in ("%TEMP%\_gentree_*.ps1") do if exist "%%F" set "LEFTOVERS=1"

if "%LEFTOVERS%"=="0" goto SKIP_LEFTOVERS

echo.
echo ##########################################
echo #  [WARNING] Leftover temp files found   #
echo #  From a previous interrupted run       #
echo ##########################################
echo.
echo   These files contain:
echo     - the scan script for a previous run
echo     - possibly paths you scanned before
echo.
echo   Location: %TEMP%
echo.
echo   File list:
echo   ----------------------------------------
for %%F in ("%TEMP%\_gentree_*.ps1") do (
    if exist "%%F" echo     %%~fF  ^(%%~zF bytes^)
)
echo   ----------------------------------------
echo.
echo   These are SAFE to delete.
echo   They will NOT affect your tree.txt files.
echo.
echo   Auto-delete in 15 seconds.
echo   Press N to keep them, or Y to delete now.
echo.
choice /C YN /T 15 /D Y /M "Delete leftovers now"
if errorlevel 2 goto KEEP_LOVERS

for %%F in ("%TEMP%\_gentree_*.ps1") do (
    if exist "%%F" del "%%F" >nul 2>&1
)
echo.
echo   [OK] Leftovers cleaned.
echo.
goto SKIP_LEFTOVERS

:KEEP_LOVERS
echo.
echo   [SKIP] Leftovers kept as-is. Continuing...
echo.
timeout /t 1 /nobreak >nul
echo.

:SKIP_LEFTOVERS

rem ============================================
rem  [2] Check tree.ps1 exists
rem ============================================
if not exist "%~dp0tree.ps1" goto NO_PS1

rem ============================================
rem  [3] Resolve desktop path from registry
rem ============================================
set "DESKTOP="
for /f "tokens=2,*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" /v Desktop 2^>nul') do set "DESKTOP=%%B"
if defined DESKTOP call set "DESKTOP=%DESKTOP%"
if not defined DESKTOP set "DESKTOP=%USERPROFILE%\Desktop"
if not exist "%DESKTOP%" set "DESKTOP=%USERPROFILE%\Desktop"

rem ============================================
rem  [4] Ask for scan path
rem ============================================
:ASK_ROOT
set "ROOT="
set /p "ROOT=Enter path to scan (e.g. E:\Sunamu-2.0.0-win): "
if not defined ROOT goto EMPTY_ROOT
set "ROOT=%ROOT:"=%"
if exist "%ROOT%" goto GOOD_ROOT
echo [ERROR] path does not exist: %ROOT%
goto ASK_ROOT

:EMPTY_ROOT
echo [ERROR] path cannot be empty
goto ASK_ROOT

:GOOD_ROOT

echo.
echo Scan mode:
echo   [0] Unlimited (default, scan everything)
echo   [1] Fast mode (limit depth + fold large dirs)
set "MODE="
set /p "MODE=Choose (0/1, Enter=0): "
if not defined MODE set "MODE=0"
if not "%MODE%"=="0" if not "%MODE%"=="1" set "MODE=0"

set "MAXDEPTH=999999"
set "MAXFILES=0"
if not "%MODE%"=="1" goto SKIP_FAST_PARAMS

set "MAXDEPTH="
set /p "MAXDEPTH=Max depth (Enter=3): "
if not defined MAXDEPTH set "MAXDEPTH=3"
echo %MAXDEPTH%| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo [WARN] invalid depth, using default 3
    set "MAXDEPTH=3"
)

set "MAXFILES="
set /p "MAXFILES=Max files per dir (Enter=20): "
if not defined MAXFILES set "MAXFILES=20"
echo %MAXFILES%| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo [WARN] invalid file limit, using default 20
    set "MAXFILES=20"
)

:SKIP_FAST_PARAMS

echo.
echo Follow symlinks / junctions into their target directory?
echo   [N] No  (default, SAFER - only show link target, do not enter)
echo   [Y] Yes (enter linked directories - may scan outside root!)
set "FOLLOWLINKS="
set /p "FOLLOWLINKS=Follow links (Y/N, Enter=N): "
if not defined FOLLOWLINKS set "FOLLOWLINKS=N"
if /i not "%FOLLOWLINKS%"=="Y" if /i not "%FOLLOWLINKS%"=="N" set "FOLLOWLINKS=N"

echo.
echo Skip rules (comma-separated, Enter = skip nothing)
echo.
echo   Manual rules:
echo     by name  : fonts              skip any dir/file named "fonts"
echo     rel path : a\b\c              path relative to scan root (exact match, dirs only)
echo     abs path : D:\proj\build      only this exact path (dirs only)
echo     glob     : *.cache, node_*    wildcard, applies to BOTH dirs and files
echo.
echo   IMPORTANT: If you want to enter multiple rules,
echo              they MUST be separated by COMMAS (,), not spaces.
echo              Example: KoeiTecmo,Rockstar Games,*.log
echo.
echo   Presets:
echo     @disk  for disk scan   : system junk only
echo     @dev   for code project: node_modules, .git, dist, ...
echo.
set "SKIP="
set /p "SKIP=Enter: "
if not defined SKIP set "SKIP=__NONE__"

if /i "%SKIP%"=="@disk" set "SKIP=$Recycle.Bin,System Volume Information,$WinREAgent,Config.Msi,MSOCache,Windows.old,PerfLogs"
if /i "%SKIP%"=="@dev"  set "SKIP=node_modules,.git,dist,build,.next,target,vendor,__pycache__,venv,.venv,.idea"

rem ============================================
rem  [5] Derive output path
rem ============================================
set "RP=%ROOT%"
if "%RP:~-1%"=="\" set "RP=%RP:~0,-1%"
set "SAFE=%RP:\=_%"
set "SAFE=%SAFE::=_%"
set "OUT=%DESKTOP%\%SAFE%_tree.txt"

echo.
echo ------------------------------------------
echo  Desktop      : %DESKTOP%
echo  Scan path    : %ROOT%
echo  Max depth    : %MAXDEPTH%
echo  Max files    : %MAXFILES%  (0 = unlimited)
echo  Follow links : %FOLLOWLINKS%
echo  Skip rules   : %SKIP%
echo  Output       : %OUT%
echo ------------------------------------------
echo.
echo Calling PowerShell...
echo.

rem ============================================
rem  [6] Run scan
rem ============================================
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tree.ps1" -Root "%ROOT%" -MaxDepth %MAXDEPTH% -MaxFiles %MAXFILES% -Out "%OUT%" -SkipRaw "%SKIP%" -FollowLinks "%FOLLOWLINKS%"
set "RC=%ERRORLEVEL%"

echo.
echo ==========================================
echo  PowerShell exit code: %RC%
if exist "%OUT%" goto HAS_OUTPUT
echo  [WARN] output file not created
goto AFTER_OUTPUT

:HAS_OUTPUT
for %%A in ("%OUT%") do echo  Output size       : %%~zA bytes

:AFTER_OUTPUT
echo ==========================================

rem ============================================
rem  [7] Post-run cleanup: check if PS1 removed
rem ============================================
set "STILL_THERE=0"
for %%F in ("%TEMP%\_gentree_*.ps1") do if exist "%%F" set "STILL_THERE=1"
if "%STILL_THERE%"=="0" goto SKIP_CLEANUP

echo.
echo  [INFO] A temp script was left behind:
for %%F in ("%TEMP%\_gentree_*.ps1") do (
    if exist "%%F" echo         %%~fF
)
echo.
echo         Cleaning it up now...
for %%F in ("%TEMP%\_gentree_*.ps1") do (
    if exist "%%F" del "%%F" >nul 2>&1
)
echo  [OK]   Done.

:SKIP_CLEANUP

echo.
echo Press any key to close...
pause >nul

endlocal & exit /b %RC%

:NO_PS1
echo.
echo [ERROR] tree.ps1 not found
echo         Place run.bat and tree.ps1 in the same folder
echo.
pause
exit /b 1