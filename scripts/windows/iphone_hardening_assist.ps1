<#
.SYNOPSIS
  Interactive Windows assistant for iPhone 15 Pro Max Phase 1+2 hardening (guided, not MDM).

.DESCRIPTION
  Best-effort guided automation for authorized personal device hardening. Does NOT modify
  the iPhone, push profiles, or change Settings from the PC. Preserves DuckDuckGo VPN/DNS
  and DuckDuckGo Password Manager - warns before any step that could conflict.

  Runs iphone_usb_check.ps1, logs to Backups\logs\, prints a numbered Phase 1+2 checklist
  with iOS Settings deep-link URLs (tap on phone via AirDrop, email, or GitHub Pages).

.PARAMETER OpenRunbook
  Open docs/IPHONE_RUN_NOW.md locally and the tap-friendly GitHub Pages runbook in browser.

.PARAMETER OpenGuide
  Open docs/iphone_hardening_guide.html in the default browser and print paths to open the same
  guided wizard on the iPhone (AirDrop, email, Files, or optional LAN URL).

.PARAMETER ServeOnLan
  With -OpenGuide only: start a short-lived Python http.server on port 8765 serving docs/ so the
  phone can open http://<laptop-lan-ip>:8765/iphone_hardening_guide.html. Requires approval on
  the same Wi-Fi; binds 0.0.0.0 (LAN only — stop server when done).

.PARAMETER LogOnly
  CI-style check: verify repo, run USB check, write log, exit without interactive prompts.

.PARAMETER LogDir
  Directory for iphone_hardening_assist.log (default: %USERPROFILE%\Backups\logs).

.EXAMPLE
  .\scripts\windows\iphone_hardening_assist.ps1

.EXAMPLE
  .\scripts\windows\iphone_hardening_assist.ps1 -OpenRunbook

.EXAMPLE
  .\scripts\windows\iphone_hardening_assist.ps1 -OpenGuide

.EXAMPLE
  .\scripts\windows\iphone_hardening_assist.ps1 -OpenGuide -ServeOnLan

.EXAMPLE
  .\scripts\windows\iphone_hardening_assist.ps1 -LogOnly
#>
[CmdletBinding()]
param(
    [switch] $OpenRunbook,
    [switch] $OpenGuide,
    [switch] $ServeOnLan,
    [switch] $LogOnly,
    [string] $LogDir = ''
)

$ErrorActionPreference = 'Continue'
$ScriptDir = $PSScriptRoot
$RepoRoot = Split-Path (Split-Path $ScriptDir -Parent) -Parent

$RunbookLocal = Join-Path $RepoRoot 'docs\IPHONE_RUN_NOW.md'
$GuideHtml = Join-Path $RepoRoot 'docs\iphone_hardening_guide.html'
$RunbookWeb = 'https://salvador-Data.github.io/cyberThreatGotchi/iphone-run-now.html'
$RunbookGitHub = 'https://github.com/salvador-Data/cyberThreatGotchi/blob/main/docs/IPHONE_RUN_NOW.md'
$ShortcutsDoc = Join-Path $RepoRoot 'docs\iphone_hardening_shortcuts.md'
$MalwarebytesAppStore = 'https://apps.apple.com/us/app/malwarebytes-mobile-security/id1327105431'
$LanGuidePort = 8765

if (-not $LogDir) {
    $LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
}
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$logFile = Join-Path $LogDir 'iphone_hardening_assist.log'
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

function Write-AssistLog {
    param([string] $Message)
    $line = "[$stamp] iphone_hardening_assist: $Message"
    Add-Content -Path $logFile -Value $line -Encoding UTF8
    Write-Output $line
}

function Test-CtgRepo {
    $markers = @(
        (Join-Path $RepoRoot 'docs\IPHONE_HARDENING.md'),
        (Join-Path $RepoRoot 'docs\IPHONE_RUN_NOW.md'),
        (Join-Path $RepoRoot 'docs\iphone_hardening_guide.html'),
        (Join-Path $ScriptDir 'iphone_usb_check.ps1')
    )
    foreach ($m in $markers) {
        if (-not (Test-Path $m)) {
            throw "CTG repo marker missing: $m (run from cyberThreatGotchi clone)"
        }
    }
}

function Get-CtgHardeningChecklist {
    @(
        @{
            Num = '0'
            Phase = 'Baseline'
            Title = 'Document VPN, Wi-Fi DNS, DuckDuckGo Password Manager - DO NOT change'
            Manual = 'Settings -> General -> VPN & Device Management -> VPN; Wi-Fi -> (i) -> Configure DNS; General -> AutoFill & Passwords -> DuckDuckGo Autofill On'
            Links = @(
                'prefs:root=General&path=ManagedConfigurationList'
                'prefs:root=WIFI'
                'prefs:root=PASSWORDS'
            )
            Warn = 'KEEP DuckDuckGo VPN/DNS + DuckDuckGo Password Manager. Do not install Cloudflare/NextDNS on top.'
        }
        @{
            Num = '1.1'
            Phase = 'Phase 1'
            Title = 'Software Update - latest iOS 17/18; Automatic Updates On'
            Manual = 'Settings -> General -> Software Update -> Automatic Updates -> On (iOS + Security Responses)'
            Links = @(
                'prefs:root=General&path=SOFTWARE_UPDATE_LINK'
                'App-Prefs:root=General&path=SOFTWARE_UPDATE_LINK'
            )
        }
        @{
            Num = '1.2'
            Phase = 'Phase 1'
            Title = 'Passcode, Face ID, Stolen Device Protection'
            Manual = 'Settings -> Face ID & Passcode -> Custom Alphanumeric Code; Stolen Device Protection -> On (iOS 17.3+) - enroll on device only'
            Links = @('prefs:root=PASSCODE')
            CannotAutomate = 'Passcode change, Face ID enroll, Stolen Device Protection require on-device biometrics'
        }
        @{
            Num = '1.3'
            Phase = 'Phase 1'
            Title = 'Find My iPhone + network + Send Last Location'
            Manual = 'Settings -> [your name] -> Find My -> Find My iPhone -> On'
            Links = @('prefs:root=APPLE_ACCOUNT')
        }
        @{
            Num = '1.4'
            Phase = 'Phase 1'
            Title = 'Apple ID - 2FA On; remove unknown devices'
            Manual = 'Settings -> [your name] -> Sign-In & Security -> Two-Factor Authentication -> On; review Devices'
            Links = @('prefs:root=APPLE_ACCOUNT')
        }
        @{
            Num = '1.5'
            Phase = 'Phase 1'
            Title = 'Safari - fraud warning, cross-site tracking, hide IP'
            Manual = 'Settings -> Apps -> Safari - Fraudulent Website Warning On; Prevent Cross-Site Tracking On; Hide IP Address'
            Links = @(
                'App-prefs:com.apple.mobilesafari'
                'prefs:root=SAFARI'
            )
        }
        @{
            Num = '1.6'
            Phase = 'Phase 1'
            Title = 'Mail - Protect Mail Activity'
            Manual = 'Settings -> Apps -> Mail -> Privacy Protection -> Protect Mail Activity -> On'
            Links = @('prefs:root=MAIL')
        }
        @{
            Num = '1.7'
            Phase = 'Phase 1'
            Title = 'Privacy - Bluetooth, Local Network, Tracking'
            Manual = 'Settings -> Privacy & Security -> Bluetooth / Local Network - revoke unneeded; Tracking -> deny'
            Links = @(
                'prefs:root=Privacy'
                'prefs:root=Bluetooth'
            )
        }
        @{
            Num = '1.8'
            Phase = 'Phase 1'
            Title = 'Lock screen - limit Allow Access When Locked; notification previews'
            Manual = 'Settings -> Face ID & Passcode -> Allow Access When Locked; Notifications -> sensitive apps -> When Unlocked'
            Links = @(
                'prefs:root=PASSCODE#ALLOW_ACCESS_WHEN_LOCKED'
                'prefs:root=NOTIFICATIONS_ID'
            )
        }
        @{
            Num = '1.9'
            Phase = 'Phase 1'
            Title = 'USB Restricted Mode - USB Accessories Off when locked'
            Manual = 'Settings -> Face ID & Passcode -> USB Accessories (Allow Accessories When Locked) -> Off'
            Links = @('prefs:root=PASSCODE')
        }
        @{
            Num = '1.10'
            Phase = 'Phase 1'
            Title = 'AirDrop Contacts Only; audit VPN & Device Management profiles'
            Manual = 'Settings -> General -> AirDrop -> Contacts Only; VPN & Device Management - remove unknown profiles only'
            Links = @(
                'prefs:root=General&path=AIRDROP_LINK'
                'prefs:root=General&path=ManagedConfigurationList'
            )
        }
        @{
            Num = '1.11'
            Phase = 'Phase 1'
            Title = 'AutoFill - verify DuckDuckGo Password Manager stays On'
            Manual = 'Settings -> General -> AutoFill & Passwords -> DuckDuckGo Passwords / DuckDuckGo Autofill -> On (do NOT turn off)'
            Links = @('prefs:root=PASSWORDS')
            Warn = 'Do not migrate to Apple Keychain during hardening unless you choose to.'
        }
        @{
            Num = '1.V'
            Phase = 'Verify'
            Title = 'Phase 1 verify - VPN, DNS, DuckDuckGo Autofill unchanged'
            Manual = 'Re-check VPN profile, Wi-Fi Configure DNS, AutoFill & Passwords - must match Step 0 baseline'
            Links = @(
                'prefs:root=General&path=ManagedConfigurationList'
                'prefs:root=WIFI'
                'prefs:root=PASSWORDS'
            )
        }
        @{
            Num = '2.1'
            Phase = 'Phase 2'
            Title = 'Install Malwarebytes Mobile Security (App Store - on phone)'
            Manual = 'App Store -> Malwarebytes Mobile Security -> Get -> complete onboarding on device'
            Links = @($MalwarebytesAppStore)
            CannotAutomate = 'App Store install and Malwarebytes permissions require on-device taps'
        }
        @{
            Num = '2.2'
            Phase = 'Phase 2'
            Title = 'Malwarebytes SMS + Safari extensions; NOT Malwarebytes paid VPN'
            Manual = 'Settings -> Apps -> Messages -> Unknown & Spam -> Malwarebytes; Safari -> Extensions -> Malwarebytes. Skip Malwarebytes VPN - keep DuckDuckGo.'
            Links = @(
                'App-prefs:com.apple.MobileSMS'
                'App-prefs:com.apple.mobilesafari'
            )
            Warn = 'Do NOT enable Malwarebytes paid VPN - preserves DuckDuckGo VPN/DNS.'
        }
        @{
            Num = '2.3'
            Phase = 'Phase 2'
            Title = 'USB hardening - Trust This Computer, Developer Mode Off, encrypted backup'
            Manual = 'Trust only this laptop; Developer Mode Off; Apple Devices on Windows -> Encrypt local backup. Reset Location & Privacy if trust is uncertain.'
            Links = @('prefs:root=PASSCODE')
            CannotAutomate = 'Trust This Computer dialog and encrypted backup password are on-device / Apple Devices UI'
        }
        @{
            Num = '2.4'
            Phase = 'Phase 2'
            Title = 'Lockdown Mode (optional - high-threat only)'
            Manual = 'Settings -> Privacy & Security -> Lockdown Mode -> On - skip for normal daily use'
            Links = @('prefs:root=Privacy')
        }
        @{
            Num = '2.V'
            Phase = 'Verify'
            Title = 'Phase 2 verify - VPN + DNS still match baseline; browse a familiar site'
            Manual = 'Settings -> VPN & Device Management -> VPN; Wi-Fi (i) -> Configure DNS - unchanged from Step 0'
            Links = @(
                'prefs:root=General&path=ManagedConfigurationList'
                'prefs:root=WIFI'
            )
        }
    )
}

function Format-DeepLinkHint {
    param([string[]] $Links)
    if (-not $Links -or $Links.Count -eq 0) {
        return '(open Settings manually - see path above)'
    }
    $primary = $Links[0]
    if ($primary -match '^https?://') {
        return "App Store / web: $primary"
    }
    $alt = if ($Links.Count -gt 1) { " | alt: $($Links[1])" } else { '' }
    return "Tap on iPhone: $primary$alt (iOS 17/18: may open parent pane only - follow manual path)"
}

function Show-CtgHardeningBanner {
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ' CyberThreatGotchi - iPhone hardening assist' -ForegroundColor Cyan
    Write-Host ' Guided automation (Windows). You own this device.' -ForegroundColor Cyan
    Write-Host ' Stock iOS: no remote Settings changes without MDM.' -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host " Repo:     $RepoRoot"
    Write-Host " Computer: $env:COMPUTERNAME"
    Write-Host " Date:     $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host ''
    Write-Host 'PRESERVE: DuckDuckGo VPN/DNS + DuckDuckGo Password Manager - do not replace.' -ForegroundColor Yellow
    Write-Host ''
}

function Show-CtgChecklist {
    param($Items)
    $currentPhase = ''
    foreach ($item in $Items) {
        if ($item.Phase -ne $currentPhase) {
            $currentPhase = $item.Phase
            Write-Host ''
            Write-Host "--- $($item.Phase) ---" -ForegroundColor Green
        }
        Write-Host ''
        Write-Host "[$($item.Num)] $($item.Title)" -ForegroundColor White
        Write-Host "    Manual: $($item.Manual)" -ForegroundColor Gray
        Write-Host "    Link:   $(Format-DeepLinkHint -Links $item.Links)" -ForegroundColor DarkCyan
        if ($item.Warn) {
            Write-Host "    WARN:   $($item.Warn)" -ForegroundColor Yellow
        }
        if ($item.CannotAutomate) {
            Write-Host "    Limit:  $($item.CannotAutomate)" -ForegroundColor DarkYellow
        }
    }
    Write-Host ''
    Write-Host 'Guided wizard (Prev/Next on phone):' -ForegroundColor Cyan
    Write-Host "  file: $GuideHtml" -ForegroundColor Cyan
    Write-Host '  run:  .\scripts\windows\iphone_hardening_assist.ps1 -OpenGuide' -ForegroundColor Cyan
    Write-Host 'Shortcuts: docs/iphone_hardening_shortcuts.md' -ForegroundColor Cyan
    Write-Host "Static list: $RunbookWeb" -ForegroundColor Cyan
    Write-Host ''
}

function Get-CtgLanIPv4 {
    $addrs = @()
    try {
        $addrs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object {
                $_.IPAddress -notmatch '^127\.' -and
                $_.IPAddress -notmatch '^169\.254\.' -and
                $_.PrefixOrigin -ne 'WellKnown'
            } |
            Select-Object -ExpandProperty IPAddress -Unique
    } catch {
        $addrs = @()
    }
    if ($addrs.Count -eq 0) {
        try {
            $hostEntry = [System.Net.Dns]::GetHostEntry($env:COMPUTERNAME)
            $addrs = $hostEntry.AddressList |
                Where-Object { $_.AddressFamily -eq 'InterNetwork' -and $_.ToString() -notmatch '^127\.' } |
                ForEach-Object { $_.ToString() }
        } catch {
            $addrs = @()
        }
    }
    return @($addrs | Select-Object -First 3)
}

function Start-CtgGuideLanServer {
    param([string] $DocsDir, [int] $Port)
    $exe = $null
    if (Get-Command python -ErrorAction SilentlyContinue) {
        $exe = (Get-Command python).Source
    } elseif (Get-Command py -ErrorAction SilentlyContinue) {
        $exe = (Get-Command py).Source
    }
    if (-not $exe) {
        Write-Host 'Python not found - skip -ServeOnLan or install Python 3.' -ForegroundColor Yellow
        return $null
    }
    $argList = @('-m', 'http.server', "$Port", '--bind', '0.0.0.0')
    Write-Host "Starting LAN guide server on port $Port (docs root)..." -ForegroundColor Cyan
    Write-Host 'Stop with: Get-Job | Stop-Job; Get-Job | Remove-Job' -ForegroundColor Yellow
    $job = Start-Job -ScriptBlock {
        param($PythonExe, $Args, $WorkDir)
        Set-Location $WorkDir
        & $PythonExe @Args 2>&1
    } -ArgumentList $exe, $argList, $DocsDir
    Start-Sleep -Seconds 1
    return $job
}

function Show-CtgGuidePhoneInstructions {
    param(
        [string] $GuidePath,
        [int] $Port,
        [bool] $LanStarted,
        [string[]] $LanIps
    )
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Green
    Write-Host ' Open guided wizard ON YOUR IPHONE' -ForegroundColor Green
    Write-Host '========================================' -ForegroundColor Green
    Write-Host ''
    Write-Host 'Simplest (recommended):' -ForegroundColor White
    Write-Host '  1. AirDrop docs\iphone_hardening_guide.html to iPhone' -ForegroundColor Gray
    Write-Host '  2. Tap file -> Open in Safari -> use Previous / Next' -ForegroundColor Gray
    Write-Host ''
    Write-Host 'Alternatives:' -ForegroundColor White
    Write-Host '  - Email the HTML to yourself; open attachment in Safari' -ForegroundColor Gray
    Write-Host '  - Files app: copy from iCloud/OneDrive project folder' -ForegroundColor Gray
    Write-Host "  - Windows path (AirDrop/USB share): $GuidePath" -ForegroundColor DarkCyan
    Write-Host ''
    if ($LanStarted -and $LanIps.Count -gt 0) {
        Write-Host 'LAN (same Wi-Fi; firewall may prompt - allow Private network):' -ForegroundColor Yellow
        foreach ($ip in $LanIps) {
            Write-Host "  http://${ip}:${Port}/iphone_hardening_guide.html" -ForegroundColor Cyan
        }
    } elseif ($LanStarted) {
        Write-Host "LAN server on port $Port but no LAN IPv4 found - check ipconfig." -ForegroundColor Yellow
    } else {
        Write-Host 'Optional LAN: re-run with -OpenGuide -ServeOnLan (Python, port 8765).' -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host 'Limit: cannot auto-enable Face ID or toggles - Open Settings only opens the pane.' -ForegroundColor Yellow
    Write-Host ''
}

function Open-CtgGuide {
    param([bool] $StartLan)
    if (-not (Test-Path $GuideHtml)) {
        throw "Guide not found: $GuideHtml"
    }
    $docsDir = Join-Path $RepoRoot 'docs'
    $lanJob = $null
    $lanIps = @()
    if ($StartLan) {
        $confirm = Read-Host "Start LAN server on port $LanGuidePort for phone access? (y/N)"
        if ($confirm -match '^[yY]') {
            $lanIps = Get-CtgLanIPv4
            $lanJob = Start-CtgGuideLanServer -DocsDir $docsDir -Port $LanGuidePort
        } else {
            Write-Host 'LAN server skipped.' -ForegroundColor Gray
        }
    }
    try {
        Start-Process $GuideHtml
    } catch {
        Write-Host "Could not open browser: $GuideHtml" -ForegroundColor Yellow
    }
    Show-CtgGuidePhoneInstructions -GuidePath $GuideHtml -Port $LanGuidePort -LanStarted ($null -ne $lanJob) -LanIps $lanIps
    if ($lanJob) {
        Write-Host "LAN server job Id: $($lanJob.Id) (serving $docsDir)" -ForegroundColor DarkCyan
    }
}

function Open-CtgRunbook {
    if (Test-Path $RunbookLocal) {
        Start-Process $RunbookLocal
    } else {
        Write-Host "Local runbook not found: $RunbookLocal" -ForegroundColor Yellow
    }
    try {
        Start-Process $RunbookWeb
    } catch {
        Write-Host "Could not open browser for $RunbookWeb" -ForegroundColor Yellow
    }
}

try {
    Test-CtgRepo
    Write-AssistLog "repo OK | LogOnly=$LogOnly | OpenRunbook=$OpenRunbook | OpenGuide=$OpenGuide | ServeOnLan=$ServeOnLan"

    $usbScript = Join-Path $ScriptDir 'iphone_usb_check.ps1'
    $usbLine = & $usbScript -LogDir $LogDir 2>&1 | Select-Object -Last 1
    Write-AssistLog "usb_check: $usbLine"

    if ($OpenGuide) {
        Open-CtgGuide -StartLan:$ServeOnLan
        Write-AssistLog "OpenGuide displayed phone instructions guide=$GuideHtml"
    }

    if ($OpenRunbook) {
        Open-CtgRunbook
    }

    $checklist = Get-CtgHardeningChecklist

    if ($LogOnly) {
        Write-AssistLog "checklist_items=$($checklist.Count) | guide=$GuideHtml | runbook=$RunbookGitHub | shortcuts=$ShortcutsDoc"
        Write-AssistLog 'LogOnly complete - no device modification from PC'
        exit 0
    }

    Show-CtgHardeningBanner
    Write-Host "USB check: $usbLine"
    Write-Host ''
    Write-Host "Runbook (local): $RunbookLocal"
    Write-Host "Runbook (web):   $RunbookWeb"
    Write-Host ''

    Show-CtgChecklist -Items $checklist

    Write-AssistLog 'interactive session displayed checklist'
    Write-Host 'Done. Complete each step on the iPhone - this script does not change the phone.' -ForegroundColor Green
} catch {
    $err = $_.Exception.Message
    Write-AssistLog "ERROR: $err"
    Write-Error $err
    exit 1
}
