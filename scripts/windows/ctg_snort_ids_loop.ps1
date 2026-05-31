<#
.SYNOPSIS
  Continuous CTG Snort IDS loop - repeated Start-CtgSnortIDS.ps1 cycles.

.DESCRIPTION
  Runs Snort detect-only cycles during lab hours. Stop with Ctrl+C.
  For perimeter IPS use OPNsense Suricata (see docs/WINDOWS_SNORT_IDS_SMS.md).

.PARAMETER CycleMinutes
  Minutes per Snort run (default 60).

.PARAMETER Interface
  Npcap interface index (default auto).

.PARAMETER UseWiresharkFallback
  When Snort missing, use Wireshark IDS each cycle.

.EXAMPLE
  .\scripts\windows\ctg_snort_ids_loop.ps1 -CycleMinutes 60
#>
[CmdletBinding()]
param(
    [int] $CycleMinutes = 60,
    [string] $Interface = '',
    [switch] $UseWiresharkFallback
)

$ErrorActionPreference = 'Continue'
$idsScript = Join-Path $PSScriptRoot 'Start-CtgSnortIDS.ps1'
. (Join-Path $PSScriptRoot 'CTG-SnortCommon.ps1')

$paths = Get-CtgSnortPaths
Write-CtgSnortLog "Snort IDS loop starting cycle=${CycleMinutes}m" $paths.IdsLog 'Cyan'

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
    if ($UseWiresharkFallback) {
        $args += '-UseWiresharkFallback'
    }
    Write-CtgSnortLog "Loop cycle begin $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" $paths.IdsLog
    & powershell @args
    Write-CtgSnortLog 'Loop cycle end - sleeping 60s before next cycle' $paths.IdsLog
    Start-Sleep -Seconds 60
}
