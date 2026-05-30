# Fix VirtualBox Kali blank screen after login (VRAM, graphics, stage in-guest recovery script).
# Authorized defensive lab use only — Hacker Planet LLC.
param(
    [string]$VmName = 'kali',
    [string]$BackupRoot = 'C:\Users\Owner\Backups',
    [int]$VramMB = 128,
    [string]$GraphicsController = 'vmsvga',
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$VBoxManage = Join-Path ${env:ProgramFiles} 'Oracle\VirtualBox\VBoxManage.exe'
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$FixScript = Join-Path $RepoRoot 'scripts\kali\fix-kali-blank-screen.sh'

function Write-CtgFixLog([string]$Message) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Host $line
    $logDir = Join-Path $BackupRoot 'logs'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    Add-Content -Path (Join-Path $logDir 'fix-kali-blank-screen.log') -Value $line -Encoding UTF8
}

if (-not (Test-Path $VBoxManage)) {
    throw "VBoxManage not found at $VBoxManage. Install Oracle VirtualBox."
}
if (-not (Test-Path $FixScript)) {
    throw "In-guest fix script missing: $FixScript"
}

if (-not (Test-Path $BackupRoot)) {
    New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
}

$destFix = Join-Path $BackupRoot 'fix-kali-blank-screen.sh'
if (-not $WhatIf) {
    Copy-Item -Path $FixScript -Destination $destFix -Force
}
Write-CtgFixLog "Staged in-guest fix: $destFix"

$vmsRaw = (& $VBoxManage list vms 2>&1 | Out-String).Trim()
if ($vmsRaw -notmatch "`"$([regex]::Escape($VmName))`"") {
    Write-CtgFixLog "VM '$VmName' not found in VirtualBox. Available:"
    Write-CtgFixLog $vmsRaw
    exit 2
}

$infoRaw = & $VBoxManage showvminfo $VmName --machinereadable 2>&1 | Out-String
$state = 'unknown'
if ($infoRaw -match 'VMState="([^"]+)"') { $state = $Matches[1] }
Write-CtgFixLog "VM state: $state"

if ($infoRaw -match 'VRAM size="(\d+)"') {
    Write-CtgFixLog "Current VRAM (MiB): $($Matches[1])"
}
if ($infoRaw -match 'graphicscontroller="([^"]+)"') {
    Write-CtgFixLog "Current graphics controller: $($Matches[1])"
}

if ($state -eq 'running') {
    Write-CtgFixLog 'Power off VM before changing VRAM/graphics (or shut down guest cleanly).'
    Write-CtgFixLog "  VBoxManage controlvm $VmName acpipowerbutton"
    Write-CtgFixLog 'Re-run this script after VM is powered off.'
} else {
    Write-CtgFixLog "Setting VRAM=${VramMB}MB graphicscontroller=$GraphicsController accelerate3d=off"
    if (-not $WhatIf) {
        & $VBoxManage modifyvm $VmName --vram $VramMB --graphicscontroller $GraphicsController --accelerate3d off
    }
}

Write-CtgFixLog '=== Immediate recovery (inside Kali VM) ==='
Write-CtgFixLog '1. At blank screen: Ctrl+Alt+F2 (host Right-Ctrl+F2 if capture is on)'
Write-CtgFixLog '2. Login as sal, then:'
Write-CtgFixLog '   sudo bash /mnt/ctg/fix-kali-blank-screen.sh'
Write-CtgFixLog '   OR if share not mounted:'
Write-CtgFixLog "   sudo bash $destFix"
Write-CtgFixLog '3. Ctrl+Alt+F1 or reboot — desktop should appear on X11'
Write-CtgFixLog '4. CTG scrambler: launch from Applications (manual GUI only)'
Write-CtgFixLog '=== Windows already applied (when VM off) ==='
Write-CtgFixLog "VBoxManage modifyvm $VmName --vram $VramMB --graphicscontroller $GraphicsController --accelerate3d off"
Write-CtgFixLog 'Root cause notes: 5 MiB VRAM + GNOME Wayland + optional profile.d read prompt — see docs/CTG_LAB_AUTORUN.md'

exit 0
