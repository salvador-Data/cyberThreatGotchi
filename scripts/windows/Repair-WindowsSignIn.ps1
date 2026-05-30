<#
.SYNOPSIS
  Diagnose and safely repair Windows 11 Sign-in options (Password / PIN / Hello).

.DESCRIPTION
  Read-only by default. Reports account type, Hello/PIN/password policy state, and
  Credential Manager health. Does NOT read, store, or change the user's password.

  Safe fixes (-ApplySafeFixes, Admin recommended): restart Web Account Manager and
  Credential Manager services, clear stale NGC PIN cache folders (requires re-PIN if PIN
  was broken), and open Settings deep links for manual password change.

  Typical symptom: Settings -> Accounts -> Sign-in options -> Password greyed out,
  "Change" does nothing, or PIN works but password path fails (common on Microsoft accounts).

.PARAMETER ApplySafeFixes
  Apply non-destructive service restarts and optional NGC cache reset. Never sets a password.

.PARAMETER ResetNgcPinCache
  With -ApplySafeFixes: remove %LOCALAPPDATA%\Packages\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy\AC\TokenBroker\Accounts
  and NGC folder for current user. User must set PIN again if PIN was in use. Admin required.

.PARAMETER OpenSettings
  Launch ms-settings:signinoptions after the report.

.PARAMETER LogDir
  Directory for repair-windows-signin.log (default: %USERPROFILE%\Backups\logs).

.EXAMPLE
  .\scripts\windows\Repair-WindowsSignIn.ps1

.EXAMPLE
  .\scripts\windows\Repair-WindowsSignIn.ps1 -ApplySafeFixes -OpenSettings
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch] $ApplySafeFixes,
    [switch] $ResetNgcPinCache,
    [switch] $OpenSettings,
    [string] $LogDir = ''
)

$ErrorActionPreference = 'Continue'

. (Join-Path $PSScriptRoot 'CTG-AdminCommon.ps1')

function Write-CtgSection([string]$Title) {
    Write-Host ''
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Write-CtgFinding([string]$Label, [string]$Value, [string]$Severity = 'Info') {
    $color = switch ($Severity) {
        'Warn' { 'Yellow' }
        'Fail' { 'Red' }
        'Ok' { 'Green' }
        default { 'Gray' }
    }
    Write-Host ("  {0,-28} {1}" -f ($Label + ':'), $Value) -ForegroundColor $color
}

function Get-CtgLogPath {
    param([string]$Dir)
    if (-not $Dir) {
        $Dir = Join-Path $env:USERPROFILE 'Backups\logs'
    }
    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    }
    return Join-Path $Dir 'repair-windows-signin.log'
}

function Add-CtgLogLine {
    param([string]$Path, [string]$Line)
    Add-Content -Path $Path -Value $Line -Encoding UTF8
}

function Get-CtgAccountSummary {
    $summary = [ordered]@{
        UserName = $env:USERNAME
        Domain = $env:USERDOMAIN
        ComputerName = $env:COMPUTERNAME
        IsAdmin = (Test-CtgIsAdmin)
        AccountType = 'Unknown'
        IsMicrosoftAccount = $false
        IsAzureADJoined = $false
        IsDomainJoined = $false
        LocalOnly = $false
    }

    try {
        $dsReg = dsregcmd /status 2>&1 | Out-String
        if ($dsReg -match 'AzureAdJoined\s*:\s*YES') { $summary.IsAzureADJoined = $true }
        if ($dsReg -match 'DomainJoined\s*:\s*YES') { $summary.IsDomainJoined = $true }
        if ($dsReg -match 'WorkplaceJoined\s*:\s*YES') { $summary.IsMicrosoftAccount = $true }
    } catch {
        # dsregcmd unavailable on some SKUs
    }

    try {
        $whoami = whoami /upn 2>&1
        if ($LASTEXITCODE -eq 0 -and $whoami -match '@') {
            $summary.IsMicrosoftAccount = $true
            $summary.AccountType = 'Microsoft account (UPN)'
        }
    } catch { }

    try {
        $localUser = Get-LocalUser -Name $env:USERNAME -ErrorAction SilentlyContinue
        if ($localUser) {
            if ($localUser.PrincipalSource -eq 'MicrosoftAccount') {
                $summary.IsMicrosoftAccount = $true
                $summary.AccountType = 'Microsoft account (local SAM bridge)'
            } elseif ($summary.AccountType -eq 'Unknown') {
                $summary.AccountType = 'Local account'
                $summary.LocalOnly = $true
            }
        }
    } catch { }

    if ($summary.IsAzureADJoined) {
        $summary.AccountType = 'Azure AD / Entra joined'
    } elseif ($summary.IsDomainJoined) {
        $summary.AccountType = 'Domain joined'
    } elseif ($summary.AccountType -eq 'Unknown' -and -not $summary.IsMicrosoftAccount) {
        $summary.AccountType = 'Local or unspecified'
        $summary.LocalOnly = $true
    }

    return $summary
}

function Get-CtgSignInPolicyState {
    $state = [ordered]@{
        DevicePasswordLess = $null
        AllowPIN = $null
        BlockMicrosoftAccount = $null
        MinimumPasswordLength = $null
        CredentialGuard = $null
    }

    $paths = @(
        @{ Key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'DevicePasswordLessBuildVersion'; Label = 'DevicePasswordLess' },
        @{ Key = 'HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork'; Name = 'UsePassportForWork'; Label = 'UsePassportForWork' },
        @{ Key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'AllowPIN'; Label = 'AllowPIN' },
        @{ Key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'BlockMicrosoftAccount'; Label = 'BlockMicrosoftAccount' },
        @{ Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name = 'LsaCfgFlags'; Label = 'CredentialGuard' }
    )

    foreach ($p in $paths) {
        try {
            $item = Get-ItemProperty -Path $p.Key -Name $p.Name -ErrorAction SilentlyContinue
            if ($null -ne $item) {
                $state[$p.Label] = $item.($p.Name)
            }
        } catch { }
    }

    try {
        $seceditOut = Join-Path $env:TEMP "ctg-secedit-$([guid]::NewGuid().ToString('N')).inf"
        secedit /export /cfg $seceditOut /areas SECURITYPOLICY 2>$null | Out-Null
        if (Test-Path $seceditOut) {
            $text = Get-Content $seceditOut -Raw
            if ($text -match 'MinimumPasswordLength\s*=\s*(\d+)') {
                $state.MinimumPasswordLength = [int]$Matches[1]
            }
            Remove-Item $seceditOut -Force -ErrorAction SilentlyContinue
        }
    } catch { }

    return $state
}

function Get-CtgHelloPinState {
    $hello = [ordered]@{
        NgcFolderExists = $false
        NgcFolderPath = Join-Path $env:WINDIR "ServiceProfiles\LocalService\AppData\Local\Microsoft\Ngc"
        PinConfigured = $false
        WebAccountManager = $null
        CredentialManager = $null
        TokenBrokerAccounts = $false
    }

    $userNgc = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Ngc'
    if (Test-Path $userNgc) {
        $hello.NgcFolderExists = $true
        $hello.PinConfigured = (Get-ChildItem -Path $userNgc -Force -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0
    }

    $tokenBroker = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy\AC\TokenBroker\Accounts'
    $hello.TokenBrokerAccounts = Test-Path $tokenBroker

    foreach ($svcName in @('TokenBroker', 'VaultSvc', 'WbioSrvc')) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            if ($svcName -eq 'TokenBroker') { $hello.WebAccountManager = $svc.Status.ToString() }
            if ($svcName -eq 'VaultSvc') { $hello.CredentialManager = $svc.Status.ToString() }
        }
    }

    return $hello
}

function Get-CtgCredentialManagerHealth {
    $health = [ordered]@{
        VaultSvcStatus = 'Unknown'
        CredEnumerateOk = $false
        CredCount = 0
        CredError = ''
    }

    $svc = Get-Service -Name 'VaultSvc' -ErrorAction SilentlyContinue
    if ($svc) { $health.VaultSvcStatus = $svc.Status.ToString() }

    try {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class CtgCred {
  [DllImport("advapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  public static extern bool CredEnumerate(string filter, int flag, out int count, out IntPtr pCredentials);
}
"@ -ErrorAction SilentlyContinue
        $count = 0
        $ptr = [IntPtr]::Zero
        $ok = [CtgCred]::CredEnumerate($null, 0, [ref]$count, [ref]$ptr)
        $health.CredEnumerateOk = $ok
        $health.CredCount = $count
        if (-not $ok) {
            $health.CredError = "CredEnumerate failed (Win32=$([Runtime.InteropServices.Marshal]::GetLastWin32Error()))"
        }
    } catch {
        $health.CredError = $_.Exception.Message
    }

    return $health
}

function Get-CtgHardeningFootprint {
    $footprint = [ordered]@{
        HwsModuleInstalled = $false
        SysmonInstalled = $false
        RecentRestorePoint = $false
        LikelyHwsPasswordImpact = 'Low (CTG default is audit-only / flag-gated)'
    }

    if (Get-Module -ListAvailable -Name 'Harden-Windows-Security') {
        $footprint.HwsModuleInstalled = $true
        $footprint.LikelyHwsPasswordImpact = 'Review if full Invoke-Hardening (enforce) was run - can set DevicePasswordLess / PIN policies'
    }

    if (Get-Service -Name 'Sysmon' -ErrorAction SilentlyContinue) {
        $footprint.SysmonInstalled = $true
    }
    if (Get-Service -Name 'Sysmon64' -ErrorAction SilentlyContinue) {
        $footprint.SysmonInstalled = $true
    }

    try {
        $rp = Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Sort-Object CreationTime -Descending | Select-Object -First 1
        if ($rp -and $rp.Description -match 'CTG') {
            $footprint.RecentRestorePoint = $true
        }
    } catch { }

    return $footprint
}

function Show-CtgManualSteps {
    param($Account)

    Write-CtgSection 'Manual steps (Settings password / PIN)'
    Write-Host @'
  Password option greyed out or Change does nothing - try in order:

  1) Open Sign-in options directly:
       start ms-settings:signinoptions

  2) Microsoft account (most Andy laptops):
       - Password is managed at https://account.microsoft.com/security
       - Settings may only offer PIN / Hello; use "I forgot my PIN" or web password change
       - Stay signed in to the same Microsoft account in Settings -> Accounts

  3) Local account - change password without Settings UI:
       - Ctrl+Alt+Del -> Change a password
       - Or Admin PowerShell (YOU type the new password - script never does):
           net user YOURUSERNAME *

  4) Classic Users dialog (auto-logon / password hints):
       - Win+R -> netplwiz
       - Select user -> Reset Password (Admin) or require sign-in checkbox

  5) If PIN works but Password path fails:
       - Sign-in options -> PIN -> I forgot my PIN (needs internet for MSA)
       - Or run this script with -ApplySafeFixes -ResetNgcPinCache (Admin), then recreate PIN

  6) Azure AD / work PC:
       - Password changes may be blocked by org policy - use company portal or IT admin

  7) After CTG hardening:
       - ctg_soc_run_once.ps1 uses Harden-Windows-Security AUDIT ONLY by default
       - Full HWS enforce can enable "Require Windows Hello for sign-in" - revert in Group Policy Editor:
           Computer Config -> Admin Templates -> Windows Components -> Windows Hello for Business
       - Or Settings -> Accounts -> Sign-in options -> turn OFF "For improved security, only allow Windows Hello..."

  This script NEVER stores or changes your password.
'@ -ForegroundColor Gray
}

function Invoke-CtgSafeFixes {
    if (-not (Test-CtgIsAdmin)) {
        Write-CtgFinding 'ApplySafeFixes' 'Skipped - run PowerShell as Administrator' 'Warn'
        return
    }

    Write-CtgSection 'Safe fixes (no password change)'

    foreach ($svcName in @('VaultSvc', 'TokenBroker', 'WbioSrvc', 'NgcSvc')) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if (-not $svc) { continue }
        if ($PSCmdlet.ShouldProcess($svcName, 'Restart service')) {
            try {
                Restart-Service -Name $svcName -Force -ErrorAction Stop
                Write-CtgFinding $svcName 'Restarted' 'Ok'
            } catch {
                Write-CtgFinding $svcName $_.Exception.Message 'Warn'
            }
        }
    }

    if ($ResetNgcPinCache) {
        $paths = @(
            (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Ngc'),
            (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy\AC\TokenBroker\Accounts')
        )
        foreach ($path in $paths) {
            if (-not (Test-Path $path)) { continue }
            if ($PSCmdlet.ShouldProcess($path, 'Remove NGC / TokenBroker cache (PIN re-setup required)')) {
                try {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                    Write-CtgFinding 'Removed cache' $path 'Ok'
                } catch {
                    Write-CtgFinding 'Remove cache failed' "$path - $($_.Exception.Message)" 'Warn'
                }
            }
        }
        Write-Host '  Recreate PIN in Settings -> Sign-in options after cache reset.' -ForegroundColor Yellow
    }
}

# --- Main ---
$logPath = Get-CtgLogPath -Dir $LogDir
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$lines = @("[$stamp] Repair-WindowsSignIn start | User=$env:USERNAME | Admin=$(Test-CtgIsAdmin)")

Write-Host ''
Write-Host 'CyberThreatGotchi - Windows Sign-in diagnostic' -ForegroundColor Cyan
Write-Host 'Read-only unless -ApplySafeFixes. Never reads or sets your password.' -ForegroundColor Gray
Write-Host ''

$account = Get-CtgAccountSummary
Write-CtgSection 'Account'
Write-CtgFinding 'User' $account.UserName
Write-CtgFinding 'Domain' $account.Domain
Write-CtgFinding 'Account type' $account.AccountType
Write-CtgFinding 'Microsoft account' $(if ($account.IsMicrosoftAccount) { 'Yes' } else { 'No' })
Write-CtgFinding 'Azure AD joined' $(if ($account.IsAzureADJoined) { 'Yes' } else { 'No' })
Write-CtgFinding 'Elevated (Admin)' $(if ($account.IsAdmin) { 'Yes' } else { 'No' })
$lines += "AccountType=$($account.AccountType) MSA=$($account.IsMicrosoftAccount) AAD=$($account.IsAzureADJoined)"

$policy = Get-CtgSignInPolicyState
Write-CtgSection 'Sign-in policy (registry / secedit)'
foreach ($key in $policy.Keys) {
    $val = $policy[$key]
    $display = if ($null -eq $val) { '(not set - OK)' } else { $val }
    $sev = 'Info'
    if ($key -eq 'DevicePasswordLess' -and $val -ge 1) {
        $sev = 'Warn'
        $display = "$val - may hide password sign-in; prefer Hello/PIN only"
    }
    if ($key -eq 'BlockMicrosoftAccount' -and $val -ge 1) {
        $sev = 'Warn'
    }
    Write-CtgFinding $key $display $sev
    $lines += "Policy.$key=$display"
}

$hello = Get-CtgHelloPinState
Write-CtgSection 'Windows Hello / PIN / Credential services'
Write-CtgFinding 'PIN data present' $(if ($hello.PinConfigured) { 'Yes' } else { 'No / not detected' })
Write-CtgFinding 'Web Account Mgr (TokenBroker)' $(if ($hello.WebAccountManager) { $hello.WebAccountManager } else { 'n/a' }) $(if ($hello.WebAccountManager -eq 'Running') { 'Ok' } else { 'Warn' })
Write-CtgFinding 'Credential Manager (VaultSvc)' $(if ($hello.CredentialManager) { $hello.CredentialManager } else { 'n/a' }) $(if ($hello.CredentialManager -eq 'Running') { 'Ok' } else { 'Warn' })
Write-CtgFinding 'TokenBroker accounts folder' $(if ($hello.TokenBrokerAccounts) { 'Present' } else { 'Missing (MSA sync issue?)' })

$cred = Get-CtgCredentialManagerHealth
Write-CtgSection 'Credential Manager health'
Write-CtgFinding 'VaultSvc' $cred.VaultSvcStatus $(if ($cred.VaultSvcStatus -eq 'Running') { 'Ok' } else { 'Warn' })
Write-CtgFinding 'CredEnumerate' $(if ($cred.CredEnumerateOk) { "OK ($($cred.CredCount) entries visible)" } else { $cred.CredError }) $(if ($cred.CredEnumerateOk) { 'Ok' } else { 'Warn' })

$harden = Get-CtgHardeningFootprint
Write-CtgSection 'CTG hardening footprint'
Write-CtgFinding 'Harden-Windows-Security module' $(if ($harden.HwsModuleInstalled) { 'Installed' } else { 'Not installed' })
Write-CtgFinding 'Sysmon' $(if ($harden.SysmonInstalled) { 'Installed' } else { 'Not detected' })
Write-CtgFinding 'Password impact hypothesis' $harden.LikelyHwsPasswordImpact $(if ($harden.LikelyHwsPasswordImpact -match 'Low') { 'Ok' } else { 'Warn' })

Write-CtgSection 'Root cause hypotheses'
$hypotheses = @()
if ($account.IsMicrosoftAccount -and -not $account.IsAzureADJoined) {
    $hypotheses += 'Microsoft account: Settings "Password" often routes to account.microsoft.com - local Change button may appear broken offline or when Hello-only policy is active.'
}
if ($policy.DevicePasswordLess -ge 1) {
    $hypotheses += 'DevicePasswordLessBuildVersion policy is set - Windows prefers Hello/PIN and may disable password sign-in UI.'
}
if ($hello.WebAccountManager -ne 'Running' -or $hello.CredentialManager -ne 'Running') {
    $hypotheses += 'TokenBroker or VaultSvc not running - restart with -ApplySafeFixes (Admin).'
}
if (-not $cred.CredEnumerateOk) {
    $hypotheses += 'Credential Manager enumeration failed - VaultSvc repair or profile corruption; safe service restart first.'
}
if ($hello.PinConfigured -and -not $hello.TokenBrokerAccounts) {
    $hypotheses += 'PIN files exist but TokenBroker cache missing - MSA token sync issue; try -ApplySafeFixes -ResetNgcPinCache then recreate PIN.'
}
if ($hypotheses.Count -eq 0) {
    $hypotheses += 'No obvious policy block - use manual steps: ms-settings:signinoptions, account.microsoft.com (MSA), or netplwiz / Ctrl+Alt+Del for local password.'
}
$i = 1
foreach ($h in $hypotheses) {
    Write-Host "  $i. $h" -ForegroundColor Yellow
    $lines += "Hypothesis=$h"
    $i++
}

Show-CtgManualSteps -Account $account

if ($ApplySafeFixes) {
    Invoke-CtgSafeFixes
} else {
    Write-CtgSection 'Safe fixes available'
    Write-Host '  Run as Administrator with -ApplySafeFixes to restart VaultSvc/TokenBroker/WbioSrvc.' -ForegroundColor Gray
    Write-Host '  Add -ResetNgcPinCache only if PIN path is broken (requires PIN re-setup).' -ForegroundColor Gray
}

if ($OpenSettings) {
    Write-CtgFinding 'Opening' 'ms-settings:signinoptions'
    Start-Process 'ms-settings:signinoptions'
}

$lines += "[$stamp] Repair-WindowsSignIn complete ApplySafeFixes=$ApplySafeFixes ResetNgc=$ResetNgcPinCache"
foreach ($line in $lines) {
    Add-CtgLogLine -Path $logPath -Line $line
}
Write-CtgFinding 'Log' $logPath 'Ok'
Write-Host ''
