<#
.SYNOPSIS
  Route CTG IDS alerts to Signal (preferred) or Twilio SMS (fallback).

.DESCRIPTION
  Default: Signal when signal-cli is configured and CTG_USE_TWILIO is not set.
  Fallback: Twilio SMS when CTG_USE_TWILIO=1, Signal unavailable, or -UseTwilio.
  Force Signal with -UseSignal when both channels are configured.

.PARAMETER AlertType
  Rate-limit key (e.g. snort-sid-1000001).

.PARAMETER Message
  Short alert body - no payloads or PII.

.PARAMETER Severity
  Passed through to Twilio SMS prefix when SMS channel is used.

.PARAMETER TestMessage
  Send test alert via selected channel.

.PARAMETER UseSecretVault
  Read phone/recipient from DPAPI vault.

.PARAMETER UseSignal
  Force signal-cli even when CTG_USE_TWILIO=1.

.PARAMETER UseTwilio
  Force Twilio SMS.

.EXAMPLE
  .\scripts\windows\Send-CtgIdsAlert.ps1 -TestMessage -UseSecretVault
#>
[CmdletBinding()]
param(
    [string] $AlertType = 'test',
    [string] $Message = '',
    [string] $Severity = 'info',
    [switch] $TestMessage,
    [switch] $UseSecretVault,
    [switch] $UseSignal,
    [switch] $UseTwilio
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'CTG-SignalCommon.ps1')

$repo = Get-CtgRepoRoot
Import-CtgDotEnv -EnvPath (Join-Path $repo '.env')

$signalScript = Join-Path $PSScriptRoot 'Send-CtgSignalAlert.ps1'
$smsScript = Join-Path $PSScriptRoot 'Send-CtgSmsAlert.ps1'

function Invoke-CtgSignalChannel {
    $args = @{
        AlertType = $AlertType
        Message   = $Message
    }
    if ($TestMessage) { $args['TestMessage'] = $true }
    if ($UseSecretVault) { $args['UseSecretVault'] = $true }
    & $signalScript @args
    return $LASTEXITCODE
}

function Invoke-CtgTwilioChannel {
    $args = @{
        AlertType = $AlertType
        Message   = $Message
        Severity  = $Severity
    }
    if ($TestMessage) { $args['TestMessage'] = $true }
    if ($UseSecretVault) { $args['UseSecretVault'] = $true }
    & $smsScript @args
    return $LASTEXITCODE
}

$signalReady = Test-CtgSignalConfigured
$twilioReady = @(
    $env:TWILIO_ACCOUNT_SID, $env:TWILIO_AUTH_TOKEN,
    $env:TWILIO_FROM_NUMBER
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$twilioReady = ($twilioReady.Count -eq 3) -and (
    -not [string]::IsNullOrWhiteSpace($env:CTG_ALERT_SMS_TO) -or $UseSecretVault
)

if ($UseTwilio -or (Test-CtgUseTwilioPreferred -and -not $UseSignal)) {
    if ($twilioReady) {
        exit (Invoke-CtgTwilioChannel)
    }
    if ($signalReady) {
        exit (Invoke-CtgSignalChannel)
    }
    exit 2
}

if ($UseSignal -or $signalReady) {
    $code = Invoke-CtgSignalChannel
    if ($code -eq 0 -or $code -eq 2) {
        if ($code -eq 2 -and $twilioReady -and -not $UseSignal) {
            exit (Invoke-CtgTwilioChannel)
        }
        exit $code
    }
    if ($twilioReady) {
        exit (Invoke-CtgTwilioChannel)
    }
    exit $code
}

if ($twilioReady) {
    exit (Invoke-CtgTwilioChannel)
}

exit 2
