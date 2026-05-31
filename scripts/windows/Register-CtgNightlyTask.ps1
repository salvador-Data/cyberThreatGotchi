<#
.SYNOPSIS
  Register Windows Scheduled Task HackerPlanet-CTG-Nightly-4AM (daily 4:00 AM local).

.NOTES
  Requires Administrator to register with RunLevel Highest.
#>
[CmdletBinding()]
param(
    [string] $TaskName = 'HackerPlanet-CTG-Nightly-4AM',
    [string] $At = '04:00'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
if (-not (Test-CtgIsAdmin)) {
    Write-Error 'Register-CtgNightlyTask.ps1 requires Administrator. Run ctg_nightly_install.ps1 elevated.'
    exit 1
}

$scriptPath = Join-Path $PSScriptRoot 'ctg_nightly_4am.ps1'
if (-not (Test-Path $scriptPath)) {
    Write-Error "Missing orchestrator: $scriptPath"
    exit 1
}

$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

$trigger = New-ScheduledTaskTrigger -Daily -At $At

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -WakeToRun `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 4)

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
    -Description 'CyberThreatGotchi nightly 4 AM — backup, website, compartmentalized audit autorun, SOC scans' | Out-Null

Write-Host "Registered scheduled task: $TaskName"
Write-Host "  Trigger: Daily at $At (local time)"
Write-Host "  Script:  $scriptPath"
Write-Host "  Run as:  $env:USERDOMAIN\$env:USERNAME (Highest privileges)"
Write-Host "  Wake:    WakeToRun enabled (AC wake when supported)"
Get-ScheduledTask -TaskName $TaskName | Format-List TaskName, State, Description
