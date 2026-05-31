<#
.SYNOPSIS
  Register weekly memory protection audit (alias for Register-CtgRamMitigationTask.ps1).

.DESCRIPTION
  Registers HackerPlanet-CTG-Memory-Protection (or custom -TaskName) to run
  Enforce-CtgRamMitigations.ps1 -Monitor on a weekly schedule. Alerts via Signal
  on regression (Send-CtgIdsAlert.ps1).

  NEVER disables hypervisor mitigations — monitors posture only.

.EXAMPLE
  .\scripts\windows\Register-CtgMemoryProtectionTask.ps1 -UseSecretVault
#>
[CmdletBinding()]
param(
    [string] $TaskName = 'HackerPlanet-CTG-Memory-Protection',
    [ValidateSet('Weekly', 'AtLogon')]
    [string] $Schedule = 'Weekly',
    [ValidateSet('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')]
    [string] $DayOfWeek = 'Monday',
    [string] $At = '04:15',
    [switch] $UseSecretVault,
    [switch] $Unregister
)

$delegate = Join-Path $PSScriptRoot 'Register-CtgRamMitigationTask.ps1'
if (-not (Test-Path $delegate)) {
    Write-Error "Missing delegate script: $delegate"
    exit 1
}

& $delegate -TaskName $TaskName -Schedule $Schedule -DayOfWeek $DayOfWeek -At $At `
    -UseSecretVault:$UseSecretVault -Unregister:$Unregister
exit $LASTEXITCODE
