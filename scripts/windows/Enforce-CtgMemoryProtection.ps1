<#
.SYNOPSIS
  Unified memory protection enforcer — alias for Enforce-CtgRamMitigations.ps1.

.DESCRIPTION
  CTG memory protection = host exploit mitigation + hypervisor-backed security (VBS/HVCI)
  + VirtualBox guest spec-ctrl + vault session hygiene. NOT network IPS.

  Delegates to Enforce-CtgRamMitigations.ps1 (same parameters). See docs/MEMORY_PROTECTION.md.

.EXAMPLE
  .\scripts\windows\Enforce-CtgMemoryProtection.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Enforce-CtgMemoryProtection.ps1 -ApplySafe

.EXAMPLE
  .\scripts\windows\Enforce-CtgMemoryProtection.ps1 -Monitor -UseSecretVault
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [switch] $ApplySafe,
    [switch] $Monitor,
    [switch] $UseSecretVault
)

$delegate = Join-Path $PSScriptRoot 'Enforce-CtgRamMitigations.ps1'
if (-not (Test-Path $delegate)) {
    Write-Error "Missing delegate script: $delegate"
    exit 1
}

$args = @{}
if ($DiagnoseOnly) { $args['DiagnoseOnly'] = $true }
if ($ApplySafe) { $args['ApplySafe'] = $true }
if ($Monitor) { $args['Monitor'] = $true }
if ($UseSecretVault) { $args['UseSecretVault'] = $true }

& $delegate @args
exit $LASTEXITCODE
