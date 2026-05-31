<#
.SYNOPSIS
  Send password rotation reminder SMS - message contains NO secrets.

.NOTES
  Called by Register-CtgSecretRotationReminder.ps1 scheduled task.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$smsScript = Join-Path $PSScriptRoot 'Send-CtgSmsAlert.ps1'
if (-not (Test-Path $smsScript)) {
    Write-Error "Missing Send-CtgSmsAlert.ps1: $smsScript"
    exit 1
}

& $smsScript `
    -AlertType 'password_rotation_reminder' `
    -Severity 'info' `
    -Message 'CTG: rotate lab passwords (Windows/Kali). Use DuckDuckGo Password Manager - never SMS secrets.'

exit $LASTEXITCODE
