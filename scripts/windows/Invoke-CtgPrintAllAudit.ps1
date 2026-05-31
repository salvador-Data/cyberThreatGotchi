<#
.SYNOPSIS
  Complete CTG print-all audit — lists print docs and runs preserve stack audit.

.DESCRIPTION
  Enumerates all printable audit markdown under docs\print\ plus legacy IPHONE/WINDOWS sheets.
  Invokes Invoke-CtgPreserveStackAudit.ps1 (DDG BEFORE/AFTER + diagnose batch).
  Writes summary to Backups\logs\ctg-print-all-audit-*.txt (gitignored).

.PARAMETER ApplySafeDefender
  Passed through to Invoke-CtgPreserveStackAudit.ps1.

.PARAMETER SkipWifiDiagnose
  Passed through to Invoke-CtgPreserveStackAudit.ps1.

.PARAMETER SkipStackAudit
  List print paths only; skip diagnose batch.

.PARAMETER OpenPrintFolder
  Open docs\print in Explorer after run.

.EXAMPLE
  cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
  .\scripts\windows\Invoke-CtgPrintAllAudit.ps1

.EXAMPLE
  .\scripts\windows\Invoke-CtgPrintAllAudit.ps1 -OpenPrintFolder
#>
[CmdletBinding()]
param(
    [switch] $ApplySafeDefender,
    [switch] $SkipWifiDiagnose,
    [switch] $SkipStackAudit,
    [switch] $OpenPrintFolder
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-Paths.ps1')
. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')

$Repo = Get-CtgRepoRoot -FromPath $PSScriptRoot
$Docs = Join-Path $Repo 'docs'
$PrintDir = Join-Path $Docs 'print'
$LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

$outFile = Join-Path $LogDir ('ctg-print-all-audit-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$lines = [System.Collections.Generic.List[string]]::new()

function Add-PrintLine {
    param([string] $Message)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    [void]$lines.Add($line)
    Write-Host $line
}

$printDocs = @(
    @{ Rel = 'docs\print\README_PRINT_ALL.md'; Label = 'Master index' }
    @{ Rel = 'docs\print\DUCKDUCKGO_PRESERVE_PRINT.md'; Label = 'DDG preserve' }
    @{ Rel = 'docs\IPHONE_AUDIT_PRINT.md'; Label = 'iPhone audit' }
    @{ Rel = 'docs\WINDOWS_SOC_AUDIT_PRINT.md'; Label = 'Windows SOC audit' }
    @{ Rel = 'docs\print\KALI_LAB_AUDIT_PRINT.md'; Label = 'Kali lab audit' }
    @{ Rel = 'docs\print\MEMORY_PROTECTION_AUDIT_PRINT.md'; Label = 'Memory protection audit' }
    @{ Rel = 'docs\print\UTMS_WIFI_AUDIT_PRINT.md'; Label = 'UTMS Wi-Fi audit' }
    @{ Rel = 'docs\print\LAB_MATURITY_AUDIT_PRINT.md'; Label = 'Lab maturity worksheet' }
    @{ Rel = 'docs\print\VAULT_SECRETS_AUDIT_PRINT.md'; Label = 'Vault secrets audit' }
    @{ Rel = 'docs\print\GITHUB_EMAIL_AUDIT_PRINT.md'; Label = 'GitHub email audit' }
    @{ Rel = 'docs\print\PRINT_ALL_COMBINED.md'; Label = 'Combined markdown print' }
    @{ Rel = 'docs\print\PRINT_ALL.html'; Label = 'Combined HTML print' }
)

Add-PrintLine '=== CTG Print-All Audit ==='
Add-PrintLine ('Repo: {0}' -f $Repo)
Add-PrintLine ('Computer: {0} User: {1} Admin: {2}' -f $env:COMPUTERNAME, $env:USERNAME, (Test-CtgIsAdmin))
Add-PrintLine 'Policy: preserve DuckDuckGo VPN/DNS/Password Manager on all network/mobile sheets'
Add-PrintLine ''

Add-PrintLine '=== Printable documents ==='
$resolvedPaths = [System.Collections.Generic.List[string]]::new()
foreach ($doc in $printDocs) {
    $full = Join-Path $Repo $doc.Rel
    $exists = Test-Path $full
    Add-PrintLine ('  [{0}] {1} — {2}' -f $(if ($exists) { 'OK' } else { 'MISSING' }), $doc.Rel, $doc.Label)
    if ($exists) { [void]$resolvedPaths.Add($full) }
}

Add-PrintLine ''
Add-PrintLine '=== Print instructions ==='
Add-PrintLine '  1. Read docs\print\DUCKDUCKGO_PRESERVE_PRINT.md first'
Add-PrintLine '  2. Run this script (stack audit) on Windows SOC'
Add-PrintLine '  3. Print individual .md sheets OR docs\print\PRINT_ALL.html in browser'
Add-PrintLine '  4. Complete iPhone + Kali sections manually on device'
Add-PrintLine ''

$stackResult = $null
if (-not $SkipStackAudit) {
    Add-PrintLine '=== Stack audit (Invoke-CtgPreserveStackAudit) ==='
    $stackScript = Join-Path $PSScriptRoot 'Invoke-CtgPreserveStackAudit.ps1'
    if (-not (Test-Path $stackScript)) {
        Add-PrintLine '  ERROR: Invoke-CtgPreserveStackAudit.ps1 not found'
    } else {
        $stackSplat = @{}
        if ($ApplySafeDefender) { $stackSplat['ApplySafeDefender'] = $true }
        if ($SkipWifiDiagnose) { $stackSplat['SkipWifiDiagnose'] = $true }
        try {
            $stackResult = & $stackScript @stackSplat
            if ($stackResult.LogFile) {
                Add-PrintLine ('  Stack log: {0}' -f $stackResult.LogFile)
            }
            if ($null -ne $stackResult.DdgTunnelUnchanged) {
                Add-PrintLine ('  DDG tunnel unchanged: {0}' -f $stackResult.DdgTunnelUnchanged)
            }
        } catch {
            Add-PrintLine ('  Stack audit ERROR: {0}' -f $_.Exception.Message)
        }
    }
} else {
    Add-PrintLine '=== Stack audit SKIPPED (-SkipStackAudit) ==='
}

Add-PrintLine ''
Add-PrintLine '=== SUMMARY ==='
Add-PrintLine ('  Print docs found: {0}/{1}' -f $resolvedPaths.Count, $printDocs.Count)
Add-PrintLine ('  Print folder: {0}' -f $PrintDir)
Add-PrintLine ('  Log: {0}' -f $outFile)
Add-PrintLine '=== END ==='

$lines | Set-Content -Path $outFile -Encoding UTF8

if ($OpenPrintFolder -and (Test-Path $PrintDir)) {
    Start-Process explorer.exe $PrintDir
}

Write-Output @{
    LogFile            = $outFile
    PrintFolder        = $PrintDir
    PrintDocPaths      = @($resolvedPaths)
    PrintDocCount      = $resolvedPaths.Count
    StackAuditResult   = $stackResult
    DdgTunnelUnchanged = if ($stackResult) { $stackResult.DdgTunnelUnchanged } else { $null }
    Admin              = (Test-CtgIsAdmin)
}
