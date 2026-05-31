<#
.SYNOPSIS
  Detect Wi-Fi jam/deauth/disconnect storms (defensive only — no RF countermeasures).

.DESCRIPTION
  DiagnoseOnly: one-shot report of Wi-Fi profile, gateway ping, recent disconnect hints.
  Watch: loop every N seconds; emit CTGEvent JSON to Backups ctg-events inbox.
  Optional Signal notify via Send-CtgIdsAlert.ps1 (rate-limited, deduped by event bus).

.PARAMETER DiagnoseOnly
  Report only (default when -Watch omitted).

.PARAMETER Watch
  Continuous monitoring loop.

.PARAMETER IntervalSec
  Watch loop interval (default 30).

.PARAMETER EmitEvents
  Write CTG events via Python event bus (default in Watch mode).

.PARAMETER NotifySignal
  Send deduped Signal alert for high/critical events when configured.

.PARAMETER UseSecretVault
  Pass through to Send-CtgIdsAlert.ps1 for vault destination.

.EXAMPLE
  .\scripts\windows\Detect-CtgWifiJam.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Detect-CtgWifiJam.ps1 -Watch -NotifySignal -UseSecretVault
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [switch] $Watch,
    [int] $IntervalSec = 30,
    [switch] $EmitEvents,
    [switch] $NotifySignal,
    [switch] $UseSecretVault
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-WiresharkCommon.ps1')

$repo = Get-CtgRepoRoot -FromPath $PSScriptRoot
$backups = Get-CtgBackupsRoot
$logDir = Join-Path $backups 'logs'
$logFile = Join-Path $logDir 'detect-wifi-jam.log'

function Write-JamLog {
    param([string] $Message, [string] $Color = 'Gray')
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    try {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        Add-Content -Path $logFile -Value $line -Encoding utf8 -ErrorAction SilentlyContinue
    } catch { }
    Write-Host $line -ForegroundColor $Color
}

function Get-CtgWifiAdapterState {
    $rows = @()
    try {
        netsh wlan show interfaces 2>$null | ForEach-Object { $rows += $_.Trim() }
    } catch { }
    $state = @{
        Connected = $false
        SSID = ''
        BSSID = ''
        Signal = ''
        DisconnectReason = ''
    }
    foreach ($line in $rows) {
        if ($line -match '^Name\s*:\s*(.+)$') { $state['Name'] = $Matches[1].Trim() }
        if ($line -match '^SSID\s*:\s*(.+)$') { $state['SSID'] = $Matches[1].Trim() }
        if ($line -match '^BSSID\s*:\s*(.+)$') { $state['BSSID'] = $Matches[1].Trim() }
        if ($line -match '^Signal\s*:\s*(.+)$') { $state['Signal'] = $Matches[1].Trim() }
        if ($line -match '^State\s*:\s*connected') { $state['Connected'] = $true }
    }
    return $state
}

function Test-CtgGatewayReachable {
    param([string] $Target = '192.168.1.1')
    try {
        $ping = Test-Connection -ComputerName $Target -Count 2 -Quiet -ErrorAction Stop
        return [bool]$ping
    } catch {
        return $false
    }
}

function Invoke-CtgEventEmit {
    param(
        [string] $Type,
        [string] $Severity,
        [string] $Message,
        [string] $Ssid = '',
        [string] $Bssid = ''
    )
    $payload = @{
        type     = $Type
        source   = 'windows'
        severity = $Severity
        message  = $Message
        ssid     = $Ssid
        bssid    = $Bssid
    } | ConvertTo-Json -Compress
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) { $python = Get-Command python3 -ErrorAction SilentlyContinue }
    if (-not $python) {
        Write-JamLog 'Emit skipped: python not found' 'Yellow'
        return $null
    }
    Push-Location $repo
    try {
        $out = & $python.Source -m core.ctg_event_bus emit --json $payload 2>&1 | Out-String
        return ($out | ConvertFrom-Json -ErrorAction SilentlyContinue)
    } catch {
        Write-JamLog "Emit failed: $($_.Exception.Message)" 'Yellow'
        return $null
    } finally {
        Pop-Location
    }
}

function Invoke-CtgJamScan {
    $wifi = Get-CtgWifiAdapterState
    $gwOk = Test-CtgGatewayReachable
    $issues = @()

    if (-not $wifi.Connected) {
        $issues += 'Wi-Fi not connected (possible disconnect storm or jam)'
    }
    if (-not $gwOk) {
        $issues += 'Default gateway ping failed while on Wi-Fi'
    }

    Write-JamLog "Wi-Fi connected=$($wifi.Connected) SSID=$($wifi.SSID) BSSID=$($wifi.BSSID) signal=$($wifi.Signal)" 'Cyan'
    Write-JamLog "Gateway reachable=$gwOk" $(if ($gwOk) { 'Green' } else { 'Yellow' })

    foreach ($i in $issues) {
        Write-JamLog "WARN: $i" 'Yellow'
    }

    if ($issues.Count -eq 0) {
        return @{ Severity = 'info'; Message = 'Wi-Fi link stable'; Issues = 0 }
    }

    $severity = if ($issues.Count -ge 2) { 'high' } else { 'warn' }
    $msg = ($issues -join '; ')
    return @{
        Severity = $severity
        Message  = $msg
        Issues   = $issues.Count
        SSID     = $wifi.SSID
        BSSID    = $wifi.BSSID
    }
}

Write-Host ''
Write-Host 'CTG Wi-Fi jam/deauth detection (defensive only — no counter-jam)' -ForegroundColor Cyan
Write-Host 'Legal: detection and failover only; FCC prohibits unauthorized jamming.' -ForegroundColor DarkGray
Write-Host ''

if (-not $Watch) {
    $DiagnoseOnly = $true
}

$result = Invoke-CtgJamScan

if ($DiagnoseOnly -and -not $EmitEvents) {
    if ($result.Issues -gt 0) {
        exit 2
    }
    exit 0
}

$shouldEmit = $EmitEvents -or $Watch
if ($shouldEmit -and $result.Issues -gt 0) {
    $etype = if ($result.Message -match 'disconnect') { 'wifi.disconnect_storm' } else { 'wifi.jam' }
    $emit = Invoke-CtgEventEmit -Type $etype -Severity $result.Severity -Message $result.Message `
        -Ssid $result.SSID -Bssid $result.BSSID
    if ($emit -and $emit.accepted -and $NotifySignal) {
        $alertType = "wifi-jam-$($result.SSID -replace '\s','')"
        $body = $emit.event.analyst_summary
        if (-not $body) { $body = "CTG: $($result.Message)" }
        & (Join-Path $PSScriptRoot 'Send-CtgIdsAlert.ps1') -AlertType $alertType -Message $body -Severity $result.Severity $(if ($UseSecretVault) { '-UseSecretVault' })
    }
}

if ($Watch) {
    Write-JamLog "Watch mode every ${IntervalSec}s (Ctrl+C to stop)" 'Gray'
    while ($true) {
        Start-Sleep -Seconds $IntervalSec
        $scan = Invoke-CtgJamScan
        if ($scan.Issues -gt 0) {
            $etype = if ($scan.Message -match 'disconnect') { 'wifi.disconnect_storm' } else { 'wifi.jam' }
            $emit = Invoke-CtgEventEmit -Type $etype -Severity $scan.Severity -Message $scan.Message `
                -Ssid $scan.SSID -Bssid $scan.BSSID
            if ($emit -and $emit.accepted -and $NotifySignal) {
                $body = $emit.event.analyst_summary
                if (-not $body) { $body = "CTG: $($scan.Message)" }
                & (Join-Path $PSScriptRoot 'Send-CtgIdsAlert.ps1') -AlertType 'wifi-jam-watch' -Message $body -Severity $scan.Severity $(if ($UseSecretVault) { '-UseSecretVault' })
            }
        }
    }
}

if ($result.Issues -gt 0) { exit 2 }
exit 0
