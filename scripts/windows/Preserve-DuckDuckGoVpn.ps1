<#
.SYNOPSIS
  Keep DuckDuckGo VPN (WireGuard) working through CTG SOC / hardening runs.
.DESCRIPTION
  - Reports VPN process + tunnel adapter status
  - Adds Defender path exclusions for DuckDuckGo.VPN (safe with audit-only SOC)
  - Does NOT install Cloudflare WARP, NextDNS, or other VPN apps that would conflict
#>
function Get-CtgDuckDuckGoVpnPaths {
    $paths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($name in @('DuckDuckGo.VPN', 'DuckDuckGo.VPN.WireGuard', 'DuckDuckGo.VPN.Tray')) {
        $p = Get-Process -Name $name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path -Unique
        foreach ($exe in $p) {
            if ($exe) {
                [void]$paths.Add((Split-Path -Parent $exe))
                [void]$paths.Add($exe)
            }
        }
    }
    $store = Join-Path $env:ProgramFiles 'WindowsApps'
    if (Test-Path -LiteralPath $store) {
        Get-ChildItem -LiteralPath $store -Directory -Filter 'DuckDuckGo.VPN_*' -ErrorAction SilentlyContinue |
            ForEach-Object { [void]$paths.Add($_.FullName) }
    }
    return @($paths)
}

function Test-CtgDuckDuckGoVpnConnected {
    $proc = Get-Process -Name 'DuckDuckGo.VPN', 'DuckDuckGo.VPN.WireGuard' -ErrorAction SilentlyContinue
    if (-not $proc) { return $false }
    $adapter = Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceDescription -match 'DuckDuckGo|WireGuard' -and $_.Status -eq 'Up' }
    return [bool]$adapter
}

function Invoke-CtgPreserveDuckDuckGoVpn {
    param(
        [scriptblock]$LogAction
    )
    function Write-CtgVpnLog([string]$Message, [string]$Color = 'Gray') {
        if ($LogAction) { & $LogAction $Message }
        else { Write-Host $Message -ForegroundColor $Color }
    }

    Write-CtgVpnLog '--- DuckDuckGo VPN preserve ---' 'Cyan'
    $paths = Get-CtgDuckDuckGoVpnPaths
    if ($paths.Count -eq 0) {
        Write-CtgVpnLog 'DuckDuckGo VPN not installed or not running - skip exclusions.' 'Yellow'
        return
    }

    $connected = Test-CtgDuckDuckGoVpnConnected
    Write-CtgVpnLog ("DuckDuckGo VPN installed: yes | tunnel up: " + $connected) $(if ($connected) { 'Green' } else { 'Yellow' })

    if (-not (Get-Command Add-MpPreference -ErrorAction SilentlyContinue)) {
        Write-CtgVpnLog 'Defender cmdlet unavailable - exclusions skipped.' 'Yellow'
        return
    }

    foreach ($path in $paths) {
        try {
            Add-MpPreference -ExclusionPath $path -ErrorAction Stop
            Write-CtgVpnLog "Defender exclusion: $path" 'Green'
        } catch {
            if ($_.Exception.Message -match 'already exists') {
                Write-CtgVpnLog "Defender exclusion (exists): $path" 'Gray'
            } else {
                Write-CtgVpnLog "Defender exclusion failed: $path - $($_.Exception.Message)" 'Yellow'
            }
        }
    }

    Write-CtgVpnLog 'CTG will NOT install Cloudflare/NextDNS VPN - keep DuckDuckGo VPN as your only system VPN.' 'Cyan'
    $env:CTG_PRESERVE_DUCKDUCKGO_VPN = '1'
}
