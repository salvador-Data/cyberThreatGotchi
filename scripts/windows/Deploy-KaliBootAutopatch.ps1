# Deploy CTG Kali boot autopatch to VirtualBox kali VM (shared folder + SSH + one-time install).
# Authorized defensive lab use only - Hacker Planet LLC.
param(
    [string]$VmName = 'kali',
    [string]$BackupRoot = 'C:\Users\Owner\Backups',
    [string]$ShareName = 'ctg-backups',
    [string]$CredentialsFile = 'C:\Users\Owner\Backups\kali-vm-credentials.txt',
    [int]$SshHostPort = 2222,
    [int]$SshWaitSeconds = 180,
    [switch]$RunBlankScreenFix,
    [switch]$StartVmIfStopped,
    [switch]$EnableSeamless,
    [switch]$NoSeamless,
    [switch]$NoSpecCtrlHardening,
    [switch]$StartWithGui,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$VBoxManage = Join-Path ${env:ProgramFiles} 'Oracle\VirtualBox\VBoxManage.exe'
$AutopatchScript = Join-Path $RepoRoot 'scripts\kali\kali-boot-autopatch.sh'
$LogDir = Join-Path $BackupRoot 'logs'
$LogFile = Join-Path $LogDir 'deploy-kali-boot-autopatch.log'

function Write-CtgDeployLog([string]$Message) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Host $line
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Get-CtgKaliCredentials {
    param([string]$Path)
    $result = @{ User = 'sal'; Password = 'kali'; Source = 'default sal/kali' }
    if (Test-Path $Path) {
        $text = Get-Content -Path $Path -Raw
        if ($text -match '(?m)^User:\s*(.+)$') { $result.User = $Matches[1].Trim() }
        if ($text -match '(?m)^Password:\s*(.+)$') { $result.Password = $Matches[1].Trim() }
        $result.Source = $Path
    }
    return $result
}

function Get-CtgVmState {
    param([string]$Name)
    $infoRaw = ''
    for ($i = 0; $i -lt 6; $i++) {
        try {
            $infoRaw = (& $VBoxManage showvminfo $Name --machinereadable 2>&1 | Out-String)
            if ($infoRaw -match 'VMState=') { break }
        } catch {
            Start-Sleep -Seconds 2
        }
    }
    $state = 'unknown'
    if ($infoRaw -match 'VMState="([^"]+)"') { $state = $Matches[1] }
    return @{ State = $state; InfoRaw = $infoRaw }
}

function Stop-CtgVmIfRunning {
    param([string]$Name)
    $st = (Get-CtgVmState -Name $Name).State
    if ($st -ne 'running') { return $true }
    Write-CtgDeployLog "VM $Name is running - sending ACPI shutdown for shared-folder / VRAM changes"
    if ($WhatIf) { return $true }
    & $VBoxManage controlvm $Name acpipowerbutton 2>&1 | Out-Null
    $deadline = (Get-Date).AddSeconds(180)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        $st = (Get-CtgVmState -Name $Name).State
        if ($st -ne 'running') {
            Write-CtgDeployLog "VM stopped (state: $st)"
            Start-Sleep -Seconds 5
            return $true
        }
    }
    Write-CtgDeployLog "ACPI shutdown timed out - poweroff"
    $ErrorActionPreference = 'Continue'
    & $VBoxManage controlvm $Name poweroff 2>&1 | Out-Null
    $ErrorActionPreference = 'Stop'
    Start-Sleep -Seconds 5
    return $true
}

function Set-CtgSpecCtrlHardening {
    # RETBleed / Spectre v2: expose IA32_SPEC_CTRL/PRED_CMD MSRs to the guest.
    # Requires VM powered off (caller stops it first). See docs/KALI_RETBLEED.md.
    param([string]$Name)
    $cfg = (& $VBoxManage showvminfo $Name --machinereadable 2>&1 | Out-String)
    $cfgFile = if ($cfg -match 'CfgFile="([^"]+)"') { ($Matches[1] -replace '\\\\', '\') } else { $null }
    $already = $false
    if ($cfgFile -and (Test-Path $cfgFile) -and ((Get-Content -Path $cfgFile -Raw) -match 'SpectreControl="true"')) {
        $already = $true
    }
    if ($already) {
        Write-CtgDeployLog 'spec-ctrl already ON (RETBleed/Spectre v2 MSRs exposed) - no change'
        return
    }
    $st = (Get-CtgVmState -Name $Name).State
    if ($st -eq 'running') {
        Write-CtgDeployLog 'spec-ctrl hardening skipped - VM still running (modifyvm needs power-off)'
        return
    }
    if ($WhatIf) {
        Write-CtgDeployLog "[WhatIf] modifyvm $Name --spec-ctrl on --ibpb-on-vm-exit on --ibpb-on-vm-entry on"
        return
    }
    foreach ($pair in @(@('--spec-ctrl', 'on'), @('--ibpb-on-vm-exit', 'on'), @('--ibpb-on-vm-entry', 'on'))) {
        & $VBoxManage modifyvm $Name $pair[0] $pair[1] 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-CtgDeployLog "spec-ctrl hardening: modifyvm $Name $($pair[0]) $($pair[1])"
        } else {
            Write-CtgDeployLog "spec-ctrl hardening WARNING: modifyvm $($pair[0]) failed"
        }
    }
}

function Enable-CtgVBoxSharedFolder {
    param(
        [string]$Name,
        [string]$HostFolder,
        [string]$FolderName
    )
    if (-not (Test-Path $HostFolder)) {
        New-Item -ItemType Directory -Path $HostFolder -Force | Out-Null
    }
    Write-CtgDeployLog "Ensuring shared folder $FolderName -> $HostFolder (VM must be off for persistent add)"
    if ($WhatIf) { return }
    $st = (Get-CtgVmState -Name $Name).State
    if ($st -eq 'running') {
        Write-CtgDeployLog "Shared folder add requires VM off - waiting for $Name to stop"
        Stop-CtgVmIfRunning -Name $Name | Out-Null
        $st = (Get-CtgVmState -Name $Name).State
    }
    try {
        if ($st -eq 'running') {
            $sfOut = & $VBoxManage controlvm $Name sharedfolder add $FolderName --hostpath $HostFolder --automount 2>&1
        } else {
            $sfOut = & $VBoxManage sharedfolder add $Name --name $FolderName --hostpath $HostFolder --automount 2>&1
        }
        if ($LASTEXITCODE -ne 0) {
            Write-CtgDeployLog "Shared folder note: $sfOut"
        } else {
            Write-CtgDeployLog "Shared folder $FolderName configured"
        }
    } catch {
        Write-CtgDeployLog "Shared folder add skipped: $($_.Exception.Message)"
    }
}

function Ensure-CtgNatSsh {
    param([string]$Name, [int]$HostPort)
    $rules = & $VBoxManage showvminfo $Name 2>$null | Select-String -Pattern "Rule.*ssh|$HostPort"
    if ($rules) { return }
    Write-CtgDeployLog "Adding NAT port forward ${HostPort}->22"
    if ($WhatIf) { return }
    $st = (Get-CtgVmState -Name $Name).State
    if ($st -eq 'running') {
        & $VBoxManage controlvm $Name natpf1 "ssh,tcp,,$HostPort,,22" 2>$null
    } else {
        & $VBoxManage modifyvm $Name --natpf1 "ssh,tcp,,$HostPort,,22"
    }
}

function Wait-CtgSshPort {
    param([int]$Port, [int]$TimeoutSec)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $tcp = Test-NetConnection -ComputerName '127.0.0.1' -Port $Port -WarningAction SilentlyContinue
        if ($tcp.TcpTestSucceeded) {
            Start-Sleep -Seconds 2
            return $true
        }
        Start-Sleep -Seconds 5
    }
    return $false
}

function Invoke-CtgOpenSshAutopatch {
    param(
        [string]$User,
        [string]$Password,
        [int]$Port,
        [string]$LocalScript
    )
    $ssh = Get-Command ssh -ErrorAction SilentlyContinue
    $scp = Get-Command scp -ErrorAction SilentlyContinue
    if (-not $ssh -or -not $scp) {
        Write-CtgDeployLog 'OpenSSH client not found - install OpenSSH Client optional feature'
        return $false
    }

    if ($WhatIf) {
        Write-CtgDeployLog "[WhatIf] scp/ssh autopatch install user=$User port=$Port"
        return $false
    }

    $sshOpts = @('-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=NUL')
    & scp -P $Port @sshOpts $LocalScript "${User}@127.0.0.1:/tmp/kali-boot-autopatch.sh"
    if ($LASTEXITCODE -ne 0) { return $false }

    $escaped = $Password.Replace("'", "'\''")
    $cmd = "echo '$escaped' | sudo -S bash /tmp/kali-boot-autopatch.sh --install"
    & ssh -p $Port @sshOpts "${User}@127.0.0.1" $cmd
    return ($LASTEXITCODE -eq 0)
}

function Invoke-CtgPlinkAutopatch {
    param(
        [string]$User,
        [string]$Password,
        [int]$Port,
        [string]$LocalScript
    )
    $plink = Get-Command plink -ErrorAction SilentlyContinue
    $pscp = Get-Command pscp -ErrorAction SilentlyContinue
    if (-not $plink -or -not $pscp) { return $false }

    if ($WhatIf) {
        Write-CtgDeployLog "[WhatIf] plink/pscp autopatch user=$User port=$Port"
        return $false
    }

    $remote = "${User}@127.0.0.1"
    & $pscp.Source -P $Port -pw $Password $LocalScript "${remote}:/tmp/kali-boot-autopatch.sh"
    if ($LASTEXITCODE -ne 0) { return $false }
    & $plink.Source -P $Port -pw $Password $remote "echo '$Password' | sudo -S bash /tmp/kali-boot-autopatch.sh --install"
    return ($LASTEXITCODE -eq 0)
}

function Invoke-CtgSshAutopatch {
    param(
        [string]$User,
        [string]$Password,
        [int]$Port,
        [string]$LocalScript
    )
    Write-CtgDeployLog 'SSH deploy: prefer OpenSSH (scp/ssh) over PuTTY plink'
    $ok = Invoke-CtgOpenSshAutopatch -User $User -Password $Password -Port $Port -LocalScript $LocalScript
    if ($ok) { return $true }
    Write-CtgDeployLog 'OpenSSH failed - trying PuTTY plink/pscp'
    return Invoke-CtgPlinkAutopatch -User $User -Password $Password -Port $Port -LocalScript $LocalScript
}

function Stage-CtgAutopatchScripts {
    param([string]$SourceScript)
    if (-not (Test-Path $BackupRoot)) {
        New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
    }
    $dest = Join-Path $BackupRoot 'kali-boot-autopatch.sh'
    if (-not $WhatIf) {
        Copy-Item -Path $SourceScript -Destination $dest -Force
    }
    Write-CtgDeployLog "Staged autopatch: $dest"

    $companion = @(
        (Join-Path $RepoRoot 'scripts\kali\ctg-lab-autorun.sh'),
        (Join-Path $RepoRoot 'scripts\kali\ctg-wifi-lab-autorun.sh'),
        (Join-Path $RepoRoot 'scripts\kali\ctg-ids-ips-autorun.sh'),
        (Join-Path $RepoRoot 'scripts\kali\fix-kali-blank-screen.sh'),
        (Join-Path $RepoRoot 'scripts\kali\kali-lab-bootstrap.sh'),
        (Join-Path $RepoRoot 'scripts\kali\rogue-ap-guard.sh'),
        (Join-Path $RepoRoot 'scripts\kali\lab-wifi.conf.example'),
        (Join-Path $RepoRoot 'scripts\kali\ctg-reboot-if-needed.sh')
    )
    $scramblerSrc = Join-Path $RepoRoot 'scripts\kali\tor-http-scrambler'
    if (Test-Path $scramblerSrc) {
        $scramblerDest = Join-Path $BackupRoot 'tor-http-scrambler'
        New-Item -ItemType Directory -Path $scramblerDest -Force | Out-Null
        if (-not $WhatIf) {
            Copy-Item -Path (Join-Path $scramblerSrc '*') -Destination $scramblerDest -Recurse -Force
        }
        Write-CtgDeployLog "Staged CTG Shield / scrambler: $scramblerDest"
    }
    foreach ($src in $companion) {
        if (Test-Path $src) {
            $name = Split-Path $src -Leaf
            if (-not $WhatIf) {
                Copy-Item -Path $src -Destination (Join-Path $BackupRoot $name) -Force
            }
            Write-CtgDeployLog "Staged: $(Join-Path $BackupRoot $name)"
        }
    }
}

# --- main ---
Write-CtgDeployLog '=== Deploy-KaliBootAutopatch.ps1 start ==='

if (-not (Test-Path $VBoxManage)) {
    throw "VBoxManage not found at $VBoxManage"
}
if (-not (Test-Path $AutopatchScript)) {
    throw "Autopatch script missing: $AutopatchScript"
}

$vmsRaw = (& $VBoxManage list vms 2>&1 | Out-String).Trim()
if ($vmsRaw -notmatch "`"$([regex]::Escape($VmName))`"") {
    Write-CtgDeployLog "VM '$VmName' not found. Available:`n$vmsRaw"
    exit 2
}

$stageScript = Join-Path $PSScriptRoot 'Stage-KaliLabToBackups.ps1'
if (Test-Path $stageScript) {
    Write-CtgDeployLog "Full Kali tree staging via Stage-KaliLabToBackups.ps1"
    if (-not $WhatIf) {
        & $stageScript -BackupRoot $BackupRoot -RepoRoot $RepoRoot
    }
} else {
    Stage-CtgAutopatchScripts -SourceScript $AutopatchScript
}

Stop-CtgVmIfRunning -Name $VmName | Out-Null
if (-not $WhatIf) { Start-Sleep -Seconds 5 }

if (-not $NoSpecCtrlHardening) {
    Set-CtgSpecCtrlHardening -Name $VmName
}

if ($RunBlankScreenFix) {
    $blankPs1 = Join-Path $PSScriptRoot 'Fix-KaliBlankScreen.ps1'
    if (Test-Path $blankPs1) {
        Write-CtgDeployLog 'Running Fix-KaliBlankScreen.ps1 (VRAM 128, VMSVGA)'
        if (-not $WhatIf) {
            try {
                & $blankPs1 -VmName $VmName -BackupRoot $BackupRoot 2>&1 | ForEach-Object { Write-CtgDeployLog "BlankScreen: $_" }
            } catch {
                Write-CtgDeployLog "Blank-screen VM tweak skipped: $($_.Exception.Message)"
            }
        }
    }
}

Enable-CtgVBoxSharedFolder -Name $VmName -HostFolder $BackupRoot -FolderName $ShareName
Ensure-CtgNatSsh -Name $VmName -HostPort $SshHostPort

$vmState = (Get-CtgVmState -Name $VmName).State
if ($vmState -ne 'running') {
    if ($StartVmIfStopped -or -not $WhatIf) {
        Write-CtgDeployLog "Starting VM: $VmName"
        if (-not $WhatIf) {
            $startType = if ($StartWithGui -or $EnableSeamless) { 'gui' } else { 'headless' }
            Write-CtgDeployLog "Starting VM with --type $startType (use -StartWithGui for seamless View menu)"
            & $VBoxManage startvm $VmName --type $startType
            Start-Sleep -Seconds 15
        }
    } else {
        Write-CtgDeployLog "VM is $vmState - pass -StartVmIfStopped to power on"
    }
}

$vmState = (Get-CtgVmState -Name $VmName).State
Write-CtgDeployLog "VM state after deploy steps: $vmState"

$sshReady = $false
$sshInstalled = $false
if ($vmState -eq 'running') {
    Write-CtgDeployLog "Waiting up to ${SshWaitSeconds}s for SSH 127.0.0.1:$SshHostPort ..."
    $sshReady = Wait-CtgSshPort -Port $SshHostPort -TimeoutSec $SshWaitSeconds
}

$creds = Get-CtgKaliCredentials -Path $CredentialsFile
Write-CtgDeployLog "Credentials: $($creds.Source) user=$($creds.User)"

if ($sshReady) {
    foreach ($tryUser in @($creds.User, 'sal', 'kali')) {
        Write-CtgDeployLog "SSH autopatch install attempt: $tryUser"
        $sshInstalled = Invoke-CtgSshAutopatch -User $tryUser -Password $creds.Password -Port $SshHostPort -LocalScript $AutopatchScript
        if ($sshInstalled) { break }
    }
} else {
    Write-CtgDeployLog 'SSH not ready on 127.0.0.1:2222 - use manual one-time install below'
}

Write-CtgDeployLog '=== One-time install inside Kali (if SSH did not complete) ==='
Write-CtgDeployLog 'sudo mkdir -p /mnt/ctg'
Write-CtgDeployLog "sudo mount -t vboxsf $ShareName /mnt/ctg"
Write-CtgDeployLog 'sudo bash /mnt/ctg/kali-boot-autopatch.sh --install'
Write-CtgDeployLog 'Optional first run with upgrades: sudo bash /mnt/ctg/kali-boot-autopatch.sh --install --upgrade'
Write-CtgDeployLog 'Verify: systemctl status ctg-kali-autopatch.service'
Write-CtgDeployLog 'Log: /var/log/ctg-boot-autopatch.log'

Write-CtgDeployLog '=== Summary ==='
Write-CtgDeployLog "VM: $VmName | state: $((Get-CtgVmState -Name $VmName).State)"
Write-CtgDeployLog "Shared folder: $ShareName -> $BackupRoot"
Write-CtgDeployLog "SSH ready: $sshReady | autopatch installed via SSH: $sshInstalled"

$wantSeamless = $EnableSeamless -or (-not $NoSeamless)
if ($wantSeamless -and (Get-CtgVmState -Name $VmName).State -eq 'running') {
    $seamlessScript = Join-Path $PSScriptRoot 'Start-KaliSeamless.ps1'
    if (Test-Path $seamlessScript) {
        Write-CtgDeployLog '=== Start-KaliSeamless.ps1 (after autopatch - GUI/Seamless + Host+L) ==='
        if ($WhatIf) {
            Write-CtgDeployLog '[WhatIf] Start-KaliSeamless.ps1 -DiagnoseOnly'
        } else {
            try {
                & $seamlessScript -DiagnoseOnly 2>&1 | ForEach-Object { Write-CtgDeployLog "SeamlessDiag: $_" }
                & $seamlessScript 2>&1 | ForEach-Object { Write-CtgDeployLog "Seamless: $_" }
            } catch {
                Write-CtgDeployLog "Start-KaliSeamless warning (non-blocking): $($_.Exception.Message)"
            }
        }
    }
}

if (-not $sshInstalled -and -not $sshReady) { exit 1 }
exit 0
