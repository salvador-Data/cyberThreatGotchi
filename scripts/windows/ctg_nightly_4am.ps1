<#
Windows laptop + hackerplanet.dev automation only (Andy PC).

.SYNOPSIS
  CyberThreatGotchi nightly 4 AM orchestrator — backup, website, scan, audit, log.

.DESCRIPTION
  Runs every night on Andy's Windows laptop. Always includes ctg_website_nightly.ps1
  (website/ + docs/web/ backup, sync_website_to_docs.py, portfolio export, GET
  https://hackerplanet.dev). Also runs selective SSD backup (when D: online),
  OneDrive staging, Windows Update audit, Defender quick scan, Sysmon/Wazuh checks,
  VPN preservation, and optional repo sync. Does NOT run Harden-Windows-Security nightly.

.PARAMETER ApplyUpdates
  Install pending Windows Updates (may reboot). Default: audit only.

.PARAMETER SkipBackup
  Skip selective_ssd_backup.ps1 and cloud_backup.ps1 only. Website nightly still runs.

.PARAMETER SyncRepos
  git pull in C:\Users\Owner\Projects\cyberThreatGotchi (default: dry-run log only).

.PARAMETER DeployWebsite
  Commit and push website/ + docs/web/ to main (triggers GitHub Pages). Default: off.

.PARAMETER VerboseLog
  Mirror each step to the host console.

.EXAMPLE
  .\scripts\windows\ctg_nightly_4am.ps1
#>
[CmdletBinding()]
param(
    [switch] $ApplyUpdates,
    [switch] $SkipBackup,
    [switch] $SyncRepos,
    [switch] $DeployWebsite,
    [switch] $VerboseLog
)

$ErrorActionPreference = 'Continue'
$Repo = 'C:\Users\Owner\Projects\cyberThreatGotchi'
$Win = Join-Path $Repo 'scripts\windows'
$date = Get-Date -Format 'yyyy-MM-dd'
$LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
$LogNightly = Join-Path $LogDir "nightly-$date.log"
$LogDesktop = Join-Path ([Environment]::GetFolderPath('Desktop')) 'ctg-soc-run-log.txt'
$SsdLogDir = 'D:\Backups\logs'
$MinFreeBytes = 5GB
$script:StepErrors = 0
$script:LastBackupRoot = ''

. (Join-Path $Win 'CTG-AdminCommon.ps1')
$script:CtgIsAdmin = Test-CtgIsAdmin

function Write-NightlyLog {
    param([string] $Message, [string] $Level = 'INFO')
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    try {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        Add-Content -Path $LogNightly -Value $line -Encoding utf8 -ErrorAction Stop
    } catch {
        Write-Warning "Nightly log write failed: $($_.Exception.Message)"
    }
    foreach ($attempt in 1..3) {
        try {
            Add-Content -Path $LogDesktop -Value $line -Encoding utf8 -ErrorAction Stop
            break
        } catch {
            if ($attempt -lt 3) { Start-Sleep -Milliseconds 250 }
        }
    }
    if ($VerboseLog -or $Level -ne 'INFO') {
        Write-Host $line
    }
}

function Add-StepError([string] $Context) {
    $script:StepErrors++
    Write-NightlyLog "$Context (step error count: $script:StepErrors)" 'WARN'
}

function Test-CtgVolumeFreeSpace {
    param([string] $DriveLetter)
    if (-not $DriveLetter) { return }
    $vol = Get-Volume -DriveLetter $DriveLetter -ErrorAction SilentlyContinue
    if (-not $vol) {
        Write-NightlyLog "Disk space: ${DriveLetter}: not present"
        return
    }
    $freeGb = [math]::Round($vol.SizeRemaining / 1GB, 2)
    if ($vol.SizeRemaining -lt $MinFreeBytes) {
        Write-NightlyLog "Disk space: ${DriveLetter}: WARNING ${freeGb} GB free (< 5 GB)" 'WARN'
    } else {
        Write-NightlyLog "Disk space: ${DriveLetter}: ${freeGb} GB free"
    }
}

function Test-CtgSsdWritable {
    param([string] $ProbeRoot = 'D:\Backups')
    try {
        New-Item -ItemType Directory -Path $ProbeRoot -Force | Out-Null
        $probe = Join-Path $ProbeRoot ('.ctg_nightly_write_{0}.tmp' -f (Get-Date -Format 'yyyyMMddHHmmss'))
        'ok' | Set-Content -Path $probe -Encoding ASCII -ErrorAction Stop
        Remove-Item -Path $probe -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

function Invoke-CtgMountSsdIfNeeded {
    param([hashtable] $Disk1)
    if (-not $script:CtgIsAdmin) {
        Write-NightlyLog 'SSD mount skipped: not running as Administrator' 'WARN'
        return $false
    }
    $mountScript = Join-Path $Win 'mount_ssd_d.ps1'
    if (-not (Test-Path $mountScript)) {
        Write-NightlyLog "SSD mount skipped: missing $mountScript" 'WARN'
        return $false
    }
    $needsMount = $false
    if ($Disk1 -and $Disk1.IsOffline) { $needsMount = $true }
    if (-not (Test-Path 'D:\')) { $needsMount = $true }
    if (-not $needsMount) { return $true }

    Write-NightlyLog 'SSD mount: invoking mount_ssd_d.ps1'
    & $mountScript *>&1 | ForEach-Object { Write-NightlyLog "  mount_ssd_d: $_" }
    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
        Write-NightlyLog "SSD mount: mount_ssd_d.ps1 exit code $LASTEXITCODE" 'WARN'
        return $false
    }
    return (Test-Path 'D:\')
}

function Get-CtgSsdStatus {
    $detail = @()
    $disk = Get-Disk -Number 1 -ErrorAction SilentlyContinue

    if (-not $disk) {
        return @{
            Status   = 'not_ready'
            Writable = $false
            Detail   = 'Disk 1 not visible to Get-Disk'
            Disk     = $null
        }
    }

    $detail += "Disk1=$($disk.FriendlyName) OpStatus=$($disk.OperationalStatus) Offline=$($disk.IsOffline)"

    if ($disk.OperationalStatus -eq 'No Media') {
        return @{
            Status   = 'not_ready'
            Writable = $false
            Detail   = ($detail -join '; ') + '; No Media (SSD unplugged or not ready)'
            Disk     = $disk
        }
    }

    if ($disk.IsOffline -or -not (Test-Path 'D:\')) {
        $mounted = Invoke-CtgMountSsdIfNeeded -Disk1 $disk
        if (-not $mounted -and -not (Test-Path 'D:\')) {
            return @{
                Status   = 'offline'
                Writable = $false
                Detail   = ($detail -join '; ') + '; D: not available after mount attempt'
                Disk     = $disk
            }
        }
    }

    if (-not (Test-Path 'D:\')) {
        return @{
            Status   = 'offline'
            Writable = $false
            Detail   = ($detail -join '; ') + '; Test-Path D:\ is false'
            Disk     = $disk
        }
    }

    if (-not (Test-CtgSsdWritable -ProbeRoot 'D:\Backups')) {
        return @{
            Status   = 'not_ready'
            Writable = $false
            Detail   = ($detail -join '; ') + '; D:\Backups not writable'
            Disk     = $disk
        }
    }

    return @{
        Status   = 'online'
        Writable = $true
        Detail   = ($detail -join '; ') + '; D: writable'
        Disk     = $disk
    }
}

function Copy-SocLogsToSsd {
    if (-not (Test-Path 'D:\Backups')) { return }
    try {
        New-Item -ItemType Directory -Path $SsdLogDir -Force | Out-Null
        if (Test-Path $LogNightly) {
            $dest = Join-Path $SsdLogDir (Split-Path $LogNightly -Leaf)
            Copy-Item -Path $LogNightly -Destination $dest -Force
            Write-NightlyLog "Copied nightly log to $dest"
        }
        if (Test-Path $LogDesktop) {
            $socDest = Join-Path $SsdLogDir 'ctg-soc-run-log.txt'
            Copy-Item -Path $LogDesktop -Destination $socDest -Force
            Write-NightlyLog "Copied SOC log to $socDest"
        }
        $elevatedLog = Join-Path $Win 'ctg-soc-run-log-elevated.txt'
        if (Test-Path $elevatedLog) {
            $elevDest = Join-Path $SsdLogDir 'ctg-soc-run-log-elevated.txt'
            Copy-Item -Path $elevatedLog -Destination $elevDest -Force
            Write-NightlyLog "Copied elevated SOC log to $elevDest"
        }
    } catch {
        Write-NightlyLog "SSD SOC log copy failed: $($_.Exception.Message)" 'WARN'
    }
}

function Invoke-CtgWindowsUpdateAudit {
    Write-NightlyLog '--- Windows Update (audit) ---'
    if ($ApplyUpdates) {
        Write-NightlyLog 'ApplyUpdates: ENABLED — updates may install and reboot' 'WARN'
    } else {
        Write-NightlyLog 'ApplyUpdates: disabled — audit/scan only (no auto-install)'
    }

    $module = Get-Module -ListAvailable -Name PSWindowsUpdate -ErrorAction SilentlyContinue
    if ($module) {
        try {
            Import-Module PSWindowsUpdate -ErrorAction Stop
            if ($ApplyUpdates) {
                Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false *>&1 |
                    ForEach-Object { Write-NightlyLog "  WU: $_" }
            } else {
                Get-WindowsUpdate *>&1 | ForEach-Object { Write-NightlyLog "  WU: $_" }
            }
            return
        } catch {
            Write-NightlyLog "PSWindowsUpdate failed: $($_.Exception.Message)" 'WARN'
        }
    }

    Write-NightlyLog 'PSWindowsUpdate not installed; using USOClient StartScan'
    try {
        $uso = Join-Path $env:SystemRoot 'System32\USOClient.exe'
        if (Test-Path $uso) {
            & $uso StartScan *>&1 | ForEach-Object { Write-NightlyLog "  USOClient: $_" }
        } else {
            Write-NightlyLog 'USOClient.exe not found' 'WARN'
        }
    } catch {
        Write-NightlyLog "USOClient scan failed: $($_.Exception.Message)" 'WARN'
    }
}

function Invoke-CtgDefenderQuickScan {
    Write-NightlyLog '--- Defender quick scan ---'
    if (-not (Get-Command Start-MpScan -ErrorAction SilentlyContinue)) {
        Write-NightlyLog 'Start-MpScan not available (Defender module missing)' 'WARN'
        return
    }
    try {
        Start-MpScan -ScanType QuickScan -AsJob | Out-Null
        Write-NightlyLog 'Defender QuickScan started (async job)'
    } catch {
        Write-NightlyLog "Defender QuickScan failed: $($_.Exception.Message)" 'WARN'
    }
}

function Invoke-CtgSysmonCheck {
    Write-NightlyLog '--- Sysmon service ---'
    $svc = Get-Service -Name Sysmon -ErrorAction SilentlyContinue
    if ($svc) {
        Write-NightlyLog "Sysmon: Status=$($svc.Status) StartType=$($svc.StartType)"
    } else {
        Write-NightlyLog 'Sysmon: service not installed' 'WARN'
    }
}

function Invoke-CtgWazuhCheck {
    Write-NightlyLog '--- Wazuh agent (status only) ---'
    $mgr = $env:CTG_WAZUH_MANAGER
    if (-not $mgr) { $mgr = $env:WAZUH_MANAGER }
    if (-not $mgr) {
        Write-NightlyLog 'Wazuh: SKIPPED (CTG_WAZUH_MANAGER / WAZUH_MANAGER not set)'
        return
    }
    $svc = Get-Service -Name WazuhSvc -ErrorAction SilentlyContinue
    if ($svc) {
        Write-NightlyLog "WazuhSvc: Status=$($svc.Status); Manager=$mgr"
    } else {
        Write-NightlyLog "WazuhSvc: not installed; Manager env=$mgr" 'WARN'
    }
}

function Invoke-CtgGitRepos {
    Write-NightlyLog '--- Git repos ---'
    if (-not (Test-Path $Repo)) {
        Write-NightlyLog "Repo missing: $Repo" 'WARN'
        return
    }
    Push-Location $Repo
    try {
        if ($SyncRepos) {
            Write-NightlyLog "SyncRepos: git pull in $Repo"
            git pull --ff-only 2>&1 | ForEach-Object { Write-NightlyLog "  git: $_" }
        } else {
            Write-NightlyLog 'Git: manual review recommended (dry-run; use -SyncRepos to pull)'
            git fetch --dry-run 2>&1 | ForEach-Object { Write-NightlyLog "  git fetch --dry-run: $_" }
            git status -sb 2>&1 | ForEach-Object { Write-NightlyLog "  git status: $_" }
        }
    } catch {
        Write-NightlyLog "Git step failed: $($_.Exception.Message)" 'WARN'
    } finally {
        Pop-Location
    }
}

# --- Run ---
Write-NightlyLog "=== CTG Nightly 4 AM started === Host=$env:COMPUTERNAME User=$env:USERNAME Admin=$script:CtgIsAdmin ==="
Write-NightlyLog 'Scope: Windows laptop + hackerplanet.dev website (mandatory every run)'

Write-NightlyLog '--- Disk space ---'
Test-CtgVolumeFreeSpace -DriveLetter 'C'
if (Test-Path 'D:\') { Test-CtgVolumeFreeSpace -DriveLetter 'D' }

$ssd = Get-CtgSsdStatus
Write-NightlyLog ("SSD: {0} - {1}" -f $ssd.Status, $ssd.Detail)

if ($ssd.Status -eq 'online' -and $ssd.Writable) {
    $script:LastBackupRoot = "D:\Backups\Andy-PC-$date"
    Write-NightlyLog "Backup tree (SSD): $script:LastBackupRoot"
} else {
    Write-NightlyLog 'SSD unavailable — backup tree uses C:\Users\Owner\Backups fallback path'
    $script:LastBackupRoot = Join-Path $env:USERPROFILE "Backups\Andy-PC-$date"
    Write-NightlyLog "Backup tree (fallback): $script:LastBackupRoot"
}

if (-not $SkipBackup) {
    Write-NightlyLog '--- Selective backup ---'
    $backupScript = Join-Path $Win 'selective_ssd_backup.ps1'
    & $backupScript -BackupRoot $script:LastBackupRoot *>&1 | ForEach-Object { Write-NightlyLog $_ }

    Write-NightlyLog '--- Cloud backup (OneDrive) ---'
    $cloudScript = Join-Path $Win 'cloud_backup.ps1'
    if (Test-Path $cloudScript) {
        $cloudArgs = @{ NightlyLogPath = $LogNightly }
        if ($script:LastBackupRoot) { $cloudArgs['SourceBackupRoot'] = $script:LastBackupRoot }
        try {
            & $cloudScript @cloudArgs *>&1 | ForEach-Object { Write-NightlyLog $_ }
        } catch {
            Write-NightlyLog "cloud_backup.ps1 failed: $($_.Exception.Message)" 'WARN'
            Add-StepError 'cloud_backup'
        }
    } else {
        Write-NightlyLog 'cloud_backup.ps1 missing' 'WARN'
    }
} else {
    Write-NightlyLog 'SkipBackup: selective + cloud backup skipped (website nightly still runs)'
}

$websiteScript = Join-Path $Win 'ctg_website_nightly.ps1'
if (Test-Path $websiteScript) {
    Write-NightlyLog '--- Website nightly (hackerplanet.dev) — mandatory ---'
    & $websiteScript -BackupRoot $script:LastBackupRoot -DeployWebsite:$DeployWebsite `
        -LogAction { param($m) Write-NightlyLog $m }
} else {
    Write-NightlyLog 'ctg_website_nightly.ps1 missing — website step failed' 'WARN'
    Add-StepError 'website_nightly'
}

Invoke-CtgWindowsUpdateAudit
Invoke-CtgDefenderQuickScan
Invoke-CtgSysmonCheck
Invoke-CtgWazuhCheck

Write-NightlyLog '--- CTG Audit Autorun (compartments) ---'
$auditScript = Join-Path $Win 'CTG-AuditAutorun.ps1'
if (Test-Path $auditScript) {
    try {
        & $auditScript -AuditOnly -SinkCloud *>&1 | ForEach-Object { Write-NightlyLog "  audit: $_" }
    } catch {
        Write-NightlyLog "CTG-AuditAutorun.ps1 failed: $($_.Exception.Message)" 'WARN'
        Add-StepError 'audit_autorun'
    }
} else {
    Write-NightlyLog 'CTG-AuditAutorun.ps1 missing' 'WARN'
}

Write-NightlyLog '--- Preserve DuckDuckGo VPN ---'
$vpnScript = Join-Path $Win 'Preserve-DuckDuckGoVpn.ps1'
if (Test-Path $vpnScript) {
    . $vpnScript
    Invoke-CtgPreserveDuckDuckGoVpn -LogAction { param($m) Write-NightlyLog $m }
} else {
    Write-NightlyLog 'Preserve-DuckDuckGoVpn.ps1 not found — skipped'
}

Invoke-CtgGitRepos

if ($ssd.Status -eq 'online' -and $ssd.Writable) {
    Copy-SocLogsToSsd
}

$summary = "SUMMARY: Host=$env:COMPUTERNAME SSD=$($ssd.Status) BackupRoot=$script:LastBackupRoot Errors=$script:StepErrors ApplyUpdates=$($ApplyUpdates.IsPresent) SkipBackup=$($SkipBackup.IsPresent) DeployWebsite=$($DeployWebsite.IsPresent)"
Write-NightlyLog $summary
Write-NightlyLog '=== CTG Nightly 4 AM finished ==='

exit 0
