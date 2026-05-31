<#
.SYNOPSIS
  Install and configure Suricata IDS on Windows 11 Pro (detect-only, CTG lab).

.DESCRIPTION
  Suricata 7.x/8.x official MSI + Npcap. Rules and config under Backups\ctg-suricata\.
  Primary free IPS path: Suricata on Kali (ctg-ids-ips-autorun.sh) or OPNsense.
  Windows stack is detect-only + SMS; inline IPS on Win11 laptop is limited.

.PARAMETER DiagnoseOnly
  Check Win11 Pro, Npcap, admin, Suricata binary, CTG paths - no install.

.PARAMETER InstallViaWinget
  Attempt winget install OISF.Suricata when binary missing.

.PARAMETER WhatIf
  Show planned actions without installing.

.EXAMPLE
  .\scripts\windows\Install-CtgSuricataWindows.ps1 -DiagnoseOnly
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [switch] $InstallViaWinget,
    [switch] $WhatIf
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
. (Join-Path $PSScriptRoot 'CTG-SuricataCommon.ps1')

$repo = Get-CtgRepoRoot
Import-CtgDotEnv -EnvPath (Join-Path $repo '.env')
$paths = Get-CtgSuricataPaths
$isAdmin = Test-CtgIsAdmin
$win = Test-CtgWin11Pro
$npcap = Test-CtgNpcapInstalled
$suricata = Test-CtgSuricataInstalled
$suricataInstall = Get-CtgSuricataInstallDir -SuricataPath $suricata

function Write-InstallLog {
    param([string] $Message, [string] $Color = 'Gray')
    Write-CtgSuricataLog $Message $paths.IdsLog $Color
}

function Invoke-CtgSuricataDiagnose {
    $ok = $true
    Write-InstallLog '--- Install-CtgSuricataWindows DiagnoseOnly ---' 'Cyan'
    Write-InstallLog "OS: $($win.Caption) build $($win.Build) Win11=$($win.IsWin11) Pro=$($win.IsPro)"
    if (-not $win.Ok) {
        Write-InstallLog 'WARN: Suricata Windows stack expects Windows 11 Pro/Enterprise (lab SOC host)' 'Yellow'
    }
    Write-InstallLog "Administrator: $isAdmin"
    if (-not $isAdmin) {
        Write-InstallLog 'WARN: Suricata live capture requires elevated PowerShell' 'Yellow'
    }
    Write-InstallLog "Npcap: $(if ($npcap) { 'installed' } else { 'MISSING - run Install-WiresharkNpcap.ps1 or https://npcap.com' })"
    if (-not $npcap) { $ok = $false }
    if ($suricata) {
        Write-InstallLog "Suricata binary: $suricata"
        $ver = Get-CtgSuricataVersion -SuricataPath $suricata
        if ($ver) { Write-InstallLog "Suricata version: $ver" }
    } else {
        Write-InstallLog 'Suricata: NOT installed - MSI from https://suricata.io/download/' 'Red'
        Write-InstallLog '  Optional: -InstallViaWinget (OISF.Suricata)' 'Yellow'
        Write-InstallLog '  Kali bridge: Start-CtgKaliSuricataSmsBridge.ps1 when VM runs Suricata-primary' 'Yellow'
        $ok = $false
    }
    Write-InstallLog "CTG suricata root: $($paths.SuricataRoot)"
    Write-InstallLog "CTG config: $($paths.YamlFile)"
    Write-InstallLog "CTG EVE log: $($paths.EveLog)"
    $twilioOk = @(
        $env:TWILIO_ACCOUNT_SID, $env:TWILIO_AUTH_TOKEN,
        $env:TWILIO_FROM_NUMBER, $env:CTG_ALERT_SMS_TO
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($twilioOk.Count -eq 4) {
        Write-InstallLog 'Twilio SMS: env configured (Send-CtgSmsAlert.ps1 -TestMessage)'
    } else {
        Write-InstallLog 'Twilio SMS: not fully configured - set vars in local .env'
    }
    Write-InstallLog "DiagnoseOnly result: $(if ($ok) { 'PASS' } else { 'FAIL - see docs/FREE_IPS_SURICATA.md' })"
    return $ok
}

function Copy-CtgSuricataRulesFromInstall {
    $srcRules = Join-Path $suricataInstall 'rules'
    if (-not (Test-Path $srcRules)) { return }
    Write-InstallLog "Copying rules from $srcRules -> $($paths.RulesDir)"
    Get-ChildItem -Path $srcRules -Filter '*.rules' -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination (Join-Path $paths.RulesDir $_.Name) -Force
    }
}

function Deploy-CtgSuricataConfig {
    Ensure-CtgSuricataLayout -Paths $paths
    $iface = Get-CtgSuricataInterface
    $conf = New-CtgSuricataYamlContent -RulesDir $paths.RulesDir -LogDir $paths.LogsDir -Interface $iface -InstallDir $suricataInstall
    if ($WhatIf) {
        Write-InstallLog "[WhatIf] Would write suricata.yaml to $($paths.YamlFile)"
        return
    }
    Set-Content -Path $paths.YamlFile -Value $conf -Encoding utf8
    Write-InstallLog "Deployed CTG suricata.yaml -> $($paths.YamlFile) iface=$iface" 'Green'
    Copy-CtgSuricataRulesFromInstall
}

function Install-CtgSuricataWinget {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-InstallLog 'winget not found - download MSI from suricata.io/download' 'Yellow'
        return $false
    }
    if ($WhatIf) {
        Write-InstallLog '[WhatIf] winget install --id OISF.Suricata -e'
        return $true
    }
    Write-InstallLog 'Installing Suricata via winget (OISF.Suricata)...' 'Cyan'
    & winget install --id OISF.Suricata -e --accept-package-agreements --accept-source-agreements
    return ($LASTEXITCODE -eq 0)
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ' CTG Suricata Windows Install (detect-only)' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan

if ($DiagnoseOnly) {
    $result = Invoke-CtgSuricataDiagnose
    exit $(if ($result) { 0 } else { 1 })
}

Ensure-CtgSuricataLayout -Paths $paths

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

if (-not $suricata -and $InstallViaWinget) {
    Install-CtgSuricataWinget | Out-Null
    $suricata = Test-CtgSuricataInstalled
    $suricataInstall = Get-CtgSuricataInstallDir -SuricataPath $suricata
}

Deploy-CtgSuricataConfig

if ($suricata) {
    Write-InstallLog 'Testing Suricata config (-T)...' 'Cyan'
    if (-not $WhatIf) {
        & $suricata -T -c $paths.YamlFile 2>&1 | ForEach-Object { Write-InstallLog "suricata -T: $_" }
        if ($LASTEXITCODE -ne 0) {
            Write-InstallLog 'Config test failed - check rule paths and Npcap interface name in yaml' 'Yellow'
        } else {
            Write-InstallLog 'Suricata config test PASSED' 'Green'
        }
    }
} else {
    Write-InstallLog 'Suricata binary still missing. Manual steps:' 'Yellow'
    Write-InstallLog '1. https://suricata.io/download/ - Suricata 8.x Windows 64-bit MSI'
    Write-InstallLog '2. Install to C:\Program Files\Suricata (default)'
    Write-InstallLog '3. Re-run: .\scripts\windows\Install-CtgSuricataWindows.ps1'
    Write-InstallLog '4. Or poll Kali VM: Start-CtgKaliSuricataSmsBridge.ps1'
}

Write-InstallLog 'Install complete. Next: Start-CtgSuricataIDS.ps1 -DiagnoseOnly' 'Green'
