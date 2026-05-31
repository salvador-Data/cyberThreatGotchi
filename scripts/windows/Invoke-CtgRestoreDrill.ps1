<#
.SYNOPSIS
  Quarterly restore drill — verify BitLocker, backup paths, backup age.

.DESCRIPTION
  -DiagnoseOnly: read-only checks (default).
  -ReportOnly: write summary to Backups/logs/restore-drill-YYYYMMDD.log.

.PARAMETER DiagnoseOnly
  Console report only.

.PARAMETER ReportOnly
  Also write log file under Backups/logs.

.EXAMPLE
  .\scripts\windows\Invoke-CtgRestoreDrill.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Invoke-CtgRestoreDrill.ps1 -ReportOnly
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [switch] $ReportOnly
)

$ErrorActionPreference = 'Continue'

$LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
$ReportFile = Join-Path $LogDir ('restore-drill-{0}.log' -f (Get-Date -Format 'yyyyMMdd'))
$BackupPaths = @(
    (Join-Path $env:USERPROFILE 'Backups'),
    (Join-Path $env:USERPROFILE 'OneDrive\Backups'),
    'D:\'
)

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

$lines = [System.Collections.Generic.List[string]]::new()

function Add-DrillLine {
    param([string] $Message, [string] $Color = 'Gray')
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Host $line -ForegroundColor $Color
    $lines.Add($line) | Out-Null
}

function Get-CtgBitLockerSummary {
    if (-not (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue)) {
        return 'Get-BitLockerVolume unavailable (Admin or Pro/Enterprise required)'
    }
    try {
        $vols = Get-BitLockerVolume -ErrorAction Stop | Where-Object { $_.MountPoint -match '^[A-Z]:\\$' }
        if (-not $vols) { return 'No BitLocker volumes reported' }
        return ($vols | ForEach-Object { "{0} Protection={1} Encryption={2}%" -f $_.MountPoint, $_.ProtectionStatus, $_.EncryptionPercentage }) -join '; '
    } catch {
        return "BitLocker query failed: $($_.Exception.Message)"
    }
}

function Get-CtgPathAgeSummary {
    param([string] $Path)
    if (-not (Test-Path $Path)) {
        return @{ Exists = $false; LastWrite = $null; Detail = 'MISSING' }
    }
    $item = Get-Item $Path
    $last = $item.LastWriteTime
    $ageDays = [math]::Round(((Get-Date) - $last).TotalDays, 1)
    return @{
        Exists    = $true
        LastWrite = $last
        Detail    = "last write $last ($ageDays days ago)"
    }
}

Add-DrillLine '=== CTG quarterly restore drill ===' 'Cyan'
Add-DrillLine 'Authorized lab - verify you can restore from backups before you need them.' 'Gray'

Add-DrillLine ('BitLocker: {0}' -f (Get-CtgBitLockerSummary))

foreach ($bp in $BackupPaths) {
    $info = Get-CtgPathAgeSummary -Path $bp
    if ($info.Exists) {
        $color = if (((Get-Date) - $info.LastWrite).TotalDays -gt 14) { 'Yellow' } else { 'Green' }
        Add-DrillLine ("Backup path {0}: {1}" -f $bp, $info.Detail) $color
    } else {
        Add-DrillLine ("Backup path {0}: MISSING" -f $bp) 'Yellow'
    }
}

$stageLog = Join-Path $LogDir 'stage-kali-lab.log'
if (Test-Path $stageLog) {
    $lastStage = (Get-Item $stageLog).LastWriteTime
    Add-DrillLine ("Kali stage log: $stageLog - $lastStage")
} else {
    Add-DrillLine 'Kali stage log not found - run Stage-KaliLabToBackups.ps1' 'Yellow'
}

$nightlyLog = Get-ChildItem -Path $LogDir -Filter 'ctg-nightly*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($nightlyLog) {
    Add-DrillLine ("Latest nightly log: $($nightlyLog.FullName) - $($nightlyLog.LastWriteTime)")
} else {
    Add-DrillLine 'No ctg-nightly*.log found - verify HackerPlanet-CTG-Nightly-4AM task' 'Yellow'
}

Add-DrillLine 'Manual drill: restore one file from OneDrive + one from Backups to a temp folder.' 'Cyan'
Add-DrillLine 'Golden Kali: Snapshot-CtgKaliGolden.ps1 -ApplySafe after clean lab run.' 'Gray'

if ($ReportOnly -or -not $DiagnoseOnly) {
    $lines | Set-Content -Path $ReportFile -Encoding UTF8
    Add-DrillLine "Report written: $ReportFile" 'Green'
}

if (-not $ReportOnly) {
    Add-DrillLine 'DiagnoseOnly complete. Use -ReportOnly for quarterly log artifact.' 'Cyan'
}

exit 0
