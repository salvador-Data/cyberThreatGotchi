<#
.SYNOPSIS
  One CTG orchestrator — install audit, preserve stack, print bundle, memory, Kali stage.

.DESCRIPTION
  Runs the full defensive lab diagnose pipeline in order. Default: -DiagnoseOnly.
  -ApplySafe: pip requirements, stage backups, safe non-Admin applies only.

  Never runs: Repair-WindowsWifi -ApplyFixes without DDG OK, guest-flash loops,
  mitigation disable, or competing VPN installs.

.PARAMETER DiagnoseOnly
  Report only (default).

.PARAMETER ApplySafe
  Enable pip install + Kali staging via install audit; still no Wi-Fi ApplyFixes without DDG.

.PARAMETER OpenPrintFolder
  Open docs\print after print-all step.

.EXAMPLE
  cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
  .\scripts\windows\Invoke-CtgOneWorking.ps1

.EXAMPLE
  .\scripts\windows\Invoke-CtgOneWorking.ps1 -ApplySafe -OpenPrintFolder
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [switch] $ApplySafe,
    [switch] $OpenPrintFolder
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-Paths.ps1')
. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')

if (-not $ApplySafe) { $DiagnoseOnly = $true }

$Repo = Get-CtgRepoRoot -FromPath $PSScriptRoot
$Win = Join-Path $Repo 'scripts\windows'
$LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

$outFile = Join-Path $LogDir ('ctg-one-working-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$lines = [System.Collections.Generic.List[string]]::new()
$summaryItems = [System.Collections.Generic.List[hashtable]]::new()
$ddgOk = $false

function Add-OwLine {
    param([string] $Message)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    [void]$lines.Add($line)
    Write-Host $line
}

function Add-OwStep {
    param(
        [int] $Step,
        [string] $Name,
        [ValidateSet('OK', 'SKIP', 'WARN', 'FAIL')]
        [string] $Result,
        [string] $Detail = ''
    )
    [void]$summaryItems.Add(@{ Step = $Step; Name = $Name; Result = $Result; Detail = $Detail })
    Add-OwLine ('=== Step {0}: {1} [{2}] ===' -f $Step, $Name, $Result)
    if ($Detail) { Add-OwLine "  $Detail" }
}

function Invoke-OwScript {
    param(
        [string] $RelativePath,
        [hashtable] $Splat = @{}
    )
    $scriptPath = Join-Path $Win $RelativePath
    if (-not (Test-Path $scriptPath)) {
        return @{ Ok = $false; Error = "Missing: $RelativePath" }
    }
    try {
        $result = & $scriptPath @Splat 2>&1
        return @{ Ok = $true; Output = @($result); ExitCode = $LASTEXITCODE; Result = $result }
    } catch {
        return @{ Ok = $false; Error = $_.Exception.Message }
    }
}

Add-OwLine '=== CTG One Working Orchestrator ==='
Add-OwLine ('Repo: {0}' -f $Repo)
Add-OwLine ('Mode: {0} | Admin: {1}' -f $(if ($ApplySafe) { 'ApplySafe' } else { 'DiagnoseOnly' }), (Test-CtgIsAdmin))
Add-OwLine 'Policy: preserve DDG VPN/DNS/PM; never disable HVCI/spec-ctrl; no guest-flash loops'
Add-OwLine ''

# Step 1 — DDG preserve + Wi-Fi diagnose only
Add-OwLine '--- Step 1: DDG preserve check ---'
$beforeSnap = @{ VpnInstalled = $false; TunnelUp = $false }
$preserveScript = Join-Path $Win 'Preserve-DuckDuckGoVpn.ps1'
if (Test-Path $preserveScript) {
    . $preserveScript
    $paths = Get-CtgDuckDuckGoVpnPaths
    $beforeSnap.VpnInstalled = $paths.Count -gt 0
    $beforeSnap.TunnelUp = Test-CtgDuckDuckGoVpnConnected
    Invoke-CtgPreserveDuckDuckGoVpn -LogAction { param($m) Add-OwLine "  $m" }
    $ddgOk = $beforeSnap.VpnInstalled
    Add-OwStep -Step 1 -Name 'DDG preserve' -Result $(if ($ddgOk) { 'OK' } else { 'WARN' }) -Detail ("installed={0} tunnel={1}" -f $beforeSnap.VpnInstalled, $beforeSnap.TunnelUp)
} else {
    Add-OwStep -Step 1 -Name 'DDG preserve' -Result 'FAIL' -Detail 'Preserve-DuckDuckGoVpn.ps1 missing'
}

$wifiScript = Join-Path $Win 'Repair-WindowsWifi.ps1'
if (Test-Path $wifiScript) {
    Add-OwLine '  Repair-WindowsWifi.ps1 -DiagnoseOnly (never ApplyFixes here unless DDG OK + Admin)'
    $wifiOut = Invoke-OwScript -RelativePath 'Repair-WindowsWifi.ps1' -Splat @{ DiagnoseOnly = $true }
    if (-not $wifiOut.Ok) {
        Add-OwLine ('  Wi-Fi diagnose ERROR: {0}' -f $wifiOut.Error)
    }
} else {
    Add-OwLine '  SKIP Repair-WindowsWifi.ps1 - missing'
}

if ($ApplySafe -and -not $ddgOk) {
    Add-OwLine '  BLOCKED: Wi-Fi ApplyFixes skipped — DDG preserve not verified'
}

# Step 2 — Install audit
Add-OwLine ''
Add-OwLine '--- Step 2: Install audit ---'
$auditSplat = @{ Json = $true }
if ($ApplySafe) { $auditSplat['ApplySafe'] = $true }
$auditResult = Invoke-OwScript -RelativePath 'Invoke-CtgInstallAudit.ps1' -Splat $auditSplat
if ($auditResult.Ok -and $auditResult.Result -is [hashtable]) {
    $counts = if ($auditResult.Result.Summary) { $auditResult.Result.Summary } elseif ($auditResult.Result.Counts) { $auditResult.Result.Counts } else { @{} }
    Add-OwStep -Step 2 -Name 'Install audit' -Result 'OK' -Detail ('INSTALLED={0} PENDING={1} MANUAL={2}' -f $counts.INSTALLED, $counts.PENDING, $counts.MANUAL)
    if ($auditResult.Result.LogFile) { Add-OwLine ('  Audit log: {0}' -f $auditResult.Result.LogFile) }
} else {
    Add-OwStep -Step 2 -Name 'Install audit' -Result 'FAIL' -Detail ($auditResult.Error)
}
$auditOut = if ($auditResult.Ok -and $auditResult.Result -is [hashtable]) { $auditResult.Result } else { $null }

# Step 3 — Preserve stack audit
Add-OwLine ''
Add-OwLine '--- Step 3: Preserve stack audit ---'
$stackResult = Invoke-OwScript -RelativePath 'Invoke-CtgPreserveStackAudit.ps1'
if ($stackResult.Ok) {
    $unchanged = $null
    if ($stackResult.Result -and $stackResult.Result.DdgTunnelUnchanged -ne $null) {
        $unchanged = $stackResult.Result.DdgTunnelUnchanged
    }
    Add-OwStep -Step 3 -Name 'Preserve stack audit' -Result 'OK' -Detail $(if ($null -ne $unchanged) { "DDG unchanged=$unchanged" } else { 'see stack log' })
    if ($stackResult.Result.LogFile) { Add-OwLine ('  Stack log: {0}' -f $stackResult.Result.LogFile) }
} else {
    Add-OwStep -Step 3 -Name 'Preserve stack audit' -Result 'FAIL' -Detail $stackResult.Error
}

# Step 4 — Print-all (paths only, skip duplicate stack)
Add-OwLine ''
Add-OwLine '--- Step 4: Print-all audit (paths only) ---'
$printSplat = @{ SkipStackAudit = $true }
if ($OpenPrintFolder) { $printSplat['OpenPrintFolder'] = $true }
$printResult = Invoke-OwScript -RelativePath 'Invoke-CtgPrintAllAudit.ps1' -Splat $printSplat
if ($printResult.Ok) {
    $cnt = if ($printResult.Result.PrintDocCount) { $printResult.Result.PrintDocCount } else { '?' }
    Add-OwStep -Step 4 -Name 'Print-all audit' -Result 'OK' -Detail ("print docs: {0}" -f $cnt)
    Add-OwLine '  Bundle: docs\print\PRINT_ALL.html'
} else {
    Add-OwStep -Step 4 -Name 'Print-all audit' -Result 'FAIL' -Detail $printResult.Error
}

# Step 5 — Memory protection diagnose
Add-OwLine ''
Add-OwLine '--- Step 5: Memory protection ---'
$memResult = Invoke-OwScript -RelativePath 'Enforce-CtgMemoryProtection.ps1' -Splat @{ DiagnoseOnly = $true }
Add-OwStep -Step 5 -Name 'Memory protection' -Result $(if ($memResult.Ok) { 'OK' } else { 'FAIL' }) -Detail 'HVCI/VBS/spec-ctrl - do not regress'

# Step 6 — Kali staging
Add-OwLine ''
Add-OwLine '--- Step 6: Kali lab staging ---'
if ($ApplySafe) {
    Add-OwLine '  (ApplySafe already staged via install audit if run; re-run for idempotent sync)'
}
$stageResult = Invoke-OwScript -RelativePath 'Stage-KaliLabToBackups.ps1'
$clickMe = Join-Path $env:USERPROFILE 'Backups\CLICK-ME-RUN-IN-KALI.sh'
Add-OwStep -Step 6 -Name 'Kali staging' -Result $(if ($stageResult.Ok -and (Test-Path $clickMe)) { 'OK' } elseif ($stageResult.Ok) { 'WARN' } else { 'FAIL' }) -Detail $(if (Test-Path $clickMe) { 'CLICK-ME staged' } else { 'CLICK-ME missing after stage' })

# Step 7 — Summary
Add-OwLine ''
Add-OwLine '=== FINAL SUMMARY ==='
Add-OwLine ''
Add-OwLine ('{0,-6} {1,-28} {2,-8} {3}' -f 'STEP', 'COMPONENT', 'RESULT', 'DETAIL')
Add-OwLine ('{0}' -f ('-' * 80))
foreach ($s in $summaryItems) {
    Add-OwLine ('{0,-6} {1,-28} {2,-8} {3}' -f $s.Step, $s.Name, $s.Result, $s.Detail)
}

if ($auditOut) {
    $auditRows = if ($auditOut.Components) { @($auditOut.Components) } elseif ($auditOut.Items) { @($auditOut.Items) } else { @() }
    if ($auditRows.Count -gt 0) {
        Add-OwLine ''
        Add-OwLine '=== INSTALL STATUS (from audit) ==='
        Add-OwLine ('{0,-12} {1}' -f 'STATUS', 'COMPONENT')
        Add-OwLine ('{0}' -f ('-' * 60))
        foreach ($it in $auditRows) {
            $st = if ($it.Status) { $it.Status } else { '' }
            $nm = if ($it.Component) { $it.Component } elseif ($it.Name) { $it.Name } else { '' }
            if ($st -in @('PENDING', 'MANUAL')) {
                Add-OwLine ('{0,-12} {1}' -f $st, $nm)
            }
        }
    }
}

Add-OwLine ''
Add-OwLine '=== MANUAL ONLY (never automated here) ==='
$manualBlock = @(
    'Scheduled tasks - Register-Ctg*.ps1 (Admin UAC)',
    'Ctg-CredentialVault.ps1 -InitVault (interactive master password)',
    'Kali CLICK-ME lab chain (guest GUI login + sudo once)',
    'Defender -ApplySafe (Admin + ASR audit review)',
    'Repair-WindowsWifi -ApplyFixes (Admin; only when Wi-Fi up + DDG OK)',
    'Docker + Wazuh -ApplySafe',
    'Cardputer flash (COM13 detect only unless Andy requests)',
    'Proton Bridge install + email vault titles'
)
foreach ($m in $manualBlock) { Add-OwLine "  - $m" }

Add-OwLine ''
Add-OwLine ('  Log: {0}' -f $outFile)
Add-OwLine '  Docs: docs\CTG_ONE_WORKING.md | Ethics: docs\CYBERSECURITY_ETHICS.md'
Add-OwLine '  Print: docs\print\PRINT_ALL.html'
Add-OwLine '=== END ==='

$lines | Set-Content -Path $outFile -Encoding UTF8

Write-Output @{
    LogFile        = $outFile
    Steps          = @($summaryItems)
    InstallAudit   = $auditOut
    DdgPreserveOk  = $ddgOk
    Admin          = (Test-CtgIsAdmin)
    Mode           = $(if ($ApplySafe) { 'ApplySafe' } else { 'DiagnoseOnly' })
}
