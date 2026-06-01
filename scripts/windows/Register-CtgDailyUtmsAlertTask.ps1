<#
.SYNOPSIS
  Register HackerPlanet-CTG-Daily-Utms-6AM — hourly check for 6 AM local UTMS alert.

.DESCRIPTION
  Runs Invoke-CtgDailyUtmsAlertIfLocal6Am.ps1 every hour. When iPhone timezone.json
  is present, fires Signal alert once per day at 6:00–6:04 local in that timezone.
  Without iPhone export, uses America/New_York (Eastern — EST/EDT via IANA conversion).

  Interactive logon + Highest — no password in task XML (same as Register-CtgNightlyTask.ps1).

.PARAMETER Unregister
  Remove the scheduled task.

.PARAMETER DiagnoseOnly
  Print planned registration without Admin changes.

.EXAMPLE
  .\scripts\windows\Register-CtgDailyUtmsAlertTask.ps1

.EXAMPLE
  .\scripts\windows\Register-CtgDailyUtmsAlertTask.ps1 -DiagnoseOnly
#>
[CmdletBinding()]
param(
    [string] $TaskName = 'HackerPlanet-CTG-Daily-Utms-6AM',
    [switch] $Unregister,
    [switch] $DiagnoseOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
. (Join-Path $PSScriptRoot 'CTG-IphoneTimezoneCommon.ps1')

$checkerScript = Join-Path $PSScriptRoot 'Invoke-CtgDailyUtmsAlertIfLocal6Am.ps1'
if (-not (Test-Path $checkerScript)) {
    Write-Error "Missing checker script: $checkerScript"
    exit 1
}

$argList = "-NoProfile -ExecutionPolicy Bypass -File `"$checkerScript`" -UseSecretVault"
$defaultTz = Get-CtgDefaultUtmsAlertTimezone

Write-Host ''
Write-Host '=== CTG daily UTMS alert task ===' -ForegroundColor Cyan
Write-Host "Task name: $TaskName"
Write-Host "Checker:   $checkerScript"
Write-Host "Schedule:  Every 1 hour (fires alert at 6:00-6:04 local)"
Write-Host "Timezone:  iPhone timezone.json or fallback $defaultTz"
Write-Host "Channel:   Signal via Send-CtgDailyUtmsAlert.ps1"

if ($DiagnoseOnly) {
    Write-Host ''
    Write-Host 'DiagnoseOnly: registration skipped (Admin not required for preview)' -ForegroundColor Yellow
    Write-Host "Admin register: .\scripts\windows\Register-CtgDailyUtmsAlertTask.ps1"
    exit 0
}

if (-not (Test-CtgIsAdmin)) {
    Write-Error @"
Register-CtgDailyUtmsAlertTask.ps1 requires Administrator.
Run elevated PowerShell:
  cd `"$(Get-CtgRepoRoot -FromPath $PSScriptRoot)`"
  .\scripts\windows\Register-CtgDailyUtmsAlertTask.ps1
"@
    exit 1
}

if ($Unregister) {
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Unregistered: $TaskName"
    } else {
        Write-Host "Task not found: $TaskName"
    }
    exit 0
}

$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument $argList

$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).Date `
    -RepetitionInterval (New-TimeSpan -Hours 1) `
    -RepetitionDuration ([TimeSpan]::MaxValue)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -WakeToRun `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 15) `
    -MultipleInstances IgnoreNew

$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Highest

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Replaced existing task: $TaskName"
}

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description 'CyberThreatGotchi daily UTMS Signal alert at 6 AM local (iPhone tz or Eastern)' | Out-Null

Write-Host ''
Write-Host "Registered scheduled task: $TaskName" -ForegroundColor Green
Write-Host '  Trigger: Every hour (6:00-6:04 local gate inside checker)'
Write-Host "  Script:  $checkerScript"
Write-Host "  Run as:  $env:USERDOMAIN\$env:USERNAME (Interactive, Highest)"
Write-Host '  Signal:  Configure Install-CtgSignalCli.ps1 + vault CTG_PII_PHONE'
Write-Host '  iPhone:  docs/IPHONE_TIMEZONE_SYNC.md'
Get-ScheduledTask -TaskName $TaskName | Format-List TaskName, State, Description
