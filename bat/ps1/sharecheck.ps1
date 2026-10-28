# ============================================================
# 网络共享检查 v7.2
# Windows PowerShell 5.1
# 保存：UTF-8 with BOM
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

function Show-Title([string]$t) {
    Write-Host ''
    Write-Host '========================================' -ForegroundColor DarkCyan
    Write-Host ("             {0}" -f $t) -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor DarkCyan
}
function Show-Section([string]$t) {
    Write-Host ''
    Write-Host ("【{0}】" -f $t) -ForegroundColor Yellow
}
function Show-OK([string]$t) { Write-Host ("[+] {0}" -f $t) -ForegroundColor Green }
function Show-Info([string]$t) { Write-Host ("[i] {0}" -f $t) -ForegroundColor Cyan }
function Show-Warn([string]$t) { Write-Host ("[!] {0}" -f $t) -ForegroundColor Yellow }
function Show-Bad([string]$t) { Write-Host ("[-] {0}" -f $t) -ForegroundColor Red }

function Test-IsLoopback([string]$a) {
    return ($a -eq '127.0.0.1' -or $a -eq '::1')
}
function Test-IsLanAddress([string]$a) {
    return (
        $a -eq '0.0.0.0' -or $a -eq '::' -or
        $a -match '^10\.' -or
        $a -match '^192\.168\.' -or
        $a -match '^172\.(1[6-9]|2[0-9]|3[0-1])\.' -or
        $a -match '^fe80:'
    )
}
function Test-TcpSelfConnection([string]$HostName,[int]$Port,[int]$TimeoutMs=700) {
    $c = New-Object System.Net.Sockets.TcpClient
    try {
        $a = $c.BeginConnect($HostName,$Port,$null,$null)
        if ($a.AsyncWaitHandle.WaitOne($TimeoutMs) -and $c.Connected) { return $true }
        return $false
    } catch { return $false }
    finally { try { $c.Close() } catch {} }
}

# ------------------------------------------------------------
# 全部进程：必须在 aria2/qB 配置解析之前建立
# ------------------------------------------------------------
$allProcesses = @(Get-CimInstance Win32_Process)

# ------------------------------------------------------------
# 程序分类规则
# ------------------------------------------------------------
$rules = @(
    @{C='网络加速';N='小黑盒加速器';P='游戏 / 网络加速';S='高';NR='';PR='heyboxaccelerator|heyboxacc';TR='小黑盒'},
    @{C='网络加速';N='Watt Toolkit / Steam++';P='Steam 工具 / 游戏网络加速';S='高';NR='';PR='steam\+\+|watt.?toolkit';TR='steam\+\+|watt.?toolkit|steamtools'},
    @{C='网络加速';N='UU 加速器';P='游戏网络加速';S='高';NR='';PR='uuaccelerator|uu.?accelerator';TR='uuaccelerator|uu.?accelerator|uu加速|网易uu'},
    @{C='网络加速';N='雷神加速器';P='游戏网络加速';S='高';NR='';PR='leigod';TR='leigod|雷神加速'},
    @{C='网络加速';N='奇游加速器';P='游戏网络加速';S='高';NR='';PR='qiyou';TR='qiyou|奇游'},
    @{C='网络加速';N='迅游加速器';P='游戏网络加速';S='高';NR='';PR='xunyou';TR='xunyou|迅游'},
    @{C='网络加速';N='其他游戏加速器';P='游戏 / 网络加速';S='中';NR='';PR='exitlag|lagofast|gearup|wtfast|noping|mudfish|biubiu|baomiao';TR='exitlag|lagofast|gearup|wtfast|noping|mudfish|biubiu|暴喵|海豚加速|腾讯网游加速器'},
    @{C='网络加速';N='其他网络加速程序';P='可能是游戏 / 网络加速';S='低';NR='';PR='';TR='accelerator|game.?booster|game.?accelerator|network.?booster|加速器'},

    @{C='代理工具';N='NekoBox / NekoRay';P='网络代理';S='高';NR='nekobox';PR='nekobox|nekoray';TR=''},
    @{C='代理工具';N='代理内核 / Clash 系';P='网络代理';S='高';NR='mihomo|clash|sing-box|singbox|xray|v2ray|v2rayn';PR='';TR=''},
    @{C='代理工具';N='Shadowsocks';P='网络代理';S='高';NR='shadowsocks|sslocal|ssserver';PR='shadowsocks';TR=''},
    @{C='代理工具';N='其他代理内核';P='网络代理';S='高';NR='tun2socks|hysteria|naiveproxy|brook|gost|sagernet';PR='';TR=''},

    @{C='VPN / 隧道';N='VPN / 隧道工具';P='虚拟网络 / 隧道';S='高';NR='wireguard|tailscale|zerotier|openvpn|cloudflared';PR='';TR=''},

    @{C='文件同步';N='Syncthing';P='文件夹同步';S='高';NR='^syncthing\.exe$';PR='';TR=''},
    @{C='文件同步';N='Syncthing';P='文件夹同步';S='高';NR='^synctrayzor\.exe$';PR='';TR=''},
    @{C='文件同步';N='其他文件同步';P='文件同步';S='高';NR='resilio|seafile|freefilesync|goodsync';PR='';TR=''},

    @{C='手机互传';N='LocalSend';P='局域网文件传输';S='高';NR='^localsend_app\.exe$';PR='localsend';TR=''},
    @{C='手机互传';N='其他局域网互传';P='局域网文件传输';S='中';NR='pairdrop|snapdrop|landrop|kdeconnect';PR='';TR=''},

    @{C='下载服务';N='aria2';P='下载 / RPC / BT';S='高';NR='^aria2.*\.exe$';PR='';TR=''},
    @{C='下载服务';N='Rayburst';P='下载 / aria2 管理工具';S='高';NR='^rayburst\.exe$';PR='';TR=''},
    @{C='下载服务';N='qBittorrent';P='BT 下载';S='高';NR='^qbittorrent\.exe$';PR='';TR=''},
    @{C='下载服务';N='其他下载程序';P='下载 / BT';S='中';NR='transmission|deluge|motrix|freedownloadmanager|idm';PR='';TR=''},

    @{C='文件服务器';N='第三方文件服务器';P='HTTP / FTP / SFTP / WebDAV';S='高';NR='copyparty|filebrowser|miniserve|sftpgo|hfs|filezilla';PR='';TR=''},
    @{C='文件服务器';N='rclone';P='网络文件服务';S='高';NR='^rclone\.exe$';PR='';TR='serve\s+(http|webdav|ftp|sftp|dlna)'},

    @{C='媒体服务器';N='第三方媒体服务器';P='视频 / 音乐 / DLNA';S='高';NR='jellyfin|emby|plex|navidrome|audiobookshelf|universalmediaserver|serviio|gerbera|minidlna';PR='';TR=''},

    @{C='网页 / API';N='Web / HTTP 服务';P='网页 / API';S='高';NR='^nginx\.exe$|^caddy\.exe$|^httpd\.exe$|^apache\.exe$';PR='';TR=''},
    @{C='网页 / API';N='Python HTTP 服务';P='网页 / 文件 HTTP 服务';S='高';NR='^python\.exe$|^pythonw\.exe$';PR='';TR='http\.server'},
    @{C='网页 / API';N='PHP Web 服务';P='网页 / API';S='高';NR='^php\.exe$|^php-cgi\.exe$';PR='';TR='\s-S\s'},

    @{C='远程控制';N='远程控制软件';P='远程桌面 / 远程控制';S='高';NR='rustdesk|anydesk|teamviewer|todesk|sunlogin|parsec';PR='';TR='向日葵'},

    @{C='云同步';N='OneDrive';P='云端同步';S='高';NR='^onedrive\.exe$|^onedrive\.sync\.service\.exe$|^filesynchelper\.exe$|^filecoauth\.exe$';PR='\\microsoft onedrive\\';TR=''},
    @{C='云同步';N='其他云同步';P='云端同步';S='高';NR='dropbox|nextcloud|googledrive';PR='';TR=''}
)

function Get-AppRule([string]$Name,[string]$Path,[string]$CommandLine) {
    $nl = ([string]$Name).ToLowerInvariant()
    $pl = ([string]$Path).ToLowerInvariant()
    $all = (($Name + ' ' + $Path + ' ' + $CommandLine)).ToLowerInvariant()

    $system = @('system','system.exe','svchost.exe','lsass.exe','services.exe','wininit.exe','winlogon.exe','csrss.exe','smss.exe','spoolsv.exe','dwm.exe','fontdrvhost.exe','conhost.exe','runtimebroker.exe','sihost.exe','searchhost.exe','searchindexer.exe','dllhost.exe','taskhostw.exe','ctfmon.exe')
    if ($system -contains $nl) { return $null }

    foreach ($r in $rules) {
        $nm = $false; $pm = $false; $tm = $false
        if ($r.NR -and $nl -match $r.NR) { $nm = $true }
        if ($r.PR -and $pl -match $r.PR) { $pm = $true }
        if ($r.TR -and $all -match $r.TR) { $tm = $true }

        if ($r.NR -or $r.PR) {
            if (-not ($nm -or $pm)) { continue }
            if ($r.TR -and -not $tm) { continue }
            return [pscustomobject]@{Category=$r.C;Name=$r.N;Purpose=$r.P;Score=$r.S}
        }
        elseif ($r.TR -and $tm) {
            return [pscustomobject]@{Category=$r.C;Name=$r.N;Purpose=$r.P;Score=$r.S}
        }
    }
    return $null
}

# ------------------------------------------------------------
# TCP / UDP
# ------------------------------------------------------------
$tcpListeners = @(Get-NetTCPConnection -State Listen)
$allUdp = @(Get-NetUDPEndpoint)

$tcpByPid = @{}
foreach ($x in $tcpListeners) {
    $p = [int]$x.OwningProcess
    if (-not $tcpByPid.ContainsKey($p)) { $tcpByPid[$p] = New-Object System.Collections.ArrayList }
    [void]$tcpByPid[$p].Add($x)
}
$udpByPid = @{}
foreach ($x in $allUdp) {
    $p = [int]$x.OwningProcess
    if (-not $udpByPid.ContainsKey($p)) { $udpByPid[$p] = New-Object System.Collections.ArrayList }
    [void]$udpByPid[$p].Add($x)
}

# ------------------------------------------------------------
# qBittorrent 配置：同时支持旧/新键名 + 命令行
# ------------------------------------------------------------
function Get-QBitInfo {
    $r = [ordered]@{
        Path = $null
        WebUIPort = $null
        WebUIAddress = $null
        WebUIEnabled = $null
        Https = $null
        TorrentPort = $null
    }

    $paths = @(
        "$env:APPDATA\qBittorrent\qBittorrent.ini",
        "$env:LOCALAPPDATA\qBittorrent\qBittorrent.ini"
    )

    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }

        $r.Path = $path
        $lines = @(Get-Content -LiteralPath $path)

        foreach ($line in $lines) {
            $s = ([string]$line).Trim()
            if (-not $s -or $s.StartsWith(';')) { continue }

            # 新版 qBittorrent / WebUI API 配置键
            if ($s -match '(?i)^web_ui_port\s*=\s*(\d+)\s*$') {
                $r.WebUIPort = [int]$matches[1]
                $r.WebUIEnabled = $true
                continue
            }
            if ($s -match '(?i)^web_ui_address\s*=\s*(.*?)\s*$') {
                $r.WebUIAddress = $matches[1].Trim()
                continue
            }
            if ($s -match '(?i)^use_https\s*=\s*(true|false)\s*$') {
                $r.Https = $matches[1]
                continue
            }

            # 老版 / 部分 Windows 配置格式
            if ($s -match '(?i)^webui[\\/]port\s*=\s*(\d+)\s*$') {
                $r.WebUIPort = [int]$matches[1]
                $r.WebUIEnabled = $true
                continue
            }
            if ($s -match '(?i)^webui[\\/]address\s*=\s*(.*?)\s*$') {
                $r.WebUIAddress = $matches[1].Trim()
                continue
            }
            if ($s -match '(?i)^webui[\\/]use_https\s*=\s*(true|false)\s*$') {
                $r.Https = $matches[1]
                continue
            }

            # BT 监听端口
            if ($s -match '(?i)^(?:connection[\\/]port|session[\\/]port|listen_port|torrenting_port)\s*=\s*(\d+)\s*$') {
                $r.TorrentPort = [int]$matches[1]
                continue
            }
            if ($s -match '(?i)^connection[\\/]port_range_min\s*=\s*(\d+)\s*$') {
                $r.TorrentPort = [int]$matches[1]
                continue
            }
            if ($s -match '(?i)^connection[\\/]portrangemin\s*=\s*(\d+)\s*$') {
                $r.TorrentPort = [int]$matches[1]
                continue
            }
        }

        break
    }

    # 命令行优先级高于配置文件
    $qp = $allProcesses |
        Where-Object { $_.Name -eq 'qbittorrent.exe' } |
        Select-Object -First 1

    if ($qp) {
        $cmd = [string]$qp.CommandLine

        if ($cmd -match '(?i)--webui-port(?:=|\s+)(\d+)') {
            $r.WebUIPort = [int]$matches[1]
            $r.WebUIEnabled = $true
        }

        if ($cmd -match '(?i)--torrenting-port(?:=|\s+)(\d+)') {
            $r.TorrentPort = [int]$matches[1]
        }
    }

    # 实际监听优先：如果 qBittorrent 只有 BT 端口，没有第二个 TCP 监听，
    # 不强行猜 WebUI 端口。
    return [pscustomobject]$r
}
$qbitInfo = Get-QBitInfo

# ------------------------------------------------------------
# aria2 配置：解析 --conf-path，并区分 RPC / BT / DHT
# ------------------------------------------------------------
function Get-Aria2Info {
    $r = [ordered]@{Path=$null;EnableRPC=$null;RPCPort=$null;RPCAll=$null;BTPort=$null;DHTPort=$null;HasSecret=$false}
    $ap = $allProcesses | Where-Object { $_.Name -match '^aria2.*\.exe$' } | Select-Object -First 1
    if (-not $ap) { return [pscustomobject]$r }
    $cmd = [string]$ap.CommandLine
    if ($cmd -match '(?i)--conf-path\s*=\s*(?:"([^"]+)"|(\S+))') {
        if ($matches[1]) { $r.Path = $matches[1] } else { $r.Path = $matches[2] }
    }
    if (-not $r.Path -or -not (Test-Path -LiteralPath $r.Path)) { return [pscustomobject]$r }
    foreach ($line in @(Get-Content -LiteralPath $r.Path)) {
        $s = [string]$line
        if ($s -match '^\s*#') { continue }
        if ($s -match '(?i)^\s*enable-rpc\s*=\s*(true|false)') { $r.EnableRPC=$matches[1] }
        elseif ($s -match '(?i)^\s*rpc-listen-port\s*=\s*(\d+)') { $r.RPCPort=[int]$matches[1] }
        elseif ($s -match '(?i)^\s*rpc-listen-all\s*=\s*(true|false)') { $r.RPCAll=$matches[1] }
        elseif ($s -match '(?i)^\s*listen-port\s*=\s*(\d+)') { $r.BTPort=[int]$matches[1] }
        elseif ($s -match '(?i)^\s*dht-listen-port\s*=\s*(\d+)') { $r.DHTPort=[int]$matches[1] }
        elseif ($s -match '(?i)^\s*rpc-secret\s*=\s*\S+') { $r.HasSecret=$true }
    }
    return [pscustomobject]$r
}
$ariaInfo = Get-Aria2Info

# ------------------------------------------------------------
# 分类全部进程
# ------------------------------------------------------------
$appMap = @{}
foreach ($proc in $allProcesses) {
    $rule = Get-AppRule ([string]$proc.Name) ([string]$proc.ExecutablePath) ([string]$proc.CommandLine)
    if (-not $rule) { continue }
    $key = "$($rule.Category)|$($rule.Name)"
    if (-not $appMap.ContainsKey($key)) {
        $appMap[$key] = [ordered]@{Category=$rule.Category;Name=$rule.Name;Purpose=$rule.Purpose;Score=$rule.Score;PIDs=(New-Object System.Collections.ArrayList);Paths=(New-Object System.Collections.ArrayList);Commands=(New-Object System.Collections.ArrayList);LANTCP=(New-Object System.Collections.ArrayList);LocalTCP=(New-Object System.Collections.ArrayList);UDP=(New-Object System.Collections.ArrayList)}
    }
    $app = $appMap[$key]
    $pidValue = [int]$proc.ProcessId
    if (-not $app.PIDs.Contains($pidValue)) { [void]$app.PIDs.Add($pidValue) }
    if ($proc.ExecutablePath -and -not $app.Paths.Contains([string]$proc.ExecutablePath)) { [void]$app.Paths.Add([string]$proc.ExecutablePath) }
    if ($proc.CommandLine -and -not $app.Commands.Contains([string]$proc.CommandLine)) { [void]$app.Commands.Add([string]$proc.CommandLine) }
    if ($tcpByPid.ContainsKey($pidValue)) {
        foreach ($c in $tcpByPid[$pidValue]) {
            $addr=[string]$c.LocalAddress; $port=[int]$c.LocalPort
            if (Test-IsLoopback $addr) { if (-not $app.LocalTCP.Contains($port)) { [void]$app.LocalTCP.Add($port) } }
            else { if (-not $app.LANTCP.Contains($port)) { [void]$app.LANTCP.Add($port) } }
        }
    }
    if ($udpByPid.ContainsKey($pidValue)) {
        foreach ($u in $udpByPid[$pidValue]) { $port=[int]$u.LocalPort; if (-not $app.UDP.Contains($port)) { [void]$app.UDP.Add($port) } }
    }
}
$apps = @($appMap.Values) | Sort-Object @{Expression={
    switch ($_.Category) {
        '文件服务器'{0};'媒体服务器'{1};'网页 / API'{2};'文件同步'{3};'手机互传'{4};'下载服务'{5};'网络加速'{6};'代理工具'{7};'VPN / 隧道'{8};'远程控制'{9};'云同步'{10};default{99}
    }
}},Name

$syncthingApps=@($apps|Where-Object{$_.Name -eq 'Syncthing'})
$localSendApps=@($apps|Where-Object{$_.Name -eq 'LocalSend'})

# ------------------------------------------------------------
# 网络 / SMB / 服务
# ------------------------------------------------------------
$privateIPs=@(Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.IPAddress -notmatch '^127\.' -and $_.IPAddress -notmatch '^169\.254\.' -and $_.AddressState -eq 'Preferred' -and ($_.IPAddress -match '^10\.' -or $_.IPAddress -match '^192\.168\.' -or $_.IPAddress -match '^172\.(1[6-9]|2[0-9]|3[0-1])\.')
})
$wifiItem=$privateIPs|Where-Object{$_.InterfaceAlias -match 'WLAN|Wi-?Fi|无线'}|Select-Object -First 1
$wifiIP=if($wifiItem){$wifiItem.IPAddress}elseif($privateIPs.Count){$privateIPs[0].IPAddress}else{$null}
$wifiProfile=Get-NetConnectionProfile|Where-Object{$_.InterfaceAlias -match 'WLAN|Wi-?Fi|无线'}|Select-Object -First 1

$allShares=@(Get-SmbShare)
$normalShares=@($allShares|Where-Object{([string]$_.Name) -notmatch '\$$'})
$hiddenShares=@($allShares|Where-Object{([string]$_.Name) -match '\$$'})
$printerShares=@($allShares|Where-Object{$_.ShareType -match 'Printer'})

$nfsShares=@(); if(Get-Command Get-NfsShare -ErrorAction SilentlyContinue){$nfsShares=@(Get-NfsShare)}
$ftp=Get-Service ftpsvc -ErrorAction SilentlyContinue
$sshd=Get-Service sshd -ErrorAction SilentlyContinue
$iis=@(); if(Get-Command Get-WebSite -ErrorAction SilentlyContinue){$iis=@(Get-WebSite)}
$webdav=$false; if(Get-Command Get-WebConfiguration -ErrorAction SilentlyContinue){foreach($m in @(Get-WebConfiguration -Filter '/system.webServer/modules/add')){if([string]$m.name -match 'WebDAV'){$webdav=$true;break}}}
$ssdpsrv=Get-Service SSDPSRV -ErrorAction SilentlyContinue
$upnp=Get-Service upnphost -ErrorAction SilentlyContinue
$wmp=Get-Service WMPNetworkSvc -ErrorAction SilentlyContinue
$upnpFound=(($ssdpsrv.Status -eq 'Running') -or ($upnp.Status -eq 'Running'))
$mediaFound=(($apps|Where-Object{$_.Category -eq '媒体服务器' -and $_.LANTCP.Count -gt 0}).Count -gt 0)
$dlnaFound=(($wmp.Status -eq 'Running') -or $mediaFound)

# ------------------------------------------------------------
# 首页
# ------------------------------------------------------------
Show-Title '网络共享检查'
Show-Section '电脑'
Write-Host "电脑名：$env:COMPUTERNAME"
Write-Host "当前用户：$env:USERDOMAIN\$env:USERNAME"

Show-Section '网络'
foreach($ip in $privateIPs){Write-Host ("  {0} : {1}" -f $ip.InterfaceAlias,$ip.IPAddress) -ForegroundColor Cyan}
if($wifiProfile){Write-Host "当前网络：$($wifiProfile.Name)";Write-Host "网络类型：$($wifiProfile.NetworkCategory)"}
if($wifiIP){Write-Host "手机优先连接：$wifiIP" -ForegroundColor Green}else{Show-Warn '没有发现局域网 IPv4'}

Show-Section '文件共享 / 文件服务'
if($normalShares.Count){Show-OK 'SMB：有共享文件夹'}else{Show-Bad 'SMB：没有发现普通共享文件夹'}
if($nfsShares.Count){Show-OK 'NFS：有共享'}else{Write-Host 'NFS：没有发现' -ForegroundColor DarkGray}
if($ftp.Status -eq 'Running'){Show-OK 'FTP：服务正在运行'}else{Write-Host 'FTP：没有发现' -ForegroundColor DarkGray}
if($sshd.Status -eq 'Running'){Show-OK 'SFTP：OpenSSH 正在运行'}else{Write-Host 'SFTP：没有发现' -ForegroundColor DarkGray}
if($webdav){Show-OK 'WebDAV：已确认'}else{Write-Host 'WebDAV：没有确认' -ForegroundColor DarkGray}
if($dlnaFound){Show-OK 'DLNA：媒体共享可用'}elseif($upnpFound){Show-Warn 'DLNA：有 UPnP / SSDP，但未确认媒体共享'}else{Write-Host 'DLNA：没有发现' -ForegroundColor DarkGray}
if($syncthingApps.Count){Show-OK 'Syncthing：文件同步'}else{Write-Host 'Syncthing：没有发现' -ForegroundColor DarkGray}
if($localSendApps.Count){Show-OK 'LocalSend：局域网文件传输'}else{Write-Host 'LocalSend：没有发现' -ForegroundColor DarkGray}

Show-Section '手机可访问服务'
foreach($s in $normalShares){if($wifiIP){Write-Host ("  SMB：smb://{0}/{1}" -f $wifiIP,$s.Name) -ForegroundColor Green}}
foreach($a in $syncthingApps){foreach($p in @($a.LANTCP|Sort-Object -Unique)){
    if($p -eq 22000){Write-Host '  Syncthing 22000：文件同步（TCP/QUIC，按实际监听显示）' -ForegroundColor Cyan}
}}
foreach($a in $localSendApps){foreach($p in @($a.LANTCP|Sort-Object -Unique)){Write-Host ("  LocalSend TCP {0}：文件传输" -f $p) -ForegroundColor Cyan}}
foreach($a in $apps){
    if($a.Name -eq 'aria2'){
        foreach($p in @($a.LANTCP|Sort-Object -Unique)){
            $role='aria2 网络服务'
            if($ariaInfo.RPCPort -eq $p){$role='JSON-RPC / XML-RPC'}elseif($ariaInfo.BTPort -eq $p){$role='BitTorrent'}elseif($ariaInfo.DHTPort -eq $p){$role='DHT'}
            Write-Host ("  aria2 TCP {0}：{1}" -f $p,$role) -ForegroundColor Cyan
        }
    }
    elseif($a.Name -eq 'qBittorrent'){
        foreach($p in @($a.LANTCP|Sort-Object -Unique)){
            $role=if($qbitInfo.WebUIPort -eq $p){'WebUI'}elseif($qbitInfo.TorrentPort -eq $p){'BT Peer'}else{'qBittorrent 网络服务'}
            Write-Host ("  qBittorrent TCP {0}：{1}" -f $p,$role) -ForegroundColor Cyan
        }
    }
    elseif($a.Category -eq '网络加速'){
        foreach($p in @($a.LANTCP|Sort-Object -Unique)){Write-Host ("  {0} TCP {1}：网络加速，不是文件服务" -f $a.Name,$p) -ForegroundColor Yellow}
    }
}

Show-Section '手机访问建议'
foreach($s in $normalShares){if($wifiIP){Write-Host ("  SMB  [推荐] {0}" -f $s.Name) -ForegroundColor Green;Write-Host ("       smb://{0}/{1}  只读" -f $wifiIP,$s.Name) -ForegroundColor Gray}}
if($localSendApps.Count){Write-Host '  LocalSend [推荐] 文件传输' -ForegroundColor Green;Write-Host '       适合临时发送/接收文件' -ForegroundColor Gray}
if($syncthingApps.Count){Write-Host '  Syncthing [推荐] 文件同步' -ForegroundColor Green;Write-Host '       适合自动同步文件夹' -ForegroundColor Gray}
$qbitLanPorts = @($apps | Where-Object { $_.Name -eq 'qBittorrent' } | ForEach-Object { $_.LANTCP } | Sort-Object -Unique)
if($qbitInfo.WebUIPort -and ($qbitLanPorts -contains $qbitInfo.WebUIPort)) {
    $qbitScheme = if($qbitInfo.Https -eq 'true'){'https'}else{'http'}
    Write-Host ("  qBittorrent [推荐] WebUI {0}://{1}:{2}" -f $qbitScheme,$wifiIP,$qbitInfo.WebUIPort) -ForegroundColor Green
}
elseif($qbitLanPorts.Count -gt 0) {
    Write-Host '  qBittorrent [可用] BT Peer' -ForegroundColor Cyan
    if($qbitInfo.WebUIPort) {
        Write-Host ("       WebUI 端口 {0} 没有出现在局域网监听中" -f $qbitInfo.WebUIPort) -ForegroundColor DarkGray
    }
    else {
        Write-Host '       没发现独立的 WebUI 局域网监听' -ForegroundColor DarkGray
    }
}

$ariaLanPorts = @($apps | Where-Object { $_.Name -eq 'aria2' } | ForEach-Object { $_.LANTCP } | Sort-Object -Unique)
if($ariaInfo.RPCPort -and ($ariaLanPorts -contains $ariaInfo.RPCPort)) {
    Write-Host ("  aria2 [注意] RPC TCP {0} 对局域网开放" -f $ariaInfo.RPCPort) -ForegroundColor Yellow
    if($ariaInfo.HasSecret){Write-Host '       已检测到 RPC 认证参数' -ForegroundColor Gray}
    else{Write-Host '       未检测到 rpc-secret，建议检查认证' -ForegroundColor Yellow}
}
elseif($ariaInfo.RPCPort) {
    Write-Host ("  aria2 [本机] RPC TCP {0}，没有对局域网开放" -f $ariaInfo.RPCPort) -ForegroundColor Green
}
else {
    Write-Host '  aria2 [可用] 下载 / 网络服务' -ForegroundColor Cyan
}
foreach($a in $apps){if($a.Category -eq '网络加速'){Write-Host ("  {0} [非文件服务] 网络加速" -f $a.Name) -ForegroundColor Yellow}}

Show-Section '共享文件夹'
foreach($s in $normalShares){
    Write-Host ""
    Write-Host ("共享：{0}" -f $s.Name) -ForegroundColor Cyan
    Write-Host ("文件夹：{0}" -f $s.Path) -ForegroundColor Gray
    $shareReadOnly=$true
    foreach($x in @(Get-SmbShareAccess -Name $s.Name)){if($x.AccessControlType -eq 'Allow' -and $x.AccessRight -match 'Change|Full'){$shareReadOnly=$false}}
    if($shareReadOnly){Write-Host '网络权限：只读' -ForegroundColor Green;Write-Host '读取：是' -ForegroundColor Green;Write-Host '写入：否' -ForegroundColor Red;Write-Host '删除：否' -ForegroundColor Red}
    else{Write-Host '网络权限：共享层允许写入' -ForegroundColor Yellow;Write-Host '读取：是' -ForegroundColor Green;Write-Host '写入：可能' -ForegroundColor Yellow;Write-Host '删除：需继续看 NTFS' -ForegroundColor Yellow}
    if($wifiIP){Write-Host ("手机地址：smb://{0}/{1}" -f $wifiIP,$s.Name) -ForegroundColor Green}
}

Show-Section 'Syncthing'
$syncConfig="$env:LOCALAPPDATA\Syncthing\config.xml"
$guiAddress=$null
if(Test-Path $syncConfig){
    try{
        [xml]$sx=Get-Content -LiteralPath $syncConfig -Encoding UTF8
        if($sx.configuration.gui.address){$guiAddress=[string]$sx.configuration.gui.address}
        Write-Host ("管理页面：http://{0}" -f $guiAddress) -ForegroundColor Cyan
        Write-Host "配置文件：$syncConfig" -ForegroundColor Gray
        foreach($f in @($sx.configuration.folder)){
            if($f){
                $mode=switch([string]$f.type){'sendonly'{'仅发送';break}'receiveonly'{'仅接收';break}default{'双向同步'}}
                Write-Host ''
                Write-Host "同步文件夹：" -ForegroundColor Gray
                Write-Host ("名称：{0}" -f $f.label)
                Write-Host ("位置：{0}" -f $f.path)
                Write-Host ("方式：{0}" -f $mode)
                if([string]$f.paused -eq 'true'){Show-Warn '状态：已暂停'}else{Show-OK '状态：运行中'}
            }
        }
    }catch{Write-Host "配置文件：$syncConfig";Show-Warn '无法解析 Syncthing 配置'}
}else{Write-Host '没有找到 Syncthing 配置文件' -ForegroundColor DarkGray}

Show-Section '局域网暴露'
$exposure=@()
if(@($tcpListeners|Where-Object{$_.LocalPort -in 139,445}).Count){$exposure+=[pscustomobject]@{Name='Windows SMB';Port='139 / 445';Type='文件共享';Level='正常'}}
foreach($a in $apps){foreach($p in @($a.LANTCP|Sort-Object -Unique)){
    $lvl=if($a.Category -eq '网络加速'){'第三方服务'}elseif($a.Category -in @('代理工具','VPN / 隧道')){'代理 / 隧道'}else{'正常'}
    $exposure+=[pscustomobject]@{Name=$a.Name;Port=$p;Type=$a.Category;Level=$lvl}
}}
foreach($e in $exposure|Sort-Object Type,Name,Port){$c=if($e.Level -eq '正常'){'Gray'}else{'Yellow'};Write-Host ("{0} : {1} / {2}" -f $e.Name,$e.Port,$e.Type) -ForegroundColor $c}

Show-Section '局域网端口自测'
if($wifiIP){
    $ports=@()
    foreach($a in $apps){foreach($p in $a.LANTCP){if($ports -notcontains $p){$ports+=$p}}}
    if(@($tcpListeners|Where-Object{$_.LocalPort -eq 445}).Count -and $ports -notcontains 445){$ports+=445}
    foreach($p in $ports|Sort-Object){if(Test-TcpSelfConnection $wifiIP $p){Write-Host ("{0}:{1} -> 本机连接成功" -f $wifiIP,$p) -ForegroundColor Green}else{Write-Host ("{0}:{1} -> 本机连接失败/被阻断" -f $wifiIP,$p) -ForegroundColor Yellow}}
    Show-Info '此测试只证明电脑自己访问 WLAN 地址是否成功，不等于手机一定能访问。'
}

Show-Section '结论'
if($normalShares.Count){Show-OK '有可直接浏览的 SMB 共享文件夹'}
if($syncthingApps.Count){Show-OK '有 Syncthing 文件同步'}
if($localSendApps.Count){Show-OK '有 LocalSend 局域网文件传输'}
if(($apps|Where-Object{$_.Category -eq '网络加速'}).Count){Show-Info '检测到网络加速 / 游戏加速软件'}
if(($apps|Where-Object{$_.Category -in @('代理工具','VPN / 隧道')}).Count){Show-Info '检测到代理或 VPN / 隧道软件'}
if($upnpFound -and -not $dlnaFound){Show-Info '检测到 UPnP / SSDP，但目前没有确认 DLNA 媒体共享'}

# ============================================================
# 专业信息
# ============================================================
Show-Title '专业详细信息'

Show-Section 'SMB 配置'
try{Get-SmbServerConfiguration|Select-Object EnableSMB1Protocol,EnableSMB2Protocol,EncryptData,RequireSecuritySignature|Format-List|Out-Host}catch{Show-Bad '无法读取 SMB 配置'}

Show-Section 'SMB 端口'
@($tcpListeners|Where-Object{$_.LocalPort -in 139,445}|Select-Object LocalAddress,LocalPort,OwningProcess|Sort-Object LocalPort,LocalAddress|Format-Table -AutoSize|Out-Host)

Show-Section '管理员 / 隐藏共享'
if($hiddenShares.Count){foreach($s in $hiddenShares){Write-Host ("{0} -> {1}" -f $s.Name,$s.Path) -ForegroundColor DarkYellow}}else{Write-Host '没有发现隐藏共享' -ForegroundColor DarkGray}

Show-Section '打印机共享'
if($printerShares.Count){foreach($s in $printerShares){Write-Host ("{0} -> {1}" -f $s.Name,$s.Path) -ForegroundColor Cyan}}else{Write-Host '没有打印机共享' -ForegroundColor DarkGray}

Show-Section 'SMB / NTFS 原始 ACL'
foreach($s in $normalShares){
    Write-Host ""
    Write-Host ("共享：{0}" -f $s.Name) -ForegroundColor Cyan
    Write-Host ("路径：{0}" -f $s.Path) -ForegroundColor Gray
    Write-Host '共享 ACL：' -ForegroundColor Yellow
    @(Get-SmbShareAccess -Name $s.Name|Select-Object AccountName,AccessControlType,AccessRight|Format-Table -AutoSize|Out-String -Width 220)|Write-Host
    if($s.Path -and (Test-Path $s.Path)){
        Write-Host 'NTFS ACL：' -ForegroundColor Yellow
        @(Get-Acl $s.Path|Select-Object -ExpandProperty Access|Select-Object IdentityReference,AccessControlType,FileSystemRights,IsInherited|Format-Table -AutoSize|Out-String -Width 220)|Write-Host
    }
}

Show-Section 'NFS'
if($nfsShares.Count){$nfsShares|Format-Table -AutoSize|Out-Host}else{Write-Host '没有 NFS 共享' -ForegroundColor DarkGray}
Show-Section 'FTP'
if($ftp){$ftp|Select-Object Name,Status,StartType|Format-Table -AutoSize|Out-Host}else{Write-Host 'FTP 服务不存在' -ForegroundColor DarkGray}
Show-Section 'OpenSSH / SFTP'
if($sshd){$sshd|Select-Object Name,Status,StartType|Format-Table -AutoSize|Out-Host}else{Write-Host 'OpenSSH SSHD 服务不存在' -ForegroundColor DarkGray}
Show-Section 'IIS / WebDAV'
Write-Host "WebDAV 模块：$webdav"
if($iis.Count){$iis|Select-Object Name,State,PhysicalPath,Bindings|Format-List|Out-Host}else{Write-Host '没有 IIS 站点' -ForegroundColor DarkGray}

Show-Section '已识别程序'
foreach($a in $apps){
    Write-Host ''
    Write-Host ("类别   : {0}" -f $a.Category) -ForegroundColor Magenta
    Write-Host ("名称   : {0}" -f $a.Name) -ForegroundColor Cyan
    Write-Host ("用途   : {0}" -f $a.Purpose)
    Write-Host ("可信度 : {0}" -f $a.Score)
    Write-Host ("PID    : {0}" -f (($a.PIDs|Sort-Object -Unique)-join ', '))
    Write-Host ("局域网 TCP : {0}" -f (($a.LANTCP|Sort-Object -Unique)-join ', '))
    Write-Host ("本机 TCP   : {0}" -f (($a.LocalTCP|Sort-Object -Unique)-join ', '))
    Write-Host ("UDP        : {0}" -f (($a.UDP|Sort-Object -Unique)-join ', '))
    foreach($p in $a.Paths|Sort-Object -Unique){Write-Host ("  {0}" -f $p) -ForegroundColor DarkGray}
}

Show-Section 'qBittorrent 专业信息'
if($qbitInfo.Path){Write-Host "配置文件：$($qbitInfo.Path)" -ForegroundColor Gray}else{Write-Host '没有找到 qBittorrent 配置文件' -ForegroundColor DarkGray}
if($qbitInfo.WebUIPort){Write-Host "WebUI 端口：$($qbitInfo.WebUIPort)" -ForegroundColor Cyan}else{Write-Host 'WebUI 端口：配置中没有识别到' -ForegroundColor DarkGray}
if($qbitInfo.WebUIAddress){Write-Host "WebUI 地址：$($qbitInfo.WebUIAddress)"}
if($qbitInfo.Https){Write-Host "WebUI HTTPS：$($qbitInfo.Https)"}
if($qbitInfo.TorrentPort){Write-Host "BT 端口：$($qbitInfo.TorrentPort)"}
$qbitLanPorts2 = @($apps | Where-Object { $_.Name -eq 'qBittorrent' } | ForEach-Object { $_.LANTCP } | Sort-Object -Unique)
if($qbitInfo.WebUIPort -and ($qbitLanPorts2 -contains $qbitInfo.WebUIPort)){Show-OK ("检测到 qBittorrent WebUI 局域网监听：TCP {0}" -f $qbitInfo.WebUIPort)}elseif($qbitInfo.WebUIPort){Show-Info ("WebUI 端口为 {0}，但当前没有发现该端口属于 qBittorrent 的局域网 LISTEN" -f $qbitInfo.WebUIPort)}else{Show-Info '当前没有识别到 qBittorrent WebUI 独立监听'}

Show-Section 'aria2 专业信息'
if($ariaInfo.Path){Write-Host "配置文件：$($ariaInfo.Path)" -ForegroundColor Gray}else{Write-Host '没有读取到 aria2 配置文件' -ForegroundColor DarkGray}
if($null -ne $ariaInfo.EnableRPC){Write-Host "RPC：$($ariaInfo.EnableRPC)"}
if($ariaInfo.RPCPort){Write-Host "RPC 端口：$($ariaInfo.RPCPort)"}
if($null -ne $ariaInfo.RPCAll){Write-Host "RPC 全接口监听：$($ariaInfo.RPCAll)"}
if($ariaInfo.BTPort){Write-Host "BT 监听端口：$($ariaInfo.BTPort)"}
if($ariaInfo.DHTPort){Write-Host "DHT 端口：$($ariaInfo.DHTPort)"}
if($ariaInfo.HasSecret){Show-OK '检测到 RPC 认证参数'}elseif($ariaInfo.EnableRPC -eq 'true'){Show-Warn 'RPC 已开启，但没有检测到 rpc-secret'}
$ariaLanPorts2 = @($apps | Where-Object { $_.Name -eq 'aria2' } | ForEach-Object { $_.LANTCP } | Sort-Object -Unique)
if($ariaInfo.RPCPort -and ($ariaLanPorts2 -contains $ariaInfo.RPCPort)){Show-Warn ("RPC TCP {0}：对局域网开放" -f $ariaInfo.RPCPort)}elseif($ariaInfo.RPCPort){Show-OK ("RPC TCP {0}：仅本机监听，手机不能直接连接" -f $ariaInfo.RPCPort)}
if($ariaInfo.BTPort -and ($ariaLanPorts2 -contains $ariaInfo.BTPort)){Show-Info ("BT TCP {0}：对局域网开放" -f $ariaInfo.BTPort)}

Show-Section 'Syncthing 专业信息'
foreach($p in @($allProcesses|Where-Object{$_.Name -match '^syncthing\.exe$'})){
    Write-Host ("PID：{0}" -f $p.ProcessId)
    Write-Host ("路径：{0}" -f $p.ExecutablePath)
    Write-Host ("命令行：{0}" -f $p.CommandLine) -ForegroundColor DarkGray
}
foreach($port in 8384,22000,21027){
    Write-Host ""
    Write-Host ("{0}：" -f $port) -ForegroundColor Cyan
    $t=@($tcpListeners|Where-Object{$_.LocalPort -eq $port}|Select-Object LocalAddress,LocalPort,OwningProcess)
    $u=@($allUdp|Where-Object{$_.LocalPort -eq $port}|Select-Object LocalAddress,LocalPort,OwningProcess)
    if($t.Count){Write-Host 'TCP：' -ForegroundColor Gray;$t|Format-Table -AutoSize|Out-Host}
    if($u.Count){Write-Host 'UDP：' -ForegroundColor Gray;$u|Format-Table -AutoSize|Out-Host}
}

Show-Section '当前 SMB 会话'
try{$ss=@(Get-SmbSession);if($ss.Count){$ss|Select-Object ClientComputerName,ClientUserName,NumOpens,Dialect|Format-Table -AutoSize|Out-Host}else{Write-Host '当前没有 SMB 客户端会话' -ForegroundColor DarkGray}}catch{Write-Host '无法读取 SMB 会话' -ForegroundColor DarkGray}

Show-Section '第三方 TCP 监听'
$tp=@{}
foreach($x in $tcpListeners){$pidValue=[int]$x.OwningProcess;$pr=$allProcesses|Where-Object{[int]$_.ProcessId -eq $pidValue}|Select-Object -First 1;if(-not $pr){continue};$n=[string]$pr.Name;if($n -in @('System','svchost.exe','lsass.exe','services.exe','wininit.exe','spoolsv.exe','winlogon.exe')){continue};$key="$pidValue|$($x.LocalPort)";if(-not $tp.ContainsKey($key)){$tp[$key]=[ordered]@{PID=$pidValue;Port=[int]$x.LocalPort;Name=$n;Path=[string]$pr.ExecutablePath;LAN=New-Object System.Collections.ArrayList;Local=New-Object System.Collections.ArrayList}};$i=$tp[$key];$ad=[string]$x.LocalAddress;if(Test-IsLoopback $ad){if(-not $i.Local.Contains($ad)){[void]$i.Local.Add($ad)}}else{if(-not $i.LAN.Contains($ad)){[void]$i.LAN.Add($ad)}}}
foreach($i in $tp.Values|Sort-Object Port,Name){Write-Host '';Write-Host ("{0}  PID {1}  {2}" -f $i.Port,$i.PID,$i.Name) -ForegroundColor Cyan;if($i.LAN.Count){Write-Host ("局域网：{0}" -f ($i.LAN-join ', ')) -ForegroundColor Green};if($i.Local.Count){Write-Host ("本机：{0}" -f ($i.Local-join ', ')) -ForegroundColor DarkGray};if($i.Path){Write-Host ("位置：{0}" -f $i.Path) -ForegroundColor DarkGray}}

Show-Section '重要 UDP'
$udpPorts=137,138,1900,5353,5355,21027
$seen=@{}
foreach($u in $allUdp){$port=[int]$u.LocalPort;if($udpPorts-notcontains $port){continue};$pidValue=[int]$u.OwningProcess;$key="$port|$pidValue";if($seen.ContainsKey($key)){continue};$seen[$key]=$true;$pr=$allProcesses|Where-Object{[int]$_.ProcessId -eq $pidValue}|Select-Object -First 1;$name=if($pr){$pr.Name}else{'未知'};$d=switch($port){137{'SMB / NetBIOS 名称'};138{'SMB / NetBIOS 数据报'};1900{'UPnP / SSDP'};5353{'mDNS'};5355{'LLMNR'};21027{'Syncthing 本地发现'}};Write-Host ("{0}  {1}  PID {2}  {3}" -f $port,$d,$pidValue,$name)}

Show-Section '相关 Windows 服务'
foreach($sn in @('LanmanServer','LanmanWorkstation','MSiSCSI','SSDPSRV','upnphost','WMPNetworkSvc','sshd','ftpsvc')){$s=Get-Service $sn -ErrorAction SilentlyContinue;if($s){Write-Host ("{0,-18} {1,-10} {2}" -f $s.Name,$s.Status,$s.StartType)}}

Show-Section '防火墙'
try{Get-NetFirewallProfile|Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction|Format-Table -AutoSize|Out-Host}catch{Show-Bad '无法读取防火墙配置'}

Show-Section 'SMB 防火墙检查'

try {
    $fwRules = @(
        Get-NetFirewallRule -Enabled True -Direction Inbound -Action Allow
    )

    $fwMatches = @()

    foreach($r in $fwRules) {
        $dn = [string]$r.DisplayName
        $dg = [string]$r.DisplayGroup
        $gn = [string]$r.Group

        $text = ($dn + ' ' + $dg + ' ' + $gn)

        # 不再调用 Get-NetFirewallPortFilter。
        # Windows 不同版本 / 本地化环境在这个关联调用上容易失败。
        # 直接根据 Windows 自带“文件和打印机共享 / 网络发现”规则名判断。
        $isSMB = (
            $text -match '(?i)SMB-In|NB-Session-In|NB-Name-In|NB-Datagram-In|File and Printer Sharing|文件和打印机共享'
        )

        if($isSMB) {
            $fwMatches += [pscustomobject]@{
                Name = $dn
                Profile = [string]$r.Profile
                Action = [string]$r.Action
                Group = $dg
            }
        }
    }

    $fwMatches = @(
        $fwMatches |
        Sort-Object Profile, Name -Unique
    )

    if($fwMatches.Count -gt 0) {
        $fwMatches | Format-Table -AutoSize | Out-Host
        Show-OK '检测到 Windows 文件共享 / SMB 入站允许规则'
    }
    else {
        Show-Warn '没有找到明确的 SMB / 文件共享入站允许规则'
    }
}
catch {
    Show-Warn ("防火墙规则读取失败：{0}" -f $_.Exception.Message)
}

# ============================================================
# 安全摘要
# ============================================================
Show-Section '安全摘要'

try {
    $smbCfg = Get-SmbServerConfiguration

    if($smbCfg.EnableSMB1Protocol -eq $false) {
        Show-OK 'SMB1：已关闭'
    }
    else {
        Show-Warn 'SMB1：处于开启状态'
    }

    if($smbCfg.RequireSecuritySignature -eq $true) {
        Show-OK 'SMB 签名：强制'
    }
    else {
        Show-Warn 'SMB 签名：没有强制要求'
    }

    if($smbCfg.EncryptData -eq $true) {
        Show-OK 'SMB 加密：开启'
    }
    else {
        Show-Info 'SMB 加密：未强制开启'
    }
}
catch {
}

if($normalShares.Count -gt 0) {
    Show-OK '普通共享的共享层权限目前均为只读'
}

if($hiddenShares.Count -gt 0) {
    Show-Info '系统仍存在 ADMIN$ / C$ / D$ / E$ / F$ 等管理员隐藏共享；它们没有放进手机普通共享列表。'
}

Show-Title '检查完成'
Read-Host '按回车键退出'
