# Shared helpers for CTG Wireshark IDS (authorized defensive lab use only).

. (Join-Path $PSScriptRoot 'CTG-Paths.ps1')

function Import-CtgDotEnv {
    param([string] $EnvPath)
    if (-not (Test-Path $EnvPath)) { return }
    Get-Content -Path $EnvPath -Encoding utf8 -ErrorAction SilentlyContinue | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith('#')) { return }
        if ($line -match '^\s*export\s+(.+)$') { $line = $Matches[1] }
        if ($line -notmatch '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') { return }
        $name = $Matches[1]
        $value = $Matches[2].Trim()
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        if (-not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) { return }
        [Environment]::SetEnvironmentVariable($name, $value, 'Process')
    }
}

function Get-CtgBackupsRoot {
    $ssd = 'D:\Backups'
    if ((Test-Path 'D:\') -and (Test-Path $ssd)) {
        try {
            $probe = Join-Path $ssd '.ctg-write-probe'
            New-Item -ItemType File -Path $probe -Force | Out-Null
            Remove-Item $probe -Force -ErrorAction SilentlyContinue
            return $ssd
        } catch { }
    }
    return Join-Path $env:USERPROFILE 'Backups'
}

function Get-CtgWiresharkPaths {
    $root = Get-CtgBackupsRoot
    $date = Get-Date -Format 'yyyy-MM-dd'
    return [PSCustomObject]@{
        BackupsRoot = $root
        PcapDir     = Join-Path $root 'pcap'
        LogsDir     = Join-Path $root 'logs'
        PcapFile    = Join-Path (Join-Path $root 'pcap') "ctg-$date.pcapng"
        IdsLog      = Join-Path (Join-Path $root 'logs') 'wireshark-ids.log'
        AlertsJson  = Join-Path (Join-Path $root 'logs') 'wireshark-alerts.json'
        SnippetsDir = Join-Path (Join-Path $root 'pcap') 'snippets'
        ExportCsv   = Join-Path (Join-Path $root 'logs') 'wireshark-export.csv'
        SmsRateFile = Join-Path (Join-Path $root 'logs') 'sms-rate-limit.json'
    }
}

function Get-CtgTsharkPath {
    $cmd = Get-Command tshark -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($p in @(
        "${env:ProgramFiles}\Wireshark\tshark.exe",
        "${env:ProgramFiles(x86)}\Wireshark\tshark.exe"
    )) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Get-CtgWiresharkVersion {
    param([string] $TsharkPath)
    if (-not $TsharkPath) { return $null }
    try {
        $out = & $TsharkPath -v 2>&1 | Select-Object -First 1
        return ($out -join ' ').Trim()
    } catch {
        return $null
    }
}

function Get-CtgCaptureInterface {
    param([string] $TsharkPath, [string] $Preferred)
    if ($Preferred) { return $Preferred }
    if (-not $TsharkPath) { return $null }
    try {
        $out = & $TsharkPath -D 2>&1
        foreach ($line in $out) {
            if ($line -match '^\s*(\d+)\.\s+(.+)$') {
                $desc = $Matches[2]
                if ($desc -match 'Loopback|Npcap Loopback Adapter') { continue }
                if ($desc -match 'Wi-Fi|Wireless|Ethernet|Realtek|Intel') {
                    return $Matches[1]
                }
            }
        }
        foreach ($line in $out) {
            if ($line -match '^\s*(\d+)\.\s+(.+)$') {
                $desc = $Matches[2]
                if ($desc -notmatch 'Loopback|Npcap Loopback') {
                    return $Matches[1]
                }
            }
        }
    } catch { }
    return '1'
}

function Write-CtgWiresharkLog {
    param(
        [string] $Message,
        [string] $LogFile,
        [string] $Color = 'Gray'
    )
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    try {
        $dir = Split-Path $LogFile -Parent
        if ($dir) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Add-Content -Path $LogFile -Value $line -Encoding utf8 -ErrorAction SilentlyContinue
    } catch { }
    Write-Host $line -ForegroundColor $Color
}

function Test-CtgSnortInstalled {
    $paths = @(
        'C:\Snort\bin\snort.exe',
        'C:\Program Files\Snort\bin\snort.exe',
        'C:\Program Files (x86)\Snort\bin\snort.exe'
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }
    $cmd = Get-Command snort -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Get-CtgPythonForIds {
    $repo = Get-CtgRepoRoot
    $candidates = @(
        (Get-Command python -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source),
        (Get-Command py -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
    ) | Where-Object { $_ }
    foreach ($py in $candidates) {
        try {
            & $py -c "import sys; sys.exit(0)" 2>$null
            if ($LASTEXITCODE -eq 0) { return $py }
        } catch { }
    }
    return 'python'
}

function Read-CtgAlertsJson {
    param([string] $Path)
    if (-not (Test-Path $Path)) { return @() }
    try {
        $raw = Get-Content -Path $Path -Raw -Encoding utf8
        if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
        $data = $raw | ConvertFrom-Json
        if ($null -eq $data) { return @() }
        if ($data -is [System.Array]) { return @($data) }
        return @($data)
    } catch {
        return @()
    }
}

function Write-CtgAlertsJson {
    param(
        [string] $Path,
        [array] $Alerts
    )
    $dir = Split-Path $Path -Parent
    if ($dir) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $Alerts | ConvertTo-Json -Depth 6 | Set-Content -Path $Path -Encoding utf8
}

function Invoke-CtgBlockRepeatOffender {
    param(
        [string] $RemoteIp,
        [string] $LogFile
    )
    if ([string]::IsNullOrWhiteSpace($RemoteIp)) { return $false }
    if ($RemoteIp -match '^(127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)') {
        Write-CtgWiresharkLog "IPS skip RFC1918/loopback block for $RemoteIp" $LogFile 'Yellow'
        return $false
    }
    $ruleName = "CTG-IDS-Block-$($RemoteIp -replace '\.', '-')"
    try {
        $existing = netsh advfirewall firewall show rule name="$ruleName" 2>$null
        if ($LASTEXITCODE -eq 0 -and $existing) {
            Write-CtgWiresharkLog "IPS rule already exists for $RemoteIp" $LogFile
            return $true
        }
        netsh advfirewall firewall add rule name="$ruleName" dir=in action=block remoteip="$RemoteIp" enable=yes | Out-Null
        Write-CtgWiresharkLog "IPS blocked inbound from $RemoteIp via netsh" $LogFile 'Red'
        return $true
    } catch {
        Write-CtgWiresharkLog "IPS block failed for ${RemoteIp}: $($_.Exception.Message)" $LogFile 'Yellow'
        return $false
    }
}

function Save-CtgPcapSnippet {
    param(
        [string] $TsharkPath,
        [string] $SourcePcap,
        [string] $SnippetsDir,
        [string] $AlertType,
        [string] $SrcIp
    )
    if (-not (Test-Path $SourcePcap)) { return $null }
    New-Item -ItemType Directory -Path $SnippetsDir -Force | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $safeType = ($AlertType -replace '[^\w\-]', '-')
    $safeIp = ($SrcIp -replace '[^\w\.\-]', '-')
    if ([string]::IsNullOrWhiteSpace($safeIp)) { $safeIp = 'unknown' }
    $out = Join-Path $SnippetsDir "alert-${safeType}-${safeIp}-${stamp}.pcapng"
    try {
        $tailSec = 120
        & $TsharkPath -r $SourcePcap -Y "frame.time_relative >= $tailSec" -w $out 2>$null
        if ((Test-Path $out) -and ((Get-Item $out).Length -gt 24)) {
            return $out
        }
        Copy-Item -Path $SourcePcap -Destination $out -Force
        return $out
    } catch {
        return $null
    }
}
