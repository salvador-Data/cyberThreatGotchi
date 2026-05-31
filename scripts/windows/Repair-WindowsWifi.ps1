<#
.SYNOPSIS
  Diagnose and conservatively repair Windows Wi-Fi (WLAN) connectivity.

.DESCRIPTION
  Read-only by default (-DiagnoseOnly). Safe fixes (-ApplyFixes, Administrator recommended):
  restart WlanSvc, enable disabled Wi-Fi adapters, flush DNS cache only.

  Does NOT delete saved Wi-Fi profiles, reset Winsock/IP stack, or change DNS servers unless
  you pass -ResetStack (stack reset only; still no DNS server changes).

  Preserves DuckDuckGo VPN and documents DDG DNS (94.140.14.14 / 94.140.15.15).

.PARAMETER DiagnoseOnly
  Report WLAN service, adapters, interfaces, profiles (names only), DNS (default).

.PARAMETER ApplyFixes
  WlanSvc restart, enable Wi-Fi adapters, ipconfig /flushdns. No profile deletes.

.PARAMETER ResetStack
  With -ApplyFixes: netsh winsock reset and netsh int ip reset (reboot required).

.PARAMETER LabWpa3ProfileXml
  Optional path to one WLAN profile XML (lab SSID). Adds/updates that profile only.

.EXAMPLE
  .\scripts\windows\Repair-WindowsWifi.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Run-AsAdmin.ps1 -TargetScript .\scripts\windows\Repair-WindowsWifi.ps1 -TargetArguments '-ApplyFixes'
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch] $DiagnoseOnly,
    [switch] $ApplyFixes,
    [switch] $ResetStack,
    [string] $LabWpa3ProfileXml = '',
    [string] $LogDir = ''
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
$DdgDnsServers = @('94.140.14.14', '94.140.15.15')

function Write-CtgSection([string]$Title) {
    Write-Host ''
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Write-CtgFinding([string]$Label, [string]$Value, [string]$Severity = 'Info') {
    $color = switch ($Severity) { 'Warn' { 'Yellow' } 'Fail' { 'Red' } 'Ok' { 'Green' } default { 'Gray' } }
    Write-Host ("  {0,-32} {1}" -f ($Label + ':'), $Value) -ForegroundColor $color
}

function Get-CtgLogPath {
    param([string]$Dir)
    if (-not $Dir) { $Dir = Join-Path $env:USERPROFILE 'Backups\logs' }
    if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
    Join-Path $Dir 'repair-windows-wifi.log'
}

function Add-CtgLogLine { param([string]$Path, [string]$Line); Add-Content -Path $Path -Value $Line -Encoding UTF8 }

function Get-CtgWifiAdapters {
    Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
        $_.PhysicalMediaType -eq 'Native 802.11' -or $_.InterfaceDescription -match 'Wi-?Fi|Wireless|802\.11|WLAN'
    }
}

function Get-CtgDdgDnsOnAdapters {
    $hits = @()
    try {
        Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object {
            $servers = @($_.ServerAddresses | Where-Object { $_ })
            $ddg = $servers | Where-Object { $_ -in $DdgDnsServers }
            if ($ddg) {
                $hits += [PSCustomObject]@{ InterfaceAlias = $_.InterfaceAlias; DdgServers = ($ddg -join ', ') }
            }
        }
    } catch { }
    $hits
}

function Get-CtgWlanProfileNames {
    $names = @()
    try {
        $out = netsh wlan show profiles 2>&1 | Out-String
        foreach ($line in ($out -split "`r?`n")) {
            if ($line -match 'All User Profile\s*:\s*(.+)') { $names += $Matches[1].Trim() }
        }
    } catch { }
    $names
}


function Get-CtgWlanProfileSecurity {
    param([string] $ProfileName)
    $out = netsh wlan show profile "name=$ProfileName" 2>&1 | Out-String
    $auths = [regex]::Matches($out, '(?m)^\s*Authentication\s*:\s*(.+)
    try {
        $out = netsh wlan show interfaces 2>&1 | Out-String
        if ($out -match 'There is no wireless interface') {
            return @{ Connected = $false; Ssid = ''; State = 'No interface' }
        }
        $ssid = ''; $state = ''
        if ($out -match 'SSID\s*:\s*(.+)') { $ssid = $Matches[1].Trim() }
        if ($out -match 'State\s*:\s*(.+)') { $state = $Matches[1].Trim() }
        @{ Connected = ($state -match 'connected'); Ssid = $ssid; State = $state }
    } catch {
        @{ Connected = $false; Ssid = ''; State = 'Error' }
    }
}

function Show-CtgWpa3Documentation {
    Write-CtgSection 'WPA3 (documentation only - router + optional lab profile)'
    $lines = @(
        '  Home router (manual): enable WPA3-Personal (SAE) or WPA2/WPA3 mixed; prefer 802.11w (PMF).',
        '  Lab profile: export with netsh wlan export; import via -LabWpa3ProfileXml (one SSID only).',
        '  See docs/WINDOWS_WIFI_WPA3.md and docs/CTG_LAB_AUTORUN.md.'
    )
    Write-Host ($lines -join [Environment]::NewLine) -ForegroundColor Gray
}

function Invoke-CtgDiagnoseWifi {
    param([ref]$LogLines)
    Write-CtgSection 'WLAN service (WlanSvc)'
    $wlanSvc = Get-Service -Name 'WlanSvc' -ErrorAction SilentlyContinue
    if ($wlanSvc) {
        Write-CtgFinding 'WlanSvc status' $wlanSvc.Status.ToString() $(if ($wlanSvc.Status -eq 'Running') { 'Ok' } else { 'Warn' })
        [void]$LogLines.Value.Add("WlanSvc=$($wlanSvc.Status)")
    } else {
        Write-CtgFinding 'WlanSvc' 'Not found' 'Fail'
        [void]$LogLines.Value.Add('WlanSvc=Missing')
    }
    Write-CtgSection 'Wi-Fi adapters'
    $adapters = @(Get-CtgWifiAdapters)
    if ($adapters.Count -eq 0) {
        Write-CtgFinding 'Adapters' 'None detected' 'Fail'
        [void]$LogLines.Value.Add('Adapters=0')
    } else {
        foreach ($a in $adapters) {
            $sev = if ($a.Status -eq 'Up') { 'Ok' } else { 'Warn' }
            Write-CtgFinding $a.Name "$($a.Status) | $($a.InterfaceDescription)" $sev
            [void]$LogLines.Value.Add("Adapter.$($a.Name)=$($a.Status)")
        }
    }
    Write-CtgSection 'WLAN interface (netsh)'
    $iface = Get-CtgWlanInterfaceReport
    Write-CtgFinding 'State' $iface.State $(if ($iface.Connected) { 'Ok' } else { 'Warn' })
    if ($iface.Ssid) { Write-CtgFinding 'SSID' $iface.Ssid }
    try {
        $detail = netsh wlan show interfaces 2>&1 | Out-String
        if ($detail -match 'Authentication\s*:\s*(.+)') { Write-CtgFinding 'Live authentication' $Matches[1].Trim() }
        if ($detail -match 'Cipher\s*:\s*(.+)') { Write-CtgFinding 'Live cipher' $Matches[1].Trim() }
        if ($detail -match 'Band\s*:\s*(.+)') { Write-CtgFinding 'Band' $Matches[1].Trim() }
    } catch { }
    [void]$LogLines.Value.Add("WlanState=$($iface.State) SSID=$($iface.Ssid)")
    Write-CtgSection 'Saved profiles (not deleted by this script)'
    $profiles = Get-CtgWlanProfileNames
    Write-CtgFinding 'Profile count' $profiles.Count
    [void]$LogLines.Value.Add("ProfileCount=$($profiles.Count)")
    Write-CtgSection 'DNS client (DDG preserve check)'
    $ddgDns = @(Get-CtgDdgDnsOnAdapters)
    if ($ddgDns.Count -gt 0) {
        foreach ($row in $ddgDns) { Write-CtgFinding $row.InterfaceAlias "DDG DNS: $($row.DdgServers)" 'Ok' }
        Write-CtgFinding 'Note' 'Flush DNS only - server list unchanged' 'Ok'
        [void]$LogLines.Value.Add('DdgDns=Present')
    } else {
        Write-CtgFinding 'DuckDuckGo DNS' 'Not on adapter IPv4 (may use VPN DNS)' 'Info'
        [void]$LogLines.Value.Add('DdgDns=NotOnAdapters')
    }
    $preserveScript = Join-Path $PSScriptRoot 'Preserve-DuckDuckGoVpn.ps1'
    if (Test-Path $preserveScript) {
        . $preserveScript
        Invoke-CtgPreserveDuckDuckGoVpn -LogAction { param($m) Write-Host "  $m" -ForegroundColor Gray }
    }
    Show-CtgWpa3Documentation
}

function Invoke-CtgApplyWifiFixes {
    param([ref]$LogLines)
    if (-not (Test-CtgIsAdmin)) {
        Write-CtgFinding 'ApplyFixes' 'Skipped - run elevated (Run-AsAdmin.ps1)' 'Warn'
        [void]$LogLines.Value.Add('ApplyFixes=SkippedNotAdmin')
        return
    }
    Write-CtgSection 'Safe fixes (WlanSvc, adapter enable, DNS flush)'
    $wlanSvc = Get-Service -Name 'WlanSvc' -ErrorAction SilentlyContinue
    if ($wlanSvc -and $PSCmdlet.ShouldProcess('WlanSvc', 'Restart')) {
        try {
            if ($wlanSvc.Status -ne 'Running') { Start-Service -Name 'WlanSvc' -ErrorAction Stop; Write-CtgFinding 'WlanSvc' 'Started' 'Ok' }
            else { Restart-Service -Name 'WlanSvc' -Force -ErrorAction Stop; Write-CtgFinding 'WlanSvc' 'Restarted' 'Ok' }
            [void]$LogLines.Value.Add('Fix.WlanSvc=OK')
        } catch {
            Write-CtgFinding 'WlanSvc' $_.Exception.Message 'Fail'
            [void]$LogLines.Value.Add('Fix.WlanSvc=Fail')
        }
    }
    foreach ($a in @(Get-CtgWifiAdapters)) {
        if ($a.Status -eq 'Disabled' -and $PSCmdlet.ShouldProcess($a.Name, 'Enable-NetAdapter')) {
            try {
                Enable-NetAdapter -Name $a.Name -Confirm:$false -ErrorAction Stop
                Write-CtgFinding "Enabled $($a.Name)" 'OK' 'Ok'
                [void]$LogLines.Value.Add("Fix.Enable.$($a.Name)=OK")
            } catch {
                Write-CtgFinding "Enable $($a.Name)" $_.Exception.Message 'Warn'
            }
        }
    }
    if ($PSCmdlet.ShouldProcess('DNS cache', 'Flush')) {
        ipconfig /flushdns | Out-Null
        Write-CtgFinding 'DNS cache' 'Flushed' 'Ok'
        [void]$LogLines.Value.Add('Fix.FlushDns=OK')
    }
    if ($ResetStack -and $PSCmdlet.ShouldProcess('stack', 'Reset')) {
        netsh winsock reset | Out-Null
        netsh int ip reset | Out-Null
        Write-CtgFinding 'Stack reset' 'Done - reboot required' 'Warn'
        [void]$LogLines.Value.Add('Fix.ResetStack=OK')
    } else {
        Write-CtgFinding 'Avoided' 'winsock/ip reset (use -ResetStack)' 'Info'
        [void]$LogLines.Value.Add('Avoided.StackReset=Yes')
    }
    if ($RemoveBrokenProfiles) {
        foreach ($n in @(Get-CtgWlanProfileNames)) {
            if ($n -eq '*') {
                if ($PSCmdlet.ShouldProcess($n, 'Remove broken profile')) {
                    netsh wlan delete profile "name=$n" | Out-Null
                    Write-CtgFinding 'Removed broken' $n 'Warn'
                    [void]$LogLines.Value.Add("Fix.RemoveBroken=$n")
                }
            }
        }
    } else {
        Write-CtgFinding 'Avoided' 'Mass profile deletion; use -RemoveBrokenProfiles for * etc.' 'Info'
    }
    Write-CtgFinding 'Avoided' 'DNS server changes (DDG VPN/DNS preserved)' 'Info'
    if ($LabWpa3ProfileXml -and (Test-Path -LiteralPath $LabWpa3ProfileXml) -and $PSCmdlet.ShouldProcess($LabWpa3ProfileXml, 'Import profile')) {
        netsh wlan add profile filename="$LabWpa3ProfileXml" user=all | Out-Null
        Write-CtgFinding 'Lab profile' 'Imported' 'Ok'
    }
}

if (-not $ApplyFixes -and -not $DiagnoseOnly) { $DiagnoseOnly = $true }
$logPath = Get-CtgLogPath -Dir $LogDir
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$lines = [System.Collections.Generic.List[string]]::new()
[void]$lines.Add("[$stamp] Repair-WindowsWifi ApplyFixes=$ApplyFixes ResetStack=$ResetStack Admin=$(Test-CtgIsAdmin)")
Write-Host ''
Write-Host 'CyberThreatGotchi - Windows Wi-Fi repair (conservative)' -ForegroundColor Cyan
$logRef = [ref]$lines
Invoke-CtgDiagnoseWifi -LogLines $logRef
if ($ListProfiles) { Show-CtgWlanProfileList }
if ($PreferWpa3) { Invoke-CtgPreferWpa3Client -LogLines $logRef }
if ($ApplyFixes) { Invoke-CtgApplyWifiFixes -LogLines $logRef }
else {
    Write-CtgSection 'Next step'
    Write-Host '  Run-AsAdmin.ps1 with Repair-WindowsWifi.ps1 -ApplyFixes' -ForegroundColor Gray
}
[void]$lines.Add('Complete')
foreach ($line in $lines) { Add-CtgLogLine -Path $logPath -Line $line }
Write-CtgFinding 'Log' $logPath 'Ok') | ForEach-Object { <#
.SYNOPSIS
  Diagnose and conservatively repair Windows Wi-Fi (WLAN) connectivity.

.DESCRIPTION
  Read-only by default (-DiagnoseOnly). Safe fixes (-ApplyFixes, Administrator recommended):
  restart WlanSvc, enable disabled Wi-Fi adapters, flush DNS cache only.

  Does NOT delete saved Wi-Fi profiles, reset Winsock/IP stack, or change DNS servers unless
  you pass -ResetStack (stack reset only; still no DNS server changes).

  Preserves DuckDuckGo VPN and documents DDG DNS (94.140.14.14 / 94.140.15.15).

.PARAMETER DiagnoseOnly
  Report WLAN service, adapters, interfaces, profiles (names only), DNS (default).

.PARAMETER ApplyFixes
  WlanSvc restart, enable Wi-Fi adapters, ipconfig /flushdns. No profile deletes.

.PARAMETER ResetStack
  With -ApplyFixes: netsh winsock reset and netsh int ip reset (reboot required).

.PARAMETER LabWpa3ProfileXml
  Optional path to one WLAN profile XML (lab SSID). Adds/updates that profile only.

.EXAMPLE
  .\scripts\windows\Repair-WindowsWifi.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Run-AsAdmin.ps1 -TargetScript .\scripts\windows\Repair-WindowsWifi.ps1 -TargetArguments '-ApplyFixes'
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch] $DiagnoseOnly,
    [switch] $ApplyFixes,
    [switch] $ResetStack,
    [string] $LabWpa3ProfileXml = '',
    [string] $LogDir = ''
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
$DdgDnsServers = @('94.140.14.14', '94.140.15.15')

function Write-CtgSection([string]$Title) {
    Write-Host ''
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Write-CtgFinding([string]$Label, [string]$Value, [string]$Severity = 'Info') {
    $color = switch ($Severity) { 'Warn' { 'Yellow' } 'Fail' { 'Red' } 'Ok' { 'Green' } default { 'Gray' } }
    Write-Host ("  {0,-32} {1}" -f ($Label + ':'), $Value) -ForegroundColor $color
}

function Get-CtgLogPath {
    param([string]$Dir)
    if (-not $Dir) { $Dir = Join-Path $env:USERPROFILE 'Backups\logs' }
    if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
    Join-Path $Dir 'repair-windows-wifi.log'
}

function Add-CtgLogLine { param([string]$Path, [string]$Line); Add-Content -Path $Path -Value $Line -Encoding UTF8 }

function Get-CtgWifiAdapters {
    Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
        $_.PhysicalMediaType -eq 'Native 802.11' -or $_.InterfaceDescription -match 'Wi-?Fi|Wireless|802\.11|WLAN'
    }
}

function Get-CtgDdgDnsOnAdapters {
    $hits = @()
    try {
        Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object {
            $servers = @($_.ServerAddresses | Where-Object { $_ })
            $ddg = $servers | Where-Object { $_ -in $DdgDnsServers }
            if ($ddg) {
                $hits += [PSCustomObject]@{ InterfaceAlias = $_.InterfaceAlias; DdgServers = ($ddg -join ', ') }
            }
        }
    } catch { }
    $hits
}

function Get-CtgWlanProfileNames {
    $names = @()
    try {
        $out = netsh wlan show profiles 2>&1 | Out-String
        foreach ($line in ($out -split "`r?`n")) {
            if ($line -match 'All User Profile\s*:\s*(.+)') { $names += $Matches[1].Trim() }
        }
    } catch { }
    $names
}

function Get-CtgWlanInterfaceReport {
    try {
        $out = netsh wlan show interfaces 2>&1 | Out-String
        if ($out -match 'There is no wireless interface') {
            return @{ Connected = $false; Ssid = ''; State = 'No interface' }
        }
        $ssid = ''; $state = ''
        if ($out -match 'SSID\s*:\s*(.+)') { $ssid = $Matches[1].Trim() }
        if ($out -match 'State\s*:\s*(.+)') { $state = $Matches[1].Trim() }
        @{ Connected = ($state -match 'connected'); Ssid = $ssid; State = $state }
    } catch {
        @{ Connected = $false; Ssid = ''; State = 'Error' }
    }
}

function Show-CtgWpa3Documentation {
    Write-CtgSection 'WPA3 (documentation only - router + optional lab profile)'
    $lines = @(
        '  Home router (manual): enable WPA3-Personal (SAE) or WPA2/WPA3 mixed; prefer 802.11w (PMF).',
        '  Lab profile: export with netsh wlan export; import via -LabWpa3ProfileXml (one SSID only).',
        '  See docs/WINDOWS_WIFI_WPA3.md and docs/CTG_LAB_AUTORUN.md.'
    )
    Write-Host ($lines -join [Environment]::NewLine) -ForegroundColor Gray
}

function Invoke-CtgDiagnoseWifi {
    param([ref]$LogLines)
    Write-CtgSection 'WLAN service (WlanSvc)'
    $wlanSvc = Get-Service -Name 'WlanSvc' -ErrorAction SilentlyContinue
    if ($wlanSvc) {
        Write-CtgFinding 'WlanSvc status' $wlanSvc.Status.ToString() $(if ($wlanSvc.Status -eq 'Running') { 'Ok' } else { 'Warn' })
        [void]$LogLines.Value.Add("WlanSvc=$($wlanSvc.Status)")
    } else {
        Write-CtgFinding 'WlanSvc' 'Not found' 'Fail'
        [void]$LogLines.Value.Add('WlanSvc=Missing')
    }
    Write-CtgSection 'Wi-Fi adapters'
    $adapters = @(Get-CtgWifiAdapters)
    if ($adapters.Count -eq 0) {
        Write-CtgFinding 'Adapters' 'None detected' 'Fail'
        [void]$LogLines.Value.Add('Adapters=0')
    } else {
        foreach ($a in $adapters) {
            $sev = if ($a.Status -eq 'Up') { 'Ok' } else { 'Warn' }
            Write-CtgFinding $a.Name "$($a.Status) | $($a.InterfaceDescription)" $sev
            [void]$LogLines.Value.Add("Adapter.$($a.Name)=$($a.Status)")
        }
    }
    Write-CtgSection 'WLAN interface (netsh)'
    $iface = Get-CtgWlanInterfaceReport
    Write-CtgFinding 'State' $iface.State $(if ($iface.Connected) { 'Ok' } else { 'Warn' })
    if ($iface.Ssid) { Write-CtgFinding 'SSID' $iface.Ssid }
    try {
        $detail = netsh wlan show interfaces 2>&1 | Out-String
        if ($detail -match 'Authentication\s*:\s*(.+)') { Write-CtgFinding 'Live authentication' $Matches[1].Trim() }
        if ($detail -match 'Cipher\s*:\s*(.+)') { Write-CtgFinding 'Live cipher' $Matches[1].Trim() }
        if ($detail -match 'Band\s*:\s*(.+)') { Write-CtgFinding 'Band' $Matches[1].Trim() }
    } catch { }
    [void]$LogLines.Value.Add("WlanState=$($iface.State) SSID=$($iface.Ssid)")
    Write-CtgSection 'Saved profiles (not deleted by this script)'
    $profiles = Get-CtgWlanProfileNames
    Write-CtgFinding 'Profile count' $profiles.Count
    [void]$LogLines.Value.Add("ProfileCount=$($profiles.Count)")
    Write-CtgSection 'DNS client (DDG preserve check)'
    $ddgDns = @(Get-CtgDdgDnsOnAdapters)
    if ($ddgDns.Count -gt 0) {
        foreach ($row in $ddgDns) { Write-CtgFinding $row.InterfaceAlias "DDG DNS: $($row.DdgServers)" 'Ok' }
        Write-CtgFinding 'Note' 'Flush DNS only - server list unchanged' 'Ok'
        [void]$LogLines.Value.Add('DdgDns=Present')
    } else {
        Write-CtgFinding 'DuckDuckGo DNS' 'Not on adapter IPv4 (may use VPN DNS)' 'Info'
        [void]$LogLines.Value.Add('DdgDns=NotOnAdapters')
    }
    $preserveScript = Join-Path $PSScriptRoot 'Preserve-DuckDuckGoVpn.ps1'
    if (Test-Path $preserveScript) {
        . $preserveScript
        Invoke-CtgPreserveDuckDuckGoVpn -LogAction { param($m) Write-Host "  $m" -ForegroundColor Gray }
    }
    Show-CtgWpa3Documentation
}

function Invoke-CtgApplyWifiFixes {
    param([ref]$LogLines)
    if (-not (Test-CtgIsAdmin)) {
        Write-CtgFinding 'ApplyFixes' 'Skipped - run elevated (Run-AsAdmin.ps1)' 'Warn'
        [void]$LogLines.Value.Add('ApplyFixes=SkippedNotAdmin')
        return
    }
    Write-CtgSection 'Safe fixes (WlanSvc, adapter enable, DNS flush)'
    $wlanSvc = Get-Service -Name 'WlanSvc' -ErrorAction SilentlyContinue
    if ($wlanSvc -and $PSCmdlet.ShouldProcess('WlanSvc', 'Restart')) {
        try {
            if ($wlanSvc.Status -ne 'Running') { Start-Service -Name 'WlanSvc' -ErrorAction Stop; Write-CtgFinding 'WlanSvc' 'Started' 'Ok' }
            else { Restart-Service -Name 'WlanSvc' -Force -ErrorAction Stop; Write-CtgFinding 'WlanSvc' 'Restarted' 'Ok' }
            [void]$LogLines.Value.Add('Fix.WlanSvc=OK')
        } catch {
            Write-CtgFinding 'WlanSvc' $_.Exception.Message 'Fail'
            [void]$LogLines.Value.Add('Fix.WlanSvc=Fail')
        }
    }
    foreach ($a in @(Get-CtgWifiAdapters)) {
        if ($a.Status -eq 'Disabled' -and $PSCmdlet.ShouldProcess($a.Name, 'Enable-NetAdapter')) {
            try {
                Enable-NetAdapter -Name $a.Name -Confirm:$false -ErrorAction Stop
                Write-CtgFinding "Enabled $($a.Name)" 'OK' 'Ok'
                [void]$LogLines.Value.Add("Fix.Enable.$($a.Name)=OK")
            } catch {
                Write-CtgFinding "Enable $($a.Name)" $_.Exception.Message 'Warn'
            }
        }
    }
    if ($PSCmdlet.ShouldProcess('DNS cache', 'Flush')) {
        ipconfig /flushdns | Out-Null
        Write-CtgFinding 'DNS cache' 'Flushed' 'Ok'
        [void]$LogLines.Value.Add('Fix.FlushDns=OK')
    }
    if ($ResetStack -and $PSCmdlet.ShouldProcess('stack', 'Reset')) {
        netsh winsock reset | Out-Null
        netsh int ip reset | Out-Null
        Write-CtgFinding 'Stack reset' 'Done - reboot required' 'Warn'
        [void]$LogLines.Value.Add('Fix.ResetStack=OK')
    } else {
        Write-CtgFinding 'Avoided' 'winsock/ip reset (use -ResetStack)' 'Info'
        [void]$LogLines.Value.Add('Avoided.StackReset=Yes')
    }
    if ($RemoveBrokenProfiles) {
        foreach ($n in @(Get-CtgWlanProfileNames)) {
            if ($n -eq '*') {
                if ($PSCmdlet.ShouldProcess($n, 'Remove broken profile')) {
                    netsh wlan delete profile "name=$n" | Out-Null
                    Write-CtgFinding 'Removed broken' $n 'Warn'
                    [void]$LogLines.Value.Add("Fix.RemoveBroken=$n")
                }
            }
        }
    } else {
        Write-CtgFinding 'Avoided' 'Mass profile deletion; use -RemoveBrokenProfiles for * etc.' 'Info'
    }
    Write-CtgFinding 'Avoided' 'DNS server changes (DDG VPN/DNS preserved)' 'Info'
    if ($LabWpa3ProfileXml -and (Test-Path -LiteralPath $LabWpa3ProfileXml) -and $PSCmdlet.ShouldProcess($LabWpa3ProfileXml, 'Import profile')) {
        netsh wlan add profile filename="$LabWpa3ProfileXml" user=all | Out-Null
        Write-CtgFinding 'Lab profile' 'Imported' 'Ok'
    }
}

if (-not $ApplyFixes -and -not $DiagnoseOnly) { $DiagnoseOnly = $true }
$logPath = Get-CtgLogPath -Dir $LogDir
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$lines = [System.Collections.Generic.List[string]]::new()
[void]$lines.Add("[$stamp] Repair-WindowsWifi ApplyFixes=$ApplyFixes ResetStack=$ResetStack Admin=$(Test-CtgIsAdmin)")
Write-Host ''
Write-Host 'CyberThreatGotchi - Windows Wi-Fi repair (conservative)' -ForegroundColor Cyan
$logRef = [ref]$lines
Invoke-CtgDiagnoseWifi -LogLines $logRef
if ($ListProfiles) { Show-CtgWlanProfileList }
if ($PreferWpa3) { Invoke-CtgPreferWpa3Client -LogLines $logRef }
if ($ApplyFixes) { Invoke-CtgApplyWifiFixes -LogLines $logRef }
else {
    Write-CtgSection 'Next step'
    Write-Host '  Run-AsAdmin.ps1 with Repair-WindowsWifi.ps1 -ApplyFixes' -ForegroundColor Gray
}
[void]$lines.Add('Complete')
foreach ($line in $lines) { Add-CtgLogLine -Path $logPath -Line $line }
Write-CtgFinding 'Log' $logPath 'Ok'.Groups[1].Value.Trim() } | Select-Object -Unique
    $ciphers = [regex]::Matches($out, '(?m)^\s*Cipher\s*:\s*(.+)
    try {
        $out = netsh wlan show interfaces 2>&1 | Out-String
        if ($out -match 'There is no wireless interface') {
            return @{ Connected = $false; Ssid = ''; State = 'No interface' }
        }
        $ssid = ''; $state = ''
        if ($out -match 'SSID\s*:\s*(.+)') { $ssid = $Matches[1].Trim() }
        if ($out -match 'State\s*:\s*(.+)') { $state = $Matches[1].Trim() }
        @{ Connected = ($state -match 'connected'); Ssid = $ssid; State = $state }
    } catch {
        @{ Connected = $false; Ssid = ''; State = 'Error' }
    }
}

function Show-CtgWpa3Documentation {
    Write-CtgSection 'WPA3 (documentation only - router + optional lab profile)'
    $lines = @(
        '  Home router (manual): enable WPA3-Personal (SAE) or WPA2/WPA3 mixed; prefer 802.11w (PMF).',
        '  Lab profile: export with netsh wlan export; import via -LabWpa3ProfileXml (one SSID only).',
        '  See docs/WINDOWS_WIFI_WPA3.md and docs/CTG_LAB_AUTORUN.md.'
    )
    Write-Host ($lines -join [Environment]::NewLine) -ForegroundColor Gray
}

function Invoke-CtgDiagnoseWifi {
    param([ref]$LogLines)
    Write-CtgSection 'WLAN service (WlanSvc)'
    $wlanSvc = Get-Service -Name 'WlanSvc' -ErrorAction SilentlyContinue
    if ($wlanSvc) {
        Write-CtgFinding 'WlanSvc status' $wlanSvc.Status.ToString() $(if ($wlanSvc.Status -eq 'Running') { 'Ok' } else { 'Warn' })
        [void]$LogLines.Value.Add("WlanSvc=$($wlanSvc.Status)")
    } else {
        Write-CtgFinding 'WlanSvc' 'Not found' 'Fail'
        [void]$LogLines.Value.Add('WlanSvc=Missing')
    }
    Write-CtgSection 'Wi-Fi adapters'
    $adapters = @(Get-CtgWifiAdapters)
    if ($adapters.Count -eq 0) {
        Write-CtgFinding 'Adapters' 'None detected' 'Fail'
        [void]$LogLines.Value.Add('Adapters=0')
    } else {
        foreach ($a in $adapters) {
            $sev = if ($a.Status -eq 'Up') { 'Ok' } else { 'Warn' }
            Write-CtgFinding $a.Name "$($a.Status) | $($a.InterfaceDescription)" $sev
            [void]$LogLines.Value.Add("Adapter.$($a.Name)=$($a.Status)")
        }
    }
    Write-CtgSection 'WLAN interface (netsh)'
    $iface = Get-CtgWlanInterfaceReport
    Write-CtgFinding 'State' $iface.State $(if ($iface.Connected) { 'Ok' } else { 'Warn' })
    if ($iface.Ssid) { Write-CtgFinding 'SSID' $iface.Ssid }
    try {
        $detail = netsh wlan show interfaces 2>&1 | Out-String
        if ($detail -match 'Authentication\s*:\s*(.+)') { Write-CtgFinding 'Live authentication' $Matches[1].Trim() }
        if ($detail -match 'Cipher\s*:\s*(.+)') { Write-CtgFinding 'Live cipher' $Matches[1].Trim() }
        if ($detail -match 'Band\s*:\s*(.+)') { Write-CtgFinding 'Band' $Matches[1].Trim() }
    } catch { }
    [void]$LogLines.Value.Add("WlanState=$($iface.State) SSID=$($iface.Ssid)")
    Write-CtgSection 'Saved profiles (not deleted by this script)'
    $profiles = Get-CtgWlanProfileNames
    Write-CtgFinding 'Profile count' $profiles.Count
    [void]$LogLines.Value.Add("ProfileCount=$($profiles.Count)")
    Write-CtgSection 'DNS client (DDG preserve check)'
    $ddgDns = @(Get-CtgDdgDnsOnAdapters)
    if ($ddgDns.Count -gt 0) {
        foreach ($row in $ddgDns) { Write-CtgFinding $row.InterfaceAlias "DDG DNS: $($row.DdgServers)" 'Ok' }
        Write-CtgFinding 'Note' 'Flush DNS only - server list unchanged' 'Ok'
        [void]$LogLines.Value.Add('DdgDns=Present')
    } else {
        Write-CtgFinding 'DuckDuckGo DNS' 'Not on adapter IPv4 (may use VPN DNS)' 'Info'
        [void]$LogLines.Value.Add('DdgDns=NotOnAdapters')
    }
    $preserveScript = Join-Path $PSScriptRoot 'Preserve-DuckDuckGoVpn.ps1'
    if (Test-Path $preserveScript) {
        . $preserveScript
        Invoke-CtgPreserveDuckDuckGoVpn -LogAction { param($m) Write-Host "  $m" -ForegroundColor Gray }
    }
    Show-CtgWpa3Documentation
}

function Invoke-CtgApplyWifiFixes {
    param([ref]$LogLines)
    if (-not (Test-CtgIsAdmin)) {
        Write-CtgFinding 'ApplyFixes' 'Skipped - run elevated (Run-AsAdmin.ps1)' 'Warn'
        [void]$LogLines.Value.Add('ApplyFixes=SkippedNotAdmin')
        return
    }
    Write-CtgSection 'Safe fixes (WlanSvc, adapter enable, DNS flush)'
    $wlanSvc = Get-Service -Name 'WlanSvc' -ErrorAction SilentlyContinue
    if ($wlanSvc -and $PSCmdlet.ShouldProcess('WlanSvc', 'Restart')) {
        try {
            if ($wlanSvc.Status -ne 'Running') { Start-Service -Name 'WlanSvc' -ErrorAction Stop; Write-CtgFinding 'WlanSvc' 'Started' 'Ok' }
            else { Restart-Service -Name 'WlanSvc' -Force -ErrorAction Stop; Write-CtgFinding 'WlanSvc' 'Restarted' 'Ok' }
            [void]$LogLines.Value.Add('Fix.WlanSvc=OK')
        } catch {
            Write-CtgFinding 'WlanSvc' $_.Exception.Message 'Fail'
            [void]$LogLines.Value.Add('Fix.WlanSvc=Fail')
        }
    }
    foreach ($a in @(Get-CtgWifiAdapters)) {
        if ($a.Status -eq 'Disabled' -and $PSCmdlet.ShouldProcess($a.Name, 'Enable-NetAdapter')) {
            try {
                Enable-NetAdapter -Name $a.Name -Confirm:$false -ErrorAction Stop
                Write-CtgFinding "Enabled $($a.Name)" 'OK' 'Ok'
                [void]$LogLines.Value.Add("Fix.Enable.$($a.Name)=OK")
            } catch {
                Write-CtgFinding "Enable $($a.Name)" $_.Exception.Message 'Warn'
            }
        }
    }
    if ($PSCmdlet.ShouldProcess('DNS cache', 'Flush')) {
        ipconfig /flushdns | Out-Null
        Write-CtgFinding 'DNS cache' 'Flushed' 'Ok'
        [void]$LogLines.Value.Add('Fix.FlushDns=OK')
    }
    if ($ResetStack -and $PSCmdlet.ShouldProcess('stack', 'Reset')) {
        netsh winsock reset | Out-Null
        netsh int ip reset | Out-Null
        Write-CtgFinding 'Stack reset' 'Done - reboot required' 'Warn'
        [void]$LogLines.Value.Add('Fix.ResetStack=OK')
    } else {
        Write-CtgFinding 'Avoided' 'winsock/ip reset (use -ResetStack)' 'Info'
        [void]$LogLines.Value.Add('Avoided.StackReset=Yes')
    }
    if ($RemoveBrokenProfiles) {
        foreach ($n in @(Get-CtgWlanProfileNames)) {
            if ($n -eq '*') {
                if ($PSCmdlet.ShouldProcess($n, 'Remove broken profile')) {
                    netsh wlan delete profile "name=$n" | Out-Null
                    Write-CtgFinding 'Removed broken' $n 'Warn'
                    [void]$LogLines.Value.Add("Fix.RemoveBroken=$n")
                }
            }
        }
    } else {
        Write-CtgFinding 'Avoided' 'Mass profile deletion; use -RemoveBrokenProfiles for * etc.' 'Info'
    }
    Write-CtgFinding 'Avoided' 'DNS server changes (DDG VPN/DNS preserved)' 'Info'
    if ($LabWpa3ProfileXml -and (Test-Path -LiteralPath $LabWpa3ProfileXml) -and $PSCmdlet.ShouldProcess($LabWpa3ProfileXml, 'Import profile')) {
        netsh wlan add profile filename="$LabWpa3ProfileXml" user=all | Out-Null
        Write-CtgFinding 'Lab profile' 'Imported' 'Ok'
    }
}

if (-not $ApplyFixes -and -not $DiagnoseOnly) { $DiagnoseOnly = $true }
$logPath = Get-CtgLogPath -Dir $LogDir
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$lines = [System.Collections.Generic.List[string]]::new()
[void]$lines.Add("[$stamp] Repair-WindowsWifi ApplyFixes=$ApplyFixes ResetStack=$ResetStack Admin=$(Test-CtgIsAdmin)")
Write-Host ''
Write-Host 'CyberThreatGotchi - Windows Wi-Fi repair (conservative)' -ForegroundColor Cyan
$logRef = [ref]$lines
Invoke-CtgDiagnoseWifi -LogLines $logRef
if ($ListProfiles) { Show-CtgWlanProfileList }
if ($PreferWpa3) { Invoke-CtgPreferWpa3Client -LogLines $logRef }
if ($ApplyFixes) { Invoke-CtgApplyWifiFixes -LogLines $logRef }
else {
    Write-CtgSection 'Next step'
    Write-Host '  Run-AsAdmin.ps1 with Repair-WindowsWifi.ps1 -ApplyFixes' -ForegroundColor Gray
}
[void]$lines.Add('Complete')
foreach ($line in $lines) { Add-CtgLogLine -Path $logPath -Line $line }
Write-CtgFinding 'Log' $logPath 'Ok') | ForEach-Object { <#
.SYNOPSIS
  Diagnose and conservatively repair Windows Wi-Fi (WLAN) connectivity.

.DESCRIPTION
  Read-only by default (-DiagnoseOnly). Safe fixes (-ApplyFixes, Administrator recommended):
  restart WlanSvc, enable disabled Wi-Fi adapters, flush DNS cache only.

  Does NOT delete saved Wi-Fi profiles, reset Winsock/IP stack, or change DNS servers unless
  you pass -ResetStack (stack reset only; still no DNS server changes).

  Preserves DuckDuckGo VPN and documents DDG DNS (94.140.14.14 / 94.140.15.15).

.PARAMETER DiagnoseOnly
  Report WLAN service, adapters, interfaces, profiles (names only), DNS (default).

.PARAMETER ApplyFixes
  WlanSvc restart, enable Wi-Fi adapters, ipconfig /flushdns. No profile deletes.

.PARAMETER ResetStack
  With -ApplyFixes: netsh winsock reset and netsh int ip reset (reboot required).

.PARAMETER LabWpa3ProfileXml
  Optional path to one WLAN profile XML (lab SSID). Adds/updates that profile only.

.EXAMPLE
  .\scripts\windows\Repair-WindowsWifi.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Run-AsAdmin.ps1 -TargetScript .\scripts\windows\Repair-WindowsWifi.ps1 -TargetArguments '-ApplyFixes'
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch] $DiagnoseOnly,
    [switch] $ApplyFixes,
    [switch] $ResetStack,
    [string] $LabWpa3ProfileXml = '',
    [string] $LogDir = ''
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
$DdgDnsServers = @('94.140.14.14', '94.140.15.15')

function Write-CtgSection([string]$Title) {
    Write-Host ''
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Write-CtgFinding([string]$Label, [string]$Value, [string]$Severity = 'Info') {
    $color = switch ($Severity) { 'Warn' { 'Yellow' } 'Fail' { 'Red' } 'Ok' { 'Green' } default { 'Gray' } }
    Write-Host ("  {0,-32} {1}" -f ($Label + ':'), $Value) -ForegroundColor $color
}

function Get-CtgLogPath {
    param([string]$Dir)
    if (-not $Dir) { $Dir = Join-Path $env:USERPROFILE 'Backups\logs' }
    if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
    Join-Path $Dir 'repair-windows-wifi.log'
}

function Add-CtgLogLine { param([string]$Path, [string]$Line); Add-Content -Path $Path -Value $Line -Encoding UTF8 }

function Get-CtgWifiAdapters {
    Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
        $_.PhysicalMediaType -eq 'Native 802.11' -or $_.InterfaceDescription -match 'Wi-?Fi|Wireless|802\.11|WLAN'
    }
}

function Get-CtgDdgDnsOnAdapters {
    $hits = @()
    try {
        Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object {
            $servers = @($_.ServerAddresses | Where-Object { $_ })
            $ddg = $servers | Where-Object { $_ -in $DdgDnsServers }
            if ($ddg) {
                $hits += [PSCustomObject]@{ InterfaceAlias = $_.InterfaceAlias; DdgServers = ($ddg -join ', ') }
            }
        }
    } catch { }
    $hits
}

function Get-CtgWlanProfileNames {
    $names = @()
    try {
        $out = netsh wlan show profiles 2>&1 | Out-String
        foreach ($line in ($out -split "`r?`n")) {
            if ($line -match 'All User Profile\s*:\s*(.+)') { $names += $Matches[1].Trim() }
        }
    } catch { }
    $names
}

function Get-CtgWlanInterfaceReport {
    try {
        $out = netsh wlan show interfaces 2>&1 | Out-String
        if ($out -match 'There is no wireless interface') {
            return @{ Connected = $false; Ssid = ''; State = 'No interface' }
        }
        $ssid = ''; $state = ''
        if ($out -match 'SSID\s*:\s*(.+)') { $ssid = $Matches[1].Trim() }
        if ($out -match 'State\s*:\s*(.+)') { $state = $Matches[1].Trim() }
        @{ Connected = ($state -match 'connected'); Ssid = $ssid; State = $state }
    } catch {
        @{ Connected = $false; Ssid = ''; State = 'Error' }
    }
}

function Show-CtgWpa3Documentation {
    Write-CtgSection 'WPA3 (documentation only - router + optional lab profile)'
    $lines = @(
        '  Home router (manual): enable WPA3-Personal (SAE) or WPA2/WPA3 mixed; prefer 802.11w (PMF).',
        '  Lab profile: export with netsh wlan export; import via -LabWpa3ProfileXml (one SSID only).',
        '  See docs/WINDOWS_WIFI_WPA3.md and docs/CTG_LAB_AUTORUN.md.'
    )
    Write-Host ($lines -join [Environment]::NewLine) -ForegroundColor Gray
}

function Invoke-CtgDiagnoseWifi {
    param([ref]$LogLines)
    Write-CtgSection 'WLAN service (WlanSvc)'
    $wlanSvc = Get-Service -Name 'WlanSvc' -ErrorAction SilentlyContinue
    if ($wlanSvc) {
        Write-CtgFinding 'WlanSvc status' $wlanSvc.Status.ToString() $(if ($wlanSvc.Status -eq 'Running') { 'Ok' } else { 'Warn' })
        [void]$LogLines.Value.Add("WlanSvc=$($wlanSvc.Status)")
    } else {
        Write-CtgFinding 'WlanSvc' 'Not found' 'Fail'
        [void]$LogLines.Value.Add('WlanSvc=Missing')
    }
    Write-CtgSection 'Wi-Fi adapters'
    $adapters = @(Get-CtgWifiAdapters)
    if ($adapters.Count -eq 0) {
        Write-CtgFinding 'Adapters' 'None detected' 'Fail'
        [void]$LogLines.Value.Add('Adapters=0')
    } else {
        foreach ($a in $adapters) {
            $sev = if ($a.Status -eq 'Up') { 'Ok' } else { 'Warn' }
            Write-CtgFinding $a.Name "$($a.Status) | $($a.InterfaceDescription)" $sev
            [void]$LogLines.Value.Add("Adapter.$($a.Name)=$($a.Status)")
        }
    }
    Write-CtgSection 'WLAN interface (netsh)'
    $iface = Get-CtgWlanInterfaceReport
    Write-CtgFinding 'State' $iface.State $(if ($iface.Connected) { 'Ok' } else { 'Warn' })
    if ($iface.Ssid) { Write-CtgFinding 'SSID' $iface.Ssid }
    try {
        $detail = netsh wlan show interfaces 2>&1 | Out-String
        if ($detail -match 'Authentication\s*:\s*(.+)') { Write-CtgFinding 'Live authentication' $Matches[1].Trim() }
        if ($detail -match 'Cipher\s*:\s*(.+)') { Write-CtgFinding 'Live cipher' $Matches[1].Trim() }
        if ($detail -match 'Band\s*:\s*(.+)') { Write-CtgFinding 'Band' $Matches[1].Trim() }
    } catch { }
    [void]$LogLines.Value.Add("WlanState=$($iface.State) SSID=$($iface.Ssid)")
    Write-CtgSection 'Saved profiles (not deleted by this script)'
    $profiles = Get-CtgWlanProfileNames
    Write-CtgFinding 'Profile count' $profiles.Count
    [void]$LogLines.Value.Add("ProfileCount=$($profiles.Count)")
    Write-CtgSection 'DNS client (DDG preserve check)'
    $ddgDns = @(Get-CtgDdgDnsOnAdapters)
    if ($ddgDns.Count -gt 0) {
        foreach ($row in $ddgDns) { Write-CtgFinding $row.InterfaceAlias "DDG DNS: $($row.DdgServers)" 'Ok' }
        Write-CtgFinding 'Note' 'Flush DNS only - server list unchanged' 'Ok'
        [void]$LogLines.Value.Add('DdgDns=Present')
    } else {
        Write-CtgFinding 'DuckDuckGo DNS' 'Not on adapter IPv4 (may use VPN DNS)' 'Info'
        [void]$LogLines.Value.Add('DdgDns=NotOnAdapters')
    }
    $preserveScript = Join-Path $PSScriptRoot 'Preserve-DuckDuckGoVpn.ps1'
    if (Test-Path $preserveScript) {
        . $preserveScript
        Invoke-CtgPreserveDuckDuckGoVpn -LogAction { param($m) Write-Host "  $m" -ForegroundColor Gray }
    }
    Show-CtgWpa3Documentation
}

function Invoke-CtgApplyWifiFixes {
    param([ref]$LogLines)
    if (-not (Test-CtgIsAdmin)) {
        Write-CtgFinding 'ApplyFixes' 'Skipped - run elevated (Run-AsAdmin.ps1)' 'Warn'
        [void]$LogLines.Value.Add('ApplyFixes=SkippedNotAdmin')
        return
    }
    Write-CtgSection 'Safe fixes (WlanSvc, adapter enable, DNS flush)'
    $wlanSvc = Get-Service -Name 'WlanSvc' -ErrorAction SilentlyContinue
    if ($wlanSvc -and $PSCmdlet.ShouldProcess('WlanSvc', 'Restart')) {
        try {
            if ($wlanSvc.Status -ne 'Running') { Start-Service -Name 'WlanSvc' -ErrorAction Stop; Write-CtgFinding 'WlanSvc' 'Started' 'Ok' }
            else { Restart-Service -Name 'WlanSvc' -Force -ErrorAction Stop; Write-CtgFinding 'WlanSvc' 'Restarted' 'Ok' }
            [void]$LogLines.Value.Add('Fix.WlanSvc=OK')
        } catch {
            Write-CtgFinding 'WlanSvc' $_.Exception.Message 'Fail'
            [void]$LogLines.Value.Add('Fix.WlanSvc=Fail')
        }
    }
    foreach ($a in @(Get-CtgWifiAdapters)) {
        if ($a.Status -eq 'Disabled' -and $PSCmdlet.ShouldProcess($a.Name, 'Enable-NetAdapter')) {
            try {
                Enable-NetAdapter -Name $a.Name -Confirm:$false -ErrorAction Stop
                Write-CtgFinding "Enabled $($a.Name)" 'OK' 'Ok'
                [void]$LogLines.Value.Add("Fix.Enable.$($a.Name)=OK")
            } catch {
                Write-CtgFinding "Enable $($a.Name)" $_.Exception.Message 'Warn'
            }
        }
    }
    if ($PSCmdlet.ShouldProcess('DNS cache', 'Flush')) {
        ipconfig /flushdns | Out-Null
        Write-CtgFinding 'DNS cache' 'Flushed' 'Ok'
        [void]$LogLines.Value.Add('Fix.FlushDns=OK')
    }
    if ($ResetStack -and $PSCmdlet.ShouldProcess('stack', 'Reset')) {
        netsh winsock reset | Out-Null
        netsh int ip reset | Out-Null
        Write-CtgFinding 'Stack reset' 'Done - reboot required' 'Warn'
        [void]$LogLines.Value.Add('Fix.ResetStack=OK')
    } else {
        Write-CtgFinding 'Avoided' 'winsock/ip reset (use -ResetStack)' 'Info'
        [void]$LogLines.Value.Add('Avoided.StackReset=Yes')
    }
    if ($RemoveBrokenProfiles) {
        foreach ($n in @(Get-CtgWlanProfileNames)) {
            if ($n -eq '*') {
                if ($PSCmdlet.ShouldProcess($n, 'Remove broken profile')) {
                    netsh wlan delete profile "name=$n" | Out-Null
                    Write-CtgFinding 'Removed broken' $n 'Warn'
                    [void]$LogLines.Value.Add("Fix.RemoveBroken=$n")
                }
            }
        }
    } else {
        Write-CtgFinding 'Avoided' 'Mass profile deletion; use -RemoveBrokenProfiles for * etc.' 'Info'
    }
    Write-CtgFinding 'Avoided' 'DNS server changes (DDG VPN/DNS preserved)' 'Info'
    if ($LabWpa3ProfileXml -and (Test-Path -LiteralPath $LabWpa3ProfileXml) -and $PSCmdlet.ShouldProcess($LabWpa3ProfileXml, 'Import profile')) {
        netsh wlan add profile filename="$LabWpa3ProfileXml" user=all | Out-Null
        Write-CtgFinding 'Lab profile' 'Imported' 'Ok'
    }
}

if (-not $ApplyFixes -and -not $DiagnoseOnly) { $DiagnoseOnly = $true }
$logPath = Get-CtgLogPath -Dir $LogDir
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$lines = [System.Collections.Generic.List[string]]::new()
[void]$lines.Add("[$stamp] Repair-WindowsWifi ApplyFixes=$ApplyFixes ResetStack=$ResetStack Admin=$(Test-CtgIsAdmin)")
Write-Host ''
Write-Host 'CyberThreatGotchi - Windows Wi-Fi repair (conservative)' -ForegroundColor Cyan
$logRef = [ref]$lines
Invoke-CtgDiagnoseWifi -LogLines $logRef
if ($ListProfiles) { Show-CtgWlanProfileList }
if ($PreferWpa3) { Invoke-CtgPreferWpa3Client -LogLines $logRef }
if ($ApplyFixes) { Invoke-CtgApplyWifiFixes -LogLines $logRef }
else {
    Write-CtgSection 'Next step'
    Write-Host '  Run-AsAdmin.ps1 with Repair-WindowsWifi.ps1 -ApplyFixes' -ForegroundColor Gray
}
[void]$lines.Add('Complete')
foreach ($line in $lines) { Add-CtgLogLine -Path $logPath -Line $line }
Write-CtgFinding 'Log' $logPath 'Ok'.Groups[1].Value.Trim() } | Select-Object -Unique
    $summary = if ($auths -contains 'WPA3-Personal') { 'WPA3-SAE (transition or pure)' }
               elseif ($auths -contains 'WPA2-Personal') { 'WPA2-PSK' }
               elseif ($auths -contains 'Open') { 'Open (remove)' }
               else { ($auths -join ' | ') }
    [PSCustomObject]@{ Name = $ProfileName; Auths = ($auths -join ' | '); Ciphers = ($ciphers -join ' | '); Summary = $summary }
}

function Show-CtgWlanProfileList {
    Write-CtgSection 'Profile security (-ListProfiles, no keys)'
    foreach ($n in (Get-CtgWlanProfileNames)) {
        $s = Get-CtgWlanProfileSecurity -ProfileName $n
        Write-CtgFinding $s.Name "$($s.Summary) [$($s.Auths)]"
    }
}

function Test-CtgWeakWifiProfile {
    param([string] $ProfileName)
    $s = Get-CtgWlanProfileSecurity -ProfileName $ProfileName
    if ($ProfileName -eq '*') { return $true }
    if ($s.Auths -match 'Open|WEP') { return $true }
    if ($s.Summary -match 'Open|WEP') { return $true }
    return $false
}

function Invoke-CtgPreferWpa3Client {
    param([ref]$LogLines)
    Write-CtgSection 'Prefer WPA3 (-PreferWpa3)'
    Write-CtgFinding 'Router/AP' 'Enable WPA2/WPA3 or WPA3-only + PMF on lab AP (script cannot change AP)' 'Info'
    Write-CtgFinding 'Client' 'Requires Win11 + driver WPA3-Personal (netsh wlan show drivers)' 'Info'
    $live = netsh wlan show interfaces 2>&1 | Out-String
    if ($live -match 'Authentication\s*:\s*(.+)') {
        Write-CtgFinding 'Live auth' $Matches[1].Trim() $(if ($Matches[1] -match 'WPA3') { 'Ok' } else { 'Warn' })
    }
    foreach ($n in @(Get-CtgWlanProfileNames)) {
        if (Test-CtgWeakWifiProfile -ProfileName $n) {
            if ($PSCmdlet.ShouldProcess($n, 'Remove weak Wi-Fi profile')) {
                netsh wlan delete profile "name=$n" | Out-Null
                Write-CtgFinding 'Removed' $n 'Warn'
                [void]$LogLines.Value.Add("PreferWpa3.Removed=$n")
            }
        }
    }
}
function Get-CtgWlanInterfaceReport {
    try {
        $out = netsh wlan show interfaces 2>&1 | Out-String
        if ($out -match 'There is no wireless interface') {
            return @{ Connected = $false; Ssid = ''; State = 'No interface' }
        }
        $ssid = ''; $state = ''
        if ($out -match 'SSID\s*:\s*(.+)') { $ssid = $Matches[1].Trim() }
        if ($out -match 'State\s*:\s*(.+)') { $state = $Matches[1].Trim() }
        @{ Connected = ($state -match 'connected'); Ssid = $ssid; State = $state }
    } catch {
        @{ Connected = $false; Ssid = ''; State = 'Error' }
    }
}

function Show-CtgWpa3Documentation {
    Write-CtgSection 'WPA3 (documentation only - router + optional lab profile)'
    $lines = @(
        '  Home router (manual): enable WPA3-Personal (SAE) or WPA2/WPA3 mixed; prefer 802.11w (PMF).',
        '  Lab profile: export with netsh wlan export; import via -LabWpa3ProfileXml (one SSID only).',
        '  See docs/WINDOWS_WIFI_WPA3.md and docs/CTG_LAB_AUTORUN.md.'
    )
    Write-Host ($lines -join [Environment]::NewLine) -ForegroundColor Gray
}

function Invoke-CtgDiagnoseWifi {
    param([ref]$LogLines)
    Write-CtgSection 'WLAN service (WlanSvc)'
    $wlanSvc = Get-Service -Name 'WlanSvc' -ErrorAction SilentlyContinue
    if ($wlanSvc) {
        Write-CtgFinding 'WlanSvc status' $wlanSvc.Status.ToString() $(if ($wlanSvc.Status -eq 'Running') { 'Ok' } else { 'Warn' })
        [void]$LogLines.Value.Add("WlanSvc=$($wlanSvc.Status)")
    } else {
        Write-CtgFinding 'WlanSvc' 'Not found' 'Fail'
        [void]$LogLines.Value.Add('WlanSvc=Missing')
    }
    Write-CtgSection 'Wi-Fi adapters'
    $adapters = @(Get-CtgWifiAdapters)
    if ($adapters.Count -eq 0) {
        Write-CtgFinding 'Adapters' 'None detected' 'Fail'
        [void]$LogLines.Value.Add('Adapters=0')
    } else {
        foreach ($a in $adapters) {
            $sev = if ($a.Status -eq 'Up') { 'Ok' } else { 'Warn' }
            Write-CtgFinding $a.Name "$($a.Status) | $($a.InterfaceDescription)" $sev
            [void]$LogLines.Value.Add("Adapter.$($a.Name)=$($a.Status)")
        }
    }
    Write-CtgSection 'WLAN interface (netsh)'
    $iface = Get-CtgWlanInterfaceReport
    Write-CtgFinding 'State' $iface.State $(if ($iface.Connected) { 'Ok' } else { 'Warn' })
    if ($iface.Ssid) { Write-CtgFinding 'SSID' $iface.Ssid }
    try {
        $detail = netsh wlan show interfaces 2>&1 | Out-String
        if ($detail -match 'Authentication\s*:\s*(.+)') { Write-CtgFinding 'Live authentication' $Matches[1].Trim() }
        if ($detail -match 'Cipher\s*:\s*(.+)') { Write-CtgFinding 'Live cipher' $Matches[1].Trim() }
        if ($detail -match 'Band\s*:\s*(.+)') { Write-CtgFinding 'Band' $Matches[1].Trim() }
    } catch { }
    [void]$LogLines.Value.Add("WlanState=$($iface.State) SSID=$($iface.Ssid)")
    Write-CtgSection 'Saved profiles (not deleted by this script)'
    $profiles = Get-CtgWlanProfileNames
    Write-CtgFinding 'Profile count' $profiles.Count
    [void]$LogLines.Value.Add("ProfileCount=$($profiles.Count)")
    Write-CtgSection 'DNS client (DDG preserve check)'
    $ddgDns = @(Get-CtgDdgDnsOnAdapters)
    if ($ddgDns.Count -gt 0) {
        foreach ($row in $ddgDns) { Write-CtgFinding $row.InterfaceAlias "DDG DNS: $($row.DdgServers)" 'Ok' }
        Write-CtgFinding 'Note' 'Flush DNS only - server list unchanged' 'Ok'
        [void]$LogLines.Value.Add('DdgDns=Present')
    } else {
        Write-CtgFinding 'DuckDuckGo DNS' 'Not on adapter IPv4 (may use VPN DNS)' 'Info'
        [void]$LogLines.Value.Add('DdgDns=NotOnAdapters')
    }
    $preserveScript = Join-Path $PSScriptRoot 'Preserve-DuckDuckGoVpn.ps1'
    if (Test-Path $preserveScript) {
        . $preserveScript
        Invoke-CtgPreserveDuckDuckGoVpn -LogAction { param($m) Write-Host "  $m" -ForegroundColor Gray }
    }
    Show-CtgWpa3Documentation
}

function Invoke-CtgApplyWifiFixes {
    param([ref]$LogLines)
    if (-not (Test-CtgIsAdmin)) {
        Write-CtgFinding 'ApplyFixes' 'Skipped - run elevated (Run-AsAdmin.ps1)' 'Warn'
        [void]$LogLines.Value.Add('ApplyFixes=SkippedNotAdmin')
        return
    }
    Write-CtgSection 'Safe fixes (WlanSvc, adapter enable, DNS flush)'
    $wlanSvc = Get-Service -Name 'WlanSvc' -ErrorAction SilentlyContinue
    if ($wlanSvc -and $PSCmdlet.ShouldProcess('WlanSvc', 'Restart')) {
        try {
            if ($wlanSvc.Status -ne 'Running') { Start-Service -Name 'WlanSvc' -ErrorAction Stop; Write-CtgFinding 'WlanSvc' 'Started' 'Ok' }
            else { Restart-Service -Name 'WlanSvc' -Force -ErrorAction Stop; Write-CtgFinding 'WlanSvc' 'Restarted' 'Ok' }
            [void]$LogLines.Value.Add('Fix.WlanSvc=OK')
        } catch {
            Write-CtgFinding 'WlanSvc' $_.Exception.Message 'Fail'
            [void]$LogLines.Value.Add('Fix.WlanSvc=Fail')
        }
    }
    foreach ($a in @(Get-CtgWifiAdapters)) {
        if ($a.Status -eq 'Disabled' -and $PSCmdlet.ShouldProcess($a.Name, 'Enable-NetAdapter')) {
            try {
                Enable-NetAdapter -Name $a.Name -Confirm:$false -ErrorAction Stop
                Write-CtgFinding "Enabled $($a.Name)" 'OK' 'Ok'
                [void]$LogLines.Value.Add("Fix.Enable.$($a.Name)=OK")
            } catch {
                Write-CtgFinding "Enable $($a.Name)" $_.Exception.Message 'Warn'
            }
        }
    }
    if ($PSCmdlet.ShouldProcess('DNS cache', 'Flush')) {
        ipconfig /flushdns | Out-Null
        Write-CtgFinding 'DNS cache' 'Flushed' 'Ok'
        [void]$LogLines.Value.Add('Fix.FlushDns=OK')
    }
    if ($ResetStack -and $PSCmdlet.ShouldProcess('stack', 'Reset')) {
        netsh winsock reset | Out-Null
        netsh int ip reset | Out-Null
        Write-CtgFinding 'Stack reset' 'Done - reboot required' 'Warn'
        [void]$LogLines.Value.Add('Fix.ResetStack=OK')
    } else {
        Write-CtgFinding 'Avoided' 'winsock/ip reset (use -ResetStack)' 'Info'
        [void]$LogLines.Value.Add('Avoided.StackReset=Yes')
    }
    if ($RemoveBrokenProfiles) {
        foreach ($n in @(Get-CtgWlanProfileNames)) {
            if ($n -eq '*') {
                if ($PSCmdlet.ShouldProcess($n, 'Remove broken profile')) {
                    netsh wlan delete profile "name=$n" | Out-Null
                    Write-CtgFinding 'Removed broken' $n 'Warn'
                    [void]$LogLines.Value.Add("Fix.RemoveBroken=$n")
                }
            }
        }
    } else {
        Write-CtgFinding 'Avoided' 'Mass profile deletion; use -RemoveBrokenProfiles for * etc.' 'Info'
    }
    Write-CtgFinding 'Avoided' 'DNS server changes (DDG VPN/DNS preserved)' 'Info'
    if ($LabWpa3ProfileXml -and (Test-Path -LiteralPath $LabWpa3ProfileXml) -and $PSCmdlet.ShouldProcess($LabWpa3ProfileXml, 'Import profile')) {
        netsh wlan add profile filename="$LabWpa3ProfileXml" user=all | Out-Null
        Write-CtgFinding 'Lab profile' 'Imported' 'Ok'
    }
}

if (-not $ApplyFixes -and -not $DiagnoseOnly) { $DiagnoseOnly = $true }
$logPath = Get-CtgLogPath -Dir $LogDir
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$lines = [System.Collections.Generic.List[string]]::new()
[void]$lines.Add("[$stamp] Repair-WindowsWifi ApplyFixes=$ApplyFixes ResetStack=$ResetStack Admin=$(Test-CtgIsAdmin)")
Write-Host ''
Write-Host 'CyberThreatGotchi - Windows Wi-Fi repair (conservative)' -ForegroundColor Cyan
$logRef = [ref]$lines
Invoke-CtgDiagnoseWifi -LogLines $logRef
if ($ListProfiles) { Show-CtgWlanProfileList }
if ($PreferWpa3) { Invoke-CtgPreferWpa3Client -LogLines $logRef }
if ($ApplyFixes) { Invoke-CtgApplyWifiFixes -LogLines $logRef }
else {
    Write-CtgSection 'Next step'
    Write-Host '  Run-AsAdmin.ps1 with Repair-WindowsWifi.ps1 -ApplyFixes' -ForegroundColor Gray
}
[void]$lines.Add('Complete')
foreach ($line in $lines) { Add-CtgLogLine -Path $logPath -Line $line }
Write-CtgFinding 'Log' $logPath 'Ok'