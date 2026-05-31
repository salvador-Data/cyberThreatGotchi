# Flash latest CTG Kali scripts from vboxsf share. Zero-touch via trigger when guestcontrol/SSH fail.
# Authorized lab use only - Hacker Planet LLC.
param(
    [string]$VmName = 'kali',
    [string]$CredentialsFile = 'C:\Users\Owner\Backups\kali-vm-credentials.txt',
    [string]$BackupRoot = 'C:\Users\Owner\Backups',
    [string]$TriggerFileName = 'CTG_RUN_AUTORUN_NOW',
    [int]$SshPort = 2222,
    [int]$TriggerWaitSec = 300,
    [switch]$SkipStage,
    [switch]$SkipSeamless,
    [switch]$TriggerOnly,
    [switch]$WhatIf,
    [switch]$UseSecretVault
)
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$LogDir = Join-Path $BackupRoot 'logs'
$LogFile = Join-Path $LogDir 'kali-guest-flash.log'

function Write-CtgFlashLog([string]$Message) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Host $line
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Redact-CtgFlashText([string]$Text, [string[]]$Secrets) {
    $out = $Text
    foreach ($s in $Secrets) {
        if ($s -and $s.Length -gt 0) { $out = $out -replace [regex]::Escape($s), '[REDACTED]' }
    }
    return $out
}

function Get-CtgVBoxManagePath {
    $path = Join-Path ${env:ProgramFiles} 'Oracle\VirtualBox\VBoxManage.exe'
    if (Test-Path $path) { return $path }
    return $null
}


function Get-CtgKaliCredentialsFromVault {
    $vaultScript = Join-Path $PSScriptRoot 'Protect-CtgSecrets.ps1'
    if (-not (Test-Path $vaultScript)) { return $null }
    . $vaultScript
    $vaultFile = Get-CtgSecretVaultFilePath
    if (-not (Test-Path $vaultFile)) { return $null }
    $user = Get-CtgProtectedSecret -SecretName 'KALI_SSH_USER' -VaultFile $vaultFile
    $password = Get-CtgProtectedSecret -SecretName 'KALI_SSH_PASSWORD' -VaultFile $vaultFile
    if ([string]::IsNullOrWhiteSpace($user) -or [string]::IsNullOrWhiteSpace($password)) { return $null }
    return @{
        User     = $user.Trim()
        Password = $password
        Source   = 'DPAPI vault (Protect-CtgSecrets.ps1)'
    }
}

function Get-CtgKaliCredentials {
    param(
        [string]$Path,
        [switch]$PreferVault
    )
    if ($PreferVault) {
        $fromVault = Get-CtgKaliCredentialsFromVault
        if ($fromVault) { return $fromVault }
        Write-CtgFlashLog 'UseSecretVault: vault missing KALI_SSH_USER/KALI_SSH_PASSWORD - falling back to credentials file'
    }
    $result = @{ User = 'sal'; Password = $null; Source = 'none' }
    if (Test-Path $Path) {
        $text = Get-Content -Path $Path -Raw
        if ($text -match '(?m)^User:\s*(.+)$') { $result.User = $Matches[1].Trim() }
        if ($text -match '(?m)^Password:\s*(.+)$') { $result.Password = $Matches[1].Trim() }
        $result.Source = $Path
    }
    if (-not $result.Password) {
        throw "No Kali credentials (vault empty and no Password in $Path). Run Protect-CtgSecrets.ps1 -SetSecret for KALI_SSH_USER and KALI_SSH_PASSWORD."
    }
    return $result
}


function Get-CtgGuestLoggedInUsersList {
    param([string]$VBoxManage, [string]$Vm)
    $raw = (& $VBoxManage guestproperty get $Vm '/VirtualBox/GuestInfo/OS/LoggedInUsersList' 2>&1 | Out-String).Trim()
    if ($raw -match 'Value:\s*(.+)') { return $Matches[1].Trim() }
    return ''
}
function Get-CtgGuestLoggedInUsers {
    param([string]$VBoxManage, [string]$Vm)
    $raw = (& $VBoxManage guestproperty get $Vm '/VirtualBox/GuestInfo/OS/LoggedInUsers' 2>&1 | Out-String).Trim()
    if ($raw -match 'Value:\s*(\d+)') { return [int]$Matches[1] }
    return 0
}

function Get-CtgGuestLabChainBash {
    $lines = @(
        'set -e'
        'if [ -x /media/sf_ctg-backups/ctg-mount-share.sh ]; then'
        '  sudo bash /media/sf_ctg-backups/ctg-mount-share.sh'
        'else'
        '  sudo mkdir -p /mnt/ctg'
        '  if ! mountpoint -q /mnt/ctg; then sudo mount -t vboxsf ctg-backups /mnt/ctg; fi'
        'fi'
        'bash /mnt/ctg/ctg-display-scale.sh --fit-window'
        'bash /mnt/ctg/ctg-seamless-guest.sh'
        'sudo bash /mnt/ctg/ctg-enable-ssh.sh'
        'sudo CTG_NO_REBOOT=1 bash /mnt/ctg/RUN-KALI-LAB-NOW.sh'
        'bash /mnt/ctg/ctg-retbleed-check.sh'
    )
    return ($lines -join "`n")
}

function Test-CtgSshBanner {
    param([int]$Port = 2222, [int]$TimeoutMs = 4000)
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect('127.0.0.1', $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs)) { $client.Close(); return $false }
        $client.EndConnect($iar) | Out-Null
        $stream = $client.GetStream()
        $stream.ReadTimeout = $TimeoutMs
        $buf = New-Object byte[] 128
        $n = $stream.Read($buf, 0, 128)
        $client.Close()
        if ($n -le 0) { return $false }
        $banner = [Text.Encoding]::ASCII.GetString($buf, 0, $n)
        return ($banner -match '^SSH-')
    } catch {
        return $false
    }
}

function Invoke-CtgKaliFlashViaSsh {
    param(
        [hashtable]$Creds,
        [int]$Port,
        [string]$ChainBash,
        [string[]]$TryUsers
    )
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if (-not (Test-CtgSshBanner -Port $Port)) {
            Write-CtgFlashLog "SSH skip: no SSH banner on 127.0.0.1:$Port (sshd likely down)"
            return $false
        }
        $sshOpts = @('-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=NUL', '-o', 'ConnectTimeout=25')
        $inner = $ChainBash.Replace("'", "'\''")
        $escapedPass = $Creds.Password.Replace("'", "'\''")
        $cmd = "echo '$escapedPass' | sudo -S bash -lc '$inner'"
        foreach ($u in $TryUsers) {
            Write-CtgFlashLog "SSH attempt user=$u port=$Port"
            $raw = & ssh -p $Port @sshOpts "${u}@127.0.0.1" $cmd 2>&1 | Out-String
            $red = Redact-CtgFlashText $raw @($Creds.Password)
            foreach ($line in ($red -split "`n")) {
                $t = $line.TrimEnd()
                if ($t) { Write-CtgFlashLog $t }
            }
            if ($LASTEXITCODE -eq 0) {
                Write-CtgFlashLog "SSH flash OK user=$u"
                return $true
            }
            Write-CtgFlashLog "SSH flash failed user=$u exit=$LASTEXITCODE"
        }
        return $false
    } finally {
        $ErrorActionPreference = $prevEap
    }
}

function Test-CtgGuestControlProbe {
    param(
        [string]$VBoxManage,
        [string]$Vm,
        [hashtable]$Creds,
        [string[]]$TryUsers
    )
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $pf = Join-Path $env:TEMP ("ctg-vbox-pw-{0}.tmp" -f [guid]::NewGuid().ToString('N'))
    try {
        Set-Content -Path $pf -Value $Creds.Password -NoNewline -Encoding ASCII
        foreach ($u in $TryUsers) {
            Write-CtgFlashLog "guestcontrol probe user=$u (touch /tmp/ctg-run-flag)"
            $raw = & $VBoxManage guestcontrol $Vm run --username $u --passwordfile $pf --wait-stdout --wait-stderr --timeout 120000 -- /bin/bash -c 'touch /tmp/ctg-run-flag && echo OK' 2>&1 | Out-String
            $red = Redact-CtgFlashText $raw @($Creds.Password)
            foreach ($line in ($red -split "`n")) {
                $t = $line.TrimEnd()
                if ($t) { Write-CtgFlashLog $t }
            }
            if ($LASTEXITCODE -eq 0 -and $red -match 'OK') {
                Write-CtgFlashLog "guestcontrol probe OK user=$u"
                return $true
            }
            Write-CtgFlashLog "guestcontrol probe failed user=$u exit=$LASTEXITCODE"
        }
        return $false
    } finally {
        Remove-Item $pf -Force -ErrorAction SilentlyContinue
        $ErrorActionPreference = $prevEap
    }
}

function Invoke-CtgKaliFlashViaGuestControl {
    param(
        [string]$VBoxManage,
        [string]$Vm,
        [hashtable]$Creds,
        [string]$ChainBash,
        [string[]]$TryUsers
    )
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $pf = Join-Path $env:TEMP ("ctg-vbox-pw-{0}.tmp" -f [guid]::NewGuid().ToString('N'))
    try {
        Set-Content -Path $pf -Value $Creds.Password -NoNewline -Encoding ASCII
        $inner = $ChainBash.Replace("'", "'\''")
        $escapedPass = $Creds.Password.Replace("'", "'\''")
        $guestCmd = "echo '$escapedPass' | sudo -S bash -lc '$inner'"
        foreach ($u in $TryUsers) {
            Write-CtgFlashLog "guestcontrol flash user=$u vm=$Vm"
            $raw = & $VBoxManage guestcontrol $Vm run --username $u --passwordfile $pf --wait-stdout --wait-stderr --timeout 600000 -- /bin/bash -l -c $guestCmd 2>&1 | Out-String
            $red = Redact-CtgFlashText $raw @($Creds.Password)
            foreach ($line in ($red -split "`n")) {
                $t = $line.TrimEnd()
                if ($t) { Write-CtgFlashLog $t }
            }
            if ($LASTEXITCODE -eq 0) {
                Write-CtgFlashLog "guestcontrol flash OK user=$u"
                return $true
            }
            Write-CtgFlashLog "guestcontrol flash failed user=$u exit=$LASTEXITCODE"
        }
        return $false
    } finally {
        Remove-Item $pf -Force -ErrorAction SilentlyContinue
        $ErrorActionPreference = $prevEap
    }
}

function Set-CtgAutorunTrigger {
    param([string]$Root, [string]$Name)
    if (-not (Test-Path $Root)) {
        New-Item -ItemType Directory -Path $Root -Force | Out-Null
    }
    $path = Join-Path $Root $Name
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    if ($WhatIf) {
        Write-CtgFlashLog "[WhatIf] would create trigger $path"
        return $path
    }
    Set-Content -Path $path -Value "CTG autorun trigger $stamp" -Encoding ASCII -Force
    Write-CtgFlashLog "Created share trigger: $path (guest ctg-watch-trigger.sh picks up when logged in)"
    return $path
}

function Wait-CtgTriggerConsumed {
    param([string]$TriggerPath, [int]$TimeoutSec, [string]$BackupRoot)
    if ($WhatIf) { return $false }
    $donePath = Join-Path $BackupRoot 'CTG_AUTORUN_DONE'
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    Write-CtgFlashLog "Waiting up to ${TimeoutSec}s for guest (trigger removed or CTG_AUTORUN_DONE)..."
    while ((Get-Date) -lt $deadline) {
        if (-not (Test-Path $TriggerPath)) {
            Write-CtgFlashLog 'Trigger file removed - guest autorun likely ran'
            return $true
        }
        if (Test-Path $donePath) {
            Write-CtgFlashLog 'CTG_AUTORUN_DONE on share - guest chain completed'
            Remove-Item $TriggerPath -Force -ErrorAction SilentlyContinue
            return $true
        }
        Start-Sleep -Seconds 5
    }
    Write-CtgFlashLog 'Trigger still present - guest may need kali-boot-autopatch.sh --install or ctg-watch-trigger running'
    return $false
}

Write-CtgFlashLog '=== Invoke-CtgKaliGuestFlash.ps1 start ==='

if (-not $SkipStage -and -not $WhatIf) {
    $stageScript = Join-Path $PSScriptRoot 'Stage-KaliLabToBackups.ps1'
    if (Test-Path $stageScript) {
        Write-CtgFlashLog 'Staging scripts/kali -> Backups share'
        & $stageScript -BackupRoot $BackupRoot -RepoRoot $RepoRoot
    }
}

$creds = Get-CtgKaliCredentials -Path $CredentialsFile -PreferVault:$UseSecretVault
$chain = Get-CtgGuestLabChainBash
$vbox = Get-CtgVBoxManagePath
$guiUser = if ($vbox) { Get-CtgGuestLoggedInUsersList -VBoxManage $vbox -Vm $VmName } else { '' }
$tryUsers = @($guiUser, 'sal', 'kali', $creds.User) | Where-Object { $_ } | Select-Object -Unique
Write-CtgFlashLog ("cred source={0} user={1} ssh port={2} tryUsers={3}" -f $creds.Source, $creds.User, $SshPort, ($tryUsers -join ','))

$loggedIn = 0

if ($vbox) {
    $loggedIn = Get-CtgGuestLoggedInUsers -VBoxManage $vbox -Vm $VmName
    Write-CtgFlashLog "Guest LoggedInUsers=$loggedIn vm=$VmName"
} else {
    Write-CtgFlashLog 'VBoxManage not found - SSH/trigger paths only'
}

if ($WhatIf) {
    Write-CtgFlashLog '[WhatIf] would run mount+scale+seamless+ssh+RUN-KALI-LAB-NOW+retbleed or drop trigger'
    exit 0
}

if ($TriggerOnly) {
    Set-CtgAutorunTrigger -Root $BackupRoot -Name $TriggerFileName | Out-Null
    Wait-CtgTriggerConsumed -TriggerPath (Join-Path $BackupRoot $TriggerFileName) -TimeoutSec $TriggerWaitSec -BackupRoot $BackupRoot | Out-Null
    exit 0
}

$ok = $false
if (-not $ok) {
    $ok = Invoke-CtgKaliFlashViaSsh -Creds $creds -Port $SshPort -ChainBash $chain -TryUsers $tryUsers
}

$guestControlOk = $false
if (-not $ok -and $vbox) {
    $guestControlOk = Test-CtgGuestControlProbe -VBoxManage $vbox -Vm $VmName -Creds $creds -TryUsers $tryUsers
    if ($guestControlOk) {
        $ok = Invoke-CtgKaliFlashViaGuestControl -VBoxManage $vbox -Vm $VmName -Creds $creds -ChainBash $chain -TryUsers $tryUsers
    } else {
        Write-CtgFlashLog 'guestcontrol auth failed - sync kali-vm-credentials.txt with sal password OR use share trigger'
    }
}

$triggerPath = $null
if (-not $ok) {
    if ($loggedIn -ge 1) {
        Write-CtgFlashLog 'LoggedInUsers>=1 - zero-touch share trigger (no Windows guest password)'
        $triggerPath = Set-CtgAutorunTrigger -Root $BackupRoot -Name $TriggerFileName
    } else {
        Write-CtgFlashLog 'LoggedInUsers=0 - log into Kali Xfce GUI, then re-run this script or create trigger manually'
        $triggerPath = Set-CtgAutorunTrigger -Root $BackupRoot -Name $TriggerFileName
    }
    if ($triggerPath) {
        $ok = Wait-CtgTriggerConsumed -TriggerPath $triggerPath -TimeoutSec $TriggerWaitSec -BackupRoot $BackupRoot
    }
}

if (-not $SkipSeamless) {
    $seamlessScript = Join-Path $PSScriptRoot 'Start-KaliSeamless.ps1'
    if ((Test-Path $seamlessScript) -and ($ok -or $loggedIn -ge 1)) {
        Write-CtgFlashLog 'Start-KaliSeamless.ps1 -DisplayMode Gui (not Scaled)'
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        & $seamlessScript -DisplayMode Gui -VmName $VmName 2>&1 | ForEach-Object { Write-CtgFlashLog "Seamless: $_" }
        $ErrorActionPreference = $prevEap
    }
}

if (-not $ok) {
    Write-CtgFlashLog 'Remote flash incomplete. ONE action: ensure sal logged into Xfce; sync kali-vm-credentials.txt OR run: sudo bash /mnt/ctg/kali-boot-autopatch.sh --install'
    Write-CtgFlashLog 'Trigger path: New-Item C:\Users\Owner\Backups\CTG_TRIGGER_AUTORUN -ItemType File -Force'
    exit 1
}

Write-CtgFlashLog '=== Guest flash complete ==='
exit 0
