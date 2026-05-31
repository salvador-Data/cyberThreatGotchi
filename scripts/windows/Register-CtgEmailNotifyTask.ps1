<#
.SYNOPSIS
  Register scheduled task for CTG email notify bridge (IMAP poll loop).

.PARAMETER Unregister
  Remove task.

.EXAMPLE
  .\scripts\windows\Register-CtgEmailNotifyTask.ps1
#>
[CmdletBinding()]
param(
    [string] $TaskName = 'HackerPlanet-CTG-Email-Notify',
    [int] $IntervalMinutes = 5,
    [switch] $Unregister
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'Start-CtgEmailNotifyBridge.ps1'
$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Once -UseSecretVault"

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration ([TimeSpan]::MaxValue)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
    -MultipleInstances IgnoreNew

$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Limited

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($Unregister) {
    if ($existing) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Removed: $TaskName"
    }
    exit 0
}

if ($existing) { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false }

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description 'CTG Proton IMAP poll -> ctg-email-notify share (vault creds)' | Out-Null

Write-Host "Registered: $TaskName (every $IntervalMinutes min, -Once -UseSecretVault)"
Write-Host "Requires: Proton Bridge running + vault title Proton IMAP"
