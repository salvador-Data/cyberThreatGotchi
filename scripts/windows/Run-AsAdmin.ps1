<#
.SYNOPSIS
  Re-launch a CTG Windows script elevated (UAC) or run inline if already Administrator.
#>
param(
    [string]$TargetScript = '',
    [string[]]$TargetArguments = @()
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
$isAdmin = Test-CtgIsAdmin
Write-Host "Running as Admin: $isAdmin"
if (-not $TargetScript) {
    $TargetScript = Join-Path $PSScriptRoot 'ctg_soc_run_once.ps1'
}
if (-not (Test-Path -LiteralPath $TargetScript)) {
    Write-Error "Script not found: $TargetScript"
}
if ($isAdmin) {
    if ($TargetArguments.Count -gt 0) {
        & $TargetScript @TargetArguments
    } else {
        & $TargetScript
    }
    if ($null -ne (Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue)) { exit $global:LASTEXITCODE } else { exit 0 }
}
Write-Host ''
Write-Host 'This task needs an elevated PowerShell session.'
Write-Host 'Alternative: Right-click PowerShell -> Run as administrator, then run the command in scripts\windows\ADMIN_STEPS.md'
Write-Host 'Requesting UAC elevation now...'
$argList = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', $TargetScript
) + $TargetArguments
Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList -Wait
if ($null -ne (Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue)) { exit $global:LASTEXITCODE } else { exit 0 }
