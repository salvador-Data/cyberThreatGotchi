<#
.SYNOPSIS
  Register Windows Scheduled Task HackerPlanet-CTG-Suricata-IDS (at logon, continuous loop).

.NOTES
  Requires Administrator. Interactive logon + Highest — no password in task XML.
  Runs ctg_suricata_ids_loop.ps1 for detect-only Suricata IDS + SMS on high severity.
#>
[CmdletBinding()]
param(
    [string] $TaskName = 'HackerPlanet-CTG-Suricata-IDS',
    [int] $CycleMinutes = 60,
    [string] $Interface = '',
    [switch] $UseKaliBridge,
    [switch] $BlockRepeatOffender,
    [switch] $Unregister
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
if (-not (Test-CtgIsAdmin)) {
    Write-Error 'Register-CtgSuricataIdsTask.ps1 requires Administrator.'
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

$loopScript = Join-Path $PSScriptRoot 'ctg_suricata_ids_loop.ps1'
if (-not (Test-Path $loopScript)) {
    Write-Error "Missing loop script: $loopScript"
    exit 1
}

$argList = "-NoProfile -ExecutionPolicy Bypass -File `"$loopScript`" -CycleMinutes $CycleMinutes"
if ($Interface) {
    $argList += " -Interface `"$Interface`""
}
if ($UseKaliBridge) {
    $argList += ' -UseKaliBridge'
}
if ($BlockRepeatOffender) {
    $argList += ' -BlockRepeatOffender'
}

$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument $argList

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 5)

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
    -Description 'CyberThreatGotchi Suricata IDS detect-only loop — SMS on high severity via Twilio env vars' | Out-Null

Write-Host "Registered scheduled task: $TaskName"
Write-Host "  Trigger: At logon ($env:USERNAME)"
Write-Host "  Script:  $loopScript"
Write-Host "  Cycle:   ${CycleMinutes} minutes per Suricata run"
Write-Host "  Run as:  $env:USERDOMAIN\$env:USERNAME (Interactive, Highest)"
if ($UseKaliBridge) {
    Write-Host '  Mode:    Kali EVE bridge when Windows Suricata missing'
}
Get-ScheduledTask -TaskName $TaskName | Format-List TaskName, State, Description
