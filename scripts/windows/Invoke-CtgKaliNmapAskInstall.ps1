# Install ctg-nmap-ask (a$k) in Kali guest — SSH, guestcontrol, trigger, keyboard.
# Authorized lab use only — Hacker Planet LLC.
param(
    [string]$VmName = 'kali',
    [string]$CredentialsFile = 'C:\Users\Owner\Backups\kali-vm-credentials.txt',
    [string]$VBoxPasswordFile = 'C:\Users\Owner\Backups\kali-vm-vbox-password.txt',
    [string]$BackupRoot = 'C:\Users\Owner\Backups',
    [int]$SshPort = 2222,
    [int]$TriggerWaitSec = 240,
    [switch]$SkipStage,
    [switch]$SkipKeyboard,
    [switch]$WhatIf
)
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$LogDir = Join-Path $BackupRoot 'logs'
$LogFile = Join-Path $LogDir 'kali-nmap-ask-install.log'
$TriggerName = 'CTG_TRIGGER_NMAP_INSTALL'
$DoneName = 'CTG_NMAP_INSTALL_DONE'

function Write-CtgInstallLog([string]$Message) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Host $line
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Redact-CtgText([string]$Text, [string[]]$Secrets) {
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

function Get-CtgGuestLoggedInUsersList {
    param([string]$VBoxManage, [string]$Vm)
    $raw = (& $VBoxManage guestproperty get $Vm '/VirtualBox/GuestInfo/OS/LoggedInUsersList' 2>&1 | Out-String).Trim()
    if ($raw -match 'Value:\s*(.+)') { return $Matches[1].Trim() }
    return ''
}

function Get-CtgInstallPasswords {
    param([string]$CredPath, [string]$VBoxPwPath)
    $passwords = New-Object System.Collections.Generic.List[string]
    foreach ($p in @($CredPath, $VBoxPwPath)) {
        if (-not (Test-Path $p)) { continue }
        $text = Get-Content -Path $p -Raw
        if ($text -match '(?m)^Password:\s*(.+)$') {
            $val = $Matches[1].Trim()
            if ($val -and -not $passwords.Contains($val)) { [void]$passwords.Add($val) }
        } elseif ($p -like '*vbox-password*') {
            $val = $text.Trim()
            if ($val -and -not $passwords.Contains($val)) { [void]$passwords.Add($val) }
        }
    }
    return @($passwords)
}

function Get-CtgInstallChainBash {
    @(
        'set -e'
        'if [ -x /media/sf_ctg-backups/ctg-mount-share.sh ]; then sudo bash /media/sf_ctg-backups/ctg-mount-share.sh; else sudo mkdir -p /mnt/ctg; mountpoint -q /mnt/ctg || sudo mount -t vboxsf ctg-backups /mnt/ctg; fi'
        'sudo bash /mnt/ctg/kali-boot-autopatch.sh --install'
    ) -join '; '
}

function Get-CtgVerifyBash {
    'test -f /opt/ctg/nmap-ask/ctg-nmap-ask.sh && echo OK_script; test -L /usr/local/bin/ctg-nmap-ask && echo OK_ctg_bin; /usr/local/bin/ctg-nmap-ask --help 2>&1 | head -n 3; command -v nmap >/dev/null && echo OK_nmap || echo MISS_nmap; systemctl is-enabled ctg-kali-autopatch.service 2>/dev/null || true'
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
        return ([Text.Encoding]::ASCII.GetString($buf, 0, $n) -match '^SSH-')
    } catch { return $false }
}

function Invoke-CtgInstallViaSsh {
    param([string[]]$TryUsers, [string[]]$Passwords, [int]$Port, [string]$Chain, [string]$Verify)
    if (-not (Test-CtgSshBanner -Port $Port)) { Write-CtgInstallLog "SSH skip: no banner on 127.0.0.1:$Port"; return @{ Ok = $false; Snippet = '' } }
    $sshOpts = @('-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=NUL', '-o', 'ConnectTimeout=25')
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        foreach ($pw in $Passwords) {
            $ep = $pw.Replace("'", "'\''")
            $inner = $Chain.Replace("'", "'\''")
            $cmd = "echo '$ep' | sudo -S bash -lc '$inner'"
            foreach ($u in $TryUsers) {
                Write-CtgInstallLog "SSH install user=$u"
                & ssh -p $Port @sshOpts "${u}@127.0.0.1" $cmd 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $raw = & ssh -p $Port @sshOpts "${u}@127.0.0.1" $Verify 2>&1 | Out-String
                    return @{ Ok = ($raw -match 'OK_script'); Snippet = (Redact-CtgText $raw @($pw)) }
                }
            }
        }
    } finally { $ErrorActionPreference = $prev }
    return @{ Ok = $false; Snippet = '' }
}

function Invoke-CtgInstallViaGuestControl {
    param([string]$VBoxManage, [string]$Vm, [string[]]$TryUsers, [string[]]$Passwords, [string]$Chain, [string]$Verify)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        foreach ($pw in $Passwords) {
            $pf = Join-Path $env:TEMP ("ctg-vbox-pw-{0}.tmp" -f [guid]::NewGuid().ToString('N'))
            Set-Content -Path $pf -Value $pw -NoNewline -Encoding ASCII
            try {
                $inner = $Chain.Replace("'", "'\''")
                $ep = $pw.Replace("'", "'\''")
                $guestCmd = "echo '$ep' | sudo -S bash -lc '$inner'"
                foreach ($u in $TryUsers) {
                    Write-CtgInstallLog "guestcontrol install user=$u"
                    & $VBoxManage guestcontrol $Vm run --username $u --passwordfile $pf --wait-stdout --wait-stderr --timeout 900000 -- /bin/bash -l -c $guestCmd 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        $vraw = & $VBoxManage guestcontrol $Vm run --username $u --passwordfile $pf --wait-stdout --wait-stderr --timeout 120000 -- /bin/bash -c $Verify 2>&1 | Out-String
                        return @{ Ok = ($vraw -match 'OK_script'); Snippet = (Redact-CtgText $vraw @($pw)) }
                    }
                }
            } finally { Remove-Item $pf -Force -ErrorAction SilentlyContinue }
        }
    } finally { $ErrorActionPreference = $prev }
    return @{ Ok = $false; Snippet = '' }
}

function Invoke-CtgInstallViaKeyboard {
    param([string]$VBoxManage, [string]$Vm, [string]$Password)
    if ($WhatIf) { return $false }
    Start-Sleep -Seconds 2
    & $VBoxManage controlvm $Vm keyboardputscancode 38 3b b8 2>&1 | Out-Null
    Start-Sleep -Seconds 2
    $ep = $Password.Replace("'", "'\''")
    $cmd = "bash /media/sf_ctg-backups/ctg-mount-share.sh 2>/dev/null; echo '$ep' | sudo -S bash /mnt/ctg/kali-boot-autopatch.sh --install"
    & $VBoxManage controlvm $Vm keyboardputstring $cmd 2>&1 | Out-Null
    & $VBoxManage controlvm $Vm keyboardputscancode 1c 9c 2>&1 | Out-Null
    Write-CtgInstallLog 'Keyboard Alt+F2 install sent (needs correct sal sudo password)'
    return $true
}

function Start-CtgTriggerWatchViaKeyboard {
    param([string]$VBoxManage, [string]$Vm)
    & $VBoxManage controlvm $Vm keyboardputscancode 1d 38 14 94 b8 9d 2>&1 | Out-Null
    Start-Sleep -Seconds 3
    $cmd = 'nohup bash /media/sf_ctg-backups/ctg-watch-trigger.sh >>$HOME/ctg-watch-trigger.log 2>&1 &'
    & $VBoxManage controlvm $Vm keyboardputstring $cmd 2>&1 | Out-Null
    & $VBoxManage controlvm $Vm keyboardputscancode 1c 9c 2>&1 | Out-Null
    Write-CtgInstallLog 'Started ctg-watch-trigger in guest terminal'
}

function Wait-CtgInstallDone {
    param([string]$Root, [int]$TimeoutSec)
    $trigger = Join-Path $Root $TriggerName
    $done = Join-Path $Root $DoneName
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path $done) { return $true }
        if (-not (Test-Path $trigger)) { return $true }
        Start-Sleep -Seconds 5
    }
    return $false
}

Write-CtgInstallLog '=== Invoke-CtgKaliNmapAskInstall.ps1 start ==='
if (-not $SkipStage -and -not $WhatIf) {
    $stage = Join-Path $PSScriptRoot 'Stage-KaliLabToBackups.ps1'
    if (Test-Path $stage) { & $stage -BackupRoot $BackupRoot -RepoRoot $RepoRoot }
}
$passwords = Get-CtgInstallPasswords -CredPath $CredentialsFile -VBoxPwPath $VBoxPasswordFile
if ($passwords.Count -eq 0) { throw 'No passwords in credentials or vbox password file' }
$vbox = Get-CtgVBoxManagePath
$loggedInList = ''
$loggedIn = 0
if ($vbox) {
    $raw = (& $vbox guestproperty get $VmName '/VirtualBox/GuestInfo/OS/LoggedInUsers' 2>&1 | Out-String)
    if ($raw -match 'Value:\s*(\d+)') { $loggedIn = [int]$Matches[1] }
    $loggedInList = Get-CtgGuestLoggedInUsersList -VBoxManage $vbox -Vm $VmName
    Write-CtgInstallLog "Guest LoggedInUsers=$loggedIn list=$loggedInList"
}
$tryUsers = @($loggedInList, 'sal', 'kali') | Where-Object { $_ } | Select-Object -Unique
$chain = Get-CtgInstallChainBash
$verify = Get-CtgVerifyBash
$result = @{ Ok = $false; Snippet = '' }
if (-not $WhatIf) {
    $result = Invoke-CtgInstallViaSsh -TryUsers $tryUsers -Passwords $passwords -Port $SshPort -Chain $chain -Verify $verify
}
if (-not $result.Ok -and $vbox -and -not $WhatIf) {
    $result = Invoke-CtgInstallViaGuestControl -VBoxManage $vbox -Vm $VmName -TryUsers $tryUsers -Passwords $passwords -Chain $chain -Verify $verify
}
if (-not $result.Ok -and $loggedIn -ge 1 -and $vbox -and -not $WhatIf) {
    Set-Content -Path (Join-Path $BackupRoot $TriggerName) -Value "CTG nmap-ask install $(Get-Date -Format o)" -Encoding ASCII -Force
    Start-CtgTriggerWatchViaKeyboard -VBoxManage $vbox -Vm $VmName
    if (Wait-CtgInstallDone -Root $BackupRoot -TimeoutSec $TriggerWaitSec) {
        $done = Join-Path $BackupRoot $DoneName
        if (Test-Path $done) { $result = @{ Ok = $true; Snippet = (Get-Content $done -Raw) } }
    }
}
if (-not $result.Ok -and -not $SkipKeyboard -and $vbox -and $loggedIn -ge 1 -and -not $WhatIf) {
    Invoke-CtgInstallViaKeyboard -VBoxManage $vbox -Vm $VmName -Password $passwords[0] | Out-Null
    Start-Sleep -Seconds 120
    $done = Join-Path $BackupRoot $DoneName
    if (Test-Path $done) { $result = @{ Ok = $true; Snippet = (Get-Content $done -Raw) } }
    else { $result = Invoke-CtgInstallViaGuestControl -VBoxManage $vbox -Vm $VmName -TryUsers $tryUsers -Passwords $passwords -Chain $verify -Verify $verify }
}
if ($result.Ok) {
    Write-CtgInstallLog '=== ctg-nmap-ask install SUCCESS ==='
    Write-CtgInstallLog $result.Snippet
    exit 0
}
Write-CtgInstallLog '=== ctg-nmap-ask install FAILED ==='
Write-CtgInstallLog "Blocker: sync Password in kali-vm-credentials.txt to desktop user ($loggedInList)."
Write-CtgInstallLog 'ONE line in Kali: sudo bash /mnt/ctg/kali-boot-autopatch.sh --install'
exit 1
