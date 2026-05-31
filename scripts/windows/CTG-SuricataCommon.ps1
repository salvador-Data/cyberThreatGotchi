# Shared helpers for CTG Suricata IDS on Windows (authorized defensive lab use only).

. (Join-Path $PSScriptRoot 'CTG-SnortCommon.ps1')

function Get-CtgSuricataRoot {
    $backups = Get-CtgBackupsRoot
    return Join-Path $backups 'ctg-suricata'
}

function Get-CtgSuricataPaths {
    $root = Get-CtgSuricataRoot
    $logs = Join-Path (Get-CtgBackupsRoot) 'logs\suricata'
    return [PSCustomObject]@{
        SuricataRoot = $root
        EtcDir       = Join-Path $root 'etc'
        RulesDir     = Join-Path $root 'rules'
        YamlFile     = Join-Path (Join-Path $root 'etc') 'suricata.yaml'
        LocalRules   = Join-Path (Join-Path $root 'rules') 'local.rules'
        EveLog       = Join-Path $logs 'eve.json'
        FastLog      = Join-Path $logs 'fast.log'
        IdsLog       = Join-Path $logs 'suricata-ids.log'
        AlertsJson   = Join-Path $logs 'suricata-alerts.json'
        StateFile    = Join-Path $logs 'suricata-eve-tail-state.json'
        LogsDir      = $logs
        SmsRateFile  = Join-Path (Get-CtgBackupsRoot) 'logs\sms-rate-limit.json'
    }
}

function Get-CtgKaliSuricataBridgePaths {
    $backups = Get-CtgBackupsRoot
    $kaliLog = Join-Path $backups 'logs\kali-suricata'
    $siemLog = Join-Path $backups 'logs\siem'
    return [PSCustomObject]@{
        KaliEveStaging = Join-Path $kaliLog 'suricata-eve.json'
        SiemLatest     = Join-Path $siemLog 'ctg-siem-latest.json'
        BridgeLog      = Join-Path $kaliLog 'kali-suricata-bridge.log'
        StateFile      = Join-Path $kaliLog 'kali-eve-bridge-state.json'
    }
}

function Test-CtgSuricataInstalled {
    $paths = @(
        'C:\Program Files\Suricata\suricata.exe',
        'C:\Program Files (x86)\Suricata\suricata.exe',
        'C:\Suricata\suricata.exe'
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }
    $cmd = Get-Command suricata -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Get-CtgSuricataVersion {
    param([string] $SuricataPath)
    if (-not $SuricataPath) { return $null }
    try {
        $out = & $SuricataPath -V 2>&1 | Select-Object -First 3
        return ($out -join ' ').Trim()
    } catch {
        return $null
    }
}

function Get-CtgSuricataInstallDir {
    param([string] $SuricataPath)
    if (-not $SuricataPath) { return 'C:\Program Files\Suricata' }
    $dir = Split-Path $SuricataPath -Parent
    if ($dir -match '\\bin$') {
        return Split-Path $dir -Parent
    }
    return $dir
}

function Get-CtgSuricataInterfaceList {
    $ifaces = @()
    try {
        Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
            $_.Status -eq 'Up' -and $_.Name -notmatch 'Loopback|vEthernet|VirtualBox|VMware|Hyper-V'
        } | ForEach-Object {
            $ifaces += [PSCustomObject]@{
                Index = $_.ifIndex
                Name  = $_.Name
            }
        }
    } catch { }
    if ($ifaces.Count -gt 0) { return $ifaces }
    return @(
        [PSCustomObject]@{ Index = 1; Name = 'Wi-Fi' },
        [PSCustomObject]@{ Index = 2; Name = 'Ethernet' }
    )
}

function Get-CtgSuricataInterface {
    param([string] $Preferred)
    if ($Preferred) { return $Preferred }
    $ifaces = Get-CtgSuricataInterfaceList
    foreach ($iface in $ifaces) {
        if ($iface.Name -match 'Wi-Fi|Wireless|Ethernet|Realtek|Intel') {
            return $iface.Name
        }
    }
    if ($ifaces.Count -gt 0) { return $ifaces[0].Name }
    return 'Wi-Fi'
}

function Write-CtgSuricataLog {
    param(
        [string] $Message,
        [string] $LogFile,
        [string] $Color = 'Gray'
    )
    Write-CtgWiresharkLog -Message $Message -LogFile $LogFile -Color $Color
}

function Get-CtgSuricataAlertSeverity {
    param(
        [int] $Severity = 3,
        [string] $Message = ''
    )
    if ($Severity -le 1) { return 'critical' }
    if ($Severity -eq 2) { return 'high' }
    $lower = $Message.ToLowerInvariant()
    foreach ($kw in @('exploit', 'shellcode', 'trojan', 'backdoor', 'malware', 'cve-')) {
        if ($lower.Contains($kw)) { return 'critical' }
    }
    foreach ($kw in @('scan', 'nmap', 'attack', 'anomaly')) {
        if ($lower.Contains($kw)) { return 'high' }
    }
    return 'medium'
}

function Parse-CtgSuricataEveLine {
    param([string] $Line)
    if ([string]::IsNullOrWhiteSpace($Line)) { return $null }
    try {
        $obj = $Line | ConvertFrom-Json
    } catch {
        return $null
    }
    if ($obj.event_type -ne 'alert') { return $null }
    $sig = $obj.alert.signature
    $sid = [string]$obj.alert.signature_id
    $sevNum = 3
    if ($null -ne $obj.alert.severity) {
        $sevNum = [int]$obj.alert.severity
    }
    $sev = Get-CtgSuricataAlertSeverity -Severity $sevNum -Message $sig
    return [PSCustomObject]@{
        Sid      = $sid
        Message  = $sig
        Severity = $sev
        SrcIp    = [string]$obj.src_ip
        DstIp    = [string]$obj.dest_ip
        Action   = [string]$obj.alert.action
        Raw      = $Line
    }
}

function Read-CtgSuricataTailState {
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

function Save-CtgSuricataTailState {
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

function Read-CtgSuricataNewAlerts {
    param(
        [string] $EveLog,
        [string] $StatePath
    )
    if (-not (Test-Path $EveLog)) { return @() }
    $state = Read-CtgSuricataTailState -StatePath $StatePath
    $file = Get-Item $EveLog
    $inode = "$($file.FullName)|$($file.Length)|$($file.LastWriteTimeUtc.Ticks)"
    $offset = $state.Offset
    if ($state.Inode -and $state.Inode -ne $inode) {
        $offset = 0
    }
    if ($offset -gt $file.Length) { $offset = 0 }
    $fs = [System.IO.File]::Open($EveLog, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $fs.Seek($offset, [System.IO.SeekOrigin]::Begin) | Out-Null
        $reader = New-Object System.IO.StreamReader($fs)
        $text = $reader.ReadToEnd()
        $newOffset = $fs.Position
    } finally {
        $fs.Dispose()
    }
    Save-CtgSuricataTailState -StatePath $StatePath -Offset $newOffset -Inode $inode
    $alerts = @()
    foreach ($line in $text -split "`n") {
        $parsed = Parse-CtgSuricataEveLine -Line $line.TrimEnd("`r")
        if ($parsed) { $alerts += $parsed }
    }
    return $alerts
}

function New-CtgSuricataYamlContent {
    param(
        [string] $RulesDir,
        [string] $LogDir,
        [string] $Interface,
        [string] $InstallDir
    )
    $logs = $LogDir -replace '\\', '/'
    $rules = $RulesDir -replace '\\', '/'
    $iface = $Interface
    $ruleFile = 'local.rules'
    @"
%YAML 1.1
---
# CTG Windows Suricata IDS — detect-only (authorized lab use)
run-as:
  user: SYSTEM
  group: SYSTEM
vars:
  address-groups:
    HOME_NET: "[192.168.0.0/16,10.0.0.0/8,172.16.0.0/12]"
    EXTERNAL_NET: "!`$HOME_NET"
  port-groups:
    HTTP_PORTS: "80,8080,8000"
default-log-dir: $logs/
outputs:
  - fast:
      enabled: yes
      filename: fast.log
  - eve-log:
      enabled: yes
      filetype: regular
      filename: eve.json
      types:
        - alert
        - dns
        - flow
pcap:
  - interface: $iface
detect-profile: medium
default-rule-path: $rules
rule-files:
  - $ruleFile
"@
}

function Ensure-CtgSuricataLayout {
    param([object] $Paths)
    foreach ($dir in @($Paths.SuricataRoot, $Paths.EtcDir, $Paths.RulesDir, $Paths.LogsDir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (-not (Test-Path $Paths.LocalRules)) {
        @'
# CTG lab local Suricata rules — authorized lab signatures only (detect-only)
alert icmp any any -> $HOME_NET any (msg:"CTG ICMP test rule"; sid:9000001; rev:1;)
'@ | Set-Content -Path $Paths.LocalRules -Encoding utf8
    }
}

function Parse-CtgSuricataEveJsonLines {
    param([string[]] $Lines)
    $alerts = @()
    foreach ($line in $Lines) {
        $parsed = Parse-CtgSuricataEveLine -Line $line
        if ($parsed) { $alerts += $parsed }
    }
    return $alerts
}
