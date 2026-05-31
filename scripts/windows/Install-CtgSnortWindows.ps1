<#
.SYNOPSIS
  Install and configure Snort 2.9.x IDS on Windows 11 Pro (detect-only, CTG lab).

.DESCRIPTION
  Snort 3 has no official Windows build - this stack targets Snort 2.9 Windows + Npcap.
  Rules and config live under Backups\ctg-snort\ (never commit secrets).
  Primary perimeter IPS remains OPNsense Suricata; Kali runs Suricata-primary passive IDS.

.PARAMETER DiagnoseOnly
  Check Win11 Pro, Npcap, admin, Snort binary, CTG paths - no install.

.PARAMETER InstallViaChocolatey
  Attempt choco install snort when binary missing (legacy 2.9.14 package).

.PARAMETER WhatIf
  Show planned actions without installing.

.EXAMPLE
  .\scripts\windows\Install-CtgSnortWindows.ps1 -DiagnoseOnly
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [switch] $InstallViaChocolatey,
    [switch] $WhatIf
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
. (Join-Path $PSScriptRoot 'CTG-SnortCommon.ps1')

$repo = Get-CtgRepoRoot
Import-CtgDotEnv -EnvPath (Join-Path $repo '.env')
$paths = Get-CtgSnortPaths
$isAdmin = Test-CtgIsAdmin
$win = Test-CtgWin11Pro
$npcap = Test-CtgNpcapInstalled
$snort = Get-CtgSnortBinary
$snortInstall = if ($snort) { Split-Path (Split-Path $snort -Parent) -Parent } else { 'C:\Snort' }

function Write-InstallLog {
    param([string] $Message, [string] $Color = 'Gray')
    Write-CtgSnortLog $Message $paths.IdsLog $Color
}

function Invoke-CtgSnortDiagnose {
    $ok = $true
    Write-InstallLog '--- Install-CtgSnortWindows DiagnoseOnly ---' 'Cyan'
    Write-InstallLog "OS: $($win.Caption) build $($win.Build) Win11=$($win.IsWin11) Pro=$($win.IsPro)"
    if (-not $win.Ok) {
        Write-InstallLog 'WARN: Snort Windows stack expects Windows 11 Pro/Enterprise (lab SOC host)' 'Yellow'
    }
    Write-InstallLog "Administrator: $isAdmin"
    if (-not $isAdmin) {
        Write-InstallLog 'WARN: Snort live capture requires elevated PowerShell' 'Yellow'
    }
    Write-InstallLog "Npcap: $(if ($npcap) { 'installed' } else { 'MISSING - run Install-WiresharkNpcap.ps1 or install from https://npcap.com' })"
    if (-not $npcap) { $ok = $false }
    if ($snort) {
        Write-InstallLog "Snort binary: $snort"
        $ver = Get-CtgSnortVersion -SnortPath $snort
        if ($ver) { Write-InstallLog "Snort version: $ver" }
    } else {
        Write-InstallLog 'Snort: NOT installed - download Snort 2.9.x Windows installer from https://www.snort.org/downloads' 'Red'
        Write-InstallLog '  Optional: -InstallViaChocolatey (legacy choco package 2.9.14.1)' 'Yellow'
        Write-InstallLog '  Fallback: Start-CtgSnortIDS.ps1 -UseWiresharkFallback uses tshark heuristics' 'Yellow'
        $ok = $false
    }
    Write-InstallLog "CTG snort root: $($paths.SnortRoot)"
    Write-InstallLog "CTG config: $($paths.ConfFile)"
    Write-InstallLog "CTG alert log: $($paths.AlertLog)"
    $twilioOk = @(
        $env:TWILIO_ACCOUNT_SID, $env:TWILIO_AUTH_TOKEN,
        $env:TWILIO_FROM_NUMBER, $env:CTG_ALERT_SMS_TO
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($twilioOk.Count -eq 4) {
        Write-InstallLog 'Twilio SMS: env configured (Send-CtgSmsAlert.ps1 -TestMessage)'
    } else {
        Write-InstallLog 'Twilio SMS: not fully configured - set vars in local .env'
    }
    Write-InstallLog "DiagnoseOnly result: $(if ($ok) { 'PASS' } else { 'FAIL - see manual steps in docs/WINDOWS_SNORT_IDS_SMS.md' })"
    return $ok
}

function Copy-CtgSnortRulesFromInstall {
    $srcRules = Join-Path $snortInstall 'rules'
    if (-not (Test-Path $srcRules)) { return }
    Write-InstallLog "Copying rules from $srcRules -> $($paths.RulesDir)"
    Get-ChildItem -Path $srcRules -Filter '*.rules' -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination (Join-Path $paths.RulesDir $_.Name) -Force
    }
    foreach ($name in @('community.rules', 'snort.rules')) {
        $src = Join-Path $srcRules $name
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination (Join-Path $paths.RulesDir $name) -Force
        }
    }
}

function Deploy-CtgSnortConfig {
    Ensure-CtgSnortLayout -Paths $paths
    $conf = New-CtgSnortConfContent -RulesDir $paths.RulesDir -LogDir $paths.LogsDir -SnortInstallDir $snortInstall
    if ($WhatIf) {
        Write-InstallLog '[WhatIf] Would write snort.conf to $($paths.ConfFile)'
        return
    }
    Set-Content -Path $paths.ConfFile -Value $conf -Encoding utf8
    Write-InstallLog "Deployed CTG snort.conf -> $($paths.ConfFile)" 'Green'
    Copy-CtgSnortRulesFromInstall
}

function Install-CtgSnortChocolatey {
    $choco = Get-Command choco -ErrorAction SilentlyContinue
    if (-not $choco) {
        Write-InstallLog 'Chocolatey not found - install Snort manually from snort.org' 'Yellow'
        return $false
    }
    if ($WhatIf) {
        Write-InstallLog '[WhatIf] choco install snort -y'
        return $true
    }
    Write-InstallLog 'Installing Snort via Chocolatey (legacy 2.9.14.1 package)...' 'Cyan'
    & choco install snort -y
    return ($LASTEXITCODE -eq 0)
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ' CTG Snort Windows Install (detect-only)' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan

if ($DiagnoseOnly) {
    $result = Invoke-CtgSnortDiagnose
    exit $(if ($result) { 0 } else { 1 })
}

Ensure-CtgSnortLayout -Paths $paths

if (-not $npcap) {
    $npcapScript = Join-Path $PSScriptRoot 'Install-WiresharkNpcap.ps1'
    Write-InstallLog 'Npcap required - install Wireshark/Npcap first:' 'Yellow'
    Write-InstallLog "  $npcapScript"
    if (-not $WhatIf -and (Test-Path $npcapScript)) {
        Write-InstallLog 'Attempting Wireshark/Npcap install via winget/choco...' 'Cyan'
        & powershell -NoProfile -ExecutionPolicy Bypass -File $npcapScript
        $npcap = Test-CtgNpcapInstalled
    }
}

if (-not $snort -and $InstallViaChocolatey) {
    Install-CtgSnortChocolatey | Out-Null
    $snort = Get-CtgSnortBinary
}

Deploy-CtgSnortConfig

if ($snort) {
    Write-InstallLog 'Testing Snort config (-T)...' 'Cyan'
    $iface = Get-CtgSnortInterface -SnortPath $snort
    if (-not $WhatIf) {
        & $snort -T -c $paths.ConfFile -i $iface 2>&1 | ForEach-Object { Write-InstallLog "snort -T: $_" }
        if ($LASTEXITCODE -ne 0) {
            Write-InstallLog 'Config test failed - check dynamic engine paths match Snort install dir' 'Yellow'
            Write-InstallLog "Snort install dir assumed: $snortInstall"
        } else {
            Write-InstallLog 'Snort config test PASSED' 'Green'
        }
    }
} else {
    Write-InstallLog 'Snort binary still missing. Manual steps:' 'Yellow'
    Write-InstallLog '1. https://www.snort.org/downloads - Snort 2.9.x Windows installer'
    Write-InstallLog '2. Install to C:\Snort (default)'
    Write-InstallLog '3. Register at snort.org for community rules tarball'
    Write-InstallLog '4. Re-run: .\scripts\windows\Install-CtgSnortWindows.ps1'
    Write-InstallLog '5. Or use Wireshark fallback: Start-CtgSnortIDS.ps1 -UseWiresharkFallback'
}

Write-InstallLog 'Install complete. Next: Start-CtgSnortIDS.ps1 -DiagnoseOnly' 'Green'
