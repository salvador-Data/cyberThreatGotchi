<#
.SYNOPSIS
  Host RAM/CPU exploit mitigation enforcer -  NOT network IPS.

.DESCRIPTION
  Network IDS (Snort/Suricata) cannot block Spectre/RETBleed/Meltdown/RAM side-channels.
  "RAM IPS" in CTG = Host Exploit Mitigation Enforcer: diagnose, apply safe host controls,
  monitor posture, and alert via Signal when exposure is detected.

  -DiagnoseOnly: SpeculationControl module (if available), RETBleed hints, HVCI/Memory integrity,
    VBS/Core isolation, Kernel DMA protection, Credential Guard, DEP, ASLR, hypervisor/VBox lab notes,
    Windows Update pending reboot, VirtualBox Kali spec-ctrl + nested virt via VBoxManage,
    vault session TTL recommendation (CTG_VAULT_SESSION_TTL)
  -ApplySafe: WU security scan (via Update-CtgExploitMitigations), enable Memory integrity if
    disabled (reboot may be required), Intel microcode guidance link, Kali VM diagnose
  -Monitor: single-pass check; if vulnerable, Send-CtgIdsAlert via Signal (companion task:
    Register-CtgRamMitigationTask.ps1)

  See docs/MEMORY_PROTECTION.md and docs/RAM_MITIGATION_IPS.md

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

function Get-CtgDeviceGuardReport {
    try {
        $dg = Get-CimInstance -Namespace 'root/Microsoft/Windows/DeviceGuard' `
            -ClassName Win32_DeviceGuard -ErrorAction Stop
        $vbsStatus = $dg.VirtualizationBasedSecurityStatus
        $vbsText = switch ($vbsStatus) {
            0 { 'VBS disabled' }
            1 { 'VBS enabled but not running (reboot or firmware check)' }
            2 { 'VBS enabled and running' }
            default { "VBS status=$vbsStatus" }
        }
        $running = @($dg.SecurityServicesRunning)
        $configured = @($dg.SecurityServicesConfigured)
        $credGuard = ($running -contains 1)
        $hvci = ($running -contains 2)
        $sysGuard = ($running -contains 3)
        return @{
            VbsSummary          = $vbsText
            VbsRunning          = ($vbsStatus -eq 2)
            CredentialGuard     = $credGuard
            HvciRunning         = $hvci
            SystemGuard         = $sysGuard
            ServicesRunning     = ($running -join ',')
            ServicesConfigured  = ($configured -join ',')
            AvailableProperties = ($dg.AvailableSecurityProperties -join ',')
            RequiredProperties  = ($dg.RequiredSecurityProperties -join ',')
        }
    } catch {
        return @{
            VbsSummary         = "DeviceGuard WMI unavailable: $($_.Exception.Message)"
            VbsRunning         = $null
            CredentialGuard    = $null
            HvciRunning        = $null
            SystemGuard        = $null
            ServicesRunning    = ''
            ServicesConfigured = ''
            AvailableProperties = ''
            RequiredProperties  = ''
        }
    }
}

function Get-CtgKernelDmaProtectionStatus {
    $enabled = $null
    $summary = 'Kernel DMA protection status unavailable'
    try {
        $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelDmaProtection'
        if (Test-Path $regPath) {
            $enabled = (Get-ItemProperty -Path $regPath -Name 'Enabled' -ErrorAction Stop).Enabled
            $summary = "Kernel DMA protection registry Enabled=$enabled"
        }
    } catch { }
    if ($null -eq $enabled) {
        try {
            $dg = Get-CimInstance -Namespace 'root/Microsoft/Windows/DeviceGuard' `
                -ClassName Win32_DeviceGuard -ErrorAction Stop
            $avail = @($dg.AvailableSecurityProperties)
            $dmaAvail = ($avail -contains 3) -or ($avail -contains 1)
            $summary = "AvailableSecurityProperties=$($avail -join ','); DMA-capable firmware hint=$dmaAvail"
            if ($dmaAvail) { $enabled = $true }
        } catch {
            $summary = 'Kernel DMA protection: check msinfo32 -> System Summary -> Kernel DMA Protection'
        }
    }
    if ($enabled -eq 0) {
        Add-CtgRamFinding 'Kernel DMA protection disabled - Thunderbolt/PCIe DMA attack surface (enable in firmware + Device Guard)'
    }
    return @{ Enabled = $enabled; Summary = $summary }
}

function Get-CtgHypervisorVBoxLabNotes {
    $notes = @()
    $hypervisorLaunch = 'unknown'
    try {
        $bcd = (& bcdedit /enum '{current}' 2>&1 | Out-String)
        if ($bcd -match 'hypervisorlaunchtype\s+(\S+)') {
            $hypervisorLaunch = $Matches[1]
        }
    } catch { }
    $notes += "hypervisorlaunchtype=$hypervisorLaunch"

    $vmp = $null
    $hyperv = $null
    try {
        $vmp = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue
        if ($vmp) { $notes += "VirtualMachinePlatform=$($vmp.State)" }
    } catch { }
    try {
        $hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
        if ($hyperv) { $notes += "Hyper-V-All=$($hyperv.State)" }
    } catch { }

    $notes += 'CTG policy: NEVER disable Memory integrity/VBS/HVCI for VirtualBox speed - see docs/MEMORY_PROTECTION.md'
    $notes += 'Microsoft: VBS/Hyper-V and third-party hypervisors share VT-x - VBox may use emulated (slow) mode while VBS runs'
    $notes += 'Lab: keep --spec-ctrl on for Kali guest; accept perf tradeoff or schedule heavy VM work when posture allows'

    if ($hypervisorLaunch -eq 'Auto' -or $hypervisorLaunch -eq 'On') {
        $notes += 'Host hypervisor active (expected with VBS/HVCI) - verify VBox not in green-turtle emulated mode'
    }
    return ($notes -join ' | ')
}

function Get-CtgKaliVmHypervisorDiagnose {
    $vbox = Join-Path ${env:ProgramFiles} 'Oracle\VirtualBox\VBoxManage.exe'
    if (-not (Test-Path $vbox)) {
        return 'VBoxManage not found - skip nested/spec-ctrl extended diagnose'
    }
    $helper = Join-Path $PSScriptRoot 'Harden-KaliVmCpu.ps1'
    if (Test-Path $helper) {
        Invoke-CtgKaliVmSpecCtrlDiagnose
    }
    $vmName = $null
    $list = (& $vbox list vms 2>&1 | Out-String)
    foreach ($candidate in @('kali', 'Kali-Lab', 'Kali', 'kali-linux')) {
        if ($list -match "`"$([regex]::Escape($candidate))`"") { $vmName = $candidate; break }
    }
    if (-not $vmName) {
        Write-CtgRamLog '  No Kali VM found for nested-virt diagnose' 'Gray'
        return
    }
    Write-CtgRamLog '--- Kali VM hypervisor flags (nested virt, spec-ctrl) ---' 'Cyan'
    $info = (& $vbox showvminfo $vmName --machinereadable 2>&1 | Out-String)
    $nested = if ($info -match 'nestedpaging="([^"]+)"') { $Matches[1] } else { 'unknown' }
    $virt = if ($info -match 'virtvms="([^"]+)"') { $Matches[1] } else { 'unknown' }
    $largePages = if ($info -match 'largepages="([^"]+)"') { $Matches[1] } else { 'unknown' }
    Write-CtgRamLog "  VM=$vmName nestedpaging=$nested virtvms=$virt largepages=$largePages"
    if ($nested -eq 'off') {
        Add-CtgRamFinding 'Kali VM nested paging OFF - guest CPU mitigations may be degraded'
    }
}

function Get-CtgVaultSessionRecommendation {
    $ttl = $env:CTG_VAULT_SESSION_TTL
    if (-not $ttl) { $ttl = '900 (default 15 min)' }
    return @{
        TtlEnv   = $env:CTG_VAULT_SESSION_TTL
        Summary  = "CTG_VAULT_SESSION_TTL=$ttl - lock vault when idle: .\Ctg-CredentialVault.ps1 -LockVault"
        DocLink  = 'docs/SECRET_VAULT.md#session-timeout-and-memory-limits'
    }
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

    Write-CtgRamLog '--- VBS / Core isolation / Device Guard ---' 'Cyan'
    $dg = Get-CtgDeviceGuardReport
    Write-CtgRamLog ("  {0}" -f $dg.VbsSummary) $(if ($dg.VbsRunning) { 'Green' } else { 'Yellow' })
    Write-CtgRamLog ("  ServicesRunning={0}; Configured={1}" -f $dg.ServicesRunning, $dg.ServicesConfigured) 'Gray'
    if ($dg.VbsRunning -eq $false) {
        Add-CtgRamFinding 'VBS not running - Core isolation stack may be inactive (reboot after enable)'
    }

    Write-CtgRamLog '--- HVCI / Memory integrity ---' 'Cyan'
    $mi = Get-CtgMemoryIntegrityStatus
    Write-CtgRamLog ("  {0}" -f $mi.Summary) $(if ($mi.HvciRunning) { 'Green' } else { 'Yellow' })
    if ($mi.HvciRunning -eq $false) {
        Add-CtgRamFinding 'Memory integrity / HVCI not running'
    }

    Write-CtgRamLog '--- Credential Guard ---' 'Cyan'
    $cgOn = $dg.CredentialGuard
    $cgText = if ($null -eq $cgOn) { 'unavailable' } elseif ($cgOn) { 'running (SecurityServicesRunning contains 1)' } else { 'not running (optional on standalone Win11 Pro)' }
    Write-CtgRamLog ("  {0}" -f $cgText) $(if ($cgOn) { 'Green' } else { 'Gray' })

    Write-CtgRamLog '--- Kernel DMA protection ---' 'Cyan'
    $dma = Get-CtgKernelDmaProtectionStatus
    Write-CtgRamLog ("  {0}" -f $dma.Summary) $(if ($dma.Enabled) { 'Green' } else { 'Yellow' })

    Write-CtgRamLog '--- Hypervisor / VirtualBox lab (never disable mitigations for perf) ---' 'Cyan'
    Write-CtgRamLog ("  {0}" -f (Get-CtgHypervisorVBoxLabNotes)) 'Gray'

    Write-CtgRamLog '--- DEP / ASLR ---' 'Cyan'
    Write-CtgRamLog ("  {0}" -f (Get-CtgDepAslrStatus))

    Write-CtgRamLog '--- Windows Update pending reboot ---' 'Cyan'
    $wu = Get-CtgWuSecurityPending
    Write-CtgRamLog ("  {0}" -f $wu.Summary) $(if ($wu.Pending) { 'Yellow' } else { 'Green' })

    Get-CtgKaliVmHypervisorDiagnose

    Write-CtgRamLog '--- Credential vault session ---' 'Cyan'
    $vaultRec = Get-CtgVaultSessionRecommendation
    Write-CtgRamLog ("  {0}" -f $vaultRec.Summary) 'Gray'
    Write-CtgRamLog ("  See {0}" -f $vaultRec.DocLink) 'DarkGray'

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
