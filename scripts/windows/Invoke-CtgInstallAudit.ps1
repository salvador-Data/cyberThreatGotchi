<#
.SYNOPSIS
  CTG install audit â€” INSTALLED vs PENDING vs MANUAL for every lab component.

.DESCRIPTION
  Diagnose-only by default. Writes a timestamped report to Backups\logs\ctg-install-audit-*.txt
  (gitignored). Source of truth for Cursor rule ctg-install-status.mdc.

  Does NOT register scheduled tasks, flash Cardputer, run Wi-Fi ApplyFixes, disable HVCI/VBS,
  or install competing VPNs. Safe to run without Administrator.

.PARAMETER ApplySafe
  Run non-destructive fixes: pip install -r requirements.txt, Stage-KaliLabToBackups.ps1.

.PARAMETER Json
  Also write ctg-install-audit-latest.json beside the text log.

.EXAMPLE
  cd "$env:USERPROFILE\Programs\Hacker Planet LLC\cyberThreatGotchi"
  .\scripts\windows\Invoke-CtgInstallAudit.ps1

.EXAMPLE
  .\scripts\windows\Invoke-CtgInstallAudit.ps1 -ApplySafe
#>
[CmdletBinding()]
param(
    [switch] $ApplySafe,
    [switch] $Json
)
. (Join-Path $PSScriptRoot 'CTG-ShellFast.ps1')

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-Paths.ps1')
. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')

$Repo = Get-CtgRepoRoot -FromPath $PSScriptRoot
$Win = Join-Path $Repo 'scripts\windows'
$Programs = Get-CtgProgramsRoot
$LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outFile = Join-Path $LogDir "ctg-install-audit-$stamp.txt"
$jsonFile = Join-Path $LogDir 'ctg-install-audit-latest.json'
$rows = [System.Collections.Generic.List[object]]::new()
$lines = [System.Collections.Generic.List[string]]::new()

function Add-AuditLine {
    param([string] $Message)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    [void]$lines.Add($line)
    Write-Host $line
}

function Add-CtgComponent {
    param(
        [string] $Component,
        [ValidateSet('INSTALLED', 'PENDING', 'MANUAL', 'OPTIONAL')]
        [string] $Status,
        [string] $Detail = '',
        [string] $AdminStep = ''
    )
    [void]$rows.Add([PSCustomObject]@{
            Component = $Component
            Status    = $Status
            Detail    = $Detail
            AdminStep = $AdminStep
        })
    $adminSuffix = if ($AdminStep) { " | $AdminStep" } else { '' }
    Add-AuditLine ("{0,-32} {1,-10} {2}{3}" -f $Component, $Status, $Detail, $adminSuffix)
}

function Test-CtgScheduledTask {
    param([string] $TaskName)
    $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    return [bool]$t
}

function Test-CtgCommand {
    param([string] $Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-CtgPythonPackages {
    param([string] $PythonExe, [string[]] $Packages)
    if (-not (Test-Path $PythonExe)) { return $false }
    foreach ($pkg in $Packages) {
        & $PythonExe -c "import $pkg" 2>$null
        if ($LASTEXITCODE -ne 0) { return $false }
    }
    return $true
}

function Test-CtgProtonBridge {
    $candidates = @(
        (Join-Path ${env:ProgramFiles} 'Proton\Proton Mail Bridge\Proton Mail Bridge.exe'),
        (Join-Path $env:LocalAppData 'Programs\Proton Mail Bridge\Proton Mail Bridge.exe'),
        (Join-Path ${env:ProgramFiles} 'Proton\Proton Bridge\Proton Bridge.exe')
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Get-CtgComPortStatus {
    param([string] $Port = 'COM13')
    $ports = [System.IO.Ports.SerialPort]::GetPortNames()
    if ($ports -contains $Port) {
        return "detected ($Port)"
    }
    if ($ports.Count -gt 0) {
        return "other ports: $($ports -join ', '); $Port not present"
    }
    return 'no serial ports detected'
}

function Test-CtgDocker {
    if (-not (Test-CtgCommand 'docker')) { return $false }
    try {
        docker info 2>&1 | Out-Null
        return $LASTEXITCODE -eq 0
    } catch { return $false }
}

function Test-CtgSiblingClone {
    param([string] $Name)
    $path = Join-Path $Programs $Name
    return (Test-Path (Join-Path $path '.git'))
}

Add-AuditLine '=== CTG Install Audit ==='
Add-AuditLine ("Repo: {0}" -f $Repo)
Add-AuditLine ("Programs root: {0}" -f $Programs)
Add-AuditLine ("Computer: {0} | User: {1} | Admin: {2}" -f $env:COMPUTERNAME, $env:USERNAME, (Test-CtgIsAdmin))
Add-AuditLine 'Policy: preserve DDG VPN/DNS/PM; no HVCI/VBS/spec-ctrl disable; no guest-flash chase'
Add-AuditLine ''
Add-AuditLine ('{0,-32} {1,-10} Detail' -f 'Component', 'Status')
Add-AuditLine ('{0}' -f ('-' * 90))

# --- Python venv ---
$venvPy = Join-Path $Repo '.venv\Scripts\python.exe'
$reqFile = Join-Path $Repo 'requirements.txt'
if (Test-Path $venvPy) {
    $pkgOk = Test-CtgPythonPackages -PythonExe $venvPy -Packages @('cryptography', 'argon2')
    if ($pkgOk) {
        Add-CtgComponent -Component 'Python venv + crypto deps' -Status 'INSTALLED' -Detail '.venv with cryptography, argon2'
    } else {
        Add-CtgComponent -Component 'Python venv + crypto deps' -Status 'PENDING' -Detail 'venv exists; pip install cryptography argon2-cffi' `
            -AdminStep '.\.venv\Scripts\pip install -r requirements.txt'
    }
} else {
    Add-CtgComponent -Component 'Python venv + crypto deps' -Status 'PENDING' -Detail 'missing .venv' `
        -AdminStep 'py -m venv .venv; .\.venv\Scripts\pip install -r requirements.txt'
}

# --- DuckDuckGo VPN preserve ---
$preserveScript = Join-Path $Win 'Preserve-DuckDuckGoVpn.ps1'
if (Test-Path $preserveScript) {
    . $preserveScript
    $ddgPaths = Get-CtgDuckDuckGoVpnPaths
    $ddgUp = Test-CtgDuckDuckGoVpnConnected
    if ($ddgPaths.Count -gt 0) {
        Add-CtgComponent -Component 'DuckDuckGo VPN (Preserve-DuckDuckGoVpn)' -Status 'INSTALLED' -Detail ("tunnel up: {0}" -f $ddgUp)
    } else {
        Add-CtgComponent -Component 'DuckDuckGo VPN (Preserve-DuckDuckGoVpn)' -Status 'MANUAL' -Detail 'install DDG VPN; CTG never installs competing VPNs'
    }
} else {
    Add-CtgComponent -Component 'DuckDuckGo VPN (Preserve-DuckDuckGoVpn)' -Status 'PENDING' -Detail 'Preserve-DuckDuckGoVpn.ps1 missing'
}

# --- Credential vault ---
$credVault = Join-Path $env:USERPROFILE 'Backups\.vault\credentials.vault'
$dpapiVault = Join-Path $env:USERPROFILE 'Backups\.vault\secrets.dpapi'
if (Test-Path $credVault) {
    Add-CtgComponent -Component 'Ctg-CredentialVault' -Status 'INSTALLED' -Detail $credVault
} elseif (Test-Path $dpapiVault) {
    Add-CtgComponent -Component 'Ctg-CredentialVault' -Status 'MANUAL' -Detail 'legacy DPAPI only; migrate when ready' `
        -AdminStep '.\scripts\windows\Ctg-CredentialVault.ps1 -InitVault -WithDpapiWrap'
} else {
    Add-CtgComponent -Component 'Ctg-CredentialVault' -Status 'MANUAL' -Detail 'not initialized' `
        -AdminStep '.\scripts\windows\Ctg-CredentialVault.ps1 -InitVault -WithDpapiWrap'
}

# --- Scheduled tasks (single Get-ScheduledTask query for speed) ---
$registeredCtgTasks = @{}
try {
    Get-ScheduledTask -ErrorAction SilentlyContinue |
        Where-Object { $_.TaskName -like 'HackerPlanet-CTG-*' } |
        ForEach-Object { $registeredCtgTasks[$_.TaskName] = $true }
} catch { }

$taskMap = [ordered]@{
    'HackerPlanet-CTG-Nightly-4AM'         = 'Register-CtgNightlyTask.ps1'
    'HackerPlanet-CTG-Cpu-Optimize'        = 'Register-CtgCpuOptimizeTask.ps1'
    'HackerPlanet-CTG-Memory-Protection'   = 'Register-CtgMemoryProtectionTask.ps1'
    'HackerPlanet-CTG-Snort-IDS'            = 'Register-CtgSnortIdsTask.ps1'
    'HackerPlanet-CTG-Suricata-IDS'         = 'Register-CtgSuricataIdsTask.ps1'
    'HackerPlanet-CTG-Email-Notify'         = 'Register-CtgEmailNotifyTask.ps1'
    'HackerPlanet-CTG-Restore-Drill'        = 'Register-CtgRestoreDrillTask.ps1'
    'HackerPlanet-CTG-Ram-Mitigation'       = 'Register-CtgRamMitigationTask.ps1'
}
foreach ($entry in $taskMap.GetEnumerator()) {
    $taskName = $entry.Key
    $regScript = $entry.Value
    if ($registeredCtgTasks.ContainsKey($taskName)) {
        Add-CtgComponent -Component "Task $taskName" -Status 'INSTALLED' -Detail 'registered'
    } else {
        $scriptPath = Join-Path $Win $regScript
        if (Test-Path $scriptPath) {
            Add-CtgComponent -Component "Task $taskName" -Status 'MANUAL' -Detail 'not registered' `
                -AdminStep "Admin: .\scripts\windows\$regScript"
        } else {
            Add-CtgComponent -Component "Task $taskName" -Status 'PENDING' -Detail "missing $regScript"
        }
    }
}

# --- External tools (presence only) ---
foreach ($tool in @('signal-cli', 'snort', 'suricata')) {
    if (Test-CtgCommand $tool) {
        $src = (Get-Command $tool).Source
        Add-CtgComponent -Component $tool -Status 'INSTALLED' -Detail $src
    } else {
        $installScript = switch ($tool) {
            'signal-cli' { 'Install-CtgSignalCli.ps1' }
            'snort'      { 'Install-CtgSnortWindows.ps1' }
            'suricata'   { 'Install-CtgSuricataWindows.ps1' }
        }
        Add-CtgComponent -Component $tool -Status 'OPTIONAL' -Detail 'not on PATH' `
            -AdminStep ".\scripts\windows\$installScript -DiagnoseOnly then -ApplySafe (Admin if prompted)"
    }
}

$bridge = Test-CtgProtonBridge
if ($bridge) {
    Add-CtgComponent -Component 'Proton Mail Bridge' -Status 'INSTALLED' -Detail $bridge
} else {
    Add-CtgComponent -Component 'Proton Mail Bridge' -Status 'MANUAL' -Detail 'install from proton.me/bridge; store creds in vault only' `
        -AdminStep 'See docs/EMAIL_NOTIFICATIONS.md'
}

# --- Wazuh / Docker ---
$composeFile = Join-Path $Repo 'scripts\wazuh-lab\docker-compose.yml'
if (Test-CtgDocker) {
    Add-CtgComponent -Component 'Docker (Wazuh lab)' -Status 'INSTALLED' -Detail 'docker info OK'
} else {
    Add-CtgComponent -Component 'Docker (Wazuh lab)' -Status 'MANUAL' -Detail 'Docker Desktop not available' `
        -AdminStep 'Install Docker Desktop; .\scripts\windows\Install-CtgWazuhLab.ps1 -ApplySafe'
}
if (Test-Path $composeFile) {
    Add-CtgComponent -Component 'Wazuh compose file' -Status 'INSTALLED' -Detail $composeFile
} else {
    Add-CtgComponent -Component 'Wazuh compose file' -Status 'PENDING' -Detail 'missing scripts/wazuh-lab/docker-compose.yml'
}

# --- Defender ASR ---
$defenderScript = Join-Path $Win 'Harden-CtgWindowsDefender.ps1'
if (Test-Path $defenderScript) {
    if (Test-CtgIsAdmin) {
        Add-CtgComponent -Component 'Defender ASR ApplySafe' -Status 'MANUAL' -Detail 'Admin available â€” run after ASR audit review' `
            -AdminStep '.\scripts\windows\Harden-CtgWindowsDefender.ps1 -ApplySafe'
    } else {
        Add-CtgComponent -Component 'Defender ASR ApplySafe' -Status 'MANUAL' -Detail 'diagnose OK without Admin' `
            -AdminStep 'Admin: .\scripts\windows\Harden-CtgWindowsDefender.ps1 -ApplySafe'
    }
} else {
    Add-CtgComponent -Component 'Defender ASR ApplySafe' -Status 'PENDING' -Detail 'script missing'
}

# --- Kali staging / spec-ctrl ---
$clickMe = Join-Path $env:USERPROFILE 'Backups\CLICK-ME-RUN-IN-KALI.sh'
if (Test-Path $clickMe) {
    Add-CtgComponent -Component 'Kali scripts staged' -Status 'INSTALLED' -Detail 'Backups share + CLICK-ME'
} else {
    Add-CtgComponent -Component 'Kali scripts staged' -Status 'PENDING' -Detail 'CLICK-ME missing from Backups' `
        -AdminStep '.\scripts\windows\Stage-KaliLabToBackups.ps1'
}

$spectreScript = Join-Path $Win 'Harden-KaliVmSpectre.ps1'
if (Test-Path $spectreScript) {
    Add-CtgComponent -Component 'Kali VM spec-ctrl' -Status 'MANUAL' -Detail 'run Harden-KaliVmSpectre.ps1 -DiagnoseOnly for live state' `
        -AdminStep '.\scripts\windows\Harden-KaliVmSpectre.ps1 -DiagnoseOnly'
} else {
    Add-CtgComponent -Component 'Kali VM spec-ctrl' -Status 'PENDING' -Detail 'Harden-KaliVmSpectre.ps1 missing'
}

Add-CtgComponent -Component 'Kali lab chain (guest)' -Status 'MANUAL' -Detail 'double-click CLICK-ME or share trigger' `
    -AdminStep 'Guest: bash /media/sf_ctg-backups/CLICK-ME-RUN-IN-KALI.sh'

# --- PlatformIO / Cardputer ---
$pio = Get-Command pio, platformio -ErrorAction SilentlyContinue | Select-Object -First 1
if ($pio) {
    Add-CtgComponent -Component 'PlatformIO CLI' -Status 'INSTALLED' -Detail $pio.Source
} else {
    Add-CtgComponent -Component 'PlatformIO CLI' -Status 'OPTIONAL' -Detail 'not on PATH' `
        -AdminStep 'pip install platformio or VS Code PlatformIO extension'
}
Add-CtgComponent -Component 'Cardputer COM13' -Status 'MANUAL' -Detail (Get-CtgComPortStatus -Port 'COM13') `
    -AdminStep 'Connect USB; flash only when requested (COM13 Espressif VID_303A)'

# --- Ecosystem clones ---
$ecosystem = @(
    'cyberThreatGotchi', 'ctg-kali-lab', 'ctg-windows-soc', 'ctg-device-hardening',
    'M5_OS-Cardputer', 'BLE-Bot-Cardputer', 'Bjorn', 'Mr.-CrackBot-AI-Nano', 'Remote-Possibility'
)
foreach ($name in $ecosystem) {
    if (Test-CtgSiblingClone -Name $name) {
        Add-CtgComponent -Component "Clone $name" -Status 'INSTALLED' -Detail (Join-Path $Programs $name)
    } else {
        Add-CtgComponent -Component "Clone $name" -Status 'OPTIONAL' -Detail 'missing under Programs' `
            -AdminStep "gh repo clone salvador-Data/$name `"$(Join-Path $Programs $name)`""
    }
}

# --- ApplySafe fixes ---
if ($ApplySafe) {
    Add-AuditLine ''
    Add-AuditLine '=== ApplySafe (non-destructive) ==='
    if ((Test-Path $venvPy) -and (Test-Path $reqFile)) {
        Add-AuditLine 'Running: python -m pip install -r requirements.txt'
        & $venvPy -m pip install -r $reqFile 2>&1 | ForEach-Object { Add-AuditLine "  $_" }
    }
    $stageScript = Join-Path $Win 'Stage-KaliLabToBackups.ps1'
    if (Test-Path $stageScript) {
        Add-AuditLine 'Running: Stage-KaliLabToBackups.ps1'
        & $stageScript 2>&1 | ForEach-Object { Add-AuditLine "  $_" }
    }
}

Add-AuditLine ''
Add-AuditLine '=== SUMMARY ==='
$installed = @($rows | Where-Object { $_.Status -eq 'INSTALLED' }).Count
$pending = @($rows | Where-Object { $_.Status -eq 'PENDING' }).Count
$manual = @($rows | Where-Object { $_.Status -eq 'MANUAL' }).Count
$optional = @($rows | Where-Object { $_.Status -eq 'OPTIONAL' }).Count
Add-AuditLine ("  INSTALLED: {0} | PENDING: {1} | MANUAL: {2} | OPTIONAL: {3}" -f $installed, $pending, $manual, $optional)
Add-AuditLine ("  Log: {0}" -f $outFile)
Add-AuditLine '=== END ==='

$lines | Set-Content -Path $outFile -Encoding UTF8

if ($Json) {
    $payload = [ordered]@{
        generatedAt = (Get-Date).ToString('o')
        repo        = $Repo
        admin       = (Test-CtgIsAdmin)
        logFile     = $outFile
        summary     = @{ INSTALLED = $installed; PENDING = $pending; MANUAL = $manual; OPTIONAL = $optional }
        components  = @($rows)
    }
    $payload | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonFile -Encoding UTF8
}

Write-Output @{
    LogFile   = $outFile
    JsonFile  = if ($Json) { $jsonFile } else { $null }
    Summary   = @{ INSTALLED = $installed; PENDING = $pending; MANUAL = $manual; OPTIONAL = $optional }
    Components = @($rows)
}
