<#
.SYNOPSIS
  Full interactive orchestrator for iPhone Phase 1+2 hardening (21 steps).

.DESCRIPTION
  Maximum automation stock iOS allows from Windows - guided walkthrough with logging.

  HONEST LIMITS (read before running):
  - Cannot auto-toggle iOS Settings from Windows - no MDM, no Apple Configurator profiles.
  - You tap each change on the iPhone; this script prints instructions, deep-link URLs,
    optional clipboard copy, and logs progress to Backups\logs\iphone_hardening_automate.log.
  - iOS 18 may block some prefs: URLs - manual path is always shown on every step.
  - Preserves DuckDuckGo VPN/DNS and DuckDuckGo Password Manager - warnings on every relevant step.

  Step IDs match docs/iphone_hardening_guide.html (0a … 2.V = 21 steps).

.PARAMETER Resume
  Read the automate log and continue from the last incomplete step.

.PARAMETER OpenGuide
  Open docs/iphone_hardening_guide.html in the default browser (sync with HTML wizard).

.PARAMETER OpenRunbook
  Open docs/IPHONE_RUN_NOW.md locally and the GitHub Pages runbook in browser.

.PARAMETER ServeOnLan
  With -OpenGuide: optional LAN http.server on port 8765 for phone access (same Wi-Fi).

.PARAMETER LogOnly
  Dry-run / CI: validate repo, run USB check, verify all step URLs exist - no prompts.

.PARAMETER LogDir
  Log directory (default: %USERPROFILE%\Backups\logs).

.EXAMPLE
  .\scripts\windows\iphone_hardening_automate.ps1

.EXAMPLE
  .\scripts\windows\iphone_hardening_automate.ps1 -Resume -OpenGuide

.EXAMPLE
  .\scripts\windows\iphone_hardening_automate.ps1 -LogOnly
#>
[CmdletBinding()]
param(
    [switch] $Resume,
    [switch] $OpenGuide,
    [switch] $OpenRunbook,
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
$ShortcutsDoc = Join-Path $RepoRoot 'docs\iphone_hardening_shortcuts.md'
$MalwarebytesAppStore = 'https://apps.apple.com/us/app/malwarebytes-mobile-security/id1327105431'
$LanGuidePort = 8765
$StepCount = 21

if (-not $LogDir) {
    $LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
}
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$logFile = Join-Path $LogDir 'iphone_hardening_automate.log'

function Get-AutomateTimestamp {
    Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
}

function Write-AutomateLog {
    param([string] $Message)
    $stamp = Get-AutomateTimestamp
    $line = "[$stamp] iphone_hardening_automate: $Message"
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

function Get-CtgAutomateSteps {
    @(
        @{
            Id = '0a'
            Index = 0
            Phase = 'Step 0 - Baseline'
            Title = 'Document VPN (do not change)'
            Instructions = @(
                'Open VPN and write down profile name(s) and Connected / Not Connected.'
                'Do NOT disconnect DuckDuckGo VPN or any working VPN.'
                'Phase 2 must not add a second DNS-capturing VPN on top.'
            )
            Manual = 'Settings -> General -> VPN & Device Management -> VPN'
            Links = @(
                'prefs:root=General&path=ManagedConfigurationList'
                'App-Prefs:root=General&path=ManagedConfigurationList'
            )
            Warn = 'KEEP DuckDuckGo VPN/DNS. Do not install Cloudflare or NextDNS on top of an active DNS VPN.'
        }
        @{
            Id = '0b'
            Index = 1
            Phase = 'Step 0 - Baseline'
            Title = 'Document Wi-Fi DNS (do not change)'
            Instructions = @(
                'On home Wi-Fi, tap (i) -> Configure DNS.'
                'Write down: Automatic, Manual (which servers), or Off.'
                'Do not switch to Manual unless you intend to.'
            )
            Manual = 'Settings -> Wi-Fi -> (i) on home network -> Configure DNS'
            Links = @('prefs:root=WIFI', 'App-Prefs:root=WIFI')
            Warn = 'KEEP existing Wi-Fi DNS configuration - document only.'
        }
        @{
            Id = '0c'
            Index = 2
            Phase = 'Step 0 - Baseline'
            Title = 'DuckDuckGo Password Manager - keep On'
            Instructions = @(
                'Confirm DuckDuckGo Passwords / DuckDuckGo Autofill is On.'
                'Confirm DuckDuckGo app is installed.'
                'Do not migrate to Apple Keychain during this session unless you choose to.'
            )
            Manual = 'Settings -> General -> AutoFill & Passwords -> DuckDuckGo Autofill -> On'
            Links = @('prefs:root=PASSWORDS', 'App-Prefs:root=PASSWORDS')
            Warn = 'Do NOT turn off DuckDuckGo Autofill during hardening.'
            BaselineScreenshot = $true
        }
        @{
            Id = '1.1'
            Index = 3
            Phase = 'Phase 1'
            Title = 'Software Update'
            Instructions = @(
                'Install latest iOS 17 or 18.'
                'Automatic Updates -> On (iOS Updates + Security Responses & System Files).'
            )
            Manual = 'Settings -> General -> Software Update -> Automatic Updates'
            Links = @(
                'prefs:root=General&path=SOFTWARE_UPDATE_LINK'
                'App-Prefs:root=General&path=SOFTWARE_UPDATE_LINK'
            )
        }
        @{
            Id = '1.2'
            Index = 4
            Phase = 'Phase 1'
            Title = 'Passcode, Face ID, Stolen Device Protection'
            Instructions = @(
                'Custom Alphanumeric Code (or strong 6-digit minimum).'
                'Confirm Face ID for unlock / Apple Pay as you use them.'
                'Stolen Device Protection -> On (requires iOS 17.3+).'
            )
            Manual = 'Settings -> Face ID & Passcode'
            Links = @('prefs:root=PASSCODE', 'App-Prefs:root=PASSCODE')
            Limit = 'Cannot auto-enroll Face ID or change passcode - complete biometrics on device.'
        }
        @{
            Id = '1.3'
            Index = 5
            Phase = 'Phase 1'
            Title = 'Find My iPhone'
            Instructions = @(
                'Find My iPhone -> On.'
                'Find My network and Send Last Location -> On if shown.'
            )
            Manual = 'Settings -> [your name] -> Find My -> Find My iPhone'
            Links = @('prefs:root=APPLE_ACCOUNT', 'App-Prefs:root=APPLE_ACCOUNT')
        }
        @{
            Id = '1.4'
            Index = 6
            Phase = 'Phase 1'
            Title = 'Apple ID - 2FA and devices'
            Instructions = @(
                'Two-Factor Authentication -> On.'
                'Sign-In & Security -> Devices - remove anything unrecognized.'
                'Keep DuckDuckGo Password Manager for Apple ID password.'
            )
            Manual = 'Settings -> [your name] -> Sign-In & Security'
            Links = @('prefs:root=APPLE_ACCOUNT', 'App-Prefs:root=APPLE_ACCOUNT')
        }
        @{
            Id = '1.5'
            Index = 7
            Phase = 'Phase 1'
            Title = 'Safari privacy'
            Instructions = @(
                'Fraudulent Website Warning -> On.'
                'Prevent Cross-Site Tracking -> On.'
                'Hide IP Address -> From Trackers and Websites (or Trackers Only).'
            )
            Manual = 'Settings -> Apps -> Safari'
            Links = @('App-prefs:com.apple.mobilesafari', 'prefs:root=SAFARI')
        }
        @{
            Id = '1.6'
            Index = 8
            Phase = 'Phase 1'
            Title = 'Mail - Protect Mail Activity'
            Instructions = @(
                'Privacy Protection -> Protect Mail Activity -> On.'
            )
            Manual = 'Settings -> Apps -> Mail -> Privacy Protection'
            Links = @('prefs:root=MAIL', 'App-Prefs:root=MAIL')
        }
        @{
            Id = '1.7'
            Index = 9
            Phase = 'Phase 1'
            Title = 'Privacy permissions'
            Instructions = @(
                'Bluetooth - revoke apps that do not need Bluetooth.'
                'Local Network - revoke unnecessary LAN access.'
                'Tracking - deny cross-app tracking.'
            )
            Manual = 'Settings -> Privacy & Security -> Bluetooth / Local Network / Tracking'
            Links = @('prefs:root=Privacy', 'App-Prefs:root=Privacy')
        }
        @{
            Id = '1.8'
            Index = 10
            Phase = 'Phase 1'
            Title = 'Lock screen & notifications'
            Instructions = @(
                'Face ID & Passcode -> Allow Access When Locked - turn off unneeded items.'
                'Notifications -> sensitive apps -> Show Previews -> When Unlocked or Never.'
            )
            Manual = 'Settings -> Face ID & Passcode; Settings -> Notifications'
            Links = @('prefs:root=PASSCODE', 'prefs:root=NOTIFICATIONS_ID')
        }
        @{
            Id = '1.9'
            Index = 11
            Phase = 'Phase 1'
            Title = 'USB Restricted Mode'
            Instructions = @(
                'USB Accessories (Allow Accessories When Locked) -> Off.'
            )
            Manual = 'Settings -> Face ID & Passcode -> USB Accessories'
            Links = @('prefs:root=PASSCODE', 'App-Prefs:root=PASSCODE')
        }
        @{
            Id = '1.10'
            Index = 12
            Phase = 'Phase 1'
            Title = 'AirDrop & profiles'
            Instructions = @(
                'AirDrop -> Contacts Only (or Receiving Off in public).'
                'VPN & Device Management - remove only unknown profiles.'
            )
            Manual = 'Settings -> General -> AirDrop; Settings -> General -> VPN & Device Management'
            Links = @(
                'prefs:root=General&path=AIRDROP_LINK'
                'prefs:root=General&path=ManagedConfigurationList'
            )
        }
        @{
            Id = '1.11'
            Index = 13
            Phase = 'Phase 1'
            Title = 'Verify DuckDuckGo Autofill (extras)'
            Instructions = @(
                'Re-confirm DuckDuckGo Autofill -> On.'
                'Optional: Messages Filter Unknown Senders; Analytics off.'
            )
            Manual = 'Settings -> General -> AutoFill & Passwords'
            Links = @('prefs:root=PASSWORDS', 'App-Prefs:root=PASSWORDS')
            Warn = 'Do not turn off DuckDuckGo Password Manager during hardening.'
        }
        @{
            Id = '1.V'
            Index = 14
            Phase = 'Phase 1 verify'
            Title = 'Verify VPN, DNS, Autofill unchanged'
            Instructions = @(
                'Re-check VPN profile - same as Step 0 (Connected if it was before).'
                'Wi-Fi Configure DNS - unchanged from Step 0.'
                'DuckDuckGo Autofill still On.'
                'Do NOT start Phase 2 until this passes.'
            )
            Manual = 'VPN -> Wi-Fi (i) -> Configure DNS -> AutoFill & Passwords'
            Links = @(
                'prefs:root=General&path=ManagedConfigurationList'
                'prefs:root=WIFI'
                'prefs:root=PASSWORDS'
            )
            Warn = 'KEEP DuckDuckGo VPN/DNS + DuckDuckGo Password Manager unchanged.'
        }
        @{
            Id = '2.1'
            Index = 15
            Phase = 'Phase 2'
            Title = 'Install Malwarebytes Mobile Security'
            Instructions = @(
                'App Store -> Malwarebytes Mobile Security -> Get.'
                'Complete onboarding in the Malwarebytes app on device.'
                'Do NOT enable Malwarebytes paid VPN - keep DuckDuckGo VPN/DNS.'
            )
            Manual = 'App Store -> Search -> Malwarebytes Mobile Security -> Get'
            Links = @($MalwarebytesAppStore)
            Limit = 'App install and onboarding require on-device taps in App Store and Malwarebytes.'
            OpenAppStore = $true
        }
        @{
            Id = '2.2'
            Index = 16
            Phase = 'Phase 2'
            Title = 'DNS VPN apps - usually SKIP'
            Instructions = @(
                'If Step 0 showed DuckDuckGo, corporate VPN, Private Relay, NextDNS, Cloudflare, or Manual DNS - SKIP.'
                'Only one DNS-capturing VPN at a time on iOS.'
                'Do NOT enable Malwarebytes paid VPN.'
            )
            Manual = 'No action if VPN/DNS already set - proceed to next step'
            Links = @('prefs:root=General&path=ManagedConfigurationList')
            Warn = 'SKIP Cloudflare/NextDNS when DuckDuckGo or existing VPN/DNS is already configured.'
        }
        @{
            Id = '2.3'
            Index = 17
            Phase = 'Phase 2'
            Title = 'Malwarebytes SMS & Safari'
            Instructions = @(
                'Messages -> Unknown & Spam -> enable Malwarebytes.'
                'Safari -> Extensions -> enable Malwarebytes blockers if offered.'
            )
            Manual = 'Settings -> Apps -> Messages; Settings -> Apps -> Safari -> Extensions'
            Links = @('App-prefs:com.apple.MobileSMS', 'App-prefs:com.apple.mobilesafari')
            Warn = 'Do NOT enable Malwarebytes paid VPN - keep DuckDuckGo VPN/DNS.'
        }
        @{
            Id = '2.4'
            Index = 18
            Phase = 'Phase 2'
            Title = 'USB hardening'
            Instructions = @(
                'Confirm USB Accessories Off when locked (step 1.9).'
                'Trust This Computer - only this laptop; reset Location & Privacy if unsure.'
                'Developer Mode -> Off (unless dev week).'
                'When cabled: Apple Devices -> Encrypt local backup (password in DuckDuckGo PM - never git).'
            )
            Manual = 'Settings -> Face ID & Passcode; Settings -> Privacy & Security -> Developer Mode'
            Links = @('prefs:root=PASSCODE', 'prefs:root=Privacy')
            Limit = 'Trust This Computer and encrypted backup password cannot be automated.'
            UsbRemind = $true
        }
        @{
            Id = '2.5'
            Index = 19
            Phase = 'Phase 2'
            Title = 'Lockdown Mode (optional)'
            Instructions = @(
                'Use only for credible targeted threat - skip for normal daily use.'
                'Lockdown Mode -> Turn On only if you accept tradeoffs.'
            )
            Manual = 'Settings -> Privacy & Security -> Lockdown Mode'
            Links = @('prefs:root=Privacy', 'App-Prefs:root=Privacy')
        }
        @{
            Id = '2.V'
            Index = 20
            Phase = 'Phase 2 verify'
            Title = 'Final verify - VPN & DNS'
            Instructions = @(
                'VPN and Wi-Fi DNS match Step 0 baseline.'
                'VPN status icon behaves as before.'
                'Browse a familiar site - no captive portal surprises.'
                'If broken: disconnect any new VPN from Phase 2; restore DuckDuckGo / original profile.'
            )
            Manual = 'Settings -> VPN; Settings -> Wi-Fi -> (i) -> Configure DNS'
            Links = @(
                'prefs:root=General&path=ManagedConfigurationList'
                'prefs:root=WIFI'
            )
            Warn = 'KEEP DuckDuckGo VPN/DNS unchanged from Step 0 baseline.'
        }
    )
}

function Format-DeepLinkDisplay {
    param([string[]] $Links)
    if (-not $Links -or $Links.Count -eq 0) {
        return '(no deep link - use manual path)'
    }
    $lines = @()
    for ($i = 0; $i -lt $Links.Count; $i++) {
        $label = if ($i -eq 0) { 'Primary' } else { "Alt $($i)" }
        $lines += "  [$label] $($Links[$i])"
    }
    return ($lines -join "`n")
}

function Copy-ToClipboardOptional {
    param([string] $Text)
    if (-not $Text) { return }
    try {
        Set-Clipboard -Value $Text -ErrorAction Stop
        Write-Host '  (Primary link copied to clipboard - paste into Notes/AirDrop for phone)' -ForegroundColor DarkCyan
    } catch {
        Write-Host '  (Clipboard copy unavailable - copy link manually)' -ForegroundColor DarkGray
    }
}

function Get-CompletedStepIdsFromLog {
    if (-not (Test-Path $logFile)) {
        return @{}
    }
    $completed = @{}
    $lines = Get-Content -Path $logFile -Encoding UTF8 -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        if ($line -match 'STEP_(?:DONE|SKIP)\s+id=([^\s]+)') {
            $completed[$Matches[1]] = $true
        }
    }
    return $completed
}

function Get-ResumeStartIndex {
    param($Steps, [hashtable] $Completed)
    for ($i = 0; $i -lt $Steps.Count; $i++) {
        if (-not $Completed.ContainsKey($Steps[$i].Id)) {
            return $i
        }
    }
    return -1
}

function Test-StepUrlsValid {
    param($Steps)
    $errors = @()
    if ($Steps.Count -ne $StepCount) {
        $errors += "Expected $StepCount steps, got $($Steps.Count)"
    }
    foreach ($step in $Steps) {
        if (-not $step.Id) {
            $errors += "Step missing Id at index $($step.Index)"
            continue
        }
        if ($step.Links -and $step.Links.Count -gt 0) {
            foreach ($link in $step.Links) {
                if ([string]::IsNullOrWhiteSpace($link)) {
                    $errors += "Step $($step.Id): empty link"
                } elseif ($link -notmatch '^(prefs:|App-[Pp]refs:|https?://)') {
                    $errors += "Step $($step.Id): invalid link scheme: $link"
                }
            }
        }
    }
    return $errors
}

function Show-AutomateBanner {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ' CyberThreatGotchi - iPhone hardening automate (21 steps)' -ForegroundColor Cyan
    Write-Host ' Guided maximum-automation flow (Windows + phone taps)' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host " Repo:     $RepoRoot"
    Write-Host " Computer: $env:COMPUTERNAME"
    Write-Host " Date:     $(Get-AutomateTimestamp)"
    Write-Host " Log:      $logFile"
    Write-Host ''
    Write-Host 'HONEST: Cannot auto-toggle iOS Settings from Windows.' -ForegroundColor Yellow
    Write-Host '        You tap each change; script guides + logs progress.' -ForegroundColor Yellow
    Write-Host '        iOS 18 may block some prefs: URLs - manual path always shown.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'PRESERVE: DuckDuckGo VPN/DNS + DuckDuckGo Password Manager.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Controls: [Enter]=done  [S]=skip  [B]=back  [Q]=quit  [C]=copy link' -ForegroundColor Gray
    Write-Host ''
}

function Show-StepScreen {
    param(
        $Step,
        [int] $CurrentNum,
        [int] $Total,
        [string] $UsbLine = ''
    )
    Write-Host ''
    Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host " Step $CurrentNum of $Total | $($Step.Phase) | ID: $($Step.Id)" -ForegroundColor Green
    Write-Host " $($Step.Title)" -ForegroundColor White
    Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host ''
    foreach ($line in $Step.Instructions) {
        Write-Host "  • $line" -ForegroundColor Gray
    }
    Write-Host ''
    Write-Host " Manual path: $($Step.Manual)" -ForegroundColor Cyan
    Write-Host ''
    Write-Host ' Deep links (tap on iPhone via AirDrop/Notes/Shortcuts):' -ForegroundColor DarkCyan
    Write-Host (Format-DeepLinkDisplay -Links $Step.Links)
    Write-Host ' (iOS 17/18: may open parent pane only - follow manual path)' -ForegroundColor DarkGray
    if ($Step.Warn) {
        Write-Host ''
        Write-Host " WARN: $($Step.Warn)" -ForegroundColor Yellow
    }
    if ($Step.Limit) {
        Write-Host " LIMIT: $($Step.Limit)" -ForegroundColor DarkYellow
    }
    if ($Step.UsbRemind -and $UsbLine) {
        Write-Host ''
        Write-Host " USB check: $UsbLine" -ForegroundColor Magenta
        Write-Host ' Reminder: Trust This Computer only on this laptop; encrypted backup in Apple Devices.' -ForegroundColor Magenta
    }
    if ($Step.OpenAppStore) {
        Write-Host ''
        $open = Read-Host 'Open Malwarebytes App Store URL in default browser? (y/N)'
        if ($open -match '^[yY]') {
            try {
                Start-Process $MalwarebytesAppStore
                Write-AutomateLog "opened_app_store step=$($Step.Id)"
            } catch {
                Write-Host "Could not open browser: $MalwarebytesAppStore" -ForegroundColor Yellow
            }
        }
    }
    Write-Host ''
}

function Confirm-BaselineScreenshot {
    Write-Host ''
    Write-Host '=== Step 0 baseline complete ===' -ForegroundColor Yellow
    Write-Host 'Take a screenshot (or Notes entry) of VPN + DNS + DuckDuckGo Autofill state.' -ForegroundColor Yellow
    Write-Host 'DO NOT change DuckDuckGo VPN/DNS or Password Manager during hardening.' -ForegroundColor Yellow
    Write-Host ''
    $confirm = Read-Host 'Screenshot or Notes baseline saved? (Y/n)'
    if ($confirm -match '^[nN]') {
        Write-Host 'Please save baseline documentation before continuing Phase 1.' -ForegroundColor Yellow
        return $false
    }
    Write-AutomateLog 'BASELINE_SCREENSHOT confirmed=yes'
    return $true
}

function Invoke-AutomateFlow {
    param(
        $Steps,
        [int] $StartIndex,
        [string] $UsbLine
    )
    $idx = $StartIndex
    $total = $Steps.Count

    while ($idx -ge 0 -and $idx -lt $total) {
        $step = $Steps[$idx]
        Show-StepScreen -Step $step -CurrentNum ($idx + 1) -Total $total -UsbLine $UsbLine

        if ($OpenGuide -and (Test-Path $GuideHtml)) {
            $guideUrl = "file:///$($GuideHtml -replace '\\', '/')?step=$idx"
            Write-Host " HTML wizard sync: iphone_hardening_guide.html?step=$idx" -ForegroundColor DarkCyan
        }

        $choice = Read-Host '[Enter]=done  [S]=skip  [B]=back  [Q]=quit  [C]=copy primary link'
        switch -Regex ($choice) {
            '^[qQ]$' {
                Write-AutomateLog "SESSION_QUIT at step=$($step.Id) index=$idx"
                Write-Host 'Session saved - re-run with -Resume to continue.' -ForegroundColor Yellow
                return
            }
            '^[bB]$' {
                if ($idx -gt 0) { $idx -= 1 }
                continue
            }
            '^[cC]$' {
                if ($step.Links -and $step.Links.Count -gt 0) {
                    Copy-ToClipboardOptional -Text $step.Links[0]
                }
                continue
            }
            '^[sS]$' {
                Write-AutomateLog "STEP_SKIP id=$($step.Id) index=$idx"
                $idx += 1
            }
            default {
                Write-AutomateLog "STEP_DONE id=$($step.Id) index=$idx"
                if ($step.BaselineScreenshot) {
                    $ok = Confirm-BaselineScreenshot
                    if (-not $ok) { continue }
                }
                $idx += 1
            }
        }
    }

    if ($idx -ge $total) {
        Write-AutomateLog 'SESSION_COMPLETE all_21_steps'
        Write-Host ''
        Write-Host 'All 21 steps complete. Re-run Step 0 checks anytime.' -ForegroundColor Green
        Write-Host "Full reference: $RunbookLocal" -ForegroundColor Cyan
    }
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
    $job = Start-Job -ScriptBlock {
        param($PythonExe, $Args, $WorkDir)
        Set-Location $WorkDir
        & $PythonExe @Args 2>&1
    } -ArgumentList $exe, $argList, $DocsDir
    Start-Sleep -Seconds 1
    return $job
}

function Open-CtgGuide {
    param([bool] $StartLan, [int] $StepIndex = 0)
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
        }
    }
    $guideUri = "$GuideHtml?step=$StepIndex"
    try {
        Start-Process $guideUri
    } catch {
        try { Start-Process $GuideHtml } catch { Write-Host "Could not open guide: $GuideHtml" -ForegroundColor Yellow }
    }
    Write-Host ''
    Write-Host 'Open guided wizard ON YOUR IPHONE:' -ForegroundColor Green
    Write-Host '  AirDrop docs\iphone_hardening_guide.html -> Open in Safari' -ForegroundColor Gray
    if ($lanJob -and $lanIps.Count -gt 0) {
        foreach ($ip in $lanIps) {
            Write-Host "  http://${ip}:${LanGuidePort}/iphone_hardening_guide.html?step=$StepIndex" -ForegroundColor Cyan
        }
    }
    Write-Host ''
}

function Open-CtgRunbook {
    if (Test-Path $RunbookLocal) {
        Start-Process $RunbookLocal
    }
    try {
        Start-Process $RunbookWeb
    } catch {
        Write-Host "Could not open browser for $RunbookWeb" -ForegroundColor Yellow
    }
}

try {
    Test-CtgRepo
    $steps = Get-CtgAutomateSteps
    Write-AutomateLog "start Resume=$Resume OpenGuide=$OpenGuide OpenRunbook=$OpenRunbook LogOnly=$LogOnly steps=$($steps.Count)"

    $usbScript = Join-Path $ScriptDir 'iphone_usb_check.ps1'
    $usbLine = & $usbScript -LogDir $LogDir 2>&1 | Select-Object -Last 1
    Write-AutomateLog "usb_check: $usbLine"

    $urlErrors = Test-StepUrlsValid -Steps $steps
    if ($urlErrors.Count -gt 0) {
        foreach ($e in $urlErrors) {
            Write-AutomateLog "URL_VALIDATE_ERROR: $e"
        }
        if ($LogOnly) {
            Write-Error ($urlErrors -join '; ')
            exit 1
        }
    } elseif ($LogOnly) {
        Write-AutomateLog "URL_VALIDATE_OK steps=$($steps.Count) guide=$GuideHtml shortcuts=$ShortcutsDoc"
        Write-AutomateLog 'LogOnly complete - no device modification from PC'
        Write-Output "LogOnly OK: $($steps.Count) steps, all URLs valid. USB: $usbLine"
        exit 0
    }

    $startIndex = 0
    if ($Resume) {
        $completed = Get-CompletedStepIdsFromLog
        $startIndex = Get-ResumeStartIndex -Steps $steps -Completed $completed
        if ($startIndex -lt 0) {
            Write-Host 'All steps already marked done in log. Re-run without -Resume to start fresh.' -ForegroundColor Green
            Write-AutomateLog 'RESUME all_complete'
            exit 0
        }
        Write-Host "Resuming from step $($steps[$startIndex].Id) (index $startIndex)..." -ForegroundColor Cyan
        Write-AutomateLog "RESUME from id=$($steps[$startIndex].Id) index=$startIndex"
    }

    if ($OpenRunbook) {
        Open-CtgRunbook
        Write-AutomateLog 'OpenRunbook displayed'
    }

    if ($OpenGuide) {
        Open-CtgGuide -StartLan:$ServeOnLan -StepIndex $startIndex
        Write-AutomateLog "OpenGuide step_index=$startIndex"
    }

    Show-AutomateBanner
    Write-Host "USB check: $usbLine"
    Write-Host "Guide:     $GuideHtml"
    Write-Host "Shortcuts: $ShortcutsDoc"
    Write-Host ''

    Invoke-AutomateFlow -Steps $steps -StartIndex $startIndex -UsbLine $usbLine
} catch {
    $err = $_.Exception.Message
    Write-AutomateLog "ERROR: $err"
    Write-Error $err
    exit 1
}
