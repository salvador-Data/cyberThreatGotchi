<#
.SYNOPSIS
  Register quarterly CTG restore drill scheduled task.

.DESCRIPTION
  Runs Invoke-CtgRestoreDrill.ps1 -ReportOnly on first Sunday of each quarter (Jan/Apr/Jul/Oct 04:00).
  Interactive logon + Highest — no password in repo.

.PARAMETER Unregister
  Remove scheduled task.

.EXAMPLE
  .\scripts\windows\Register-CtgRestoreDrillTask.ps1
#>
[CmdletBinding()]
param(
    [string] $TaskName = 'HackerPlanet-CTG-Restore-Drill',
    [switch] $Unregister
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')

if (-not (Test-CtgIsAdmin)) {
    Write-Error 'Register-CtgRestoreDrillTask.ps1 requires Administrator.'
    exit 1
}

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($Unregister) {
    if ($existing) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Removed: $TaskName"
    } else {
        Write-Host "Task not registered: $TaskName"
    }
    exit 0
}

$scriptPath = Join-Path $PSScriptRoot 'Invoke-CtgRestoreDrill.ps1'
$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -ReportOnly"

# Quarterly: Jan, Apr, Jul, Oct — first Sunday 04:00 (approximate via monthly + week 1)
$triggers = @(
    (New-ScheduledTaskTrigger -Weekly -WeeksInterval 13 -DaysOfWeek Sunday -At '04:00')
)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Highest

if ($existing) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $triggers `
    -Settings $settings `
    -Principal $principal `
    -Description 'CTG quarterly restore drill — BitLocker + backup path age report' | Out-Null

Write-Host "Registered: $TaskName (quarterly Sunday 04:00, -ReportOnly)"
Write-Host "Log: $env:USERPROFILE\Backups\logs\restore-drill-YYYYMMDD.log"
