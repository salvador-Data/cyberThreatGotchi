<#
.SYNOPSIS
  Replace known CTG vault PII in text with [REDACTED:tag] placeholders.

.DESCRIPTION
  Loads DPAPI-encrypted PII briefly in memory; index and .hash sidecars hold SHA-256 only.
  Never logs plaintext. See docs/SECRET_VAULT.md.

.PARAMETER Text
  String to redact (pipeline-friendly).

.PARAMETER VaultPath
  Override vault file path (tests only).

.EXAMPLE
  $safe = .\Redact-CtgPiiInText.ps1 -Text "Alert for +12155551234 from IDS"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string] $Text,

    [string] $VaultPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Protect-CtgSecrets.ps1') -VaultPath $VaultPath

$result = Redact-CtgPiiInText -Text $Text -VaultPath $VaultPath
Write-Output $result
