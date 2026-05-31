<#
.SYNOPSIS
  DPAPI-encrypt local lab config blobs to Backups\.vault\ (config only — not offensive tooling).

.DESCRIPTION
  Stores operator-specific config templates (lab Wi-Fi placeholders, event bus paths, IMAP
  metadata) as DPAPI-protected files under %USERPROFILE%\Backups\.vault\sensitive\.
  Never commits secrets to git. Does NOT encrypt or ship jammer/deauth/counter-RF scripts.

.PARAMETER EncryptFile
  Encrypt a local plaintext config file to .vault\sensitive\<Name>.dpapi.

.PARAMETER DecryptFile
  Decrypt a vault blob to stdout (for operator review — redirect to gitignored path).

.PARAMETER ListBlobs
  List encrypted blob names only.

.PARAMETER Name
  Logical name for the blob (e.g. LabWifiTemplate, EventBusPaths).

.PARAMETER SourcePath
  Plaintext source file for -EncryptFile (must exist locally, never in git with real values).

.PARAMETER DiagnoseOnly
  Show vault directory and usage — no crypto.

.EXAMPLE
  .\Protect-CtgSensitiveScripts.ps1 -DiagnoseOnly

.EXAMPLE
  .\Protect-CtgSensitiveScripts.ps1 -EncryptFile -Name LabWifiTemplate -SourcePath C:\Users\Owner\Backups\lab-wifi.conf
#>
[CmdletBinding(DefaultParameterSetName = 'None')]
param(
    [Parameter(ParameterSetName = 'Encrypt', Mandatory = $true)]
    [switch] $EncryptFile,

    [Parameter(ParameterSetName = 'Decrypt', Mandatory = $true)]
    [switch] $DecryptFile,

    [Parameter(ParameterSetName = 'List', Mandatory = $true)]
    [switch] $ListBlobs,

    [Parameter(ParameterSetName = 'Diagnose', Mandatory = $true)]
    [switch] $DiagnoseOnly,

    [string] $Name = '',
    [string] $SourcePath = '',
    [string] $VaultDir = ''
)

$ErrorActionPreference = 'Stop'

if (-not $VaultDir) {
    $VaultDir = Join-Path $env:USERPROFILE 'Backups\.vault\sensitive'
}

function Write-CtgSensitiveLog {
    param([string] $Message)
    Write-Host "[Protect-CtgSensitiveScripts] $Message"
}

function Protect-CtgBytes {
    param([byte[]] $PlainBytes)
    return [System.Security.Cryptography.ProtectedData]::Protect(
        $PlainBytes,
        $null,
        [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
}

function Unprotect-CtgBytes {
    param([byte[]] $CipherBytes)
    return [System.Security.Cryptography.ProtectedData]::Unprotect(
        $CipherBytes,
        $null,
        [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
}

function Get-CtgSensitiveBlobPath {
    param([string] $BlobName)
    if (-not $BlobName) { throw 'Name required' }
    $safe = ($BlobName -replace '[^\w\-.]', '_')
    return Join-Path $VaultDir "$safe.dpapi"
}

if ($DiagnoseOnly) {
    Write-CtgSensitiveLog "Vault dir: $VaultDir (gitignored via .gitignore Backups/.vault/)"
    Write-CtgSensitiveLog 'Purpose: lab config templates only — NOT jammer/deauth/counter-RF tooling'
    Write-CtgSensitiveLog 'Preferred store for credentials: Ctg-CredentialVault.ps1'
    Write-CtgSensitiveLog 'See docs/SECRET_VAULT.md and docs/GITHUB_NOTIFICATIONS.md'
    if (Test-Path $VaultDir) {
        Get-ChildItem $VaultDir -Filter '*.dpapi' -ErrorAction SilentlyContinue |
            ForEach-Object { Write-CtgSensitiveLog "  blob: $($_.Name)" }
    }
    exit 0
}

if (-not (Test-Path $VaultDir)) {
    New-Item -ItemType Directory -Path $VaultDir -Force | Out-Null
}

if ($ListBlobs) {
    Get-ChildItem $VaultDir -Filter '*.dpapi' -ErrorAction SilentlyContinue |
        ForEach-Object { $_.BaseName }
    exit 0
}

if ($EncryptFile) {
    if (-not $Name) { throw '-Name required with -EncryptFile' }
    if (-not $SourcePath -or -not (Test-Path $SourcePath)) {
        throw "SourcePath not found: $SourcePath"
    }
    $plain = [System.IO.File]::ReadAllBytes($SourcePath)
    $protected = Protect-CtgBytes -PlainBytes $plain
    $dest = Get-CtgSensitiveBlobPath -BlobName $Name
    [System.IO.File]::WriteAllBytes($dest, $protected)
    Write-CtgSensitiveLog "Encrypted -> $dest"
    exit 0
}

if ($DecryptFile) {
    if (-not $Name) { throw '-Name required with -DecryptFile' }
    $src = Get-CtgSensitiveBlobPath -BlobName $Name
    if (-not (Test-Path $src)) { throw "Blob not found: $src" }
    $cipher = [System.IO.File]::ReadAllBytes($src)
    $plain = Unprotect-CtgBytes -CipherBytes $cipher
    [Console]::OpenStandardOutput().Write($plain, 0, $plain.Length)
    exit 0
}

Write-CtgSensitiveLog 'No action — use -DiagnoseOnly, -EncryptFile, -DecryptFile, or -ListBlobs'
exit 1
