<#
.SYNOPSIS
  CIS Windows benchmark subset — read-only diagnose (no enforcement).

.DESCRIPTION
  Maps a small CIS-aligned checklist to CTG lab maturity scoring.
  Full CIS-CAT requires licensed tooling — this script is a free posture snapshot.

.EXAMPLE
  .\scripts\windows\Test-CtgCisBenchmarkDiagnose.ps1 -DiagnoseOnly
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')

$LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
$LogFile = Join-Path $LogDir 'test-ctg-cis-benchmark.log'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-CisLog {
    param([string] $Check, [string] $Status, [string] $Detail = '')
    $line = "[$(Get-Date -Format 'HH:mm:ss')] [$Status] $Check $(if ($Detail) { "- $Detail" })"
    $color = switch ($Status) { 'PASS' { 'Green' } 'WARN' { 'Yellow' } default { 'Gray' } }
    Write-Host $line -ForegroundColor $color
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

Write-CisLog 'CIS benchmark diagnose' 'INFO' 'subset only — see docs/LAB_MATURITY.md'

# 1.1 — Ensure Windows Firewall enabled (all profiles)
foreach ($prof in @('Domain', 'Private', 'Public')) {
    $fw = Get-NetFirewallProfile -Name $prof -ErrorAction SilentlyContinue
    if ($fw -and $fw.Enabled) {
        Write-CisLog "Firewall $prof enabled" 'PASS'
    } else {
        Write-CisLog "Firewall $prof enabled" 'WARN' 'profile disabled or unavailable'
    }
}

# 2.x — UAC
try {
    $uac = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction Stop
    if ([int]$uac.EnableLUA -eq 1) {
        Write-CisLog 'UAC EnableLUA' 'PASS'
    } else {
        Write-CisLog 'UAC EnableLUA' 'WARN' 'disabled'
    }
} catch {
    Write-CisLog 'UAC registry' 'WARN' $_.Exception.Message
}

# 18.x — Defender real-time
$mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
if ($mp -and $mp.RealTimeProtectionEnabled) {
    Write-CisLog 'Defender real-time protection' 'PASS'
} else {
    Write-CisLog 'Defender real-time protection' 'WARN'
}

# 18.x — ASR configured
$pref = Get-MpPreference -ErrorAction SilentlyContinue
if ($pref -and $pref.AttackSurfaceReductionRules_Ids) {
    Write-CisLog 'Defender ASR rules present' 'PASS' ($pref.AttackSurfaceReductionRules_Ids.Count.ToString() + ' rules')
} else {
    Write-CisLog 'Defender ASR rules present' 'WARN' 'run Harden-CtgWindowsDefender.ps1 -ApplySafe'
}

# 2.3 — Guest account
$guest = Get-LocalUser -Name 'Guest' -ErrorAction SilentlyContinue
if ($guest -and $guest.Enabled) {
    Write-CisLog 'Guest account disabled' 'WARN' 'Guest enabled'
} else {
    Write-CisLog 'Guest account disabled' 'PASS'
}

# BitLocker (CIS 18.9.x mobile/workstation)
if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
    $os = Get-BitLockerVolume -MountPoint 'C:' -ErrorAction SilentlyContinue
    if ($os -and $os.ProtectionStatus -eq 'On') {
        Write-CisLog 'BitLocker C: protection' 'PASS'
    } else {
        Write-CisLog 'BitLocker C: protection' 'WARN'
    }
} else {
    Write-CisLog 'BitLocker C: protection' 'WARN' 'cmdlet unavailable'
}

Write-CisLog 'DiagnoseOnly complete' 'INFO' $LogFile
exit 0
