<#
.SYNOPSIS
  Find duplicate files by SHA256 in Backups, Downloads, and Hacker Planet Programs tree.

.DESCRIPTION
  Default DiagnoseOnly. Excludes .git, node_modules, .venv, __pycache__, .vault, VirtualBox VM dirs.
  -ApplyDedupe: delete redundant copies only under Backups/Downloads (keeps newest; prefers path under Hacker Planet LLC).

.NOTES
  Report: C:\Users\Owner\Backups\logs\ctg-duplicate-report.json
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch] $ApplyDedupe,
    [string[]] $ScanRoots = @(
        (Join-Path $env:USERPROFILE 'Backups'),
        (Join-Path $env:USERPROFILE 'Downloads'),
        (Join-Path $env:USERPROFILE 'Programs\Hacker Planet LLC')
    ),
    [int] $MaxFiles = 50000,
    [long] $MinSizeBytes = 1024
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$ReportJson = Join-Path $LogDir 'ctg-duplicate-report.json'
$LogFile = Join-Path $LogDir 'ctg-duplicate-scan.log'

function Write-Log([string] $Message) {
    $line = "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
    Write-Host $line
}

$ExcludePattern = '\\(\.git|node_modules|\.venv|__pycache__|\.vault|VirtualBox VMs)(\\|$)'

function Test-ExcludedPath([string] $FullName) {
    return $FullName -match $ExcludePattern
}

function Format-Size([long] $Bytes) {
    if ($Bytes -ge 1GB) { return '{0:N2} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N2} MB' -f ($Bytes / 1MB) }
    return '{0:N0} KB' -f ($Bytes / 1KB)
}

Write-Log "=== Find-CtgDuplicateFiles $(if ($ApplyDedupe) { 'ApplyDedupe' } else { 'DiagnoseOnly' }) ==="

$hashMap = @{}
$fileCount = 0

foreach ($root in $ScanRoots) {
    if (-not (Test-Path -LiteralPath $root)) {
        Write-Log "Skip missing root: $root"
        continue
    }
    Write-Log "Scanning: $root"
    Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
        if ($fileCount -ge $MaxFiles) { return }
        if (Test-ExcludedPath $_.FullName) { return }
        if ($_.Length -lt $MinSizeBytes) { return }
        $fileCount++
        if ($fileCount % 2000 -eq 0) { Write-Log "Hashed $fileCount files..." }
        try {
            $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
        } catch {
            return
        }
        if (-not $hashMap.ContainsKey($hash)) {
            $hashMap[$hash] = [System.Collections.Generic.List[object]]::new()
        }
        $hashMap[$hash].Add([PSCustomObject]@{
            Path         = $_.FullName
            Length       = $_.Length
            LastWriteUtc = $_.LastWriteTimeUtc
        })
    }
}

$dupGroups = foreach ($kv in $hashMap.GetEnumerator()) {
    if ($kv.Value.Count -lt 2) { continue }
    $size = [long]$kv.Value[0].Length
    $waste = $size * ($kv.Value.Count - 1)
    [PSCustomObject]@{
        Hash           = $kv.Key
        FileSizeBytes  = $size
        CopyCount      = $kv.Value.Count
        RecoverableBytes = $waste
        Files          = @($kv.Value | Sort-Object LastWriteUtc -Descending)
    }
}

$dupGroups = @($dupGroups | Sort-Object RecoverableBytes -Descending)
$totalRecoverable = ($dupGroups | Measure-Object RecoverableBytes -Sum).Sum
if ($null -eq $totalRecoverable) { $totalRecoverable = 0 }

Write-Log ("Files hashed: {0}" -f $fileCount)
Write-Log ("Duplicate groups: {0}" -f $dupGroups.Count)
Write-Log ("Recoverable (all copies except one per group): {0}" -f (Format-Size $totalRecoverable))

$top = $dupGroups | Select-Object -First 25 | ForEach-Object {
    @{
        Hash = $_.Hash
        FileSizeBytes = $_.FileSizeBytes
        CopyCount = $_.CopyCount
        RecoverableBytes = $_.RecoverableBytes
        Paths = @($_.Files | ForEach-Object { $_.Path })
    }
}

@{
    ScannedAt = (Get-Date).ToString('o')
    FileCount = $fileCount
    DuplicateGroupCount = $dupGroups.Count
    RecoverableBytes = $totalRecoverable
    TopGroups = $top
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportJson -Encoding UTF8

Write-Log "Report: $ReportJson"
$dupGroups | Select-Object -First 10 | ForEach-Object {
    Write-Log ("TOP: {0} x{1} recover {2}" -f (Format-Size $_.FileSizeBytes), $_.CopyCount, (Format-Size $_.RecoverableBytes))
    $_.Files | Select-Object -First 5 | ForEach-Object { Write-Log "  $($_.Path)" }
}

$hpPrefix = (Join-Path $env:USERPROFILE 'Programs\Hacker Planet LLC').ToLowerInvariant()
$safeRoots = @(
    (Join-Path $env:USERPROFILE 'Backups').ToLowerInvariant(),
    (Join-Path $env:USERPROFILE 'Downloads').ToLowerInvariant()
)

if ($ApplyDedupe) {
    $deleted = 0
    $freed = 0L
    foreach ($g in $dupGroups) {
        $files = @($g.Files)
        $keep = $files | Where-Object { $_.Path.ToLowerInvariant().StartsWith($hpPrefix) } | Select-Object -First 1
        if (-not $keep) {
            $keep = $files | Sort-Object LastWriteUtc -Descending | Select-Object -First 1
        }
        foreach ($f in $files) {
            if ($f.Path -eq $keep.Path) { continue }
            $low = $f.Path.ToLowerInvariant()
            $inSafe = $false
            foreach ($sr in $safeRoots) { if ($low.StartsWith($sr)) { $inSafe = $true; break } }
            if (-not $inSafe) {
                Write-Log "Skip delete (outside Backups/Downloads): $($f.Path)"
                continue
            }
            if ($PSCmdlet.ShouldProcess($f.Path, 'Delete duplicate')) {
                Remove-Item -LiteralPath $f.Path -Force -ErrorAction SilentlyContinue
                $deleted++
                $freed += $g.FileSizeBytes
                Write-Log "Deleted duplicate: $($f.Path)"
            }
        }
    }
    Write-Log ("ApplyDedupe: deleted {0} files, freed ~{1}" -f $deleted, (Format-Size $freed))
}

if (-not $ApplyDedupe) {
    Write-Log 'DiagnoseOnly complete. Review JSON before -ApplyDedupe'
}
