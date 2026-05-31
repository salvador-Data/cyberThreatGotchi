# Shared helpers for CTG Signal alerts via signal-cli (authorized defensive lab use only).

. (Join-Path $PSScriptRoot 'CTG-WiresharkCommon.ps1')

function Get-CtgSignalConfigDir {
    if (-not [string]::IsNullOrWhiteSpace($env:CTG_SIGNAL_CONFIG_DIR)) {
        return $env:CTG_SIGNAL_CONFIG_DIR.Trim()
    }
    $vaultDir = Join-Path (Get-CtgBackupsRoot) '.vault\signal-cli'
    if (Test-Path $vaultDir) {
        return $vaultDir
    }
    return Join-Path $env:USERPROFILE '.local\share\signal-cli'
}

function Get-CtgSignalCliPath {
    if (-not [string]::IsNullOrWhiteSpace($env:CTG_SIGNAL_CLI_PATH)) {
        $p = $env:CTG_SIGNAL_CLI_PATH.Trim()
        if (Test-Path $p) { return (Resolve-Path $p).Path }
        return $null
    }
    foreach ($candidate in @(
        (Join-Path $env:LOCALAPPDATA 'Programs\signal-cli\signal-cli.exe'),
        (Join-Path $env:USERPROFILE '.local\bin\signal-cli.exe'),
        (Join-Path $env:USERPROFILE 'scoop\shims\signal-cli.exe'),
        'C:\Tools\signal-cli\signal-cli.exe'
    )) {
        if (Test-Path $candidate) { return (Resolve-Path $candidate).Path }
    }
    $cmd = Get-Command signal-cli -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Get-CtgSignalAccount {
    if (-not [string]::IsNullOrWhiteSpace($env:CTG_SIGNAL_ACCOUNT)) {
        return $env:CTG_SIGNAL_ACCOUNT.Trim()
    }
    $configDir = Get-CtgSignalConfigDir
    if (-not (Test-Path $configDir)) { return $null }
    $dataDir = Join-Path $configDir 'data'
    if (-not (Test-Path $dataDir)) { return $null }
    $accounts = Get-ChildItem -Path $dataDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d+$' }
    if ($accounts.Count -eq 1) {
        return '+' + $accounts[0].Name
    }
    return $null
}

function Get-CtgSignalDestination {
    param([switch] $PreferVault)
    if ($PreferVault) {
        $vaultScript = Join-Path $PSScriptRoot 'Protect-CtgSecrets.ps1'
        if (Test-Path $vaultScript) {
            . $vaultScript
            $phone = Get-CtgPiiForScript -Name 'CTG_PII_PHONE'
            if (-not [string]::IsNullOrWhiteSpace($phone)) {
                return $phone.Trim()
            }
            $vaultTo = Get-CtgProtectedSecret -SecretName 'CTG_ALERT_SIGNAL_TO' -VaultFile (Get-CtgSecretVaultFilePath)
            if (-not [string]::IsNullOrWhiteSpace($vaultTo)) {
                return $vaultTo.Trim()
            }
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($env:CTG_ALERT_SIGNAL_TO)) {
        return $env:CTG_ALERT_SIGNAL_TO.Trim()
    }
    return $null
}

function Test-CtgSignalConfigured {
    $cli = Get-CtgSignalCliPath
    if (-not $cli) { return $false }
    $to = Get-CtgSignalDestination
    if (-not $to) { return $false }
    $configDir = Get-CtgSignalConfigDir
    if (-not (Test-Path $configDir)) { return $false }
    $dataDir = Join-Path $configDir 'data'
    if (-not (Test-Path $dataDir)) { return $false }
    $hasAccount = @(Get-ChildItem -Path $dataDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d+$' }).Count -gt 0
    return $hasAccount
}

function Test-CtgUseTwilioPreferred {
    $flag = $env:CTG_USE_TWILIO
    if ([string]::IsNullOrWhiteSpace($flag)) { return $false }
    return $flag -match '^(1|true|yes|on)$'
}

function Get-CtgAlertRatePath {
    $paths = Get-CtgWiresharkPaths
    return $paths.SmsRateFile
}

function Test-CtgAlertRateLimited {
    param(
        [string] $AlertType,
        [int] $RateMinutes = 15
    )
    if ($AlertType -eq 'test') { return $false }
    $ratePath = Get-CtgAlertRatePath
    if (-not (Test-Path $ratePath)) { return $false }
    try {
        $obj = Get-Content $ratePath -Raw -Encoding utf8 | ConvertFrom-Json
        if (-not $obj) { return $false }
        $lastStr = $null
        $obj.PSObject.Properties | ForEach-Object {
            if ($_.Name -eq $AlertType) { $lastStr = [string]$_.Value }
        }
        if (-not $lastStr) { return $false }
        $last = [datetime]::Parse($lastStr)
        return ((Get-Date) - $last).TotalMinutes -lt $RateMinutes
    } catch {
        return $false
    }
}

function Set-CtgAlertRateTimestamp {
    param([string] $AlertType)
    $ratePath = Get-CtgAlertRatePath
    $rate = @{}
    if (Test-Path $ratePath) {
        try {
            $obj = Get-Content $ratePath -Raw -Encoding utf8 | ConvertFrom-Json
            if ($obj) {
                $obj.PSObject.Properties | ForEach-Object { $rate[$_.Name] = $_.Value }
            }
        } catch { }
    }
    $rate[$AlertType] = (Get-Date).ToString('o')
    $out = [ordered]@{}
    foreach ($k in $rate.Keys) { $out[$k] = $rate[$k] }
    $dir = Split-Path $ratePath -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $out | ConvertTo-Json | Set-Content -Path $ratePath -Encoding utf8
}
