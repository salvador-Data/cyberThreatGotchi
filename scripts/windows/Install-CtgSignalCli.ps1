<#
.SYNOPSIS
  Diagnose signal-cli for CTG SOC alerts and print link/register steps.

.DESCRIPTION
  signal-cli is free OSS — sends Signal messages from Windows or WSL without Twilio.
  Account data stays in gitignored config dir (never commit).
  Does not auto-download binaries — prints install URLs and one-command steps.

.PARAMETER DiagnoseOnly
  Report Java, signal-cli path, config dir, linked account, env vars.

.EXAMPLE
  .\scripts\windows\Install-CtgSignalCli.ps1 -DiagnoseOnly
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-SignalCommon.ps1')

$repo = Get-CtgRepoRoot
Import-CtgDotEnv -EnvPath (Join-Path $repo '.env')

function Write-Step([string] $Text, [string] $Color = 'Gray') {
    Write-Host $Text -ForegroundColor $Color
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ' CTG signal-cli (Signal alerts)' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan

$cli = Get-CtgSignalCliPath
$configDir = Get-CtgSignalConfigDir
$account = Get-CtgSignalAccount
$signalTo = Get-CtgSignalDestination
$configured = Test-CtgSignalConfigured

$java = Get-Command java -ErrorAction SilentlyContinue
Write-Step "Java on PATH: $(if ($java) { $java.Source } else { 'NOT FOUND (required for signal-cli JAR builds)' })" `
    $(if ($java) { 'Green' } else { 'Yellow' })
Write-Step "signal-cli: $(if ($cli) { $cli } else { 'NOT FOUND — set CTG_SIGNAL_CLI_PATH' })" `
    $(if ($cli) { 'Green' } else { 'Red' })
Write-Step "Config dir: $configDir exists=$(Test-Path $configDir)"
Write-Step "Linked account: $(if ($account) { $account } else { 'none' })"
Write-Step "CTG_ALERT_SIGNAL_TO set: $(-not [string]::IsNullOrWhiteSpace($signalTo))"
Write-Step "CTG_SIGNAL_ACCOUNT: $(if ($env:CTG_SIGNAL_ACCOUNT) { $env:CTG_SIGNAL_ACCOUNT } else { '(auto-detect if one account)' })"
Write-Step "CTG_USE_TWILIO: $(if (Test-CtgUseTwilioPreferred) { '1 (SMS preferred)' } else { 'unset (Signal preferred when configured)' })"
Write-Step "Signal ready: $configured" $(if ($configured) { 'Green' } else { 'Yellow' })

if ($DiagnoseOnly) {
    Write-Step "DiagnoseOnly: $(if ($configured) { 'PASS' } else { 'ACTION NEEDED' })" 'Cyan'
    exit $(if ($configured) { 0 } else { 1 })
}

Write-Host ''
Write-Step '--- Install signal-cli (pick one) ---' 'Cyan'
Write-Step '1. Releases: https://github.com/AsamK/signal-cli/releases'
Write-Step '   Windows: download signal-cli-*-Windows-native.zip or JAR + Java 21+'
Write-Step '   Extract to e.g. %LOCALAPPDATA%\Programs\signal-cli\ and set CTG_SIGNAL_CLI_PATH'
Write-Step '2. WSL (Debian/Ubuntu): sudo apt install signal-cli  OR  use GitHub release binary'
Write-Step '3. Scoop: scoop install signal-cli (if bucket available on your machine)'

Write-Host ''
Write-Step '--- Link this host to your Signal account (recommended) ---' 'Cyan'
Write-Step 'Scan QR from your phone (Signal > Settings > Linked Devices > Link New Device):'
Write-Step ''
Write-Step 'cd C:\Users\Owner\Projects\cyberThreatGotchi' 'White'
Write-Step ''
if ($cli) {
    Write-Step "`"$cli`" --config `"$configDir`" link -n CTG-SOC" 'White'
} else {
    Write-Step 'signal-cli --config "%USERPROFILE%\.local\share\signal-cli" link -n CTG-SOC' 'White'
}
Write-Step ''
Write-Step 'Alternative (SMS register — needs dedicated number, not your primary phone):'
Write-Step 'signal-cli -a +1XXXXXXXXXX register'
Write-Step 'signal-cli -a +1XXXXXXXXXX verify CODE'

Write-Host ''
Write-Step '--- .env (local only — never commit) ---' 'Cyan'
Write-Step 'CTG_SIGNAL_CLI_PATH=C:\Users\Owner\AppData\Local\Programs\signal-cli\signal-cli.exe'
Write-Step 'CTG_SIGNAL_CONFIG_DIR=%USERPROFILE%\.local\share\signal-cli'
Write-Step 'CTG_ALERT_SIGNAL_TO=+1XXXXXXXXXX'
Write-Step 'CTG_SIGNAL_ACCOUNT=+1XXXXXXXXXX'
Write-Step '# CTG_USE_TWILIO=1   # optional — force Twilio instead of Signal'

Write-Host ''
Write-Step '--- Vault phone (preferred over .env) ---' 'Cyan'
Write-Step '.\scripts\windows\Protect-CtgSecrets.ps1 -SetPii -Name CTG_PII_PHONE'

Write-Host ''
Write-Step '--- Test alert ---' 'Cyan'
Write-Step '.\scripts\windows\Send-CtgSignalAlert.ps1 -TestMessage -UseSecretVault' 'White'
Write-Step '.\scripts\windows\Start-CtgSuricataIDS.ps1 -TestAlert'

Write-Host ''
Write-Step "Docs: docs/SIGNAL_ALERTS.md" 'Gray'
exit $(if ($configured) { 0 } else { 1 })
