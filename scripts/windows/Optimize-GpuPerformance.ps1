<#
.SYNOPSIS
  Conservative GPU performance diagnose and safe Windows-level optimization (no OC offsets).

.DESCRIPTION
  Diagnose-only by default: GPU adapters, NVIDIA/AMD/Intel detection, driver versions,
  NVIDIA persistence mode and power management when nvidia-smi is present.

  -ApplySafe: NVIDIA persistence mode (-pm 1) when available; optional visual-effects
  performance preset (HKCU); documents Windows Graphics Settings per-app steps.

  Does NOT apply voltage/clock offsets, aggressive power-limit changes, or disable
  security mitigations. Integrated-only systems skip discrete-GPU actions.

.PARAMETER DiagnoseOnly
  Report current GPU posture (default when -ApplySafe omitted).

.PARAMETER ApplySafe
  Apply conservative tweaks (Administrator recommended for NVIDIA -pm).

.PARAMETER SkipVisualEffects
  When applying safe tweaks, do not change visual-effects registry keys.

.EXAMPLE
  .\scripts\windows\Optimize-GpuPerformance.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Run-AsAdmin.ps1 -TargetScript .\scripts\windows\Optimize-GpuPerformance.ps1 -TargetArguments '-ApplySafe'
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch] $DiagnoseOnly,
    [switch] $ApplySafe,
    [switch] $SkipVisualEffects
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')
$script:CtgIsAdmin = Test-CtgIsAdmin

$LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
$LogFile = Join-Path $LogDir 'optimize-gpu.log'

function Write-CtgGpuLog {
    param([string] $Message, [string] $Color = 'Gray')
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    try {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        Add-Content -Path $LogFile -Value $line -Encoding utf8 -ErrorAction SilentlyContinue
    } catch { }
    Write-Host $line -ForegroundColor $Color
}

function Get-CtgGpuAdapters {
    $rows = @()
    try {
        Get-CimInstance Win32_VideoController -ErrorAction Stop | ForEach-Object {
            $name = ($_.Name -as [string]).Trim()
            if (-not $name) { return }
            $vendor = 'Unknown'
            if ($name -match 'NVIDIA|Quadro|GeForce|RTX|GTX') { $vendor = 'NVIDIA' }
            elseif ($name -match 'AMD|Radeon') { $vendor = 'AMD' }
            elseif ($name -match 'Intel') { $vendor = 'Intel' }

            $rows += [PSCustomObject]@{
                Name           = $name
                Vendor         = $vendor
                DriverVersion  = $_.DriverVersion
                AdapterRAM     = $_.AdapterRAM
                VideoProcessor = $_.VideoProcessor
                PNPDeviceID    = $_.PNPDeviceID
            }
        }
    } catch {
        Write-CtgGpuLog "Win32_VideoController query failed: $($_.Exception.Message)" 'Yellow'
    }
    return $rows
}

function Get-CtgNvidiaSmiPath {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'NVIDIA Corporation\NVSMI\nvidia-smi.exe')
        (Join-Path ${env:ProgramFiles(x86)} 'NVIDIA Corporation\NVSMI\nvidia-smi.exe')
        'C:\Windows\System32\nvidia-smi.exe'
    )
    foreach ($p in $candidates) {
        if ($p -and (Test-Path -LiteralPath $p)) { return $p }
    }
    if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
        return (Get-Command nvidia-smi).Source
    }
    return $null
}

function Invoke-CtgNvidiaSmi {
    param([string[]] $Arguments)
    $exe = Get-CtgNvidiaSmiPath
    if (-not $exe) { return $null }
    try {
        $out = & $exe @Arguments 2>&1 | Out-String
        return $out.Trim()
    } catch {
        return "nvidia-smi failed: $($_.Exception.Message)"
    }
}

function Get-CtgVisualEffectsState {
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
    $setting = $null
    try {
        if (Test-Path $key) {
            $setting = (Get-ItemProperty -Path $key -Name VisualFXSetting -ErrorAction SilentlyContinue).VisualFXSetting
        }
    } catch { }
    $labels = @{
        0 = 'Let Windows decide'
        1 = 'Best appearance'
        2 = 'Best performance'
        3 = 'Custom'
    }
    $label = if ($null -ne $setting -and $labels.ContainsKey([int]$setting)) { $labels[[int]$setting] } else { 'unknown' }
    return [PSCustomObject]@{ VisualFXSetting = $setting; Label = $label }
}

function Get-CtgGpuPreferenceCount {
    $key = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    try {
        if (-not (Test-Path $key)) { return 0 }
        return (Get-ItemProperty -Path $key -ErrorAction SilentlyContinue).PSObject.Properties |
            Where-Object { $_.Name -notmatch '^PS' } |
            Measure-Object | Select-Object -ExpandProperty Count
    } catch {
        return 0
    }
}

function Invoke-CtgGpuDiagnose {
    Write-CtgGpuLog '=== GPU performance diagnose ===' 'Cyan'

    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        Write-CtgGpuLog ("System: {0} {1}" -f $cs.Manufacturer, $cs.Model) 'White'
    } catch { }

    $adapters = Get-CtgGpuAdapters
    if ($adapters.Count -eq 0) {
        Write-CtgGpuLog 'No video adapters detected via WMI' 'Yellow'
    } else {
        foreach ($a in $adapters) {
            Write-CtgGpuLog ("GPU: {0} (vendor={1})" -f $a.Name, $a.Vendor) 'White'
            Write-CtgGpuLog ("  Driver={0} RAM={1} bytes" -f $a.DriverVersion, $a.AdapterRAM) 'Gray'
        }
    }

    $hasNvidia = @($adapters | Where-Object { $_.Vendor -eq 'NVIDIA' }).Count -gt 0
    $hasDiscrete = @($adapters | Where-Object { $_.Vendor -in @('NVIDIA', 'AMD') }).Count -gt 0
    $hasIntelOnly = (-not $hasDiscrete) -and (@($adapters | Where-Object { $_.Vendor -eq 'Intel' }).Count -gt 0)

    if ($hasIntelOnly) {
        Write-CtgGpuLog 'Integrated Intel only - discrete GPU tweaks skipped; use Windows Graphics Settings for per-app GPU' 'Yellow'
    }

    $smi = Get-CtgNvidiaSmiPath
    if ($hasNvidia -and $smi) {
        Write-CtgGpuLog "NVIDIA tools: nvidia-smi at $smi" 'Gray'
        $summary = Invoke-CtgNvidiaSmi -Arguments @('--query-gpu=name,driver_version,persistence_mode,power.management,power.limit,clocks.current.graphics,clocks.max.graphics', '--format=csv,noheader')
        if ($summary) {
            Write-CtgGpuLog "  nvidia-smi: $summary" 'Gray'
        }
        $pm = Invoke-CtgNvidiaSmi -Arguments @('--query-gpu=persistence_mode', '--format=csv,noheader')
        Write-CtgGpuLog "  Persistence mode: $pm" 'Gray'
    } elseif ($hasNvidia) {
        Write-CtgGpuLog 'NVIDIA adapter present but nvidia-smi not found - install/update NVIDIA driver package' 'Yellow'
    }

    if (@($adapters | Where-Object { $_.Vendor -eq 'AMD' }).Count -gt 0) {
        Write-CtgGpuLog 'AMD discrete GPU: use AMD Software Adrenalin performance mode manually; no scripted OC' 'Yellow'
    }

    $vfx = Get-CtgVisualEffectsState
    Write-CtgGpuLog ("Visual effects: {0} (VisualFXSetting={1})" -f $vfx.Label, $vfx.VisualFXSetting) 'Gray'

    $prefCount = Get-CtgGpuPreferenceCount
    Write-CtgGpuLog "Windows Graphics Settings (UserGpuPreferences entries): $prefCount" 'Gray'
    Write-CtgGpuLog 'Manual: Settings -> System -> Display -> Graphics -> add VirtualBox, Cursor, browsers -> High performance GPU' 'Yellow'

    if ($cs.Manufacturer -match 'Dell') {
        Write-CtgGpuLog 'Dell Precision: install Dell Power Manager manually for thermal/performance profiles (not scripted - user consent)' 'Yellow'
    }

    Write-CtgGpuLog 'Script OC / offset changes: NOT supported - see docs/CPU_PERFORMANCE.md GPU section' 'Yellow'
    Write-CtgGpuLog "Log: $LogFile" 'DarkGray'
}

function Set-CtgVisualEffectsPerformance {
    $explorerKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
    $advancedKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

    if (-not (Test-Path $explorerKey)) {
        New-Item -Path $explorerKey -Force | Out-Null
    }
    Set-ItemProperty -Path $explorerKey -Name VisualFXSetting -Value 2 -Type DWord -Force

    if (-not (Test-Path $advancedKey)) {
        New-Item -Path $advancedKey -Force | Out-Null
    }
    foreach ($prop in @(
            @{ Name = 'ListviewAlphaSelect'; Value = 0 }
            @{ Name = 'ListviewShadow'; Value = 0 }
            @{ Name = 'TaskbarAnimations'; Value = 0 }
            @{ Name = 'IconsOnly'; Value = 1 }
        )) {
        Set-ItemProperty -Path $advancedKey -Name $prop.Name -Value $prop.Value -Type DWord -Force -ErrorAction SilentlyContinue
    }

    # Refresh shell so Explorer picks up VisualFXSetting (best-effort)
    try {
        $sig = @'
[DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
        Add-Type -MemberDefinition $sig -Name CtgSendMessage -Namespace CtgGpu -ErrorAction SilentlyContinue | Out-Null
        [UIntPtr]$result = [UIntPtr]::Zero
        [CtgGpu.CtgSendMessage]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result) | Out-Null
    } catch { }

    Write-CtgGpuLog 'Set visual effects to Best performance (HKCU VisualFXSetting=2)' 'Green'
}

function Invoke-CtgGpuApplySafe {
    Write-CtgGpuLog '=== Applying safe GPU performance tweaks ===' 'Cyan'

    $adapters = Get-CtgGpuAdapters
    $hasNvidia = @($adapters | Where-Object { $_.Vendor -eq 'NVIDIA' }).Count -gt 0
    $applied = @()
    $skipped = @()

    if ($hasNvidia) {
        $smi = Get-CtgNvidiaSmiPath
        if ($smi) {
            if ($PSCmdlet.ShouldProcess('NVIDIA GPU', 'Enable persistence mode (-pm 1)')) {
                if ($script:CtgIsAdmin) {
                    $pmOut = Invoke-CtgNvidiaSmi -Arguments @('-pm', '1')
                    Write-CtgGpuLog "nvidia-smi -pm 1: $pmOut" 'Green'
                    $applied += 'NVIDIA persistence mode (-pm 1)'
                } else {
                    Write-CtgGpuLog 'NVIDIA -pm 1 skipped (Administrator recommended) - re-run via Run-AsAdmin.ps1' 'Yellow'
                    $skipped += 'NVIDIA persistence mode (needs Admin)'
                }
            }
        } else {
            $skipped += 'NVIDIA persistence mode (nvidia-smi missing)'
        }
    } else {
        $skipped += 'Discrete NVIDIA actions (no NVIDIA adapter)'
    }

    if (-not $SkipVisualEffects) {
        if ($PSCmdlet.ShouldProcess('Visual effects', 'Set Best performance preset')) {
            Set-CtgVisualEffectsPerformance
            $applied += 'Visual effects Best performance (HKCU)'
        }
    } else {
        $skipped += 'Visual effects (SkipVisualEffects)'
    }

    if ($applied.Count -gt 0) {
        Write-CtgGpuLog ('Applied: ' + ($applied -join '; ')) 'Green'
    }
    if ($skipped.Count -gt 0) {
        Write-CtgGpuLog ('Skipped/manual: ' + ($skipped -join '; ')) 'Yellow'
    }

    Write-CtgGpuLog 'Per-app High performance GPU: manual via Settings -> Display -> Graphics (documented in CPU_PERFORMANCE.md)' 'Yellow'
    Invoke-CtgGpuDiagnose
    return 0
}

# --- Main ---
if (-not $ApplySafe) {
    $DiagnoseOnly = $true
}

Write-CtgGpuLog "Optimize-GpuPerformance start Admin=$script:CtgIsAdmin ApplySafe=$($ApplySafe.IsPresent)" 'DarkGray'

$exitCode = 0
if ($ApplySafe) {
    $exitCode = Invoke-CtgGpuApplySafe
} else {
    Invoke-CtgGpuDiagnose
}

Write-CtgGpuLog "Optimize-GpuPerformance finished exit=$exitCode" 'DarkGray'
exit $exitCode
