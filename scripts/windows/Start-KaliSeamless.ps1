# Start VirtualBox Kali VM in seamless mode (Guest Additions + graphical login required).
# Authorized defensive lab use only - Hacker Planet LLC · Philadelphia, PA
param(
    [string]$VmName = 'kali',
    [string[]]$VmNameCandidates = @('kali', 'Kali-Lab', 'Kali', 'kali-linux'),
    [int]$GuestAdditionsWaitSec = 60,
    [int]$DesktopWaitSec = 120,
    [switch]$SkipExtradata,
    [switch]$DiagnoseOnly,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Continue'
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$LogDir = 'C:\Users\Owner\Backups\logs'
$LogFile = Join-Path $LogDir 'kali-seamless.log'
$script:VBoxLockRetries = 3

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

function Get-CtgVBoxHostVersion {
    param([string]$VBoxManage)
    $raw = (& $VBoxManage --version 2>&1 | Out-String).Trim()
    if ($raw -match '^(\d+)\.(\d+)') {
        return @{ Major = [int]$Matches[1]; Minor = [int]$Matches[2]; Raw = $raw }
    }
    return @{ Major = 7; Minor = 0; Raw = $raw }
}

function Invoke-CtgVBoxManage {
    param(
        [string]$VBoxManage,
        [string[]]$Arguments,
        [int]$Retries = $script:VBoxLockRetries
    )
    $attempt = 0
    while ($true) {
        $attempt++
        $out = & $VBoxManage @Arguments 2>&1 | Out-String
        $code = $LASTEXITCODE
        if ($code -eq 0 -and $out -notmatch 'E_ACCESSDENIED|already locked|unexpected process') {
            return @{ ExitCode = $code; Output = $out }
        }
        if ($out -match 'already locked|E_ACCESSDENIED|unexpected process' -and $attempt -lt $Retries) {
            Write-CtgSeamlessLog "VBoxManage lock (attempt $attempt/$Retries) - retry in 3s"
            Start-Sleep -Seconds 3
            continue
        }
        return @{ ExitCode = $code; Output = $out }
    }
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
    $infoRaw = (Invoke-CtgVBoxManage -VBoxManage $VBoxManage -Arguments @('showvminfo', $Name, '--machinereadable')).Output
    $state = 'unknown'
    if ($infoRaw -match 'VMState="(.+?)"') { $state = $Matches[1] }
    return $state
}

function Get-CtgGuestPropertyValue {
    param([string]$Name, [string]$VBoxManage, [string]$Property)
    $raw = (Invoke-CtgVBoxManage -VBoxManage $VBoxManage -Arguments @('guestproperty', 'get', $Name, $Property)).Output.Trim()
    if ($raw -match 'Value:\s*(.+)$') {
        $val = $Matches[1].Trim()
        if ($val -and $val -notmatch 'No value set|^$') { return $val }
    }
    return $null
}

function Test-CtgGuestAdditionsReady {
    param([string]$Name, [string]$VBoxManage)
    if ((Get-CtgVmState -Name $Name -VBoxManage $VBoxManage) -ne 'running') {
        return $false
    }
    foreach ($prop in @('/VirtualBox/GuestAdd/Version', '/VirtualBox/GuestAdd/GuestAddVersion')) {
        if (Get-CtgGuestPropertyValue -Name $Name -VBoxManage $VBoxManage -Property $prop) {
            return $true
        }
    }
    $info = (Invoke-CtgVBoxManage -VBoxManage $VBoxManage -Arguments @('showvminfo', $Name)).Output
    if ($info -match 'Guest Additions:\s*(\d+\.\d+)') { return $true }
    return $false
}

function Test-CtgGuestDesktopReady {
    param([string]$Name, [string]$VBoxManage)
    if ((Get-CtgVmState -Name $Name -VBoxManage $VBoxManage) -ne 'running') {
        return $false
    }
    $noUsers = Get-CtgGuestPropertyValue -Name $Name -VBoxManage $VBoxManage -Property '/VirtualBox/GuestInfo/OS/NoLoggedInUsers'
    if ($noUsers -eq 'true') { return $false }
    $count = Get-CtgGuestPropertyValue -Name $Name -VBoxManage $VBoxManage -Property '/VirtualBox/GuestInfo/OS/LoggedInUsers'
    if ($count -match '^\d+$' -and [int]$count -gt 0) { return $true }
    $users = Get-CtgGuestPropertyValue -Name $Name -VBoxManage $VBoxManage -Property '/VirtualBox/GuestInfo/OS/LoggedInUsersList'
    if ($users -and $users -notmatch 'No value set') { return $true }
    return $false
}

function Test-CtgSeamlessFacilityActive {
    param([string]$Name, [string]$VBoxManage)
    $info = (Invoke-CtgVBoxManage -VBoxManage $VBoxManage -Arguments @('showvminfo', $Name)).Output
    return ($info -match 'Facility "Seamless Mode":\s*active')
}

function Get-CtgExtradataValue {
    param([string]$Name, [string]$VBoxManage, [string]$Key)
    $raw = (Invoke-CtgVBoxManage -VBoxManage $VBoxManage -Arguments @('getextradata', $Name, $Key)).Output.Trim()
    if ($raw -match 'Value:\s*(.+)$') { return $Matches[1].Trim() }
    if ($raw -notmatch 'No value set') { return $raw }
    return $null
}

function Set-CtgSeamlessExtradata {
    param([string]$Name, [string]$VBoxManage)
    if ($SkipExtradata) { return $true }
    Write-CtgSeamlessLog "Setting extradata GUI/Seamless=on on $Name (auto-enter when Guest Additions + desktop ready)"
    if ($WhatIf) {
        Write-CtgSeamlessLog ('[WhatIf] setextradata ' + $Name + ' GUI/Seamless on')
        Write-CtgSeamlessLog ('[WhatIf] setextradata ' + $Name + ' GUI/SeamlessMode 1')
        return $true
    }
    foreach ($pair in @(@('GUI/Seamless', 'on'), @('GUI/SeamlessMode', '1'))) {
        $result = Invoke-CtgVBoxManage -VBoxManage $VBoxManage -Arguments @('setextradata', $Name, $pair[0], $pair[1])
        if ($result.Output.Trim()) {
            Write-CtgSeamlessLog $result.Output.Trim()
        }
    }
    $seamless = Get-CtgExtradataValue -Name $Name -VBoxManage $VBoxManage -Key 'GUI/Seamless'
    if ($seamless -ne 'on') {
        Write-CtgSeamlessLog "WARNING: GUI/Seamless extradata is '$seamless' (expected on) - close other VBoxManage sessions and re-run"
        return $false
    }
    return $true
}

function Test-CtgVBoxControlvmSeamlessSupported {
    param([string]$VBoxManage)
    $ver = Get-CtgVBoxHostVersion -VBoxManage $VBoxManage
    return ($ver.Major -lt 7)
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

function Write-CtgDesktopLoginHint {
    Write-CtgSeamlessLog 'WARNING: No graphical login in Kali - log in to GNOME/X11 at the VM console, then press Host+L or re-run this script.'
    Write-CtgSeamlessLog 'Guest fix: sudo bash /mnt/ctg/kali-boot-autopatch.sh (ensures vboxservice + X11)'
}

function Wait-CtgGuestDesktop {
    param(
        [string]$Name,
        [string]$VBoxManage,
        [int]$WaitSec
    )
    if ($WaitSec -le 0) { return (Test-CtgGuestDesktopReady -Name $Name -VBoxManage $VBoxManage) }
    Write-CtgSeamlessLog "Waiting up to ${WaitSec}s for Kali graphical login ..."
    $deadline = (Get-Date).AddSeconds($WaitSec)
    while ((Get-Date) -lt $deadline) {
        if (Test-CtgGuestDesktopReady -Name $Name -VBoxManage $VBoxManage) {
            Write-CtgSeamlessLog 'Guest desktop session detected (LoggedInUsers > 0)'
            return $true
        }
        Start-Sleep -Seconds 5
    }
    return $false
}

function Get-CtgSeamlessDiagnostics {
    param([string]$Name, [string]$VBoxManage)
    $ver = Get-CtgVBoxHostVersion -VBoxManage $VBoxManage
    $state = Get-CtgVmState -Name $Name -VBoxManage $VBoxManage
    $info = (Invoke-CtgVBoxManage -VBoxManage $VBoxManage -Arguments @('showvminfo', $Name)).Output
    $vram = if ($info -match 'VRAM size:\s*(\d+)MB') { $Matches[1] + 'MB' } else { 'unknown' }
    $gfx = if ($info -match 'Graphics Controller:\s*(\S+)') { $Matches[1] } else { 'unknown' }
    $gaVer = Get-CtgGuestPropertyValue -Name $Name -VBoxManage $VBoxManage -Property '/VirtualBox/GuestAdd/Version'
    $gaReady = Test-CtgGuestAdditionsReady -Name $Name -VBoxManage $VBoxManage
    $desktop = Test-CtgGuestDesktopReady -Name $Name -VBoxManage $VBoxManage
    $seamlessActive = Test-CtgSeamlessFacilityActive -Name $Name -VBoxManage $VBoxManage
    $extradataSeamless = Get-CtgExtradataValue -Name $Name -VBoxManage $VBoxManage -Key 'GUI/Seamless'
    $extradataMode = Get-CtgExtradataValue -Name $Name -VBoxManage $VBoxManage -Key 'GUI/SeamlessMode'
    $session = if ($info -match 'Session name:\s*(.+)') { $Matches[1].Trim() } else { 'none' }
    $issues = @()
    if (-not $gaReady) { $issues += 'Guest Additions not reporting (install virtualbox-guest-x11)' }
    if ($state -eq 'running' -and -not $desktop) { $issues += 'No graphical login - log in at Kali console' }
    if ($extradataSeamless -ne 'on') { $issues += 'GUI/Seamless extradata not on (script sets this)' }
    if ($vram -ne '128MB') { $issues += "VRAM is $vram (recommend 128MB - Fix-KaliBlankScreen.ps1)" }
    if ($gfx -notmatch 'VMSVGA|VBoxSVGA') { $issues += "Graphics controller is $gfx (recommend VMSVGA)" }
    if ($gaVer -and $ver.Raw -notmatch [regex]::Escape($gaVer.Split('.')[0])) {
        $issues += "Guest Additions $gaVer may not match host $($ver.Raw) - run kali-boot-autopatch.sh"
    }
    if ($state -eq 'running' -and $gaReady -and $desktop -and -not $seamlessActive) {
        $issues += 'Seamless facility inactive - press Host+L on Kali window (VB7 has no controlvm seamless)'
    }
    return [ordered]@{
        HostVBox       = $ver.Raw
        VmName         = $Name
        VmState        = $state
        Session        = $session
        Vram           = $vram
        Graphics       = $gfx
        GuestAdditions = if ($gaVer) { $gaVer } else { 'not detected' }
        GaReady        = $gaReady
        DesktopReady   = $desktop
        SeamlessActive = $seamlessActive
        ExtradataSeamless = $extradataSeamless
        ExtradataMode  = $extradataMode
        ControlvmSeamless = (Test-CtgVBoxControlvmSeamlessSupported -VBoxManage $VBoxManage)
        Issues         = $issues
    }
}

function Invoke-CtgSeamlessDiagnose {
    param([string]$Name, [string]$VBoxManage)
    $diag = Get-CtgSeamlessDiagnostics -Name $Name -VBoxManage $VBoxManage
    Write-CtgSeamlessLog '=== Kali seamless diagnose ==='
    foreach ($key in $diag.Keys) {
        if ($key -eq 'Issues') { continue }
        Write-CtgSeamlessLog ("  {0}: {1}" -f $key, $diag[$key])
    }
    if ($diag.Issues.Count -gt 0) {
        Write-CtgSeamlessLog 'Issues:'
        foreach ($issue in $diag.Issues) { Write-CtgSeamlessLog "  - $issue" }
        return 1
    }
    Write-CtgSeamlessLog 'Diagnose: all checks passed (toggle Host+L if seamless not visible)'
    return 0
}

function Enable-CtgSeamlessOnRunningVm {
    param(
        [string]$Name,
        [string]$VBoxManage,
        [int]$WaitSec = $DesktopWaitSec
    )
    if (-not (Test-CtgGuestAdditionsReady -Name $Name -VBoxManage $VBoxManage)) {
        Write-CtgGuestAdditionsHint
        Write-CtgSeamlessLog "VM $Name is running but Guest Additions missing - leaving normal windowed mode"
        return $false
    }
    if (Test-CtgSeamlessFacilityActive -Name $Name -VBoxManage $VBoxManage) {
        Write-CtgSeamlessLog "Seamless mode already active on $Name"
        return $true
    }
    if (-not (Wait-CtgGuestDesktop -Name $Name -VBoxManage $VBoxManage -WaitSec $WaitSec)) {
        Write-CtgDesktopLoginHint
        Write-CtgHostLHint -Name $Name
        return $false
    }
    if (Test-CtgVBoxControlvmSeamlessSupported -VBoxManage $VBoxManage) {
        Write-CtgSeamlessLog "Enabling seamless on running VM: $Name (legacy controlvm)"
        if ($WhatIf) {
            Write-CtgSeamlessLog ('[WhatIf] controlvm ' + $Name + ' seamless on')
            return $true
        }
        $result = Invoke-CtgVBoxManage -VBoxManage $VBoxManage -Arguments @('controlvm', $Name, 'seamless', 'on')
        if ($result.ExitCode -eq 0 -and $result.Output -notmatch 'error|VBOX_E|Invalid parameter') {
            Write-CtgSeamlessLog "Seamless mode enabled on $Name (Host+L toggles)"
            return $true
        }
        Write-CtgSeamlessLog "controlvm seamless on unavailable: $($result.Output.Trim())"
    }
    Write-CtgSeamlessLog "VM $Name running with Guest Additions + desktop - extradata GUI/Seamless=on set"
    Write-CtgHostLHint -Name $Name
    return $true
}

function Start-CtgKaliSeamless {
    param(
        [string]$Name = $VmName,
        [string]$VBoxManage = '',
        [int]$WaitSec = $GuestAdditionsWaitSec,
        [int]$DesktopSec = $DesktopWaitSec,
        [switch]$WhatIfParam,
        [switch]$DiagnoseOnlyParam
    )
    if ($WhatIfParam) { $script:WhatIf = $true }
    if ($DiagnoseOnlyParam) { $script:DiagnoseOnly = $true }

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

    if ($DiagnoseOnly) {
        return (Invoke-CtgSeamlessDiagnose -Name $Name -VBoxManage $VBoxManage)
    }

    Set-CtgSeamlessExtradata -Name $Name -VBoxManage $VBoxManage | Out-Null

    $state = Get-CtgVmState -Name $Name -VBoxManage $VBoxManage
    Write-CtgSeamlessLog "VM $Name state: $state"

    if ($state -eq 'running') {
        if (Enable-CtgSeamlessOnRunningVm -Name $Name -VBoxManage $VBoxManage -WaitSec $DesktopSec) { return 0 }
        return 1
    }

    if ($state -notin @('poweroff', 'saved', 'aborted')) {
        Write-CtgSeamlessLog "VM $Name is $state - cannot start (wait or power off first)"
        return 2
    }

    Write-CtgSeamlessLog "Starting $Name (seamless via GUI/Seamless extradata + --type gui)"
    if ($WhatIf) {
        Write-CtgSeamlessLog ('[WhatIf] startvm ' + $Name + ' --type gui')
        return 0
    }

    $startOut = (Invoke-CtgVBoxManage -VBoxManage $VBoxManage -Arguments @('startvm', $Name, '--type', 'seamless')).Output
    if ($startOut -notmatch 'error|VBOX_E|Invalid|failed|already locked') {
        Write-CtgSeamlessLog "Started $Name with --type seamless (legacy VirtualBox)"
        return 0
    }

    if ($startOut -match 'Invalid|--type|already locked') {
        if ($startOut -match 'already locked') {
            Write-CtgSeamlessLog 'VM already has a GUI session - ensuring seamless on running VM instead of second start'
            if (Enable-CtgSeamlessOnRunningVm -Name $Name -VBoxManage $VBoxManage -WaitSec $DesktopSec) { return 0 }
            return 1
        }
        Write-CtgSeamlessLog 'VirtualBox 7: --type seamless not available - using --type gui + GUI/Seamless=on'
    } else {
        Write-CtgSeamlessLog "Seamless start failed ($($startOut.Trim())) - fallback: gui + Guest Additions check"
    }

    $guiOut = (Invoke-CtgVBoxManage -VBoxManage $VBoxManage -Arguments @('startvm', $Name, '--type', 'gui')).Output
    if ($guiOut -match 'already locked') {
        Write-CtgSeamlessLog 'GUI start skipped - VM locked by existing VirtualBox session'
        if (Enable-CtgSeamlessOnRunningVm -Name $Name -VBoxManage $VBoxManage -WaitSec $DesktopSec) { return 0 }
        return 1
    }
    if ($guiOut -match 'error|VBOX_E|failed') {
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

    if (-not $gaReady) {
        Write-CtgGuestAdditionsHint
        Write-CtgSeamlessLog "Started $Name in normal GUI - install Guest Additions then re-run Start-KaliSeamless.ps1"
        return 1
    }

    if (Enable-CtgSeamlessOnRunningVm -Name $Name -VBoxManage $VBoxManage -WaitSec $DesktopSec) {
        return 0
    }
    return 1
}

$script:IsDotSourced = ($MyInvocation.InvocationName -eq '.')
if (-not $script:IsDotSourced) {
    $exitCode = Start-CtgKaliSeamless -Name $VmName -WaitSec $GuestAdditionsWaitSec -DesktopSec $DesktopWaitSec -DiagnoseOnlyParam:$DiagnoseOnly
    if ($null -ne $exitCode) { exit $exitCode }
}
