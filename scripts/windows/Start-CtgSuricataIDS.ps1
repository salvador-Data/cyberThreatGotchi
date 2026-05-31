<#
.SYNOPSIS
  CTG Suricata IDS on Windows — detect-only capture, EVE tail, rate-limited SMS.

.DESCRIPTION
  Runs Suricata in passive IDS mode on selected Npcap interface. Logs EVE JSON to Backups\logs\suricata\.
  High/critical alerts trigger Send-CtgIdsAlert.ps1 (Signal preferred; Twilio fallback).
  Rate limit: one alert per rule SID per 15 minutes.
  Optional -BlockRepeatOffender adds netsh firewall block for external repeat sources (lab only).

.PARAMETER DiagnoseOnly
  Verify Suricata, Npcap, config, Signal/Twilio env, paths.

.PARAMETER ApplyRules
  Redeploy CTG suricata.yaml and sync rules from Program Files install.

.PARAMETER TestAlert
  Send test alert via Send-CtgIdsAlert.ps1 (Signal preferred; no live Suricata required).

.PARAMETER Interface
  Npcap interface name (e.g. Wi-Fi, Ethernet). Default: auto.

.PARAMETER RunMinutes
  Minutes to run Suricata + alert polling (default 60). Use 0 for single poll cycle.

.PARAMETER NoSms
  Log alerts locally only.

.PARAMETER BlockRepeatOffender
  After high/critical alert from external IP, add netsh inbound block (non-RFC1918 only).

.PARAMETER UseKaliBridge
  Delegate to Start-CtgKaliSuricataSmsBridge.ps1 (Kali Suricata-primary EVE on share).

.EXAMPLE
  .\scripts\windows\Start-CtgSuricataIDS.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Start-CtgSuricataIDS.ps1 -TestAlert

.EXAMPLE
  .\scripts\windows\Start-CtgSuricataIDS.ps1 -ApplyRules -RunMinutes 120 -Interface Wi-Fi
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [switch] $ApplyRules,
    [switch] $TestAlert,
    [string] $Interface = '',
    [int] $RunMinutes = 60,
    [switch] $NoSms,
    [switch] $UseSignal,
    [switch] $UseTwilio,
    [switch] $BlockRepeatOffender,
    [switch] $UseKaliBridge
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
. (Join-Path $PSScriptRoot 'CTG-SuricataCommon.ps1')
. (Join-Path $PSScriptRoot 'CTG-SignalCommon.ps1')

$repo = Get-CtgRepoRoot
Import-CtgDotEnv -EnvPath (Join-Path $repo '.env')
$paths = Get-CtgSuricataPaths
$isAdmin = Test-CtgIsAdmin
$suricata = Test-CtgSuricataInstalled
$iface = Get-CtgSuricataInterface -Preferred $Interface
$suricataProc = $null

function Write-IdsLog {
    param([string] $Message, [string] $Color = 'Gray')
    Write-CtgSuricataLog $Message $paths.IdsLog $Color
}

function Invoke-CtgSuricataDiagnose {
    $ok = $true
    Write-IdsLog '--- Start-CtgSuricataIDS DiagnoseOnly ---' 'Cyan'
    $win = Test-CtgWin11Pro
    Write-IdsLog "OS: $($win.Caption) Pro=$($win.IsPro)"
    Write-IdsLog "Admin: $isAdmin"
    Write-IdsLog "Npcap: $(Test-CtgNpcapInstalled)"
    if ($suricata) {
        Write-IdsLog "Suricata: $suricata"
        Write-IdsLog "Interface: $iface"
    } else {
        Write-IdsLog 'Suricata: NOT installed' 'Red'
        Write-IdsLog '  Run Install-CtgSuricataWindows.ps1 or -UseKaliBridge' 'Yellow'
        $ok = $false
    }
    Write-IdsLog "Config: $($paths.YamlFile) exists=$(Test-Path $paths.YamlFile)"
    Write-IdsLog "EVE log: $($paths.EveLog)"
    Write-IdsLog "IDS log: $($paths.IdsLog)"
    Write-IdsLog "Signal configured: $(Test-CtgSignalConfigured)"
    $twilioOk = @(
        $env:TWILIO_ACCOUNT_SID, $env:TWILIO_AUTH_TOKEN,
        $env:TWILIO_FROM_NUMBER, $env:CTG_ALERT_SMS_TO
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    Write-IdsLog "Twilio configured: $($twilioOk.Count -eq 4)"
    Write-IdsLog "Alert channel: $(if (Test-CtgUseTwilioPreferred) { 'Twilio (CTG_USE_TWILIO=1)' } elseif (Test-CtgSignalConfigured) { 'Signal (default)' } else { 'Twilio fallback if set' })"
    Write-IdsLog "DiagnoseOnly: $(if ($ok) { 'PASS' } else { 'FAIL' })"
    return $ok
}

function Invoke-CtgApplyRules {
    Ensure-CtgSuricataLayout -Paths $paths
    $installDir = Get-CtgSuricataInstallDir -SuricataPath $suricata
    $conf = New-CtgSuricataYamlContent -RulesDir $paths.RulesDir -LogDir $paths.LogsDir -Interface $iface -InstallDir $installDir
    Set-Content -Path $paths.YamlFile -Value $conf -Encoding utf8
    Write-IdsLog "Applied config -> $($paths.YamlFile)" 'Green'
    $srcRules = Join-Path $installDir 'rules'
    if (Test-Path $srcRules) {
        Get-ChildItem -Path $srcRules -Filter '*.rules' -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination (Join-Path $paths.RulesDir $_.Name) -Force
        }
    }
}

function Invoke-CtgTestAlert {
    $alertScript = Join-Path $PSScriptRoot 'Send-CtgIdsAlert.ps1'
    $msg = 'CTG Suricata: [info] sid 9000001 - review log'
    Write-IdsLog "Sending test alert: $msg" 'Cyan'
    $args = @{
        AlertType   = 'suricata-test'
        Severity    = 'info'
        Message     = $msg
        TestMessage = $true
    }
    if ($UseSignal) { $args['UseSignal'] = $true }
    if ($UseTwilio) { $args['UseTwilio'] = $true }
    & $alertScript @args
    exit $LASTEXITCODE
}

function Invoke-CtgSuricataAlert {
    param(
        [object] $Alert,
        [string] $IfaceLabel
    )
    if ($NoSms) { return }
    if ($Alert.Severity -notin @('high', 'critical')) { return }
    $sid = if ($Alert.Sid) { $Alert.Sid } else { 'unknown' }
    $alertScript = Join-Path $PSScriptRoot 'Send-CtgIdsAlert.ps1'
    $msg = "CTG Suricata: [$($Alert.Severity)] sid $sid - review log"
    $alertType = "suricata-sid-$sid"
    $args = @{
        AlertType = $alertType
        Severity  = $Alert.Severity
        Message   = $msg
    }
    if ($UseSignal) { $args['UseSignal'] = $true }
    if ($UseTwilio) { $args['UseTwilio'] = $true }
    & $alertScript @args 2>&1 | ForEach-Object { Write-IdsLog $_ }
}

function Invoke-CtgProcessNewAlerts {
    param([string] $IfaceLabel)
    $newAlerts = Read-CtgSuricataNewAlerts -EveLog $paths.EveLog -StatePath $paths.StateFile
    if ($newAlerts.Count -eq 0) { return }
    $allAlerts = @()
    foreach ($alert in $newAlerts) {
        Write-IdsLog "ALERT [$($alert.Severity)] sid=$($alert.Sid) $($alert.Message)" `
            $(if ($alert.Severity -in @('high','critical')) { 'Red' } else { 'Yellow' })
        Invoke-CtgSuricataAlert -Alert $alert -IfaceLabel $IfaceLabel
        if ($BlockRepeatOffender -and $alert.Severity -in @('high', 'critical') -and $alert.SrcIp) {
            Invoke-CtgBlockRepeatOffender -RemoteIp $alert.SrcIp -LogFile $paths.IdsLog | Out-Null
        }
        $allAlerts += [ordered]@{
            alert_type = 'suricata_alert'
            severity   = $alert.Severity
            summary    = $alert.Message
            src_ip     = $alert.SrcIp
            dst_ip     = $alert.DstIp
            sid        = $alert.Sid
            action     = $alert.Action
            source     = 'suricata'
        }
    }
    if ($allAlerts.Count -gt 0) {
        $existing = @()
        if (Test-Path $paths.AlertsJson) {
            try {
                $raw = Get-Content $paths.AlertsJson -Raw -Encoding utf8 | ConvertFrom-Json
                if ($raw -is [System.Array]) { $existing = @($raw) }
                elseif ($raw) { $existing = @($raw) }
            } catch { }
        }
        $merged = $existing + $allAlerts
        if ($merged.Count -gt 500) {
            $merged = $merged[-500..-1]
        }
        $merged | ConvertTo-Json -Depth 5 | Set-Content -Path $paths.AlertsJson -Encoding utf8
    }
}

function Start-CtgSuricataDaemon {
    param([string] $IfaceName)
    New-Item -ItemType Directory -Path $paths.LogsDir -Force | Out-Null
    if (-not (Test-Path $paths.YamlFile)) {
        Invoke-CtgApplyRules
    }
    $suricataArgs = @(
        '-c', $paths.YamlFile,
        '-i', $IfaceName
    )
    Write-IdsLog "Starting Suricata IDS iface=$IfaceName config=$($paths.YamlFile)" 'Cyan'
    $proc = Start-Process -FilePath $suricata -ArgumentList $suricataArgs -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 4
    if ($proc.HasExited) {
        Write-IdsLog "Suricata exited early (code $($proc.ExitCode)) - try -DiagnoseOnly and suricata -T" 'Red'
        return $null
    }
    return $proc
}

function Invoke-CtgKaliBridge {
    Write-IdsLog 'Suricata unavailable on Windows — using Kali EVE SMS bridge' 'Yellow'
    $bridgeScript = Join-Path $PSScriptRoot 'Start-CtgKaliSuricataSmsBridge.ps1'
    if (-not (Test-Path $bridgeScript)) {
        Write-IdsLog "Missing bridge script: $bridgeScript" 'Red'
        exit 1
    }
    $mins = if ($RunMinutes -gt 0) { $RunMinutes } else { 5 }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $bridgeScript -RunMinutes $mins
    exit $LASTEXITCODE
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ' CTG Suricata IDS (detect-only lab)' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan

if ($TestAlert) {
    Invoke-CtgTestAlert
}

if ($DiagnoseOnly) {
    $result = Invoke-CtgSuricataDiagnose
    exit $(if ($result) { 0 } else { 1 })
}

if ($ApplyRules) {
    Invoke-CtgApplyRules
    if (-not $PSBoundParameters.ContainsKey('RunMinutes')) {
        exit 0
    }
}

if (-not $suricata) {
    if ($UseKaliBridge) {
        Invoke-CtgKaliBridge
    }
    Write-IdsLog 'Suricata not installed. Run Install-CtgSuricataWindows.ps1 or pass -UseKaliBridge' 'Red'
    exit 1
}

if (-not $isAdmin) {
    Write-IdsLog 'WARN: Suricata packet capture typically requires Administrator' 'Yellow'
}

Write-IdsLog "Computer=$env:COMPUTERNAME iface=$iface"

$suricataProc = Start-CtgSuricataDaemon -IfaceName $iface
if (-not $suricataProc) {
    exit 1
}

$pollSec = 30
$deadline = if ($RunMinutes -gt 0) { (Get-Date).AddMinutes($RunMinutes) } else { (Get-Date).AddSeconds($pollSec) }

try {
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds $pollSec
        if ($suricataProc.HasExited) {
            Write-IdsLog "Suricata process ended (exit $($suricataProc.ExitCode))" 'Yellow'
            break
        }
        Invoke-CtgProcessNewAlerts -IfaceLabel $iface
    }
    Invoke-CtgProcessNewAlerts -IfaceLabel $iface
} finally {
    if ($suricataProc -and -not $suricataProc.HasExited) {
        try { Stop-Process -Id $suricataProc.Id -Force -ErrorAction SilentlyContinue } catch { }
        Write-IdsLog 'Suricata IDS stopped' 'Green'
    }
}

Write-IdsLog 'Suricata IDS cycle complete' 'Green'
