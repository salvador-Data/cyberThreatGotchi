<#
.SYNOPSIS
  DPAPI-protected local secret vault for CTG lab scripts (Windows CurrentUser scope).

.DESCRIPTION
  Secrets live under %USERPROFILE%\Backups\.vault\secrets.dpapi — never in git.
  Set values interactively on your machine; other scripts read via -GetSecret or dot-sourcing.

.PARAMETER SetSecret
  Store or update a named secret (prompts when -Value omitted).

.PARAMETER GetSecret
  Return one secret to the pipeline (for Deploy-KaliLab.ps1 and peers).

.PARAMETER ListSecrets
  Print secret names only (never values).

.PARAMETER RemoveSecret
  Delete a named secret from the vault.

.PARAMETER Name
  Secret key (e.g. KALI_SSH_USER, KALI_SSH_PASSWORD). Uppercase A-Z, digits, underscore.

.PARAMETER Value
  Optional value for -SetSecret. Omit to prompt (SecureString for *PASSWORD names).

.PARAMETER VaultPath
  Override vault file path (tests only — do not commit real vaults).

.EXAMPLE
  .\Protect-CtgSecrets.ps1 -SetSecret -Name KALI_SSH_USER

.EXAMPLE
  .\Protect-CtgSecrets.ps1 -SetSecret -Name KALI_SSH_PASSWORD

.EXAMPLE
  $pw = .\Protect-CtgSecrets.ps1 -GetSecret -Name KALI_SSH_PASSWORD
#>
[CmdletBinding(DefaultParameterSetName = 'None')]
param(
    [Parameter(ParameterSetName = 'Set', Mandatory = $true)]
    [switch] $SetSecret,

    [Parameter(ParameterSetName = 'Get', Mandatory = $true)]
    [switch] $GetSecret,

    [Parameter(ParameterSetName = 'List', Mandatory = $true)]
    [switch] $ListSecrets,

    [Parameter(ParameterSetName = 'Remove', Mandatory = $true)]
    [switch] $RemoveSecret,

    [Parameter(ParameterSetName = 'Set', Mandatory = $true)]
    [Parameter(ParameterSetName = 'Get', Mandatory = $true)]
    [Parameter(ParameterSetName = 'Remove', Mandatory = $true)]
    [ValidatePattern('^[A-Z][A-Z0-9_]{1,63}$')]
    [string] $Name,

    [Parameter(ParameterSetName = 'Set')]
    [string] $Value,

    [string] $VaultPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Security

function Get-CtgSecretVaultDirectory {
    param([string] $OverrideVaultPath)
    if ($OverrideVaultPath) {
        return (Split-Path -Parent $OverrideVaultPath)
    }
    return Join-Path $env:USERPROFILE 'Backups\.vault'
}

function Get-CtgSecretVaultFilePath {
    param([string] $OverrideVaultPath)
    if ($OverrideVaultPath) {
        return $OverrideVaultPath
    }
    return Join-Path (Get-CtgSecretVaultDirectory) 'secrets.dpapi'
}

function Test-CtgSecretName {
    param([string] $SecretName)
    return ($SecretName -match '^[A-Z][A-Z0-9_]{1,63}$')
}

function Read-CtgSecretPlainPrompt {
    param([string] $SecretName)
    $secure = Read-Host -Prompt "Enter value for $SecretName" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Read-CtgSecretSecurePrompt {
    param([string] $SecretName)
    $secure = Read-Host -Prompt "Enter secret for $SecretName (SecureString)" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Get-CtgSecretStore {
    param([string] $VaultFile)
    if (-not (Test-Path $VaultFile)) {
        return @{}
    }
    $raw = [IO.File]::ReadAllBytes($VaultFile)
    if ($raw.Length -eq 0) {
        return @{}
    }
    $plain = [Security.Cryptography.ProtectedData]::Unprotect(
        $raw,
        $null,
        [Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    $json = [Text.Encoding]::UTF8.GetString($plain)
    $obj = $json | ConvertFrom-Json
    $store = @{}
    if ($obj) {
        $obj.PSObject.Properties | ForEach-Object { $store[$_.Name] = [string]$_.Value }
    }
    return $store
}

function Save-CtgSecretStore {
    param(
        [hashtable] $Store,
        [string] $VaultFile
    )
    $dir = Split-Path -Parent $VaultFile
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $ordered = [ordered]@{}
    foreach ($key in ($Store.Keys | Sort-Object)) {
        $ordered[$key] = $Store[$key]
    }
    $json = ($ordered | ConvertTo-Json -Compress)
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $protected = [Security.Cryptography.ProtectedData]::Protect(
        $bytes,
        $null,
        [Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    [IO.File]::WriteAllBytes($VaultFile, $protected)
}

function Set-CtgProtectedSecret {
    param(
        [string] $SecretName,
        [string] $SecretValue,
        [string] $VaultFile
    )
    if (-not (Test-CtgSecretName $SecretName)) {
        throw "Invalid secret name: $SecretName"
    }
    if ([string]::IsNullOrWhiteSpace($SecretValue)) {
        if ($SecretName -match 'PASSWORD|TOKEN|SECRET|KEY$') {
            $SecretValue = Read-CtgSecretSecurePrompt -SecretName $SecretName
        } else {
            $SecretValue = Read-CtgSecretPlainPrompt -SecretName $SecretName
        }
    }
    if ([string]::IsNullOrWhiteSpace($SecretValue)) {
        throw "Empty value refused for $SecretName"
    }
    $store = Get-CtgSecretStore -VaultFile $VaultFile
    $store[$SecretName] = $SecretValue
    Save-CtgSecretStore -Store $store -VaultFile $VaultFile
    Write-Host "Stored secret: $SecretName (vault: $VaultFile)"
}

function Get-CtgProtectedSecret {
    param(
        [string] $SecretName,
        [string] $VaultFile
    )
    if (-not (Test-CtgSecretName $SecretName)) {
        throw "Invalid secret name: $SecretName"
    }
    $store = Get-CtgSecretStore -VaultFile $VaultFile
    if (-not $store.ContainsKey($SecretName)) {
        return $null
    }
    return [string]$store[$SecretName]
}

function Get-CtgProtectedSecretNames {
    param([string] $VaultFile)
    $store = Get-CtgSecretStore -VaultFile $VaultFile
    return @($store.Keys | Sort-Object)
}

function Remove-CtgProtectedSecret {
    param(
        [string] $SecretName,
        [string] $VaultFile
    )
    if (-not (Test-CtgSecretName $SecretName)) {
        throw "Invalid secret name: $SecretName"
    }
    $store = Get-CtgSecretStore -VaultFile $VaultFile
    if (-not $store.ContainsKey($SecretName)) {
        Write-Host "Secret not found: $SecretName"
        return
    }
    $store.Remove($SecretName) | Out-Null
    if ($store.Count -eq 0) {
        if (Test-Path $VaultFile) {
            Remove-Item -Path $VaultFile -Force
        }
    } else {
        Save-CtgSecretStore -Store $store -VaultFile $VaultFile
    }
    Write-Host "Removed secret: $SecretName"
}

$vaultFile = Get-CtgSecretVaultFilePath -OverrideVaultPath $VaultPath

if ($MyInvocation.InvocationName -eq '.') {
    return
}

if ($SetSecret) {
    Set-CtgProtectedSecret -SecretName $Name -SecretValue $Value -VaultFile $vaultFile
    exit 0
}

if ($GetSecret) {
    $found = Get-CtgProtectedSecret -SecretName $Name -VaultFile $vaultFile
    if ($null -eq $found) {
        exit 1
    }
    Write-Output $found
    exit 0
}

if ($ListSecrets) {
    $names = Get-CtgProtectedSecretNames -VaultFile $vaultFile
    if ($names.Count -eq 0) {
        Write-Host 'Vault empty or missing.'
        exit 0
    }
    $names | ForEach-Object { Write-Host $_ }
    exit 0
}

if ($RemoveSecret) {
    Remove-CtgProtectedSecret -SecretName $Name -VaultFile $vaultFile
    exit 0
}

Write-Host @'
CTG DPAPI secret vault — interactive use only (no secrets in git).

  Set username:  .\Protect-CtgSecrets.ps1 -SetSecret -Name KALI_SSH_USER
  Set password:  .\Protect-CtgSecrets.ps1 -SetSecret -Name KALI_SSH_PASSWORD
  List names:    .\Protect-CtgSecrets.ps1 -ListSecrets
  Read (script): .\Protect-CtgSecrets.ps1 -GetSecret -Name KALI_SSH_USER

See docs/SECRET_VAULT.md
'@
