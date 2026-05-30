<#
.SYNOPSIS
  Log-only reminder when an iPhone may be USB-attached to the Windows SOC laptop.

.DESCRIPTION
  Does NOT modify the iPhone or install profiles. Apple does not expose device policy
  APIs for arbitrary PowerShell without MDM/Apple Business Manager.

  Detects common Apple USB identifiers (Espressif not used here - Cardputer is separate)
  and writes a one-line reminder to run docs/IPHONE_RUN_NOW.md Phase 2 section 2.3 (USB).

.PARAMETER LogDir
  Directory for iphone_usb_check.log (default: user Backups\logs).

.EXAMPLE
  .\scripts\windows\iphone_usb_check.ps1
#>
[CmdletBinding()]
param(
    [string] $LogDir = ''
)

$ErrorActionPreference = 'Continue'

if (-not $LogDir) {
    $LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
}
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$logFile = Join-Path $LogDir 'iphone_usb_check.log'
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

# Apple Inc. vendor IDs commonly seen on iPhone/iPad USB (informational only)
$appleVendorIds = @('05AC')

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

$detected = $pnps.Count -gt 0
$detail = if ($detected) {
    ($pnps | Select-Object -First 3 -Property FriendlyName, InstanceId | ForEach-Object { $_.FriendlyName }) -join '; '
} else {
    'no Apple USB PnP match (device may be Wi-Fi only or cable unplugged)'
}

$runbook = 'docs/IPHONE_RUN_NOW.md - Phase 2 section 2.3 USB (preserve VPN/DNS)'
$usbDoc = 'docs/IPHONE_USB_HARDENING.md'

if ($detected) {
    $line = "[$stamp] iPhone attached - run IPHONE_RUN_NOW Phase 2 USB | $runbook | $usbDoc | PnP: $detail"
} else {
    $line = "[$stamp] iphone_usb_check: $detail | Runbook: $runbook"
}

Add-Content -Path $logFile -Value $line -Encoding UTF8
Write-Output $line
