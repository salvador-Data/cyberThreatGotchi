<#
.SYNOPSIS
  Conservative CPU performance diagnose and safe Windows-level optimization (no script OC).

.DESCRIPTION
  Diagnose-only by default: CPU model, cores, turbo policy, laptop vs desktop heuristic,
  thermal hints, Intel XTU / AMD Ryzen Master applicability.

  -ApplySafe: high/ultimate performance on AC, aggressive boost if supported, min/max 100% on AC,
  disable core parking on AC only. With -BalancedOnBattery (default ON), battery stays on Balanced.

  -ApplyUnsafe: NOT implemented — prints BIOS/XTU manual guidance only.

  Logs to %USERPROFILE%\Backups\logs\optimize-cpu.log — no secrets.

.PARAMETER DiagnoseOnly
  Report current CPU and power posture (default when -ApplySafe omitted).

.PARAMETER ApplySafe
  Apply conservative Windows power tweaks (Administrator recommended).

.PARAMETER ApplyUnsafe
  Rejected — voltage/frequency OC requires BIOS or vendor tools (manual only).

.PARAMETER BalancedOnBattery
  When applying safe tweaks, leave Balanced plan active on battery (default ON).

.EXAMPLE
  .\scripts\windows\Optimize-CpuPerformance.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Run-AsAdmin.ps1 -TargetScript .\scripts\windows\Optimize-CpuPerformance.ps1 -TargetArguments '-ApplySafe'
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch] $DiagnoseOnly,
    [switch] $ApplySafe,
    [switch] $ApplyUnsafe,
    [switch] $BalancedOnBattery = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
$script:CtgIsAdmin = Test-CtgIsAdmin

$LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
$LogFile = Join-Path $LogDir 'optimize-cpu.log'

$HighPerfGuid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
$UltimateGuid = 'e9a42b8d-02a5-4dd1-9a83-421f5de58455'
$BalancedGuid = '381b4222-f694-41f0-9685-ff5bb260df2e'

# powercfg subgroup / setting aliases (processor)
$ProcSubgroup = '54533251-82be-4824-96c1-47b60b740d00'
$BoostSetting = 'be337238-0d82-4806-9cbc-d0cb787ae1b5'
$MinStateSetting = '893dee8e-2bef-41e7-89c6-beb8e44fb58e'
$MaxStateSetting = 'bc5038f7-23e0-4960-96da-33abaf5935ec'
$MinCoresSetting = '942c6ddb-bae3-4056-9142-f878fce013a5'
$ParkPerfSetting = '0cc5b647-c1df-4637-891a-dec35c318583'

function Write-CtgCpuLog {
    param([string] $Message, [string] $Color = 'Gray')
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    try {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        Add-Content -Path $LogFile -Value $line -Encoding utf8 -ErrorAction SilentlyContinue
    } catch { }
    Write-Host $line -ForegroundColor $Color
}

function Get-CtgCpuInfo {
    $cpus = @()
    try {
        Get-CimInstance Win32_Processor -ErrorAction Stop | ForEach-Object {
            $cpus += [PSCustomObject]@{
                Name              = $_.Name.Trim()
                Manufacturer      = $_.Manufacturer
                Cores             = $_.NumberOfCores
                LogicalProcessors = $_.NumberOfLogicalProcessors
                MaxClockMHz       = $_.MaxClockSpeed
                CurrentClockMHz   = $_.CurrentClockSpeed
                LoadPercent       = $_.LoadPercentage
                Architecture      = $_.Architecture
                Socket            = $_.SocketDesignation
            }
        }
    } catch {
        Write-CtgCpuLog "Win32_Processor query failed: $($_.Exception.Message)" 'Yellow'
    }
    return $cpus
}

function Get-CtgFormFactorHint {
    $hint = [ordered]@{
        IsLikelyLaptop   = $false
        PCSystemType     = $null
        ChassisTypes     = @()
        BatteryPresent   = $false
        BatteryStatus    = 'unknown'
        HeuristicSummary = ''
    }

    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $hint.PCSystemType = $cs.PCSystemType
        # 1=Desktop, 2=Mobile, 3=Workstation, 4=Enterprise Server, 5=SOHO Server, 6=Appliance PC
        if ($cs.PCSystemType -eq 2) {
            $hint.IsLikelyLaptop = $true
        }
    } catch { }

    try {
        $enc = Get-CimInstance Win32_SystemEnclosure -ErrorAction Stop
        $types = @($enc.ChassisTypes)
        $hint.ChassisTypes = $types
        # 8=Portable, 9=Laptop, 10=Notebook, 14=Sub Notebook
        foreach ($t in $types) {
            if ($t -in 8, 9, 10, 14, 11, 12, 21, 31, 32) {
                $hint.IsLikelyLaptop = $true
                break
            }
        }
    } catch { }

    try {
        $bat = Get-CimInstance Win32_Battery -ErrorAction Stop | Select-Object -First 1
        if ($bat) {
            $hint.BatteryPresent = $true
            $hint.IsLikelyLaptop = $true
            $hint.BatteryStatus = "EstimatedChargeRemaining=$($bat.EstimatedChargeRemaining)%"
        }
    } catch {
        $hint.BatteryPresent = $false
    }

    if ($hint.IsLikelyLaptop) {
        $hint.HeuristicSummary = 'Likely laptop/mobile — BIOS voltage/frequency OC usually unavailable or unsafe'
    } else {
        $hint.HeuristicSummary = 'Likely desktop/workstation — BIOS OC may be possible; still not scripted here'
    }
    return [PSCustomObject]$hint
}

function Get-CtgOcToolHint {
    $result = [ordered]@{
        IntelXtuInstalled    = $false
        AmdRyzenMasterInstalled = $false
        Recommendation       = ''
    }

    $xtuPaths = @(
        "${env:ProgramFiles}\Intel\Intel(R) Extreme Tuning Utility\Client\XTUCli.exe"
        "${env:ProgramFiles(x86)}\Intel\Intel(R) Extreme Tuning Utility\Client\XTUCli.exe"
    )
    foreach ($p in $xtuPaths) {
        if (Test-Path $p) {
            $result.IntelXtuInstalled = $true
            break
        }
    }

    $ryzenPaths = @(
        "${env:ProgramFiles}\AMD\RyzenMaster\bin\AMD Ryzen Master.exe"
        "${env:ProgramFiles(x86)}\AMD\RyzenMaster\bin\AMD Ryzen Master.exe"
    )
    foreach ($p in $ryzenPaths) {
        if (Test-Path $p) {
            $result.AmdRyzenMasterInstalled = $true
            break
        }
    }

    if ($result.IntelXtuInstalled) {
        $result.Recommendation = 'Intel XTU detected — manual tuning only; monitor thermals'
    } elseif ($result.AmdRyzenMasterInstalled) {
        $result.Recommendation = 'AMD Ryzen Master detected — manual PBO/curve only; monitor thermals'
    } else {
        $result.Recommendation = 'No vendor OC tool detected — use BIOS for any frequency/voltage changes'
    }
    return [PSCustomObject]$result
}

function Get-CtgActivePowerPlan {
    try {
        $raw = powercfg /getactivescheme 2>&1 | Out-String
        $guid = $null
        $name = $null
        if ($raw -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') {
            $guid = $Matches[1]
        }
        if ($raw -match '\(([^)]+)\)') {
            $name = $Matches[1]
        }
        return [PSCustomObject]@{ Raw = $raw.Trim(); Guid = $guid; Name = $name }
    } catch {
        return [PSCustomObject]@{ Raw = $_.Exception.Message; Guid = $null; Name = $null }
    }
}

function Get-CtgPowerSettingValue {
    param(
        [string] $PlanGuid,
        [string] $Subgroup,
        [string] $Setting,
        [ValidateSet('AC', 'DC')]
        [string] $PowerSource = 'AC'
    )
    $flag = if ($PowerSource -eq 'AC') { '/setacvalueindex' } else { '/setdcvalueindex' }
    try {
        $query = powercfg /query $PlanGuid $Subgroup $Setting 2>&1 | Out-String
        $suffix = if ($PowerSource -eq 'AC') { 'Current AC Power Setting Index' } else { 'Current DC Power Setting Index' }
        if ($query -match "(?m)${suffix}:\s*0x([0-9a-f]+)") {
            return [int]('0x' + $Matches[1])
        }
    } catch { }
    return $null
}

function Get-CtgBoostModeLabel {
    param([int] $Value)
    switch ($Value) {
        0 { return 'Disabled' }
        1 { return 'Enabled' }
        2 { return 'Aggressive' }
        3 { return 'Efficient enabled' }
        4 { return 'Efficient aggressive' }
        default { return "Unknown ($Value)" }
    }
}

function Get-CtgThermalHints {
    $rows = @()
    try {
        Get-CimInstance MSAcpi_ThermalZoneTemperature -ErrorAction Stop | ForEach-Object {
            $c = [math]::Round(($_.CurrentTemperature / 10) - 273.15, 1)
            $rows += "ThermalZone: ${c}C (raw=$($_.CurrentTemperature))"
        }
    } catch {
        $rows += "MSAcpi_ThermalZoneTemperature: unavailable ($($_.Exception.Message))"
    }

    try {
        $perf = Get-CimInstance Win32_PerfFormattedData_Counters_ThermalZoneInformation -ErrorAction Stop
        foreach ($p in $perf) {
            if ($p.HighPrecisionTemperature) {
                $rows += "PerfCounter $($p.Name): $($p.HighPrecisionTemperature)"
            }
        }
    } catch { }

    $cpus = Get-CtgCpuInfo
    foreach ($c in $cpus) {
        if ($c.MaxClockMHz -and $c.CurrentClockMHz -and $c.MaxClockMHz -gt 0) {
            $pct = [math]::Round(100 * $c.CurrentClockMHz / $c.MaxClockMHz, 1)
            $rows += "Clock ratio $($c.CurrentClockMHz)/$($c.MaxClockMHz) MHz ($pct pct) - low ratio under load may indicate throttling"
        }
    }
    if ($rows.Count -eq 0) {
        $rows += 'No thermal WMI data — run elevated for ACPI zones; watch fan noise and sustained clock drops'
    }
    return $rows
}

function Test-CtgUltimatePlanAvailable {
    try {
        $list = powercfg /list 2>&1 | Out-String
        return ($list -match [regex]::Escape($UltimateGuid))
    } catch {
        return $false
    }
}

function Enable-CtgUltimatePerformancePlan {
    $dup = powercfg /duplicatescheme $UltimateGuid 2>&1 | Out-String
    if ($dup -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') {
        return $Matches[1]
    }
    return $null
}

function Set-CtgPowerSetting {
    param(
        [string] $PlanGuid,
        [string] $Subgroup,
        [string] $Setting,
        [int] $AcValue,
        [int] $DcValue
    )
    powercfg /setacvalueindex $PlanGuid $Subgroup $Setting $AcValue 2>&1 | Out-Null
    powercfg /setdcvalueindex $PlanGuid $Subgroup $Setting $DcValue 2>&1 | Out-Null
}

function Invoke-CtgCpuDiagnose {
    Write-CtgCpuLog '=== CPU performance diagnose ===' 'Cyan'

    $cpus = Get-CtgCpuInfo
    foreach ($c in $cpus) {
        Write-CtgCpuLog ("CPU: {0}" -f $c.Name) 'White'
        Write-CtgCpuLog ("  Cores={0} Threads={1} MaxClock={2}MHz Current={3}MHz Load={4}%" -f `
            $c.Cores, $c.LogicalProcessors, $c.MaxClockMHz, $c.CurrentClockMHz, $c.LoadPercent)
        $mfr = $c.Manufacturer
        if ($mfr -match 'Intel') {
            Write-CtgCpuLog '  Vendor: Intel — turbo via Windows power policy; OC via BIOS/XTU only' 'Gray'
        } elseif ($mfr -match 'AMD') {
            Write-CtgCpuLog '  Vendor: AMD — PBO/curve in BIOS/Ryzen Master only' 'Gray'
        }
    }

    $form = Get-CtgFormFactorHint
    Write-CtgCpuLog ("Form factor: {0} (PCSystemType={1}, Battery={2})" -f `
        $form.HeuristicSummary, $form.PCSystemType, $form.BatteryPresent) 'Yellow'

    $tools = Get-CtgOcToolHint
    Write-CtgCpuLog ("OC tools: IntelXTU={0} RyzenMaster={1}" -f $tools.IntelXtuInstalled, $tools.AmdRyzenMasterInstalled) 'Gray'
    Write-CtgCpuLog ("  $($tools.Recommendation)") 'Gray'

    $plan = Get-CtgActivePowerPlan
    Write-CtgCpuLog ("Active power plan: {0} [{1}]" -f $plan.Name, $plan.Guid) 'White'

    if ($plan.Guid) {
        foreach ($src in @('AC', 'DC')) {
            $boost = Get-CtgPowerSettingValue -PlanGuid $plan.Guid -Subgroup $ProcSubgroup -Setting $BoostSetting -PowerSource $src
            $minSt = Get-CtgPowerSettingValue -PlanGuid $plan.Guid -Subgroup $ProcSubgroup -Setting $MinStateSetting -PowerSource $src
            $maxSt = Get-CtgPowerSettingValue -PlanGuid $plan.Guid -Subgroup $ProcSubgroup -Setting $MaxStateSetting -PowerSource $src
            if ($null -ne $boost) {
                Write-CtgCpuLog ("  {0}: boost={1}, min={2}%, max={3}%" -f $src, (Get-CtgBoostModeLabel $boost), $minSt, $maxSt) 'Gray'
            }
        }
    }

    Write-CtgCpuLog 'Thermal hints:' 'Cyan'
    foreach ($t in Get-CtgThermalHints) {
        Write-CtgCpuLog "  $t" 'Gray'
    }

    Write-CtgCpuLog 'Script OC (-ApplyUnsafe): NOT supported — see docs/CPU_PERFORMANCE.md' 'Yellow'
    Write-CtgCpuLog "Log: $LogFile" 'DarkGray'
}

function Invoke-CtgCpuApplySafe {
    if (-not $script:CtgIsAdmin) {
        Write-CtgCpuLog 'ApplySafe requires Administrator — use Run-AsAdmin.ps1' 'Red'
        return 1
    }

    Write-CtgCpuLog '=== Applying safe CPU performance tweaks (AC-focused) ===' 'Cyan'

    $targetGuid = $HighPerfGuid
    $targetName = 'High performance'

    if (Test-CtgUltimatePlanAvailable) {
        $targetGuid = $UltimateGuid
        $targetName = 'Ultimate Performance'
    } else {
        $dupGuid = Enable-CtgUltimatePerformancePlan
        if ($dupGuid) {
            $targetGuid = $dupGuid
            $targetName = 'Ultimate Performance (duplicated)'
            Write-CtgCpuLog "Enabled Ultimate Performance plan: $targetGuid" 'Green'
        }
    }

    if ($PSCmdlet.ShouldProcess($targetName, 'Activate power plan')) {
        powercfg /setactive $targetGuid 2>&1 | Out-Null
        Write-CtgCpuLog "Activated plan: $targetName ($targetGuid)" 'Green'
    }

    $plansToTune = @($targetGuid)
    if ($BalancedOnBattery) {
        $plansToTune += $BalancedGuid
        Write-CtgCpuLog 'BalancedOnBattery=ON — aggressive AC tweaks on performance plan; Balanced DC limits preserved on battery plan' 'Yellow'
    }

    foreach ($pg in $plansToTune) {
        $isPerf = ($pg -eq $targetGuid)
        $acMin = if ($isPerf) { 100 } else { 5 }
        $acMax = if ($isPerf) { 100 } else { 100 }
        $dcMin = if ($isPerf -and -not $BalancedOnBattery) { 100 } else { 5 }
        $dcMax = if ($isPerf -and -not $BalancedOnBattery) { 100 } else { 100 }
        $acBoost = if ($isPerf) { 2 } else { 1 }
        $dcBoost = 1

        if ($PSCmdlet.ShouldProcess($pg, 'Set processor power settings')) {
            Set-CtgPowerSetting -PlanGuid $pg -Subgroup $ProcSubgroup -Setting $BoostSetting -AcValue $acBoost -DcValue $dcBoost
            Set-CtgPowerSetting -PlanGuid $pg -Subgroup $ProcSubgroup -Setting $MinStateSetting -AcValue $acMin -DcValue $dcMin
            Set-CtgPowerSetting -PlanGuid $pg -Subgroup $ProcSubgroup -Setting $MaxStateSetting -AcValue $acMax -DcValue $dcMax
            # Core parking: 100% min cores / perf floor on AC only for performance plan
            Set-CtgPowerSetting -PlanGuid $pg -Subgroup $ProcSubgroup -Setting $MinCoresSetting -AcValue $(if ($isPerf) { 100 } else { 0 }) -DcValue 0
            Set-CtgPowerSetting -PlanGuid $pg -Subgroup $ProcSubgroup -Setting $ParkPerfSetting -AcValue $(if ($isPerf) { 100 } else { 50 }) -DcValue 50
            powercfg /setactive $pg 2>&1 | Out-Null
            Write-CtgCpuLog ("Tuned plan $pg (perf=$isPerf): AC boost=$acBoost min=$acMin max=$acMax") 'Green'
            # Re-apply settings to store in scheme (powercfg requires setactive after value changes)
        }
    }

    powercfg /setactive $targetGuid 2>&1 | Out-Null
    Write-CtgCpuLog 'Safe apply complete — monitor thermals; revert via powercfg /setactive for Balanced if needed' 'Cyan'
    Invoke-CtgCpuDiagnose
    return 0
}

function Invoke-CtgCpuApplyUnsafe {
    Write-CtgCpuLog '=== ApplyUnsafe rejected ===' 'Red'
    Write-CtgCpuLog 'Voltage/frequency overclock is NOT implemented in this script.' 'Yellow'
    Write-CtgCpuLog 'Reason: thermal runaway, warranty, and instability risk on laptops.' 'Yellow'
    Write-CtgCpuLog 'Manual only: BIOS/UEFI or Intel XTU / AMD Ryzen Master with stress testing.' 'Yellow'
    Write-CtgCpuLog 'Doc: docs/CPU_PERFORMANCE.md (repo) or https://github.com/salvador-Data/cyberThreatGotchi/blob/main/docs/CPU_PERFORMANCE.md' 'Gray'
    return 2
}

# --- Main ---
if (-not $ApplySafe -and -not $ApplyUnsafe) {
    $DiagnoseOnly = $true
}

Write-CtgCpuLog "Optimize-CpuPerformance start Admin=$script:CtgIsAdmin ApplySafe=$($ApplySafe.IsPresent) ApplyUnsafe=$($ApplyUnsafe.IsPresent)" 'DarkGray'

$exitCode = 0
if ($ApplyUnsafe) {
    $exitCode = Invoke-CtgCpuApplyUnsafe
} elseif ($ApplySafe) {
    $exitCode = Invoke-CtgCpuApplySafe
} else {
    Invoke-CtgCpuDiagnose
}

Write-CtgCpuLog "Optimize-CpuPerformance finished exit=$exitCode" 'DarkGray'
exit $exitCode
