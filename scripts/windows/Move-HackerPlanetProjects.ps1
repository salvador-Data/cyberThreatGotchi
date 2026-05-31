<#
.SYNOPSIS
  Inventory and optionally move Hacker Planet LLC dev projects to profile Programs folder.

.DESCRIPTION
  Default: DiagnoseOnly — report source→destination map, sizes, git repos, and path-update targets.
  Use -ApplyMove to move folders (robocopy /MOV). Use -UpdatePaths to rewrite CTG script paths after move.

.NOTES
  Does NOT use C:\Program Files. Target: C:\Users\Owner\Programs\Hacker Planet LLC
  Log: C:\Users\Owner\Backups\logs\hacker-planet-move.log
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch] $ApplyMove,
    [switch] $UpdatePaths,
    [switch] $ApplyDiskCleanup,
    [string] $SourceRoot = 'C:\Users\Owner\Projects',
    [string] $DestRoot = 'C:\Users\Owner\Programs\Hacker Planet LLC'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
$LogFile = Join-Path $LogDir 'hacker-planet-move.log'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Write-Log([string] $Message) {
    $line = "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
    Write-Host $line
}

function Sum-Long($InputObject) {
    $m = $InputObject | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue
    if ($null -eq $m -or -not $m.PSObject.Properties.Match('Sum')) { return 0L }
    $s = $m.Sum
    if ($null -eq $s) { return 0L }
    return [long]$s
}

$SkipDirNames = @('.pytest_cache', 'node_modules', '.git')

function Get-FolderSizeBytes([string] $Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return 0L }
    Sum-Long (Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue)
}

function Format-Size([long] $Bytes) {
    if ($Bytes -lt 1) { return '0 B' }
    if ($Bytes -ge 1GB) { return '{0:N2} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N2} MB' -f ($Bytes / 1MB) }
    return '{0:N0} KB' -f ($Bytes / 1KB)
}

Write-Log "=== Move-HackerPlanetProjects $(if ($ApplyMove) { 'ApplyMove' } else { 'DiagnoseOnly' }) ==="

if (-not (Test-Path -LiteralPath $SourceRoot)) {
    Write-Log "Source missing: $SourceRoot"
    exit 1
}

if (-not (Test-Path -LiteralPath $DestRoot)) {
    if ($ApplyMove) {
        New-Item -ItemType Directory -Force -Path $DestRoot | Out-Null
        Write-Log "Created destination: $DestRoot"
    } else {
        Write-Log "Destination would be created: $DestRoot"
    }
}

$dirs = Get-ChildItem -LiteralPath $SourceRoot -Directory -Force |
    Where-Object { $SkipDirNames -notcontains $_.Name }

$plan = foreach ($d in $dirs) {
    $dest = Join-Path $DestRoot $d.Name
    $size = Get-FolderSizeBytes $d.FullName
    $isGit = Test-Path (Join-Path $d.FullName '.git')
    [PSCustomObject]@{
        Name        = $d.Name
        Source      = $d.FullName
        Destination = $dest
        SizeBytes   = $size
        SizeHuman   = Format-Size $size
        GitRepo     = $isGit
        DestExists  = Test-Path -LiteralPath $dest
    }
}

$totalBytes = ($plan | Measure-Object -Property SizeBytes -Sum).Sum
if ($null -eq $totalBytes) { $totalBytes = 0 }
Write-Log ("Projects to move: {0}  Total: {1}" -f @($plan).Count, (Format-Size $totalBytes))
$plan | Format-Table Name, SizeHuman, GitRepo, DestExists, Source, Destination -AutoSize | Out-String | ForEach-Object { Write-Log $_.TrimEnd() }

$reportPath = Join-Path $LogDir 'hacker-planet-move-plan.json'
$plan | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $reportPath -Encoding UTF8
Write-Log "Plan JSON: $reportPath"

Write-Log '--- External references (manual verify) ---'
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match 'CTG|Hacker|cyberThreat' } | ForEach-Object {
    $a = (Get-ScheduledTask $_).Actions
    Write-Log ("ScheduledTask: {0} -> {1} {2}" -f $_.TaskName, $a.Execute, $a.Arguments)
}
$vbox = Get-Command VBoxManage -ErrorAction SilentlyContinue
if ($vbox) {
    & VBoxManage list vms 2>$null | ForEach-Object { Write-Log "VirtualBox: $_" }
} else {
    Write-Log 'VBoxManage not in PATH (skip VM list)'
}

if ($ApplyMove) {
    foreach ($row in $plan) {
        if ($row.DestExists) {
            Write-Log "SKIP (dest exists): $($row.Name)"
            continue
        }
        Write-Log "Moving: $($row.Source) -> $($row.Destination)"
        $null = robocopy $row.Source $row.Destination /E /MOVE /R:2 /W:5 /NFL /NDL /NP /LOG+:$LogFile
        if ($LASTEXITCODE -ge 8) {
            Write-Log "Robocopy error code $LASTEXITCODE for $($row.Name)"
        }
    }
}

$OldProjects = 'C:\Users\Owner\Projects'
$NewPrograms = 'C:\Users\Owner\Programs\Hacker Planet LLC'
$OldCtg = Join-Path $OldProjects 'cyberThreatGotchi'
$NewCtg = Join-Path $NewPrograms 'cyberThreatGotchi'

if ($UpdatePaths) {
    if (-not (Test-Path -LiteralPath $NewCtg)) {
        Write-Log "UpdatePaths: cyberThreatGotchi not at $NewCtg — run -ApplyMove first or fix path"
    } else {
        $ctgRoot = $NewCtg
        $patterns = @(
            @{ Old = $OldCtg; New = $NewCtg },
            @{ Old = $OldProjects; New = $NewPrograms }
        )
        $files = Get-ChildItem -LiteralPath $ctgRoot -Recurse -Include *.ps1,*.py,*.md,*.mdc,*.bat -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notmatch '\\\.git\\|\\node_modules\\|\\.venv\\|__pycache__|\\.pio\\|\\.pytest_cache\\'
            }
        $updated = @()
        foreach ($f in $files) {
            $text = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $text) { continue }
            $newText = $text
            foreach ($p in $patterns) {
                $newText = $newText.Replace($p.Old, $p.New)
            }
            if ($newText -ne $text) {
                if ($PSCmdlet.ShouldProcess($f.FullName, 'Update paths')) {
                    Set-Content -LiteralPath $f.FullName -Value $newText -Encoding UTF8 -NoNewline
                }
                $updated += $f.FullName
                Write-Log "Updated paths: $($f.FullName)"
            }
        }
        $listPath = Join-Path $LogDir 'hacker-planet-path-updates.txt'
        $updated | Set-Content -LiteralPath $listPath -Encoding UTF8
        Write-Log "Path update list: $listPath ($($updated.Count) files)"
    }
}

function Get-DiskCleanupPlan {
    $items = @()
    $temp = $env:TEMP
    if (Test-Path $temp) {
        $b = Sum-Long (Get-ChildItem $temp -Recurse -File -Force -ErrorAction SilentlyContinue)
        $items += [PSCustomObject]@{ Category = 'User TEMP'; Path = $temp; SizeBytes = $b; Action = 'Clear old files (manual or ApplyDiskCleanup)' }
    }
    $logDir = Join-Path $env:USERPROFILE 'Backups\logs'
    if (Test-Path $logDir) {
        $cutoff = (Get-Date).AddDays(-90)
        $oldLogs = @(Get-ChildItem $logDir -Filter '*.log' -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $cutoff })
        $b = Sum-Long $oldLogs
        $items += [PSCustomObject]@{ Category = 'Logs >90d'; Path = $logDir; SizeBytes = $b; Action = "Delete $($oldLogs.Count) log files" }
    }
    $rbBytes = 0L
    try {
        $shell = New-Object -ComObject Shell.Application
        $rb = $shell.NameSpace(0x0a)
        if ($rb -and $rb.Items()) {
            foreach ($i in @($rb.Items())) {
                try { $rbBytes += [long]$i.Size } catch { }
            }
        }
    } catch { }
    $items += [PSCustomObject]@{ Category = 'Recycle Bin'; Path = '(shell)'; SizeBytes = $rbBytes; Action = 'Empty recycle bin' }
    $items += [PSCustomObject]@{ Category = 'Windows Disk Cleanup'; Path = 'cleanmgr'; SizeBytes = 0L; Action = 'Run cleanmgr /sageset:1 then /sagerun:1 (manual)' }
    return $items
}

$cleanup = Get-DiskCleanupPlan
Write-Log '--- Disk cleanup (DiagnoseOnly) ---'
$cleanup | ForEach-Object { Write-Log ("{0}: {1} — {2}" -f $_.Category, (Format-Size $_.SizeBytes), $_.Action) }

if ($ApplyDiskCleanup) {
    Write-Log 'ApplyDiskCleanup: removing logs >90 days'
    $cutoff = (Get-Date).AddDays(-90)
    Get-ChildItem (Join-Path $env:USERPROFILE 'Backups\logs') -Filter '*.log' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue; Write-Log "Deleted log: $($_.Name)" }
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Log 'Recycle bin cleared'
}

if (-not $ApplyMove -and -not $UpdatePaths -and -not $ApplyDiskCleanup) {
    Write-Log 'DiagnoseOnly complete. Re-run with -ApplyMove, then -UpdatePaths; optional -ApplyDiskCleanup'
}
