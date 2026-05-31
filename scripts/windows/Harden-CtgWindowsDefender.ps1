# Defender EDR baseline — Admin required only for -ApplySafe
<#
.SYNOPSIS
  Harden Microsoft Defender for CTG lab endpoint detection (EDR baseline).

.DESCRIPTION
  -DiagnoseOnly: Defender status, ASR rules, cloud protection, PUA, MAPS (no changes).
  -ApplySafe: enable cloud-delivered protection, PUA block, ASR audit mode (log before block).
  Commercial EDR options documented in docs/LAB_MATURITY.md — this script stays on built-in Defender.

.PARAMETER DiagnoseOnly
  Report posture only.

.PARAMETER ApplySafe
  Apply reversible Defender hardening (ASR audit, cloud, PUA).

.PARAMETER EnforceASR
  With -ApplySafe, set selected ASR rules to Block mode (after audit review).

.EXAMPLE
  .\scripts\windows\Harden-CtgWindowsDefender.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Harden-CtgWindowsDefender.ps1 -ApplySafe
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch] $DiagnoseOnly,
    [switch] $ApplySafe,
    [switch] $EnforceASR
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')

$LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
$LogFile = Join-Path $LogDir 'harden-ctg-windows-defender.log'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-CtgDefenderLog {
    param([string] $Message, [string] $Color = 'Gray')
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Host $line -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

$AsrRuleGuids = @(
    '75668C1F-73B5-4CF0-BB93-3EC8755A2549',
    'D4F940AB-401B-4EFC-AADC-AD5F3C50688A',
    '3B576869-A4EC-4529-8536-B80A7769E899',
    'BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550',
    '92E97FA1-2EDF-4476-ADD1-48D-040B96905',
    '5BEB7EFE-FD9A-4BAC-8DDF-00C0DFB4E5C5',
    'D3E037E1-3EB8-44C8-A917-57927947596D',
    '01443614-cd74-433a-b99e-2ecdc07bfc25',
    'c1db55a4-8369-4edb-b408-8f1a984424e7',
    '9e6e4bc8-54e7-4cdc-8df4-9756b05fb53',
    'e6db77e5-3df2-4cf1-b95a-63697935e238'
)

function Get-CtgDefenderReport {
    $report = [ordered]@{}
    $mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if (-not $mp) {
        $report['Status'] = 'Defender cmdlet unavailable — is Defender enabled?'
        return $report
    }
    $report['AntivirusEnabled'] = $mp.AntivirusEnabled
    $report['RealTimeProtectionEnabled'] = $mp.RealTimeProtectionEnabled
    $report['AntispywareEnabled'] = $mp.AntispywareEnabled
    $report['IoavProtectionEnabled'] = $mp.IoavProtectionEnabled
    $report['OnAccessProtectionEnabled'] = $mp.OnAccessProtectionEnabled
    $report['BehaviorMonitorEnabled'] = $mp.BehaviorMonitorEnabled
    $report['NISEnabled'] = $mp.NISEnabled
    $report['AMServiceEnabled'] = $mp.AMServiceEnabled
    $report['QuickScanAge'] = $mp.QuickScanAge
    $report['FullScanAge'] = $mp.FullScanAge

    $pref = Get-MpPreference -ErrorAction SilentlyContinue
    if ($pref) {
        $report['MAPSReporting'] = $pref.MAPSReporting
        $report['SubmitSamplesConsent'] = $pref.SubmitSamplesConsent
        $report['PUAProtection'] = $pref.PUAProtection
        $report['CloudBlockLevel'] = $pref.CloudBlockLevel
        $report['CloudExtendedTimeout'] = $pref.CloudExtendedTimeout
        $asrIds = @($pref.AttackSurfaceReductionRules_Ids)
        $asrActs = @($pref.AttackSurfaceReductionRules_Actions)
        $asrSummary = @()
        for ($i = 0; $i -lt [Math]::Min($asrIds.Count, $asrActs.Count); $i++) {
            $asrSummary += "$($asrIds[$i])=$($asrActs[$i])"
        }
        $report['ASRRules'] = ($asrSummary -join '; ')
    }
    return $report
}

function Show-CtgDefenderReport {
    Write-CtgDefenderLog '--- Microsoft Defender EDR baseline ---' 'Cyan'
    $report = Get-CtgDefenderReport
    foreach ($kv in $report.GetEnumerator()) {
        Write-CtgDefenderLog ("  {0}: {1}" -f $kv.Key, $kv.Value)
    }
    Write-CtgDefenderLog 'Commercial EDR: see docs/LAB_MATURITY.md (CrowdStrike, SentinelOne, Microsoft Defender for Endpoint)' 'Gray'
}

function Set-CtgDefenderApplySafe {
    if (-not (Test-CtgIsAdmin)) {
        Write-CtgDefenderLog 'ApplySafe requires Administrator.' 'Red'
        return 1
    }
    if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Apply Defender safe hardening')) {
        return 0
    }
    try {
        Set-MpPreference -MAPSReporting Advanced -ErrorAction Stop
        Write-CtgDefenderLog 'MAPSReporting set to Advanced (cloud-delivered protection).' 'Green'
    } catch {
        Write-CtgDefenderLog "MAPSReporting failed: $($_.Exception.Message)" 'Yellow'
    }
    try {
        Set-MpPreference -PUAProtection Enabled -ErrorAction Stop
        Write-CtgDefenderLog 'PUAProtection enabled.' 'Green'
    } catch {
        Write-CtgDefenderLog "PUAProtection failed: $($_.Exception.Message)" 'Yellow'
    }
    try {
        Set-MpPreference -CloudBlockLevel High -ErrorAction Stop
        Write-CtgDefenderLog 'CloudBlockLevel set to High.' 'Green'
    } catch {
        Write-CtgDefenderLog "CloudBlockLevel failed: $($_.Exception.Message)" 'Yellow'
    }
    $asrAction = if ($EnforceASR) { 'Block' } else { 'AuditMode' }
    try {
        Add-MpPreference -AttackSurfaceReductionRules_Ids $AsrRuleGuids `
            -AttackSurfaceReductionRules_Actions $asrAction -ErrorAction Stop
        Write-CtgDefenderLog "ASR rules set to $asrAction for $($AsrRuleGuids.Count) GUIDs." 'Green'
        if ($asrAction -eq 'AuditMode') {
            Write-CtgDefenderLog 'Review Event Viewer before -EnforceASR Block mode.' 'Yellow'
        }
    } catch {
        Write-CtgDefenderLog "ASR update failed: $($_.Exception.Message)" 'Yellow'
    }
    return 0
}

if (-not $ApplySafe) { $DiagnoseOnly = $true }

Show-CtgDefenderReport

if ($ApplySafe) {
    exit (Set-CtgDefenderApplySafe)
}

Write-CtgDefenderLog 'DiagnoseOnly complete. Run -ApplySafe (Admin) to enable cloud/PUA/ASR audit.' 'Cyan'
exit 0
