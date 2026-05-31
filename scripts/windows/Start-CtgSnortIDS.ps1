<#
.SYNOPSIS
  CTG Snort IDS on Windows — detect-only capture, alert tail, rate-limited SMS.

.DESCRIPTION
  Runs Snort 2.9.x in passive IDS mode on selected interface. Logs to Backups\logs\snort\.
  High/critical alerts trigger Send-CtgSmsAlert.ps1 (15 min rate limit per rule SID).
  Snort 3 is Linux-only; use -UseWiresharkFallback when Snort binary unavailable.

.PARAMETER DiagnoseOnly
  Verify Snort, Npcap, config, Twilio env, paths.

.PARAMETER ApplyRules
  Redeploy CTG snort.conf and sync rules from C:\Snort\rules.

.PARAMETER TestAlert
  Send test SMS via Send-CtgSmsAlert.ps1 (no live Snort required).

.PARAMETER Interface
  Npcap interface index (snort -W). Default: auto Wi-Fi/Ethernet.

.PARAMETER RunMinutes
  Minutes to run Snort + alert polling (default 60). Use 0 for single poll cycle.

.PARAMETER NoSms
  Log alerts locally only.

.PARAMETER UseWiresharkFallback
  When Snort missing: delegate to Start-CTGWiresharkIDS.ps1 heuristics.

.EXAMPLE
  .\scripts\windows\Start-CtgSnortIDS.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Start-CtgSnortIDS.ps1 -TestAlert

.EXAMPLE
  .\scripts\windows\Start-CtgSnortIDS.ps1 -ApplyRules -RunMinutes 120 -Interface 3
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [switch] $ApplyRules,
    [switch] $TestAlert,
    [string] $Interface = '',
    [int] $RunMinutes = 60,
    [switch] $NoSms,
    [switch] $UseWiresharkFallback
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
. (Join-Path $PSScriptRoot 'CTG-SnortCommon.ps1')

$repo = Get-CtgRepoRoot
Import-CtgDotEnv -EnvPath (Join-Path $repo '.env')
$paths = Get-CtgSnortPaths
$isAdmin = Test-CtgIsAdmin
$snort = Get-CtgSnortBinary
$iface = Get-CtgSnortInterface -SnortPath $snort -Preferred $Interface
$ifaceName = $iface
$snortProc = $null

function Write-IdsLog {
    param([string] $Message, [string] $Color = 'Gray')
    Write-CtgSnortLog $Message $paths.IdsLog $Color
}

function Get-CtgIfaceLabel {
    param([string] $Idx)
    if (-not $snort) { return "iface$Idx" }
    $list = Get-CtgSnortInterfaceList -SnortPath $snort
    foreach ($item in $list) {
        if ($item.Index -eq $Idx) { return $item.Name }
    }
    return "iface$Idx"
}

function Invoke-CtgSnortDiagnose {
    $ok = $true
    Write-IdsLog '--- Start-CtgSnortIDS DiagnoseOnly ---' 'Cyan'
    $win = Test-CtgWin11Pro
    Write-IdsLog "OS: $($win.Caption) Pro=$($win.IsPro)"
    Write-IdsLog "Admin: $isAdmin"
    Write-IdsLog "Npcap: $(Test-CtgNpcapInstalled)"
    if ($snort) {
        Write-IdsLog "Snort: $snort"
        Write-IdsLog "Interface: $iface ($((Get-CtgIfaceLabel -Idx $iface)))"
    } else {
        Write-IdsLog 'Snort: NOT installed' 'Red'
        Write-IdsLog '  Run Install-CtgSnortWindows.ps1 or use -UseWiresharkFallback' 'Yellow'
        $ok = $false
    }
    Write-IdsLog "Config: $($paths.ConfFile) exists=$(Test-Path $paths.ConfFile)"
    Write-IdsLog "Alert log: $($paths.AlertLog)"
    Write-IdsLog "IDS log: $($paths.IdsLog)"
    $twilioOk = @(
        $env:TWILIO_ACCOUNT_SID, $env:TWILIO_AUTH_TOKEN,
        $env:TWILIO_FROM_NUMBER, $env:CTG_ALERT_SMS_TO
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    Write-IdsLog "Twilio configured: $($twilioOk.Count -eq 4)"
    Write-IdsLog "DiagnoseOnly: $(if ($ok) { 'PASS' } else { 'FAIL' })"
    return $ok
}

function Invoke-CtgApplyRules {
    Ensure-CtgSnortLayout -Paths $paths
    $installDir = 'C:\Snort'
    if ($snort) {
        $installDir = Split-Path (Split-Path $snort -Parent) -Parent
    }
    $conf = New-CtgSnortConfContent -RulesDir $paths.RulesDir -LogDir $paths.LogsDir -SnortInstallDir $installDir
    Set-Content -Path $paths.ConfFile -Value $conf -Encoding utf8
    Write-IdsLog "Applied rules/config -> $($paths.ConfFile)" 'Green'
    $srcRules = Join-Path $installDir 'rules'
    if (Test-Path $srcRules) {
        Get-ChildItem -Path $srcRules -Filter '*.rules' -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination (Join-Path $paths.RulesDir $_.Name) -Force
        }
    }
}

function Invoke-CtgTestSms {
    $smsScript = Join-Path $PSScriptRoot 'Send-CtgSmsAlert.ps1'
    $label = Get-CtgIfaceLabel -Idx $iface
    $msg = "CTG Snort: [info] test sid 9000001 on $label - review log"
    Write-IdsLog "Sending test SMS: $msg" 'Cyan'
    & $smsScript -AlertType 'snort-test' -Severity 'info' -Message $msg -TestMessage
    exit $LASTEXITCODE
}

function Invoke-CtgSnortSms {
    param(
        [object] $Alert,
        [string] $IfaceLabel
    )
    if ($NoSms) { return }
    if ($Alert.Severity -notin @('high', 'critical')) { return }
    $sid = if ($Alert.Sid) { $Alert.Sid } else { 'unknown' }
    $smsScript = Join-Path $PSScriptRoot 'Send-CtgSmsAlert.ps1'
    $msg = "CTG Snort: [$($Alert.Severity)] rule $sid on $IfaceLabel - review log"
    $alertType = "snort-sid-$sid"
    & $smsScript -AlertType $alertType -Severity $Alert.Severity -Message $msg 2>&1 |
        ForEach-Object { Write-IdsLog $_ }
}

function Invoke-CtgProcessNewAlerts {
    param([string] $IfaceLabel)
    $newAlerts = Read-CtgSnortNewAlerts -AlertLog $paths.AlertLog -StatePath $paths.StateFile
    if ($newAlerts.Count -eq 0) { return }
    $allAlerts = @()
    foreach ($alert in $newAlerts) {
        Write-IdsLog "ALERT [$($alert.Severity)] sid=$($alert.Sid) $($alert.Message)" `
            $(if ($alert.Severity -in @('high','critical')) { 'Red' } else { 'Yellow' })
        Invoke-CtgSnortSms -Alert $alert -IfaceLabel $IfaceLabel
        $allAlerts += [ordered]@{
            alert_type = 'snort_alert'
            severity   = $alert.Severity
            summary    = $alert.Message
            src_ip     = $alert.SrcIp
            dst_ip     = $alert.DstIp
            sid        = $alert.Sid
            gid        = $alert.Gid
            source     = 'snort'
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

function Start-CtgSnortDaemon {
    param([string] $IfaceIdx)
    New-Item -ItemType Directory -Path $paths.LogsDir -Force | Out-Null
    if (-not (Test-Path $paths.ConfFile)) {
        Invoke-CtgApplyRules
    }
    $snortArgs = @(
        '-A', 'alert',
        '-i', $IfaceIdx,
        '-c', $paths.ConfFile,
        '-l', $paths.LogsDir
    )
    Write-IdsLog "Starting Snort IDS iface=$IfaceIdx config=$($paths.ConfFile)" 'Cyan'
    $proc = Start-Process -FilePath $snort -ArgumentList $snortArgs -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 3
    if ($proc.HasExited) {
        Write-IdsLog "Snort exited early (code $($proc.ExitCode)) - try -DiagnoseOnly and snort -T" 'Red'
        return $null
    }
    return $proc
}

function Invoke-CtgWiresharkFallback {
    Write-IdsLog 'Snort unavailable - using Wireshark/tshark IDS fallback' 'Yellow'
    $wireScript = Join-Path $PSScriptRoot 'Start-CTGWiresharkIDS.ps1'
    if (-not (Test-Path $wireScript)) {
        Write-IdsLog "Missing fallback script: $wireScript" 'Red'
        exit 1
    }
    $mins = if ($RunMinutes -gt 0) { $RunMinutes } else { 5 }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $wireScript -CaptureMinutes $mins
    exit $LASTEXITCODE
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ' CTG Snort IDS (detect-only lab)' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan

if ($TestAlert) {
    Invoke-CtgTestSms
}

if ($DiagnoseOnly) {
    $result = Invoke-CtgSnortDiagnose
    exit $(if ($result) { 0 } else { 1 })
}

if ($ApplyRules) {
    Invoke-CtgApplyRules
    if (-not $PSBoundParameters.ContainsKey('RunMinutes')) {
        exit 0
    }
}

if (-not $snort) {
    if ($UseWiresharkFallback) {
        Invoke-CtgWiresharkFallback
    }
    Write-IdsLog 'Snort not installed. Run Install-CtgSnortWindows.ps1 or pass -UseWiresharkFallback' 'Red'
    exit 1
}

if (-not $isAdmin) {
    Write-IdsLog 'WARN: Snort packet capture typically requires Administrator' 'Yellow'
}

$ifaceLabel = Get-CtgIfaceLabel -Idx $iface
Write-IdsLog "Computer=$env:COMPUTERNAME iface=$iface ($ifaceLabel)"

$snortProc = Start-CtgSnortDaemon -IfaceIdx $iface
if (-not $snortProc) {
    exit 1
}

$pollSec = 30
$deadline = if ($RunMinutes -gt 0) { (Get-Date).AddMinutes($RunMinutes) } else { (Get-Date).AddSeconds($pollSec) }

try {
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds $pollSec
        if ($snortProc.HasExited) {
            Write-IdsLog "Snort process ended (exit $($snortProc.ExitCode))" 'Yellow'
            break
        }
        Invoke-CtgProcessNewAlerts -IfaceLabel $ifaceLabel
    }
    Invoke-CtgProcessNewAlerts -IfaceLabel $ifaceLabel
} finally {
    if ($snortProc -and -not $snortProc.HasExited) {
        try { Stop-Process -Id $snortProc.Id -Force -ErrorAction SilentlyContinue } catch { }
        Write-IdsLog 'Snort IDS stopped' 'Green'
    }
}

Write-IdsLog 'Snort IDS cycle complete' 'Green'
