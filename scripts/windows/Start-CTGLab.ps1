# CyberThreatGotchi - master CTG Lab autorun (Windows host).
# Authorized defensive lab use only - Hacker Planet LLC · Philadelphia, PA.
# Orchestrates: Defender pause (optional), DDG preserve, Kali deploy, Wireshark, OPNsense stub.
param(
    [switch]$SkipDefender,
    [switch]$SkipOpnsense,
    [switch]$FullBootstrap,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Continue'
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$LogDir = 'C:\Users\Owner\Backups\logs'
$LogFile = Join-Path $LogDir 'ctg-lab-autorun.log'
$DefenderWasPaused = $false

function Write-CtgAutorunLog([string]$Message) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Host $line
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Test-CtgIsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-CtgDefenderPauseIfNeeded {
    if ($SkipDefender) {
        Write-CtgAutorunLog 'Defender pause: SKIPPED (-SkipDefender)'
        return
    }
    $pauseScript = Join-Path $PSScriptRoot 'Pause-DefenderRealtime.ps1'
    if (-not (Test-Path $pauseScript)) {
        Write-CtgAutorunLog 'Pause-DefenderRealtime.ps1 not found - skip pause'
        return
    }
    if (-not (Test-CtgIsAdmin)) {
        Write-CtgAutorunLog 'Defender pause: not Admin - skip (run elevated for build windows)'
        return
    }
    Write-CtgAutorunLog 'Defender: pausing real-time protection for lab deploy window'
    if ($WhatIf) {
        Write-CtgAutorunLog '[WhatIf] Pause-DefenderRealtime.ps1 -Pause'
        $script:DefenderWasPaused = $true
        return
    }
    try {
        & $pauseScript -Pause
        $script:DefenderWasPaused = $true
        Write-CtgAutorunLog 'Defender: paused (will resume at end of autorun)'
    } catch {
        Write-CtgAutorunLog "Defender pause failed (non-blocking): $($_.Exception.Message)"
    }
}

function Invoke-CtgDefenderResumeIfNeeded {
    if (-not $DefenderWasPaused) { return }
    $pauseScript = Join-Path $PSScriptRoot 'Pause-DefenderRealtime.ps1'
    if (-not (Test-Path $pauseScript)) { return }
    if (-not (Test-CtgIsAdmin)) {
        Write-CtgAutorunLog 'Defender resume: not Admin - run: .\Pause-DefenderRealtime.ps1 -Resume'
        return
    }
    Write-CtgAutorunLog 'Defender: resuming real-time protection'
    if ($WhatIf) {
        Write-CtgAutorunLog '[WhatIf] Pause-DefenderRealtime.ps1 -Resume'
        return
    }
    try {
        & $pauseScript -Resume
        Write-CtgAutorunLog 'Defender: resumed'
    } catch {
        Write-CtgAutorunLog "Defender resume failed: $($_.Exception.Message) - run -Resume manually"
    }
}

function Invoke-CtgDdgPreserve {
    $preserveScript = Join-Path $PSScriptRoot 'Preserve-DuckDuckGoVpn.ps1'
    if (-not (Test-Path $preserveScript)) {
        Write-CtgAutorunLog 'Preserve-DuckDuckGoVpn.ps1 not found - skip'
        return
    }
    Write-CtgAutorunLog '=== DuckDuckGo VPN/DNS preserve ==='
    if ($WhatIf) {
        Write-CtgAutorunLog '[WhatIf] dot-source Preserve-DuckDuckGoVpn.ps1'
        return
    }
    try {
        . $preserveScript
        Invoke-CtgPreserveDuckDuckGoVpn -LogAction { param($m) Write-CtgAutorunLog $m }
    } catch {
        Write-CtgAutorunLog "DDG preserve warning (non-blocking): $($_.Exception.Message)"
    }
}

function Copy-CtgKaliScriptsToBackups {
    $backupRoot = 'C:\Users\Owner\Backups'
    $stageScript = Join-Path $PSScriptRoot 'Stage-KaliLabToBackups.ps1'
    if (Test-Path $stageScript) {
        if ($WhatIf) {
            Write-CtgAutorunLog "[WhatIf] Stage-KaliLabToBackups.ps1 -> $backupRoot"
        } else {
            & $stageScript -BackupRoot $backupRoot -RepoRoot $RepoRoot
            Write-CtgAutorunLog "Full Kali tree staged via Stage-KaliLabToBackups.ps1"
        }
        return
    }
    if (-not (Test-Path $backupRoot)) { New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null }
    $files = @(
        (Join-Path $RepoRoot 'scripts\kali\kali-lab-bootstrap.sh'),
        (Join-Path $RepoRoot 'scripts\kali\ctg-lab-autorun.sh'),
        (Join-Path $RepoRoot 'scripts\kali\ctg-ids-ips-autorun.sh'),
        (Join-Path $RepoRoot 'scripts\kali\ctg-siem-autorun.sh'),
        (Join-Path $RepoRoot 'scripts\kali\kali-boot-autopatch.sh'),
        (Join-Path $RepoRoot 'scripts\kali\ctg-wifi-lab-autorun.sh'),
        (Join-Path $RepoRoot 'scripts\kali\ctg-reboot-if-needed.sh'),
        (Join-Path $RepoRoot 'scripts\kali\ctg-lab-playground.sh'),
        (Join-Path $RepoRoot 'scripts\kali\rogue-ap-guard.sh')
    )
    $scramblerDir = Join-Path $RepoRoot 'scripts\kali\tor-http-scrambler'
    if (Test-Path $scramblerDir) {
        Get-ChildItem -Path $scramblerDir -File | ForEach-Object { $files += $_.FullName }
    }
    foreach ($src in $files) {
        if (-not (Test-Path $src)) { continue }
        $dest = Join-Path $backupRoot (Split-Path $src -Leaf)
        if ($WhatIf) {
            Write-CtgAutorunLog "[WhatIf] Copy $src -> $dest"
        } else {
            Copy-Item -Path $src -Destination $dest -Force
            Write-CtgAutorunLog "Staged: $dest"
        }
    }
    if (Test-Path $scramblerDir) {
        $destScram = Join-Path $backupRoot 'tor-http-scrambler'
        if (-not $WhatIf) {
            New-Item -ItemType Directory -Path $destScram -Force | Out-Null
            Copy-Item -Path (Join-Path $scramblerDir '*') -Destination $destScram -Recurse -Force
            Write-CtgAutorunLog "Staged scrambler tree: $destScram"
        }
    }
    $siemLogDir = Join-Path $backupRoot 'logs\siem'
    if (-not $WhatIf) {
        New-Item -ItemType Directory -Path $siemLogDir -Force | Out-Null
        Write-CtgAutorunLog "Staged SIEM log dir: $siemLogDir"
    }
    $siemDoc = Join-Path $RepoRoot 'docs\KALI_SIEM_STACK.md'
    if ((Test-Path $siemDoc) -and -not $WhatIf) {
        Copy-Item -Path $siemDoc -Destination (Join-Path $backupRoot 'KALI_SIEM_STACK.md') -Force
        Write-CtgAutorunLog "Staged: $(Join-Path $backupRoot 'KALI_SIEM_STACK.md')"
    }
    $playgroundPs1 = Join-Path $PSScriptRoot 'CTG-Lab-Playground.ps1'
    if ((Test-Path $playgroundPs1) -and -not $WhatIf) {
        Copy-Item -Path $playgroundPs1 -Destination (Join-Path $backupRoot 'CTG-Lab-Playground.ps1') -Force
        Write-CtgAutorunLog "Staged: $(Join-Path $backupRoot 'CTG-Lab-Playground.ps1')"
    }
    $playgroundDoc = Join-Path $RepoRoot 'docs\CTG_LAB_PLAYGROUND.md'
    if ((Test-Path $playgroundDoc) -and -not $WhatIf) {
        Copy-Item -Path $playgroundDoc -Destination (Join-Path $backupRoot 'CTG_LAB_PLAYGROUND.md') -Force
        Write-CtgAutorunLog "Staged: $(Join-Path $backupRoot 'CTG_LAB_PLAYGROUND.md')"
    }
}

function Invoke-CtgWiresharkNonBlocking {
    $wsScript = Join-Path $PSScriptRoot 'Install-WiresharkNpcap.ps1'
    if (-not (Test-Path $wsScript)) {
        Write-CtgAutorunLog 'Install-WiresharkNpcap.ps1 not found - skip'
        return
    }
    Write-CtgAutorunLog '=== Wireshark/Npcap companion (non-blocking) ==='
    if ($WhatIf) {
        Write-CtgAutorunLog '[WhatIf] Install-WiresharkNpcap.ps1'
        return
    }
    try {
        & $wsScript 2>&1 | ForEach-Object { Write-CtgAutorunLog "Wireshark: $_" }
    } catch {
        Write-CtgAutorunLog "Wireshark install skipped: $($_.Exception.Message)"
    }
}

function Invoke-CtgOpnsenseNonBlocking {
    if ($SkipOpnsense) {
        Write-CtgAutorunLog 'OPNsense: SKIPPED (-SkipOpnsense)'
        return
    }
    $iso = Get-ChildItem -Path 'C:\Users\Owner\Downloads' -Filter '*.iso' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'OPNsense|opnsense' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $iso) {
        Write-CtgAutorunLog 'OPNsense: no ISO in Downloads - skip Install-OpnsenseLab.ps1'
        return
    }
    $opnScript = Join-Path $PSScriptRoot 'Install-OpnsenseLab.ps1'
    if (-not (Test-Path $opnScript)) {
        Write-CtgAutorunLog 'Install-OpnsenseLab.ps1 not found - skip'
        return
    }
    Write-CtgAutorunLog "OPNsense: ISO found ($($iso.Name)) - launching lab VM setup (non-blocking)"
    if ($WhatIf) {
        Write-CtgAutorunLog '[WhatIf] Install-OpnsenseLab.ps1'
        return
    }
    try {
        & $opnScript 2>&1 | ForEach-Object { Write-CtgAutorunLog "OPNsense: $_" }
    } catch {
        Write-CtgAutorunLog "OPNsense setup skipped: $($_.Exception.Message)"
    }
}

function Write-CtgKaliScramblerInstructions {
    Write-CtgAutorunLog '=== Kali in-guest (after SSH or shared folder) ==='
    Write-CtgAutorunLog 'One-shot autorun:  sudo bash /mnt/ctg/ctg-lab-autorun.sh'
    Write-CtgAutorunLog 'Fallback:         sudo bash /mnt/ctg/kali-lab-bootstrap.sh --wifi-profile=company-lab'
    Write-CtgAutorunLog 'Scrambler daemon: sudo /opt/ctg/tor-http-scrambler/scrambler-daemon.sh start'
    Write-CtgAutorunLog 'Scrambler GUI:    /opt/ctg/tor-http-scrambler/ctg-scrambler-gui.py  (or desktop CTG .TOR/HTTP Scrambler)'
    Write-CtgAutorunLog 'Defaults: browser Tor mode, DDG preserve ON, company-lab WiFi, SIEM rotate prompt y/n'
}

Write-CtgAutorunLog '=== Start-CTGLab.ps1 (CTG Lab Autorun) ==='
Write-CtgAutorunLog "Repo: $RepoRoot | Log: $LogFile | FullBootstrap: $FullBootstrap"

try {
    Invoke-CtgDefenderPauseIfNeeded
    Invoke-CtgDdgPreserve
    Copy-CtgKaliScriptsToBackups

    $deployScript = Join-Path $PSScriptRoot 'Deploy-KaliLab.ps1'
    if (-not (Test-Path $deployScript)) {
        Write-CtgAutorunLog "BLOCKED: Deploy-KaliLab.ps1 not found at $deployScript"
        exit 2
    }

    $deployArgs = @{
        StartVmIfStopped = $true
        WhatIf           = $WhatIf
    }
    if ($FullBootstrap) {
        Write-CtgAutorunLog 'FullBootstrap: deploy with lab-anonymity + scrambler (via bootstrap --install-scrambler)'
    }
    if ($SkipOpnsense) { $deployArgs['SkipOpnsense'] = $true }

    Write-CtgAutorunLog '=== Deploy-KaliLab.ps1 ==='
    $deployExit = 0
    if ($WhatIf) {
        Write-CtgAutorunLog '[WhatIf] Deploy-KaliLab.ps1 -StartVmIfStopped'
    } else {
        try {
            & $deployScript @deployArgs
            $deployExit = $LASTEXITCODE
            if ($null -eq $deployExit) { $deployExit = 0 }
        } catch {
            Write-CtgAutorunLog "Deploy-KaliLab failed: $($_.Exception.Message)"
            $deployExit = 1
        }
    }

    $seamlessScript = Join-Path $PSScriptRoot 'Start-KaliSeamless.ps1'
    if (Test-Path $seamlessScript) {
        Write-CtgAutorunLog '=== Start-KaliSeamless.ps1 (ensure seamless GUI) ==='
        if ($WhatIf) {
            Write-CtgAutorunLog '[WhatIf] Start-KaliSeamless.ps1'
        } else {
            try {
                & $seamlessScript 2>&1 | ForEach-Object { Write-CtgAutorunLog "Seamless: $_" }
            } catch {
                Write-CtgAutorunLog "Start-KaliSeamless warning (non-blocking): $($_.Exception.Message)"
            }
        }
    }

    Invoke-CtgWiresharkNonBlocking
    Invoke-CtgOpnsenseNonBlocking
    Write-CtgKaliScramblerInstructions

    Write-CtgAutorunLog '=== Start-CTGLab.ps1 summary ==='
    Write-CtgAutorunLog "Deploy-KaliLab exit: $deployExit | Docs: docs/CTG_LAB_AUTORUN.md"
    if ($deployExit -ne 0) {
        Write-CtgAutorunLog 'MANUAL: mount shared folder ctg -> /mnt/ctg then: sudo bash /mnt/ctg/ctg-lab-autorun.sh'
        exit $deployExit
    }
    exit 0
} finally {
    Invoke-CtgDefenderResumeIfNeeded
}
