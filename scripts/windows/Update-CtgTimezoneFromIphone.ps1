<#
.SYNOPSIS
  Read iPhone-exported timezone JSON and validate for CTG daily alerts.

.DESCRIPTION
  Expects gitignored %USERPROFILE%\Backups\iphone-location\timezone.json
  (or iphone-timezone.json alias) dropped by Apple Shortcuts or manual copy.
  Validates IANA timezone string. Does not change system timezone (Admin tzutil)
  - daily alert uses iPhone-reported tz for 6 AM local window instead.

.PARAMETER DiagnoseOnly
  Print file status, validation, and local time in reported timezone.

.PARAMETER Quiet
  Minimal output for orchestrators.

.EXAMPLE
  .\scripts\windows\Update-CtgTimezoneFromIphone.ps1 -DiagnoseOnly
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [switch] $Quiet
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-IphoneTimezoneCommon.ps1')

$dir = Get-CtgIphoneTimezoneDir
if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$data = Read-CtgIphoneTimezoneJson -AllowAlias
$defaultTz = Get-CtgDefaultUtmsAlertTimezone

function Write-TzLine([string] $Text, [string] $Color = 'Gray') {
    if ($Quiet) { return }
    Write-Host $Text -ForegroundColor $Color
}

Write-TzLine ''
Write-TzLine '=== CTG iPhone timezone sync ===' 'Cyan'
Write-TzLine "Directory: $dir"
Write-TzLine "Primary file: $(Get-CtgIphoneTimezoneFile)"
Write-TzLine "Exists: $(Test-Path (Get-CtgIphoneTimezoneFile))"

if (-not $data) {
    Write-TzLine "No timezone.json - daily alert falls back to $defaultTz" 'Yellow'
    Write-TzLine 'See docs/IPHONE_TIMEZONE_SYNC.md for Shortcuts setup' 'Gray'
    if ($DiagnoseOnly) { exit 1 }
    exit 0
}

if (-not $data.Valid) {
    Write-TzLine "Invalid timezone file: $($data.Error)" 'Red'
    Write-TzLine "timezone field: $($data.Timezone)" 'Yellow'
    if ($DiagnoseOnly) { exit 1 }
    exit 2
}

try {
    $local = Get-CtgLocalTimeInTimezone -TimezoneId $data.Timezone
    Write-TzLine "IANA timezone: $($data.Timezone)" 'Green'
    Write-TzLine "Updated: $($data.Updated)"
    Write-TzLine "Local time now: $($local.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-TzLine 'Note: Windows cannot pull live iPhone GPS - Shortcuts export required.' 'Gray'
} catch {
    Write-TzLine "Timezone conversion failed: $($_.Exception.Message)" 'Red'
    if ($DiagnoseOnly) { exit 1 }
    exit 2
}

if ($DiagnoseOnly) {
    Write-TzLine 'DiagnoseOnly: PASS' 'Green'
    exit 0
}

exit 0
