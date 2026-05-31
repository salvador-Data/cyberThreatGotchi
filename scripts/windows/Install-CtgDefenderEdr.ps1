<#
.SYNOPSIS
  Alias for Harden-CtgWindowsDefender.ps1 (CTG lab EDR baseline).

.EXAMPLE
  .\scripts\windows\Install-CtgDefenderEdr.ps1 -DiagnoseOnly
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [switch] $ApplySafe,
    [switch] $EnforceASR
)

$delegate = Join-Path $PSScriptRoot 'Harden-CtgWindowsDefender.ps1'
& $delegate @PSBoundParameters
exit $LASTEXITCODE
