<#
.SYNOPSIS
  Selective user-data backup to external SSD (no full C: clone).

.DESCRIPTION
  Copies Documents, Desktop, Projects, Pictures (optional cap), exports installed
  programs list, optional registry hives, writes BACKUP_MANIFEST.txt and setup_log.txt.
  Never formats or deletes destination volumes.

.PARAMETER BackupRoot
  Target folder (default: D:\Backups\Andy-PC-YYYY-MM-DD if D: SSD exists).

.PARAMETER MaxPicturesGB
  Skip Pictures if folder exceeds this size (default 50).

.PARAMETER SkipRegistryExport
  Skip reg export of HKCU/HKLM\SOFTWARE samples.

.EXAMPLE
  .\scripts\windows\selective_ssd_backup.ps1
#>
[CmdletBinding()]
param(
    [string] $BackupRoot = '',
    [int] $MaxPicturesGB = 50,
    [switch] $SkipRegistryExport
)

$ErrorActionPreference = 'Continue'
$date = Get-Date -Format 'yyyy-MM-dd'
$log = @()

function Add-Log([string]$msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
    $script:log += $line
    Write-Host $line
}


function Test-BackupVolumeWritable {
    param([string]$Root)
    try {
        New-Item -ItemType Directory -Path $Root -Force | Out-Null
        $t = Join-Path $Root '.write_test'
        'ok' | Set-Content -Path $t -Encoding ASCII -ErrorAction Stop
        Remove-Item $t -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}
function Resolve-BackupRoot {
    param([string]$Requested)
    if ($Requested) { return $Requested }
    $ssd = Get-Volume -DriveLetter D -ErrorAction SilentlyContinue
    if ($ssd -and $ssd.FileSystemLabel -eq 'SSD') {
        return "D:\Backups\Andy-PC-$date"
    }
    foreach ($letter in @('E','F','G','H')) {
        $v = Get-Volume -DriveLetter $letter -ErrorAction SilentlyContinue
        if ($v -and $v.SizeRemaining -gt 50GB -and $v.DriveType -eq 'Fixed') {
            return "${letter}:\Backups\Andy-PC-$date"
        }
    }
    return (Join-Path $env:USERPROFILE "Backups\Andy-PC-$date")
}

$root = Resolve-BackupRoot -Requested $BackupRoot
if (-not (Test-BackupVolumeWritable -Root $root)) {
    Add-Log "WARNING: backup volume not writable ($root); falling back to OneDrive"
    $od = $env:OneDrive
    if (-not $od) { $od = Join-Path $env:USERPROFILE 'OneDrive' }
    $root = Join-Path $od "Backups\Andy-PC-$date"
    if (-not (Test-BackupVolumeWritable -Root $root)) {
        $root = Join-Path $env:USERPROFILE "Backups\Andy-PC-$date"
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }
}
New-Item -ItemType Directory -Path $root -Force | Out-Null
$logPath = Join-Path $root 'setup_log.txt'

Add-Log "Backup root: $root"
Add-Log "Computer: $env:COMPUTERNAME User: $env:USERNAME"

$free = (Get-Volume -DriveLetter ($root.Substring(0,1)) -ErrorAction SilentlyContinue).SizeRemaining
if ($free -and $free -lt 5GB) {
    Add-Log "WARNING: less than 5 GB free on backup volume"
}

$robolog = Join-Path $root 'robocopy.log'
$oneDriveRoot = $env:OneDrive
if (-not $oneDriveRoot) { $oneDriveRoot = Join-Path $env:USERPROFILE 'OneDrive' }
$backupOnOneDrive = $oneDriveRoot -and ($root.StartsWith($oneDriveRoot, [StringComparison]::OrdinalIgnoreCase))
$sources = @(
    @{ Name = 'Documents'; Path = [Environment]::GetFolderPath('MyDocuments') },
    @{ Name = 'Desktop'; Path = [Environment]::GetFolderPath('Desktop') },
    @{ Name = 'Projects'; Path = 'C:\Users\Owner\Projects' },
    @{ Name = 'Pictures'; Path = [Environment]::GetFolderPath('MyPictures') }
)

$manifest = @()
$manifest += "CyberThreatGotchi selective backup"
$manifest += "Timestamp: $(Get-Date -Format o)"
$manifest += "Computer: $env:COMPUTERNAME"
$manifest += "User: $env:USERNAME"
$manifest += "BackupRoot: $root"
$manifest += ""

foreach ($item in $sources) {
    if ($item.Name -in @('Documents','Desktop','Pictures') -and $oneDriveRoot -and $item.Path.StartsWith($oneDriveRoot, [StringComparison]::OrdinalIgnoreCase)) {
        Add-Log "SKIP $($item.Name) (path under OneDrive — cloud sync, no local duplicate: $($item.Path))"
        $manifest += "CLOUD_SYNC (skip duplicate): $($item.Name) at $($item.Path)"
        continue
    }
    $src = $item.Path
    if (-not (Test-Path $src)) {
        Add-Log "SKIP missing: $src"
        $manifest += "SKIPPED (missing): $($item.Name) -> $src"
        continue
    }
    if ($item.Name -eq 'Pictures') {
        $sizeGB = (Get-ChildItem $src -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
        if ($sizeGB -gt $MaxPicturesGB) {
            Add-Log "SKIP Pictures (${sizeGB:N1} GB > $MaxPicturesGB GB cap)"
            $manifest += "SKIPPED (size): Pictures $src"
            continue
        }
    }
    $dest = Join-Path $root $item.Name
    Add-Log "Robocopy: $src -> $dest"
    $manifest += "COPIED: $($item.Name) from $src to $dest"
    & robocopy $src $dest /E /R:2 /W:5 /XJ /FFT /Z /NP /NDL /NFL /MAX:524288000 /XD node_modules .git __pycache__ venv .venv /XF *.iso /LOG+:$robolog /R:2 /W:5 /XJ /FFT /Z /NP /NDL /NFL /LOG+:$robolog | Out-Null
}

$progList = Join-Path $root 'installed_programs.txt'
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName } |
    Select-Object DisplayName, DisplayVersion, Publisher |
    Sort-Object DisplayName |
    Format-Table -AutoSize | Out-String | Set-Content -Path $progList -Encoding UTF8
Add-Log "Wrote installed_programs.txt"
$manifest += "EXPORT: installed_programs.txt"

if (-not $SkipRegistryExport) {
    $regDir = Join-Path $root 'registry_exports'
    New-Item -ItemType Directory -Path $regDir -Force | Out-Null
    reg export HKCU (Join-Path $regDir 'hkcu_sample.reg') /y 2>$null
    reg export 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies' (Join-Path $regDir 'policies_sample.reg') /y 2>$null
    Add-Log "Registry sample exports in registry_exports\"
    $manifest += "EXPORT: registry_exports (HKCU + Policies sample)"
}

try {
    Checkpoint-Computer -Description 'CTG-Pre-Hardening-Backup' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
    Add-Log "System restore point created: CTG-Pre-Hardening-Backup"
    $manifest += "RESTORE POINT: CTG-Pre-Hardening-Backup"
} catch {
    Add-Log "Restore point failed (run as Admin / enable System Protection): $($_.Exception.Message)"
    $manifest += "RESTORE POINT: FAILED - $($_.Exception.Message)"
}

$manifestPath = Join-Path $root 'BACKUP_MANIFEST.txt'
$manifest | Set-Content -Path $manifestPath -Encoding UTF8
$log | Set-Content -Path $logPath -Encoding UTF8
Add-Log "Manifest: $manifestPath"
Write-Output "BACKUP_ROOT=$root"
