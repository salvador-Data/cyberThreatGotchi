# Install Wireshark + Npcap on Windows host (companion to Kali lab).
# Authorized defensive lab use only — Hacker Planet LLC.
param(
    [switch]$NpcapLoopback,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

function Test-CtgWiresharkInstalled {
    $cmd = Get-Command wireshark -ErrorAction SilentlyContinue
    if ($cmd) { return $true }
    $paths = @(
        "${env:ProgramFiles}\Wireshark\Wireshark.exe",
        "${env:ProgramFiles(x86)}\Wireshark\Wireshark.exe"
    )
    return ($paths | Where-Object { Test-Path $_ }).Count -gt 0
}

if (Test-CtgWiresharkInstalled) {
    Write-Host 'Wireshark already installed.'
    wireshark --version 2>$null | Select-Object -First 1
    return
}

$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($winget) {
    Write-Host 'Installing Wireshark via winget (includes Npcap prompt during install)...'
    if ($WhatIf) {
        Write-Host '[WhatIf] winget install WiresharkFoundation.Wireshark'
        return
    }
    & winget install --id WiresharkFoundation.Wireshark -e --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'Wireshark install complete. WiFi monitor mode on Windows remains limited — use Kali VM + USB passthrough for 802.11 lab.'
        return
    }
    Write-Warning "winget exit $LASTEXITCODE — try manual download from https://www.wireshark.org/download.html"
}

$choco = Get-Command choco -ErrorAction SilentlyContinue
if ($choco) {
    Write-Host 'Installing Wireshark via Chocolatey...'
    if ($WhatIf) {
        Write-Host '[WhatIf] choco install wireshark -y'
        return
    }
    & choco install wireshark -y
    return
}

Write-Host 'Neither winget nor choco found. Manual steps:'
Write-Host '1. Download Wireshark installer from https://www.wireshark.org/download.html'
Write-Host '2. Enable Npcap during setup (WinPcap legacy not recommended)'
Write-Host '3. For USB WiFi monitor mode, use Kali VM with Realtek passthrough per KALI_LAB_ARCHITECTURE.md'

if ($NpcapLoopback) {
    Write-Host 'Optional: Npcap loopback adapter for localhost capture — enable in Npcap installer advanced options.'
}
