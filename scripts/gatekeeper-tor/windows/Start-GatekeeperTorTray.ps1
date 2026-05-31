<#
.SYNOPSIS
  Gatekeeper.TOR Windows system tray — lit icon, Tor/HTTPS toggle, DDG coexistence.

.DESCRIPTION
  Hacker Planet LLC · authorized defensive lab only.
  Does NOT replace DuckDuckGo VPN/DNS/Password Manager. Active mode shows lit neon PNG;
  inactive mode is dim gray. When DDG VPN is active, shows coexistence status and optional
  local Tor Expert Bundle SOCKS (127.0.0.1:9050) for apps that opt in — no conflicting
  system-wide routes without user consent.

.PARAMETER DiagnoseOnly
  Print paths, DDG note, Tor detection, lit icon assets — no tray.

.PARAMETER InstallTray
  Register Current User Run key for tray at logon (no admin required).

.EXAMPLE
  .\scripts\gatekeeper-tor\windows\Start-GatekeeperTorTray.ps1 -DiagnoseOnly
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [switch] $InstallTray
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\windows\CTG-Paths.ps1')
$RepoRoot = Get-CtgRepoRoot -FromPath $PSScriptRoot
$AssetsDir = Join-Path $RepoRoot 'assets\gatekeeper-tor'
$CorePy = Join-Path $RepoRoot 'core\gatekeeper_tor.py'
$StateDir = Join-Path $env:USERPROFILE 'Backups\gatekeeper-tor'

function Get-GatekeeperPythonStatus {
    if (-not (Test-Path $CorePy)) {
        return @{ ok = $false; error = "Missing $CorePy" }
    }
    $py = Get-Command python -ErrorAction SilentlyContinue
    if (-not $py) {
        $py = Get-Command py -ErrorAction SilentlyContinue
    }
    if (-not $py) {
        return @{ ok = $false; error = 'python not in PATH' }
    }
    $exe = if ($py.Name -eq 'py') { 'py -3' } else { $py.Source }
    if ($exe -eq 'py -3') {
        $out = & py -3 $CorePy status 2>&1 | Out-String
    } else {
        $out = & $py.Source $CorePy status 2>&1 | Out-String
    }
    return @{ ok = $true; output = $out.Trim() }
}

function Get-GatekeeperMode {
    $st = Get-GatekeeperPythonStatus
    if ($st.ok -and $st.output -match '"mode"\s*:\s*"([^"]+)"') {
        $m = $Matches[1].ToLower()
        if ($m -match '^(https|http|clearnet)$') { return 'https' }
        return 'tor'
    }
    return 'tor'
}

function Get-GkLitIconPath {
    param([string] $Mode)
    $active = Get-GatekeeperMode
    $lit = ($Mode -eq $active)
    $suffix = if ($lit) { 'on' } else { 'off' }
    if ($Mode -eq 'https') {
        return Join-Path $AssetsDir "logo-https-$suffix.png"
    }
    return Join-Path $AssetsDir "logo-tor-$suffix.png"
}

function Get-GkLitTooltip {
    $mode = Get-GatekeeperMode
    $label = if ($mode -eq 'https') { 'HTTPS' } else { 'TOR' }
    return "Gatekeeper.TOR — $label (lit)"
}

function Test-CtgDdgVpnActive {
    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -match 'DuckDuckGo|WireGuard|TAP' }
    return [bool]($adapters | Select-Object -First 1)
}

function Test-CtgLocalTorSocks {
    try {
        $tcp = Test-NetConnection -ComputerName 127.0.0.1 -Port 9050 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        return [bool]$tcp.TcpTestSucceeded
    } catch {
        return $false
    }
}

function Invoke-GatekeeperSetMode {
    param([string] $Mode)
    $py = Get-Command python -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command py -ErrorAction SilentlyContinue }
    if (-not $py) { return }
    if ($py.Name -eq 'py') {
        & py -3 $CorePy set-mode $Mode | Out-Null
    } else {
        & $py.Source $CorePy set-mode $Mode | Out-Null
    }
}

function Update-GatekeeperTrayUi {
    param(
        [System.Windows.Forms.NotifyIcon] $NotifyIcon,
        [System.Windows.Forms.ContextMenuStrip] $Menu
    )
    $mode = Get-GatekeeperMode
    $iconPath = Get-GkLitIconPath -Mode $mode
    if (Test-Path $iconPath) {
        try {
            $NotifyIcon.Icon = [System.Drawing.Icon]::new($iconPath)
        } catch {
            $NotifyIcon.Icon = [System.Windows.Forms.SystemIcons]::Shield
        }
    }
    $ddg = Test-CtgDdgVpnActive
    $socks = Test-CtgLocalTorSocks
    $tooltip = Get-GkLitTooltip
    if ($ddg) { $tooltip += ' | DDG preserved' }
    if ($socks) { $tooltip += ' | SOCKS :9050' }
    $NotifyIcon.Text = $tooltip.Substring(0, [Math]::Min(63, $tooltip.Length))
    if ($Menu.Items.Count -ge 2) {
        $Menu.Items[0].Text = if ($mode -eq 'tor') { '✓ TOR (lit)' } else { '  TOR' }
        $Menu.Items[1].Text = if ($mode -eq 'https') { '✓ HTTPS (lit)' } else { '  HTTPS' }
    }
}

function Start-GatekeeperTrayUi {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $script:NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
    $script:ContextMenu = New-Object System.Windows.Forms.ContextMenuStrip

    $mode = Get-GatekeeperMode
    [void]$script:ContextMenu.Items.Add(
        $(if ($mode -eq 'tor') { '✓ TOR (lit)' } else { '  TOR' }),
        $null,
        { Invoke-GatekeeperSetMode 'tor'; Update-GatekeeperTrayUi $script:NotifyIcon $script:ContextMenu }
    )
    [void]$script:ContextMenu.Items.Add(
        $(if ($mode -eq 'https') { '✓ HTTPS (lit)' } else { '  HTTPS' }),
        $null,
        { Invoke-GatekeeperSetMode 'https'; Update-GatekeeperTrayUi $script:NotifyIcon $script:ContextMenu }
    )
    [void]$script:ContextMenu.Items.Add('-')
    $ddg = Test-CtgDdgVpnActive
    $ddgLabel = if ($ddg) { 'DDG VPN: active (preserved)' } else { 'DDG VPN: verify Preserve-DuckDuckGoVpn.ps1' }
    [void]$script:ContextMenu.Items.Add($ddgLabel, $null, { })
    $socks = Test-CtgLocalTorSocks
    $socksLabel = if ($socks) { 'Local Tor SOCKS: :9050' } else { 'Local Tor SOCKS: not listening' }
    [void]$script:ContextMenu.Items.Add($socksLabel, $null, {
        Start-Process 'https://www.torproject.org/download/tor/'
    })
    [void]$script:ContextMenu.Items.Add('-')
    [void]$script:ContextMenu.Items.Add('Health check', $null, {
        $py = Get-Command python -ErrorAction SilentlyContinue
        if (-not $py) { $py = Get-Command py -ErrorAction SilentlyContinue }
        if ($py) {
            $h = if ($py.Name -eq 'py') {
                (& py -3 $CorePy health 2>&1 | Out-String)
            } else {
                (& $py.Source $CorePy health 2>&1 | Out-String)
            }
            [System.Windows.Forms.MessageBox]::Show($h, 'Gatekeeper health')
        }
    })
    [void]$script:ContextMenu.Items.Add('Exit', $null, {
        $script:NotifyIcon.Visible = $false
        [System.Windows.Forms.Application]::Exit()
    })

    $script:NotifyIcon.ContextMenuStrip = $script:ContextMenu
    Update-GatekeeperTrayUi $script:NotifyIcon $script:ContextMenu
    $script:NotifyIcon.Visible = $true

    [void][System.Windows.Forms.Application]::Run()
}

Write-Host '=== Gatekeeper.TOR (Windows) ===' -ForegroundColor Cyan
Write-Host "Repo:      $RepoRoot"
Write-Host "Assets:    $AssetsDir"
Write-Host "State dir: $StateDir"
Write-Host "Core:      $CorePy"
Write-Host "Tooltip:   $(Get-GkLitTooltip)"

foreach ($name in @('logo-tor-on.png', 'logo-tor-off.png', 'logo-https-on.png', 'logo-https-off.png')) {
    $p = Join-Path $AssetsDir $name
    $status = if (Test-Path $p) { 'OK' } else { 'MISSING' }
    Write-Host "  $name : $status"
}

$ddgActive = Test-CtgDdgVpnActive
$socksUp = Test-CtgLocalTorSocks
Write-Host "DDG VPN adapter signal: $ddgActive (Gatekeeper does NOT replace DDG)"
Write-Host "Local Tor SOCKS 9050:    $socksUp"

$st = Get-GatekeeperPythonStatus
if ($st.ok) {
    Write-Host $st.output
} else {
    Write-Host "Python state: $($st.error)" -ForegroundColor Yellow
}

if ($InstallTray) {
    $self = $PSCommandPath
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    Set-ItemProperty -Path $runKey -Name 'CTG-GatekeeperTorTray' -Value "powershell.exe -WindowStyle Hidden -File `"$self`""
    Write-Host 'Registered HKCU Run: CTG-GatekeeperTorTray'
}

if ($DiagnoseOnly) {
    Write-Host 'Diagnose complete.' -ForegroundColor Green
    exit 0
}

Start-GatekeeperTrayUi
