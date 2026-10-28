# Check that all required dependency files are present and non-empty.
# This script does not execute any EXE or load any DLL.

$ErrorActionPreference = 'Stop'

$requiredFiles = @(
    'ffmpeg.exe',
    'fpcalc.exe',
    'gsdll64.dll',
    'gswin64c.exe',
    'img2pdf.exe',
    'img2pdf-gui.exe',
    'TagLibSharp.dll'
)

$problems = @()

Write-Host "Checking dependency folder: $PSScriptRoot" -ForegroundColor Cyan
Write-Host ''

foreach ($name in $requiredFiles) {
    $path = Join-Path -Path $PSScriptRoot -ChildPath $name

    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Write-Host "[MISSING] $name" -ForegroundColor Red
        $problems += $name
        continue
    }

    $file = Get-Item -LiteralPath $path
    if ($file.Length -le 0) {
        Write-Host "[EMPTY]   $name" -ForegroundColor Yellow
        $problems += $name
        continue
    }

    Write-Host ("[OK]      {0} ({1:N0} bytes)" -f $name, $file.Length) -ForegroundColor Green
}

Write-Host ''
if ($problems.Count -gt 0) {
    Write-Host ("Check failed: {0} file(s) are missing or empty." -f $problems.Count) -ForegroundColor Red
    exit 1
}

Write-Host 'All required files are present and non-empty.' -ForegroundColor Green
exit 0
