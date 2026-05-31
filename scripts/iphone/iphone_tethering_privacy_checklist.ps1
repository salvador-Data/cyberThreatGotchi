<#
.SYNOPSIS
  Read-only iPhone laptop-connection privacy checklist (no device modification).

.DESCRIPTION
  Prints defensive Settings paths for iPhone 15 Pro Max when connected to Andy's
  Windows SOC laptop via USB or hotspot. Does NOT change MAC addresses, hardware IDs,
  or iOS configuration - Apple does not expose those APIs without MDM.

  Preserves DuckDuckGo VPN/DNS and Password Manager per project rules.

.PARAMETER DetectUsb
  When set, query Win32 PnP for Apple USB (VID_05AC) and note if iPhone may be attached.

.PARAMETER LogDir
  Optional log directory (default: Backups\logs).

.EXAMPLE
  .\scripts\iphone\iphone_tethering_privacy_checklist.ps1

.EXAMPLE
  .\scripts\iphone\iphone_tethering_privacy_checklist.ps1 -DetectUsb
#>
[CmdletBinding()]
param(
    [switch] $DetectUsb,
    [string] $LogDir = ''
)

$ErrorActionPreference = 'Continue'

if (-not $LogDir) {
    $LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
}
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$logFile = Join-Path $LogDir 'iphone_tethering_privacy_checklist.log'
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

function Write-CtgChecklistLine {
    param([string] $Message, [string] $Color = 'Gray')
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $logFile -Value "[$stamp] $Message" -Encoding UTF8
}

Write-CtgChecklistLine '=== CTG iPhone laptop connection checklist (read-only) ===' 'Cyan'
Write-CtgChecklistLine 'HONEST SCOPE: Windows cannot rewrite iPhone MAC or hardware IDs.' 'Yellow'
Write-CtgChecklistLine 'Complete every step ON THE IPHONE. Preserve DuckDuckGo VPN/DNS + Password Manager.' 'Yellow'
Write-CtgChecklistLine '' 

$items = @(
    @{ Id = '1'; Item = 'Private Wi-Fi Address'; Path = 'Settings -> Wi-Fi -> (i) -> Private Wi-Fi Address ON' }
    @{ Id = '2'; Item = 'Limit IP Tracking (Wi-Fi)'; Path = 'Settings -> Wi-Fi -> (i) -> Limit IP Address Tracking ON' }
    @{ Id = '3'; Item = 'Limit IP Tracking (cellular)'; Path = 'Settings -> Cellular -> Cellular Data Options -> Limit IP Address Tracking ON' }
    @{ Id = '4'; Item = 'USB Restricted Mode'; Path = 'Settings -> Face ID & Passcode -> USB Accessories OFF when locked' }
    @{ Id = '5'; Item = 'Trust This Computer'; Path = 'Trust ONLY this laptop; Reset Location & Privacy if unsure' }
    @{ Id = '6'; Item = 'iOS updates'; Path = 'Settings -> General -> Software Update; Automatic Updates ON' }
    @{ Id = '7'; Item = 'VPN/DNS baseline'; Path = 'Settings -> VPN - DuckDuckGo unchanged; Wi-Fi DNS unchanged' }
    @{ Id = '8'; Item = 'DuckDuckGo Password Manager'; Path = 'Settings -> AutoFill & Passwords -> DuckDuckGo Autofill ON' }
    @{ Id = '9'; Item = 'Hotspot password'; Path = 'Settings -> Personal Hotspot - strong password if sharing cellular' }
    @{ Id = '10'; Item = 'Find My + Stolen Device Protection'; Path = 'Settings -> Find My ON; Stolen Device Protection ON (iOS 17.3+)' }
)

foreach ($row in $items) {
    Write-CtgChecklistLine ("[ ] {0}. {1}" -f $row.Id, $row.Item) 'White'
    Write-CtgChecklistLine ("      {0}" -f $row.Path) 'DarkGray'
}

Write-CtgChecklistLine ''
Write-CtgChecklistLine 'Docs: docs/IPHONE_LAPTOP_CONNECTION.md | docs/IPHONE_HARDENING.md | docs/IPHONE_USB_HARDENING.md' 'Cyan'

$usbDetected = $false
$usbDetail = 'USB detect skipped (use -DetectUsb)'

if ($DetectUsb) {
    $pnps = @()
    try {
        $pnps = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
            Where-Object {
                $_.InstanceId -match 'USB\\' -and
                ($_.FriendlyName -match 'Apple|iPhone|iPad' -or $_.InstanceId -match 'VID_05AC')
            }
    } catch {
        $pnps = @()
    }
    $usbDetected = $pnps.Count -gt 0
    if ($usbDetected) {
        $names = ($pnps | Select-Object -First 3 -ExpandProperty FriendlyName) -join '; '
        $usbDetail = "Apple USB PnP detected: $names - run checklist on device now"
        Write-CtgChecklistLine '' 
        Write-CtgChecklistLine $usbDetail 'Green'
    } else {
        $usbDetail = 'No Apple USB PnP match (Wi-Fi only, unplugged, or driver pending)'
        Write-CtgChecklistLine '' 
        Write-CtgChecklistLine $usbDetail 'DarkYellow'
    }
}

Write-CtgChecklistLine ''
Write-CtgChecklistLine 'Connection exposure: USB tethering = wired gateway; Hotspot = Wi-Fi hop - both visible to laptop IDS (Snort/Suricata).' 'Gray'
Write-CtgChecklistLine 'RAM-class CPU bugs (Spectre/RETBleed) are NOT blocked by network IDS - patch OS/microcode instead.' 'Gray'

Write-Output @{
    Timestamp    = $stamp
    UsbDetected  = $usbDetected
    UsbDetail    = $usbDetail
    LogFile      = $logFile
    ReadOnly     = $true
}
