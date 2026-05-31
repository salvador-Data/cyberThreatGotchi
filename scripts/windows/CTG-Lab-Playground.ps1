# CTG Lab Playground — interactive Windows SOC menu (authorized lab only).
# Hacker Planet LLC · Philadelphia, PA
param()

$ErrorActionPreference = 'Continue'
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$BackupRoot = 'C:\Users\Owner\Backups'

function Write-CtgPlayLine([string]$Text, [string]$Color = 'White') {
    Write-Host $Text -ForegroundColor $Color
}

function Write-CtgProfessor([string]$Note) {
    Write-Host ''
    Write-Host "  Professor note: $Note" -ForegroundColor DarkCyan
    Write-Host ''
}

function Show-CtgPlaygroundMenu {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '  CTG Lab Playground — Windows SOC (authorized lab only)' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '  1  Wireshark IDS DiagnoseOnly'
    Write-Host '  2  CTG Shield Status (host + optional Kali SSH)'
    Write-Host '  3  DDoS / rogue WiFi diagnose'
    Write-Host '  4  Open kickstarter.html / feeds (if present)'
    Write-Host '  5  Start 2-min Wireshark capture demo'
    Write-Host '  6  SMS test (Twilio via .env)'
    Write-Host '  7  Launch VirtualBox Kali + print Kali playground command'
    Write-Host '  0  Exit'
    Write-Host '============================================================' -ForegroundColor Cyan
}

function Invoke-CtgPlayWiresharkDiagnose {
    Write-CtgProfessor 'Wireshark IDS on Windows is detect-only heuristics plus optional netsh blocks for repeat offenders on YOUR lab NIC. Full inline IPS belongs on OPNsense Suricata.'
    $script = Join-Path $PSScriptRoot 'Start-CTGWiresharkIDS.ps1'
    if (-not (Test-Path $script)) {
        Write-CtgPlayLine "Not found: $script" 'Yellow'
        return
    }
    & $script -DiagnoseOnly
}

function Invoke-CtgPlayShieldStatus {
    Write-CtgProfessor 'Shield status is read-only on Windows (DDG VPN, DNS, NIC IP/MAC). USB wlan rotate happens on Kali via ctg-shield-rotate.sh.'
    $script = Join-Path $PSScriptRoot 'CTG-Shield-Status.ps1'
    if (-not (Test-Path $script)) {
        Write-CtgPlayLine "Not found: $script" 'Yellow'
        return
    }
    & $script
}

function Invoke-CtgPlayDdosDiagnose {
    Write-CtgProfessor 'Client-side hardening cannot stop volumetric DDoS to your public IP — that needs your ISP. This diagnose checks firewall posture, rogue WiFi exposure, and honest limits.'
    $script = Join-Path $PSScriptRoot 'Harden-DDoSRogueWifi.ps1'
    if (-not (Test-Path $script)) {
        Write-CtgPlayLine "Not found: $script" 'Yellow'
        return
    }
    & $script -DiagnoseOnly
}

function Invoke-CtgPlayOpenWebPages {
    Write-CtgProfessor 'Kickstarter and feeds pages are static site previews — open locally before pushing to GitHub Pages.'
    $candidates = @(
        (Join-Path $RepoRoot 'website\kickstarter.html'),
        (Join-Path $RepoRoot 'website\feeds.html'),
        (Join-Path $RepoRoot 'docs\web\kickstarter.html'),
        (Join-Path $RepoRoot 'docs\web\feeds.html')
    )
    $opened = 0
    foreach ($path in $candidates | Select-Object -Unique) {
        if (-not (Test-Path $path)) { continue }
        Write-CtgPlayLine "Opening: $path" 'Green'
        Start-Process $path
        $opened++
    }
    if ($opened -eq 0) {
        Write-CtgPlayLine 'No kickstarter.html or feeds.html found in repo — run website sync or pull latest.' 'Yellow'
    }
}

function Invoke-CtgPlayCaptureDemo {
    Write-CtgProfessor 'Two-minute ring capture writes to Backups/logs — lab traffic only. Stop early with Ctrl+C if you need to.'
    $script = Join-Path $PSScriptRoot 'Start-CTGWiresharkIDS.ps1'
    if (-not (Test-Path $script)) {
        Write-CtgPlayLine "Not found: $script" 'Yellow'
        return
    }
    & $script -CaptureMinutes 2 -OptimizeCapture -NoSms
}

function Invoke-CtgPlaySmsTest {
    Write-CtgProfessor 'SMS uses Twilio env vars from .env only — never commit secrets. Rate limit applies except for -TestMessage.'
    $script = Join-Path $PSScriptRoot 'Send-CtgSmsAlert.ps1'
    if (-not (Test-Path $script)) {
        Write-CtgPlayLine "Not found: $script" 'Yellow'
        return
    }
    $envPath = Join-Path $RepoRoot '.env'
    if (-not (Test-Path $envPath)) {
        Write-CtgPlayLine 'No .env — set TWILIO_* and CTG_ALERT_SMS_TO locally (see docs/WIRESHARK_IDS_SMS.md)' 'Yellow'
        return
    }
    try {
        & $script -TestMessage
    } catch {
        Write-CtgPlayLine "SMS test failed: $($_.Exception.Message)" 'Yellow'
    }
}

function Invoke-CtgPlayKaliVm {
    Write-CtgProfessor 'Kali playground runs inside the VM after mounting the ctg-backups share. Windows host starts Kali in VirtualBox seamless mode (Guest Additions required); in-guest menu is root-only. Host+L toggles seamless.'
    $seamlessScript = Join-Path $PSScriptRoot 'Start-KaliSeamless.ps1'
    if (Test-Path $seamlessScript) {
        & $seamlessScript
    } else {
        Write-CtgPlayLine "Not found: $seamlessScript — run Deploy-KaliLab.ps1 first." 'Yellow'
    }
    Write-Host ''
    Write-CtgPlayLine 'In Kali (after mount):' 'Cyan'
    Write-CtgPlayLine '  sudo mkdir -p /mnt/ctg' 'White'
    Write-CtgPlayLine '  sudo mount -t vboxsf ctg-backups /mnt/ctg' 'White'
    Write-CtgPlayLine '  sudo bash /mnt/ctg/ctg-lab-playground.sh' 'Green'
    Write-CtgPlayLine 'Docs: docs/CTG_LAB_PLAYGROUND.md' 'Gray'
}

Write-CtgPlayLine '=== CTG Lab Playground (Windows) ===' 'Cyan'
Write-CtgPlayLine "Repo: $RepoRoot" 'Gray'

while ($true) {
    Show-CtgPlaygroundMenu
    $choice = Read-Host '  Choose [0-7]'
    switch ($choice) {
        '1' { Invoke-CtgPlayWiresharkDiagnose }
        '2' { Invoke-CtgPlayShieldStatus }
        '3' { Invoke-CtgPlayDdosDiagnose }
        '4' { Invoke-CtgPlayOpenWebPages }
        '5' { Invoke-CtgPlayCaptureDemo }
        '6' { Invoke-CtgPlaySmsTest }
        '7' { Invoke-CtgPlayKaliVm }
        '0' { Write-CtgPlayLine 'Good lab session — stay defensive.' 'Cyan'; break }
        default { Write-CtgPlayLine "Invalid choice: $choice" 'Yellow' }
    }
    if ($choice -eq '0') { break }
    Read-Host '  Press Enter to return to menu'
}
