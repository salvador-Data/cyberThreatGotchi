<#
.SYNOPSIS
  Gatekeeper.TOR — Windows HTTPS sandbox browser (Windows Sandbox or Edge InPrivate fallback).

.DESCRIPTION
  Hacker Planet LLC · authorized defensive lab only.
  HTTPS = TLS encryption; sandbox = process isolation — complementary layers.
  Does NOT replace DuckDuckGo VPN/DNS/Password Manager on the Windows host.

.PARAMETER DiagnoseOnly
  Check Windows Sandbox feature, Hyper-V/WSL2 note, Gatekeeper tray, allowlist path.

.PARAMETER EnableSandboxFeature
  Enable Containers-DisposableClientVM (Windows Sandbox) — requires Administrator.

.PARAMETER LaunchSandboxBrowser
  Launch Edge in Windows Sandbox (primary) or InPrivate fallback. Sets CTG_SANDBOX=1.

.PARAMETER LaunchHttpLabOnly
  Launch only if URL is http:// and host is on local allowlist.

.PARAMETER Url
  Target URL (HTTPS preferred). Default about:blank.

.EXAMPLE
  .\scripts\gatekeeper-tor\windows\Start-CtgHttpsSandbox.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\gatekeeper-tor\windows\Start-CtgHttpsSandbox.ps1 -LaunchSandboxBrowser
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [switch] $EnableSandboxFeature,
    [switch] $EnableSandboxFeatureInline,
    [switch] $LaunchSandboxBrowser,
    [switch] $LaunchHttpLabOnly,
    [string] $Url = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\windows\CTG-Paths.ps1')
$RepoRoot = Get-CtgRepoRoot -FromPath $PSScriptRoot
$CoreSandbox = Join-Path $RepoRoot 'core\gatekeeper_sandbox.py'
$CoreTor = Join-Path $RepoRoot 'core\gatekeeper_tor.py'
$TrayScript = Join-Path $PSScriptRoot 'Start-GatekeeperTorTray.ps1'
$RunAsAdmin = Join-Path $RepoRoot 'scripts\windows\Run-AsAdmin.ps1'
$SandboxRoot = Join-Path $env:USERPROFILE 'Backups\ctg-sandbox'
$AllowlistPath = Join-Path $SandboxRoot 'http-allowlist.txt'

function Invoke-CtgPythonSandbox {
    param([string[]] $PyArgs)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $prevPyPath = $env:PYTHONPATH
    $env:PYTHONPATH = $RepoRoot
    try {
        $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
        if ($pyLauncher) {
            return (& py -3 $CoreSandbox @PyArgs 2>&1 | Out-String).Trim()
        }
        $py = Get-Command python -ErrorAction SilentlyContinue
        if (-not $py) { return '' }
        return (& $py.Source $CoreSandbox @PyArgs 2>&1 | Out-String).Trim()
    } finally {
        $ErrorActionPreference = $prevEap
        if ($null -eq $prevPyPath) {
            Remove-Item Env:PYTHONPATH -ErrorAction SilentlyContinue
        } else {
            $env:PYTHONPATH = $prevPyPath
        }
    }
}

function Test-CtgWindowsSandboxFeature {
    try {
        $feat = Get-WindowsOptionalFeature -Online -FeatureName 'Containers-DisposableClientVM' -ErrorAction Stop
        return [pscustomobject]@{
            Available = $true
            Enabled   = ($feat.State -eq 'Enabled')
            State     = $feat.State
        }
    } catch {
        return [pscustomobject]@{
            Available = $false
            Enabled   = $false
            State     = 'Unknown (run Admin diagnose or: Get-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM)'
            Error     = $_.Exception.Message
        }
    }
}

function Get-CtgHyperVWslNote {
    $hyperv = $false
    $wsl = $false
    try {
        $hv = Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Hyper-V-All' -ErrorAction SilentlyContinue
        $hyperv = $hv -and ($hv.State -eq 'Enabled')
    } catch { }
    try {
        $wsl = [bool](Get-Command wsl.exe -ErrorAction SilentlyContinue)
        if ($wsl) {
            $wslStatus = (& wsl.exe --status 2>&1 | Out-String)
            if ($wslStatus -match 'WSL2') { $wsl = $true }
        }
    } catch { }
    if ($hyperv -and $wsl) {
        return 'Hyper-V and WSL2 both present — Windows Sandbox can coexist; no CTG route changes.'
    }
    if ($hyperv) {
        return 'Hyper-V enabled — Windows Sandbox supported on Win11 Pro when feature is on.'
    }
    return 'Enable Hyper-V + Windows Sandbox feature for disposable VM lane (Admin). WSL2 also uses Hyper-V on Win11.'
}

function Test-CtgGatekeeperTrayRunning {
    try {
        $procs = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -match 'Start-GatekeeperTorTray' }
        return [bool]($procs | Select-Object -First 1)
    } catch {
        return $false
    }
}

function Get-CtgGatekeeperMode {
    if (-not (Test-Path $CoreTor)) { return 'unknown' }
    $out = Invoke-CtgPythonSandbox @('check-mode') 2>$null
    if ($out -match '"ok"\s*:\s*true') { return 'https' }
    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($pyLauncher) {
        $st = (& py -3 $CoreTor status 2>&1 | Out-String)
        if ($st -match '"mode"\s*:\s*"([^"]+)"') {
            $m = $Matches[1].ToLower()
            if ($m -match '^(https|http|clearnet)$') { return 'https' }
            return 'tor'
        }
    }
    return 'unknown'
}

function Initialize-CtgSandboxDir {
    if (-not (Test-Path $SandboxRoot)) {
        New-Item -ItemType Directory -Path $SandboxRoot -Force | Out-Null
    }
    if (-not (Test-Path $AllowlistPath)) {
        @(
            '# CTG HTTP allowlist — lab captive/legacy clearnet only (authorized lab)'
            '# Never use HTTP for banking, credentials, or payments.'
            '# One host per line; # comments allowed.'
            '# lab-ap.local'
            '# captive.portal.example'
        ) | Set-Content -Path $AllowlistPath -Encoding utf8NoBOM
    }
}

function Test-CtgLaunchUrlAllowed {
    param(
        [string] $TargetUrl,
        [switch] $HttpLabOnly
    )
    Initialize-CtgSandboxDir
    $pyArgs = @('check-url', $TargetUrl)
    if ($HttpLabOnly) { $pyArgs += '--http-lab' }
    $out = Invoke-CtgPythonSandbox $pyArgs
    if ($out -match '"ok"\s*:\s*true') {
        if ($out -match '"url"\s*:\s*"([^"]*)"') {
            return @{ ok = $true; url = $Matches[1]; message = 'ok' }
        }
        return @{ ok = $true; url = $TargetUrl; message = 'ok' }
    }
    if ($out -match '"message"\s*:\s*"([^"]*)"') {
        return @{ ok = $false; url = $TargetUrl; message = $Matches[1] }
    }
    return @{ ok = $false; url = $TargetUrl; message = 'URL validation failed' }
}

function New-CtgSandboxLaunchScript {
    param([string] $TargetUrl)
    $launchPs1 = Join-Path $SandboxRoot 'Invoke-SandboxEdge.ps1'
    $escaped = $TargetUrl -replace "'", "''"
    @"
# Ephemeral CTG sandbox launcher — no secrets · Hacker Planet LLC
`$env:CTG_SANDBOX = '1'
`$edge = "`${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path `$edge)) { `$edge = "`$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe" }
if (Test-Path `$edge) {
    Start-Process -FilePath `$edge -ArgumentList @('--inprivate', '$escaped')
} else {
    Start-Process 'https://www.microsoft.com/edge'
}
"@ | Set-Content -Path $launchPs1 -Encoding UTF8
    return $launchPs1
}

function Start-CtgWindowsSandboxSession {
    param([string] $TargetUrl)
    $launchHost = New-CtgSandboxLaunchScript -TargetUrl $TargetUrl
    $wsbPath = Join-Path $SandboxRoot ("ctg-sandbox-{0}.wsb" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $sandboxScript = 'C:\Users\WDAGUtilityAccount\Desktop\CTG\Invoke-SandboxEdge.ps1'
    $xml = @"
<Configuration>
  <VGpu>Default</VGpu>
  <Networking>Default</Networking>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>$SandboxRoot</HostFolder>
      <SandboxFolder>C:\Users\WDAGUtilityAccount\Desktop\CTG</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>powershell.exe -NoProfile -ExecutionPolicy Bypass -File $sandboxScript</Command>
  </LogonCommand>
</Configuration>
"@
    Set-Content -Path $wsbPath -Value $xml -Encoding UTF8
    Write-Host "Starting Windows Sandbox: $wsbPath"
    Write-Host "Mapped (read-only): $launchHost"
    Start-Process -FilePath $wsbPath
}

function Start-CtgEdgeInPrivateFallback {
    param([string] $TargetUrl)
    Write-Host 'Windows Sandbox unavailable — launching Edge InPrivate (weaker isolation).' -ForegroundColor Yellow
    Write-Host 'HTTPS protects the wire; InPrivate is not a VM sandbox. Prefer Windows Sandbox when enabled.'
    $env:CTG_SANDBOX = '1'
    $edge = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    if (-not (Test-Path $edge)) {
        $edge = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    }
    if (-not (Test-Path $edge)) {
        Write-Error 'Microsoft Edge not found.'
    }
    Start-Process -FilePath $edge -ArgumentList @('--inprivate', $TargetUrl)
}

function Invoke-CtgEnableSandboxFeature {
    if (-not (Test-Path $RunAsAdmin)) {
        Write-Error "Missing Run-AsAdmin wrapper: $RunAsAdmin"
    }
    Write-Host 'Enabling Windows Sandbox (Containers-DisposableClientVM) — UAC Admin required.'
    & $RunAsAdmin -TargetScript $PSCommandPath -TargetArguments @('-EnableSandboxFeatureInline')
}

function Enable-CtgSandboxFeatureInline {
    $feat = Get-WindowsOptionalFeature -Online -FeatureName 'Containers-DisposableClientVM'
    if ($feat.State -eq 'Enabled') {
        Write-Host 'Windows Sandbox feature already enabled.'
        return
    }
    Write-Host 'Enabling feature (reboot may be required)...'
    Enable-WindowsOptionalFeature -Online -FeatureName 'Containers-DisposableClientVM' -All -NoRestart
    Write-Host 'Done. Reboot if prompted, then re-run -DiagnoseOnly.'
}

function Invoke-CtgDiagnose {
    Write-Host '=== CTG HTTPS Sandbox (Windows 11 Pro) ===' -ForegroundColor Cyan
    Write-Host "Repo:           $RepoRoot"
    Write-Host "Sandbox dir:    $SandboxRoot (gitignored)"
    Write-Host "Allowlist:      $AllowlistPath"
    Initialize-CtgSandboxDir
    Write-Host 'DDG coexistence: Sandbox is optional lane — DuckDuckGo VPN/DNS/PM stay primary on host.'
    $wsb = Test-CtgWindowsSandboxFeature
    Write-Host "Windows Sandbox feature: $($wsb.State) (enabled=$($wsb.Enabled))"
    Write-Host "Hyper-V/WSL note: $(Get-CtgHyperVWslNote)"
    $tray = Test-CtgGatekeeperTrayRunning
    Write-Host "Gatekeeper tray running: $tray"
    Write-Host "Gatekeeper mode: $(Get-CtgGatekeeperMode)"
    if (Test-Path $CoreSandbox) {
        Write-Host (Invoke-CtgPythonSandbox @('diagnose'))
    } else {
        Write-Host "MISSING $CoreSandbox" -ForegroundColor Yellow
    }
    Write-Host 'HTTPS != sandbox: TLS protects wire; Windows Sandbox contains the browser VM.'
    Write-Host 'Diagnose complete.' -ForegroundColor Green
}

if ($EnableSandboxFeatureInline) {
    Enable-CtgSandboxFeatureInline
    exit 0
}

if ($EnableSandboxFeature) {
    Invoke-CtgEnableSandboxFeature
    exit 0
}

if ($DiagnoseOnly -or (-not $LaunchSandboxBrowser -and -not $LaunchHttpLabOnly)) {
    Invoke-CtgDiagnose
    exit 0
}

$mode = Get-CtgGatekeeperMode
if ($mode -ne 'https') {
    Write-Host 'Refusing launch: set Gatekeeper to HTTPS mode first (tray menu or gatekeeper_tor.py set-mode https).' -ForegroundColor Yellow
    exit 1
}

$target = if ($Url) { $Url } else { 'about:blank' }
$check = Test-CtgLaunchUrlAllowed -TargetUrl $target -HttpLabOnly:($LaunchHttpLabOnly.IsPresent)
if (-not $check.ok) {
    Write-Host $check.message -ForegroundColor Yellow
    exit 1
}
$target = $check.url
$env:CTG_SANDBOX = '1'

$wsb = Test-CtgWindowsSandboxFeature
if ($wsb.Enabled) {
    Start-CtgWindowsSandboxSession -TargetUrl $target
} else {
    Start-CtgEdgeInPrivateFallback -TargetUrl $target
}
