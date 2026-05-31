# Start VirtualBox Kali VM in seamless mode (Guest Additions + graphical login required).
# Authorized defensive lab use only - Hacker Planet LLC - Philadelphia, PA
param(
    [string]$VmName = 'kali',
    [string[]]$VmNameCandidates = @('kali', 'Kali-Lab', 'Kali', 'kali-linux'),
    [int]$GuestAdditionsWaitSec = 60,
    [int]$DesktopWaitSec = 120,
    [ValidateSet('Seamless', 'Scaled', 'Gui')]
    [string]$DisplayMode = 'Seamless',
    [switch]$SkipExtradata,
    [switch]$NoShowHostToolbar,
    [switch]$DiagnoseOnly,
    [switch]$WhatIf,
    [switch]$EnsureGuiSession,
    [switch]$NoEnsureGuiSession,
    [switch]$ApplyExtradata
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


function Enable-CtgGuiSession {
    param([string]$Name, [string]$VBoxManage)
    if ((Get-CtgVmState -Name $Name -VBoxManage $VBoxManage) -ne 'running') { return $true }
    $info = (Invoke-CtgVBoxManage -VBoxManage $VBoxManage -Arguments @('showvminfo', $Name)).Output
    $session = if ($info -match 'Session name:\s*(.+)') { $Matches[1].Trim() } else { 'none' }
    if ($session -notmatch 'headless|none|^$') {
        Write-CtgSeamlessLog "GUI session already present: $session"
        return $true
    }
    Write-CtgSeamlessLog "No GUI session ($session) - attaching VirtualBox window via startvm --type gui"
    if ($WhatIf) {
        Write-CtgSeamlessLog ('[WhatIf] startvm ' + $Name + ' --type gui')
        return $true
    }
    $guiOut = (Invoke-CtgVBoxManage -VBoxManage $VBoxManage -Arguments @('startvm', $Name, '--type', 'gui')).Output
    if ($guiOut -match 'already locked') {
        Write-CtgSeamlessLog 'GUI attach: VM already has a GUI lock (open VirtualBox Manager window for kali)'
        return $true
    }
    if ($guiOut -match 'error|VBOX_E|failed') {
        Write-CtgSeamlessLog ("GUI attach failed: " + $guiOut.Trim())
        return $false
    }
    Start-Sleep -Seconds 2
    return $true
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

function Test-CtgExtradataTruthy {
    param([string]$Value)
    if (-not $Value) { return $false }
    $v = $Value.ToLowerInvariant()
    return $v -in @('on', 'true', '1', 'yes')
}

function Get-CtgGuiExtradataSnapshot {
    param([string]$Name, [string]$VBoxManage)
    $keys = @('GUI/Seamless', 'GUI/SeamlessMode', 'GUI/ShowMiniToolBar', 'GUI/MiniToolBarAutoHide', 'GUI/MiniToolBarAlignment', 'GUI/AutoresizeGuest', 'GUI/Scale', 'GUI/LastGuestSizeHint', 'GUI/SuppressMessages', 'GUI/GlobalMenuBar')
    $snap = [ordered]@{}
    foreach ($key in $keys) {
        $snap[$key] = Get-CtgExtradataValue -Name $Name -VBoxManage $VBoxManage -Key $key
    }
    return $snap
}

function Set-CtgHostToolbarExtradata {
    param([string]$Name, [string]$VBoxManage, [switch]$Enable)
    if ($SkipExtradata) { return $true }
    if (-not $Enable) {
        Write-CtgSeamlessLog 'Host mini toolbar extradata skipped (-NoShowHostToolbar)'
        return $true
    }
    Write-CtgSeamlessLog "Setting extradata GUI/ShowMiniToolBar=true on $Name"
    if ($WhatIf) {
        Write-CtgSeamlessLog ('[WhatIf] setextradata ' + $Name + ' GUI/ShowMiniToolBar true')
        return $true
    }
    $result = Invoke-CtgVBoxManage -VBoxManage $VBoxManage -Arguments @('setextradata', $Name, 'GUI/ShowMiniToolBar', 'true')
    if ($result.Output.Trim()) { Write-CtgSeamlessLog $result.Output.Trim() }
    $val = Get-CtgExtradataValue -Name $Name -VBoxManage $VBoxManage -Key 'GUI/ShowMiniToolBar'
    if (-not (Test-CtgExtradataTruthy -Value $val)) {
        Write-CtgSeamlessLog "WARNING: GUI/ShowMiniToolBar is '$val' - use Host+Home (Right Ctrl+Home) for VM menu"
        return $false
    }
    return $true
}

function Set-CtgExtradataPair {
    param([string]$Name, [string]$VBoxManage, [string]$Key, [string]$Value)
    if ($WhatIf) {
        Write-CtgSeamlessLog ('[WhatIf] setextradata ' + $Name + ' ' + $Key + ' ' + $Value)
        return
    }
    $result = Invoke-CtgVBoxManage -VBoxManage $VBoxManage -Arguments @('setextradata', $Name, $Key, $Value)
    if ($result.Output.Trim()) { Write-CtgSeamlessLog $result.Output.Trim() }
    Write-CtgSeamlessLog ("  extradata {0} = {1}" -f $Key, $Value)
}

function Test-CtgGuestSizeHintOversized {
    param([string]$Hint)
    if (-not $Hint) { return $false }
    if ($Hint -match '^(\d+),(\d+)') {
        $w = [int]$Matches[1]
        $h = [int]$Matches[2]
        return ($w -gt 2560 -or $h -gt 1600)
    }
    return $false
}

function Clear-CtgBadGuestSizeHint {
    # Huge LastGuestSizeHint (e.g. 3428,1660) makes guest UI tiny on 150% Windows hosts.
    param([string]$Name, [string]$VBoxManage)
    if ($SkipExtradata) { return }
    $hint = Get-CtgExtradataValue -Name $Name -VBoxManage $VBoxManage -Key 'GUI/LastGuestSizeHint'
    if (-not (Test-CtgGuestSizeHintOversized -Hint $hint)) {
        if ($hint) {
            Write-CtgSeamlessLog "GUI/LastGuestSizeHint OK: $hint"
        }
        return
    }
    Write-CtgSeamlessLog "Clearing oversized GUI/LastGuestSizeHint ($hint) — causes tiny terminal/UI in guest"
    if ($WhatIf) {
        Write-CtgSeamlessLog ('[WhatIf] setextradata ' + $Name + ' GUI/LastGuestSizeHint (delete)')
        return
    }
    $result = Invoke-CtgVBoxManage -VBoxManage $VBoxManage -Arguments @('setextradata', $Name, 'GUI/LastGuestSizeHint')
    if ($result.Output.Trim()) { Write-CtgSeamlessLog $result.Output.Trim() }
    Write-CtgSeamlessLog '  extradata GUI/LastGuestSizeHint cleared (AutoresizeGuest will set fresh hint)'
}

function Set-CtgCommonGuiExtradata {
    # Applied in every mode - autoresize prevents wrap/clip; mini-toolbar keys help full-screen.
    param([string]$Name, [string]$VBoxManage)
    if ($SkipExtradata) { return }
    Set-CtgExtradataPair -Name $Name -VBoxManage $VBoxManage -Key 'GUI/AutoresizeGuest' -Value 'true'
    Clear-CtgBadGuestSizeHint -Name $Name -VBoxManage $VBoxManage
}

function Set-CtgMiniToolbarExtradata {
    param([string]$Name, [string]$VBoxManage)
    if ($SkipExtradata -or $NoShowHostToolbar) { return }
    Write-CtgSeamlessLog "Configuring mini toolbar (top, always visible) on $Name"
    Set-CtgExtradataPair -Name $Name -VBoxManage $VBoxManage -Key 'GUI/ShowMiniToolBar' -Value 'true'
    Set-CtgExtradataPair -Name $Name -VBoxManage $VBoxManage -Key 'GUI/MiniToolBarAutoHide' -Value 'false'
    Set-CtgExtradataPair -Name $Name -VBoxManage $VBoxManage -Key 'GUI/MiniToolBarAlignment' -Value 'top'
}

function Set-CtgSeamlessExtradata {
    param([string]$Name, [string]$VBoxManage, [string]$Mode = 'Seamless')
    if ($SkipExtradata) { return $true }
    Set-CtgCommonGuiExtradata -Name $Name -VBoxManage $VBoxManage
    if ($Mode -eq 'Scaled' -or $Mode -eq 'Gui') {
        Write-CtgSeamlessLog "DisplayMode=$Mode - normal/scaled window with full menu bar + scrollbars (clearing GUI/Seamless)"
        Set-CtgExtradataPair -Name $Name -VBoxManage $VBoxManage -Key 'GUI/Seamless' -Value 'off'
        if ($Mode -eq 'Scaled') {
            Set-CtgExtradataPair -Name $Name -VBoxManage $VBoxManage -Key 'GUI/Scale' -Value 'true'
        } else {
            # Normal windowed: real scrollbars when guest > window
            Set-CtgExtradataPair -Name $Name -VBoxManage $VBoxManage -Key 'GUI/Scale' -Value 'false'
        }
        return $true
    }
    Write-CtgSeamlessLog "Setting extradata GUI/Seamless=on on $Name (Scale off — scaled+seamless together causes glitch-revert)"
    Set-CtgExtradataPair -Name $Name -VBoxManage $VBoxManage -Key 'GUI/Seamless' -Value 'on'
    Set-CtgExtradataPair -Name $Name -VBoxManage $VBoxManage -Key 'GUI/SeamlessMode' -Value '1'
    Set-CtgExtradataPair -Name $Name -VBoxManage $VBoxManage -Key 'GUI/Scale' -Value 'false'
    if ($WhatIf) { return $true }
    $seamless = Get-CtgExtradataValue -Name $Name -VBoxManage $VBoxManage -Key 'GUI/Seamless'
    if (-not (Test-CtgExtradataTruthy -Value $seamless)) {
        Write-CtgSeamlessLog "WARNING: GUI/Seamless extradata is '$seamless' (expected on/true) - close other VBoxManage sessions and re-run"
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

function Write-CtgHostToolbarHint {
    Write-CtgSeamlessLog 'Host toolbar: top screen edge for mini toolbar (pin thumbtack), or Host+Home (Right Ctrl+Home) for full VM menu'
    Write-CtgSeamlessLog 'Guest panel: bash /mnt/ctg/ctg-seamless-guest.sh - see docs/KALI_SEAMLESS_MODE.md'
    Write-CtgSeamlessLog 'Guest scale: bash /mnt/ctg/ctg-display-scale.sh - see docs/KALI_DISPLAY_SCALING.md'
}

function Write-CtgGuestAdditionsHint {
    Write-CtgSeamlessLog 'WARNING: Guest Additions not ready - seamless mode unavailable.'
    Write-CtgSeamlessLog 'Fix in Kali: sudo bash /mnt/ctg/kali-boot-autopatch.sh --install'
    Write-CtgSeamlessLog 'Or: sudo bash /mnt/ctg/fix-kali-blank-screen.sh'
    Write-CtgSeamlessLog 'Host deploy: .\scripts\windows\Deploy-KaliBootAutopatch.ps1'
    Write-CtgSeamlessLog 'Docs: docs/KALI_SEAMLESS_MODE.md'
}

function Write-CtgDesktopLoginHint {
    Write-CtgSeamlessLog 'WARNING: No graphical login in Kali - log in to GNOME/X11 at the VM console, then press Host+L or re-run this script.'
    Write-CtgSeamlessLog 'Guest fix: sudo bash /mnt/ctg/kali-boot-autopatch.sh (ensures vboxservice + X11)'
}

function Write-CtgGlitchRevertFix {
    Write-CtgSeamlessLog 'GLITCH-REVERT: seamless was requested but the guest dropped back to windowed/scaled.'
    Write-CtgSeamlessLog 'Most common causes: Wayland session (need X11/Xorg) or VBoxClient --seamless not running.'
    Write-CtgSeamlessLog 'In Kali after GUI login (choose Xfce session, not Wayland):'
    Write-CtgSeamlessLog '  bash /mnt/ctg/ctg-seamless-guest.sh'
    Write-CtgSeamlessLog 'Then on Windows: press Host+L once. Seamless should stay on.'
    Write-CtgSeamlessLog 'Docs: docs/KALI_SEAMLESS_MODE.md'
}

function Test-CtgSeamlessPreflight {
    param([string]$Name, [string]$VBoxManage)
    if ((Get-CtgVmState -Name $Name -VBoxManage $VBoxManage) -ne 'running') {
        return $true
    }
    if (-not (Test-CtgGuestAdditionsReady -Name $Name -VBoxManage $VBoxManage)) {
        Write-CtgGuestAdditionsHint
        return $false
    }
    if (-not (Test-CtgGuestDesktopReady -Name $Name -VBoxManage $VBoxManage)) {
        Write-CtgDesktopLoginHint
        return $false
    }
    return $true
}

function Wait-CtgSeamlessFacilityStable {
    param(
        [string]$Name,
        [string]$VBoxManage,
        [int]$PollSec = 12,
        [int]$IntervalSec = 2
    )
    if ($PollSec -le 0) {
        return (Test-CtgSeamlessFacilityActive -Name $Name -VBoxManage $VBoxManage)
    }
    Write-CtgSeamlessLog "Polling up to ${PollSec}s for Seamless facility to stay active ..."
    $deadline = (Get-Date).AddSeconds($PollSec)
    $seenActive = $false
    while ((Get-Date) -lt $deadline) {
        if (Test-CtgSeamlessFacilityActive -Name $Name -VBoxManage $VBoxManage) {
            $seenActive = $true
        } elseif ($seenActive) {
            Write-CtgSeamlessLog 'Seamless facility went active then inactive (glitch-revert detected)'
            return $false
        }
        Start-Sleep -Seconds $IntervalSec
    }
    if ($seenActive) {
        Write-CtgSeamlessLog 'Seamless facility stable (active)'
        return $true
    }
    return $false
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
    $guiExtra = Get-CtgGuiExtradataSnapshot -Name $Name -VBoxManage $VBoxManage
    $extradataSeamless = $guiExtra['GUI/Seamless']
    $extradataMode = $guiExtra['GUI/SeamlessMode']
    $extradataMiniTb = $guiExtra['GUI/ShowMiniToolBar']
    $session = if ($info -match 'Session name:\s*(.+)') { $Matches[1].Trim() } else { 'none' }
    $sessionType = if ($info -match 'Session type:\s*(.+)') { $Matches[1].Trim() } else { 'unknown' }
    $loggedInCount = Get-CtgGuestPropertyValue -Name $Name -VBoxManage $VBoxManage -Property '/VirtualBox/GuestInfo/OS/LoggedInUsers'
    $isHeadlessSession = ($state -eq 'running' -and ($session -match 'headless|^none$|^$'))
    $issues = @()
    if ($isHeadlessSession) { $issues += 'No GUI session (headless/none) - VirtualBox View menu disabled until startvm --type gui (-EnsureGuiSession)' }
    if ($state -eq 'running' -and $loggedInCount -eq '0') { $issues += 'View→Seamless grayed out: LoggedInUsers=0 - log in to Xfce/X11 desktop in the VM window, then Host+L' }
    if ($state -eq 'running' -and -not $gaReady) { $issues += 'Guest Additions not reporting (install virtualbox-guest-x11)' }
    if ($state -eq 'running' -and -not $desktop) { $issues += 'No graphical login (guest property) - log in at Kali console if desktop is blank' }
    if ($DisplayMode -eq 'Seamless' -and -not $seamlessActive -and -not (Test-CtgExtradataTruthy -Value $extradataSeamless)) {
        $issues += "GUI/Seamless extradata not enabled (got '$extradataSeamless')"
    }
    if (-not $NoShowHostToolbar -and -not (Test-CtgExtradataTruthy -Value $extradataMiniTb)) {
        $issues += "GUI/ShowMiniToolBar is '$extradataMiniTb' - host mini toolbar hidden; re-run without -NoShowHostToolbar"
    }
    if ($DisplayMode -eq 'Seamless' -and $seamlessActive) {
        $issues += 'Seamless facility ACTIVE — if menu toggle still reverts, run bash /mnt/ctg/ctg-seamless-guest.sh in Kali (X11 + VBoxClient)'
    }
    if (-not (Test-CtgExtradataTruthy -Value $guiExtra['GUI/AutoresizeGuest'])) {
        $issues += "GUI/AutoresizeGuest is '$($guiExtra['GUI/AutoresizeGuest'])' - guest may wrap/clip; script sets this true"
    }
    if (Test-CtgGuestSizeHintOversized -Hint $guiExtra['GUI/LastGuestSizeHint']) {
        $issues += "GUI/LastGuestSizeHint is '$($guiExtra['GUI/LastGuestSizeHint'])' — tiny UI; script clears hints >2560×1600"
    }
    if ($vram -ne '128MB') { $issues += "VRAM is $vram (recommend 128MB - Fix-KaliBlankScreen.ps1)" }
    if ($gfx -notmatch 'VMSVGA|VBoxSVGA') { $issues += "Graphics controller is $gfx (recommend VMSVGA)" }
    if ($gaVer -and $ver.Raw -notmatch [regex]::Escape($gaVer.Split('.')[0])) {
        $issues += "Guest Additions $gaVer may not match host $($ver.Raw) - run kali-boot-autopatch.sh"
    }
    if ($state -eq 'running' -and $gaReady -and $desktop -and -not $seamlessActive -and (Test-CtgExtradataTruthy -Value $extradataSeamless)) {
        $issues += 'GLITCH-REVERT: GUI/Seamless on but Seamless facility INACTIVE. Cause is almost always a Wayland session or VBoxClient --seamless not running. In Kali run: bash /mnt/ctg/ctg-seamless-guest.sh (forces X11 + restarts VBoxClient)'
    }
    return [ordered]@{
        HostVBox       = $ver.Raw
        VmName         = $Name
        VmState        = $state
        Session        = $session
        SessionType    = $sessionType
        Vram           = $vram
        Graphics       = $gfx
        GuestAdditions = if ($gaVer) { $gaVer } else { 'not detected' }
        GaReady        = $gaReady
        DesktopReady   = $desktop
        SeamlessActive = $seamlessActive
        ExtradataSeamless = $extradataSeamless
        ExtradataMode  = $extradataMode
        ExtradataShowMiniToolBar = $extradataMiniTb
        ExtradataMiniToolBarAutoHide = $guiExtra['GUI/MiniToolBarAutoHide']
        ExtradataMiniToolBarAlignment = $guiExtra['GUI/MiniToolBarAlignment']
        ExtradataAutoresizeGuest = $guiExtra['GUI/AutoresizeGuest']
        ExtradataScale = $guiExtra['GUI/Scale']
        ExtradataLastGuestSizeHint = $guiExtra['GUI/LastGuestSizeHint']
        ExtradataSuppressMessages = $guiExtra['GUI/SuppressMessages']
        ExtradataGlobalMenuBar = $guiExtra['GUI/GlobalMenuBar']
        DisplayModeParam = $DisplayMode
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
    Write-CtgSeamlessLog 'Diagnose: all checks passed (Host+L seamless, Host+Home menu, top-edge mini toolbar)'
    Write-CtgHostToolbarHint
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
        Write-CtgSeamlessLog "VM $Name is running but Guest Additions missing - seamless will revert"
        return $false
    }
    if (-not (Test-CtgGuestDesktopReady -Name $Name -VBoxManage $VBoxManage)) {
        if (-not (Wait-CtgGuestDesktop -Name $Name -VBoxManage $VBoxManage -WaitSec $WaitSec)) {
            Write-CtgDesktopLoginHint
            return $false
        }
    }
    if (Test-CtgSeamlessFacilityActive -Name $Name -VBoxManage $VBoxManage) {
        Write-CtgSeamlessLog "Seamless mode already active on $Name"
        if (Wait-CtgSeamlessFacilityStable -Name $Name -VBoxManage $VBoxManage -PollSec 4) {
            return $true
        }
        Write-CtgGlitchRevertFix
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
            Write-CtgHostToolbarHint
            return $true
        }
        Write-CtgSeamlessLog "controlvm seamless on unavailable: $($result.Output.Trim())"
    }
    Write-CtgSeamlessLog "VM $Name ready — extradata GUI/Seamless=on, GUI/Scale=false. Press Host+L to enter seamless."
    Write-CtgHostLHint -Name $Name
    Write-CtgGlitchRevertFix
    if (Wait-CtgSeamlessFacilityStable -Name $Name -VBoxManage $VBoxManage -PollSec 8) {
        return $true
    }
    return $false
}

function Start-CtgKaliSeamless {
    param(
        [string]$Name = $VmName,
        [string]$VBoxManage = '',
        [int]$WaitSec = $GuestAdditionsWaitSec,
        [int]$DesktopSec = $DesktopWaitSec,
        [string]$Mode = $DisplayMode,
        [switch]$WhatIfParam,
        [switch]$DiagnoseOnlyParam,
        [switch]$NoShowHostToolbarParam
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
        if ($ApplyExtradata -and $DisplayMode -eq 'Seamless') {
            Set-CtgSeamlessExtradata -Name $Name -VBoxManage $VBoxManage -Mode $DisplayMode | Out-Null
        }
        return (Invoke-CtgSeamlessDiagnose -Name $Name -VBoxManage $VBoxManage)
    }

    $wantGuiSession = $EnsureGuiSession -and -not $NoEnsureGuiSession
    if ($wantGuiSession -and (Get-CtgVmState -Name $Name -VBoxManage $VBoxManage) -eq 'running') {
        Enable-CtgGuiSession -Name $Name -VBoxManage $VBoxManage | Out-Null
    }

    Set-CtgSeamlessExtradata -Name $Name -VBoxManage $VBoxManage -Mode $Mode | Out-Null
    if (-not $NoShowHostToolbarParam) {
        Set-CtgMiniToolbarExtradata -Name $Name -VBoxManage $VBoxManage
    }
    if ($Mode -eq 'Seamless') {
        Write-CtgSeamlessLog 'Seamless preflight: needs graphical X11 login + VBoxClient --seamless in guest.'
        Write-CtgSeamlessLog 'Before Host+L in Kali run: bash /mnt/ctg/ctg-seamless-guest.sh (fixes Wayland glitch-revert)'
        Write-CtgSeamlessLog 'For visible menu/scrollbars use -DisplayMode Scaled (does not disable seamless)'
    }

    $state = Get-CtgVmState -Name $Name -VBoxManage $VBoxManage
    Write-CtgSeamlessLog "VM $Name state: $state"

    if ($state -eq 'running') {
        if ($Mode -ne 'Seamless') {
            Write-CtgSeamlessLog "VM running in $Mode mode - use Host+L or View menu to adjust display"
            Write-CtgHostToolbarHint
            return 0
        }
        if (Enable-CtgSeamlessOnRunningVm -Name $Name -VBoxManage $VBoxManage -WaitSec $DesktopSec) {
            return 0
        }
        return 1
    }

    if ($state -notin @('poweroff', 'saved', 'aborted')) {
        Write-CtgSeamlessLog "VM $Name is $state - cannot start (wait or power off first)"
        return 2
    }

    if ($Mode -eq 'Scaled') {
        Write-CtgSeamlessLog "Starting $Name (scaled window - GUI/Seamless off; Host+L for seamless later)"
    } else {
        Write-CtgSeamlessLog "Starting $Name (seamless via GUI/Seamless extradata + --type gui)"
    }
    if ($WhatIf) {
        Write-CtgSeamlessLog ('[WhatIf] startvm ' + $Name + ' --type gui')
        return 0
    }

    $startOut = (Invoke-CtgVBoxManage -VBoxManage $VBoxManage -Arguments @('startvm', $Name, '--type', 'seamless')).Output
    if ($startOut -notmatch 'error|VBOX_E|Invalid|failed|already locked') {
        Write-CtgSeamlessLog "Started $Name with --type seamless (legacy VirtualBox)"
        Write-CtgHostToolbarHint
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

    if ($Mode -eq 'Seamless' -and (Enable-CtgSeamlessOnRunningVm -Name $Name -VBoxManage $VBoxManage -WaitSec $DesktopSec)) {
        return 0
    }
    if ($Mode -ne 'Seamless') {
        Write-CtgHostToolbarHint
        return 0
    }
    return 1
}

$script:IsDotSourced = ($MyInvocation.InvocationName -eq '.')
if (-not $script:IsDotSourced) {
    $exitCode = Start-CtgKaliSeamless -Name $VmName -WaitSec $GuestAdditionsWaitSec -DesktopSec $DesktopWaitSec -Mode $DisplayMode -DiagnoseOnlyParam:$DiagnoseOnly -NoShowHostToolbarParam:$NoShowHostToolbar
    if ($null -ne $exitCode) { exit $exitCode }
}
