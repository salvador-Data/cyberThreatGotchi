<#
.SYNOPSIS
  Optional Tor Expert Bundle guidance for Gatekeeper.TOR on Windows (Hacker Planet LLC).

.DESCRIPTION
  Documents install path; does not download Tor automatically (user consent).
  Preserves DuckDuckGo VPN — no system-wide route stacking.

.PARAMETER DiagnoseOnly
  Report Tor SOCKS port and Gatekeeper state only.
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\windows\CTG-Paths.ps1')
$RepoRoot = Get-CtgRepoRoot -FromPath $PSScriptRoot

Write-Host '=== Gatekeeper.TOR Windows install (diagnose / guide) ===' -ForegroundColor Cyan
Write-Host 'Tor Expert Bundle: https://www.torproject.org/download/tor/'
Write-Host 'After install, default SOCKS is typically 127.0.0.1:9050 (verify torrc).'
Write-Host 'Gatekeeper does NOT replace DuckDuckGo VPN/DNS/Password Manager.'
Write-Host 'Use Tor only for apps that opt into SOCKS — not as a second system VPN without consent.'
Write-Host ''
Write-Host "Docs: $(Join-Path $RepoRoot 'docs\GATEKEEPER_TOR.md')"

$tray = Join-Path $PSScriptRoot 'Start-GatekeeperTorTray.ps1'
if (Test-Path $tray) {
    & $tray -DiagnoseOnly
}

if (-not $DiagnoseOnly) {
    Write-Host ''
    Write-Host 'Next: install Tor Expert Bundle manually, then:' -ForegroundColor Yellow
    Write-Host "  .\scripts\gatekeeper-tor\windows\Start-GatekeeperTorTray.ps1 -InstallTray"
}
