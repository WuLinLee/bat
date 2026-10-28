param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Paths
)

$ErrorActionPreference = "Continue"

# ============================================
# 把本次所有输出（Write-Host 的内容）录制到桌面的 txt
# ============================================
$logDir  = [Environment]::GetFolderPath("Desktop")
$logName = "DiagnoseResult_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".txt"
$logFile = Join-Path $logDir $logName
try {
    # -Encoding 参数只在 PowerShell 7+ 有效；5.1 走默认编码
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Start-Transcript -Path $logFile -Encoding UTF8 -Force | Out-Null
    } else {
        Start-Transcript -Path $logFile -Force | Out-Null
    }
    Write-Host "Transcript: $logFile" -ForegroundColor Cyan
} catch {
    Write-Host "[WARN] Failed to start transcript: $_" -ForegroundColor Yellow
    $logFile = ""
}

$dll = Join-Path $PSScriptRoot '..\..\ffmpeg-gs\TagLibSharp.dll'
if (-not (Test-Path -LiteralPath $dll)) { $dll = 'E:\ffmpeg-gs\TagLibSharp.dll' }
Add-Type -Path $dll -ErrorAction Stop

if (-not $Paths -or $Paths.Count -eq 0) {
    Write-Host "[ERROR] No file path received." -ForegroundColor Red
    if ($logFile) { try { Stop-Transcript | Out-Null } catch {} }
    Read-Host "Press Enter"; exit 1
}

# ---- 展开成文件列表（支持文件夹递归） ----
$audioExts = @(
    ".mp3",".flac",".m4a",".mp4",".aac",".alac",
    ".ogg",".oga",".opus",".wma",".wav",
    ".aiff",".aif",".ape",".wv",".tak",".tta",
    ".shn",".mpc",".dsf",".dff",
    ".mid",".midi",".mod",".xm",".s3m",".it"
)

$fileList = New-Object System.Collections.Generic.List[string]
foreach ($p in $Paths) {
    if (-not $p) { continue }
    $p = $p.Trim().Trim('"')
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Host "[SKIP] Not found: $p" -ForegroundColor Yellow
        continue
    }
    $item = Get-Item -LiteralPath $p -Force
    if ($item.PSIsContainer) {
        Write-Host "Scanning folder: $($item.FullName)" -ForegroundColor Green
        Get-ChildItem -LiteralPath $item.FullName -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $audioExts -contains $_.Extension.ToLower() } |
            ForEach-Object { $fileList.Add($_.FullName) }
    } else {
        $fileList.Add($item.FullName)
    }
}

$uniqueFiles = @($fileList | Select-Object -Unique)
$total = $uniqueFiles.Count

if ($total -eq 0) {
    Write-Host "[ERROR] No valid audio files found." -ForegroundColor Red
    if ($logFile) { try { Stop-Transcript | Out-Null } catch {} }
    Read-Host "Press Enter"; exit 1
}

Write-Host "Files to check: $total" -ForegroundColor Cyan
Write-Host ""

# ---- 每个文件依次诊断 ----
$idx = 0
$summary = New-Object System.Collections.Generic.List[object]

foreach ($filePath in $uniqueFiles) {
    $idx++

    Write-Host ""
    Write-Host ("=" * 78) -ForegroundColor DarkCyan
    Write-Host "[$idx / $total] $filePath" -ForegroundColor Yellow
    Write-Host ("=" * 78) -ForegroundColor DarkCyan

    $entry = [ordered]@{
        File       = $filePath
        HasLrc     = "?"
        Length     = 0
        TsTotal    = 0
        TsUnique   = 0
        DupRate    = 0
        SyltCount  = 0
    }

    try {
        $file = [TagLib.File]::Create($filePath)
        try {
            # ---- Basic tags ----
            Write-Host ""
            Write-Host "=== Basic Tags ===" -ForegroundColor Cyan
            Write-Host ("  Title    : " + $file.Tag.Title)
            Write-Host ("  Artist   : " + ($file.Tag.Performers -join "; "))
            Write-Host ("  Album    : " + $file.Tag.Album)
            Write-Host ("  Composer : " + ($file.Tag.Composers -join "; "))

            # ---- Tag.Lyrics ----
            Write-Host ""
            Write-Host "=== Tag.Lyrics ===" -ForegroundColor Cyan
            $lyr = $file.Tag.Lyrics
            $hasLyr = $lyr -and $lyr.Trim().Length -gt 0
            if ($hasLyr) {
                Write-Host "  Length: $($lyr.Length)" -ForegroundColor Green
                $entry.Length = $lyr.Length
                $entry.HasLrc = "Yes"

                $tsMatches = [regex]::Matches($lyr, '\[(\d{1,2}):(\d{2})(?:[\.:](\d{1,3}))?(?:[+-]\d+)?\]')
                $tsList = @()
                foreach ($m in $tsMatches) {
                    $ms = $m.Groups[3].Value
                    if ($ms -and $ms.Length -ge 1) { $ms1 = $ms.Substring(0,1) } else { $ms1 = "0" }
                    $tsList += "$($m.Groups[1].Value):$($m.Groups[2].Value).$ms1"
                }
                $tsCounter = @{}
                foreach ($t in $tsList) {
                    if ($tsCounter.ContainsKey($t)) { $tsCounter[$t]++ } else { $tsCounter[$t] = 1 }
                }
                $uniq = $tsCounter.Count
                $dup  = @($tsCounter.Values | Where-Object { $_ -ge 2 }).Count
                if ($uniq -gt 0) { $dupRate = [math]::Round($dup / $uniq, 3) } else { $dupRate = 0 }

                $entry.TsTotal  = $tsList.Count
                $entry.TsUnique = $uniq
                $entry.DupRate  = $dupRate

                Write-Host ("  Timestamps: total=$($tsList.Count)  unique=$uniq  dupRate=$dupRate") -ForegroundColor Green

                Write-Host ""
                Write-Host "--- Lyrics content ---" -ForegroundColor DarkGray
                Write-Host $lyr
            } else {
                Write-Host "  (empty)" -ForegroundColor DarkYellow
                $entry.HasLrc = "No"
            }

            # ---- ID3v2 SYLT ----
            Write-Host ""
            Write-Host "=== ID3v2 SYLT Frame ===" -ForegroundColor Cyan
            $id3v2 = $null
            try { $id3v2 = $file.GetTag([TagLib.TagTypes]::Id3v2) } catch {}
            if ($id3v2) {
                $syltFrames = $null
                try { $syltFrames = $id3v2.GetFrames("SYLT") } catch {}
                $syltCount = @($syltFrames).Count
                $entry.SyltCount = $syltCount
                Write-Host "  SYLT frame count: $syltCount"
                if ($syltFrames -and $syltCount -gt 0) {
                    Write-Host $syltFrames[0].ToString()
                }
            } else {
                Write-Host "  No ID3v2 tag" -ForegroundColor DarkYellow
            }

            # ---- All frames ----
            Write-Host ""
            Write-Host "=== All ID3v2 Frames ===" -ForegroundColor Cyan
            if ($id3v2) {
                foreach ($frame in $id3v2) {
                    Write-Host "  $($frame.FrameId)  (len=$($frame.Size))"
                }
            }
        } finally {
            if ($file) { $file.Dispose() }
        }
    } catch {
        Write-Host "  [ERROR] $_" -ForegroundColor Red
    }

    $summary.Add([PSCustomObject]$entry)
}

# ---- 汇总表 ----
Write-Host ""
Write-Host ("=" * 78) -ForegroundColor DarkCyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 78) -ForegroundColor DarkCyan

$summary |
    Select-Object `
        @{N='File'; E={ Split-Path -Leaf $_.File }},
        HasLrc, Length, TsTotal, TsUnique, DupRate, SyltCount |
    Format-Table -AutoSize

Write-Host ""
Write-Host "Done. Total: $total" -ForegroundColor Green
if ($logFile) {
    Write-Host "Result saved to: $logFile" -ForegroundColor Yellow
}

# ---- 结束录制（放在 Read-Host 之前，避免把 "Press Enter" 也记进去） ----
if ($logFile) {
    try { Stop-Transcript | Out-Null } catch {}
}

Read-Host "Press Enter to exit"