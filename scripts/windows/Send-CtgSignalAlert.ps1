<#
.SYNOPSIS
  Send CTG SOC alerts via signal-cli (env/vault only — never commit secrets).

.DESCRIPTION
  Rate-limited: max one message per alert_type per 15 minutes (shared with SMS rate file).
  Set CTG_ALERT_SIGNAL_TO in local .env (E.164 or Signal uuid) — do not commit .env.
  Prefer DPAPI vault CTG_PII_PHONE with -UseSecretVault.
  Account data: gitignored %USERPROFILE%\.local\share\signal-cli\ or Backups\.vault\signal-cli\

.PARAMETER AlertType
  Logical alert key used for rate limiting (e.g. suricata-sid-12345).

.PARAMETER Message
  Alert body — short, no payloads or PII.

.PARAMETER Severity
  Optional severity label (included in Message by caller; not duplicated here).

.PARAMETER TestMessage
  Send "CTG: test alert" and exit (ignores rate limit for test type).

.PARAMETER UseSecretVault
  Read destination from DPAPI vault: CTG_PII_PHONE, then CTG_ALERT_SIGNAL_TO vault key.

.EXAMPLE
  .\scripts\windows\Send-CtgSignalAlert.ps1 -TestMessage -UseSecretVault
#>
[CmdletBinding()]
param(
    [string] $AlertType = 'test',
    [string] $Message = '',
    [switch] $TestMessage,
    [switch] $UseSecretVault
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'CTG-SignalCommon.ps1')

$repo = Get-CtgRepoRoot
Import-CtgDotEnv -EnvPath (Join-Path $repo '.env')
$paths = Get-CtgWiresharkPaths

$cli = Get-CtgSignalCliPath
$configDir = Get-CtgSignalConfigDir
$account = Get-CtgSignalAccount
$to = Get-CtgSignalDestination -PreferVault:$UseSecretVault

function Write-SignalLog([string] $Text) {
    Write-CtgWiresharkLog $Text $paths.IdsLog
}

if ($TestMessage) {
    $AlertType = 'test'
    if (-not $Message) {
        $Message = 'CTG: test alert'
    }
}

if (-not $Message) {
    throw 'Message is required unless -TestMessage is used.'
}

if (-not $cli) {
    Write-SignalLog 'Signal skipped: signal-cli not found (set CTG_SIGNAL_CLI_PATH or run Install-CtgSignalCli.ps1)'
    exit 2
}

if ([string]::IsNullOrWhiteSpace($to)) {
    Write-SignalLog 'Signal skipped: CTG_ALERT_SIGNAL_TO not set (configure in local .env or vault — never commit)'
    exit 2
}

if (-not (Test-Path $configDir)) {
    Write-SignalLog "Signal skipped: config dir missing ($configDir) — run signal-cli link"
    exit 2
}

$rateMinutes = 15
if ($AlertType -ne 'test') {
    if (Test-CtgAlertRateLimited -AlertType $AlertType -RateMinutes $rateMinutes) {
        Write-SignalLog "Signal rate-limited for alert_type=$AlertType (15 min window)"
        exit 0
    }
}

$body = $Message
if ($body.Length -gt 500) {
    $body = $body.Substring(0, 497) + '...'
}

$sendArgs = @('--config', $configDir)
if ($account) {
    $sendArgs += @('-a', $account)
}
$sendArgs += @('send', '-m', $body)

if ($to -match '^\+?\d') {
    $sendArgs += $to
} else {
    $sendArgs += @('-u', $to)
}

try {
    $output = & $cli @sendArgs 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        $errText = ($output | Out-String).Trim()
        Write-SignalLog "Signal failed alert_type=$AlertType exit=$code error=$errText"
        exit 1
    }
    Write-SignalLog "Signal sent alert_type=$AlertType"
    Set-CtgAlertRateTimestamp -AlertType $AlertType
    exit 0
} catch {
    Write-SignalLog "Signal failed alert_type=$AlertType error=$($_.Exception.Message)"
    exit 1
}
