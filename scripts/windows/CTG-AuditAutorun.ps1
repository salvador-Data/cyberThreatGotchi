<#
.SYNOPSIS
  CyberThreatGotchi compartmentalized audit autorun - harden, audit, SSD backup, cloud sink.

.DESCRIPTION
  Writes append-only audit runs under Backups\audit\YYYY-MM-DD\run-HHmmss\ with
  separated compartments (windows-security, network-ids, soc-ctg, kali-bridge).
  Optional hardening pass, SSD selective backup when D: online, and env-configured
  cloud sink (Wazuh agent, rclone, or Filebeat template). No secrets in git.

.PARAMETER AuditOnly
  Collect audit artifacts only (default when neither switch is set).

.PARAMETER HardenAndAudit
  Run defensive hardening checks before audit collection.

.PARAMETER SinkCloud
  Push audit run to configured cloud sink (Wazuh status, rclone, Filebeat note).

.PARAMETER SkipSsdBackup
  Skip selective_ssd_backup.ps1 even when SSD is online.

.EXAMPLE
  .\scripts\windows\CTG-AuditAutorun.ps1 -AuditOnly

.EXAMPLE
  .\scripts\windows\CTG-AuditAutorun.ps1 -HardenAndAudit -SinkCloud
#>
[CmdletBinding()]
param(
    [switch] $AuditOnly,
    [switch] $HardenAndAudit,
    [switch] $SinkCloud,
    [switch] $SkipSsdBackup
)

$ErrorActionPreference = 'Continue'
$Repo = 'C:\Users\Owner\Projects\cyberThreatGotchi'
$Win = Join-Path $Repo 'scripts\windows'
$Now = Get-Date
$RunDate = $Now.ToString('yyyy-MM-dd')
$RunTime = $Now.ToString('HHmmss')
$RunId = "run-$RunTime"
$AuditBase = Join-Path $env:USERPROFILE 'Backups\audit'
$RunRoot = Join-Path (Join-Path $AuditBase $RunDate) $RunId
$LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
$LogFile = Join-Path $LogDir 'ctg-audit-autorun.log'
$script:StepErrors = 0
$script:SsdOnline = $false

. (Join-Path $Win 'CTG-AdminCommon.ps1')
$script:CtgIsAdmin = Test-CtgIsAdmin

if (-not $AuditOnly -and -not $HardenAndAudit) {
    $AuditOnly = $true
}

function Write-AuditLog {
    param([string] $Message, [string] $Level = 'INFO')
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    try {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        Add-Content -Path $LogFile -Value $line -Encoding utf8 -ErrorAction Stop
    } catch {
        Write-Warning "Audit log write failed: $($_.Exception.Message)"
    }
    Write-Host $line
}

function Add-AuditError([string] $Context) {
    $script:StepErrors++
    Write-AuditLog "$Context (errors: $script:StepErrors)" 'WARN'
}

function New-Compartment {
    param([string] $Name)
    $path = Join-Path $RunRoot $Name
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Copy-IfExists {
    param(
        [string] $Source,
        [string] $DestDir,
        [string] $DestName = ''
    )
    if (-not (Test-Path $Source)) { return $false }
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    $leaf = if ($DestName) { $DestName } else { Split-Path $Source -Leaf }
    Copy-Item -Path $Source -Destination (Join-Path $DestDir $leaf) -Force
    return $true
}

function Get-CtgEnvVar {
    param([string] $Name)
    $v = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if ($v) { return $v.Trim() }
    $v = [Environment]::GetEnvironmentVariable($Name, 'User')
    if ($v) { return $v.Trim() }
    $v = [Environment]::GetEnvironmentVariable($Name, 'Machine')
    if ($v) { return $v.Trim() }
    return ''
}

function Test-CtgSsdOnline {
    $disk = Get-Disk -Number 1 -ErrorAction SilentlyContinue
    if ($disk -and $disk.OperationalStatus -eq 'No Media') {
        return @{ Online = $false; Detail = 'Disk 1 No Media (SSD unplugged)' }
    }
    if (-not (Test-Path 'D:\')) {
        return @{ Online = $false; Detail = 'D: not present' }
    }
    try {
        New-Item -ItemType Directory -Path 'D:\Backups' -Force | Out-Null
        $probe = Join-Path 'D:\Backups' ('.ctg_audit_probe_{0}.tmp' -f (Get-Date -Format 'yyyyMMddHHmmss'))
        'ok' | Set-Content -Path $probe -Encoding ASCII -ErrorAction Stop
        Remove-Item -Path $probe -Force -ErrorAction SilentlyContinue
        $label = (Get-Volume -DriveLetter D -ErrorAction SilentlyContinue).FileSystemLabel
        return @{ Online = $true; Detail = "D: writable; label=$label" }
    } catch {
        return @{ Online = $false; Detail = "D: not writable: $($_.Exception.Message)" }
    }
}

function Get-UsbDiskSummary {
    $rows = @()
    try {
        Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue |
            Where-Object { $_.InterfaceType -match 'USB' } |
            ForEach-Object {
                $rows += [PSCustomObject]@{
                    Model         = $_.Model
                    Serial        = $_.SerialNumber
                    SizeGB        = [math]::Round($_.Size / 1GB, 2)
                    InterfaceType = $_.InterfaceType
                }
            }
    } catch { }
    return $rows
}

function Invoke-CtgHardenPass {
    Write-AuditLog '--- Harden pass ---'
    $hardenDir = New-Compartment 'windows-security'

    $ddos = Join-Path $Win 'Harden-DDoSRogueWifi.ps1'
    if (Test-Path $ddos) {
        Write-AuditLog 'Harden: Harden-DDoSRogueWifi -DiagnoseOnly'
        $ddosOut = Join-Path $hardenDir 'ddos-rogue-diagnose.txt'
        & $ddos -DiagnoseOnly *>&1 | Tee-Object -FilePath $ddosOut
    } else {
        Add-AuditError 'Harden-DDoSRogueWifi.ps1 missing'
    }

    $fwOut = Join-Path $hardenDir 'firewall-profiles.txt'
    try {
        netsh advfirewall show allprofiles state 2>&1 | Set-Content -Path $fwOut -Encoding utf8
        netsh advfirewall show allprofiles firewallpolicy 2>&1 | Add-Content -Path $fwOut -Encoding utf8
        Write-AuditLog "Firewall verify: wrote $fwOut"
    } catch {
        Add-AuditError "Firewall verify failed: $($_.Exception.Message)"
    }

    $vpnScript = Join-Path $Win 'Preserve-DuckDuckGoVpn.ps1'
    if (Test-Path $vpnScript) {
        $vpnOut = Join-Path $hardenDir 'ddg-vpn-preserve.txt'
        . $vpnScript
        Invoke-CtgPreserveDuckDuckGoVpn -LogAction {
            param($m)
            Add-Content -Path $vpnOut -Value $m -Encoding utf8
            Write-AuditLog "  VPN: $m"
        }
    } else {
        Write-AuditLog 'Preserve-DuckDuckGoVpn.ps1 not found - skipped' 'WARN'
    }

    $pwdScript = Join-Path $Win 'Harden-PasswordPolicy.ps1'
    if (Test-Path $pwdScript) {
        Write-AuditLog 'Harden: Harden-PasswordPolicy -DiagnoseOnly'
        $pwdOut = Join-Path $hardenDir 'password-policy-diagnose.txt'
        & $pwdScript -DiagnoseOnly *>&1 | Tee-Object -FilePath $pwdOut
        if ($script:CtgIsAdmin) {
            Write-AuditLog 'Harden: Harden-PasswordPolicy -ApplyPolicy (elevated)'
            & $pwdScript -ApplyPolicy *>&1 | Tee-Object -FilePath (Join-Path $hardenDir 'password-policy-apply.txt') -Append
        } else {
            Write-AuditLog 'Harden-PasswordPolicy -ApplyPolicy skipped (not Admin)' 'WARN'
        }
    } else {
        Add-AuditError 'Harden-PasswordPolicy.ps1 missing'
    }
}

function Invoke-CtgWindowsSecurityAudit {
    param([string] $CompDir)
    Write-AuditLog 'Audit: windows-security compartment'

    try {
        Get-MpComputerStatus | ConvertTo-Json -Depth 4 |
            Set-Content -Path (Join-Path $CompDir 'defender-status.json') -Encoding utf8
        Write-AuditLog '  Defender status exported'
    } catch {
        Add-AuditError "Defender status failed: $($_.Exception.Message)"
    }

    $signIn = Join-Path $CompDir 'recent-sign-in-events.txt'
    try {
        Get-WinEvent -FilterHashtable @{
            LogName   = 'Security'
            Id        = 4624, 4625
            StartTime = (Get-Date).AddHours(-24)
        } -MaxEvents 50 -ErrorAction Stop |
            Select-Object TimeCreated, Id, Message |
            Format-List | Out-String | Set-Content -Path $signIn -Encoding utf8
        Write-AuditLog '  Sign-in events (24h) exported'
    } catch {
        Write-AuditLog "  Sign-in events skipped: $($_.Exception.Message)" 'WARN'
        @("Sign-in export skipped: $($_.Exception.Message)") | Set-Content -Path $signIn -Encoding utf8
    }

    $fwLog = Join-Path $env:USERPROFILE 'Backups\logs\firewall.log'
    if (Copy-IfExists -Source $fwLog -DestDir $CompDir -DestName 'firewall-tail.log') {
        try {
            Get-Content -Path (Join-Path $CompDir 'firewall-tail.log') -Tail 200 -ErrorAction Stop |
                Set-Content -Path (Join-Path $CompDir 'firewall-tail-last200.log') -Encoding utf8
        } catch { }
        Write-AuditLog '  Firewall log copied'
    } else {
        Write-AuditLog '  Firewall log not present' 'WARN'
    }

    try {
        Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction |
            ConvertTo-Json | Set-Content -Path (Join-Path $CompDir 'firewall-profiles.json') -Encoding utf8
    } catch { }
}

function Invoke-CtgNetworkIdsAudit {
    param([string] $CompDir)
    Write-AuditLog 'Audit: network-ids compartment'

    $alerts = Join-Path $env:USERPROFILE 'Backups\logs\wireshark-alerts.json'
    if (Copy-IfExists -Source $alerts -DestDir $CompDir) {
        Write-AuditLog '  wireshark-alerts.json copied'
    } else {
        @('[]') | Set-Content -Path (Join-Path $CompDir 'wireshark-alerts.json') -Encoding utf8
        Write-AuditLog '  wireshark-alerts.json absent - placeholder written' 'WARN'
    }

    $idsLog = Join-Path $env:USERPROFILE 'Backups\logs\wireshark-ids.log'
    Copy-IfExists -Source $idsLog -DestDir $CompDir | Out-Null

    foreach ($snortPath in @(
            Join-Path $env:USERPROFILE 'Backups\logs\snort.log'
            'D:\Backups\logs\snort.log'
            Join-Path $Repo 'data\snort.log'
        )) {
        if (Copy-IfExists -Source $snortPath -DestDir $CompDir) {
            Write-AuditLog "  Snort log copied from $snortPath"
            break
        }
    }
}

function Invoke-CtgSocCtgAudit {
    param([string] $CompDir)
    Write-AuditLog 'Audit: soc-ctg compartment'

    $port = Get-CtgEnvVar 'CTG_WEB_PORT'
    if (-not $port) { $port = '8765' }
    $base = "http://127.0.0.1:$port"

    foreach ($ep in @(
            @{ Name = 'audit.json'; Path = '/api/export/audit.json' }
            @{ Name = 'threats.json'; Path = '/api/export/threats.json' }
        )) {
        $dest = Join-Path $CompDir $ep.Name
        try {
            $resp = Invoke-WebRequest -Uri ($base + $ep.Path) -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
            $resp.Content | Set-Content -Path $dest -Encoding utf8
            Write-AuditLog "  CTG export $($ep.Name) OK"
        } catch {
            @("{""error"":""$($_.Exception.Message)"",""endpoint"":""$($ep.Path)""}") |
                Set-Content -Path $dest -Encoding utf8
            Write-AuditLog "  CTG export $($ep.Name) unavailable" 'WARN'
        }
    }

    foreach ($socLog in @(
            (Join-Path $Win 'ctg-soc-run-log-elevated.txt')
            (Join-Path ([Environment]::GetFolderPath('Desktop')) 'ctg-soc-run-log.txt')
        )) {
        Copy-IfExists -Source $socLog -DestDir $CompDir | Out-Null
    }
}

function Invoke-CtgKaliBridgeAudit {
    param([string] $CompDir)
    Write-AuditLog 'Audit: kali-bridge compartment (placeholder)'

    $shareRoots = @(
        Join-Path $env:USERPROFILE 'Backups\kali-bridge'
        '\\kali\ctg-logs'
        'D:\Backups\kali-bridge'
    )
    $found = $false
    foreach ($root in $shareRoots) {
        if (-not (Test-Path $root)) { continue }
        $dest = Join-Path $CompDir 'synced'
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        Get-ChildItem -Path $root -File -ErrorAction SilentlyContinue |
            Select-Object -First 20 |
            ForEach-Object { Copy-Item $_.FullName -Destination $dest -Force -ErrorAction SilentlyContinue }
        $found = $true
        Write-AuditLog "  Kali bridge synced from $root"
        break
    }
    if (-not $found) {
        @(
            'Kali bridge placeholder - no synced logs found.'
            'Configure SMB share or copy Kali SIEM exports to Backups\kali-bridge\'
            "Checked: $($shareRoots -join ', ')"
        ) | Set-Content -Path (Join-Path $CompDir 'README.txt') -Encoding utf8
    }
}

function Get-PreviousManifestHash {
    param([string] $DayDir)
    if (-not (Test-Path $DayDir)) { return $null }
    $manifests = Get-ChildItem -Path $DayDir -Directory -Filter 'run-*' |
        Sort-Object Name -Descending |
        Select-Object -Skip 1 -First 1
    foreach ($dir in $manifests) {
        $mf = Join-Path $dir.FullName 'manifest.json'
        if (Test-Path $mf) {
            try {
                $bytes = [System.IO.File]::ReadAllBytes($mf)
                $sha = [System.Security.Cryptography.SHA256]::Create()
                return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant()
            } catch { return $null }
        }
    }
    return $null
}

function Write-CtgManifest {
    param(
        [string] $SsdDetail,
        [bool] $SsdOnline
    )
    $dayDir = Join-Path $AuditBase $RunDate
    $prevHash = Get-PreviousManifestHash -DayDir $dayDir
    $manifest = [ordered]@{
        run_id       = $RunId
        timestamp    = $Now.ToString('o')
        hostname     = $env:COMPUTERNAME
        username     = $env:USERNAME
        admin        = $script:CtgIsAdmin
        mode         = if ($HardenAndAudit) { 'harden-and-audit' } else { 'audit-only' }
        ssd_online   = $SsdOnline
        ssd_detail   = $SsdDetail
        compartments = @('windows-security', 'network-ids', 'soc-ctg', 'kali-bridge')
        errors       = $script:StepErrors
        prev_hash    = $prevHash
    }
    $mfPath = Join-Path $RunRoot 'manifest.json'
    ($manifest | ConvertTo-Json -Depth 4) | Set-Content -Path $mfPath -Encoding utf8

    try {
        $bytes = [System.IO.File]::ReadAllBytes($mfPath)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $manifest['content_hash'] = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant()
        ($manifest | ConvertTo-Json -Depth 4) | Set-Content -Path $mfPath -Encoding utf8
    } catch { }

    Write-AuditLog "Manifest: $mfPath"
    return $mfPath
}

function Invoke-CtgSsdBackup {
    if ($SkipSsdBackup) {
        Write-AuditLog 'SSD backup skipped (-SkipSsdBackup)'
        return
    }
    if (-not $script:SsdOnline) {
        Write-AuditLog 'SSD backup skipped (SSD offline)'
        return
    }
    $backupScript = Join-Path $Win 'selective_ssd_backup.ps1'
    if (-not (Test-Path $backupScript)) {
        Add-AuditError 'selective_ssd_backup.ps1 missing'
        return
    }
    $backupRoot = "D:\Backups\Andy-PC-$RunDate"
    Write-AuditLog "SSD backup: $backupScript -> $backupRoot"
    & $backupScript -BackupRoot $backupRoot *>&1 | ForEach-Object { Write-AuditLog "  backup: $_" }

    $auditMirror = Join-Path "D:\Backups\audit\$RunDate" $RunId
    try {
        New-Item -ItemType Directory -Path $auditMirror -Force | Out-Null
        Copy-Item -Path (Join-Path $RunRoot '*') -Destination $auditMirror -Recurse -Force
        Write-AuditLog "Audit run mirrored to $auditMirror"
    } catch {
        Write-AuditLog "Audit SSD mirror failed: $($_.Exception.Message)" 'WARN'
    }
}

function Invoke-CtgCloudSink {
    if (-not $SinkCloud) { return }
    Write-AuditLog '--- Cloud sink ---'

    $mgr = Get-CtgEnvVar 'CTG_WAZUH_MANAGER'
    if (-not $mgr) { $mgr = Get-CtgEnvVar 'WAZUH_MANAGER' }
    if ($mgr) {
        $svc = Get-Service -Name WazuhSvc -ErrorAction SilentlyContinue
        $status = if ($svc) { $svc.Status.ToString() } else { 'not_installed' }
        Write-AuditLog "Wazuh sink: manager=$mgr service=$status"
        $sinkNote = Join-Path $RunRoot 'cloud-sink-wazuh.txt'
        @(
            "Wazuh agent forwarder (live telemetry)"
            "Manager: $mgr"
            "Service: $status"
            "Audit run path: $RunRoot"
            "Agent ingests Sysmon/ossec locally; this run folder is archival copy via rclone if configured."
        ) | Set-Content -Path $sinkNote -Encoding utf8
    }

    $remote = Get-CtgEnvVar 'CTG_AUDIT_REMOTE'
    if ($remote) {
        $rclone = Get-Command rclone -ErrorAction SilentlyContinue
        if (-not $rclone) {
            Write-AuditLog 'CTG_AUDIT_REMOTE set but rclone not in PATH' 'WARN'
        } else {
            Write-AuditLog "rclone sink: $remote"
            & rclone copy $RunRoot $remote --create-empty-src-dirs *>&1 | ForEach-Object { Write-AuditLog "  rclone: $_" }
            if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
                Add-AuditError "rclone exit $LASTEXITCODE"
            }
        }
    } else {
        Write-AuditLog 'rclone sink: SKIPPED (CTG_AUDIT_REMOTE not set)'
    }

    $fbHost = Get-CtgEnvVar 'CTG_ELASTIC_HOST'
    $templateDir = Join-Path $Repo 'config\filebeat'
    $templatePath = Join-Path $templateDir 'filebeat-audit.yml.example'
    if ((Test-Path $templatePath) -or $fbHost) {
        Write-AuditLog "Filebeat template: $templatePath (see docs/AUDIT_CLOUD_SINK.md)"
        $fbNote = Join-Path $RunRoot 'cloud-sink-filebeat.txt'
        @(
            'Filebeat to Elastic/OpenSearch (optional)'
            "Template: $templatePath"
            "CTG_ELASTIC_HOST: $(if ($fbHost) { $fbHost } else { '(not set)' })"
            'Install Filebeat, copy template to ProgramData, point at this run root.'
        ) | Set-Content -Path $fbNote -Encoding utf8
    }
}

# --- Main ---
Write-AuditLog "=== CTG Audit Autorun started === run=$RunId Admin=$script:CtgIsAdmin ==="
Write-AuditLog "Mode: $(if ($HardenAndAudit) { 'HardenAndAudit' } else { 'AuditOnly' }) SinkCloud=$($SinkCloud.IsPresent)"

New-Item -ItemType Directory -Path $RunRoot -Force | Out-Null
foreach ($c in @('windows-security', 'network-ids', 'soc-ctg', 'kali-bridge')) {
    New-Item -ItemType Directory -Path (Join-Path $RunRoot $c) -Force | Out-Null
}

$ssd = Test-CtgSsdOnline
$script:SsdOnline = [bool]$ssd.Online
Write-AuditLog ("SSD: online={0} - {1}" -f $script:SsdOnline, $ssd.Detail)

$usb = Get-UsbDiskSummary
if ($usb.Count -gt 0) {
    $usb | ConvertTo-Json | Set-Content -Path (Join-Path $RunRoot 'usb-disks.json') -Encoding utf8
}

if (-not $script:SsdOnline -and $script:CtgIsAdmin) {
    $mountScript = Join-Path $Win 'mount_ssd_d.ps1'
    if (Test-Path $mountScript) {
        Write-AuditLog 'Attempting mount_ssd_d.ps1'
        & $mountScript *>&1 | ForEach-Object { Write-AuditLog "  mount: $_" }
        $ssd = Test-CtgSsdOnline
        $script:SsdOnline = [bool]$ssd.Online
        Write-AuditLog ("SSD after mount: online={0} - {1}" -f $script:SsdOnline, $ssd.Detail)
    }
}

if ($HardenAndAudit) {
    Invoke-CtgHardenPass
}

$wsDir = Join-Path $RunRoot 'windows-security'
Invoke-CtgWindowsSecurityAudit -CompDir $wsDir
Invoke-CtgNetworkIdsAudit -CompDir (Join-Path $RunRoot 'network-ids')
Invoke-CtgSocCtgAudit -CompDir (Join-Path $RunRoot 'soc-ctg')
Invoke-CtgKaliBridgeAudit -CompDir (Join-Path $RunRoot 'kali-bridge')

Write-CtgManifest -SsdDetail $ssd.Detail -SsdOnline $script:SsdOnline
Invoke-CtgSsdBackup
Invoke-CtgCloudSink

Write-AuditLog "=== CTG Audit Autorun finished === run=$RunRoot errors=$script:StepErrors ==="
Write-Output "AUDIT_RUN=$RunRoot"
Write-Output "SSD_ONLINE=$($script:SsdOnline)"
exit 0
