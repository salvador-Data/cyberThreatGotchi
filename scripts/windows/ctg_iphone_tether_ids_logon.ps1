<#
.SYNOPSIS
  At logon: run Start-CtgIphoneTetherIds when tether is detected (else exit 0).

.NOTES
  Requires tether heuristics inside Start-CtgIphoneTetherIds.ps1; skips when none found.
#>
[CmdletBinding()]
param(
    [int] $RunMinutes = 60,
    [switch] $UseSignal,
    [switch] $UseSnort,
    [switch] $UseSuricata,
    [string] $HotspotSsidPattern = ''
)

$ErrorActionPreference = 'Continue'
$startScript = Join-Path $PSScriptRoot 'Start-CtgIphoneTetherIds.ps1'
$diag = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $startScript -DiagnoseOnly 2>&1
# DiagnoseOnly exit 1 when no tether OR no IDS; parse log for tether selection
if ($diag -match 'Selected for IDS:') {
    $args = @{ RunMinutes = $RunMinutes }
    if ($UseSignal) { $args['UseSignal'] = $true }
    if ($UseSnort) { $args['UseSnort'] = $true }
    if ($UseSuricata) { $args['UseSuricata'] = $true }
    if ($HotspotSsidPattern) { $args['HotspotSsidPattern'] = $HotspotSsidPattern }
    & $startScript @args
    exit $LASTEXITCODE
}
exit 0