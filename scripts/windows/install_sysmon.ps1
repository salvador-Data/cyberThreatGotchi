#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Install Sysmon with SwiftOnSecurity baseline config (authorized lab / owned hosts only).

.DESCRIPTION
  Downloads Sysmon from Microsoft Sysinternals, fetches the community export config from
  SwiftOnSecurity/sysmon-config, and installs with -accepteula.
  Does not run unless you execute this script explicitly.

.PARAMETER InstallDir
  Directory for Sysmon binaries and config (default: %ProgramData%\CTG\Sysmon).

.PARAMETER Force
  Re-download and reinstall even if Sysmon service already exists.

.EXAMPLE
  .\scripts\windows\install_sysmon.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $InstallDir = (Join-Path $env:ProgramData 'CTG\Sysmon'),
    [switch] $Force
)

$ErrorActionPreference = 'Stop'

$SysmonZipUrl = 'https://download.sysinternals.com/files/Sysmon.zip'
$ConfigUrl = 'https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml'

function Test-SysmonInstalled {
    $svc = Get-Service -Name 'Sysmon' -ErrorAction SilentlyContinue
    return ($null -ne $svc)
}

Write-Host ''
Write-Host 'CyberThreatGotchi - Sysmon install (defensive / authorized use only)' -ForegroundColor Cyan
Write-Host 'Host: ' -NoNewline; Write-Host $env:COMPUTERNAME -ForegroundColor Gray
Write-Host ''

if ((Test-SysmonInstalled) -and -not $Force) {
    Write-Host 'Sysmon service already present. Use -Force to reinstall.' -ForegroundColor Yellow
    & (Join-Path $InstallDir 'Sysmon64.exe') -c 2>$null | Out-String | Write-Host
    return
}

if (-not $PSCmdlet.ShouldProcess($InstallDir, 'Download and install Sysmon')) {
    return
}

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
$zipPath = Join-Path $InstallDir 'Sysmon.zip'
$configPath = Join-Path $InstallDir 'sysmonconfig-export.xml'

Write-Host 'Downloading Sysmon...' -ForegroundColor Gray
Invoke-WebRequest -Uri $SysmonZipUrl -OutFile $zipPath -UseBasicParsing

Write-Host 'Extracting...' -ForegroundColor Gray
Expand-Archive -Path $zipPath -DestinationPath $InstallDir -Force

Write-Host 'Downloading SwiftOnSecurity config...' -ForegroundColor Gray
Invoke-WebRequest -Uri $ConfigUrl -OutFile $configPath -UseBasicParsing

$sysmonExe = Join-Path $InstallDir 'Sysmon64.exe'
if (-not (Test-Path $sysmonExe)) {
    throw "Sysmon64.exe not found after extract: $sysmonExe"
}

function Invoke-SysmonNative {
    param([Parameter(Mandatory = $true)][string[]] $NativeArgs)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & $sysmonExe @NativeArgs 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    foreach ($line in $output) {
        if ($line -is [System.Management.Automation.ErrorRecord]) {
            Write-Host $line.ToString()
        } else {
            Write-Host $line
        }
    }
    return $exitCode
}

if (Test-SysmonInstalled) {
    Write-Host 'Updating Sysmon configuration...' -ForegroundColor Gray
    $exitCode = Invoke-SysmonNative -NativeArgs @('-c', $configPath)
} else {
    Write-Host 'Installing Sysmon (accept EULA)...' -ForegroundColor Gray
    $exitCode = Invoke-SysmonNative -NativeArgs @('-accepteula', '-i', $configPath)
}

if ($exitCode -eq 740) {
    throw 'Sysmon requires Administrator. Re-run ctg_soc_run_once.ps1 from an elevated PowerShell session.'
}
if ($exitCode -ne 0 -and -not (Test-SysmonInstalled)) {
    throw "Sysmon install failed (exit code $exitCode). Check config at $configPath"
}

if (-not (Test-SysmonInstalled)) {
    throw 'Sysmon service not found after install.'
}

Write-Host ''
Write-Host 'Sysmon installed. Verify:' -ForegroundColor Green
Write-Host "  Get-Service Sysmon"
Write-Host "  & '$sysmonExe' -c"
Write-Host ''
