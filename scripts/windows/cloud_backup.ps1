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

.PARAMETER NightlyLogPath
  Optional nightly log file to mirror into OneDrive\Backups\logs\.

.EXAMPLE
  .\scripts\windows\cloud_backup.ps1

.EXAMPLE
  .\scripts\windows\cloud_backup.ps1 -SourceBackupRoot 'D:\Backups\Andy-PC-2026-05-29'
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $SourceBackupRoot = '',
    [string] $NightlyLogPath = '',
    [switch] $PreviewOnly
)

$ErrorActionPreference = 'Stop'
$date = Get-Date -Format 'yyyy-MM-dd'

function Get-CtgOneDriveInfo {
    foreach ($entry in @(
            @{ Env = 'OneDriveCommercial'; Kind = 'Commercial (Work/School)' },
            @{ Env = 'OneDriveConsumer'; Kind = 'Personal (Consumer)' },
            @{ Env = 'OneDrive'; Kind = 'Personal (OneDrive)' }
        )) {
        $p = [Environment]::GetEnvironmentVariable($entry.Env, 'Process')
        if (-not $p) { $p = [Environment]::GetEnvironmentVariable($entry.Env, 'User') }
        if ($p -and (Test-Path $p)) {
            return @{ Path = $p; Kind = $entry.Kind; EnvVar = $entry.Env }
        }
    }
    $default = Join-Path $env:USERPROFILE 'OneDrive'
    if (Test-Path $default) {
        return @{ Path = $default; Kind = 'Personal (default folder)'; EnvVar = 'default' }
    }
    return $null
}

function Get-OneDriveRoot {
    $info = Get-CtgOneDriveInfo
    if ($info) { return $info.Path }
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
$odInfo = Get-CtgOneDriveInfo
if (-not $odInfo) {
    Write-Warning 'OneDrive folder not found. Sign into Microsoft account and enable OneDrive sync first.'
    Write-Host 'Manual: Settings > Accounts > Windows backup, or install OneDrive from microsoft.com/onedrive'
    exit 2
}
$od = $odInfo.Path

$dest = Join-Path $od "Backups\Andy-PC-$date"
Write-Host "Source backup: $src"
Write-Host "OneDrive root: $od"
Write-Host "OneDrive kind: $($odInfo.Kind) (env: $($odInfo.EnvVar))"
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

foreach ($folder in @('website', 'docs-web', 'portfolio', 'portfolio_export')) {
    $folderSrc = Join-Path $src $folder
    if (Test-Path $folderSrc) {
        $folderDest = Join-Path $dest $folder
        New-Item -ItemType Directory -Path $folderDest -Force | Out-Null
        Copy-Item -Path (Join-Path $folderSrc '*') -Destination $folderDest -Recurse -Force
        Write-Host "Copied $folder\ (hackerplanet.dev / portfolio backup)" -ForegroundColor Green
    }
}

. (Join-Path $PSScriptRoot 'CTG-Paths.ps1')
$repoRoot = Get-CtgRepoRoot -FromPath $PSScriptRoot
$portfolioScript = Join-Path $repoRoot 'scripts\export_portfolio_html.py'
if ((Test-Path $portfolioScript) -and -not (Test-Path (Join-Path $src 'portfolio_export'))) {
    $portfolioOut = Join-Path $src 'portfolio_export'
    New-Item -ItemType Directory -Path $portfolioOut -Force | Out-Null
    Write-Host "Portfolio export (OneDrive staging): $portfolioScript -> $portfolioOut"
    try {
        $py = (Get-Command python -ErrorAction SilentlyContinue).Source
        if (-not $py) { $py = (Get-Command py -ErrorAction SilentlyContinue).Source }
        if ($py) {
            & $py $portfolioScript $portfolioOut 2>&1 | ForEach-Object { Write-Host $_ }
            if (Test-Path $portfolioOut) {
                $portfolioDest = Join-Path $dest 'portfolio_export'
                New-Item -ItemType Directory -Path $portfolioDest -Force | Out-Null
                Copy-Item -Path (Join-Path $portfolioOut '*') -Destination $portfolioDest -Recurse -Force
                Write-Host 'Copied portfolio_export\ to OneDrive staging' -ForegroundColor Green
            }
        } else {
            Write-Warning 'Python not found - portfolio export skipped'
        }
    } catch {
        Write-Warning "Portfolio export failed: $($_.Exception.Message)"
    }
}

if ($NightlyLogPath -and (Test-Path $NightlyLogPath)) {
    $odLogDir = Join-Path $od 'Backups\logs'
    New-Item -ItemType Directory -Path $odLogDir -Force | Out-Null
    $odLogDest = Join-Path $odLogDir (Split-Path $NightlyLogPath -Leaf)
    Copy-Item -Path $NightlyLogPath -Destination $odLogDest -Force
    Write-Host "Mirrored nightly log to OneDrive: $odLogDest" -ForegroundColor Green
}

$cloudNote = @(
    "Microsoft Windows cloud backup note"
    "Generated: $(Get-Date -Format o)"
    "OneDrive client installed: $(Test-OneDriveClient)"
    "OneDrive path: $od"
    "OneDrive kind: $($odInfo.Kind)"
    "OneDrive env var: $($odInfo.EnvVar)"
    "Staged folder: $dest"
    "Nightly log mirrored: $(if ($NightlyLogPath) { $NightlyLogPath } else { 'none' })"
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

