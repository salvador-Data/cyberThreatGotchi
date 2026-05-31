<#
.SYNOPSIS
  DuckDuckGo-preserving stack audit â€” diagnose key CTG Windows SOC scripts.

.DESCRIPTION
  Runs Preserve-DuckDuckGoVpn before and after a batch of -DiagnoseOnly scripts.
  Writes a printable summary to Backups\logs\ctg-stack-audit-*.txt (gitignored).
  Does NOT run Repair-WindowsWifi -ApplyFixes or change Wi-Fi DNS.

.PARAMETER ApplySafeDefender
  After diagnose, run Harden-CtgWindowsDefender.ps1 -ApplySafe if Admin.

.PARAMETER SkipWifiDiagnose
  Skip Repair-WindowsWifi.ps1 -DiagnoseOnly (faster; DDG preserve still runs).

.EXAMPLE
  cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
  .\scripts\windows\Invoke-CtgPreserveStackAudit.ps1

.EXAMPLE
  .\scripts\windows\Invoke-CtgPreserveStackAudit.ps1 -ApplySafeDefender
#>
[CmdletBinding()]
param(
    [switch] $ApplySafeDefender,
    [switch] $SkipWifiDiagnose
)
. (Join-Path $PSScriptRoot 'CTG-ShellFast.ps1')

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-Paths.ps1')
. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')

$Repo = Get-CtgRepoRoot -FromPath $PSScriptRoot
$Win = Join-Path $Repo 'scripts\windows'
$script:CtgPreserveScriptLoaded = $false
$script:CtgPreserveScriptPath = Join-Path $Win 'Preserve-DuckDuckGoVpn.ps1'
if (Test-Path $script:CtgPreserveScriptPath) {
    . $script:CtgPreserveScriptPath
    $script:CtgPreserveScriptLoaded = $true
}
$LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$outFile = Join-Path $LogDir ('ctg-stack-audit-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$lines = [System.Collections.Generic.List[string]]::new()

function Add-StackLine {
    param([string] $Message)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    [void]$lines.Add($line)
    Write-Host $line
}

function Get-CtgDdgSnapshot {
    $snap = [ordered]@{
        VpnInstalled = $false
        TunnelUp     = $false
        Processes    = @()
    }
    $preserveScript = Join-Path $Win 'Preserve-DuckDuckGoVpn.ps1'
    if (Test-Path $preserveScript) {
        . $preserveScript
        $paths = Get-CtgDuckDuckGoVpnPaths
        $snap.VpnInstalled = $paths.Count -gt 0
        $snap.TunnelUp = Test-CtgDuckDuckGoVpnConnected
    }
    $procs = Get-Process -Name 'DuckDuckGo.VPN', 'DuckDuckGo.VPN.WireGuard' -ErrorAction SilentlyContinue
    if ($procs) {
        $snap.Processes = @($procs | Select-Object -ExpandProperty Name -Unique)
    }
    return $snap
}

function Write-CtgDdgSnapshot {
    param([string] $Label, [hashtable] $Snap)
    Add-StackLine "=== DDG $Label ==="
    Add-StackLine ('  Installed: {0} | TunnelUp: {1}' -f $Snap.VpnInstalled, $Snap.TunnelUp)
    if ($Snap.Processes.Count -gt 0) {
        Add-StackLine ('  Processes: {0}' -f ($Snap.Processes -join ', '))
    } else {
        Add-StackLine '  Processes: (none detected)'
    }
}

function Invoke-CtgStackScript {
    param(
        [string] $Name,
        [string] $RelativePath,
        [string[]] $Arguments = @('-DiagnoseOnly')
    )
    $scriptPath = Join-Path $Win $RelativePath
    Add-StackLine "=== $Name ==="
    if (-not (Test-Path $scriptPath)) {
        Add-StackLine ('  SKIP -- missing: {0}' -f $RelativePath)
        return
    }
    Add-StackLine ('  Command: .\scripts\windows\{0} {1}' -f $RelativePath, ($Arguments -join ' '))
    try {
        $splat = @{ DiagnoseOnly = $true }
        if ($Arguments -contains '-ApplySafe') {
            $splat = @{ ApplySafe = $true }
        }
        $output = & $scriptPath @splat 2>&1
        foreach ($row in @($output)) {
            $text = $row.ToString().Trim()
            if ($text) { Add-StackLine "  $text" }
        }
        Add-StackLine ('  Exit: {0}' -f $LASTEXITCODE)
    } catch {
        Add-StackLine ('  ERROR: {0}' -f $_.Exception.Message)
    }
}

Add-StackLine '=== CTG Preserve Stack Audit ==='
Add-StackLine ('Repo: {0}' -f $Repo)
Add-StackLine ('Computer: {0} User: {1} Admin: {2}' -f $env:COMPUTERNAME, $env:USERNAME, (Test-CtgIsAdmin))
Add-StackLine 'Policy: preserve DuckDuckGo VPN/DNS -- no competing VPN installs'
Add-StackLine ''

$before = Get-CtgDdgSnapshot
Write-CtgDdgSnapshot -Label 'BEFORE' -Snap $before

$preserveScript = Join-Path $Win 'Preserve-DuckDuckGoVpn.ps1'
if (Test-Path $preserveScript) {
    Add-StackLine '=== Preserve-DuckDuckGoVpn ==='
    . $preserveScript
    Invoke-CtgPreserveDuckDuckGoVpn -LogAction { param($m) Add-StackLine "  $m" }
}

if (-not $SkipWifiDiagnose) {
    Invoke-CtgStackScript -Name 'Wi-Fi diagnose (DDG-safe)' -RelativePath 'Repair-WindowsWifi.ps1' -Arguments @('-DiagnoseOnly')
}

Invoke-CtgStackScript -Name 'Defender EDR' -RelativePath 'Harden-CtgWindowsDefender.ps1'
Invoke-CtgStackScript -Name 'Memory protection' -RelativePath 'Enforce-CtgMemoryProtection.ps1'
Invoke-CtgStackScript -Name 'DDoS / rogue Wi-Fi' -RelativePath 'Harden-DDoSRogueWifi.ps1'
Invoke-CtgStackScript -Name 'Wi-Fi jam detect' -RelativePath 'Detect-CtgWifiJam.ps1'
Invoke-CtgStackScript -Name 'Email vault' -RelativePath 'Initialize-CtgEmailVault.ps1'
Invoke-CtgStackScript -Name 'Lab VLAN segment' -RelativePath 'Test-CtgLabNetworkSegment.ps1'

if ($ApplySafeDefender) {
    Add-StackLine '=== Defender ApplySafe (requested) ==='
    if (-not (Test-CtgIsAdmin)) {
        Add-StackLine '  SKIP -- Admin required for -ApplySafeDefender'
    } else {
        Invoke-CtgStackScript -Name 'Defender ApplySafe' -RelativePath 'Harden-CtgWindowsDefender.ps1' -Arguments @('-ApplySafe')
    }
}

$after = Get-CtgDdgSnapshot
Write-CtgDdgSnapshot -Label 'AFTER' -Snap $after

$unchanged = ($before.VpnInstalled -eq $after.VpnInstalled) -and ($before.TunnelUp -eq $after.TunnelUp)
Add-StackLine '=== SUMMARY ==='
Add-StackLine ('  DDG tunnel state unchanged: {0}' -f $unchanged)
Add-StackLine '  Printable docs: docs\print\README_PRINT_ALL.md (full bundle)'
Add-StackLine '  Run: .\scripts\windows\Invoke-CtgPrintAllAudit.ps1 -OpenPrintFolder'
Add-StackLine ('  Log: {0}' -f $outFile)
Add-StackLine '=== END ==='

$lines | Set-Content -Path $outFile -Encoding UTF8

Write-Output @{
    LogFile           = $outFile
    DdgBefore         = $before
    DdgAfter          = $after
    DdgTunnelUnchanged = $unchanged
    Admin             = (Test-CtgIsAdmin)
}
