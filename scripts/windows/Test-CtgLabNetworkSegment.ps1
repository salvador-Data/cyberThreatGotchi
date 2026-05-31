<#
.SYNOPSIS
  Diagnose lab network segmentation (flat LAN vs VLAN).

.DESCRIPTION
  Detects whether host, guest VM, and lab targets share a flat subnet.
  Recommends pfSense/OPNsense VLAN IDs from lab-vlan.conf.example placeholders.
  No changes applied — guidance only.

.PARAMETER DiagnoseOnly
  Default mode — report only.

.PARAMETER ConfigPath
  Optional lab-vlan.conf (gitignored local copy).

.EXAMPLE
  .\scripts\windows\Test-CtgLabNetworkSegment.ps1 -DiagnoseOnly
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [string] $ConfigPath = ''
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-Paths.ps1')

$LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
$LogFile = Join-Path $LogDir 'test-ctg-lab-network-segment.log'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-CtgNetLog {
    param([string] $Message, [string] $Color = 'Gray')
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Host $line -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Get-CtgActiveIPv4Networks {
    Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notmatch '^127\.' -and $_.PrefixOrigin -ne 'WellKnown' } |
        ForEach-Object {
            $ip = $_.IPAddress
            $prefix = $_.PrefixLength
            [PSCustomObject]@{
                Interface = $_.InterfaceAlias
                IP        = $ip
                Prefix    = $prefix
                Network   = "$ip/$prefix"
            }
        }
}

function Test-CtgFlatNetworkRisk {
    param([array] $Networks)
    $subnets = @($Networks | ForEach-Object { $_.Network } | Sort-Object -Unique)
    if ($subnets.Count -le 1) {
        return @{
            FlatRisk = $true
            Detail   = 'Single IPv4 subnet detected — lab VMs and host may share broadcast domain.'
        }
    }
    return @{
        FlatRisk = $false
        Detail   = "Multiple subnets: $($subnets -join ', ')"
    }
}

Write-CtgNetLog '=== CTG lab network segmentation diagnose ===' 'Cyan'
Write-CtgNetLog 'See docs/LAB_VLAN.md for pfSense/OPNsense VLAN design.' 'Gray'

$networks = @(Get-CtgActiveIPv4Networks)
if (-not $networks) {
    Write-CtgNetLog 'No active IPv4 interfaces found.' 'Yellow'
} else {
    foreach ($n in $networks) {
        Write-CtgNetLog ("  {0}: {1} on {2}" -f $n.Interface, $n.Network, $n.IP)
    }
}

$risk = Test-CtgFlatNetworkRisk -Networks $networks
if ($risk.FlatRisk) {
    Write-CtgNetLog ("FLAT NETWORK RISK: {0}" -f $risk.Detail) 'Yellow'
    Write-CtgNetLog 'Recommend: VLAN 10 mgmt, VLAN 20 lab, VLAN 30 guest IoT (see lab-vlan.conf.example)' 'Yellow'
} else {
    Write-CtgNetLog ("Segmentation hint: {0}" -f $risk.Detail) 'Green'
}

$examplePath = Join-Path (Get-CtgRepoRoot -FromPath $PSScriptRoot) 'scripts\kali\lab-vlan.conf.example'
if ($ConfigPath -and (Test-Path $ConfigPath)) {
    Write-CtgNetLog "Local config: $ConfigPath (review VLAN_* placeholders)" 'Cyan'
} elseif (Test-Path $examplePath) {
    Write-CtgNetLog "Template: $examplePath — copy to Backups/lab-vlan.conf (gitignored)" 'Gray'
}

# VirtualBox host-only / NAT hints
$vbox = Get-Command VBoxManage -ErrorAction SilentlyContinue
if ($vbox) {
    Write-CtgNetLog 'VirtualBox: prefer Host-Only + NAT for Kali — isolate lab traffic from LAN.' 'Gray'
    try {
        & VBoxManage list hostonlyifs 2>$null | ForEach-Object { Write-CtgNetLog "  $_" }
    } catch { }
} else {
    Write-CtgNetLog 'VBoxManage not in PATH — skip VM network inspect.' 'Gray'
}

Write-CtgNetLog 'DiagnoseOnly complete — no network changes applied.' 'Cyan'
exit 0
