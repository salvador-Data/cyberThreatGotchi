<#
.SYNOPSIS
  Read-only CTG Shield status on Windows SOC host (optional Kali guest via SSH).
.DESCRIPTION
  Reports active adapter IPv4/MAC, DuckDuckGo VPN tunnel state, and DNS hints.
  Does not rotate or change network configuration.
  Optional: set CTG_KALI_SSH_HOST (default 127.0.0.1) and CTG_KALI_SSH_PORT (2222)
  to query /opt/ctg/tor-http-scrambler/ctg-shield-rotate.sh status on the lab VM.
.NOTES
  Hacker Planet LLC - authorized defensive lab use only.
#>
param(
    [string]$KaliSshHost = $(if ($env:CTG_KALI_SSH_HOST) { $env:CTG_KALI_SSH_HOST } else { '127.0.0.1' }),
    [int]$KaliSshPort = $(if ($env:CTG_KALI_SSH_PORT) { [int]$env:CTG_KALI_SSH_PORT } else { 2222 }),
    [string]$KaliUser = $(if ($env:CTG_KALI_SSH_USER) { $env:CTG_KALI_SSH_USER } else { 'kali' }),
    [switch]$SkipKaliSsh
)

$ErrorActionPreference = 'Continue'
$ddgPrimary = '94.140.14.14'
$ddgSecondary = '94.140.15.15'

function Write-CtgShieldLine([string]$Label, [string]$Value, [string]$Color = 'Gray') {
    Write-Host ("{0,-22} {1}" -f ($Label + ':'), $Value) -ForegroundColor $Color
}

function Get-CtgDdgDnsOnHost {
    $hits = @()
    try {
        $adapters = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.ServerAddresses -match '94\.140\.(14\.14|15\.15)' }
        foreach ($a in $adapters) {
            $hits += "$($a.InterfaceAlias): $($a.ServerAddresses -join ', ')"
        }
    } catch {
        return @()
    }
    return $hits
}

function Test-CtgDdgVpnConnected {
    $proc = Get-Process -Name 'DuckDuckGo.VPN', 'DuckDuckGo.VPN.WireGuard' -ErrorAction SilentlyContinue
    if (-not $proc) { return $false }
    $adapter = Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceDescription -match 'DuckDuckGo|WireGuard' -and $_.Status -eq 'Up' }
    return [bool]$adapter
}

Write-Host '--- CTG Shield status (Windows host, read-only) ---' -ForegroundColor Cyan

$vpnUp = Test-CtgDdgVpnConnected
Write-CtgShieldLine 'DuckDuckGo VPN' $(if ($vpnUp) { 'Connected' } else { 'Not connected / not installed' }) $(if ($vpnUp) { 'Green' } else { 'Yellow' })

$dnsHits = Get-CtgDdgDnsOnHost
if ($dnsHits.Count -gt 0) {
    Write-CtgShieldLine 'DDG DNS on NIC' ($dnsHits -join ' | ') 'Green'
} else {
    Write-CtgShieldLine 'DDG DNS on NIC' "No $ddgPrimary / $ddgSecondary on active IPv4 adapters (may be via VPN tunnel only)" 'Yellow'
}

$active = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | Sort-Object -Property InterfaceMetric
foreach ($nic in $active) {
    if ($nic.InterfaceDescription -match 'Loopback|VirtualBox Host-Only|VMware') { continue }
    $ip = (Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notmatch '^169\.254\.' } |
        Select-Object -First 1 -ExpandProperty IPAddress)
    if (-not $ip) { continue }
    Write-CtgShieldLine $nic.Name "$ip  MAC $($nic.MacAddress)" 'White'
}

if ($SkipKaliSsh) {
    Write-Host 'Kali SSH query skipped (-SkipKaliSsh).' -ForegroundColor Gray
    exit 0
}

$ssh = Get-Command ssh -ErrorAction SilentlyContinue
if (-not $ssh) {
    Write-Host 'OpenSSH client not found - install Windows OpenSSH Client for Kali guest status.' -ForegroundColor Yellow
    exit 0
}

$remoteCmd = 'sudo /opt/ctg/tor-http-scrambler/ctg-shield-rotate.sh status 2>/dev/null || true'
$target = "${KaliUser}@${KaliSshHost}"
Write-Host "--- Kali guest ($target port $KaliSshPort) ---" -ForegroundColor Cyan

try {
    $kaliOut = & ssh -p $KaliSshPort -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new $target $remoteCmd 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "SSH unavailable (start VM, NAT port $KaliSshPort, or use -SkipKaliSsh): $kaliOut" -ForegroundColor Yellow
    } else {
        $kaliOut | ForEach-Object { Write-Host $_ }
    }
} catch {
    Write-Host "SSH error: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host 'Rotate on Kali: sudo /opt/ctg/tor-http-scrambler/ctg-shield-rotate.sh rotate' -ForegroundColor Gray
Write-Host 'Playbook: docs/CTG_SHIELD_SIEM_PLAYBOOK.md' -ForegroundColor Gray
