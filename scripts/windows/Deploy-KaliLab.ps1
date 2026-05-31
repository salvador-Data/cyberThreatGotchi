# Deploy CyberThreatGotchi Kali lab bootstrap to VirtualBox or VMware Kali VM.
# Authorized defensive lab use only - Hacker Planet LLC.
# Master script: DDG preserve, detect hypervisor, Wireshark/Npcap, OPNsense lab stub, Kali bootstrap.
param(
    [string[]]$VmNameCandidates = @('kali', 'Kali-Lab', 'Kali', 'kali-linux'),
    [string]$BootstrapScript = '',
    [string]$CredentialsFile = 'C:\Users\Owner\Backups\kali-vm-credentials.txt',
    [string]$WifiProfile = 'company-lab',
    [int]$SshHostPort = 2222,
    [int]$SshWaitSeconds = 300,
    [switch]$PreserveDdgDns,
    [switch]$NoPreserveDdgDns,
    [switch]$DdgDnsOnly,
    [switch]$SkipOpnsense,
    [switch]$SkipWireshark,
    [switch]$SkipDdgPreserve,
    [switch]$NoLabAnonymity,
    [switch]$StartVmIfStopped,
    [switch]$InstallSshServerHint,
    [switch]$WhatIf
)

# Default: preserve DuckDuckGo DNS (same as IPHONE_HARDENING.md)
if (-not $NoPreserveDdgDns) {
    $PreserveDdgDns = $true
}

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$DdgDnsPrimary = '94.140.14.14'
$DdgDnsSecondary = '94.140.15.15'
$IphoneHardeningDoc = Join-Path $RepoRoot 'docs\IPHONE_HARDENING.md'
if (-not $BootstrapScript) {
    $BootstrapScript = Join-Path $RepoRoot 'scripts\kali\kali-lab-bootstrap.sh'
}
if (-not (Test-Path $BootstrapScript)) {
    throw "Bootstrap script not found: $BootstrapScript"
}

function Write-CtgLog([string]$Message) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Host $line
    $logDir = 'C:\Users\Owner\Backups\logs'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    Add-Content -Path (Join-Path $logDir 'deploy-kali-lab.log') -Value $line -Encoding UTF8
}

function Get-CtgDuckDuckGoHostStatus {
    $status = @{
        VpnInstalled = $false
        VpnConnected = $false
        DnsOnHost = $false
        DnsAdapters = @()
        DnsServers = @($DdgDnsPrimary, $DdgDnsSecondary)
    }

    $ddgProc = Get-Process -Name 'DuckDuckGo.VPN', 'DuckDuckGo.VPN.WireGuard' -ErrorAction SilentlyContinue
    if ($ddgProc) { $status.VpnInstalled = $true }

    $ddgAdapter = Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceDescription -match 'DuckDuckGo|WireGuard' -and $_.Status -eq 'Up' }
    if ($ddgAdapter) {
        $status.VpnConnected = $true
    }

    $dnsRows = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue
    foreach ($row in $dnsRows) {
        $match = $false
        foreach ($srv in $row.ServerAddresses) {
            if ($srv -eq $DdgDnsPrimary -or $srv -eq $DdgDnsSecondary) {
                $match = $true
                break
            }
        }
        if ($match) {
            $status.DnsOnHost = $true
            $alias = (Get-NetAdapter -InterfaceIndex $row.InterfaceIndex -ErrorAction SilentlyContinue).Name
            $status.DnsAdapters += "$alias ($($row.ServerAddresses -join ', '))"
        }
    }
    return $status
}

function Invoke-CtgDuckDuckGoPreserveCheck {
    Write-CtgLog '=== DuckDuckGo VPN/DNS preserve (mandatory) ==='
    Write-CtgLog "Policy: same as $IphoneHardeningDoc - do NOT replace DDG on Windows/iPhone/router"
    Write-CtgLog 'OPNsense lab: DuckDuckGo forwarders only - do NOT stack NextDNS/Cloudflare/1.1.1.1 when DDG set'

    $ddg = Get-CtgDuckDuckGoHostStatus
    if ($ddg.VpnInstalled) {
        $vpnState = if ($ddg.VpnConnected) { 'connected' } else { 'installed (tunnel down)' }
        Write-CtgLog "Windows DuckDuckGo VPN: $vpnState"
    } else {
        Write-CtgLog 'Windows DuckDuckGo VPN: not detected (OK if using DDG DNS only)'
    }
    if ($ddg.DnsOnHost) {
        $ddgAdapters = $ddg.DnsAdapters -join '; '
        Write-CtgLog "Windows DuckDuckGo DNS on adapter(s): $ddgAdapters"
    } else {
        Write-CtgLog 'Windows adapter DNS: no 94.140.14.14 or 94.140.15.15 on active interfaces (DDG may be via VPN tunnel only)'
    }

    if ($PreserveDdgDns) {
        Write-CtgLog 'Kali bootstrap: --preserve-ddg-dns (default ON)'
    } else {
        Write-CtgLog 'WARNING: -NoPreserveDdgDns - Kali may change resolv.conf without DDG guard'
    }
    if ($DdgDnsOnly) {
        Write-CtgLog 'Kali bootstrap: --ddg-dns-only - resolv.conf + Unbound stub to DuckDuckGo only'
    }

    $preserveScript = Join-Path $PSScriptRoot 'Preserve-DuckDuckGoVpn.ps1'
    if (-not $SkipDdgPreserve -and (Test-Path $preserveScript)) {
        Write-CtgLog 'Running Preserve-DuckDuckGoVpn.ps1 (Defender exclusions, no second VPN install)'
        if (-not $WhatIf) {
            . $preserveScript
            Invoke-CtgPreserveDuckDuckGoVpn -LogAction { param($m) Write-CtgLog $m }
        }
    }
}

function Get-CtgBootstrapExtraArgs {
    $args = @("--wifi-profile=$WifiProfile")
    if ($PreserveDdgDns) { $args += '--preserve-ddg-dns' }
    if ($NoPreserveDdgDns) { $args += '--no-preserve-ddg-dns' }
    if ($DdgDnsOnly) { $args += '--ddg-dns-only' }
    if ($NoLabAnonymity) {
        $args += '--no-lab-anonymity'
        $args += '--no-install-scrambler'
    } else {
        $args += '--lab-anonymity'
        $args += '--install-scrambler'
    }
    return ($args -join ' ')
}

function Invoke-CtgWiresharkCompanion {
    if ($SkipWireshark) {
        Write-CtgLog 'Skipping Install-WiresharkNpcap.ps1 (-SkipWireshark)'
        return
    }
    $wsScript = Join-Path $PSScriptRoot 'Install-WiresharkNpcap.ps1'
    if (-not (Test-Path $wsScript)) {
        Write-CtgLog 'Install-WiresharkNpcap.ps1 not found - skip Windows Wireshark companion'
        return
    }
    Write-CtgLog 'Windows companion: Wireshark + Npcap (WiFi monitor via Kali VM + USB passthrough)'
    if ($WhatIf) {
        Write-CtgLog '[WhatIf] Install-WiresharkNpcap.ps1'
        return
    }
    try {
        & $wsScript 2>&1 | ForEach-Object { Write-CtgLog "Wireshark: $_" }
    } catch {
        Write-CtgLog "Wireshark install skipped or failed: $($_.Exception.Message)"
    }
}

function Write-CtgLabChecklistStatus {
    Write-CtgLog '=== Kali lab feature checklist (docs/KALI_LAB_ARCHITECTURE.md) ==='
    $items = @(
        '1 Auto Kali hardening (bootstrap/Ansible)',
        '2 Free IDS/IPS - Suricata OPNsense + passive Snort Kali',
        '3 ClamAV',
        '4 Wireshark + WiFi monitor lab',
        '5 Snort (passive Kali)',
        '6 Realtek dongle drivers - Kali + Windows notes',
        '7 OSINT tier 1/2 (Maltego CE manual)',
        '8 WiFi Option 2 company-lab profile',
        '9 Production firewall - OPNsense lab VM',
        '10 WiFi range/lab tune module',
        '11 Deploy-KaliLab.ps1 + kali-lab-bootstrap.sh',
        '12 Windows Wireshark/Npcap companion',
        '13 Defender pause script (Pause-DefenderRealtime.ps1 - manual for builds)',
        '14 Authorized Hacker Planet LLC lab framing',
        '15 DuckDuckGo VPN + DNS preserve (this deploy)',
        '16 Lab anonymity + authorized pentest (Tor/proxychains; lab-targets.example)',
        '17 CTG Lab Autorun Start-CTGLab.ps1 + ctg-lab-autorun.sh',
        '18 CTG Privacy Router tor-http-scrambler (Phase 7)'
    )
    foreach ($item in $items) { Write-CtgLog "  [doc+script] $item" }
}

function Get-CtgKaliCredentials {
    param([string]$Path)
    $result = @{
        User = 'kali'
        Password = 'kali'
        Source = 'default kali/kali'
    }
    if (Test-Path $Path) {
        $text = Get-Content -Path $Path -Raw
        if ($text -match '(?m)^User:\s*(.+)$') { $result.User = $Matches[1].Trim() }
        if ($text -match '(?m)^Password:\s*(.+)$') { $result.Password = $Matches[1].Trim() }
        $result.Source = $Path
    }
    return $result
}

function Find-CtgVirtualBoxKali {
    param([string[]]$Names)
    $VBoxManage = Join-Path ${env:ProgramFiles} 'Oracle\VirtualBox\VBoxManage.exe'
    if (-not (Test-Path $VBoxManage)) { return $null }
    try {
        $vmsRaw = (& $VBoxManage list vms 2>&1 | Out-String).Trim()
    } catch {
        Write-CtgLog "VirtualBox list vms failed: $($_.Exception.Message)"
        return $null
    }
    if (-not $vmsRaw) { return $null }
    foreach ($n in $Names) {
        $pattern = '"' + [regex]::Escape($n) + '"'
        if ($vmsRaw -match $pattern) {
            return @{ Hypervisor = 'VirtualBox'; Name = $n; Tool = $VBoxManage }
        }
    }
    return $null
}

function Find-CtgVmwareKali {
    param([string[]]$Names)
    $vmrunPaths = @(
        'C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe',
        'C:\Program Files\VMware\VMware Workstation\vmrun.exe'
    )
    $vmrun = $vmrunPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $vmrun) { return $null }

    $searchRoots = @(
        (Join-Path $env:USERPROFILE 'Documents\Virtual Machines'),
        (Join-Path $env:USERPROFILE 'vmware'),
        'C:\VMware',
        'D:\VMware'
    )
    foreach ($root in $searchRoots) {
        if (-not (Test-Path $root)) { continue }
        $vmxFiles = Get-ChildItem -Path $root -Filter '*.vmx' -Recurse -ErrorAction SilentlyContinue
        foreach ($vmx in $vmxFiles) {
            $base = [System.IO.Path]::GetFileNameWithoutExtension($vmx.Name)
            foreach ($n in $Names) {
                if ($base -ieq $n -or $vmx.Name -match [regex]::Escape($n)) {
                    return @{ Hypervisor = 'VMware'; Name = $base; VmxPath = $vmx.FullName; Tool = $vmrun }
                }
            }
        }
    }
    return $null
}

function Get-CtgVmStateVirtualBox {
    param([string]$Name, [string]$VBoxManage)
    $infoRaw = (& $VBoxManage showvminfo $Name --machinereadable 2>&1 | Out-String)
    $state = 'unknown'
    if ($infoRaw -match 'VMState="([^"]+)"') { $state = $Matches[1] }
    $guestIp = ((& $VBoxManage guestproperty get $Name '/VirtualBox/GuestInfo/Net/0/V4/IP' 2>&1 | Out-String) -replace '(?s).*Value:\s*', '').Trim()
    if ($guestIp -match 'No value set') { $guestIp = '' }
    $loggedIn = ((& $VBoxManage guestproperty get $Name '/VirtualBox/GuestInfo/OS/LoggedInUsersList' 2>&1 | Out-String) -replace '(?s).*Value:\s*', '').Trim()
    if ($loggedIn -match 'No value set') { $loggedIn = '' }
    return @{ State = $state; GuestIp = $guestIp; LoggedInUser = $loggedIn }
}

function Ensure-CtgVBoxNatSsh {
    param([string]$Name, [string]$VBoxManage, [int]$HostPort)
    $rules = & $VBoxManage showvminfo $Name 2>$null | Select-String -Pattern 'Rule.*ssh|2222'
    if ($rules) { return }
    Write-CtgLog "Adding NAT port forward ${HostPort}->22 on $Name"
    if ($WhatIf) { return }
    $state = (Get-CtgVmStateVirtualBox -Name $Name -VBoxManage $VBoxManage).State
    if ($state -eq 'running') {
        & $VBoxManage controlvm $Name natpf1 "ssh,tcp,,$HostPort,,22" 2>$null
    } else {
        & $VBoxManage modifyvm $Name --natpf1 "ssh,tcp,,$HostPort,,22"
    }
}

function Start-CtgVirtualBoxVm {
    param([string]$Name, [string]$VBoxManage)
    $state = (Get-CtgVmStateVirtualBox -Name $Name -VBoxManage $VBoxManage).State
    if ($state -eq 'running') { return }
    if (-not $StartVmIfStopped) {
        Write-CtgLog "VM $Name is $state - pass -StartVmIfStopped to power on"
        return
    }
    Write-CtgLog "Starting VirtualBox VM: $Name"
    if (-not $WhatIf) { & $VBoxManage startvm $Name --type headless }
}

function Wait-CtgSshReady {
    param(
        [string]$HostName = '127.0.0.1',
        [int]$Port,
        [int]$TimeoutSec
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $tcp = Test-NetConnection -ComputerName $HostName -Port $Port -WarningAction SilentlyContinue
        if ($tcp.TcpTestSucceeded) {
            Start-Sleep -Seconds 2
            return $true
        }
        Start-Sleep -Seconds 5
    }
    return $false
}

function Invoke-CtgPlinkBootstrap {
    param(
        [string]$User,
        [string]$Password,
        [int]$Port,
        [string]$LocalScript,
        [string]$ExtraArgs
    )
    $plink = Get-Command plink -ErrorAction SilentlyContinue
    $pscp = Get-Command pscp -ErrorAction SilentlyContinue
    if (-not $plink -or -not $pscp) {
        Write-CtgLog 'PuTTY plink/pscp not in PATH - falling back to OpenSSH (password auth may prompt/fail on Windows)'
        return Invoke-CtgOpenSshBootstrap -User $User -Password $Password -Port $Port -LocalScript $LocalScript -ExtraArgs $ExtraArgs
    }

    $remote = "${User}@127.0.0.1"
    if ($WhatIf) {
        Write-CtgLog "[WhatIf] pscp bootstrap to $remote port $Port"
        Write-CtgLog "[WhatIf] plink sudo bash /tmp/kali-lab-bootstrap.sh $ExtraArgs"
        return $false
    }

    & $pscp.Source -P $Port -pw $Password $LocalScript "${remote}:/tmp/kali-lab-bootstrap.sh"
    if ($LASTEXITCODE -ne 0) { return $false }
    & $plink.Source -P $Port -pw $Password $remote "echo '$Password' | sudo -S bash /tmp/kali-lab-bootstrap.sh $ExtraArgs"
    return ($LASTEXITCODE -eq 0)
}

function Invoke-CtgOpenSshBootstrap {
    param(
        [string]$User,
        [string]$Password,
        [int]$Port,
        [string]$LocalScript,
        [string]$ExtraArgs
    )
    if ($WhatIf) {
        Write-CtgLog "[WhatIf] scp/ssh bootstrap port $Port user $User args: $ExtraArgs"
        return $false
    }

    $sshOpts = @('-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=NUL', '-p', "$Port")
    & scp @sshOpts $LocalScript "${User}@127.0.0.1:/tmp/kali-lab-bootstrap.sh"
    if ($LASTEXITCODE -ne 0) { return $false }

    $cmd = "echo '$($Password.Replace("'", "'\\''"))' | sudo -S bash /tmp/kali-lab-bootstrap.sh $ExtraArgs"
    & ssh @sshOpts "${User}@127.0.0.1" $cmd
    return ($LASTEXITCODE -eq 0)
}

function Enable-CtgVBoxSharedBootstrap {
    param(
        [string]$Name,
        [string]$VBoxManage,
        [string]$HostFolder = 'C:\Users\Owner\Backups',
        [string]$ShareName = 'ctg-backups'
    )
    if (-not (Test-Path $HostFolder)) { return $false }
    Write-CtgLog "Ensuring VirtualBox shared folder $ShareName -> $HostFolder"
    if ($WhatIf) { return $true }
    $state = (Get-CtgVmStateVirtualBox -Name $Name -VBoxManage $VBoxManage).State
    try {
        if ($state -eq 'running') {
            & $VBoxManage controlvm $Name sharedfolder add $ShareName --hostpath $HostFolder --automount 2>&1 | Out-Null
        } else {
            & $VBoxManage sharedfolder add $Name --name $ShareName --hostpath $HostFolder --automount 2>&1 | Out-Null
        }
    } catch {
        Write-CtgLog "Shared folder add skipped (may already exist): $($_.Exception.Message)"
    }
    Write-CtgLog "In Kali: sudo mkdir -p /mnt/ctg; sudo mount -t vboxsf $ShareName /mnt/ctg"
    Write-CtgLog "Then: sudo bash /mnt/ctg/ctg-lab-autorun.sh"
    Write-CtgLog "  or: sudo bash /mnt/ctg/kali-lab-bootstrap.sh --wifi-profile=$WifiProfile"
    return $true
}

function Copy-CtgBootstrapToSharedFolder {
    param([string]$LocalScript)
    $backupRoot = 'C:\Users\Owner\Backups'
    if (-not (Test-Path $backupRoot)) { New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null }
    $dest = Join-Path $backupRoot 'kali-lab-bootstrap.sh'
    Copy-Item -Path $LocalScript -Destination $dest -Force
    Write-CtgLog "Bootstrap copied to $dest"

    $autorun = Join-Path $RepoRoot 'scripts\kali\ctg-lab-autorun.sh'
    if (Test-Path $autorun) {
        Copy-Item -Path $autorun -Destination (Join-Path $backupRoot 'ctg-lab-autorun.sh') -Force
        Write-CtgLog "Autorun copied to $(Join-Path $backupRoot 'ctg-lab-autorun.sh')"
    }

    $blankFix = Join-Path $RepoRoot 'scripts\kali\fix-kali-blank-screen.sh'
    if (Test-Path $blankFix) {
        Copy-Item -Path $blankFix -Destination (Join-Path $backupRoot 'fix-kali-blank-screen.sh') -Force
        Write-CtgLog "Blank-screen fix copied to $(Join-Path $backupRoot 'fix-kali-blank-screen.sh')"
    }

    $autopatch = Join-Path $RepoRoot 'scripts\kali\kali-boot-autopatch.sh'
    if (Test-Path $autopatch) {
        Copy-Item -Path $autopatch -Destination (Join-Path $backupRoot 'kali-boot-autopatch.sh') -Force
        Write-CtgLog "Boot autopatch copied to $(Join-Path $backupRoot 'kali-boot-autopatch.sh')"
    }

    $scramblerSrc = Join-Path $RepoRoot 'scripts\kali\tor-http-scrambler'
    if (Test-Path $scramblerSrc) {
        $scramblerDest = Join-Path $backupRoot 'tor-http-scrambler'
        New-Item -ItemType Directory -Path $scramblerDest -Force | Out-Null
        Copy-Item -Path (Join-Path $scramblerSrc '*') -Destination $scramblerDest -Recurse -Force
        Write-CtgLog "Scrambler staged: $scramblerDest"
    }

    $rogueAp = Join-Path $RepoRoot 'scripts\kali\rogue-ap-guard.sh'
    if (Test-Path $rogueAp) {
        Copy-Item -Path $rogueAp -Destination (Join-Path $backupRoot 'rogue-ap-guard.sh') -Force
        Write-CtgLog "Rogue AP guard copied to $(Join-Path $backupRoot 'rogue-ap-guard.sh')"
    }

    $wifiAutorun = Join-Path $RepoRoot 'scripts\kali\ctg-wifi-lab-autorun.sh'
    if (Test-Path $wifiAutorun) {
        Copy-Item -Path $wifiAutorun -Destination (Join-Path $backupRoot 'ctg-wifi-lab-autorun.sh') -Force
        Write-CtgLog "WiFi lab autorun copied to $(Join-Path $backupRoot 'ctg-wifi-lab-autorun.sh')"
    }

    $labWifiExample = Join-Path $RepoRoot 'scripts\kali\lab-wifi.conf.example'
    if (Test-Path $labWifiExample) {
        Copy-Item -Path $labWifiExample -Destination (Join-Path $backupRoot 'lab-wifi.conf.example') -Force
        Write-CtgLog "Lab WiFi example copied to $(Join-Path $backupRoot 'lab-wifi.conf.example')"
        Write-CtgLog 'In Kali: sudo cp /mnt/ctg/lab-wifi.conf.example /etc/ctg/lab-wifi.conf && sudo chmod 600 /etc/ctg/lab-wifi.conf'
    }

    $shieldPs1 = Join-Path $PSScriptRoot 'CTG-Shield-Status.ps1'
    if (Test-Path $shieldPs1) {
        Copy-Item -Path $shieldPs1 -Destination (Join-Path $backupRoot 'CTG-Shield-Status.ps1') -Force
        Write-CtgLog "CTG Shield status script staged on host: $(Join-Path $backupRoot 'CTG-Shield-Status.ps1')"
    }

    $shieldPlaybook = Join-Path $RepoRoot 'docs\CTG_SHIELD_SIEM_PLAYBOOK.md'
    if (Test-Path $shieldPlaybook) {
        Copy-Item -Path $shieldPlaybook -Destination (Join-Path $backupRoot 'CTG_SHIELD_SIEM_PLAYBOOK.md') -Force
        Write-CtgLog "CTG Shield playbook staged: $(Join-Path $backupRoot 'CTG_SHIELD_SIEM_PLAYBOOK.md')"
    }

    Write-CtgLog 'In Kali after mount: sudo bash /mnt/ctg/ctg-lab-autorun.sh'
    Write-CtgLog "  or: sudo bash /mnt/ctg/kali-lab-bootstrap.sh --wifi-profile=$WifiProfile"
    return $dest
}

# --- main ---
Write-CtgLog '=== Deploy-KaliLab.ps1 start ==='
Write-CtgLog "Repo: $RepoRoot | WiFi profile: $WifiProfile"
Write-CtgLabChecklistStatus
Invoke-CtgDuckDuckGoPreserveCheck
Invoke-CtgWiresharkCompanion

$bootstrapExtra = Get-CtgBootstrapExtraArgs
Write-CtgLog "Kali bootstrap args: $bootstrapExtra"
if ($NoLabAnonymity) {
    Write-CtgLog 'Lab anonymity module: SKIPPED (-NoLabAnonymity)'
} else {
    Write-CtgLog 'Lab anonymity module: ON - tor, proxychains4, Tor Browser launcher, firefox-esr; manual Tor Browser launch'
    Write-CtgLog 'Authorized pentest: copy scripts/kali/lab-targets.example to lab-targets.conf (gitignored); nmap/metasploit/burp/sqlmap against listed targets only'
    Write-CtgLog 'See docs/KALI_LAB_ARCHITECTURE.md Lab anonymity section - NOT third-party or crime use'
}

$vbox = Find-CtgVirtualBoxKali -Names @($VmNameCandidates)
$vmware = Find-CtgVmwareKali -Names @($VmNameCandidates)

$target = $null
if ($vbox) {
    $target = $vbox
    Write-CtgLog "Hypervisor: Oracle VirtualBox - VM $($vbox.Name)"
} elseif ($vmware) {
    $target = $vmware
    Write-CtgLog "Hypervisor: VMware Workstation - VM $($vmware.Name) at $($vmware.VmxPath)"
} else {
    Write-CtgLog 'No Kali VM found in VirtualBox or VMware. Run Install-KaliVirtualBox.ps1 or create VMware VM first.'
    Copy-CtgBootstrapToSharedFolder -LocalScript $BootstrapScript | Out-Null
    exit 2
}

$creds = Get-CtgKaliCredentials -Path $CredentialsFile
Write-CtgLog "Credentials source: $($creds.Source) (user: $($creds.User))"

$deployed = $false
$sshReady = $false

if ($target.Hypervisor -eq 'VirtualBox') {
    $blankFixPs1 = Join-Path $PSScriptRoot 'Fix-KaliBlankScreen.ps1'
    if ((Test-Path $blankFixPs1) -and $target.Name -eq 'kali') {
        Write-CtgLog 'Kali VM: ensuring VRAM/graphics via Fix-KaliBlankScreen.ps1 (when powered off)'
        if (-not $WhatIf) {
            try {
                & $blankFixPs1 -VmName $target.Name 2>&1 | ForEach-Object { Write-CtgLog "BlankScreen: $_" }
            } catch {
                Write-CtgLog "Blank-screen VM tweak skipped: $($_.Exception.Message)"
            }
        }
    }

    $vbState = Get-CtgVmStateVirtualBox -Name $target.Name -VBoxManage $target.Tool
    Write-CtgLog "VM state: $($vbState.State) | guest IP: $($vbState.GuestIp) | logged in: $($vbState.LoggedInUser)"

    if ($vbState.State -ne 'running') {
        Start-CtgVirtualBoxVm -Name $target.Name -VBoxManage $target.Tool
        Start-Sleep -Seconds 10
        $vbState = Get-CtgVmStateVirtualBox -Name $target.Name -VBoxManage $target.Tool
    }

    if ($vbState.State -eq 'running') {
        Ensure-CtgVBoxNatSsh -Name $target.Name -VBoxManage $target.Tool -HostPort $SshHostPort
        Write-CtgLog "Waiting up to ${SshWaitSeconds}s for SSH on 127.0.0.1:$SshHostPort ..."
        $sshReady = Wait-CtgSshReady -Port $SshHostPort -TimeoutSec $SshWaitSeconds
    }
} else {
    Write-CtgLog 'VMware path: ensure VM is running and SSH reachable (NAT port forward or bridged IP).'
    if (-not $WhatIf) {
        $list = & $target.Tool list 2>$null
        $running = $list -match [regex]::Escape($target.VmxPath)
        if (-not $running -and $StartVmIfStopped) {
            & $target.Tool start $target.VmxPath nogui
            Start-Sleep -Seconds 15
        }
    }
    $sshReady = Wait-CtgSshReady -Port $SshHostPort -TimeoutSec $SshWaitSeconds
}

if ($sshReady) {
    Write-CtgLog 'SSH port open - attempting bootstrap deploy'
    foreach ($tryUser in @($creds.User, 'kali', 'sal')) {
        $tryCreds = @{ User = $tryUser; Password = $creds.Password }
        Write-CtgLog "Trying SSH user: $tryUser"
        $deployed = Invoke-CtgPlinkBootstrap -User $tryUser -Password $creds.Password -Port $SshHostPort `
            -LocalScript $BootstrapScript -ExtraArgs $bootstrapExtra
        if ($deployed) { break }
        if ($tryUser -eq 'kali' -and $creds.Password -ne 'kali') {
            $deployed = Invoke-CtgPlinkBootstrap -User 'kali' -Password 'kali' -Port $SshHostPort `
                -LocalScript $BootstrapScript -ExtraArgs $bootstrapExtra
            if ($deployed) { break }
        }
    }
} else {
    Write-CtgLog "SSH not ready - Kali may need openssh-server enabled or NAT rule applied after reboot."
    if ($InstallSshServerHint) {
        Write-CtgLog "Inside Kali terminal: sudo apt update; sudo apt install -y openssh-server; sudo systemctl enable --now ssh"
    }
}

$sharedPath = Copy-CtgBootstrapToSharedFolder -LocalScript $BootstrapScript

if (-not $deployed -and $target.Hypervisor -eq 'VirtualBox') {
    Enable-CtgVBoxSharedBootstrap -Name $target.Name -VBoxManage $target.Tool | Out-Null
}

if (-not $SkipOpnsense) {
    $opnScript = Join-Path $PSScriptRoot 'Install-OpnsenseLab.ps1'
    if (Test-Path $opnScript) {
        Write-CtgLog 'Launching OPNsense lab VM setup (non-blocking)...'
        if (-not $WhatIf) {
            try {
                & $opnScript -WhatIf:$false 2>&1 | ForEach-Object { Write-CtgLog "OPNsense: $_" }
            } catch {
                Write-CtgLog "OPNsense setup skipped or failed: $($_.Exception.Message)"
            }
        }
    }
}

Write-CtgLog '=== Deploy-KaliLab.ps1 summary ==='
Write-CtgLog "Hypervisor: $($target.Hypervisor) | VM: $($target.Name)"
Write-CtgLog "SSH ready: $sshReady | Bootstrap deployed via SSH: $deployed"
Write-CtgLog "DDG preserve: $PreserveDdgDns | ddg-dns-only: $DdgDnsOnly | lab-anonymity: $(-not $NoLabAnonymity)"
Write-CtgLog "Fallback script: $sharedPath"
Write-CtgLog "OPNsense DNS template: docs/OPNSENSE_LAB_DNS.md"
Write-CtgLog "iPhone/Windows DDG rules: docs/IPHONE_HARDENING.md"
if (-not $deployed) {
    Write-CtgLog 'MANUAL: Finish Kali install if needed, enable SSH, then re-run this script.'
    exit 1
}
exit 0
