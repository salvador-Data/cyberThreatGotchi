<#
.SYNOPSIS
  Send CTG SOC SMS alerts via Twilio (env vars only - never commit secrets).

.DESCRIPTION
  Rate-limited: max one SMS per alert_type per 15 minutes.
  Set CTG_ALERT_SMS_TO in your local .env (E.164) - do not commit .env.
  Rate state: Backups/logs/sms-rate-limit.json

.PARAMETER AlertType
  Logical alert key used for rate limiting (e.g. port_scan, syn_flood).

.PARAMETER Message
  SMS body (1600 char Twilio limit enforced softly at 1500).

.PARAMETER Severity
  Optional severity label prepended to message.

.PARAMETER TestMessage
  Send a test SMS and exit (ignores rate limit for test type once).

.EXAMPLE
  .\scripts\windows\Send-CtgSmsAlert.ps1 -TestMessage
#>
[CmdletBinding()]
param(
    [string] $AlertType = 'test',
    [string] $Message = '',
    [string] $Severity = 'info',
    [switch] $TestMessage
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'CTG-WiresharkCommon.ps1')

$repo = Get-CtgRepoRoot
Import-CtgDotEnv -EnvPath (Join-Path $repo '.env')
$paths = Get-CtgWiresharkPaths

$sid = $env:TWILIO_ACCOUNT_SID
$token = $env:TWILIO_AUTH_TOKEN
$from = $env:TWILIO_FROM_NUMBER
$to = $env:CTG_ALERT_SMS_TO

function Write-SmsLog([string] $Text) {
    Write-CtgWiresharkLog $Text $paths.IdsLog
}

if ($TestMessage) {
    $AlertType = 'test'
    if (-not $Message) {
        $Message = "CTG Wireshark IDS test from $env:COMPUTERNAME at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    }
}

if (-not $Message) {
    throw 'Message is required unless -TestMessage is used.'
}

foreach ($req in @(
    @{ Name = 'TWILIO_ACCOUNT_SID'; Value = $sid },
    @{ Name = 'TWILIO_AUTH_TOKEN'; Value = $token },
    @{ Name = 'TWILIO_FROM_NUMBER'; Value = $from },
    @{ Name = 'CTG_ALERT_SMS_TO'; Value = $to }
)) {
    if ([string]::IsNullOrWhiteSpace($req.Value)) {
        Write-SmsLog "SMS skipped: $($req.Name) not set (configure in local .env - never commit)"
        exit 2
    }
}

$rateMinutes = 15
$now = Get-Date
$ratePath = $paths.SmsRateFile
$rate = @{}
if (Test-Path $ratePath) {
    try {
        $obj = Get-Content $ratePath -Raw -Encoding utf8 | ConvertFrom-Json
        if ($obj) {
            $obj.PSObject.Properties | ForEach-Object { $rate[$_.Name] = $_.Value }
        }
    } catch {
        $rate = @{}
    }
}

if ($AlertType -ne 'test') {
    if ($rate.ContainsKey($AlertType)) {
        $last = [datetime]::Parse([string]$rate[$AlertType])
        if (($now - $last).TotalMinutes -lt $rateMinutes) {
            Write-SmsLog "SMS rate-limited for alert_type=$AlertType (15 min window)"
            exit 0
        }
    }
}

$body = "[CTG-$Severity] $Message"
if ($body.Length -gt 1500) {
    $body = $body.Substring(0, 1497) + '...'
}

$uri = "https://api.twilio.com/2010-04-01/Accounts/$sid/Messages.json"
$pairs = @{
    From = $from
    To   = $to
    Body = $body
}

try {
    $resp = Invoke-RestMethod -Uri $uri -Method Post -Body $pairs -Credential (New-Object PSCredential($sid, (ConvertTo-SecureString $token -AsPlainText -Force))) -ErrorAction Stop
    Write-SmsLog "SMS sent alert_type=$AlertType sid=$($resp.sid)"
    $rate[$AlertType] = $now.ToString('o')
    $out = [ordered]@{}
    foreach ($k in $rate.Keys) { $out[$k] = $rate[$k] }
    $out | ConvertTo-Json | Set-Content -Path $ratePath -Encoding utf8
    exit 0
} catch {
    Write-SmsLog "SMS failed alert_type=$AlertType error=$($_.Exception.Message)"
    exit 1
}
