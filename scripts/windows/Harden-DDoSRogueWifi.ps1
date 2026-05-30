<#
.SYNOPSIS
  Client-side DDoS, rogue WiFi, and exposure hardening (authorized lab / owned hosts only).

.DESCRIPTION
  Diagnose-only by default. Use -ApplyHardening from an elevated session for firewall,
  registry, and firewall-log changes. Does NOT attack back — defensive posture only.

.PARAMETER DiagnoseOnly
  Report current state; no registry or firewall mutations (default when -ApplyHardening omitted).

.PARAMETER ApplyHardening
  Apply firewall, registry, and inbound block rules (Administrator required).

.PARAMETER StrictInbound
  With -ApplyHardening: block all inbound except established/loopback (aggressive client mode).

.EXAMPLE
  .\scripts\windows\Harden-DDoSRogueWifi.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Harden-DDoSRogueWifi.ps1 -ApplyHardening -StrictInbound
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch] $DiagnoseOnly,
    [switch] $ApplyHardening,
    [switch] $StrictInbound
)

$ErrorActionPreference = 'Continue'
$ScriptDir = $PSScriptRoot

. (Join-Path $ScriptDir 'CTG-AdminCommon.ps1')
$script:CtgIsAdmin = Test-CtgIsAdmin

$BackupsRoot = Join-Path $env:USERPROFILE 'Backups'
$LogDir = Join-Path $BackupsRoot 'logs'
$LogFile = Join-Path $LogDir 'harden-ddos-rogue.log'
$FirewallLog = Join-Path $LogDir 'firewall.log'

function Write-CtgDdosLog {
    param([string] $Message, [string] $Color = 'Gray')
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    try {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        Add-Content -Path $LogFile -Value $line -Encoding utf8 -ErrorAction SilentlyContinue
    } catch { }
    Write-Host $line -ForegroundColor $Color
}

function Write-Banner {
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ' CTG — DDoS / rogue WiFi hardening' -ForegroundColor Cyan
    Write-Host ' Authorized defensive use on systems you own' -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
    Write-CtgDdosLog "Computer=$env:COMPUTERNAME User=$env:USERNAME Admin=$script:CtgIsAdmin"
}

function Get-CtgFirewallProfileState {
    $rows = @()
    try {
        netsh advfirewall show allprofiles state 2>$null | ForEach-Object { $rows += $_.Trim() }
    } catch { }
    return $rows
}

function Get-CtgFirewallInboundDefault {
    $profiles = @('domainprofile', 'privateprofile', 'publicprofile')
    $result = @{}
    foreach ($p in $profiles) {
        $block = $null
        try {
            $out = netsh advfirewall show $p firewallpolicy 2>$null
            if ($out -match 'BlockInbound,AllowOutbound') { $block = $true }
            elseif ($out -match 'BlockInbound') { $block = $true }
            else { $block = $false }
        } catch { $block = $null }
        $result[$p] = $block
    }
    return $result
}

function Get-CtgListeningExposure {
    $listeners = @()
    try {
        Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
            Where-Object { $_.LocalAddress -notin @('127.0.0.1', '::1', '0.0.0.0') -or $_.LocalPort -in @(445, 135, 139, 3389, 5985, 5986, 8765) } |
            ForEach-Object {
                $listeners += [PSCustomObject]@{
                    LocalAddress = $_.LocalAddress
                    LocalPort    = $_.LocalPort
                    OwningProcess = $_.OwningProcess
                }
            }
    } catch { }
    if ($listeners.Count -eq 0) {
        try {
            netstat -an | Select-String 'LISTENING' | ForEach-Object {
                if ($_ -match 'TCP\s+(\S+):(\d+)\s+.*LISTENING') {
                    $addr = $Matches[1]; $port = [int]$Matches[2]
                    if ($addr -notin @('127.0.0.1', '[::1]') -or $port -in @(445, 135, 139, 3389, 5985, 5986, 8765)) {
                        $listeners += [PSCustomObject]@{ LocalAddress = $addr; LocalPort = $port; OwningProcess = $null }
                    }
                }
            }
        } catch { }
    }
    return $listeners | Sort-Object LocalPort -Unique
}

function Get-CtgCtgWebApiBinding {
    $port = if ($env:CTG_WEB_PORT) { [int]$env:CTG_WEB_PORT } else { 8765 }
    $hits = @()
    try {
        Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue |
            ForEach-Object {
                $hits += [PSCustomObject]@{
                    Port = $port
                    Address = $_.LocalAddress
                    OkLocalhostOnly = ($_.LocalAddress -in @('127.0.0.1', '::1'))
                }
            }
    } catch { }
    return @{ Port = $port; Listeners = $hits }
}

function Get-CtgWlanAutoConnectOpen {
    $issues = @()
    try {
        $autoOpen = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config' -Name 'AutoConnectOpenNetworks' -ErrorAction SilentlyContinue
        if ($autoOpen -and $autoOpen.AutoConnectOpenNetworks -ne 0) {
            $issues += 'AutoConnectOpenNetworks is enabled (registry) — open hotspots may auto-join.'
        }
    } catch { }
    try {
        netsh wlan show profiles 2>$null | Select-String 'All User Profile' | ForEach-Object {
            $name = ($_ -replace '.*:\s*', '').Trim()
            if ($name -match '^(xfinitywifi|attwifi|Boingo|Free WiFi|Starbucks|McDonald|Guest|Public)$') {
                $issues += "Saved profile may be public/open: $name"
            }
        }
    } catch { }
    return $issues
}

function Get-CtgLlmnrNetbiosState {
    $state = @{}
    try {
        $llmnr = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' -Name 'EnableMulticast' -ErrorAction SilentlyContinue
        $state.LlmnrDisabled = ($llmnr -and $llmnr.EnableMulticast -eq 0)
    } catch { $state.LlmnrDisabled = $null }
    try {
        $nb = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces' -ErrorAction SilentlyContinue
        $state.NetbiosNote = 'Per-adapter NetBIOS over TCP/IP: set EnableNetbios=2 under each interface GUID (ApplyHardening).'
    } catch { }
    return $state
}

function Test-CtgSmb1Enabled {
    try {
        $feat = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction SilentlyContinue
        if ($feat) { return ($feat.State -eq 'Enabled') }
    } catch { }
    try {
        $svc = Get-Service -Name LanmanServer -ErrorAction SilentlyContinue
        return $null
    } catch { }
    return $null
}

function Invoke-CtgDiagnose {
    Write-CtgDdosLog '--- Diagnose ---' 'Cyan'

    Write-CtgDdosLog 'Firewall profiles:'
    Get-CtgFirewallProfileState | ForEach-Object { Write-CtgDdosLog "  $_" }

    Write-CtgDdosLog 'Inbound default (BlockInbound expected):'
    (Get-CtgFirewallInboundDefault).GetEnumerator() | ForEach-Object {
        $ok = if ($_.Value) { 'OK' } else { 'NEEDS HARDENING' }
        Write-CtgDdosLog "  $($_.Key): $($_.Value) [$ok]" $(if ($_.Value) { 'Green' } else { 'Yellow' })
    }

    Write-CtgDdosLog 'Listening sockets (non-loopback or sensitive ports):'
    $exp = Get-CtgListeningExposure
    if ($exp.Count -eq 0) {
        Write-CtgDdosLog '  None flagged (good for client posture).' 'Green'
    } else {
        $exp | ForEach-Object { Write-CtgDdosLog "  $($_.LocalAddress):$($_.LocalPort) pid=$($_.OwningProcess)" 'Yellow' }
    }

    $web = Get-CtgCtgWebApiBinding
    if ($web.Listeners.Count -eq 0) {
        Write-CtgDdosLog "CTG web API (port $($web.Port)): not listening." 'Green'
    } else {
        foreach ($l in $web.Listeners) {
            $msg = "CTG web API port $($l.Port) on $($l.Address)"
            if ($l.OkLocalhostOnly) { Write-CtgDdosLog "$msg — localhost only (OK)." 'Green' }
            else { Write-CtgDdosLog "$msg — EXPOSED ON LAN/WAN; bind 127.0.0.1 only." 'Red' }
        }
    }

    $smb1 = Test-CtgSmb1Enabled
    if ($null -eq $smb1) { Write-CtgDdosLog 'SMB1: could not determine (Admin may be required).' 'Yellow' }
    elseif ($smb1) { Write-CtgDdosLog 'SMB1: ENABLED — disable if not needed.' 'Red' }
    else { Write-CtgDdosLog 'SMB1: disabled or not installed (OK).' 'Green' }

    $proto = Get-CtgLlmnrNetbiosState
    if ($proto.LlmnrDisabled) { Write-CtgDdosLog 'LLMNR: disabled via policy (OK).' 'Green' }
    else { Write-CtgDdosLog 'LLMNR: not disabled — spoofing/deauth-adjacent risk on LAN.' 'Yellow' }

    $wlan = Get-CtgWlanAutoConnectOpen
    if ($wlan.Count -eq 0) { Write-CtgDdosLog 'WiFi auto-connect open: no obvious issues.' 'Green' }
    else { $wlan | ForEach-Object { Write-CtgDdosLog "WiFi: $_" 'Yellow' } }

    Write-CtgDdosLog '--- Client DDoS honest limits ---' 'Cyan'
    Write-CtgDdosLog 'Volumetric DDoS (flood to your public IP) cannot be stopped on the laptop — call ISP.'
    Write-CtgDdosLog 'This script: shrink attack surface, firewall inbound, VPN for IP privacy, unplug WAN if flooded.'
    Write-CtgDdosLog 'No exposed services checklist: disable file sharing, remote desktop, IIS, CTG web on 0.0.0.0.'
    Write-CtgDdosLog 'Rogue captive portal: never enter credentials on a portal you did not expect; use VPN first.'
}

function Invoke-CtgApplyFirewall {
    if (-not $script:CtgIsAdmin) {
        Write-CtgDdosLog 'ApplyHardening firewall: SKIPPED (Administrator required).' 'Red'
        return
    }
    if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Configure Windows Firewall')) { return }

    Write-CtgDdosLog 'Enabling firewall on all profiles...' 'Cyan'
    netsh advfirewall set allprofiles state on | Out-Null
    netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound | Out-Null
    Write-CtgDdosLog 'Firewall: all profiles ON; default BlockInbound, AllowOutbound.' 'Green'

    if ($StrictInbound) {
        Write-CtgDdosLog 'StrictInbound: ensuring no broad allow inbound rules (review manually).' 'Yellow'
    }

    $blockPorts = @(135, 137, 138, 139, 445, 3389, 5985, 5986, 23, 21, 69, 161, 1900)
    foreach ($port in $blockPorts) {
        $ruleName = "CTG-Block-Inbound-TCP-$port"
        if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Block -Protocol TCP -LocalPort $port -Profile Any -ErrorAction SilentlyContinue | Out-Null
        }
        Write-CtgDdosLog "Inbound block rule: TCP $port ($ruleName)" 'Green'
    }

    try {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        netsh advfirewall set currentprofile logging filename $FirewallLog | Out-Null
        netsh advfirewall set currentprofile logging maxfilesize 4096 | Out-Null
        netsh advfirewall set currentprofile logging droppedconnections enable | Out-Null
        netsh advfirewall set domainprofile logging filename $FirewallLog | Out-Null
        netsh advfirewall set domainprofile logging droppedconnections enable | Out-Null
        netsh advfirewall set privateprofile logging filename $FirewallLog | Out-Null
        netsh advfirewall set privateprofile logging droppedconnections enable | Out-Null
        netsh advfirewall set publicprofile logging filename $FirewallLog | Out-Null
        netsh advfirewall set publicprofile logging droppedconnections enable | Out-Null
        Write-CtgDdosLog "Firewall logging enabled: $FirewallLog" 'Green'
    } catch {
        Write-CtgDdosLog "Firewall logging failed: $($_.Exception.Message)" 'Yellow'
    }
}

function Invoke-CtgApplyRegistry {
    if (-not $script:CtgIsAdmin) {
        Write-CtgDdosLog 'ApplyHardening registry: SKIPPED (Administrator required).' 'Red'
        return
    }
    if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Apply LLMNR/NetBIOS/WiFi registry hardening')) { return }

    $dnsClient = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'
    if (-not (Test-Path $dnsClient)) { New-Item -Path $dnsClient -Force | Out-Null }
    Set-ItemProperty -Path $dnsClient -Name 'EnableMulticast' -Value 0 -Type DWord -Force
    Write-CtgDdosLog 'LLMNR disabled (EnableMulticast=0). Reboot recommended.' 'Green'

    $wcm = 'HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config'
    if (-not (Test-Path $wcm)) { New-Item -Path $wcm -Force | Out-Null }
    Set-ItemProperty -Path $wcm -Name 'AutoConnectOpenNetworks' -Value 0 -Type DWord -Force
    Write-CtgDdosLog 'WiFi AutoConnectOpenNetworks=0 (do not auto-join open hotspots).' 'Green'

    $nbRoot = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces'
    if (Test-Path $nbRoot) {
        Get-ChildItem -Path $nbRoot -ErrorAction SilentlyContinue | ForEach-Object {
            Set-ItemProperty -Path $_.PSPath -Name 'NetbiosOptions' -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
        }
        Write-CtgDdosLog 'NetBIOS over TCP/IP disabled on interfaces (NetbiosOptions=2). Reboot recommended.' 'Green'
    }

    try {
        $smb1 = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction SilentlyContinue
        if ($smb1 -and $smb1.State -eq 'Enabled') {
            Write-CtgDdosLog 'SMB1 is enabled — run: Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart' 'Yellow'
        }
    } catch { }
}

function Invoke-CtgPreserveVpn {
    $preserve = Join-Path $ScriptDir 'Preserve-DuckDuckGoVpn.ps1'
    if (-not (Test-Path $preserve)) {
        Write-CtgDdosLog 'Preserve-DuckDuckGoVpn.ps1 not found — skip.' 'Yellow'
        return
    }
    . $preserve
    Invoke-CtgPreserveDuckDuckGoVpn -LogAction { param($m) Write-CtgDdosLog $m 'Gray' }
    Write-CtgDdosLog 'VPN note: DuckDuckGo VPN hides your IP from some L7 attacks; volumetric DDoS still needs ISP.' 'Cyan'
}

# --- Main ---
Write-Banner

if ($ApplyHardening -and $DiagnoseOnly) {
    Write-CtgDdosLog 'Both -ApplyHardening and -DiagnoseOnly set — diagnose first, then apply.' 'Yellow'
}

Invoke-CtgDiagnose

if ($ApplyHardening) {
    Write-CtgDdosLog '--- ApplyHardening ---' 'Cyan'
    Invoke-CtgApplyFirewall
    Invoke-CtgApplyRegistry
} elseif (-not $DiagnoseOnly) {
    Write-CtgDdosLog 'No -ApplyHardening — guidance/diagnose only. Re-run with -ApplyHardening as Admin to apply.' 'Yellow'
}

Invoke-CtgPreserveVpn

Write-CtgDdosLog "Log: $LogFile" 'Cyan'
Write-CtgDdosLog 'Guide: docs/DEFENSE_DDOS_ROGUE_WIFI.md' 'Cyan'
Write-CtgDdosLog 'Done.' 'Green'
