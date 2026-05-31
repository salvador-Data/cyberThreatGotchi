#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Install or verify Wazuh agent on Windows (SIEM endpoint - authorized use only).

.DESCRIPTION
  Manager IP from -Manager, or environment variables CTG_WAZUH_MANAGER / WAZUH_MANAGER.
  No secrets are stored in this script. Agent enrollment uses your Wazuh manager IP only.

.PARAMETER Manager
  Wazuh manager IP or hostname (overrides env when set).

.PARAMETER AgentName
  Agent name reported to manager (default: COMPUTERNAME).

.PARAMETER InstallOnly
  Skip connectivity check to manager.

.PARAMETER WhatIf
  Show planned actions without installing.

.EXAMPLE
  $env:CTG_WAZUH_MANAGER = '192.168.1.50'
  .\scripts\windows\wazuh_agent_setup.ps1

.EXAMPLE
  .\scripts\windows\wazuh_agent_setup.ps1 -Manager 10.0.0.5 -AgentName lab-win01
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $Manager,
    [string] $AgentName = $env:COMPUTERNAME,
    [switch] $InstallOnly
)

$ErrorActionPreference = 'Stop'

function Get-WazuhManager {
    param([string] $Override)
    if ($Override) { return $Override.Trim() }
    foreach ($name in @('CTG_WAZUH_MANAGER', 'WAZUH_MANAGER')) {
        $v = [Environment]::GetEnvironmentVariable($name, 'Process')
        if (-not $v) { $v = [Environment]::GetEnvironmentVariable($name, 'User') }
        if (-not $v) { $v = [Environment]::GetEnvironmentVariable($name, 'Machine') }
        if ($v) { return $v.Trim() }
    }
    return $null
}

function Get-WazuhAgentMsiUrl {
    # Latest 4.x Windows agent MSI (Wazuh packages CDN)
    return 'https://packages.wazuh.com/4.x/windows/wazuh-agent-4.9.2-1.msi'
}

function Get-PackageInstaller {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        return @{ Type = 'winget'; Id = 'Wazuh.WazuhAgent' }
    }
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        return @{ Type = 'choco'; Id = 'wazuh-agent' }
    }
    return $null
}

$managerIp = Get-WazuhManager -Override $Manager
$configDir = Join-Path $env:ProgramData 'CTG\Wazuh'
$configTemplate = Join-Path $configDir 'ossec.conf.template'

Write-Host ''
Write-Host 'CyberThreatGotchi - Wazuh agent setup (defensive / authorized use only)' -ForegroundColor Cyan
Write-Host ''

if (-not $managerIp) {
    Write-Host 'Wazuh manager not set. Set one of:' -ForegroundColor Yellow
    Write-Host '  $env:CTG_WAZUH_MANAGER = ''<manager-ip-or-host>'''
    Write-Host '  $env:WAZUH_MANAGER = ''<manager-ip-or-host>'''
    Write-Host '  .\scripts\windows\wazuh_agent_setup.ps1 -Manager <ip>'
    exit 1
}

# Basic hostname/IP sanity (no secrets)
if ($managerIp -match '[\s;|&<>]') {
    throw 'Manager value contains invalid characters.'
}

$svc = Get-Service -Name 'WazuhSvc' -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq 'Running') {
    Write-Host "Wazuh agent service already running (Status: $($svc.Status))." -ForegroundColor Green
    Write-Host "Manager target: $managerIp"
    Write-Host 'Config (after install): C:\Program Files (x86)\ossec-agent\ossec.conf'
    if (-not $InstallOnly) {
        $port = 1514
        Write-Host "Checking TCP $port to manager..." -ForegroundColor Gray
        $tnc = Test-NetConnection -ComputerName $managerIp -Port $port -WarningAction SilentlyContinue
        if ($tnc.TcpTestSucceeded) {
            Write-Host "Manager reachable on port $port." -ForegroundColor Green
        } else {
            Write-Host "Cannot reach manager on port $port (firewall/VPN/manager down?)." -ForegroundColor Yellow
        }
    }
    return
}

New-Item -ItemType Directory -Path $configDir -Force | Out-Null

@'
<!-- CTG template: merge <client><server> into ossec.conf after MSI install -->
<ossec_config>
  <client>
    <server>
      <address>MANAGER_PLACEHOLDER</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
    <config-profile>windows, windows10</config-profile>
    <notify_time>10</notify_time>
    <time-reconnect>60</time-reconnect>
    <auto_restart>yes</auto_restart>
  </client>
</ossec_config>
'@ -replace 'MANAGER_PLACEHOLDER', $managerIp |
    Set-Content -Path $configTemplate -Encoding UTF8

Write-Host "Manager: $managerIp"
Write-Host "Agent name: $AgentName"
Write-Host "Config template: $configTemplate"
Write-Host ''

if (-not $PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Install Wazuh agent')) {
    Write-Host 'WhatIf: would install Wazuh agent and register with manager.' -ForegroundColor Yellow
    return
}

$installed = $false
$pkg = Get-PackageInstaller

if ($pkg) {
    Write-Host "Trying $($pkg.Type): $($pkg.Id) ..." -ForegroundColor Gray
    try {
        if ($pkg.Type -eq 'winget') {
            winget install --id $pkg.Id --accept-package-agreements --accept-source-agreements
            if ($LASTEXITCODE -eq 0) { $installed = $true }
        } elseif ($pkg.Type -eq 'choco') {
            choco install $pkg.Id -y
            if ($LASTEXITCODE -eq 0) { $installed = $true }
        }
    } catch {
        Write-Host "Package manager install failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if (-not $installed) {
    $msiUrl = Get-WazuhAgentMsiUrl
    $msiPath = Join-Path $configDir 'wazuh-agent.msi'
    Write-Host 'Downloading Wazuh agent MSI...' -ForegroundColor Gray
    Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing

    Write-Host 'Installing MSI (quiet)...' -ForegroundColor Gray
    $msiArgs = @(
        '/i', $msiPath,
        '/qn',
        "WAZUH_MANAGER=$managerIp",
        "WAZUH_AGENT_NAME=$AgentName"
    )
    $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs -Wait -PassThru
    if ($p.ExitCode -ne 0) {
        throw "msiexec exited with code $($p.ExitCode)"
    }
    $installed = $true
}

Start-Sleep -Seconds 3
$svc = Get-Service -Name 'WazuhSvc' -ErrorAction SilentlyContinue
if (-not $svc) {
    Write-Host 'WazuhSvc not found. Check install log and ossec-agent folder.' -ForegroundColor Yellow
    exit 1
}

if ($svc.Status -ne 'Running') {
    Start-Service -Name 'WazuhSvc'
}

Write-Host ''
Write-Host 'Wazuh agent installed. Next steps:' -ForegroundColor Green
Write-Host '  1. Confirm manager IP in C:\Program Files (x86)\ossec-agent\ossec.conf'
Write-Host '  2. On Wazuh dashboard: confirm agent enrolled (Active)'
Write-Host "  3. Template reference: $configTemplate"
Write-Host ''

if (-not $InstallOnly) {
    $tnc = Test-NetConnection -ComputerName $managerIp -Port 1514 -WarningAction SilentlyContinue
    if ($tnc.TcpTestSucceeded) {
        Write-Host 'Manager port 1514: reachable.' -ForegroundColor Green
    } else {
        Write-Host 'Manager port 1514: not reachable - check VPN/firewall.' -ForegroundColor Yellow
    }
}
