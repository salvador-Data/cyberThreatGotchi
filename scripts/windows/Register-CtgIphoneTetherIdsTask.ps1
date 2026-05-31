<#
.SYNOPSIS
  Register HackerPlanet-CTG-iPhone-Tether-IDS (at logon, tether-gated).

.NOTES
  Requires Administrator. Interactive logon + Highest - no password in task XML.
#>
[CmdletBinding()]
param(
    [string] $TaskName = 'HackerPlanet-CTG-iPhone-Tether-IDS',
    [int] $RunMinutes = 60,
    [string] $HotspotSsidPattern = '',
    [switch] $UseSignal,
    [switch] $Unregister
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
if (-not (Test-CtgIsAdmin)) {
    Write-Error 'Register-CtgIphoneTetherIdsTask.ps1 requires Administrator.'
    exit 1
}

if ($Unregister) {
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Unregistered: $TaskName"
    } else { Write-Host "Task not found: $TaskName" }
    exit 0
}

$loopScript = Join-Path $PSScriptRoot 'ctg_iphone_tether_ids_logon.ps1'
if (-not (Test-Path $loopScript)) { Write-Error "Missing: $loopScript"; exit 1 }

$argList = "-NoProfile -ExecutionPolicy Bypass -File `"$loopScript`" -RunMinutes $RunMinutes"
if ($HotspotSsidPattern) { $argList += " -HotspotSsidPattern `"$HotspotSsidPattern`"" }
if ($UseSignal) { $argList += ' -UseSignal' }

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argList
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false; Write-Host "Replaced existing task: $TaskName" }

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'CyberThreatGotchi iPhone tether IDS when hotspot/USB detected at logon' | Out-Null
Write-Host "Registered scheduled task: $TaskName"