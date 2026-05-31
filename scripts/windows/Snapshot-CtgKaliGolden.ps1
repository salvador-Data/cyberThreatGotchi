<#
.SYNOPSIS
  Snapshot VirtualBox Kali VM as golden image (authorized lab use).

.DESCRIPTION
  -DiagnoseOnly: list VMs and existing snapshots.
  -ApplySafe: take snapshot after VM named state (powered off or running — your choice).

.PARAMETER VmName
  VirtualBox VM name (default: Kali or CTG_KALI_VM env).

.PARAMETER SnapshotName
  Snapshot label (default: ctg-golden-YYYYMMDD).

.EXAMPLE
  .\scripts\windows\Snapshot-CtgKaliGolden.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Snapshot-CtgKaliGolden.ps1 -ApplySafe -VmName Kali
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch] $DiagnoseOnly,
    [switch] $ApplySafe,
    [string] $VmName = '',
    [string] $SnapshotName = ''
)

$ErrorActionPreference = 'Stop'

$LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
$LogFile = Join-Path $LogDir 'snapshot-ctg-kali-golden.log'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-CtgSnapLog {
    param([string] $Message, [string] $Color = 'Gray')
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Host $line -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Get-CtgVBoxManage {
    $candidates = @(
        'VBoxManage',
        "${env:ProgramFiles}\Oracle\VirtualBox\VBoxManage.exe",
        "${env:ProgramFiles(x86)}\Oracle\VirtualBox\VBoxManage.exe"
    )
    foreach ($c in $candidates) {
        if (Get-Command $c -ErrorAction SilentlyContinue) { return $c }
        if (Test-Path $c) { return $c }
    }
    return $null
}

if (-not $VmName) {
    $VmName = [Environment]::GetEnvironmentVariable('CTG_KALI_VM', 'User')
    if (-not $VmName) { $VmName = 'Kali' }
}
if (-not $SnapshotName) {
    $SnapshotName = 'ctg-golden-' + (Get-Date -Format 'yyyyMMdd')
}

$vbox = Get-CtgVBoxManage
if (-not $vbox) {
    Write-CtgSnapLog 'VBoxManage not found — install VirtualBox.' 'Red'
    exit 1
}

Write-CtgSnapLog '=== CTG Kali golden snapshot ===' 'Cyan'
Write-CtgSnapLog "Target VM: $VmName"
Write-CtgSnapLog "Snapshot name: $SnapshotName"
Write-CtgSnapLog 'Restore: VBoxManage snapshot "VM" restore "NAME" — see docs/LAB_MATURITY.md' 'Gray'
Write-CtgSnapLog 'CLICK-ME success path: snapshot after RUN-KALI-LAB-NOW completes cleanly.' 'Gray'

try {
    $vms = & $vbox list vms 2>&1
    Write-CtgSnapLog 'Registered VMs:'
    $vms | ForEach-Object { Write-CtgSnapLog "  $_" }
} catch {
    Write-CtgSnapLog "list vms failed: $($_.Exception.Message)" 'Yellow'
}

try {
    $snaps = & $vbox snapshot $VmName list 2>&1
    Write-CtgSnapLog "Snapshots for $VmName`:"
    $snaps | ForEach-Object { Write-CtgSnapLog "  $_" }
} catch {
    Write-CtgSnapLog "No snapshots or VM not found: $VmName" 'Yellow'
}

if (-not $ApplySafe) {
    Write-CtgSnapLog 'DiagnoseOnly complete. Run -ApplySafe to take snapshot (VM should be in known-good state).' 'Cyan'
    exit 0
}

if (-not $PSCmdlet.ShouldProcess($VmName, "snapshot take $SnapshotName")) {
    Write-CtgSnapLog '[WhatIf] snapshot take' 'Yellow'
    exit 0
}

& $vbox snapshot $VmName take $SnapshotName --description "CTG golden image $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
if ($LASTEXITCODE -ne 0) {
    Write-CtgSnapLog 'Snapshot failed — is VM name correct and VirtualBox running?' 'Red'
    exit $LASTEXITCODE
}

Write-CtgSnapLog "Golden snapshot created: $SnapshotName" 'Green'
exit 0
