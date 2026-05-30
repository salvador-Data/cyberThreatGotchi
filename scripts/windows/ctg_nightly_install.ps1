<#
Windows laptop automation only — does not flash or schedule anything on M5 Cardputer.

.SYNOPSIS
  One-shot installer: register HackerPlanet-CTG-Nightly-4AM scheduled task (run as Admin).

.DESCRIPTION
  Registers a Windows Scheduled Task on Andy's laptop only. Does NOT touch COM13,
  PlatformIO, or M5Stack Cardputer flash/upload workflows.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\ctg_nightly_install.ps1
#>
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$register = Join-Path $PSScriptRoot 'Register-CtgNightlyTask.ps1'
if (-not (Test-Path $register)) {
    Write-Error "Missing: $register"
    exit 1
}

Write-Host '=== CTG Nightly 4 AM installer ==='
Write-Host 'Windows laptop automation only — does not flash or schedule anything on M5 Cardputer.'
& $register
if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { exit $LASTEXITCODE }
Write-Host ''
Write-Host 'Done. Logs:'
Write-Host "  $(Join-Path $env:USERPROFILE 'Backups\logs\nightly-YYYY-MM-DD.log')"
Write-Host "  $(Join-Path ([Environment]::GetFolderPath('Desktop')) 'ctg-soc-run-log.txt')"
Write-Host '  D:\Backups\logs\ (when SSD online)'
