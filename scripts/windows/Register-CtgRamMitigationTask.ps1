<#
.SYNOPSIS
  Register scheduled task for CTG RAM mitigation monitor (host enforcer — not network IPS).

.DESCRIPTION
  Registers HackerPlanet-CTG-Ram-Mitigation to run Enforce-CtgRamMitigations.ps1 -Monitor
  on a weekly schedule (default Monday 04:15) or at user logon.

  Uses Interactive logon + RunLevel Highest — no password stored in script or git.
  Registration requires Administrator.

  Alerts use Send-CtgIdsAlert (Signal preferred) when vulnerable posture is detected.

.PARAMETER TaskName
  Windows Scheduled Task name.

.PARAMETER Schedule
  Weekly (default) or AtLogon.

.PARAMETER DayOfWeek
  Day for weekly trigger (default Monday).

.PARAMETER At
  Local time for weekly trigger (default 04:15).

.PARAMETER UseSecretVault
  Pass -UseSecretVault to Enforce-CtgRamMitigations -Monitor (Signal from DPAPI vault).

.PARAMETER Unregister
  Remove the scheduled task.

.EXAMPLE
  .\scripts\windows\Register-CtgRamMitigationTask.ps1

.EXAMPLE
  .\scripts\windows\Register-CtgRamMitigationTask.ps1 -UseSecretVault

.EXAMPLE
  .\scripts\windows\Register-CtgRamMitigationTask.ps1 -Unregister
#>
[CmdletBinding()]
param(
    [string] $TaskName = 'HackerPlanet-CTG-Ram-Mitigation',
    [ValidateSet('Weekly', 'AtLogon')]
    [string] $Schedule = 'Weekly',
    [ValidateSet('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')]
    [string] $DayOfWeek = 'Monday',
    [string] $At = '04:15',
    [switch] $UseSecretVault,
    [switch] $Unregister
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
if (-not (Test-CtgIsAdmin)) {
    Write-Error 'Register-CtgRamMitigationTask.ps1 requires Administrator. Right-click PowerShell -> Run as administrator.'
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

$scriptPath = Join-Path $PSScriptRoot 'Enforce-CtgRamMitigations.ps1'
if (-not (Test-Path $scriptPath)) {
    Write-Error "Missing script: $scriptPath"
    exit 1
}

$argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$scriptPath`"", '-Monitor')
if ($UseSecretVault) {
    $argList += '-UseSecretVault'
}
$argString = ($argList -join ' ')

$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument $argString

if ($Schedule -eq 'AtLogon') {
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
} else {
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DayOfWeek -At $At
}

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

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
    -Description 'CTG RAM/CPU mitigation monitor (Enforce-CtgRamMitigations -Monitor); host enforcer not network IPS' | Out-Null

Write-Host "Registered scheduled task: $TaskName"
Write-Host "  Schedule:  $Schedule $(if ($Schedule -eq 'Weekly') { "$DayOfWeek at $At" } else { '' })"
Write-Host "  Script:    $scriptPath -Monitor"
Write-Host "  Vault:     UseSecretVault=$($UseSecretVault.IsPresent)"
Write-Host "  Run as:    $env:USERDOMAIN\$env:USERNAME (Highest, Interactive - logged-on only)"
Write-Host '  Password:  NOT stored in script or git (Interactive logon when user session active)'
Write-Host "  Log:       $env:USERPROFILE\Backups\logs\enforce-ctg-ram-mitigations.log"
Get-ScheduledTask -TaskName $TaskName | Format-List TaskName, State, Description
