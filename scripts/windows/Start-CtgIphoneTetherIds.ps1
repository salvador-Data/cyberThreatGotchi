<#
.SYNOPSIS
  Monitor iPhone tether egress on Windows - detect-only IDS on hotspot/USB adapter.

.DESCRIPTION
  Defensive lab use only. Does NOT spoof or impersonate iPhone Wi-Fi, BLE, or cellular radios.
  When the phone shares internet (Personal Hotspot Wi-Fi or USB tether), the laptop sees
  NAT'd IP traffic on that Windows adapter - Snort/Suricata monitor that hop.

  Integrates read-only iphone_tethering_privacy_checklist.ps1 before capture when tether
  is detected. Preserve DuckDuckGo VPN/DNS on the phone (Settings unchanged by CTG).

.PARAMETER DiagnoseOnly
  List active adapters, tether heuristics, IDS availability, Signal/Twilio env.

.PARAMETER RunMinutes
  Minutes to run IDS on detected tether interface (default 60).

.PARAMETER Interface
  Manual override: Snort Npcap index or Suricata adapter name.

.PARAMETER UseSnort
  Prefer Snort when both Snort and Suricata are installed.

.PARAMETER UseSuricata
  Prefer Suricata (default when installed; Snort fallback).

.PARAMETER HotspotSsidPattern
  Optional regex for your Personal Hotspot SSID (e.g. YourHotspotSSID). Not stored in repo.

.PARAMETER SkipChecklist
  Skip iphone_tethering_privacy_checklist.ps1 (not recommended).

.PARAMETER ApplyRules
  Pass through to Start-CtgSnortIDS / Start-CtgSuricataIDS.

.PARAMETER NoSms
  Log alerts locally only.

.EXAMPLE
  .\scripts\windows\Start-CtgIphoneTetherIds.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Start-CtgIphoneTetherIds.ps1 -RunMinutes 120

.EXAMPLE
  .\scripts\windows\Start-CtgIphoneTetherIds.ps1 -HotspotSsidPattern '^YourHotspotSSID$' -RunMinutes 60
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [int] $RunMinutes = 60,
    [string] $Interface = '',
    [switch] $UseSnort,
    [switch] $UseSuricata,
    [string] $HotspotSsidPattern = '',
    [switch] $SkipChecklist,
    [switch] $ApplyRules,
    [switch] $NoSms,
    [switch] $UseSignal,
    [switch] $UseTwilio,
    [switch] $UseWiresharkFallback,
    [switch] $TestAlert
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
. (Join-Path $PSScriptRoot 'CTG-WiresharkCommon.ps1')
. (Join-Path $PSScriptRoot 'CTG-SnortCommon.ps1')
. (Join-Path $PSScriptRoot 'CTG-SuricataCommon.ps1')
. (Join-Path $PSScriptRoot 'CTG-SignalCommon.ps1')

$repo = Get-CtgRepoRoot
Import-CtgDotEnv -EnvPath (Join-Path $repo '.env')

$logDir = Join-Path (Get-CtgBackupsRoot) 'logs\iphone-tether-ids'
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$idsLog = Join-Path $logDir 'iphone-tether-ids.log'

function Write-TetherLog {
    param([string] $Message, [string] $Color = 'Gray')
    Write-CtgWiresharkLog -Message $Message -LogFile $idsLog -Color $Color
}

function Get-CtgWlanConnectedSsid {
    try {
        $out = netsh wlan show interfaces 2>&1 | Out-String
        if ($out -match '(?m)^\s*SSID\s*:\s*(.+)$') {
            return $Matches[1].Trim()
        }
    } catch { }
    return $null
}

function Get-CtgAdapterDefaultGateway {
    param([int] $IfIndex)
    try {
        $route = Get-NetRoute -InterfaceIndex $IfIndex -DestinationPrefix '0.0.0.0/0' `
            -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($route -and $route.NextHop -and $route.NextHop -ne '0.0.0.0') {
            return $route.NextHop.ToString()
        }
    } catch { }
    return $null
}

function Test-CtgIphoneTetherGateway {
    param([string] $Gateway)
    if (-not $Gateway) { return $false }
    # Classic iPhone Personal Hotspot / USB tether gateway
    if ($Gateway -eq '172.20.10.1') { return $true }
    # Some carriers / iOS versions use adjacent private ranges for hotspot DHCP
    if ($Gateway -match '^172\.20\.10\.\d+$') { return $true }
    return $false
}

function Get-CtgTetherCandidateAdapters {
    $candidates = @()
    $wlanSsid = Get-CtgWlanConnectedSsid
    $ssidMatch = $false
    if ($HotspotSsidPattern -and $wlanSsid) {
        try {
            $ssidMatch = $wlanSsid -match $HotspotSsidPattern
        } catch {
            Write-TetherLog "HotspotSsidPattern invalid regex: $HotspotSsidPattern" 'Yellow'
        }
    }

    $adapters = @()
    try {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
            $_.Status -eq 'Up' -and $_.Name -notmatch 'Loopback|vEthernet|VirtualBox|VMware|Hyper-V|Npcap Loopback'
        }
    } catch {
        return @()
    }

    foreach ($adapter in $adapters) {
        $score = 0
        $reasons = @()
        $label = "$($adapter.Name) (ifIndex $($adapter.ifIndex))"
        $desc = "$($adapter.InterfaceDescription) $($adapter.Name)"

        if ($desc -match 'Apple|iPhone|iPad|Mobile Device|Remote NDIS|RNDIS|\bNCM\b') {
            $score += 50
            $reasons += 'Apple/USB tether adapter name or description'
        }

        $gw = Get-CtgAdapterDefaultGateway -IfIndex $adapter.ifIndex
        if (Test-CtgIphoneTetherGateway -Gateway $gw) {
            $score += 40
            $reasons += "default gateway $gw (typical iPhone hotspot/USB)"
        }

        if ($adapter.Name -match 'Wi-Fi|Wireless' -and $ssidMatch) {
            $score += 35
            $reasons += "Wi-Fi SSID matches HotspotSsidPattern ($wlanSsid)"
        }
        elseif ($adapter.Name -match 'Wi-Fi|Wireless' -and (Test-CtgIphoneTetherGateway -Gateway $gw)) {
            $score += 25
            $reasons += 'Wi-Fi adapter with iPhone-class gateway (likely Personal Hotspot)'
        }

        if ($adapter.Name -match 'Ethernet' -and $desc -match 'Remote NDIS|RNDIS|NCM|Apple') {
            $score += 30
            $reasons += 'USB Ethernet-class tether (RNDIS/NCM)'
        }

        if ($score -gt 0) {
            $candidates += [PSCustomObject]@{
                Adapter       = $adapter
                IfIndex       = $adapter.ifIndex
                Name          = $adapter.Name
                Description   = $adapter.InterfaceDescription
                Gateway       = $gw
                Score         = $score
                Reasons       = ($reasons -join '; ')
                WlanSsid      = if ($adapter.Name -match 'Wi-Fi|Wireless') { $wlanSsid } else { $null }
            }
        }
    }

    return $candidates | Sort-Object -Property Score -Descending
}

function Get-CtgIphoneTetherInterface {
    param([string] $ManualInterface)
    if ($ManualInterface) {
        return [PSCustomObject]@{
            SnortIndex    = $ManualInterface
            SuricataName  = $ManualInterface
            Name          = $ManualInterface
            Source        = 'manual'
            Score         = 100
            Reasons       = 'Interface parameter override'
        }
    }

    $candidates = Get-CtgTetherCandidateAdapters
    if ($candidates.Count -eq 0) {
        return $null
    }

    $best = $candidates[0]
    return [PSCustomObject]@{
        SnortIndex   = [string]$best.IfIndex
        SuricataName = $best.Name
        Name         = $best.Name
        Source       = 'heuristic'
        Score        = $best.Score
        Reasons      = $best.Reasons
        Gateway      = $best.Gateway
        WlanSsid     = $best.WlanSsid
    }
}

function Get-CtgPreferredIdsEngine {
    $snort = Get-CtgSnortBinary
    $suricata = Test-CtgSuricataInstalled
    if ($UseSnort -and $snort) { return 'snort' }
    if ($UseSuricata -and $suricata) { return 'suricata' }
    if ($suricata) { return 'suricata' }
    if ($snort) { return 'snort' }
    return $null
}

function Invoke-CtgTetherChecklist {
    $checklist = Join-Path $repo 'scripts\iphone\iphone_tethering_privacy_checklist.ps1'
    if (-not (Test-Path $checklist)) {
        Write-TetherLog "Checklist missing: $checklist" 'Yellow'
        return
    }
    Write-TetherLog 'Running read-only iPhone tether privacy checklist...' 'Cyan'
    & $checklist -DetectUsb -LogDir (Join-Path (Get-CtgBackupsRoot) 'logs') | Out-Null
}


function Invoke-CtgTetherTestAlert {
    $alertScript = Join-Path $PSScriptRoot 'Send-CtgIdsAlert.ps1'
    if (-not (Test-Path $alertScript)) { Write-TetherLog "Missing: $alertScript" 'Red'; exit 1 }
    $args = @{ AlertType = 'iphone-tether-test'; TestMessage = $true }
    if ($UseSignal) { $args['UseSignal'] = $true }
    if ($UseTwilio) { $args['UseTwilio'] = $true }
    Write-TetherLog 'Sending test IDS alert (Signal preferred when configured)...' 'Cyan'
    & $alertScript @args
    if ($?) { exit 0 } else { exit 1 }
}
function Invoke-CtgTetherDiagnose {
    $ok = $true
    Write-TetherLog '--- Start-CtgIphoneTetherIds DiagnoseOnly ---' 'Cyan'
    Write-TetherLog 'SCOPE: monitor tether egress only - no Wi-Fi/BLE/cellular radio spoofing' 'Yellow'
    Write-TetherLog "Admin: $(Test-CtgIsAdmin)"
    Write-TetherLog "Npcap: $(Test-CtgNpcapInstalled)"
    Write-TetherLog "Signal configured: $(Test-CtgSignalConfigured)"

    $engine = Get-CtgPreferredIdsEngine
    Write-TetherLog "Preferred IDS engine: $(if ($engine) { $engine } else { 'NONE - install Snort or Suricata' })"
    if (-not $engine) { $ok = $false }

    $wlanSsid = Get-CtgWlanConnectedSsid
    if ($wlanSsid) {
        Write-TetherLog "Connected Wi-Fi SSID: $wlanSsid"
    } else {
        Write-TetherLog 'Connected Wi-Fi SSID: (none or unavailable)'
    }

    Write-TetherLog '--- Active adapters (non-virtual) ---' 'Cyan'
    try {
        Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
            $_.Status -eq 'Up' -and $_.Name -notmatch 'Loopback|vEthernet|VirtualBox|VMware|Hyper-V'
        } | ForEach-Object {
            $gw = Get-CtgAdapterDefaultGateway -IfIndex $_.ifIndex
            Write-TetherLog "  $($_.Name) ifIndex=$($_.ifIndex) gw=$gw desc=$($_.InterfaceDescription)"
        }
    } catch {
        Write-TetherLog "  Get-NetAdapter failed: $_" 'Red'
    }

    Write-TetherLog '--- Tether candidates (heuristic) ---' 'Cyan'
    $candidates = Get-CtgTetherCandidateAdapters
    if ($candidates.Count -eq 0) {
        Write-TetherLog '  No tether candidate detected. Enable Personal Hotspot or USB tether on iPhone.' 'Yellow'
        Write-TetherLog '  Optional: -HotspotSsidPattern for your SSID (placeholder: YourHotspotSSID)' 'Yellow'
        $ok = $false
    } else {
        foreach ($c in $candidates) {
            Write-TetherLog ("  score={0} {1} gw={2} - {3}" -f $c.Score, $c.Name, $c.Gateway, $c.Reasons) 'Green'
        }
        $pick = Get-CtgIphoneTetherInterface
        Write-TetherLog "Selected for IDS: $($pick.Name) ($($pick.Reasons))" 'Cyan'
    }

    Write-TetherLog "DiagnoseOnly: $(if ($ok) { 'PASS' } else { 'FAIL - connect tether or pass -Interface' })"
    return $ok
}

function Invoke-CtgTetherIdsRun {
    param(
        [object] $TetherIface,
        [string] $Engine
    )

    $commonArgs = @{
        RunMinutes = $RunMinutes
        NoSms      = $NoSms
    }
    if ($ApplyRules) { $commonArgs['ApplyRules'] = $true }
    if ($UseSignal) { $commonArgs['UseSignal'] = $true }
    if ($UseTwilio) { $commonArgs['UseTwilio'] = $true }

    if ($Engine -eq 'suricata') {
        $script = Join-Path $PSScriptRoot 'Start-CtgSuricataIDS.ps1'
        $commonArgs['Interface'] = $TetherIface.SuricataName
        Write-TetherLog "Starting Suricata on tether iface $($TetherIface.SuricataName)" 'Cyan'
        & $script @commonArgs
        return $LASTEXITCODE
    }

    $script = Join-Path $PSScriptRoot 'Start-CtgSnortIDS.ps1'
    $commonArgs['Interface'] = $TetherIface.SnortIndex
    if ($UseWiresharkFallback) { $commonArgs['UseWiresharkFallback'] = $true }
    Write-TetherLog "Starting Snort on tether iface index $($TetherIface.SnortIndex)" 'Cyan'
    & $script @commonArgs
    return $LASTEXITCODE
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ' CTG iPhone tether egress IDS (lab)' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan

if ($TestAlert) { Invoke-CtgTetherTestAlert }

if ($DiagnoseOnly) {
    $result = Invoke-CtgTetherDiagnose
    exit $(if ($result) { 0 } else { 1 })
}

$tether = Get-CtgIphoneTetherInterface -ManualInterface $Interface
if (-not $tether) {
    Write-TetherLog 'No iPhone tether interface detected. Use -DiagnoseOnly or -Interface override.' 'Red'
    Write-TetherLog 'Enable Personal Hotspot (Wi-Fi) or USB tether on the phone first.' 'Yellow'
    exit 1
}

$engine = Get-CtgPreferredIdsEngine
if (-not $engine) {
    if ($UseWiresharkFallback) {
        $engine = 'snort'
    } else {
        Write-TetherLog 'Neither Snort nor Suricata installed. Run Install-CtgSuricataWindows.ps1 or -UseWiresharkFallback' 'Red'
        exit 1
    }
}

Write-TetherLog "Tether monitor: $($tether.Name) score=$($tether.Score) engine=$engine"
Write-TetherLog "Reasons: $($tether.Reasons)"
Write-TetherLog 'BLE/cellular air interfaces stay on phone - laptop sees NAT IP traffic only' 'Gray'

if (-not $SkipChecklist) {
    Invoke-CtgTetherChecklist
}

exit (Invoke-CtgTetherIdsRun -TetherIface $tether -Engine $engine)
