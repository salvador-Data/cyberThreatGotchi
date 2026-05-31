<#
.SYNOPSIS
  Publish UTMS threat pack OTA broadcast manifest to Backups share.

.DESCRIPTION
  Runs scripts/utms_threat_pack.py to stage signed-manifest placeholder and pack copy
  under Backups\ctg-utms-broadcast for Cardputer/Kali pull. Emits utms.broadcast CTGEvent.

.PARAMETER Channel
  Broadcast channel: lab, pro, or dev.

.PARAMETER PackPath
  Optional custom pack JSON (default: scripts/utms/threat_pack.example.json).

.PARAMETER DiagnoseOnly
  Print paths and digest only.

.EXAMPLE
  .\scripts\windows\Start-CtgUtmsThreatBroadcast.ps1
#>
[CmdletBinding()]
param(
    [ValidateSet('lab', 'pro', 'dev')]
    [string] $Channel = 'lab',
    [string] $PackPath = '',
    [switch] $DiagnoseOnly
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'CTG-WiresharkCommon.ps1')

$repo = Get-CtgRepoRoot -FromPath $PSScriptRoot
$backups = Get-CtgBackupsRoot
$outDir = Join-Path $backups 'ctg-utms-broadcast'
$packScript = Join-Path $repo 'scripts\utms_threat_pack.py'
if (-not $PackPath) {
    $PackPath = Join-Path $repo 'scripts\utms\threat_pack.example.json'
}

Write-Host 'CTG UTMS threat pack broadcast (authorized lab OTA only)' -ForegroundColor Cyan
Write-Host "  Out: $outDir"
Write-Host "  Pack: $PackPath"

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
if (-not $python) { throw 'Python not found on PATH.' }

Push-Location $repo
try {
    if ($DiagnoseOnly) {
        & $python.Source $packScript --pack $PackPath --print-digest
        exit $LASTEXITCODE
    }
    & $python.Source $packScript --pack $PackPath --out $outDir --channel $Channel
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $manifestPath = Join-Path $outDir 'utms-broadcast-manifest.json'
    $manifest = Get-Content $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
    $payload = @{
        type     = 'utms.broadcast'
        source   = 'windows'
        severity = 'info'
        message  = "UTMS pack broadcast staged channel=$Channel sha256=$($manifest.pack_sha256.Substring(0,16))..."
    } | ConvertTo-Json -Compress
    & $python.Source -m core.ctg_event_bus emit --json $payload | Out-Null
    Write-Host "Broadcast manifest: $manifestPath" -ForegroundColor Green
} finally {
    Pop-Location
}
