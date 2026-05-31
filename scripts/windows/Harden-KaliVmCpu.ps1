# Harden VirtualBox Kali VM CPU side-channel posture (RETBleed / Spectre v2).
# Authorized defensive lab use only - Hacker Planet LLC - Philadelphia, PA.
#
# WHY: On a RETBleed-affected host CPU (e.g. Intel Coffee Lake i9-8950HK) the Kali
# guest kernel prints:
#   "Spectre v2: WARNING: Spectre v2 mitigation leaves CPU vulnerable to RETBleed
#    attacks, data leaks possible!"
# when VirtualBox does NOT expose the IA32_SPEC_CTRL / IA32_PRED_CMD MSRs to the
# guest. Without those MSRs the guest can only use retpoline, which is insufficient
# for RETBleed on these microarchitectures. Setting --spec-ctrl on passes the MSRs
# through so the guest kernel can use IBRS/IBPB and the warning clears.
#
# IMPORTANT: VBoxManage modifyvm requires the VM to be POWERED OFF. This script will
# only stop a running VM when you pass -StopVmIfRunning (ACPI shutdown, graceful).
#
# Usage (one command per block - see .cursor/rules/andy-communication.mdc):
#   .\scripts\windows\Harden-KaliVmCpu.ps1 -DiagnoseOnly
#   .\scripts\windows\Harden-KaliVmCpu.ps1 -StopVmIfRunning -StartAfter
#   .\scripts\windows\Harden-KaliVmCpu.ps1 -StopVmIfRunning -FullCpuMitigations
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

$ErrorActionPreference = 'Stop'
$LogDir = 'C:\Users\Owner\Backups\logs'
$LogFile = Join-Path $LogDir 'harden-kali-vm-cpu.log'

function Write-CtgCpuLog([string]$Message) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Host $line
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Get-CtgVBoxManagePath {
    $path = Join-Path ${env:ProgramFiles} 'Oracle\VirtualBox\VBoxManage.exe'
    if (Test-Path $path) { return $path }
    return $null
}

function Resolve-CtgKaliVmName {
    param([string]$VBoxManage, [string[]]$Candidates)
    $list = (& $VBoxManage list vms 2>&1 | Out-String)
    foreach ($name in $Candidates) {
        if ($list -match "`"$([regex]::Escape($name))`"") { return $name }
    }
    return $null
}

function Get-CtgVmState {
    param([string]$Name, [string]$VBoxManage)
    $infoRaw = (& $VBoxManage showvminfo $Name --machinereadable 2>&1 | Out-String)
    $state = 'unknown'
    if ($infoRaw -match 'VMState="([^"]+)"') { $state = $Matches[1] }
    return $state
}

function Get-CtgVmConfigFile {
    param([string]$Name, [string]$VBoxManage)
    $infoRaw = (& $VBoxManage showvminfo $Name --machinereadable 2>&1 | Out-String)
    if ($infoRaw -match 'CfgFile="([^"]+)"') { return ($Matches[1] -replace '\\\\', '\') }
    return $null
}

function Get-CtgSpecCtrlState {
    # VirtualBox stores --spec-ctrl on as SpectreControl="true" on the <CPU> element.
    param([string]$CfgFile)
    if (-not $CfgFile -or -not (Test-Path $CfgFile)) { return 'unknown' }
    $xml = Get-Content -Path $CfgFile -Raw
    if ($xml -match 'SpectreControl="true"') { return 'on' }
    return 'off'
}

function Stop-CtgVmGraceful {
    param([string]$Name, [string]$VBoxManage, [int]$WaitSec)
    $st = Get-CtgVmState -Name $Name -VBoxManage $VBoxManage
    if ($st -ne 'running') {
        Write-CtgCpuLog "VM $Name already $st - no shutdown needed"
        return $true
    }
    if ($WhatIf) {
        Write-CtgCpuLog "[WhatIf] controlvm $Name acpipowerbutton (graceful shutdown)"
        return $true
    }
    Write-CtgCpuLog "VM $Name running - sending ACPI power button (graceful guest shutdown)"
    & $VBoxManage controlvm $Name acpipowerbutton 2>&1 | Out-Null
    $deadline = (Get-Date).AddSeconds($WaitSec)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        $st = Get-CtgVmState -Name $Name -VBoxManage $VBoxManage
        if ($st -ne 'running') {
            Write-CtgCpuLog "VM $Name stopped (state: $st)"
            Start-Sleep -Seconds 3
            return $true
        }
    }
    Write-CtgCpuLog "ACPI shutdown timed out after ${WaitSec}s - VM still running; not forcing poweroff"
    return $false
}

function Set-CtgSpecCtrlOn {
    param([string]$Name, [string]$VBoxManage, [bool]$Full)
    # Core RETBleed / Spectre v2 fix: expose IA32_SPEC_CTRL + IA32_PRED_CMD to guest.
    $applied = @()
    $coreArgs = @(
        @('--spec-ctrl', 'on'),
        @('--ibpb-on-vm-exit', 'on'),
        @('--ibpb-on-vm-entry', 'on')
    )
    $fullArgs = @(
        @('--l1d-flush-on-vm-entry', 'on'),
        @('--mds-clear-on-vm-entry', 'on')
    )
    $argSets = $coreArgs
    if ($Full) { $argSets += $fullArgs }
    foreach ($set in $argSets) {
        $flag = $set[0]; $val = $set[1]
        if ($WhatIf) {
            Write-CtgCpuLog "[WhatIf] modifyvm $Name $flag $val"
            $applied += "$flag=$val"
            continue
        }
        $out = (& $VBoxManage modifyvm $Name $flag $val 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -eq 0) {
            Write-CtgCpuLog "Applied: modifyvm $Name $flag $val"
            $applied += "$flag=$val"
        } else {
            Write-CtgCpuLog "WARNING: modifyvm $Name $flag $val failed: $out"
        }
    }
    return $applied
}

function Start-CtgVm {
    param([string]$Name, [string]$VBoxManage, [string]$Type)
    $typeMap = @{ Headless = 'headless'; Gui = 'gui'; Separate = 'separate' }
    $vboxType = $typeMap[$Type]
    if ($WhatIf) {
        Write-CtgCpuLog "[WhatIf] startvm $Name --type $vboxType"
        return
    }
    Write-CtgCpuLog "Starting VM $Name (--type $vboxType)"
    & $VBoxManage startvm $Name --type $vboxType 2>&1 | ForEach-Object { Write-CtgCpuLog "  startvm: $_" }
}

# --- main ---
Write-CtgCpuLog '=== Harden-KaliVmCpu.ps1 start (RETBleed / Spectre v2 spec-ctrl) ==='

$VBoxManage = Get-CtgVBoxManagePath
if (-not $VBoxManage) {
    Write-CtgCpuLog 'VBoxManage not found - install Oracle VirtualBox'
    exit 2
}

$resolved = Resolve-CtgKaliVmName -VBoxManage $VBoxManage -Candidates (@($VmName) + $VmNameCandidates | Select-Object -Unique)
if (-not $resolved) {
    Write-CtgCpuLog "No Kali VM found (tried: $((@($VmName) + $VmNameCandidates | Select-Object -Unique) -join ', '))"
    exit 2
}
$VmName = $resolved

$state = Get-CtgVmState -Name $VmName -VBoxManage $VBoxManage
$cfg = Get-CtgVmConfigFile -Name $VmName -VBoxManage $VBoxManage
$specBefore = Get-CtgSpecCtrlState -CfgFile $cfg
Write-CtgCpuLog "VM: $VmName | state: $state | spec-ctrl: $specBefore | cfg: $cfg"

if ($DiagnoseOnly) {
    if ($specBefore -eq 'on') {
        Write-CtgCpuLog 'Diagnose: spec-ctrl is ON - guest receives IA32_SPEC_CTRL/PRED_CMD MSRs (RETBleed fix in place)'
    } else {
        Write-CtgCpuLog 'Diagnose: spec-ctrl is OFF - guest cannot use IBRS/IBPB; expect RETBleed warning on Coffee Lake'
        Write-CtgCpuLog 'Fix: power VM off, then .\scripts\windows\Harden-KaliVmCpu.ps1 -StopVmIfRunning -StartAfter'
    }
    Write-CtgCpuLog 'Reminder: host BIOS + Windows Update microcode are primary RETBleed mitigation; see docs/KALI_RETBLEED.md'
    Write-CtgCpuLog '=== Harden-KaliVmCpu.ps1 complete (diagnose-only) ==='
    exit 0
}

if ($specBefore -eq 'on' -and -not $FullCpuMitigations) {
    Write-CtgCpuLog 'spec-ctrl already ON - nothing to change (pass -FullCpuMitigations for L1D/MDS flush-on-entry)'
    Write-CtgCpuLog '=== Harden-KaliVmCpu.ps1 complete (no change) ==='
    exit 0
}

if ($state -eq 'running') {
    if (-not $StopVmIfRunning) {
        Write-CtgCpuLog "VM $VmName is RUNNING. modifyvm requires power-off."
        Write-CtgCpuLog 'Re-run with -StopVmIfRunning (graceful ACPI shutdown) -StartAfter to apply and restart.'
        exit 1
    }
    if (-not (Stop-CtgVmGraceful -Name $VmName -VBoxManage $VBoxManage -WaitSec $AcpiWaitSeconds)) {
        Write-CtgCpuLog 'VM did not stop gracefully - aborting (will not force poweroff). Save your work and shut down Kali, then re-run.'
        exit 1
    }
} elseif ($state -notin @('poweroff', 'saved', 'aborted')) {
    Write-CtgCpuLog "VM $VmName is $state - cannot modify. Power it off and re-run."
    exit 1
}

if ($state -eq 'saved') {
    Write-CtgCpuLog 'WARNING: VM is in SAVED state - modifyvm may be refused. Discard saved state if it fails: VBoxManage discardstate kali'
}

$applied = Set-CtgSpecCtrlOn -Name $VmName -VBoxManage $VBoxManage -Full:$FullCpuMitigations
$specAfter = Get-CtgSpecCtrlState -CfgFile $cfg
Write-CtgCpuLog "spec-ctrl after apply: $specAfter | flags: $($applied -join ', ')"

if ($StartAfter) {
    Start-CtgVm -Name $VmName -VBoxManage $VBoxManage -Type $StartType
}

Write-CtgCpuLog 'NEXT: in Kali after reboot, verify with:'
Write-CtgCpuLog '  cat /sys/devices/system/cpu/vulnerabilities/retbleed'
Write-CtgCpuLog '  cat /sys/devices/system/cpu/vulnerabilities/spectre_v2'
Write-CtgCpuLog "  sudo bash /mnt/ctg/fix-retbleed-mitigation.sh --diagnose-only"
Write-CtgCpuLog 'Primary mitigation remains host BIOS/microcode (Intel Coffee Lake) - see docs/KALI_RETBLEED.md'
Write-CtgCpuLog '=== Harden-KaliVmCpu.ps1 complete ==='
exit 0
