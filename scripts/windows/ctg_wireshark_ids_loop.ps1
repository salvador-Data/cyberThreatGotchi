<#
.SYNOPSIS
  Continuous CTG Wireshark IDS loop - capture, analyze, SMS on high severity.

.DESCRIPTION
  Runs repeated capture cycles via Start-CTGWiresharkIDS.ps1. Stop with Ctrl+C.
  For production homelab IPS, use OPNsense Suricata (see docs/WIRESHARK_IDS_SMS.md).

.PARAMETER CycleMinutes
  Minutes per capture cycle (default 15).

.PARAMETER Interface
  tshark interface index (default auto).

.PARAMETER BlockRepeatOffenders
  Admin: optional netsh inbound block for repeat high-severity sources.

.EXAMPLE
  .\scripts\windows\ctg_wireshark_ids_loop.ps1 -CycleMinutes 15
#>
[CmdletBinding()]
param(
    [int] $CycleMinutes = 15,
    [string] $Interface = '',
    [switch] $BlockRepeatOffenders
)

$ErrorActionPreference = 'Continue'
$idsScript = Join-Path $PSScriptRoot 'Start-CTGWiresharkIDS.ps1'
. (Join-Path $PSScriptRoot 'CTG-WiresharkCommon.ps1')

$paths = Get-CtgWiresharkPaths
Write-CtgWiresharkLog "Wireshark IDS loop starting cycle=${CycleMinutes}m" $paths.IdsLog 'Cyan'

while ($true) {
    $args = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $idsScript,
        '-CaptureMinutes', $CycleMinutes
    )
    if ($Interface) {
        $args += @('-Interface', $Interface)
    }
    if ($BlockRepeatOffenders) {
        $args += '-BlockRepeatOffenders'
    }
    $args += '-OptimizeCapture'
    Write-CtgWiresharkLog "Loop cycle begin $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" $paths.IdsLog
    & powershell @args
    Write-CtgWiresharkLog 'Loop cycle end - sleeping 30s before next cycle' $paths.IdsLog
    Start-Sleep -Seconds 30
}
