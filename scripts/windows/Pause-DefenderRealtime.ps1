<#
.SYNOPSIS
  Pause or resume Microsoft Defender real-time protection for short build windows.
.DESCRIPTION
  Requires Administrator. Use only during PlatformIO/Cardputer builds, then resume.
  Prefer -AddBuildExclusions for persistent build-folder exclusions without disabling AV.
.PARAMETER Pause
  Disable real-time monitoring.
.PARAMETER Resume
  Re-enable real-time monitoring.
.PARAMETER Status
  Show current Defender real-time status only (no changes).
.PARAMETER AddBuildExclusions
  Add Defender path exclusions for common CTG build trees (does not pause realtime).
.EXAMPLE
  .\Pause-DefenderRealtime.ps1 -Status
.EXAMPLE
  .\Pause-DefenderRealtime.ps1 -Pause
.EXAMPLE
  .\Pause-DefenderRealtime.ps1 -Resume
.EXAMPLE
  .\Pause-DefenderRealtime.ps1 -AddBuildExclusions
.NOTES
  Hacker Planet LLC / CyberThreatGotchi — authorized use on systems you administer only.
  OneDrive sync cannot be paused reliably from script; pause sync from the tray icon or exclude build folders.
#>
[CmdletBinding(DefaultParameterSetName = 'Toggle')]
param(
    [Parameter(ParameterSetName = 'Pause')]
    [switch]$Pause,

    [Parameter(ParameterSetName = 'Resume')]
    [switch]$Resume,

    [Parameter(ParameterSetName = 'Status')]
    [switch]$Status,

    [switch]$AddBuildExclusions
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')

$buildExclusionPaths = @(
    'C:\pio\',
    'C:\Users\Owner\Projects\M5_OS-Cardputer\.pio',
    'C:\Users\Owner\Projects'
)

function Write-DefenderBanner {
    Write-Host ''
    Write-Host '=== Microsoft Defender real-time protection ===' -ForegroundColor Cyan
    Write-Host 'Requires Administrator. Pause only briefly during builds; resume when done.'
    Write-Host 'OneDrive: pause sync from the tray icon, or use -AddBuildExclusions / folder exclusions.'
    Write-Host ''
}

function Get-DefenderRealtimeStatus {
    $mp = Get-MpComputerStatus
    $pref = Get-MpPreference
    [PSCustomObject]@{
        RealTimeProtectionEnabled = $mp.RealTimeProtectionEnabled
        AMServiceEnabled          = $mp.AMServiceEnabled
        AntispywareEnabled        = $mp.AntispywareEnabled
        DisableRealtimeMonitoring = $pref.DisableRealtimeMonitoring
    }
}

function Show-DefenderStatus([string]$Label) {
    $s = Get-DefenderRealtimeStatus
    Write-Host "[$Label]"
    Write-Host ('  RealTimeProtectionEnabled : ' + $s.RealTimeProtectionEnabled)
    Write-Host ('  DisableRealtimeMonitoring : ' + $s.DisableRealtimeMonitoring)
    Write-Host ('  AMServiceEnabled          : ' + $s.AMServiceEnabled)
    Write-Host ('  AntispywareEnabled        : ' + $s.AntispywareEnabled)
}

function Assert-Admin {
    if (-not (Test-CtgIsAdmin)) {
        Write-Host 'Pause-DefenderRealtime.ps1 requires Administrator.' -ForegroundColor Red
        Write-Host 'Right-click PowerShell -> Run as administrator, or double-click Pause-DefenderRealtime.bat'
        exit 1
    }
}

function Add-BuildExclusions {
    Assert-Admin
    Write-DefenderBanner
    $existing = @(Get-MpPreference).ExclusionPath
    foreach ($path in $buildExclusionPaths) {
        if ($existing -contains $path) {
            Write-Host "Exclusion already present: $path"
            continue
        }
        Write-Host "Adding exclusion: $path"
        Add-MpPreference -ExclusionPath $path
    }
    Write-Host ''
    Write-Host 'Build path exclusions applied. Real-time protection remains enabled unless you also -Pause.'
}

Write-DefenderBanner

if ($AddBuildExclusions) {
    Add-BuildExclusions
    if ($PSCmdlet.ParameterSetName -eq 'Status' -or (-not $Pause -and -not $Resume)) {
        Show-DefenderStatus 'After exclusions'
    }
    if (-not $Pause -and -not $Resume -and $PSCmdlet.ParameterSetName -ne 'Status') {
        exit 0
    }
}

if ($Status) {
    Show-DefenderStatus 'Current'
    exit 0
}

Assert-Admin

Show-DefenderStatus 'Before'

$action = $PSCmdlet.ParameterSetName
if ($action -eq 'Toggle') {
    $current = Get-DefenderRealtimeStatus
    if ($current.DisableRealtimeMonitoring -or -not $current.RealTimeProtectionEnabled) {
        $action = 'Resume'
        Write-Host ''
        Write-Host 'Toggle: realtime is off — resuming protection.'
    } else {
        $action = 'Pause'
        Write-Host ''
        Write-Host 'Toggle: realtime is on — pausing for build window.'
        Write-Host 'WARNING: Resume after your build finishes (.\Pause-DefenderRealtime.ps1 -Resume).'
    }
}

switch ($action) {
    'Pause' {
        Set-MpPreference -DisableRealtimeMonitoring $true
        Write-Host ''
        Write-Host 'Real-time monitoring PAUSED.' -ForegroundColor Yellow
    }
    'Resume' {
        Set-MpPreference -DisableRealtimeMonitoring $false
        Write-Host ''
        Write-Host 'Real-time monitoring RESUMED.' -ForegroundColor Green
    }
}

Show-DefenderStatus 'After'
exit 0
