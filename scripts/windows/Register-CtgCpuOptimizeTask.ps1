<#
.SYNOPSIS
  Register scheduled task for safe CPU performance optimization (no password in repo).

.DESCRIPTION
  Registers HackerPlanet-CTG-Cpu-Optimize to run Optimize-CpuPerformance.ps1 -ApplySafe
  on a weekly schedule (default Sunday 03:30) or at user logon.

  Uses Interactive logon + RunLevel Highest - runs only when you are logged on;
  Windows stores no password in this script or git. Registration requires Administrator.

  Optional unattended path: use DPAPI vault (Protect-CtgSecrets.ps1) only for other secrets -
  this task does NOT require a stored password when LogonType is Interactive.

.PARAMETER TaskName
  Windows Scheduled Task name.

.PARAMETER Schedule
  Weekly (default) or AtLogon.

.PARAMETER DayOfWeek
  Day for weekly trigger (default Sunday).

.PARAMETER At
  Local time for weekly trigger (default 03:30).

.PARAMETER Unregister
  Remove the scheduled task.

.EXAMPLE
  .\scripts\windows\Register-CtgCpuOptimizeTask.ps1

.EXAMPLE
  .\scripts\windows\Register-CtgCpuOptimizeTask.ps1 -Schedule AtLogon

.EXAMPLE
  .\scripts\windows\Register-CtgCpuOptimizeTask.ps1 -Unregister
#>
[CmdletBinding()]
param(
    [string] $TaskName = 'HackerPlanet-CTG-Cpu-Optimize',
    [ValidateSet('Weekly', 'AtLogon')]
    [string] $Schedule = 'Weekly',
    [ValidateSet('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')]
    [string] $DayOfWeek = 'Sunday',
    [string] $At = '03:30',
    [switch] $Unregister
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
if (-not (Test-CtgIsAdmin)) {
    Write-Error 'Register-CtgCpuOptimizeTask.ps1 requires Administrator. Right-click PowerShell -> Run as administrator.'
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

$scriptPath = Join-Path $PSScriptRoot 'Optimize-CpuPerformance.ps1'
if (-not (Test-Path $scriptPath)) {
    Write-Error "Missing script: $scriptPath"
    exit 1
}

$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -ApplySafe"

if ($Schedule -eq 'AtLogon') {
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
} else {
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DayOfWeek -At $At
}

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 15)

# Interactive + Highest: run only when user logged on; no password embedded in task XML from this script
$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Highest

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
    -Description 'CTG safe CPU power tweaks (Optimize-CpuPerformance -ApplySafe); no secrets in repo' | Out-Null

Write-Host "Registered scheduled task: $TaskName"
Write-Host "  Schedule:  $Schedule $(if ($Schedule -eq 'Weekly') { "$DayOfWeek at $At" } else { '' })"
Write-Host "  Script:    $scriptPath -ApplySafe"
Write-Host "  Run as:    $env:USERDOMAIN\$env:USERNAME (Highest, Interactive - logged-on only)"
Write-Host '  Password:  NOT stored in script or git (Interactive logon when user session active)'
Write-Host "  Log:       $env:USERPROFILE\Backups\logs\optimize-cpu.log"
Get-ScheduledTask -TaskName $TaskName | Format-List TaskName, State, Description
