<#
.SYNOPSIS
  Register optional scheduled task: SMS reminder to rotate lab passwords (no secrets in message).

.DESCRIPTION
  Sends "CTG: rotate lab passwords" via Send-CtgSmsAlert.ps1 every 120 days.
  Requires Twilio + CTG_ALERT_SMS_TO in local .env only — never commit .env.

.PARAMETER TaskName
  Windows Scheduled Task name.

.PARAMETER IntervalDays
  Days between reminders (default 120, aligned with password max age policy).

.PARAMETER Unregister
  Remove the scheduled task.

.EXAMPLE
  .\Register-CtgSecretRotationReminder.ps1

.EXAMPLE
  .\Register-CtgSecretRotationReminder.ps1 -Unregister
#>
[CmdletBinding()]
param(
    [string] $TaskName = 'HackerPlanet-CTG-Secret-Rotation-Reminder',
    [int] $IntervalDays = 120,
    [switch] $Unregister
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
if (-not (Test-CtgIsAdmin)) {
    Write-Error 'Register-CtgSecretRotationReminder.ps1 requires Administrator.'
    exit 1
}

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($Unregister) {
    if ($existing) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Removed scheduled task: $TaskName"
    } else {
        Write-Host "Task not registered: $TaskName"
    }
    exit 0
}

$runnerPath = Join-Path $PSScriptRoot 'Invoke-CtgSecretRotationSms.ps1'
if (-not (Test-Path $runnerPath)) {
    Write-Error "Missing runner script: $runnerPath"
    exit 1
}

$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$runnerPath`""

$startAt = (Get-Date).Date.AddHours(9)
if ($startAt -lt (Get-Date)) {
    $startAt = $startAt.AddDays(1)
}

$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At $startAt `
    -RepetitionInterval (New-TimeSpan -Days $IntervalDays) `
    -RepetitionDuration ([TimeSpan]::MaxValue)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Limited

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
    -Description 'CTG lab password rotation reminder SMS (no secrets in message)' | Out-Null

Write-Host "Registered scheduled task: $TaskName"
Write-Host "  First run: $($startAt.ToString('yyyy-MM-dd HH:mm')) (local)"
Write-Host "  Interval:  every $IntervalDays days"
Write-Host "  Runner:    $runnerPath"
Write-Host '  SMS body:  CTG: rotate lab passwords (configure CTG_ALERT_SMS_TO in .env)'
Get-ScheduledTask -TaskName $TaskName | Format-List TaskName, State, Description
