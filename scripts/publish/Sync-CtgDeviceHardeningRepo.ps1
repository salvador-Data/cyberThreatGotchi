<#
.SYNOPSIS
  Sync device-hardening docs and scripts to ctg-device-hardening split repo.

.DESCRIPTION
  Copies iPhone, exploit mitigation, CVE feed, and related docs from the monorepo
  into sibling ctg-device-hardening. No .env, Backups/, or PII.

.EXAMPLE
  .\scripts\publish\Sync-CtgDeviceHardeningRepo.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\windows\CTG-Paths.ps1')
$MonoRoot = Get-CtgRepoRoot -FromPath $PSScriptRoot
$DestRepo = Join-Path (Get-CtgProgramsRoot) 'ctg-device-hardening'

function Copy-CtgFile {
    param([string] $Source, [string] $Dest)
    if (-not (Test-Path $Source)) {
        Write-Warning "Missing: $Source"
        return
    }
    $destDir = Split-Path $Dest -Parent
    if (-not (Test-Path $destDir)) {
        if ($PSCmdlet.ShouldProcess($destDir, 'Create directory')) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
    }
    if ($PSCmdlet.ShouldProcess($Dest, 'Copy')) {
        Copy-Item -Path $Source -Destination $Dest -Force
    }
}

Write-Host '=== Sync ctg-device-hardening ===' -ForegroundColor Cyan
Write-Host "Monorepo: $MonoRoot"
Write-Host "Dest:     $DestRepo"

if (-not (Test-Path $DestRepo)) {
    Write-Warning "Clone or create $DestRepo first (gh repo create salvador-Data/ctg-device-hardening)"
}

$files = @(
    @{ S = 'docs\IPHONE_LAPTOP_CONNECTION.md'; D = 'docs\IPHONE_LAPTOP_CONNECTION.md' }
    @{ S = 'docs\IPHONE_TETHER_MONITORING.md'; D = 'docs\IPHONE_TETHER_MONITORING.md' }
    @{ S = 'docs\IPHONE_HARDENING.md'; D = 'docs\IPHONE_HARDENING.md' }
    @{ S = 'docs\IPHONE_AUDIT_PRINT.md'; D = 'docs\IPHONE_AUDIT_PRINT.md' }
    @{ S = 'docs\IPHONE_RUN_NOW.md'; D = 'docs\IPHONE_RUN_NOW.md' }
    @{ S = 'docs\IPHONE_USB_HARDENING.md'; D = 'docs\IPHONE_USB_HARDENING.md' }
    @{ S = 'docs\SIGNAL_ALERTS.md'; D = 'docs\SIGNAL_ALERTS.md' }
    @{ S = 'docs\WINDOWS_SNORT_IDS_SMS.md'; D = 'docs\WINDOWS_SNORT_IDS_SMS.md' }
    @{ S = 'docs\SECURITY_HARDENING.md'; D = 'docs\SECURITY_HARDENING.md' }
    @{ S = 'docs\KALI_RETBLEED_SPECTRE.md'; D = 'docs\KALI_RETBLEED_SPECTRE.md' }
    @{ S = 'docs\RAM_MITIGATION_IPS.md'; D = 'docs\RAM_MITIGATION_IPS.md' }
    @{ S = 'docs\MEMORY_PROTECTION.md'; D = 'docs\MEMORY_PROTECTION.md' }
    @{ S = 'docs\device-hardening\README.md'; D = 'README.md' }
    @{ S = 'scripts\iphone\iphone_tethering_privacy_checklist.ps1'; D = 'scripts\iphone\iphone_tethering_privacy_checklist.ps1' }
    @{ S = 'scripts\windows\Start-CtgIphoneTetherIds.ps1'; D = 'scripts\windows\Start-CtgIphoneTetherIds.ps1' }
    @{ S = 'scripts\kali\ctg-tether-bridge-ids.sh'; D = 'scripts\kali\ctg-tether-bridge-ids.sh' }
    @{ S = 'scripts\windows\Update-CtgExploitMitigations.ps1'; D = 'scripts\windows\Update-CtgExploitMitigations.ps1' }
    @{ S = 'scripts\windows\Enforce-CtgRamMitigations.ps1'; D = 'scripts\windows\Enforce-CtgRamMitigations.ps1' }
    @{ S = 'scripts\windows\Enforce-CtgMemoryProtection.ps1'; D = 'scripts\windows\Enforce-CtgMemoryProtection.ps1' }
    @{ S = 'scripts\windows\Register-CtgRamMitigationTask.ps1'; D = 'scripts\windows\Register-CtgRamMitigationTask.ps1' }
    @{ S = 'scripts\windows\Register-CtgMemoryProtectionTask.ps1'; D = 'scripts\windows\Register-CtgMemoryProtectionTask.ps1' }
    @{ S = 'scripts\windows\Sync-CtgVulnerabilityFeeds.ps1'; D = 'scripts\windows\Sync-CtgVulnerabilityFeeds.ps1' }
    @{ S = 'scripts\windows\Harden-KaliVmCpu.ps1'; D = 'scripts\windows\Harden-KaliVmCpu.ps1' }
    @{ S = 'scripts\kali\ctg-exploit-mitigations-check.sh'; D = 'scripts\kali\ctg-exploit-mitigations-check.sh' }
    @{ S = 'scripts\kali\ctg-ram-mitigation-enforcer.sh'; D = 'scripts\kali\ctg-ram-mitigation-enforcer.sh' }
    @{ S = 'scripts\kali\ctg-retbleed-check.sh'; D = 'scripts\kali\ctg-retbleed-check.sh' }
    @{ S = 'scripts\publish\Set-CtgPrivateRepos.ps1'; D = 'scripts\publish\Set-CtgPrivateRepos.ps1' }
)

foreach ($f in $files) {
    Copy-CtgFile -Source (Join-Path $MonoRoot $f.S) -Dest (Join-Path $DestRepo $f.D)
}

$license = Join-Path $MonoRoot 'LICENSE'
if (Test-Path $license) {
    Copy-CtgFile -Source $license -Dest (Join-Path $DestRepo 'LICENSE')
}

Write-Host 'Sync complete — commit and push ctg-device-hardening separately.' -ForegroundColor Green
