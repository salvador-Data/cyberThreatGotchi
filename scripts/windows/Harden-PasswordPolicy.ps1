<#
.SYNOPSIS
  Local password policy hardening — max age, lockout, minimum length (authorized owned hosts).

.DESCRIPTION
  Diagnose-only by default. Use -ApplyPolicy from an elevated session to set:
  - Maximum password age: 120 days (4 months)
  - Lockout threshold: 10 failed attempts
  - Lockout duration / reset counter: 30 minutes (configurable)
  - Minimum password length: 12+ if current policy is weaker

  Preserves DuckDuckGo Password Manager workflow — does NOT rotate or read passwords.
  Documents Microsoft account vs local account recovery paths.

.PARAMETER DiagnoseOnly
  Report current net accounts / secedit state (default when -ApplyPolicy omitted).

.PARAMETER ApplyPolicy
  Apply local security policy (Administrator required).

.PARAMETER LockoutMinutes
  Lockout duration and observation window in minutes (default 30).

.EXAMPLE
  .\scripts\windows\Harden-PasswordPolicy.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Harden-PasswordPolicy.ps1 -ApplyPolicy
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch] $DiagnoseOnly,
    [switch] $ApplyPolicy,
    [int] $LockoutMinutes = 30,
    [int] $MaxPasswordAgeDays = 120,
    [int] $LockoutThreshold = 10,
    [int] $MinPasswordLength = 12
)

$ErrorActionPreference = 'Continue'
$ScriptDir = $PSScriptRoot

. (Join-Path $ScriptDir 'CTG-AdminCommon.ps1')
$script:CtgIsAdmin = Test-CtgIsAdmin

$BackupsRoot = Join-Path $env:USERPROFILE 'Backups'
$LogDir = Join-Path $BackupsRoot 'logs'
$LogFile = Join-Path $LogDir 'harden-password-policy.log'

function Write-CtgPwdLog {
    param([string] $Message, [string] $Color = 'Gray')
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    try {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        Add-Content -Path $LogFile -Value $line -Encoding utf8 -ErrorAction SilentlyContinue
    } catch { }
    Write-Host $line -ForegroundColor $Color
}

function Get-CtgNetAccountsSnapshot {
    $rows = @()
    try {
        net accounts 2>&1 | ForEach-Object { $rows += $_.ToString().Trim() }
    } catch { }
    return $rows
}

function Get-CtgPasswordPolicyFromSecedit {
    $result = [ordered]@{
        MinimumPasswordLength = $null
        MaximumPasswordAge    = $null
        LockoutBadCount       = $null
        LockoutDuration       = $null
        ResetLockoutCount     = $null
    }
    $tmpCfg = Join-Path $env:TEMP ("ctg-secedit-export-{0}.inf" -f ([guid]::NewGuid().ToString('N')))
    try {
        $null = secedit /export /cfg $tmpCfg /areas SECURITYPOLICY 2>&1
        if (Test-Path $tmpCfg) {
            $text = Get-Content -Path $tmpCfg -Raw -ErrorAction SilentlyContinue
            foreach ($key in $result.Keys) {
                if ($text -match "(?m)^$key\s*=\s*(\S+)") {
                    $result[$key] = $Matches[1]
                }
            }
        }
    } catch { }
    finally {
        Remove-Item -Path $tmpCfg -Force -ErrorAction SilentlyContinue
    }
    return $result
}

function Get-CtgAccountTypeHint {
    try {
        $whoami = whoami /user 2>&1 | Out-String
        if ($whoami -match 'S-1-12-') {
            return 'Likely Microsoft account (AzureAD/MSA SID prefix) - password often managed at account.microsoft.com'
        }
    } catch { }
    return 'Likely local account - password via Settings, Ctrl+Alt+Del, or net user (manual only)'
}

function Show-CtgRecoveryGuidance {
    Write-CtgPwdLog '--- Password recovery (preserve DuckDuckGo Password Manager) ---' 'Cyan'
    Write-CtgPwdLog '  DuckDuckGo PM: keep as primary vault on Windows + iPhone (see docs/PASSWORD_HARDENING.md)'
    Write-CtgPwdLog '  Microsoft account: https://account.microsoft.com/security - recovery codes in DDG PM'
    Write-CtgPwdLog '  Local account: Ctrl+Alt+Del -> Change a password; Repair-WindowsSignIn.ps1 for UI issues'
    Write-CtgPwdLog '  This script NEVER reads, stores, or rotates your password.'
}

function Invoke-CtgApplyPasswordPolicy {
    if (-not $script:CtgIsAdmin) {
        Write-CtgPwdLog 'ApplyPolicy requires Administrator - re-run elevated' 'Yellow'
        return $false
    }
    Write-CtgPwdLog "Applying: max age=$MaxPasswordAgeDays lockout=$LockoutThreshold duration=${LockoutMinutes}m min len=$MinPasswordLength"
    $args = @(
        '/maxpwage:' + $MaxPasswordAgeDays
        '/lockoutthreshold:' + $LockoutThreshold
        '/lockoutduration:' + $LockoutMinutes
        '/lockoutwindow:' + $LockoutMinutes
    )
    $current = Get-CtgPasswordPolicyFromSecedit
    $curMin = 0
    if ($current.MinimumPasswordLength -match '^\d+$') {
        $curMin = [int]$current.MinimumPasswordLength
    }
    if ($curMin -lt $MinPasswordLength) {
        $args += '/minpwlen:' + $MinPasswordLength
    } else {
        Write-CtgPwdLog "Minimum password length already $curMin (>= $MinPasswordLength) - not lowering"
    }
    if ($PSCmdlet.ShouldProcess('Local security policy', 'net accounts')) {
        & net accounts @args 2>&1 | ForEach-Object { Write-CtgPwdLog "  net accounts: $_" }
        if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
            Write-CtgPwdLog "net accounts exit $LASTEXITCODE" 'Yellow'
            return $false
        }
    }
    return $true
}

if (-not $ApplyPolicy) {
    $DiagnoseOnly = $true
}

Write-CtgPwdLog "=== CTG Password Policy === Computer=$env:COMPUTERNAME User=$env:USERNAME Admin=$script:CtgIsAdmin Mode=$(if ($ApplyPolicy) { 'ApplyPolicy' } else { 'DiagnoseOnly' })"

Write-CtgPwdLog '--- net accounts ---' 'Cyan'
Get-CtgNetAccountsSnapshot | ForEach-Object { Write-CtgPwdLog "  $_" }

Write-CtgPwdLog '--- secedit export (password policy section) ---' 'Cyan'
$pol = Get-CtgPasswordPolicyFromSecedit
foreach ($k in $pol.Keys) {
    Write-CtgPwdLog ("  {0} = {1}" -f $k, $(if ($null -eq $pol[$k]) { '(not set)' } else { $pol[$k] }))
}

Write-CtgPwdLog ('--- Account hint: ' + (Get-CtgAccountTypeHint)) 'Cyan'
Show-CtgRecoveryGuidance

if ($ApplyPolicy) {
    $ok = Invoke-CtgApplyPasswordPolicy
    Write-CtgPwdLog '--- After apply ---' 'Cyan'
    Get-CtgNetAccountsSnapshot | ForEach-Object { Write-CtgPwdLog "  $_" }
    if ($ok) {
        Write-CtgPwdLog 'Policy applied - update DDG PM recovery notes if lockout settings changed' 'Green'
    }
}

Write-CtgPwdLog "=== Complete === log=$LogFile"
Write-Output "LOG_FILE=$LogFile"
