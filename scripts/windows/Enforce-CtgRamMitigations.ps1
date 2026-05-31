<#
.SYNOPSIS
  Host RAM/CPU exploit mitigation enforcer -  NOT network IPS.

.DESCRIPTION
  Network IDS (Snort/Suricata) cannot block Spectre/RETBleed/Meltdown/RAM side-channels.
  "RAM IPS" in CTG = Host Exploit Mitigation Enforcer: diagnose, apply safe host controls,
  monitor posture, and alert via Signal when exposure is detected.

  -DiagnoseOnly: SpeculationControl module (if available), RETBleed hints, HVCI/Memory integrity,
    DEP, ASLR, Windows Update pending reboot, VirtualBox Kali spec-ctrl via VBoxManage
  -ApplySafe: WU security scan (via Update-CtgExploitMitigations), enable Memory integrity if
    disabled (reboot may be required), Intel microcode guidance link, Kali VM diagnose
  -Monitor: single-pass check; if vulnerable, Send-CtgIdsAlert via Signal (companion task:
    Register-CtgRamMitigationTask.ps1)

  See docs/RAM_MITIGATION_IPS.md

.PARAMETER DiagnoseOnly
  Report posture only (default when no action switch is set).

.PARAMETER ApplySafe
  Apply safe host mitigations (no forced reboot or auto-install).

.PARAMETER Monitor
  Check posture once; alert on vulnerable state (rate-limited via Send-CtgIdsAlert).

.PARAMETER UseSecretVault
  Pass through to Send-CtgIdsAlert for Signal destination from DPAPI vault.

.EXAMPLE
  .\scripts\windows\Enforce-CtgRamMitigations.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Enforce-CtgRamMitigations.ps1 -ApplySafe

.EXAMPLE
  .\scripts\windows\Enforce-CtgRamMitigations.ps1 -Monitor -UseSecretVault
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [switch] $ApplySafe,
    [switch] $Monitor,
    [switch] $UseSecretVault
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
$script:CtgIsAdmin = Test-CtgIsAdmin

$LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
$LogFile = Join-Path $LogDir 'enforce-ctg-ram-mitigations.log'
$script:VulnerableFindings = @()

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-CtgRamLog {
    param([string] $Message, [string] $Color = 'Gray')
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Host $line -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Add-CtgRamFinding {
    param([string] $Finding)
    if ($Finding -and ($script:VulnerableFindings -notcontains $Finding)) {
        $script:VulnerableFindings += $Finding
    }
}

function Get-CtgSpeculationControlModuleReport {
    $mod = Get-Module -ListAvailable -Name SpeculationControl -ErrorAction SilentlyContinue
    if (-not $mod) {
        return @{
            Available = $false
            Summary   = 'SpeculationControl module not installed (Install-Module SpeculationControl -Scope CurrentUser)'
        }
    }
    try {
        Import-Module SpeculationControl -ErrorAction Stop
        $settings = Get-SpeculationControlSettings -ErrorAction Stop
        $lines = @()
        foreach ($prop in $settings.PSObject.Properties) {
            $lines += "$($prop.Name)=$($prop.Value)"
        }
        $text = ($lines -join '; ')
        if ($text -match 'Vulnerable|Not enabled|Not supported') {
            Add-CtgRamFinding 'Host speculation controls report possible exposure (SpeculationControl module)'
        }
        return @{ Available = $true; Summary = $text }
    } catch {
        return @{ Available = $true; Summary = "SpeculationControl error: $($_.Exception.Message)" }
    }
}

function Get-CtgRetBleedRegistryHint {
    $paths = @(
        'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
        'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Kernel'
    )
    $out = @()
    foreach ($p in $paths) {
        try {
            $props = Get-ItemProperty -Path $p -ErrorAction SilentlyContinue
            if ($props.FeatureSettingsOverride) {
                $out += "FeatureSettingsOverride=$($props.FeatureSettingsOverride)"
            }
            if ($props.FeatureSettingsOverrideMask) {
                $out += "FeatureSettingsOverrideMask=$($props.FeatureSettingsOverrideMask)"
            }
            if ($props.MitigationAuditOptions) {
                $out += "MitigationAuditOptions=$($props.MitigationAuditOptions)"
            }
        } catch { }
    }
    if ($out.Count -eq 0) {
        return 'Registry speculation keys not exposed (rely on Windows Update + BIOS microcode -  Intel SA-00702 RETBleed)'
    }
    return ($out -join '; ')
}

function Get-CtgMemoryIntegrityStatus {
    try {
        $dg = Get-CimInstance -Namespace 'root/Microsoft/Windows/DeviceGuard' `
            -ClassName Win32_DeviceGuard -ErrorAction Stop
        $running = @($dg.SecurityServicesRunning)
        $hvciOn = $running -contains 2
        $cfg = $dg.CodeIntegrityPolicyEnforcementStatus
        return @{
            HvciRunning = $hvciOn
            Summary     = "HVCI/MemoryIntegrity running=$hvciOn; CodeIntegrityPolicy=$cfg; Services=$($running -join ',')"
        }
    } catch {
        try {
            $enabled = (Get-ItemProperty -Path `
                'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' `
                -Name 'Enabled' -ErrorAction Stop).Enabled
            $on = ($enabled -eq 1)
            return @{ HvciRunning = $on; Summary = "Memory integrity registry Enabled=$enabled" }
        } catch {
            return @{ HvciRunning = $null; Summary = 'Memory integrity status unavailable' }
        }
    }
}

function Get-CtgDepAslrStatus {
    $dep = $null
    $aslr = $null
    try {
        $out = (& bcdedit /enum '{current}' 2>&1 | Out-String)
        if ($out -match 'nx\s+(\S+)') { $dep = $Matches[1] }
        if ($out -match 'increaseuserva\s+(\S+)') { $aslr = "increaseuserva=$($Matches[1])" }
        if ($out -match 'disableelamdrivers\s+(\S+)') { $aslr += "; disableelamdrivers=$($Matches[1])" }
    } catch { }
    if (-not $dep) {
        try {
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $dep = if ($os.DataExecutionPrevention_Available) { 'Available' } else { 'Unavailable' }
        } catch {
            $dep = 'unknown'
        }
    }
    if ($dep -eq 'AlwaysOff' -or $dep -eq 'Unavailable') {
        Add-CtgRamFinding 'DEP not fully enabled'
    }
    $aslrText = if ($aslr) { $aslr } else { 'see bcdedit /enum {current}' }
    return "DEP=$dep; ASLR=$aslrText"
}

function Get-CtgWuSecurityPending {
    $pending = $false
    $reasons = @()
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        $pending = $true
        $reasons += 'WU RebootRequired'
    }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        $pending = $true
        $reasons += 'CBS RebootPending'
    }
    if ($pending) {
        Add-CtgRamFinding 'Pending reboot -  security/microcode updates may not be active until reboot'
    }
    $detail = if ($reasons.Count -gt 0) { ($reasons -join ', ') } else { 'none' }
    return @{ Pending = $pending; Summary = "RebootPending=$pending ($detail)" }
}

function Invoke-CtgKaliVmSpecCtrlDiagnose {
    $helper = Join-Path $PSScriptRoot 'Harden-KaliVmCpu.ps1'
    if (-not (Test-Path $helper)) {
        Write-CtgRamLog 'Harden-KaliVmCpu.ps1 missing -  skip Kali VM spec-ctrl diagnose' 'Yellow'
        return
    }
    Write-CtgRamLog '--- Kali VM spec-ctrl (VirtualBox guest MSR exposure) ---' 'Cyan'
    $output = @()
    try {
        & $helper -DiagnoseOnly 2>&1 | ForEach-Object {
            $line = "$_"
            $output += $line
            Write-CtgRamLog "  $line"
        }
    } catch {
        Write-CtgRamLog "Kali VM diagnose failed: $($_.Exception.Message)" 'Yellow'
        return
    }
    $joined = $output -join ' '
    if ($joined -match 'spec-ctrl is OFF') {
        Add-CtgRamFinding 'Kali VM spec-ctrl OFF -  guest RETBleed/Spectre v2 exposure until Harden-KaliVmCpu.ps1 applied (VM off)'
    }
}

function Invoke-CtgEnableMemoryIntegritySafe {
    if (-not $script:CtgIsAdmin) {
        Write-CtgRamLog 'Memory integrity enable skipped (Administrator required)' 'Yellow'
        return
    }
    $st = Get-CtgMemoryIntegrityStatus
    if ($st.HvciRunning -eq $true) {
        Write-CtgRamLog 'Memory integrity / HVCI already enabled' 'Green'
        return
    }
    $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
    try {
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath -Name 'Enabled' -Value 1 -Type DWord -Force
        Write-CtgRamLog 'Memory integrity Enabled=1 written -  reboot required for HVCI to take effect' 'Yellow'
        Write-CtgRamLog 'Settings -> Privacy & security -> Windows Security -> Device security -> Core isolation' 'Gray'
    } catch {
        Write-CtgRamLog "Memory integrity enable failed: $($_.Exception.Message)" 'Yellow'
    }
}

function Invoke-CtgRamDiagnose {
    Write-CtgRamLog '=== CTG RAM mitigation enforcer (host -  NOT network IPS) ===' 'Cyan'
    Write-CtgRamLog 'Snort/Suricata block network exploits; Spectre/RETBleed/Meltdown need microcode + OS patches.' 'Yellow'

    Write-CtgRamLog '--- SpeculationControl module ---' 'Cyan'
    $sc = Get-CtgSpeculationControlModuleReport
    Write-CtgRamLog ("  Available={0}; {1}" -f $sc.Available, $sc.Summary)

    Write-CtgRamLog '--- RETBleed / speculation registry ---' 'Cyan'
    Write-CtgRamLog ("  {0}" -f (Get-CtgRetBleedRegistryHint))

    Write-CtgRamLog '--- HVCI / Memory integrity ---' 'Cyan'
    $mi = Get-CtgMemoryIntegrityStatus
    Write-CtgRamLog ("  {0}" -f $mi.Summary) $(if ($mi.HvciRunning) { 'Green' } else { 'Yellow' })
    if ($mi.HvciRunning -eq $false) {
        Add-CtgRamFinding 'Memory integrity / HVCI not running'
    }

    Write-CtgRamLog '--- DEP / ASLR ---' 'Cyan'
    Write-CtgRamLog ("  {0}" -f (Get-CtgDepAslrStatus))

    Write-CtgRamLog '--- Windows Update pending reboot ---' 'Cyan'
    $wu = Get-CtgWuSecurityPending
    Write-CtgRamLog ("  {0}" -f $wu.Summary) $(if ($wu.Pending) { 'Yellow' } else { 'Green' })

    Invoke-CtgKaliVmSpecCtrlDiagnose

    Write-CtgRamLog '--- Intel RETBleed microcode guidance ---' 'Cyan'
    Write-CtgRamLog '  https://www.intel.com/content/www/us/en/security-center/advisory/intel-sa-00702.html' 'Gray'

    Write-CtgRamLog '--- Kali guest (manual in VM) ---' 'Cyan'
    Write-CtgRamLog '  bash /mnt/ctg/ctg-ram-mitigation-enforcer.sh' 'Gray'
    Write-CtgRamLog '  bash /mnt/ctg/ctg-exploit-mitigations-check.sh' 'Gray'

    if ($script:VulnerableFindings.Count -gt 0) {
        Write-CtgRamLog ("VULNERABLE: {0}" -f ($script:VulnerableFindings -join ' | ')) 'Red'
        return $false
    }
    Write-CtgRamLog 'Posture: no CTG RAM-mit vulnerable findings on this pass' 'Green'
    return $true
}

function Invoke-CtgRamApplySafe {
    Write-CtgRamLog '--- ApplySafe: delegate WU scan to Update-CtgExploitMitigations ---' 'Cyan'
    $upd = Join-Path $PSScriptRoot 'Update-CtgExploitMitigations.ps1'
    if (Test-Path $upd) {
        & $upd -ApplySafe 2>&1 | ForEach-Object { Write-CtgRamLog "  upd: $_" }
    } else {
        Write-CtgRamLog 'Update-CtgExploitMitigations.ps1 missing' 'Yellow'
    }

    Invoke-CtgEnableMemoryIntegritySafe

    Write-CtgRamLog '--- ApplySafe: re-diagnose after safe apply ---' 'Cyan'
    Invoke-CtgRamDiagnose | Out-Null

    Write-CtgRamLog 'ApplySafe complete -  install WU packages when ready; reboot if CBS/HVCI requires' 'Green'
}

function Invoke-CtgRamMonitor {
    $ok = Invoke-CtgRamDiagnose
    if ($ok) {
        Write-CtgRamLog 'Monitor: posture OK -  no alert sent' 'Green'
        return 0
    }

    $alertScript = Join-Path $PSScriptRoot 'Send-CtgIdsAlert.ps1'
    if (-not (Test-Path $alertScript)) {
        Write-CtgRamLog 'Send-CtgIdsAlert.ps1 missing -  cannot alert' 'Red'
        return 1
    }

    $primary = $script:VulnerableFindings | Select-Object -First 1
    $msg = "CTG RAM-mit: $primary - run Update-CtgExploitMitigations.ps1 -ApplySafe; see docs/RAM_MITIGATION_IPS.md"
    Write-CtgRamLog "Monitor: sending alert -  $msg" 'Yellow'

    $alertArgs = @{
        AlertType = 'ram-mit-exposure'
        Message   = $msg
        Severity  = 'high'
    }
    if ($UseSecretVault) { $alertArgs['UseSecretVault'] = $true }

    & $alertScript @alertArgs
    return $LASTEXITCODE
}

# --- Main ---
if ($Monitor) {
    $code = Invoke-CtgRamMonitor
    Write-CtgRamLog "Log: $LogFile" 'DarkGray'
    exit $code
}

if ($ApplySafe) {
    Invoke-CtgRamApplySafe
    Write-CtgRamLog "Log: $LogFile" 'DarkGray'
    exit $(if ($script:VulnerableFindings.Count -gt 0) { 1 } else { 0 })
}

# Default: DiagnoseOnly
Invoke-CtgRamDiagnose | Out-Null
Write-CtgRamLog "Log: $LogFile" 'DarkGray'
exit $(if ($script:VulnerableFindings.Count -gt 0) { 1 } else { 0 })
