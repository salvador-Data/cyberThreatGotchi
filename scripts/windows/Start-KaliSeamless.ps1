# Start VirtualBox Kali VM in seamless mode (Guest Additions required).
# Authorized defensive lab use only — Hacker Planet LLC · Philadelphia, PA
param(
    [string]$VmName = 'kali',
    [string[]]$VmNameCandidates = @('kali', 'Kali-Lab', 'Kali', 'kali-linux'),
    [int]$GuestAdditionsWaitSec = 30,
    [switch]$SkipExtradata,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Continue'
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$LogDir = 'C:\Users\Owner\Backups\logs'
$LogFile = Join-Path $LogDir 'kali-seamless.log'

function Write-CtgSeamlessLog([string]$Message) {
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

function Test-CtgGuestAdditionsReady {
    param([string]$Name, [string]$VBoxManage)
    if ((Get-CtgVmState -Name $Name -VBoxManage $VBoxManage) -ne 'running') {
        return $false
    }
    $props = @(
        '/VirtualBox/GuestAdd/GuestAddVersion',
        '/VirtualBox/GuestAdd/Version'
    )
    foreach ($prop in $props) {
        $raw = (& $VBoxManage guestproperty get $Name $prop 2>&1 | Out-String).Trim()
        if ($raw -match 'Value:\s*(.+)$') {
            $val = $Matches[1].Trim()
            if ($val -and $val -notmatch 'No value set|^$') { return $true }
        }
    }
    $info = (& $VBoxManage showvminfo $Name 2>&1 | Out-String)
    if ($info -match 'Guest Additions:\s*(\d+\.\d+)') { return $true }
    return $false
}

function Set-CtgSeamlessExtradata {
    param([string]$Name, [string]$VBoxManage)
    if ($SkipExtradata) { return }
    Write-CtgSeamlessLog "Setting extradata GUI/Seamless=on on $Name (auto-enter when Guest Additions ready)"
    if ($WhatIf) {
        Write-CtgSeamlessLog "[WhatIf] setextradata $Name GUI/Seamless on"
        Write-CtgSeamlessLog "[WhatIf] setextradata $Name GUI/SeamlessMode 1"
        return
    }
    & $VBoxManage setextradata $Name 'GUI/Seamless' 'on' 2>&1 | ForEach-Object { Write-CtgSeamlessLog $_ }
    & $VBoxManage setextradata $Name 'GUI/SeamlessMode' '1' 2>&1 | ForEach-Object { Write-CtgSeamlessLog $_ }
}

function Test-CtgVBoxControlvmSeamlessSupported {
    param([string]$VBoxManage)
    $help = (& $VBoxManage controlvm 2>&1 | Out-String)
    return ($help -match '\bseamless\b')
}

function Write-CtgHostLHint {
    param([string]$Name)
    Write-CtgSeamlessLog "VirtualBox 7: press Host+L (default Host=Right Ctrl) on the $Name window to toggle seamless now"
}

function Write-CtgGuestAdditionsHint {
    Write-CtgSeamlessLog 'WARNING: Guest Additions not ready - seamless mode unavailable.'
    Write-CtgSeamlessLog 'Fix in Kali: sudo bash /mnt/ctg/kali-boot-autopatch.sh --install'
    Write-CtgSeamlessLog 'Or: sudo bash /mnt/ctg/fix-kali-blank-screen.sh'
    Write-CtgSeamlessLog 'Host deploy: .\scripts\windows\Deploy-KaliBootAutopatch.ps1'
    Write-CtgSeamlessLog 'Docs: docs/KALI_VIRTUALBOX_SEAMLESS.md'
}

function Enable-CtgSeamlessOnRunningVm {
    param([string]$Name, [string]$VBoxManage)
    if (-not (Test-CtgGuestAdditionsReady -Name $Name -VBoxManage $VBoxManage)) {
        Write-CtgGuestAdditionsHint
        Write-CtgSeamlessLog "VM $Name is running but Guest Additions missing - leaving normal windowed mode"
        return $false
    }
    if (-not (Test-CtgVBoxControlvmSeamlessSupported -VBoxManage $VBoxManage)) {
        Write-CtgSeamlessLog "VM $Name running with Guest Additions - extradata GUI/Seamless=on set for seamless on next gui start"
        Write-CtgHostLHint -Name $Name
        return $true
    }
    Write-CtgSeamlessLog "Enabling seamless on running VM: $Name (legacy controlvm)"
    if ($WhatIf) {
        Write-CtgSeamlessLog "[WhatIf] controlvm $Name seamless on"
        return $true
    }
    $out = & $VBoxManage controlvm $Name seamless on 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $out -match 'error|VBOX_E|Invalid parameter') {
        Write-CtgSeamlessLog "controlvm seamless on unavailable: $($out.Trim())"
        Write-CtgHostLHint -Name $Name
        return $true
    }
    Write-CtgSeamlessLog "Seamless mode enabled on $Name (Host+L toggles)"
    return $true
}

function Start-CtgKaliSeamless {
    param(
        [string]$Name = $VmName,
        [string]$VBoxManage = '',
        [int]$WaitSec = $GuestAdditionsWaitSec,
        [switch]$WhatIfParam
    )
    if ($WhatIfParam) { $script:WhatIf = $true }

    if (-not $VBoxManage) {
        $VBoxManage = Get-CtgVBoxManagePath
    }
    if (-not $VBoxManage -or -not (Test-Path $VBoxManage)) {
        Write-CtgSeamlessLog 'VBoxManage not found - install Oracle VirtualBox'
        return 2
    }

    if (-not $Name) {
        $Name = Resolve-CtgKaliVmName -VBoxManage $VBoxManage -Candidates $VmNameCandidates
    }
    if (-not $Name) {
        Write-CtgSeamlessLog "No Kali VM found (tried: $($VmNameCandidates -join ', '))"
        return 2
    }

    Set-CtgSeamlessExtradata -Name $Name -VBoxManage $VBoxManage

    $state = Get-CtgVmState -Name $Name -VBoxManage $VBoxManage
    Write-CtgSeamlessLog "VM $Name state: $state"

    if ($state -eq 'running') {
        if (Enable-CtgSeamlessOnRunningVm -Name $Name -VBoxManage $VBoxManage) { return 0 }
        return 1
    }

    if ($state -notin @('poweroff', 'saved', 'aborted')) {
        Write-CtgSeamlessLog "VM $Name is $state - cannot start (wait or power off first)"
        return 2
    }

    Write-CtgSeamlessLog "Starting $Name (seamless via GUI/Seamless extradata + --type gui)"
    if ($WhatIf) {
        Write-CtgSeamlessLog "[WhatIf] startvm $Name --type gui"
        return 0
    }

    $startOut = & $VBoxManage startvm $Name --type seamless 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and $startOut -notmatch 'error|VBOX_E|Invalid|failed') {
        Write-CtgSeamlessLog "Started $Name with --type seamless (legacy VirtualBox)"
        return 0
    }

    if ($startOut -match 'Invalid|--type') {
        Write-CtgSeamlessLog 'VirtualBox 7: --type seamless not available - using --type gui + GUI/Seamless=on'
    } else {
        Write-CtgSeamlessLog "Seamless start failed ($($startOut.Trim())) - fallback: gui + Guest Additions check"
    }

    $guiOut = & $VBoxManage startvm $Name --type gui 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Write-CtgSeamlessLog "GUI start failed: $($guiOut.Trim())"
        return 2
    }

    Write-CtgSeamlessLog "Waiting ${WaitSec}s for Guest Additions ..."
    $deadline = (Get-Date).AddSeconds($WaitSec)
    $gaReady = $false
    while ((Get-Date) -lt $deadline) {
        if (Test-CtgGuestAdditionsReady -Name $Name -VBoxManage $VBoxManage) {
            $gaReady = $true
            break
        }
        Start-Sleep -Seconds 5
    }

    if ($gaReady) {
        if (Test-CtgVBoxControlvmSeamlessSupported -VBoxManage $VBoxManage) {
            Enable-CtgSeamlessOnRunningVm -Name $Name -VBoxManage $VBoxManage | Out-Null
        } else {
            Write-CtgSeamlessLog "Guest Additions ready - VirtualBox should auto-enter seamless (GUI/Seamless=on)"
            Write-CtgHostLHint -Name $Name
        }
        return 0
    }

    Write-CtgGuestAdditionsHint
    Write-CtgSeamlessLog "Started $Name in normal GUI - install Guest Additions then re-run Start-KaliSeamless.ps1"
    return 1
}

$script:IsDotSourced = ($MyInvocation.InvocationName -eq '.')
if (-not $script:IsDotSourced) {
    $exitCode = Start-CtgKaliSeamless -Name $VmName -WaitSec $GuestAdditionsWaitSec
    if ($null -ne $exitCode) { exit $exitCode }
}
