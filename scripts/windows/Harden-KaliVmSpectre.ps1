# Harden VirtualBox Kali VM Spectre / RETBleed MSR exposure (wrapper).
# Delegates to Harden-KaliVmCpu.ps1 — same parameters and behavior.
# Authorized defensive lab use only — Hacker Planet LLC — Philadelphia, PA.
param(
    [string]$VmName = 'kali',
    [string[]]$VmNameCandidates = @('kali', 'Kali-Lab', 'Kali', 'kali-linux'),
    [switch]$StopVmIfRunning,
    [switch]$StartAfter,
    [ValidateSet('Headless', 'Gui', 'Separate')]
    [string]$StartType = 'Gui',
    [switch]$FullCpuMitigations,
    [int]$AcpiWaitSeconds = 180,
    [switch]$DiagnoseOnly,
    [switch]$WhatIf
)
$helper = Join-Path $PSScriptRoot 'Harden-KaliVmCpu.ps1'
if (-not (Test-Path $helper)) {
    Write-Error "Missing $helper"
    exit 2
}
& $helper @PSBoundParameters
exit $LASTEXITCODE
