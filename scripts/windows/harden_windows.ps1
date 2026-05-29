#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Windows defensive hardening orchestrator (authorized lab / owned hosts only).

.DESCRIPTION
  Does NOT apply changes unless you pass explicit switches. Prompts for a restore point
  before optional hardening steps. Run components individually or via flags.

.PARAMETER InstallSysmon
  Run install_sysmon.ps1 (SwiftOnSecurity config).

.PARAMETER RunHardenWindowsSecurity
  Install and invoke Harden-Windows-Security module (PowerShell Gallery).

.PARAMETER HardenWindowsSecurityAuditOnly
  With -RunHardenWindowsSecurity, prefer audit/report mode when the module supports it.

.PARAMETER CheckWazuhAgent
  Verify Wazuh agent service and manager env vars only (no install).

.PARAMETER SetupWazuhAgent
  Run wazuh_agent_setup.ps1 (requires CTG_WAZUH_MANAGER or WAZUH_MANAGER).

.PARAMETER DefenderASRAudit
  Set common Attack Surface Reduction rules to Audit mode (Defender AV required).

.PARAMETER SkipRestorePoint
  Skip system restore point prompt.

.EXAMPLE
  .\scripts\windows\harden_windows.ps1

.EXAMPLE
  .\scripts\windows\harden_windows.ps1 -InstallSysmon -CheckWazuhAgent

.EXAMPLE
  .\scripts\windows\harden_windows.ps1 -RunHardenWindowsSecurity -DefenderASRAudit
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch] $InstallSysmon,
    [switch] $RunHardenWindowsSecurity,
    [switch] $HardenWindowsSecurityAuditOnly,
    [switch] $CheckWazuhAgent,
    [switch] $SetupWazuhAgent,
    [switch] $DefenderASRAudit,
    [switch] $SkipRestorePoint
)

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot

function Write-Banner {
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ' CyberThreatGotchi — Windows SOC hardening' -ForegroundColor Cyan
    Write-Host ' Authorized defensive use on systems you own' -ForegroundColor Cyan
    Write-Host ' or are explicitly permitted to administer.' -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host " Computer: $env:COMPUTERNAME"
    Write-Host " User:     $env:USERNAME"
    Write-Host " Date:     $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host ''
}

function Invoke-RestorePointPrompt {
    if ($SkipRestorePoint) {
        Write-Host 'Restore point: skipped (-SkipRestorePoint).' -ForegroundColor Gray
        return
    }
    Write-Host 'Recommended: create a System Restore Point before hardening.' -ForegroundColor Yellow
    $r = Read-Host 'Create restore point now? (y/N)'
    if ($r -notmatch '^[Yy]') {
        Write-Host 'Skipped restore point.' -ForegroundColor Gray
        return
    }
    if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Create system restore point')) {
        return
    }
    try {
        Checkpoint-Computer -Description 'CTG-Windows-Hardening' -RestorePointType 'MODIFY_SETTINGS'
        Write-Host 'Restore point created.' -ForegroundColor Green
    } catch {
        Write-Host "Restore point failed (enable System Protection?): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Invoke-SysmonHelper {
    $installer = Join-Path $ScriptDir 'install_sysmon.ps1'
    if (-not (Test-Path $installer)) {
        throw "Missing: $installer"
    }
    Write-Host '--- Sysmon ---' -ForegroundColor Cyan
    & $installer
}

function Invoke-HardenWindowsSecurityModule {
    Write-Host '--- Harden-Windows-Security module ---' -ForegroundColor Cyan
    if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Install/run Harden-Windows-Security')) {
        return
    }
    $repo = Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue
    if (-not $repo) {
        Write-Host 'PSGallery not available. Install module manually:' -ForegroundColor Yellow
        Write-Host '  Install-Module -Name Harden-Windows-Security -Scope CurrentUser'
        return
    }
    if (-not (Get-Module -ListAvailable -Name 'Harden-Windows-Security')) {
        Write-Host 'Installing Harden-Windows-Security from PSGallery...' -ForegroundColor Gray
        Install-Module -Name 'Harden-Windows-Security' -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module 'Harden-Windows-Security' -Force
    $cmd = Get-Command -Name 'Invoke-Hardening' -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Write-Host 'Invoke-Hardening not found. See: https://github.com/Harden-Windows-Security/Module' -ForegroundColor Yellow
        Write-Host '  Get-Command -Module Harden-Windows-Security'
        return
    }
    if ($HardenWindowsSecurityAuditOnly) {
        Write-Host 'Running Invoke-Hardening (audit/report — confirm module parameters in README)...' -ForegroundColor Gray
        try {
            Invoke-Hardening -Mode 'Audit'
        } catch {
            Write-Host 'Audit mode not supported or failed; try full report:' -ForegroundColor Yellow
            Invoke-Hardening
        }
    } else {
        Write-Host 'Running Invoke-Hardening — review changes before applying on production.' -ForegroundColor Yellow
        Invoke-Hardening
    }
}

function Get-WazuhManagerFromEnv {
    foreach ($name in @('CTG_WAZUH_MANAGER', 'WAZUH_MANAGER')) {
        $v = [Environment]::GetEnvironmentVariable($name, 'Process')
        if (-not $v) { $v = [Environment]::GetEnvironmentVariable($name, 'User') }
        if (-not $v) { $v = [Environment]::GetEnvironmentVariable($name, 'Machine') }
        if ($v) { return $v.Trim() }
    }
    return $null
}

function Invoke-WazuhCheck {
    Write-Host '--- Wazuh agent check ---' -ForegroundColor Cyan
    $mgr = Get-WazuhManagerFromEnv
    if ($mgr) {
        Write-Host "Manager env set: $mgr" -ForegroundColor Green
    } else {
        Write-Host 'Manager env not set (CTG_WAZUH_MANAGER / WAZUH_MANAGER).' -ForegroundColor Yellow
    }
    $svc = Get-Service -Name 'WazuhSvc' -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Host "WazuhSvc: $($svc.Status)" -ForegroundColor Green
    } else {
        Write-Host 'WazuhSvc: not installed' -ForegroundColor Yellow
        Write-Host '  Install: .\scripts\windows\wazuh_agent_setup.ps1'
    }
}

function Invoke-WazuhSetup {
    $setup = Join-Path $ScriptDir 'wazuh_agent_setup.ps1'
    if (-not (Test-Path $setup)) {
        throw "Missing: $setup"
    }
    Write-Host '--- Wazuh agent install ---' -ForegroundColor Cyan
    & $setup
}

function Set-DefenderASRAuditMode {
    Write-Host '--- Defender ASR (audit mode) ---' -ForegroundColor Cyan
    if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Set Defender ASR rules to Audit')) {
        return
    }
    $mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if (-not $mp) {
        Write-Host 'Windows Defender status unavailable. Is Defender enabled?' -ForegroundColor Yellow
        return
    }
    # Common ASR rule GUIDs — audit only (log, do not block)
    $valid = @(
        '75668C1F-73B5-4CF0-BB93-3EC8755A2549',
        'D4F940AB-401B-4EFC-AADC-AD5F3C50688A',
        '3B576869-A4EC-4529-8536-B80A7769E899',
        'BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550',
        '92E97FA1-2EDF-4476-ADD1-48D040B96905',
        '5BEB7EFE-FD9A-4BAC-8DDF-00C0DFB4E5C5',
        'D3E037E1-3EB8-44C8-A917-57927947596D',
        '01443614-cd74-433a-b99e-2ecdc07bfc25',
        'c1db55a4-8369-4edb-b408-8f1a984424e7',
        '9e6e4bc8-54e7-4cdc-8df4-c9756b05fb53',
        'e6db77e5-3df2-4cf1-b95a-63697935e238'
    )
    try {
        Add-MpPreference -AttackSurfaceReductionRules_Ids $valid -AttackSurfaceReductionRules_Actions AuditMode
        Write-Host 'ASR rules set to AuditMode for selected GUIDs.' -ForegroundColor Green
        Write-Host 'Review: Get-MpPreference | Select AttackSurfaceReductionRules_Ids, AttackSurfaceReductionRules_Actions'
    } catch {
        Write-Host "ASR audit update failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host 'Ensure Defender is active and you have Administrator rights.'
    }
}

function Show-UsageIfNoFlags {
    $any = $InstallSysmon -or $RunHardenWindowsSecurity -or $CheckWazuhAgent -or $SetupWazuhAgent -or $DefenderASRAudit
    if ($any) { return $false }
    Write-Host 'No action flags passed — guidance only (no hardening applied).' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Suggested order (see scripts/windows/README_WINDOWS_SOC.md):'
    Write-Host '  1. Restore point (prompt below)'
    Write-Host '  2. -InstallSysmon'
    Write-Host '  3. -RunHardenWindowsSecurity [-HardenWindowsSecurityAuditOnly]'
    Write-Host '  4. Set manager IP, then -SetupWazuhAgent or -CheckWazuhAgent'
    Write-Host '  5. -DefenderASRAudit (tune ASR before enforce)'
    Write-Host ''
    Write-Host 'Examples:'
    Write-Host '  .\scripts\windows\harden_windows.ps1 -InstallSysmon'
    Write-Host '  $env:CTG_WAZUH_MANAGER = ''10.0.0.5'''
    Write-Host '  .\scripts\windows\harden_windows.ps1 -SetupWazuhAgent'
    Write-Host ''
    return $true
}

Write-Banner

$guidanceOnly = Show-UsageIfNoFlags

if (-not $guidanceOnly) {
    Invoke-RestorePointPrompt
}

if ($InstallSysmon) { Invoke-SysmonHelper }
if ($RunHardenWindowsSecurity) { Invoke-HardenWindowsSecurityModule }
if ($CheckWazuhAgent) { Invoke-WazuhCheck }
if ($SetupWazuhAgent) { Invoke-WazuhSetup }
if ($DefenderASRAudit) { Set-DefenderASRAuditMode }

if ($guidanceOnly) {
    Invoke-RestorePointPrompt
    Invoke-WazuhCheck
    Write-Host 'Full guide: scripts\windows\README_WINDOWS_SOC.md' -ForegroundColor Cyan
}

Write-Host ''
Write-Host 'Done. No further steps run without explicit flags.' -ForegroundColor Green
Write-Host ''
