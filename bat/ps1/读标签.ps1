$ErrorActionPreference = "Continue"

$out = Join-Path ([Environment]::GetFolderPath("Desktop")) "tags.csv"
Write-Host "Desktop: $([Environment]::GetFolderPath('Desktop'))" -ForegroundColor Cyan
Write-Host "Output : $out" -ForegroundColor Cyan

# ---- 音频扩展名白名单 ----
$audioExts = @(
    ".mp3", ".flac", ".m4a", ".mp4", ".aac", ".alac",
    ".ogg", ".oga", ".opus",
    ".wma", ".wav", ".aiff", ".aif",
    ".ape", ".wv", ".tak", ".tta", ".shn", ".mpc",
    ".dsf", ".dff"
)

# ---- 黑名单 ----
$skipExts = @(
    ".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tif", ".tiff",
    ".log", ".cue", ".txt", ".nfo", ".m3u", ".m3u8", ".sfv", ".md5", ".ffp",
    ".accurip", ".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx",
    ".zip", ".rar", ".7z", ".iso", ".exe", ".dll", ".ini", ".cfg",
    ".json", ".xml", ".html", ".htm", ".url", ".lnk", ".bat", ".cmd", ".ps1"
)

# ---- 加载 TagLib# ----
$dll = Join-Path $PSScriptRoot '..\..\ffmpeg-gs\TagLibSharp.dll'
if (-not (Test-Path -LiteralPath $dll)) { $dll = 'E:\ffmpeg-gs\TagLibSharp.dll' }
if (-not (Test-Path -LiteralPath $dll)) {
    Write-Host "[ERROR] TagLibSharp.dll not found: $dll" -ForegroundColor Red
    Read-Host "Press Enter"; exit 1
}
try {
    Add-Type -Path $dll -ErrorAction Stop
    Write-Host "TagLib# loaded OK" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to load TagLib#: $_" -ForegroundColor Red
    Read-Host "Press Enter"; exit 1
}

# ---- 必须拖入路径 ----
$paths = @($args)
if ($paths.Count -eq 0) {
    Write-Host "[ERROR] No input paths." -ForegroundColor Red
    Write-Host "        Please DRAG files or folders onto the bat file." -ForegroundColor Yellow
    Read-Host "Press Enter"
    exit 1
}

# ---- 遍历，按扩展名过滤 ----
$fileList = New-Object System.Collections.Generic.List[string]
foreach ($p in $paths) {
    $p = $p.Trim().Trim('"')
    if (-not $p) { continue }
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Host "[SKIP] Not found: $p" -ForegroundColor Yellow
        continue
    }
    $item = Get-Item -LiteralPath $p -Force
    if ($item.PSIsContainer) {
        Write-Host "Scanning folder: $($item.FullName)" -ForegroundColor Green
        Get-ChildItem -LiteralPath $item.FullName -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $ext = $_.Extension.ToLower()
            if ($skipExts -contains $ext) { return }
            if ($audioExts -contains $ext) {
                $fileList.Add($_.FullName)
            }
        }
    } else {
        $ext = $item.Extension.ToLower()
        if ($audioExts -contains $ext) {
            Write-Host "Added file: $($item.FullName)" -ForegroundColor Green
            $fileList.Add($item.FullName)
        } else {
            Write-Host "[SKIP non-audio] $($item.Name)" -ForegroundColor Yellow
        }
    }
}

$uniqueFiles = @($fileList | Select-Object -Unique)
$totalFiles = $uniqueFiles.Count
Write-Host ""
Write-Host "Total audio files: $totalFiles" -ForegroundColor Cyan
Write-Host ""

function Get-PropFromFile($filePath, $key) {
    try {
        $dir  = Split-Path -Parent $filePath
        $name = Split-Path -Leaf   $filePath
        $shell = New-Object -ComObject Shell.Application
        $folder = $shell.Namespace($dir)
        if (-not $folder) { return "" }
        $f = $folder.ParseName($name)
        if (-not $f) { return "" }
        $v = $f.ExtendedProperty($key)
        if ($null -eq $v) { return "" }
        if ($v -is [array]) { return ($v -join "; ") }
        return [string]$v
    } catch { return "" }
}

function Format-Duration($raw) {
    if (-not $raw) { return "" }
    try {
        $ticks = [double]$raw
        $sec = [math]::Floor($ticks / 10000000)
        $m = [math]::Floor($sec / 60)
        $s = [int]($sec % 60)
        return ("{0}:{1:D2}" -f $m, $s)
    } catch { return "" }
}
function Format-Bitrate($raw) {
    if (-not $raw) { return "" }
    try { return ("{0} kbps" -f [math]::Round([double]$raw / 1000)) } catch { return "" }
}
function Format-SampleRate($raw) {
    if (-not $raw) { return "" }
    try { return ("{0} Hz" -f [int][double]$raw) } catch { return "" }
}
function Format-Size($raw) {
    if (-not $raw) { return "" }
    try {
        $bytes = [double]$raw
        if ($bytes -ge 1MB)     { return ("{0:N2} MB" -f ($bytes / 1MB)) }
        elseif ($bytes -ge 1KB) { return ("{0:N1} KB" -f ($bytes / 1KB)) }
        else                    { return ("{0} B"   -f [int]$bytes) }
    } catch { return "" }
}
function Format-Channels($raw) {
    if (-not $raw) { return "" }
    switch ([string]$raw) {
        "1" { return "1 (Mono)" }
        "2" { return "2 (Stereo)" }
        "6" { return "6 (5.1)" }
        "8" { return "8 (7.1)" }
        default { return $raw }
    }
}

# ============================================
# 歌词判断
#   核心区分：
#     A 类"无歌词声明"：纯音乐 / 请欣赏 / 暂无歌词 / 无歌词 / instrumental / no lyrics
#        → 命中即一票否决（这歌就是没歌词）
#     B 类"版权声明"：未经许可 / 不得翻唱 / 版权所有 / 转载请注明 / all rights reserved
#        → 只从正文剥离，不影响"有没有歌词"的判断
#          （这样"有真歌词 + 版权声明"的文件不会被误杀）
# ============================================
function Get-LyricsInfo($filePath) {
    $hasLyrics = "No"
    $hasChinese = "No"
    try {
        $file = [TagLib.File]::Create($filePath)
        try {
            $lyricsText = ""
            if ($file.Tag.Lyrics -and $file.Tag.Lyrics.Trim().Length -gt 0) {
                $lyricsText = $file.Tag.Lyrics
            }
            if (-not $lyricsText) {
                try {
                    $id3v2 = $file.GetTag([TagLib.TagTypes]::Id3v2)
                    if ($id3v2) {
                        $syltFrames = $id3v2.GetFrames("SYLT")
                        if ($syltFrames -and $syltFrames.Count -gt 0) {
                            $lyricsText = $syltFrames[0].ToString()
                        }
                    }
                } catch {}
            }

            if (-not ($lyricsText -and $lyricsText.Trim().Length -gt 0)) {
                return @{ HasLrc = "No"; HasChinese = "No" }
            }

            $hasLyrics = "Yes"

            # ---- 1) 剥头 / 剥时间戳 / 剥署名行 / 剥版权声明，得到"正文" ----
            $body = $lyricsText
            # LRC 头 [ti:][ar:][al:][by:][offset:] 等
            $body = [regex]::Replace($body, '(?m)^\s*\[(ti|ar|al|by|offset|re|ve|length|au|la|tool)\s*:[^\]]*\]\s*$', '')
            # 所有时间戳（含 -1 / +500 偏移后缀）
            $body = [regex]::Replace($body, '\[\d{1,2}:\d{2}(?:[\.:]\d{1,3})?(?:[+-]\d+)?\]', '')
            # 作词 / 作曲 / 编曲 / 混音 / 录音 / 制作人 署名行
            $body = [regex]::Replace($body, '(?m)^\s*(\u4F5C\u8BCD|\u4F5C\u66F2|\u7F16\u66F2|\u6DF7\u97F3|\u5F55\u97F3|\u5236\u4F5C\u4EBA)\s*[:\uFF1A].*$', '')
            # 版权声明短语：只剥离，不作为"无歌词"依据
            $body = [regex]::Replace($body, '(\u672A\u7ECF\u8BB8\u53EF|\u4E0D\u5F97\u7FFB\u5531|\u7248\u6743\u6240\u6709|\u8F6C\u8F7D\u8BF7\u6CE8\u660E|all\s+rights\s+reserved)', '')
            $body = $body.Trim()

            # ---- 2) 占位词：只查"声明无歌词"的 ----
            $placeholderPatterns = @(
                '\u7EAF\u97F3\u4E50',              # 纯音乐
                '\u8BF7\u6B23\u8D4F',              # 请欣赏
                '\u6682\u65E0\u6B4C\u8BCD',        # 暂无歌词
                '\u6CA1\u6709\u6B4C\u8BCD',        # 没有歌词
                '\u65E0\u6B4C\u8BCD',              # 无歌词
                'instrumental',
                'no\s+lyrics'
            )
            foreach ($pat in $placeholderPatterns) {
                if ($body -match $pat) {
                    return @{ HasLrc = "No"; HasChinese = "No" }
                }
            }

            # ---- 3) 空壳检测：正文太短 → 无歌词 ----
            if ($body.Length -lt 5) {
                return @{ HasLrc = "No"; HasChinese = "No" }
            }

            # ---- 4) 时间戳提取：只统计「时间戳后面还有正文」的行 ----
            $timestamps = New-Object System.Collections.Generic.List[string]
            foreach ($line in ($lyricsText -split "`r?`n")) {
                $lineMatches = [regex]::Matches($line, '\[(\d{1,2}):(\d{2})(?:[\.:](\d{1,3}))?(?:[+-]\d+)?\]')
                if ($lineMatches.Count -eq 0) { continue }

                $lineNoTs = [regex]::Replace($line, '\[(\d{1,2}):(\d{2})(?:[\.:](\d{1,3}))?(?:[+-]\d+)?\]', '').Trim()
                if ($lineNoTs.Length -eq 0) { continue }

                foreach ($m in $lineMatches) {
                    $ms  = $m.Groups[3].Value
                    $ms1 = if ($ms -and $ms.Length -ge 1) { $ms.Substring(0,1) } else { "0" }
                    $timestamps.Add("$($m.Groups[1].Value):$($m.Groups[2].Value).$ms1")
                }
            }

            # 汉字 / 假名探测
            $hanPattern  = '[\u4E00-\u9FFF]'
            $kanaPattern = '[\u3040-\u309F\u30A0-\u30FF\uFF66-\uFF9D]'

            # ---- 5) 判定 HasChinese ----
            if ($timestamps.Count -lt 4) {
                $hasKana = $body -match $kanaPattern
                $hasHan  = $body -match $hanPattern
                if (-not $hasKana -and $hasHan) { $hasChinese = "Yes" }
            } else {
                $tsCounter = @{}
                foreach ($ts in $timestamps) {
                    if ($tsCounter.ContainsKey($ts)) { $tsCounter[$ts]++ } else { $tsCounter[$ts] = 1 }
                }
                $totalTs = $tsCounter.Count
                $dupTs   = @($tsCounter.Values | Where-Object { $_ -ge 2 }).Count
                $dupRate = $dupTs / $totalTs

                if ($dupRate -ge 0.5) {
                    $hasChinese = "Yes"
                } else {
                    $hasKana = $body -match $kanaPattern
                    $hasHan  = $body -match $hanPattern
                    if (-not $hasKana -and $hasHan) {
                        $hasChinese = "Yes"
                    }
                }
            }
        } finally { $file.Dispose() }
    } catch {}
    return @{ HasLrc = $hasLyrics; HasChinese = $hasChinese }
}

$results = @()
$counter = 0

foreach ($fp in $uniqueFiles) {
    $counter++
    $fname = Split-Path -Leaf $fp

    Write-Progress -Activity "Reading tags" -Status "$counter / $totalFiles  $fname" `
                   -PercentComplete (($counter / $totalFiles) * 100)

    $relDir = Split-Path -Parent $fp

    $row = [ordered]@{ Dir = $relDir }
    $row["Title"]        = Get-PropFromFile $fp "System.Title"
    $row["Artist"]       = Get-PropFromFile $fp "System.Music.Artist"
    $row["AlbumArtist"]  = Get-PropFromFile $fp "System.Music.AlbumArtist"
    $row["Album"]        = Get-PropFromFile $fp "System.Music.AlbumTitle"
    $row["Genre"]        = Get-PropFromFile $fp "System.Music.Genre"
    $row["Track"]        = Get-PropFromFile $fp "System.Music.TrackNumber"
    $row["Year"]         = Get-PropFromFile $fp "System.Media.Year"
    $row["Duration"]     = Format-Duration   (Get-PropFromFile $fp "System.Media.Duration")
    $row["Bitrate"]      = Format-Bitrate    (Get-PropFromFile $fp "System.Audio.EncodingBitrate")
    $row["SampleRate"]   = Format-SampleRate (Get-PropFromFile $fp "System.Audio.SampleRate")
    $row["Channels"]     = Format-Channels   (Get-PropFromFile $fp "System.Audio.ChannelCount")
    $row["Composer"]     = Get-PropFromFile $fp "System.Music.Composer"
    $row["BPM"]          = Get-PropFromFile $fp "System.Music.BeatsPerMinute"
    $row["Comment"]      = Get-PropFromFile $fp "System.Comment"
    $row["DateModified"] = Get-PropFromFile $fp "System.DateModified"
    $row["Size"]         = Format-Size (Get-PropFromFile $fp "System.Size")

    $ly = Get-LyricsInfo $fp
    $row["HasLyrics"]    = $ly.HasLrc
    $row["HasChinese"]   = $ly.HasChinese
    $row["Filename"]     = $fname

    $results += [PSCustomObject]$row
}

Write-Progress -Activity "Reading tags" -Completed

$results | Export-Csv -Path $out -Encoding UTF8 -NoTypeInformation

Write-Host "Done!" -ForegroundColor Green
Write-Host "Total: $($results.Count)"
Write-Host "Result: $out" -ForegroundColor Yellow
Read-Host "Press Enter to exit"