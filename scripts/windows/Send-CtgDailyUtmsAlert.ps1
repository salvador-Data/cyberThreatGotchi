<#
.SYNOPSIS
  Send daily UTMS/CTG status summary via Signal (IDS, Gatekeeper, lab maturity).

.DESCRIPTION
  Builds a short defensive lab status one-liner and sends via Send-CtgIdsAlert.ps1
  (Signal preferred). No secrets or PII in message body.

.PARAMETER WhatIf
  Print message without sending.

.PARAMETER DiagnoseOnly
  Report channel readiness and sample message; no send.

.PARAMETER SkipTimezoneUpdate
  Do not call Update-CtgTimezoneFromIphone.ps1 first.

.PARAMETER UseSecretVault
  Read Signal destination from DPAPI vault.

.EXAMPLE
  .\scripts\windows\Send-CtgDailyUtmsAlert.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Send-CtgDailyUtmsAlert.ps1 -WhatIf
#>
[CmdletBinding()]
param(
    [switch] $WhatIf,
    [switch] $DiagnoseOnly,
    [switch] $SkipTimezoneUpdate,
    [switch] $UseSecretVault
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'CTG-Paths.ps1')
. (Join-Path $PSScriptRoot 'CTG-SignalCommon.ps1')
. (Join-Path $PSScriptRoot 'CTG-WiresharkCommon.ps1')
. (Join-Path $PSScriptRoot 'CTG-SuricataCommon.ps1')
. (Join-Path $PSScriptRoot 'CTG-IphoneTimezoneCommon.ps1')

$repo = Get-CtgRepoRoot
Import-CtgDotEnv -EnvPath (Join-Path $repo '.env')

$logDir = Join-Path $env:USERPROFILE 'Backups\logs'
$logFile = Join-Path $logDir 'ctg-daily-utms-alert.log'
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-DailyLog([string] $Text) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Text"
    Add-Content -Path $logFile -Value $line -Encoding utf8 -ErrorAction SilentlyContinue
    Write-Host $line
}

function Get-CtgGatekeeperModeLine {
    $stateFile = Join-Path $env:USERPROFILE 'Backups\gatekeeper-tor\state.json'
    if (-not (Test-Path $stateFile)) { return 'GK:unknown' }
    try {
        $st = Get-Content -Path $stateFile -Raw -Encoding utf8 | ConvertFrom-Json
        $mode = [string]$st.mode
        if ($mode -match '^(tor|https)$') { return "GK:$mode" }
    } catch { }
    return 'GK:unknown'
}

function Get-CtgIdsStatusLine {
    $parts = @()
    $snort = Test-CtgSnortInstalled
    if ($snort) { $parts += 'Snort:ready' } else { $parts += 'Snort:off' }
    $suricata = Test-CtgSuricataInstalled
    if ($suricata) { $parts += 'Suricata:ready' } else { $parts += 'Suricata:off' }
    $signalOk = Test-CtgSignalConfigured
    if ($signalOk) { $parts += 'Signal:ok' } else { $parts += 'Signal:setup' }
    return ($parts -join ' ')
}

function Get-CtgLabMaturityPing {
    $vaultFile = Join-Path $env:USERPROFILE 'Backups\.vault\credentials.vault'
    $clickMe = Join-Path $env:USERPROFILE 'Backups\CLICK-ME-RUN-IN-KALI.sh'
    $score = 0
    if (Test-Path $vaultFile) { $score++ }
    if (Test-Path $clickMe) { $score++ }
    $fw = Get-NetFirewallProfile -Name 'Private' -ErrorAction SilentlyContinue
    if ($fw -and $fw.Enabled) { $score++ }
    $mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($mp -and $mp.RealTimeProtectionEnabled) { $score++ }
    return "Lab:target8-9 checks=$score/4"
}

function Build-CtgDailyUtmsMessage {
    $tzInfo = Read-CtgIphoneTimezoneJson -AllowAlias
    $tzLine = if ($tzInfo -and $tzInfo.Valid) {
        "tz=$($tzInfo.Timezone)"
    } else {
        $defTz = Get-CtgDefaultUtmsAlertTimezone
        "tz=$defTz (default)"
    }
    $ids = Get-CtgIdsStatusLine
    $gk = Get-CtgGatekeeperModeLine
    $lab = Get-CtgLabMaturityPing
    return "CTG UTMS daily | $tzLine | $ids | $gk | $lab | Hacker Planet LLC"
}

if (-not $SkipTimezoneUpdate) {
    $tzScript = Join-Path $PSScriptRoot 'Update-CtgTimezoneFromIphone.ps1'
    if (Test-Path $tzScript) {
        & $tzScript -Quiet 2>&1 | Out-Null
    }
}

$message = Build-CtgDailyUtmsMessage
$signalReady = Test-CtgSignalConfigured

Write-DailyLog "Message: $message"
Write-DailyLog "Signal ready: $signalReady"

if ($DiagnoseOnly) {
    Write-Host ''
    Write-Host '=== CTG daily UTMS alert (DiagnoseOnly) ===' -ForegroundColor Cyan
    Write-Host "Sample message: $message"
    Write-Host "Signal configured: $signalReady"
    Write-Host "Log: $logFile"
    if (-not $signalReady) {
        Write-Host ''
        Write-Host 'Signal setup: .\scripts\windows\Install-CtgSignalCli.ps1' -ForegroundColor Yellow
        Write-Host 'Vault phone: .\scripts\windows\Protect-CtgSecrets.ps1 -SetPii -Name CTG_PII_PHONE' -ForegroundColor Yellow
    }
    exit $(if ($signalReady) { 0 } else { 1 })
}

if ($WhatIf) {
    Write-DailyLog 'WhatIf: would send daily UTMS alert'
    Write-Host $message
    exit 0
}

if (-not $signalReady) {
    Write-DailyLog 'Skipped: Signal not configured (run Install-CtgSignalCli.ps1 -DiagnoseOnly)'
    exit 2
}

$idsScript = Join-Path $PSScriptRoot 'Send-CtgIdsAlert.ps1'
$splat = @{
    AlertType = 'daily-utms'
    Message   = $message
    UseSignal = $true
}
if ($UseSecretVault) { $splat['UseSecretVault'] = $true }

& $idsScript @splat
$code = $LASTEXITCODE
if ($code -eq 0) {
    $tzData = Read-CtgIphoneTimezoneJson -AllowAlias
    $tzId = if ($tzData -and $tzData.Valid) { $tzData.Timezone } else { Get-CtgDefaultUtmsAlertTimezone }
    Set-CtgDailyUtmsAlertSentToday -TimezoneId $tzId
    Write-DailyLog 'Daily UTMS alert sent'
} else {
    Write-DailyLog "Send failed exit=$code"
}
exit $code
