# Shared helpers for CTG Snort IDS on Windows (authorized defensive lab use only).

. (Join-Path $PSScriptRoot 'CTG-WiresharkCommon.ps1')

function Get-CtgSnortRoot {
    $backups = Get-CtgBackupsRoot
    return Join-Path $backups 'ctg-snort'
}

function Get-CtgSnortPaths {
    $root = Get-CtgSnortRoot
    $logs = Join-Path (Get-CtgBackupsRoot) 'logs\snort'
    return [PSCustomObject]@{
        SnortRoot    = $root
        EtcDir       = Join-Path $root 'etc'
        RulesDir     = Join-Path $root 'rules'
        ConfFile     = Join-Path (Join-Path $root 'etc') 'snort.conf'
        LocalRules   = Join-Path (Join-Path $root 'rules') 'local.rules'
        AlertLog     = Join-Path $logs 'alert'
        IdsLog       = Join-Path $logs 'snort-ids.log'
        AlertsJson   = Join-Path $logs 'snort-alerts.json'
        StateFile    = Join-Path $logs 'snort-tail-state.json'
        LogsDir      = $logs
        SmsRateFile  = Join-Path (Get-CtgBackupsRoot) 'logs\sms-rate-limit.json'
    }
}

function Test-CtgWin11Pro {
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $caption = [string]$os.Caption
        $build = [int]$os.BuildNumber
        $isPro = $caption -match 'Pro' -or $caption -match 'Enterprise' -or $caption -match 'Education'
        $isWin11 = $build -ge 22000
        return [PSCustomObject]@{
            Ok       = ($isWin11 -and $isPro)
            Caption  = $caption
            Build    = $build
            IsPro    = $isPro
            IsWin11  = $isWin11
        }
    } catch {
        return [PSCustomObject]@{ Ok = $false; Caption = 'unknown'; Build = 0; IsPro = $false; IsWin11 = $false }
    }
}

function Test-CtgNpcapInstalled {
    $paths = @(
        "${env:ProgramFiles}\Npcap",
        "${env:ProgramFiles(x86)}\Npcap",
        "${env:ProgramFiles}\WinPcap"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { return $true }
    }
    $svc = Get-Service -Name npcap -ErrorAction SilentlyContinue
    if ($svc) { return $true }
    return $false
}

function Get-CtgSnortBinary {
    $found = Test-CtgSnortInstalled
    if ($found) { return $found }
    return $null
}

function Get-CtgSnortVersion {
    param([string] $SnortPath)
    if (-not $SnortPath) { return $null }
    try {
        $out = & $SnortPath -V 2>&1 | Select-Object -First 3
        return ($out -join ' ').Trim()
    } catch {
        return $null
    }
}

function Get-CtgSnortInterfaceList {
    param([string] $SnortPath)
    if (-not $SnortPath) { return @() }
    try {
        $out = & $SnortPath -W 2>&1
        $ifaces = @()
        foreach ($line in $out) {
            if ($line -match '^\s*(\d+)\.\s+(.+)$') {
                $ifaces += [PSCustomObject]@{
                    Index = $Matches[1]
                    Name  = $Matches[2].Trim()
                }
            }
        }
        return $ifaces
    } catch {
        return @()
    }
}

function Get-CtgSnortInterface {
    param(
        [string] $SnortPath,
        [string] $Preferred
    )
    if ($Preferred) { return $Preferred }
    $ifaces = Get-CtgSnortInterfaceList -SnortPath $SnortPath
    foreach ($iface in $ifaces) {
        if ($iface.Name -match 'Wi-Fi|Wireless|Ethernet|Realtek|Intel') {
            if ($iface.Name -notmatch 'Loopback|Npcap Loopback') {
                return $iface.Index
            }
        }
    }
    foreach ($iface in $ifaces) {
        if ($iface.Name -notmatch 'Loopback|Npcap Loopback') {
            return $iface.Index
        }
    }
    if ($ifaces.Count -gt 0) { return $ifaces[0].Index }
    return '1'
}

function Write-CtgSnortLog {
    param(
        [string] $Message,
        [string] $LogFile,
        [string] $Color = 'Gray'
    )
    Write-CtgWiresharkLog -Message $Message -LogFile $LogFile -Color $Color
}

function Get-CtgSnortHighSeverityKeywords {
    return @(
        'exploit', 'shellcode', 'trojan', 'backdoor', 'malware',
        'scan', 'nmap', 'attack', 'anomaly', 'cve-', 'overflow',
        'injection', 'botnet', 'c2', 'command and control'
    )
}

function Get-CtgSnortAlertSeverity {
    param([string] $Message, [int] $Priority = 3)
    $lower = $Message.ToLowerInvariant()
    if ($Priority -le 1) { return 'critical' }
    if ($Priority -eq 2) { return 'high' }
    foreach ($kw in @('exploit', 'shellcode', 'trojan', 'backdoor', 'malware')) {
        if ($lower.Contains($kw)) { return 'critical' }
    }
    foreach ($kw in @('scan', 'nmap', 'attack', 'anomaly')) {
        if ($lower.Contains($kw)) { return 'high' }
    }
    return 'medium'
}

function Parse-CtgSnortAlertLine {
    param([string] $Line)
    if ([string]::IsNullOrWhiteSpace($Line)) { return $null }
    if ($Line -notmatch '\[\*\*\]') { return $null }
    $sid = $null
    $gid = $null
    if ($Line -match '\[\s*(?<gid>\d+)\:(?<sid>\d+)\:') {
        $gid = $Matches['gid']
        $sid = $Matches['sid']
    }
    $priority = 3
    if ($Line -match '\[Priority:\s*(?<p>\d+)\]') {
        $priority = [int]$Matches['p']
    }
    $msg = $Line
    if ($Line -match '\[\*\*\]\s*(?<m>.+?)\s*\[\*\*\]') {
        $msg = $Matches['m'].Trim()
    }
    $srcIp = $null
    $dstIp = $null
    if ($Line -match '(?<src>\d+\.\d+\.\d+\.\d+):\d+\s+->\s+(?<dst>\d+\.\d+\.\d+\.\d+)') {
        $srcIp = $Matches['src']
        $dstIp = $Matches['dst']
    }
    $sev = Get-CtgSnortAlertSeverity -Message $msg -Priority $priority
    return [PSCustomObject]@{
        Sid      = $sid
        Gid      = $gid
        Message  = $msg
        Severity = $sev
        SrcIp    = $srcIp
        DstIp    = $dstIp
        Raw      = $Line
    }
}

function Read-CtgSnortTailState {
    param([string] $StatePath)
    if (-not (Test-Path $StatePath)) {
        return [PSCustomObject]@{ Offset = 0; Inode = $null }
    }
    try {
        $obj = Get-Content $StatePath -Raw -Encoding utf8 | ConvertFrom-Json
        return [PSCustomObject]@{
            Offset = [long]$obj.offset
            Inode  = $obj.inode
        }
    } catch {
        return [PSCustomObject]@{ Offset = 0; Inode = $null }
    }
}

function Save-CtgSnortTailState {
    param(
        [string] $StatePath,
        [long] $Offset,
        [string] $Inode
    )
    $dir = Split-Path $StatePath -Parent
    if ($dir) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [ordered]@{ offset = $Offset; inode = $Inode; updated = (Get-Date).ToString('o') } |
        ConvertTo-Json | Set-Content -Path $StatePath -Encoding utf8
}

function Read-CtgSnortNewAlerts {
    param(
        [string] $AlertLog,
        [string] $StatePath
    )
    if (-not (Test-Path $AlertLog)) { return @() }
    $state = Read-CtgSnortTailState -StatePath $StatePath
    $file = Get-Item $AlertLog
    $inode = "$($file.FullName)|$($file.Length)|$($file.LastWriteTimeUtc.Ticks)"
    $offset = $state.Offset
    if ($state.Inode -and $state.Inode -ne $inode) {
        $offset = 0
    }
    if ($offset -gt $file.Length) { $offset = 0 }
    $fs = [System.IO.File]::Open($AlertLog, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $fs.Seek($offset, [System.IO.SeekOrigin]::Begin) | Out-Null
        $reader = New-Object System.IO.StreamReader($fs)
        $text = $reader.ReadToEnd()
        $newOffset = $fs.Position
    } finally {
        $fs.Dispose()
    }
    Save-CtgSnortTailState -StatePath $StatePath -Offset $newOffset -Inode $inode
    $alerts = @()
    foreach ($line in $text -split "`n") {
        $parsed = Parse-CtgSnortAlertLine -Line $line.TrimEnd("`r")
        if ($parsed) { $alerts += $parsed }
    }
    return $alerts
}

function New-CtgSnortConfContent {
    param(
        [string] $RulesDir,
        [string] $LogDir,
        [string] $SnortInstallDir
    )
    $rules = $RulesDir -replace '\\', '\\'
    $logs = $LogDir -replace '\\', '\\'
    $dynPre = 'C:\\Snort\\lib\\snort_dynamicpreprocessor'
    $dynEng = 'C:\\Snort\\lib\\snort_dynamicengine\\sf_engine.dll'
    if ($SnortInstallDir) {
        $base = $SnortInstallDir -replace '\\', '\\'
        $dynPre = "$base\\lib\\snort_dynamicpreprocessor"
        $dynEng = "$base\\lib\\snort_dynamicengine\\sf_engine.dll"
    }
    @"
# CTG Windows Snort IDS — detect-only, community rules (authorized lab use)
ipvar HOME_NET [192.168.0.0/16,10.0.0.0/8,172.16.0.0/12]
ipvar EXTERNAL_NET !`$HOME_NET
var RULE_PATH $rules
var SO_RULE_PATH $rules
var PREPROC_RULE_PATH $rules
var WHITE_LIST_PATH $rules
var BLACK_LIST_PATH $rules
var SQL_SERVERS `$HOME_NET
var DNS_SERVERS `$HOME_NET
var SMTP_SERVERS `$HOME_NET
var HTTP_SERVERS `$HOME_NET

config logdir: $logs
config alert_with_interface_name
config disable_decode_drops
config disable_tcpopt_experimentation_drops
config disable_tcpopt_obsolete_drops
config checksum_mode: all

dynamicpreprocessor directory $dynPre
dynamicengine $dynEng

preprocessor stream5_global: max_tcp 262144, track_tcp yes, track_udp yes, track_icmp no
preprocessor stream5_tcp: policy first, use_static_footprint_sizes
preprocessor stream5_udp: timeout 30
preprocessor sfportscan: proto { all } scan_type { all } sense_level low

output alert_fast: $logs\\alert

include `$RULE_PATH\\local.rules
include `$RULE_PATH\\community.rules
"@
}

function Ensure-CtgSnortLayout {
    param([object] $Paths)
    foreach ($dir in @($Paths.SnortRoot, $Paths.EtcDir, $Paths.RulesDir, $Paths.LogsDir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (-not (Test-Path $Paths.LocalRules)) {
        @'
# CTG lab local Snort rules — authorized lab signatures only (detect-only)
alert icmp any any -> $HOME_NET any (msg:"CTG ICMP test rule"; sid:9000001; rev:1;)
'@ | Set-Content -Path $Paths.LocalRules -Encoding utf8
    }
    $community = Join-Path $Paths.RulesDir 'community.rules'
    if (-not (Test-Path $community)) {
        @'
# Placeholder — download community rules from https://www.snort.org/downloads (#rule-downloads)
# Or copy from C:\Snort\rules after official Snort Windows install
'@ | Set-Content -Path $community -Encoding utf8
    }
}
