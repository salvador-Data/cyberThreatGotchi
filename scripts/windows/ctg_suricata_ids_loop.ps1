<#
.SYNOPSIS
  Continuous CTG Suricata IDS loop - repeated Start-CtgSuricataIDS.ps1 cycles.

.DESCRIPTION
  Runs Suricata detect-only cycles during lab hours. Stop with Ctrl+C.
  For perimeter IPS use OPNsense Suricata (see docs/FREE_IPS_SURICATA.md).

.PARAMETER CycleMinutes
  Minutes per Suricata run (default 60).

.PARAMETER Interface
  Npcap interface name (default auto).

.PARAMETER UseKaliBridge
  When Suricata missing on Windows, poll Kali EVE each cycle.

.PARAMETER BlockRepeatOffender
  netsh block external repeat offenders on high/critical alerts.

.EXAMPLE
  .\scripts\windows\ctg_suricata_ids_loop.ps1 -CycleMinutes 60
#>
[CmdletBinding()]
param(
    [int] $CycleMinutes = 60,
    [string] $Interface = '',
    [switch] $UseKaliBridge,
    [switch] $BlockRepeatOffender
)

$ErrorActionPreference = 'Continue'
$idsScript = Join-Path $PSScriptRoot 'Start-CtgSuricataIDS.ps1'
. (Join-Path $PSScriptRoot 'CTG-SuricataCommon.ps1')

$paths = Get-CtgSuricataPaths
Write-CtgSuricataLog "Suricata IDS loop starting cycle=${CycleMinutes}m" $paths.IdsLog 'Cyan'

while ($true) {
    $args = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $idsScript,
        '-RunMinutes', $CycleMinutes
    )
    if ($Interface) {
        $args += @('-Interface', $Interface)
    }
    if ($UseKaliBridge) {
        $args += '-UseKaliBridge'
    }
    if ($BlockRepeatOffender) {
        $args += '-BlockRepeatOffender'
    }
    Write-CtgSuricataLog "Loop cycle begin $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" $paths.IdsLog
    & powershell @args
    Write-CtgSuricataLog 'Loop cycle end - sleeping 60s before next cycle' $paths.IdsLog
    Start-Sleep -Seconds 60
}
