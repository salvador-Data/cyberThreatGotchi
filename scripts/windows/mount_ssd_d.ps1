<#
.SYNOPSIS
  Bring SDK SSD (Disk 1) online and mount as D: without formatting when a partition exists.
.NOTES
  Hacker Planet / CyberThreatGotchi - run elevated: Right-click PowerShell -> Run as administrator
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
$ctgAdmin = Test-CtgIsAdmin
Write-Host ('Running as Admin: ' + $ctgAdmin)
if (-not $ctgAdmin) {
    Write-Host 'mount_ssd_d.ps1 requires Administrator. Right-click PowerShell -> Run as administrator, or:'
    Write-Host '  powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot ''Run-AsAdmin.ps1'') -TargetScript (Join-Path $PSScriptRoot ''mount_ssd_d.ps1'')'
    exit 1
}

function Write-Step([string]$msg) { Write-Host "[mount_ssd_d] $msg" }

Write-Step '=== Storage enumeration (before) ==='
try { Update-HostStorageCache } catch { Write-Step "Update-HostStorageCache: $($_.Exception.Message)" }
Get-Disk | Format-Table Number, FriendlyName, OperationalStatus, PartitionStyle, IsOffline, Size -AutoSize
Get-Partition | Format-Table DiskNumber, PartitionNumber, DriveLetter, Size, Type -AutoSize
Get-Volume | Format-Table DriveLetter, FileSystemLabel, FileSystem, Size, HealthStatus -AutoSize

$targetDisk = 1
$letter = 'D'

Write-Step "=== Target: Disk $targetDisk letter $letter (SDK SSD) ==="
$disk = Get-Disk -Number $targetDisk -ErrorAction SilentlyContinue
if (-not $disk) {
    Write-Step 'Disk 1 not visible to Get-Disk; trying diskpart online...'
} else {
    if ($disk.IsOffline) {
        Write-Step 'Bringing disk online (Set-Disk)...'
        Set-Disk -Number $targetDisk -IsOffline $false
    }
}

$dpScript = @"
select disk $targetDisk
online disk
attributes disk clear readonly
list partition
"@
$dpList = Join-Path $env:TEMP 'ctg_diskpart_list.txt'
$dpScript | Set-Content -Path $dpList -Encoding ASCII
Write-Step "diskpart list: $dpList"
diskpart /s $dpList

# Ghost D: (size 0, no filesystem) - release letter before reassignment
$volD = Get-Volume -DriveLetter $letter -ErrorAction SilentlyContinue
if ($volD -and ($volD.Size -eq 0 -or [string]::IsNullOrWhiteSpace($volD.FileSystem))) {
    Write-Step 'Removing stale drive letter D from empty volume...'
    try {
        $partGhost = Get-Partition -DriveLetter $letter -ErrorAction SilentlyContinue
        if ($partGhost) {
            Remove-PartitionAccessPath -DiskNumber $partGhost.DiskNumber -PartitionNumber $partGhost.PartitionNumber -AccessPath "${letter}:"
        }
    } catch {
        Write-Step "Remove-PartitionAccessPath failed: $($_.Exception.Message); trying mountvol /D"
        & mountvol "${letter}:" /D 2>&1 | Out-Host
    }
}

$parts = Get-Partition -DiskNumber $targetDisk -ErrorAction SilentlyContinue
if (-not $parts) {
    Write-Step 'No partitions from Get-Partition on disk 1 after online. Check USB cable / Disk Management.'
    exit 2
}

$dataPart = $parts | Where-Object { $_.Type -match 'Basic' -or $_.GptType -eq '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}' } | Sort-Object Size -Descending | Select-Object -First 1
if (-not $dataPart) { $dataPart = $parts | Sort-Object Size -Descending | Select-Object -First 1 }

Write-Step "Using partition $($dataPart.PartitionNumber) size $($dataPart.Size) type $($dataPart.Type)"

if ($dataPart.DriveLetter -ne $letter) {
    $inUse = Get-Partition -DriveLetter $letter -ErrorAction SilentlyContinue
    if ($inUse -and ($inUse.DiskNumber -ne $targetDisk -or $inUse.PartitionNumber -ne $dataPart.PartitionNumber)) {
        Write-Step 'Letter D in use by another partition; clearing...'
        Remove-PartitionAccessPath -DiskNumber $inUse.DiskNumber -PartitionNumber $inUse.PartitionNumber -AccessPath "${letter}:"
    }
    Write-Step 'Assigning drive letter D...'
    Set-Partition -DiskNumber $targetDisk -PartitionNumber $dataPart.PartitionNumber -NewDriveLetter $letter
}

$dpAssign = @"
select disk $targetDisk
select partition $($dataPart.PartitionNumber)
assign letter=$letter
"@
$dpAssignPath = Join-Path $env:TEMP 'ctg_diskpart_assign.txt'
$dpAssign | Set-Content -Path $dpAssignPath -Encoding ASCII
diskpart /s $dpAssignPath

try { Update-HostStorageCache } catch { }

Write-Step '=== Storage enumeration (after) ==='
Get-Disk -Number $targetDisk | Format-List Number, FriendlyName, OperationalStatus, IsOffline
Get-Partition -DiskNumber $targetDisk | Format-Table PartitionNumber, DriveLetter, Size, Type -AutoSize
Get-Volume -DriveLetter $letter | Format-List DriveLetter, FileSystem, FileSystemLabel, Size, SizeRemaining, HealthStatus

$root = "${letter}:\"
if (-not (Test-Path $root)) {
    Write-Step "FAIL: Test-Path $root is false"
    exit 3
}

$backupDir = Join-Path $root 'Backups'
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$probe = Join-Path $backupDir ('ctg_mount_probe_{0}.txt' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
Set-Content -Path $probe -Value "CTG mount probe OK at $(Get-Date -Format o)" -Encoding UTF8
Write-Step "SUCCESS: wrote $probe"
exit 0
