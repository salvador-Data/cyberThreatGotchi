<#
.SYNOPSIS
  Stage backup manifest and critical subset to Microsoft OneDrive (Windows cloud sync).

.DESCRIPTION
  Copies BACKUP_MANIFEST.txt, setup_log.txt, installed_programs.txt, and optional
  registry_exports from SSD/local backup to OneDrive\Backups\Andy-PC-YYYY-MM-DD.
  Does not upload secrets. Optional CTG alert via CTG_WEBHOOK_URL + CTG_WEBHOOK_SECRET (env).

.PARAMETER SourceBackupRoot
  Local or SSD backup folder (default: newest D:\Backups\Andy-PC-* or today).

.PARAMETER WhatIf
  Show paths only; no copy (PreviewOnly).

.EXAMPLE
  .\scripts\windows\cloud_backup.ps1

.EXAMPLE
  .\scripts\windows\cloud_backup.ps1 -SourceBackupRoot 'D:\Backups\Andy-PC-2026-05-29'
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $SourceBackupRoot = '',
    [switch] $PreviewOnly
)

$ErrorActionPreference = 'Stop'
$date = Get-Date -Format 'yyyy-MM-dd'

function Get-OneDriveRoot {
    foreach ($name in @('OneDriveCommercial', 'OneDriveConsumer', 'OneDrive')) {
        $p = [Environment]::GetEnvironmentVariable($name, 'Process')
        if (-not $p) { $p = [Environment]::GetEnvironmentVariable($name, 'User') }
        if ($p -and (Test-Path $p)) { return $p }
    }
    $default = Join-Path $env:USERPROFILE 'OneDrive'
    if (Test-Path $default) { return $default }
    return $null
}

function Find-LatestBackup {
    param([string]$Explicit)
    if ($Explicit -and (Test-Path $Explicit)) { return $Explicit }
    $candidates = @()
    if (Test-Path 'D:\Backups') {
        $candidates += Get-ChildItem 'D:\Backups' -Directory -Filter 'Andy-PC-*' -ErrorAction SilentlyContinue
    }
    $local = Join-Path $env:USERPROFILE 'Backups'
    if (Test-Path $local) {
        $candidates += Get-ChildItem $local -Directory -Filter 'Andy-PC-*' -ErrorAction SilentlyContinue
    }
    if ($candidates.Count -gt 0) {
        return ($candidates | Sort-Object Name -Descending | Select-Object -First 1).FullName
    }
    return "D:\Backups\Andy-PC-$date"
}

function Test-OneDriveClient {
    $paths = @(
        "${env:ProgramFiles}\Microsoft OneDrive\OneDrive.exe",
        "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe"
    )
    foreach ($p in $paths) { if (Test-Path $p) { return $true } }
    return $false
}

$src = Find-LatestBackup -Explicit $SourceBackupRoot
$od = Get-OneDriveRoot
if (-not $od) {
    Write-Warning 'OneDrive folder not found. Sign into Microsoft account and enable OneDrive sync first.'
    Write-Host 'Manual: Settings > Accounts > Windows backup, or install OneDrive from microsoft.com/onedrive'
    exit 2
}

$dest = Join-Path $od "Backups\Andy-PC-$date"
Write-Host "Source backup: $src"
Write-Host "OneDrive root: $od"
Write-Host "Cloud staging: $dest"

if (-not (Test-Path $src)) {
    Write-Warning "Source backup folder missing. Run selective_ssd_backup.ps1 first."
    exit 3
}

if ($PreviewOnly) { return }

if (-not $PSCmdlet.ShouldProcess($dest, 'Copy backup subset to OneDrive')) { return }

New-Item -ItemType Directory -Path $dest -Force | Out-Null

$files = @('BACKUP_MANIFEST.txt', 'setup_log.txt', 'installed_programs.txt', 'WAZUH_SETUP_CHECKLIST.txt', 'MICROSOFT_CLOUD_CHECKLIST.txt')
foreach ($f in $files) {
    $from = Join-Path $src $f
    if (Test-Path $from) {
        Copy-Item -Path $from -Destination (Join-Path $dest $f) -Force
        Write-Host "Copied $f" -ForegroundColor Green
    }
}

$regSrc = Join-Path $src 'registry_exports'
if (Test-Path $regSrc) {
    $regDest = Join-Path $dest 'registry_exports'
    New-Item -ItemType Directory -Path $regDest -Force | Out-Null
    Copy-Item -Path (Join-Path $regSrc '*') -Destination $regDest -Recurse -Force
    Write-Host 'Copied registry_exports\' -ForegroundColor Green
}

$cloudNote = @(
    "Microsoft Windows cloud backup note"
    "Generated: $(Get-Date -Format o)"
    "OneDrive client installed: $(Test-OneDriveClient)"
    "OneDrive path: $od"
    "Staged folder: $dest"
    ""
    "Andy manual steps:"
    "1. Sign in: Settings > Accounts > Your Microsoft account"
    "2. OneDrive: ensure Files On-Demand or sync includes Backups\Andy-PC-*"
    "3. Win11: Settings > Accounts > Windows backup (File History / PC backup if offered)"
    "4. Defender for Cloud: portal.azure.com > Microsoft Defender for Cloud > enable free CSPM on subscription"
    "5. Entra: entra.microsoft.com > Security > Identity Protection / MFA for your account"
    ""
    "No tokens or secrets stored in this file."
)
$cloudNotePath = Join-Path $dest 'MICROSOFT_CLOUD_CHECKLIST.txt'
$cloudNote | Set-Content -Path $cloudNotePath -Encoding UTF8
Copy-Item $cloudNotePath (Join-Path $src 'MICROSOFT_CLOUD_CHECKLIST.txt') -Force -ErrorAction SilentlyContinue

$webhookUrl = [Environment]::GetEnvironmentVariable('CTG_WEBHOOK_URL', 'User')
if (-not $webhookUrl) { $webhookUrl = [Environment]::GetEnvironmentVariable('CTG_WEBHOOK_URL', 'Machine') }
$webhookSecret = [Environment]::GetEnvironmentVariable('CTG_WEBHOOK_SECRET', 'User')
if (-not $webhookSecret) { $webhookSecret = [Environment]::GetEnvironmentVariable('CTG_WEBHOOK_SECRET', 'Machine') }

if ($webhookUrl -and $webhookSecret) {
    try {
        $body = @{
            event = 'windows_cloud_backup_staged'
            host  = $env:COMPUTERNAME
            path  = $dest
            ts    = (Get-Date -Format o)
        } | ConvertTo-Json -Compress
        $headers = @{ 'X-CTG-Secret' = $webhookSecret; 'Content-Type' = 'application/json' }
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Headers $headers -Body $body -TimeoutSec 15
        Write-Host 'CTG webhook notified (no secrets logged).' -ForegroundColor Gray
    } catch {
        Write-Warning "CTG webhook notify failed: $($_.Exception.Message)"
    }
} else {
    Write-Host 'CTG webhook optional: set CTG_WEBHOOK_URL and CTG_WEBHOOK_SECRET to notify CTG API.' -ForegroundColor Gray
}

Write-Host ''
Write-Host "Done. OneDrive will sync when signed in: $dest" -ForegroundColor Green

