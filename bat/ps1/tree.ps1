param(
    [string]$Root        = "",
    [int]$MaxDepth       = 999999,
    [int]$MaxFiles       = 0,
    [string]$Out         = "tree.txt",
    [string]$SkipRaw     = "__NONE__",
    [string]$FollowLinks = "N"
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch {}

function Log  ($msg) { Write-Host $msg -ForegroundColor Cyan }
function Ok   ($msg) { Write-Host $msg -ForegroundColor Green }
function Warn ($msg) { Write-Host $msg -ForegroundColor Yellow }
function Err  ($msg) { Write-Host $msg -ForegroundColor Red }

function FormatError {
    param($Exception)
    if ($Exception -is [System.IO.PathTooLongException])      { return "PATH TOO LONG" }
    if ($Exception -is [System.UnauthorizedAccessException])  { return "ACCESS DENIED" }
    if ($Exception -is [System.IO.DirectoryNotFoundException]){ return "DIR NOT FOUND" }
    if ($Exception -is [System.IO.FileNotFoundException])     { return "FILE NOT FOUND" }
    if ($Exception -is [System.IO.IOException])               { return "IO ERROR" }
    if ($Exception -is [System.Security.SecurityException])   { return "SECURITY" }
    return ($Exception.GetType().Name + ": " + $Exception.Message)
}

$writer = $null
# List to collect captured errors for summary at the end
$capturedErrors = [System.Collections.Generic.List[string]]::new()

try {
    # ---------- 0. params ----------
    $followLinksBool = ($FollowLinks -ieq 'Y')

    # ---------- 1. resolve path ----------
    Log "[1/6] Resolving root path..."
    if (-not $Root) { throw "Root path is empty" }
    if (-not (Test-Path -LiteralPath $Root)) { throw "Root path does not exist: $Root" }
    $rootFull = (Resolve-Path -LiteralPath $Root).Path
    if ($rootFull.Length -gt 3 -and $rootFull.EndsWith('\')) {
        $rootFull = $rootFull.TrimEnd('\')
    }
    Ok  "      Root = $rootFull"
    Ok  "      MaxDepth = $MaxDepth   MaxFiles = $MaxFiles   FollowLinks = $followLinksBool"

    # ---------- 2. parse skip rules ----------
    Log "[2/6] Parsing skip rules..."
    $skipNames = @{}
    $skipPaths = New-Object System.Collections.Generic.List[string]
    $skipGlobs = New-Object System.Collections.Generic.List[string]
    if ($SkipRaw -and $SkipRaw -ne '__NONE__') {
        foreach ($s in $SkipRaw.Split(',')) {
            $t = $s.Trim()
            if (-not $t) { continue }
            $t = $t.Replace('/', '\')
            if ($t.Length -gt 3) { $t = $t.TrimEnd('\') }
            if ($t.Contains('*') -or $t.Contains('?')) {
                $skipGlobs.Add($t) | Out-Null
                Write-Host "        -> Glob Rule: $t" -ForegroundColor DarkGray
            } elseif ($t.Contains('\')) {
                $skipPaths.Add($t) | Out-Null
                Write-Host "        -> Path Rule: $t" -ForegroundColor DarkGray
            } else {
                $skipNames[$t] = $true
                Write-Host "        -> Name Rule: $t" -ForegroundColor DarkGray
            }
        }
    }
    Ok "      name-rules=$($skipNames.Count)  path-rules=$($skipPaths.Count)  glob-rules=$($skipGlobs.Count)"

    # ---------- 3. .gitignore (simplified support) ----------
    Log "[3/6] Reading .gitignore (if present, simplified support only)..."
    $giNames = @{}
    $giGlobs = New-Object System.Collections.Generic.List[string]
    $gitFile = Join-Path $rootFull '.gitignore'
    $giError = ""
    if (Test-Path -LiteralPath $gitFile) {
        try {
            $giLines = Get-Content -LiteralPath $gitFile -ErrorAction Stop
            foreach ($line in $giLines) {
                $line = $line.Trim()
                if (-not $line -or $line.StartsWith('#')) { continue }
                if ($line.StartsWith('!')) { continue }  # negation not supported
                $line = $line.TrimStart('/')
                $line = $line.TrimEnd('/')
                $line = $line.Replace('/', '\')
                if (-not $line) { continue }
                if ($line.Contains('\')) { continue }  # nested-path patterns not supported
                if ($line.Contains('*') -or $line.Contains('?')) {
                    $giGlobs.Add($line) | Out-Null
                } else {
                    $giNames[$line] = $true
                }
            }
            Ok "      From .gitignore: name=$($giNames.Count)  glob=$($giGlobs.Count)"
        } catch {
            $giError = "[!GITIGNORE READ ERROR: " + (FormatError $_.Exception) + "!] " + $gitFile
            Warn "      $giError"
            $capturedErrors.Add("GITIGNORE READ ERROR: $gitFile (" + $_.Exception.Message + ")")
        }
    } else {
        Ok "      No .gitignore, skipped"
    }

    # ---------- 4. prepare output writer ----------
    Log "[4/6] Preparing output writer..."
    $utf8 = New-Object System.Text.UTF8Encoding $false
    $writer = New-Object System.IO.StreamWriter($Out, $false, $utf8)

    $writer.WriteLine('ROOT: ' + $rootFull)
    $writer.WriteLine('MAX-DEPTH: ' + $MaxDepth + '   MAX-FILES-PER-DIR: ' + $MaxFiles + '   FOLLOW-LINKS: ' + $followLinksBool)
    $allSkips = @()
    if ($skipNames.Count -gt 0) { $allSkips += ($skipNames.Keys  | Sort-Object) }
    if ($skipPaths.Count -gt 0) { $allSkips += ($skipPaths       | Sort-Object) }
    if ($skipGlobs.Count -gt 0) { $allSkips += ($skipGlobs       | Sort-Object) }
    if ($allSkips.Count -gt 0) {
        $writer.WriteLine('SKIP-RULES: ' + ($allSkips -join ', '))
    } else {
        $writer.WriteLine('SKIP-RULES: (none)')
    }
    if ($giNames.Count -gt 0 -or $giGlobs.Count -gt 0) {
        $gi = @()
        if ($giNames.Count -gt 0) { $gi += ($giNames.Keys | Sort-Object) }
        if ($giGlobs.Count -gt 0) { $gi += ($giGlobs      | Sort-Object) }
        $writer.WriteLine('GITIGNORE-RULES (simplified, name/glob only): ' + ($gi -join ', '))
    }
    if ($giError) { $writer.WriteLine($giError) }
    $writer.WriteLine('')
    Ok "      header written"

    # ---------- counters & progress ----------
    $script:dirCount  = 0
    $script:fileCount = 0
    $script:errCount  = 0
    $script:startTime = Get-Date
    $script:lastTick  = Get-Date

    function Tick {
        $now = Get-Date
        if ($script:dirCount % 50 -eq 0 -or ($now - $script:lastTick).TotalSeconds -ge 2) {
            $elapsed = [int]($now - $script:startTime).TotalSeconds
            $errs = if ($script:errCount -gt 0) { "  errors=$($script:errCount)" } else { "" }
            Write-Host ("      [progress] dirs=$($script:dirCount)  files=$($script:fileCount)$errs  elapsed=${elapsed}s") -ForegroundColor DarkGray
            $script:lastTick = $now
        }
    }

    function MatchesGlob([string]$name, [string]$pattern) {
        return $name -like $pattern
    }

    function MatchesNameOrGlob([string]$name) {
        if ($skipNames.ContainsKey($name)) { return $true }
        if ($giNames.ContainsKey($name))   { return $true }
        foreach ($g in $skipGlobs) { if (MatchesGlob $name $g) { return $true } }
        foreach ($g in $giGlobs)   { if (MatchesGlob $name $g) { return $true } }
        return $false
    }

    function MatchesPathRule([string]$fullPath, [string]$relPath) {
        if ($skipPaths.Count -eq 0) { return $false }
        $full = $fullPath.Replace('/', '\')
        if ($full.Length -gt 3) { $full = $full.TrimEnd('\') }
        $rp = $relPath.Replace('/', '\')
        foreach ($sp in $skipPaths) {
            $isAbs = ($sp.Length -ge 2 -and $sp[1] -eq ':') -or $sp.StartsWith('\\')
            if ($isAbs) {
                if ($full -ieq $sp) { return $true }
            } else {
                if ($rp -ieq $sp) { return $true }
            }
        }
        return $false
    }

    function ShouldSkipDir {
        param([System.IO.DirectoryInfo]$dir, [string]$relPath)
        if (MatchesNameOrGlob $dir.Name) { return $true }
        if (MatchesPathRule $dir.FullName $relPath) { return $true }
        return $false
    }

    function ShouldSkipFile {
        param([System.IO.FileInfo]$file)
        return (MatchesNameOrGlob $file.Name)
    }

    function IsReparse([System.IO.FileSystemInfo]$item) {
        try {
            return [bool]($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
        } catch {
            return $false
        }
    }

    function GetRealPath([string]$p) {
        try {
            $item = Get-Item -LiteralPath $p -Force -ErrorAction Stop
            if ($item.Target) {
                $t = $item.Target
                if ($t -is [array]) { $t = $t[0] }
                return [string]$t
            }
            return $item.FullName
        } catch {
            $script:errCount++
            $msg = FormatError $_.Exception
            $writer.WriteLine('      [! REALPATH ' + $msg + ' !] ' + $p)
            # FIXED: Wrapped $msg in {} to prevent PowerShell parsing ": " as a drive-qualified variable
            $capturedErrors.Add("REALPATH ${msg}: $p")
            return $null
        }
    }

    $visitedDirs = @{}

    function Walk {
        param([string]$p, [int]$depth, [string]$indent, [string]$rel)

        if ($depth -gt $MaxDepth) {
            $writer.WriteLine($indent + '<max depth reached, contents omitted>')
            return
        }

        $script:dirCount++
        if ($script:dirCount % 20 -eq 0) {
            Write-Host ("      [dir $($script:dirCount)] " + $p) -ForegroundColor DarkGray
        }
        Tick

        $realPath = GetRealPath $p
        if ($realPath) {
            if ($visitedDirs.ContainsKey($realPath)) {
                $writer.WriteLine($indent + '[CYCLE: already visited ' + $realPath + ']')
                return
            }
            $visitedDirs[$realPath] = $true
        }

        $childErrs = $null
        $items = @(Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue -ErrorVariable childErrs)

        $dirs  = [System.Collections.Generic.List[System.IO.DirectoryInfo]]::new()
        $files = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
        foreach ($it in $items) {
            if ($it.PSIsContainer) { $dirs.Add($it) } else { $files.Add($it) }
        }

        if ($childErrs -and $childErrs.Count -gt 0) {
            foreach ($e in $childErrs) {
                $script:errCount++
                $target = $e.TargetObject
                if (-not $target) { $target = $p }
                $msg = FormatError $e.Exception
                $writer.WriteLine($indent + '|-- [! ' + $msg + ' !] ' + $target)
                # FIXED: Wrapped $msg in {} to prevent PowerShell parsing ": " as a drive-qualified variable
                $capturedErrors.Add("${msg}: $target")
            }
        }

        $sortedFiles = @($files | Sort-Object Name)
        $sortedDirs  = @($dirs  | Sort-Object Name)

        $script:fileCount += $sortedFiles.Count

        $visibleFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]
        $skippedFileCount = 0
        foreach ($f in $sortedFiles) {
            if (ShouldSkipFile $f) { $skippedFileCount++; continue }
            $visibleFiles.Add($f) | Out-Null
        }

        if ($MaxFiles -gt 0 -and $visibleFiles.Count -gt $MaxFiles) {
            $writer.WriteLine($indent + '|-- [SKIPPED: ' + $visibleFiles.Count + ' files > limit ' + $MaxFiles + ']')
        } else {
            foreach ($f in $visibleFiles) {
                $tag = ''
                if (IsReparse $f) { $tag = '  <link>' }
                $writer.WriteLine($indent + '|-- ' + $f.Name + $tag)
            }
        }
        if ($skippedFileCount -gt 0) {
            $writer.WriteLine($indent + '|-- [' + $skippedFileCount + ' file(s) hidden by skip rules]')
        }

        foreach ($d in $sortedDirs) {
            $newRel = if ($rel) { $rel + '\' + $d.Name } else { $d.Name }
            if (ShouldSkipDir $d $newRel) {
                $writer.WriteLine($indent + '+-- [' + $d.Name + ']/  <skipped>')
                continue
            }
            $isLink = IsReparse $d
            if ($isLink) {
                $target = $null
                try {
                    $target = (Get-Item -LiteralPath $d.FullName -Force -ErrorAction Stop).Target
                } catch {
                    $script:errCount++
                    $msg = FormatError $_.Exception
                    $writer.WriteLine($indent + '    [! TARGET READ ' + $msg + ' !] ' + $d.FullName)
                    # FIXED: Wrapped $msg in {} to prevent PowerShell parsing ": " as a drive-qualified variable
                    $capturedErrors.Add("TARGET READ ${msg}: $($d.FullName)")
                    $target = $null
                }
                if ($target -is [array]) { $target = $target[0] }

                if (-not $followLinksBool) {
                    if ($target) {
                        $writer.WriteLine($indent + '+-- [' + $d.Name + ']/  -> ' + $target + '  <not entered>')
                    } else {
                        $writer.WriteLine($indent + '+-- [' + $d.Name + ']/  <reparse point, not entered>')
                    }
                    continue
                } else {
                    if ($target) {
                        $writer.WriteLine($indent + '+-- [' + $d.Name + ']/  -> ' + $target + '  <entered>')
                    } else {
                        $writer.WriteLine($indent + '+-- [' + $d.Name + ']/  <reparse, entered>')
                    }
                }
            } else {
                $writer.WriteLine($indent + '+-- [' + $d.Name + ']/')
            }
            Walk $d.FullName ($depth + 1) ($indent + '    ') $newRel
        }
    }

    # ---------- 5. scan ----------
    Log "[5/6] Scanning..."
    $rootName = Split-Path $rootFull -Leaf
    if (-not $rootName) { $rootName = $rootFull }
    $writer.WriteLine('[' + $rootName + ']/')
    Walk $rootFull 1 '' ''
    $elapsed = [int]((Get-Date) - $script:startTime).TotalSeconds
    if ($script:errCount -gt 0) {
        Warn "      done: dirs=$($script:dirCount)  files=$($script:fileCount)  errors=$($script:errCount)  elapsed=${elapsed}s"
    } else {
        Ok   "      done: dirs=$($script:dirCount)  files=$($script:fileCount)  elapsed=${elapsed}s"
    }

    # ---------- 6. footer & finalize ----------
    Log "[6/6] Finalizing output..."
    $writer.WriteLine('')
    $writer.WriteLine('---- SUMMARY ----')
    $writer.WriteLine('dirs scanned : ' + $script:dirCount)
    $writer.WriteLine('files listed : ' + $script:fileCount)
    $writer.WriteLine('errors       : ' + $script:errCount)
    $writer.WriteLine('elapsed sec  : ' + $elapsed)
    
    # Write aggregated error list if there were any errors
    if ($capturedErrors.Count -gt 0) {
        $writer.WriteLine('')
        $writer.WriteLine('---- CAPTURED ERRORS ----')
        for ($i = 0; $i -lt $capturedErrors.Count; $i++) {
            $writer.WriteLine("[$($i + 1)] $($capturedErrors[$i])")
        }
    }
    
    $writer.Flush()
    $writer.Dispose()
    $writer = $null

    Ok "      written: $Out"
    if ($script:errCount -gt 0) {
        Warn "      NOTE: $($script:errCount) error(s) were captured."
        Warn "            Check the bottom of the output file for the CAPTURED ERRORS list."
    }

    Write-Host ""
    Write-Host "===== DONE =====" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host ""
    Err "===== FAILED ====="
    Err $_.Exception.Message
    Err "at: $($_.InvocationInfo.PositionMessage)"
    if ($writer) {
        try { 
            $writer.WriteLine('[! FATAL ERROR: ' + $_.Exception.Message + ' !]')
            $writer.Flush()
            $writer.Dispose() 
        } catch {}
    }
    exit 1
}