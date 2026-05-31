<#
.SYNOPSIS
  Install or diagnose local Wazuh manager stack (Docker single-node lab).

.DESCRIPTION
  -DiagnoseOnly: check Docker, compose file, port availability.
  -ApplySafe: docker compose up -d in scripts/wazuh-lab (local data under ./data — gitignored).
  Agent enrollment: set CTG_WAZUH_MANAGER to host IP; run wazuh_agent_setup.ps1 on Windows
  or ctg-wazuh-agent-install.sh on Kali.

.PARAMETER DiagnoseOnly
  Report only (default when -ApplySafe not set).

.PARAMETER ApplySafe
  Start Docker compose stack.

.EXAMPLE
  .\scripts\windows\Install-CtgWazuhLab.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Install-CtgWazuhLab.ps1 -ApplySafe
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch] $DiagnoseOnly,
    [switch] $ApplySafe
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'CTG-Paths.ps1')

$LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
$LogFile = Join-Path $LogDir 'install-ctg-wazuh-lab.log'
$ComposeDir = Join-Path (Get-CtgRepoRoot -FromPath $PSScriptRoot) 'scripts\wazuh-lab'
$ComposeFile = Join-Path $ComposeDir 'docker-compose.yml'

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-CtgWazuhLog {
    param([string] $Message, [string] $Color = 'Gray')
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Host $line -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Test-CtgDockerAvailable {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) { return $false }
    try {
        docker info 2>&1 | Out-Null
        return $LASTEXITCODE -eq 0
    } catch { return $false }
}

Write-CtgWazuhLog '=== CTG Wazuh lab stack ===' 'Cyan'

if (-not (Test-Path $ComposeFile)) {
    Write-CtgWazuhLog "Missing compose file: $ComposeFile" 'Red'
    exit 1
}

$dockerOk = Test-CtgDockerAvailable
Write-CtgWazuhLog ("Docker available: {0}" -f $dockerOk)

foreach ($port in @(1514, 5601, 9200)) {
    $inUse = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if ($inUse) {
        Write-CtgWazuhLog "Port $port in use — may conflict with existing Wazuh/SIEM" 'Yellow'
    } else {
        Write-CtgWazuhLog "Port $port: available" 'Gray'
    }
}

$manager = [Environment]::GetEnvironmentVariable('CTG_WAZUH_MANAGER', 'User')
if (-not $manager) { $manager = [Environment]::GetEnvironmentVariable('CTG_WAZUH_MANAGER', 'Process') }
Write-CtgWazuhLog ("CTG_WAZUH_MANAGER: {0}" -f $(if ($manager) { $manager } else { '(not set — set to host LAN IP after stack up)' }))

Write-CtgWazuhLog 'Snort/Suricata JSON: forward via Filebeat or CTG IDS scripts — see docs/LAB_MATURITY.md' 'Gray'
Write-CtgWazuhLog 'Kali agent stub: scripts/kali/ctg-wazuh-agent-install.sh' 'Gray'

if (-not $ApplySafe) {
    Write-CtgWazuhLog 'DiagnoseOnly complete. Run -ApplySafe to start docker compose.' 'Cyan'
    exit 0
}

if (-not $dockerOk) {
    Write-CtgWazuhLog 'Docker not available — install Docker Desktop and retry.' 'Red'
    exit 1
}

if (-not $PSCmdlet.ShouldProcess('wazuh-lab', 'docker compose up -d')) {
    Write-CtgWazuhLog '[WhatIf] docker compose up -d' 'Yellow'
    exit 0
}

Push-Location $ComposeDir
try {
    docker compose up -d
    if ($LASTEXITCODE -ne 0) { throw "docker compose exited $LASTEXITCODE" }
    Write-CtgWazuhLog 'Wazuh stack started. Dashboard: https://localhost:5601 (default creds in compose — change locally)' 'Green'
    Write-CtgWazuhLog 'Set CTG_WAZUH_MANAGER to this host LAN IP for agents.' 'Yellow'
} finally {
    Pop-Location
}

exit 0
