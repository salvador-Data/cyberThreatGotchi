<#
.SYNOPSIS
  Poll Kali Suricata EVE JSON from ctg-backups share and send rate-limited alerts.

.DESCRIPTION
  Reads staged EVE from Backups\logs\kali-suricata\ or SIEM export ctg-siem-latest.json.
  Kali guest stages logs via ctg-suricata-ips-sms.sh (ctg-ids-ips-autorun.sh primary).
  Alerts via Send-CtgIdsAlert.ps1 - Signal preferred on Windows host; Twilio fallback.

.PARAMETER RunMinutes
  Minutes to poll (default 60). Use 0 for one poll cycle.

.PARAMETER PollSeconds
  Poll interval (default 30).

.PARAMETER NoSms
  Log alerts only.

.PARAMETER BlockRepeatOffender
  netsh inbound block for external repeat offenders on high/critical (lab only).

.PARAMETER TestAlert
  Send test alert without reading Kali logs.

.EXAMPLE
  .\scripts\windows\Start-CtgKaliSuricataSmsBridge.ps1 -RunMinutes 120

.EXAMPLE
  .\scripts\windows\Start-CtgKaliSuricataSmsBridge.ps1 -TestAlert
#>
[CmdletBinding()]
param(
    [int] $RunMinutes = 60,
    [int] $PollSeconds = 30,
    [switch] $NoSms,
    [switch] $UseSignal,
    [switch] $UseTwilio,
    [switch] $BlockRepeatOffender,
    [switch] $TestAlert
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
. (Join-Path $PSScriptRoot 'CTG-SuricataCommon.ps1')

$repo = Get-CtgRepoRoot
Import-CtgDotEnv -EnvPath (Join-Path $repo '.env')
$bridge = Get-CtgKaliSuricataBridgePaths
$paths = Get-CtgSuricataPaths

function Write-BridgeLog {
    param([string] $Message, [string] $Color = 'Gray')
    Write-CtgSuricataLog $Message $bridge.BridgeLog $Color
}

function Invoke-CtgBridgeTestAlert {
    $alertScript = Join-Path $PSScriptRoot 'Send-CtgIdsAlert.ps1'
    $msg = 'CTG Suricata: [info] sid 9000001 - review log'
    Write-BridgeLog "Sending test alert: $msg" 'Cyan'
    $args = @{
        AlertType   = 'suricata-kali-test'
        Severity    = 'info'
        Message     = $msg
        TestMessage = $true
    }
    if ($UseSignal) { $args['UseSignal'] = $true }
    if ($UseTwilio) { $args['UseTwilio'] = $true }
    & $alertScript @args
    exit $LASTEXITCODE
}

function Get-CtgKaliEveLines {
    if (Test-Path $bridge.KaliEveStaging) {
        try {
            return Get-Content $bridge.KaliEveStaging -Encoding utf8 -ErrorAction Stop
        } catch { }
    }
    if (Test-Path $bridge.SiemLatest) {
        try {
            $siem = Get-Content $bridge.SiemLatest -Raw -Encoding utf8 | ConvertFrom-Json
            if ($siem.suricata_eve_tail) {
                return @($siem.suricata_eve_tail)
            }
        } catch { }
    }
    return @()
}

function Read-CtgKaliBridgeNewAlerts {
    $lines = Get-CtgKaliEveLines
    if ($lines.Count -eq 0) { return @() }

    $sourcePath = if (Test-Path $bridge.KaliEveStaging) { $bridge.KaliEveStaging } else { $bridge.SiemLatest }
    $state = Read-CtgSuricataTailState -StatePath $bridge.StateFile
    $file = Get-Item $sourcePath
    $inode = "$($file.FullName)|$($file.Length)|$($file.LastWriteTimeUtc.Ticks)"
    $offset = $state.Offset

    if ($sourcePath -eq $bridge.KaliEveStaging) {
        if ($state.Inode -and $state.Inode -ne $inode) { $offset = 0 }
        if ($offset -gt $file.Length) { $offset = 0 }
        $fs = [System.IO.File]::Open($sourcePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        try {
            $fs.Seek($offset, [System.IO.SeekOrigin]::Begin) | Out-Null
            $reader = New-Object System.IO.StreamReader($fs)
            $text = $reader.ReadToEnd()
            $newOffset = $fs.Position
        } finally {
            $fs.Dispose()
        }
        Save-CtgSuricataTailState -StatePath $bridge.StateFile -Offset $newOffset -Inode $inode
        $newLines = $text -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        return Parse-CtgSuricataEveJsonLines -Lines $newLines
    }

    $hash = ($lines -join "`n").GetHashCode()
    $hashKey = "siem|$hash"
    if ($state.Inode -eq $hashKey) { return @() }
    Save-CtgSuricataTailState -StatePath $bridge.StateFile -Offset $lines.Count -Inode $hashKey
    return Parse-CtgSuricataEveJsonLines -Lines $lines
}

function Invoke-CtgBridgeAlert {
    param([object] $Alert)
    if ($NoSms) { return }
    if ($Alert.Severity -notin @('high', 'critical')) { return }
    $sid = if ($Alert.Sid) { $Alert.Sid } else { 'unknown' }
    $alertScript = Join-Path $PSScriptRoot 'Send-CtgIdsAlert.ps1'
    $msg = "CTG Suricata: [$($Alert.Severity)] sid $sid - review log"
    $args = @{
        AlertType = "suricata-kali-sid-$sid"
        Severity  = $Alert.Severity
        Message   = $msg
    }
    if ($UseSignal) { $args['UseSignal'] = $true }
    if ($UseTwilio) { $args['UseTwilio'] = $true }
    & $alertScript @args 2>&1 | ForEach-Object { Write-BridgeLog $_ }
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ' CTG Kali Suricata Alert Bridge' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan

if ($TestAlert) {
    Invoke-CtgBridgeTestAlert
}

New-Item -ItemType Directory -Path (Split-Path $bridge.KaliEveStaging -Parent) -Force | Out-Null
Write-BridgeLog "Bridge start staging=$($bridge.KaliEveStaging) siem=$($bridge.SiemLatest)"

$deadline = if ($RunMinutes -gt 0) { (Get-Date).AddMinutes($RunMinutes) } else { (Get-Date).AddSeconds($PollSeconds) }

while ((Get-Date) -lt $deadline) {
    $alerts = Read-CtgKaliBridgeNewAlerts
    foreach ($alert in $alerts) {
        Write-BridgeLog "KALI ALERT [$($alert.Severity)] sid=$($alert.Sid) $($alert.Message)" `
            $(if ($alert.Severity -in @('high','critical')) { 'Red' } else { 'Yellow' })
        Invoke-CtgBridgeAlert -Alert $alert
        if ($BlockRepeatOffender -and $alert.Severity -in @('high', 'critical') -and $alert.SrcIp) {
            Invoke-CtgBlockRepeatOffender -RemoteIp $alert.SrcIp -LogFile $bridge.BridgeLog | Out-Null
        }
    }
    if ((Get-Date) -ge $deadline) { break }
    Start-Sleep -Seconds $PollSeconds
}

Write-BridgeLog 'Kali Suricata bridge cycle complete' 'Green'
