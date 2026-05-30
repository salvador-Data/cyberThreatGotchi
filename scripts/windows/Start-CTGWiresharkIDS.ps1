<#
.SYNOPSIS
  CTG Wireshark IDS - ring-buffer capture, tshark/Snort/CTG analysis, optional IPS blocks.

.DESCRIPTION
  Authorized defensive home/lab monitoring only. Requires Wireshark/Npcap (Install-WiresharkNpcap.ps1).
  Windows Wireshark is IDS-oriented - full inline IPS belongs on OPNsense Suricata (see docs).
  Logs: wireshark-ids.log, wireshark-alerts.json under Backups/logs.

.PARAMETER DiagnoseOnly
  Verify tshark, interface, paths, Snort, Python analyzer - no capture.

.PARAMETER CaptureMinutes
  Capture duration (default 5). Use 0 with loop script for continuous service.

.PARAMETER Interface
  tshark interface index or name (default: auto-select active NIC).

.PARAMETER BlockRepeatOffenders
  Admin: netsh inbound block for high-severity repeat offender IPs (optional, lab only).

.PARAMETER NoSms
  Skip SMS even on high-severity alerts.

.EXAMPLE
  .\scripts\windows\Start-CTGWiresharkIDS.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Start-CTGWiresharkIDS.ps1 -CaptureMinutes 10 -Interface 5
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [int] $CaptureMinutes = 5,
    [string] $Interface = '',
    [switch] $BlockRepeatOffenders,
    [switch] $NoSms
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
. (Join-Path $PSScriptRoot 'CTG-WiresharkCommon.ps1')

$script:CtgIsAdmin = Test-CtgIsAdmin
$repo = Get-CtgRepoRoot
Import-CtgDotEnv -EnvPath (Join-Path $repo '.env')
$paths = Get-CtgWiresharkPaths
$tshark = Get-CtgTsharkPath
$iface = Get-CtgCaptureInterface -TsharkPath $tshark -Preferred $Interface
$py = Get-CtgPythonForIds
$analyzer = Join-Path $repo 'scripts\wireshark_ids\analyze_traffic.py'
$snort = Test-CtgSnortInstalled
$offenderCounts = @{}

function Write-IdsLog {
    param([string] $Message, [string] $Color = 'Gray')
    Write-CtgWiresharkLog -Message $Message -LogFile $paths.IdsLog -Color $Color
}

function Show-Banner {
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ' CTG Wireshark IDS (defensive lab only)' -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
    Write-IdsLog "Computer=$env:COMPUTERNAME User=$env:USERNAME Admin=$script:CtgIsAdmin"
}

function Invoke-CtgDiagnose {
    $ok = $true
    Write-IdsLog '--- DiagnoseOnly ---' 'Cyan'
    if (-not $tshark) {
        Write-IdsLog 'MISSING: tshark - run Install-WiresharkNpcap.ps1' 'Red'
        $ok = $false
    } else {
        Write-IdsLog "tshark: $tshark"
        $ver = Get-CtgWiresharkVersion -TsharkPath $tshark
        if ($ver) { Write-IdsLog "version: $ver" }
    }
    Write-IdsLog "interface: $iface"
    Write-IdsLog "pcap: $($paths.PcapFile)"
    Write-IdsLog "log: $($paths.IdsLog)"
    Write-IdsLog "alerts: $($paths.AlertsJson)"
    if ($snort) {
        Write-IdsLog "Snort: $snort (optional parallel IDS)"
    } else {
        Write-IdsLog 'Snort: not installed - using tshark + CTG signature scan only'
    }
    if (Test-Path $analyzer) {
        Write-IdsLog "analyzer: $analyzer"
    } else {
        Write-IdsLog "MISSING: $analyzer" 'Red'
        $ok = $false
    }
    $twilioOk = @(
        $env:TWILIO_ACCOUNT_SID,
        $env:TWILIO_AUTH_TOKEN,
        $env:TWILIO_FROM_NUMBER,
        $env:CTG_ALERT_SMS_TO
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($twilioOk.Count -eq 4) {
        Write-IdsLog 'Twilio SMS: env configured (use Send-CtgSmsAlert.ps1 -TestMessage to verify)'
    } else {
        Write-IdsLog 'Twilio SMS: not fully configured - alerts log locally only'
    }
    if ($BlockRepeatOffenders -and -not $script:CtgIsAdmin) {
        Write-IdsLog '-BlockRepeatOffenders requires Administrator' 'Yellow'
    }
    Write-IdsLog "DiagnoseOnly result: $(if ($ok) { 'PASS' } else { 'FAIL' })"
    return $ok
}

function Export-CtgTsharkSummary {
    param([string] $PcapPath)
    if (-not $tshark -or -not (Test-Path $PcapPath)) { return $false }
    $fieldList = @(
        'frame.time_epoch', 'ip.src', 'ip.dst',
        'tcp.srcport', 'tcp.dstport', 'udp.srcport', 'udp.dstport',
        '_ws.col.Protocol', 'frame.len', 'tcp.flags',
        'dns.qry.name', 'arp.src.proto_ipv4', 'arp.src.hw_mac', 'data.text'
    )
    try {
        $tArgs = @('-r', $PcapPath, '-T', 'fields', '-E', 'separator=	', '-E', 'quote=d')
        foreach ($f in $fieldList) { $tArgs += @('-e', $f) }
        & $tshark @tArgs 2>$null | Set-Content -Path $paths.ExportCsv -Encoding utf8
        return $true
    } catch {
        Write-IdsLog "tshark export failed: $($_.Exception.Message)" 'Yellow'
        return $false
    }
}

function Invoke-CtgTrafficAnalysis {
    $args = @(
        $analyzer,
        '--csv', $paths.ExportCsv,
        '--json-out', $paths.AlertsJson
    )
    $snortLog = 'C:\Snort\log\alert'
    if (-not (Test-Path $snortLog)) {
        $snortLog = Join-Path $env:ProgramFiles 'Snort\log\alert'
    }
    if (Test-Path $snortLog) {
        $args += @('--snort-log', $snortLog)
    }
    try {
        & $py @args 2>&1 | ForEach-Object { Write-IdsLog "analyzer: $_" }
        return Read-CtgAlertsJson -Path $paths.AlertsJson
    } catch {
        Write-IdsLog "analyzer error: $($_.Exception.Message)" 'Red'
        return @()
    }
}

function Invoke-CtgAlertActions {
    param([array] $Alerts)
    if (-not $Alerts -or $Alerts.Count -eq 0) {
        Write-IdsLog 'No alerts this cycle'
        return
    }
    foreach ($alert in $Alerts) {
        $type = $alert.alert_type
        $sev = $alert.severity
        $summary = $alert.summary
        $src = $alert.src_ip
        Write-IdsLog "ALERT [$sev] $type - $summary" $(if ($sev -in @('high','critical')) { 'Red' } else { 'Yellow' })
        if ($sev -in @('high', 'critical')) {
            $snippet = Save-CtgPcapSnippet -TsharkPath $tshark -SourcePcap $paths.PcapFile -SnippetsDir $paths.SnippetsDir -AlertType $type -SrcIp $src
            if ($snippet) {
                Write-IdsLog "pcap snippet: $snippet"
            }
            if (-not $NoSms) {
                $smsScript = Join-Path $PSScriptRoot 'Send-CtgSmsAlert.ps1'
                $smsMsg = "$summary (host $env:COMPUTERNAME)"
                & $smsScript -AlertType $type -Severity $sev -Message $smsMsg 2>&1 | ForEach-Object { Write-IdsLog $_ }
            }
            if ($BlockRepeatOffenders -and $script:CtgIsAdmin -and $src) {
                if (-not $offenderCounts.ContainsKey($src)) { $offenderCounts[$src] = 0 }
                $offenderCounts[$src]++
                if ($offenderCounts[$src] -ge 2) {
                    Invoke-CtgBlockRepeatOffender -RemoteIp $src -LogFile $paths.IdsLog | Out-Null
                }
            }
        }
    }
}

function Start-CtgRingBufferCapture {
    param([int] $Minutes)
    New-Item -ItemType Directory -Path $paths.PcapDir -Force | Out-Null
    New-Item -ItemType Directory -Path $paths.LogsDir -Force | Out-Null
    $durationSec = [Math]::Max(60, $Minutes * 60)
    $args = @(
        '-i', $iface,
        '-w', $paths.PcapFile,
        '-b', 'filesize:52428800',
        '-b', 'files:48',
        '-b', "duration:$durationSec",
        '-q'
    )
    Write-IdsLog "Starting tshark ring capture iface=$iface duration=${Minutes}m -> $($paths.PcapFile)" 'Cyan'
    $proc = Start-Process -FilePath $tshark -ArgumentList $args -PassThru -WindowStyle Hidden
    return $proc
}

Show-Banner

if ($DiagnoseOnly) {
    $result = Invoke-CtgDiagnose
    exit $(if ($result) { 0 } else { 1 })
}

if (-not $tshark) {
    Write-IdsLog 'tshark not found - run Install-WiresharkNpcap.ps1 first' 'Red'
    exit 1
}

if (-not (Test-Path $analyzer)) {
    Write-IdsLog "Missing analyzer: $analyzer" 'Red'
    exit 1
}

$captureProc = Start-CtgRingBufferCapture -Minutes $CaptureMinutes
$deadline = (Get-Date).AddMinutes($CaptureMinutes)
$cycleSec = 60

try {
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds $cycleSec
        if ($captureProc.HasExited) {
            Write-IdsLog 'tshark capture ended early' 'Yellow'
            break
        }
        if (Test-Path $paths.PcapFile) {
            Export-CtgTsharkSummary -PcapPath $paths.PcapFile | Out-Null
            $alerts = Invoke-CtgTrafficAnalysis
            Invoke-CtgAlertActions -Alerts $alerts
        }
    }
} finally {
    if (-not $captureProc.HasExited) {
        try { Stop-Process -Id $captureProc.Id -Force -ErrorAction SilentlyContinue } catch { }
    }
    if (Test-Path $paths.PcapFile) {
        Export-CtgTsharkSummary -PcapPath $paths.PcapFile | Out-Null
        $finalAlerts = Invoke-CtgTrafficAnalysis
        Invoke-CtgAlertActions -Alerts $finalAlerts
    }
    Write-IdsLog 'Capture cycle complete' 'Green'
}
