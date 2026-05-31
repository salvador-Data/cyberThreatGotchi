<#
.SYNOPSIS
  Read-only iOS supervised-device / Apple Configurator checklist export.

.DESCRIPTION
  Prints MDM/supervision checklist items for docs/IPHONE_HARDENING.md — no device changes.

.EXAMPLE
  .\scripts\iphone\Export-CtgIosProfileChecklist.ps1
#>
[CmdletBinding()]
param()

$items = @(
    'Supervision: Apple Configurator 2 on Mac — backup iPhone first',
    'Supervision: Settings -> General -> VPN and Device Management — verify no unknown profiles',
    'Configurator: Prepare -> Manual -> Supervise devices (org name placeholder only in docs)',
    'Configurator: Skip setup screens — disable Siri/analytics if policy requires',
    'Restrictions: USB restricted mode when locked (Settings -> Face ID -> USB Accessories)',
    'Restrictions: App install — App Store only; MDM allow-list for fleet devices',
    'Passcode: 6+ digits; Stolen Device Protection ON (iOS 17+)',
    'Updates: Automatic iOS updates ON; beta OFF unless test device',
    'DNS/VPN: preserve existing DuckDuckGo VPN/DNS — do not stack second DNS VPN',
    'Passwords: DuckDuckGo Password Manager + separate CTG lab vault on Windows',
    'Find My: ON; Activation Lock documented for recovery',
    'Backup: encrypted local backup before supervision changes'
)

Write-Host '=== CTG iOS profile / supervision checklist (read-only) ===' -ForegroundColor Cyan
Write-Host 'Personal device: most items are manual Settings — MDM is optional enterprise.' -ForegroundColor Gray
Write-Host ''

$i = 1
foreach ($item in $items) {
    Write-Host ("{0,2}. {1}" -f $i, $item)
    $i++
}

$outDir = Join-Path $env:USERPROFILE 'Backups\logs'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$outFile = Join-Path $outDir ('ios-profile-checklist-{0}.txt' -f (Get-Date -Format 'yyyyMMdd'))
$items | Set-Content -Path $outFile -Encoding UTF8
Write-Host ''
Write-Host "Saved: $outFile"
