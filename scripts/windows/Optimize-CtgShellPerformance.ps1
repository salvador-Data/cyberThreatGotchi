<#
.SYNOPSIS
  Diagnose and safely optimize PowerShell shell response time for CTG workflows.

.DESCRIPTION
  Does NOT disable Defender, weaken HVCI/VBS, or change DuckDuckGo VPN/DNS policy.
  -DiagnoseOnly (default): profile paths, PS version, transcription, timing hints.
  -ApplySafe: install lightweight profile snippet (ctg function, progress prefs).

.EXAMPLE
  .\scripts\windows\Optimize-CtgShellPerformance.ps1

.EXAMPLE
  .\scripts\windows\Optimize-CtgShellPerformance.ps1 -ApplySafe
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [switch] $ApplySafe
)

if (-not $ApplySafe) { $DiagnoseOnly = $true }

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-Paths.ps1')
. (Join-Path $PSScriptRoot 'CTG-ShellFast.ps1')

$Repo = Get-CtgRepoRoot -FromPath $PSScriptRoot
$LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$outFile = Join-Path $LogDir ('ctg-shell-perf-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$lines = [System.Collections.Generic.List[string]]::new()

function Add-SpLine {
    param([string] $Message)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    [void]$lines.Add($line)
    Write-Host $line
}

function Get-CtgShellTranscriptionState {
    $paths = @(
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription',
        'HKCU:\SOFTWARE\Policies\Microsoft\PowerShell\Transcription'
    )
    $enabled = $false
    $detail = @()
    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { continue }
        $props = Get-ItemProperty -Path $p -ErrorAction SilentlyContinue
        if ($props.EnableTranscripting -eq 1) {
            $enabled = $true
            $detail += "$p EnableTranscripting=1"
        }
        if ($props.EnableInvocationHeader -eq 1) {
            $detail += "$p EnableInvocationHeader=1"
        }
    }
    return @{ Enabled = $enabled; Detail = ($detail -join '; ') }
}

Add-SpLine '=== CTG Shell Performance ==='
Add-SpLine ('Repo: {0}' -f $Repo)
Add-SpLine ('Mode: {0}' -f $(if ($ApplySafe) { 'ApplySafe' } else { 'DiagnoseOnly' }))
Add-SpLine ''

# PowerShell versions
$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
$ps51Path = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
Add-SpLine '--- PowerShell versions ---'
Add-SpLine ('  Current host: {0} {1}' -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition)
Add-SpLine ('  pwsh 7: {0}' -f $(if ($pwshPath) { $pwshPath } else { '(not on PATH)' }))
Add-SpLine ('  Windows PowerShell 5.1: {0}' -f $ps51Path)
Add-SpLine '  Recommendation: set Windows Terminal default profile to PowerShell 7 (pwsh) for faster startup and CTG scripts.'
Add-SpLine '  (This script does not change system default terminal.)'
Add-SpLine ''

# Execution policy
Add-SpLine '--- Execution policy ---'
Get-ExecutionPolicy -List | ForEach-Object {
    Add-SpLine ('  {0,-14} {1}' -f $_.Scope, $_.ExecutionPolicy)
}
Add-SpLine ''

# Profiles
Add-SpLine '--- Profile paths ---'
$profileTargets = @(
    @{ Label = 'CurrentUserCurrentHost'; Path = $PROFILE },
    @{ Label = 'CurrentUserAllHosts'; Path = $PROFILE.CurrentUserAllHosts },
    @{ Label = 'AllUsersAllHosts'; Path = $PROFILE.AllUsersAllHosts }
)
foreach ($t in $profileTargets) {
    $exists = Test-Path -LiteralPath $t.Path
    Add-SpLine ('  {0}: {1} (exists={2})' -f $t.Label, $t.Path, $exists)
    if ($exists) {
        $ms = (Measure-Command { . $t.Path 2>$null }).TotalMilliseconds
        Add-SpLine ('    dot-source load: {0:N0} ms' -f $ms)
    }
}
Add-SpLine ''

# Module autoload
Add-SpLine '--- Module autoload ---'
Add-SpLine ('  PSModuleAutoLoadingPreference: {0}' -f $PSModuleAutoLoadingPreference)
Add-SpLine ('  CTG heavy-module skip list: {0}' -f ($script:CtgShellHeavyModuleSkip -join ', '))
Add-SpLine '  Tip: avoid Import-Module Az/Graph in CTG orchestrators; use dedicated admin sessions.'
Add-SpLine ''

# Transcription
$tx = Get-CtgShellTranscriptionState
Add-SpLine '--- PowerShell transcription (GPO) ---'
Add-SpLine ('  Enabled: {0}' -f $tx.Enabled)
if ($tx.Detail) { Add-SpLine ('  Detail: {0}' -f $tx.Detail) }
if ($tx.Enabled) {
    Add-SpLine '  If shell feels slow, review Group Policy transcription output path and retention (diagnose only — not disabled here).'
}
Add-SpLine ''

# Defender note
Add-SpLine '--- Antivirus ---'
Add-SpLine '  Windows Defender real-time scan may add cold-start latency on scripts\windows\*.ps1 (expected; do not disable).'
Add-SpLine ''

# CTG script timing sample
Add-SpLine '--- CTG cold-start sample (Measure-Command) ---'
$auditScript = Join-Path $PSScriptRoot 'Invoke-CtgInstallAudit.ps1'
if (Test-Path $auditScript) {
    $sec = (Measure-Command { & $auditScript -Json 2>&1 | Out-Null }).TotalSeconds
    Add-SpLine ('  Invoke-CtgInstallAudit.ps1 -Json: {0:N2}s' -f $sec)
}
$oneScript = Join-Path $PSScriptRoot 'Invoke-CtgOneWorking.ps1'
if (Test-Path $oneScript) {
    $secOw = (Measure-Command { & $oneScript -DiagnoseOnly 2>&1 | Out-Null }).TotalSeconds
    Add-SpLine ('  Invoke-CtgOneWorking.ps1 -DiagnoseOnly: {0:N2}s' -f $secOw)
}
Add-SpLine ''

Add-SpLine '--- Quick wins ---'
Add-SpLine '  1. Use pwsh 7 as default terminal profile.'
Add-SpLine '  2. Run -ApplySafe once to add ctg-shell-fast.ps1 to your profile.'
Add-SpLine '  3. Prefer Invoke-CtgOneWorking.ps1 -DiagnoseOnly over re-running full stack twice.'
Add-SpLine '  4. See docs/SHELL_PERFORMANCE.md'
Add-SpLine ''

if ($ApplySafe) {
    Add-SpLine '--- ApplySafe ---'
    $snippet = Join-Path $PSScriptRoot 'profile.d\ctg-shell-fast.ps1'
    if (-not (Test-Path $snippet)) {
        Add-SpLine "  SKIP — missing $snippet"
    } else {
        $profilePath = $PROFILE
        $profileDir = Split-Path -Parent $profilePath
        if (-not (Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
            Add-SpLine "  Created profile directory: $profileDir"
        }
        $marker = '# CTG shell fast (Optimize-CtgShellPerformance.ps1)'
        $sourceLine = ". '$snippet'"
        if (-not (Test-Path $profilePath)) {
            @(
                $marker,
                $sourceLine
            ) | Set-Content -Path $profilePath -Encoding UTF8
            Add-SpLine "  Created profile: $profilePath"
        } elseif (-not (Select-String -LiteralPath $profilePath -Pattern 'ctg-shell-fast\.ps1' -Quiet)) {
            Add-Content -Path $profilePath -Value "`n$marker`n$sourceLine"
            Add-SpLine "  Appended CTG snippet to profile: $profilePath"
        } else {
            Add-SpLine '  Profile already sources ctg-shell-fast.ps1 — no change.'
        }
    }
}

Add-SpLine ('Log: {0}' -f $outFile)
Add-SpLine '=== END ==='
$lines | Set-Content -Path $outFile -Encoding UTF8

Write-Output @{
    LogFile   = $outFile
    Mode      = $(if ($ApplySafe) { 'ApplySafe' } else { 'DiagnoseOnly' })
    PwshPath  = $pwshPath
    Profile   = $PROFILE
    Transcription = $tx
}
