<#
.SYNOPSIS
  Hourly gate: send daily UTMS alert when local time is 6:00–6:04 AM in iPhone tz.

.DESCRIPTION
  Registered by Register-CtgDailyUtmsAlertTask.ps1 (runs every hour).
  Reads Backups\iphone-location\timezone.json when present; otherwise America/New_York.
  Sends at most once per local calendar day per timezone (state file).

.PARAMETER DiagnoseOnly
  Report window, timezone source, and whether alert would fire now.

.PARAMETER Force
  Bypass 6 AM window (still respects once-per-day unless -Force with test type).

.EXAMPLE
  .\scripts\windows\Invoke-CtgDailyUtmsAlertIfLocal6Am.ps1 -DiagnoseOnly
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [switch] $Force,
    [switch] $UseSecretVault
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'CTG-IphoneTimezoneCommon.ps1')

$logDir = Join-Path $env:USERPROFILE 'Backups\logs'
$logFile = Join-Path $logDir 'ctg-daily-utms-hourly.log'
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-HourlyLog([string] $Text) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Text"
    Add-Content -Path $logFile -Value $line -Encoding utf8 -ErrorAction SilentlyContinue
    Write-Host $line
}

$data = Read-CtgIphoneTimezoneJson -AllowAlias
$tzId = if ($data -and $data.Valid) { $data.Timezone } else { Get-CtgDefaultUtmsAlertTimezone }
$source = if ($data -and $data.Valid) { 'iphone-export' } else { 'default-eastern' }

try {
    $local = Get-CtgLocalTimeInTimezone -TimezoneId $tzId
} catch {
    Write-HourlyLog "Timezone error ($tzId): $($_.Exception.Message)"
    exit 2
}

$inWindow = Test-CtgIsLocalSixAmWindow -TimezoneId $tzId
$alreadySent = Get-CtgDailyUtmsAlertSentToday -TimezoneId $tzId
$wouldSend = ($Force -or $inWindow) -and -not $alreadySent

Write-HourlyLog "tz=$tzId source=$source local=$($local.ToString('HH:mm')) window=$inWindow sent_today=$alreadySent would_send=$wouldSend"

if ($DiagnoseOnly) {
    Write-Host ''
    Write-Host '=== CTG daily UTMS hourly gate (DiagnoseOnly) ===' -ForegroundColor Cyan
    Write-Host "Timezone: $tzId ($source)"
    Write-Host "Local time: $($local.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Host "6 AM window (6:00-6:04): $inWindow"
    Write-Host "Already sent today: $alreadySent"
    Write-Host "Would send now: $wouldSend"
    Write-Host "Log: $logFile"
    exit 0
}

if (-not $wouldSend) {
    exit 0
}

$sendScript = Join-Path $PSScriptRoot 'Send-CtgDailyUtmsAlert.ps1'
$splat = @{ SkipTimezoneUpdate = $true }
if ($UseSecretVault) { $splat['UseSecretVault'] = $true }

& $sendScript @splat
exit $LASTEXITCODE
