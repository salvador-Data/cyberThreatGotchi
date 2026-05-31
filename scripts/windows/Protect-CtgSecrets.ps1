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

.PARAMETER SetSecretHash
  Store SHA-256 hash of a secret in the DPAPI vault (key Name_HASH) — for local verification only.
  Does NOT enable scheduled-task elevation; Windows needs plaintext or Interactive/UAC.

.PARAMETER TestSecretHash
  Compare a prompted (or -Value) secret against a stored hash. Exit 0 match, 1 mismatch/missing.

.PARAMETER SetPii
  Store recoverable PII (DPAPI). Prompts with SecureString (no echo). Updates hash sidecar + index.

.PARAMETER GetPii
  Return PII to pipeline for scripts — never Write-Host the value. Use -Quiet for a Name/Value object.

.PARAMETER SetPiiHash
  Store SHA-256 of normalized PII in .vault\<Name>.hash and pii-index.json (no plaintext in index).

.PARAMETER Quiet
  With -GetPii, return [PSCustomObject]@{ Name; Value } instead of a bare string.

.PARAMETER Name
  Secret key (e.g. KALI_SSH_USER) or PII key (CTG_PII_PHONE, CTG_PII_EMAIL, …).

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

    [Parameter(ParameterSetName = 'SetHash', Mandatory = $true)]
    [switch] $SetSecretHash,

    [Parameter(ParameterSetName = 'TestHash', Mandatory = $true)]
    [switch] $TestSecretHash,

    [Parameter(ParameterSetName = 'SetPii', Mandatory = $true)]
    [switch] $SetPii,

    [Parameter(ParameterSetName = 'GetPii', Mandatory = $true)]
    [switch] $GetPii,

    [Parameter(ParameterSetName = 'SetPiiHash', Mandatory = $true)]
    [switch] $SetPiiHash,

    [Parameter(ParameterSetName = 'Set', Mandatory = $true)]
    [Parameter(ParameterSetName = 'Get', Mandatory = $true)]
    [Parameter(ParameterSetName = 'Remove', Mandatory = $true)]
    [Parameter(ParameterSetName = 'SetHash', Mandatory = $true)]
    [Parameter(ParameterSetName = 'TestHash', Mandatory = $true)]
    [Parameter(ParameterSetName = 'SetPii', Mandatory = $true)]
    [Parameter(ParameterSetName = 'GetPii', Mandatory = $true)]
    [Parameter(ParameterSetName = 'SetPiiHash', Mandatory = $true)]
    [ValidatePattern('^[A-Z][A-Z0-9_]{1,63}$')]
    [string] $Name,

    [Parameter(ParameterSetName = 'Set')]
    [Parameter(ParameterSetName = 'TestHash')]
    [Parameter(ParameterSetName = 'SetHash')]
    [Parameter(ParameterSetName = 'SetPii')]
    [Parameter(ParameterSetName = 'SetPiiHash')]
    [string] $Value,

    [Parameter(ParameterSetName = 'GetPii')]
    [switch] $Quiet,

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
    # Comma preserves single-element arrays (StrictMode: strings have no .Count)
    return ,@($store.Keys | Sort-Object)
}

function Get-CtgSecretHashKeyName {
    param([string] $SecretName)
    return "${SecretName}_HASH"
}

function Get-CtgSecretSha256Hex {
    param([string] $PlainText)
    $bytes = [Text.Encoding]::UTF8.GetBytes($PlainText)
    $hash = [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    return ([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
}

function Test-CtgConstantTimeEqual {
    param(
        [string] $A,
        [string] $B
    )
    if ($null -eq $A -or $null -eq $B) {
        return $false
    }
    $aBytes = [Text.Encoding]::UTF8.GetBytes($A)
    $bBytes = [Text.Encoding]::UTF8.GetBytes($B)
    if ($aBytes.Length -ne $bBytes.Length) {
        return $false
    }
    $result = 0
    for ($i = 0; $i -lt $aBytes.Length; $i++) {
        $result = $result -bor ($aBytes[$i] -bxor $bBytes[$i])
    }
    return ($result -eq 0)
}

function Set-CtgProtectedSecretHash {
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
    $hashKey = Get-CtgSecretHashKeyName -SecretName $SecretName
    $hashHex = Get-CtgSecretSha256Hex -PlainText $SecretValue
    $store = Get-CtgSecretStore -VaultFile $VaultFile
    $store[$hashKey] = $hashHex
    Save-CtgSecretStore -Store $store -VaultFile $VaultFile
    Write-Host "Stored hash only: $hashKey (vault: $VaultFile)"
    Write-Host 'Hash verification does NOT replace -SetSecret for scripts that need plaintext (SSH, scheduled tasks).'
}

function Test-CtgProtectedSecretHash {
    param(
        [string] $SecretName,
        [string] $SecretValue,
        [string] $VaultFile
    )
    if (-not (Test-CtgSecretName $SecretName)) {
        throw "Invalid secret name: $SecretName"
    }
    $hashKey = Get-CtgSecretHashKeyName -SecretName $SecretName
    $store = Get-CtgSecretStore -VaultFile $VaultFile
    if (-not $store.ContainsKey($hashKey)) {
        Write-Host "Hash not found: $hashKey"
        return $false
    }
    if ([string]::IsNullOrWhiteSpace($SecretValue)) {
        if ($SecretName -match 'PASSWORD|TOKEN|SECRET|KEY$') {
            $SecretValue = Read-CtgSecretSecurePrompt -SecretName $SecretName
        } else {
            $SecretValue = Read-CtgSecretPlainPrompt -SecretName $SecretName
        }
    }
    $candidate = Get-CtgSecretSha256Hex -PlainText $SecretValue
    return (Test-CtgConstantTimeEqual -A $candidate -B ([string]$store[$hashKey]))
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

$script:CtgPiiCatalog = @{
    'CTG_PII_FULL_NAME' = 'name'
    'CTG_PII_EMAIL'     = 'email'
    'CTG_PII_PHONE'     = 'phone'
    'CTG_PII_ADDRESS'   = 'address'
    'CTG_PII_SSN_LAST4' = 'ssn_last4'
}

function Test-CtgPiiName {
    param([string] $PiiName)
    return $script:CtgPiiCatalog.ContainsKey($PiiName)
}

function Get-CtgPiiRedactTag {
    param([string] $PiiName)
    if (-not (Test-CtgPiiName $PiiName)) {
        throw "Unknown PII name: $PiiName (use CTG_PII_* keys; see docs/SECRET_VAULT.md)"
    }
    return $script:CtgPiiCatalog[$PiiName]
}

function Get-CtgPiiIndexPath {
    param([string] $OverrideVaultPath)
    return Join-Path (Get-CtgSecretVaultDirectory -OverrideVaultPath $OverrideVaultPath) 'pii-index.json'
}

function Get-CtgPiiHashSidecarPath {
    param(
        [string] $PiiName,
        [string] $OverrideVaultPath
    )
    return Join-Path (Get-CtgSecretVaultDirectory -OverrideVaultPath $OverrideVaultPath) "$PiiName.hash"
}

function Get-CtgPiiIndex {
    param([string] $OverrideVaultPath)
    $path = Get-CtgPiiIndexPath -OverrideVaultPath $OverrideVaultPath
    if (-not (Test-Path $path)) {
        return @{}
    }
    try {
        $obj = Get-Content -Path $path -Raw -Encoding utf8 | ConvertFrom-Json
        $index = @{}
        if ($obj) {
            $obj.PSObject.Properties | ForEach-Object {
                $index[$_.Name] = @{
                    hash = [string]$_.Value.hash
                    tag  = [string]$_.Value.tag
                }
            }
        }
        return $index
    } catch {
        return @{}
    }
}

function Save-CtgPiiIndex {
    param(
        [hashtable] $Index,
        [string] $OverrideVaultPath
    )
    $path = Get-CtgPiiIndexPath -OverrideVaultPath $OverrideVaultPath
    $dir = Split-Path -Parent $path
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $ordered = [ordered]@{}
    foreach ($key in ($Index.Keys | Sort-Object)) {
        $ordered[$key] = [ordered]@{
            hash = $Index[$key].hash
            tag  = $Index[$key].tag
        }
    }
    $json = $ordered | ConvertTo-Json -Compress
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [IO.File]::WriteAllText($path, $json, $utf8NoBom)
}

function Write-CtgVaultUtf8NoBom {
    param(
        [string] $Path,
        [string] $Content
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Normalize-CtgPiiValue {
    param(
        [string] $PiiName,
        [string] $PlainText
    )
    if ([string]::IsNullOrWhiteSpace($PlainText)) {
        return ''
    }
    $v = $PlainText.Trim()
    switch ($PiiName) {
        'CTG_PII_FULL_NAME' { return ($v -replace '\s+', ' ').ToLowerInvariant() }
        'CTG_PII_EMAIL'     { return $v.ToLowerInvariant() }
        'CTG_PII_PHONE'     {
            $digits = ($v -replace '\D', '')
            if ($v.TrimStart().StartsWith('+') -and $digits.Length -gt 0) {
                return '+' + $digits
            }
            return $digits
        }
        'CTG_PII_ADDRESS'   { return ($v -replace '\s+', ' ').ToLowerInvariant() }
        'CTG_PII_SSN_LAST4' {
            $digits = ($v -replace '\D', '')
            if ($digits.Length -gt 4) {
                $digits = $digits.Substring($digits.Length - 4)
            }
            return $digits
        }
        default { return $v }
    }
}

function Get-CtgPiiMatchVariants {
    param(
        [string] $PiiName,
        [string] $PlainText
    )
    $variants = New-Object 'System.Collections.Generic.List[string]'
    if ([string]::IsNullOrWhiteSpace($PlainText)) {
        return @()
    }
    $trimmed = $PlainText.Trim()
    [void]$variants.Add($trimmed)
    $normalized = Normalize-CtgPiiValue -PiiName $PiiName -PlainText $trimmed
    if ($normalized -and ($normalized -ne $trimmed)) {
        [void]$variants.Add($normalized)
    }
    if ($PiiName -eq 'CTG_PII_PHONE') {
        $digits = ($trimmed -replace '\D', '')
        if ($digits -and -not ($variants -contains $digits)) {
            [void]$variants.Add($digits)
        }
        if ($digits -and -not ($variants -contains ('+' + $digits))) {
            [void]$variants.Add('+' + $digits)
        }
    }
    return ($variants | Sort-Object { $_.Length } -Descending)
}

function Read-CtgPiiSecurePrompt {
    param([string] $PiiName)
    $secure = Read-Host -Prompt "Enter PII for $PiiName (SecureString, no echo)" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Set-CtgPiiHashSidecar {
    param(
        [string] $PiiName,
        [string] $PlainText,
        [string] $OverrideVaultPath
    )
    $hashHex = Get-CtgSecretSha256Hex -PlainText (Normalize-CtgPiiValue -PiiName $PiiName -PlainText $PlainText)
    $sidecar = Get-CtgPiiHashSidecarPath -PiiName $PiiName -OverrideVaultPath $OverrideVaultPath
    $dir = Split-Path -Parent $sidecar
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [IO.File]::WriteAllText($sidecar, $hashHex, $utf8NoBom)
    $index = Get-CtgPiiIndex -OverrideVaultPath $OverrideVaultPath
    $index[$PiiName] = @{
        hash = $hashHex
        tag  = Get-CtgPiiRedactTag -PiiName $PiiName
    }
    Save-CtgPiiIndex -Index $index -OverrideVaultPath $OverrideVaultPath
    return $hashHex
}

function Set-CtgProtectedPii {
    param(
        [string] $PiiName,
        [string] $PiiValue,
        [string] $VaultFile,
        [string] $OverrideVaultPath
    )
    if (-not (Test-CtgPiiName $PiiName)) {
        throw "Invalid PII name: $PiiName"
    }
    if ([string]::IsNullOrWhiteSpace($PiiValue)) {
        $PiiValue = Read-CtgPiiSecurePrompt -PiiName $PiiName
    }
    if ([string]::IsNullOrWhiteSpace($PiiValue)) {
        throw "Empty value refused for $PiiName"
    }
    if ($PiiName -eq 'CTG_PII_SSN_LAST4') {
        $digits = ($PiiValue -replace '\D', '')
        if ($digits.Length -ne 4) {
            throw 'CTG_PII_SSN_LAST4 must be exactly 4 digits - store last-4 only, never full SSN'
        }
    }
    $store = Get-CtgSecretStore -VaultFile $VaultFile
    $store[$PiiName] = $PiiValue.Trim()
    Save-CtgSecretStore -Store $store -VaultFile $VaultFile
    Set-CtgPiiHashSidecar -PiiName $PiiName -PlainText $PiiValue -OverrideVaultPath $OverrideVaultPath | Out-Null
    Write-Host "Stored PII (DPAPI + hash sidecar): $PiiName"
}

function Get-CtgProtectedPii {
    param(
        [string] $PiiName,
        [string] $VaultFile,
        [switch] $AsObject
    )
    if (-not (Test-CtgPiiName $PiiName)) {
        throw "Invalid PII name: $PiiName"
    }
    $store = Get-CtgSecretStore -VaultFile $VaultFile
    if (-not $store.ContainsKey($PiiName)) {
        return $null
    }
    $value = [string]$store[$PiiName]
    if ($AsObject) {
        return [PSCustomObject]@{ Name = $PiiName; Value = $value }
    }
    return $value
}

function Set-CtgProtectedPiiHash {
    param(
        [string] $PiiName,
        [string] $PiiValue,
        [string] $OverrideVaultPath
    )
    if (-not (Test-CtgPiiName $PiiName)) {
        throw "Invalid PII name: $PiiName"
    }
    if ([string]::IsNullOrWhiteSpace($PiiValue)) {
        $PiiValue = Read-CtgPiiSecurePrompt -PiiName $PiiName
    }
    if ([string]::IsNullOrWhiteSpace($PiiValue)) {
        throw "Empty value refused for $PiiName"
    }
    $hashHex = Set-CtgPiiHashSidecar -PiiName $PiiName -PlainText $PiiValue -OverrideVaultPath $OverrideVaultPath
    Write-Host "Stored PII hash sidecar: $PiiName.hash (index tag: $(Get-CtgPiiRedactTag -PiiName $PiiName))"
    Write-Host 'Hash alone is not recoverable - use -SetPii for DPAPI-encrypted recovery via -GetPii / Get-CtgPiiForScript.'
}

function Get-CtgPiiForScript {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,
        [string] $VaultPath = ''
    )
    $vaultFile = Get-CtgSecretVaultFilePath -OverrideVaultPath $VaultPath
    return Get-CtgProtectedPii -PiiName $Name -VaultFile $vaultFile
}

function Redact-CtgPiiInText {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Text,
        [string] $VaultPath = ''
    )
    if ([string]::IsNullOrEmpty($Text)) {
        return $Text
    }
    $vaultFile = Get-CtgSecretVaultFilePath -OverrideVaultPath $VaultPath
    if (-not (Test-Path $vaultFile)) {
        return $Text
    }
    $index = Get-CtgPiiIndex -OverrideVaultPath $VaultPath
    $store = Get-CtgSecretStore -VaultFile $vaultFile
    $replacements = @()
    foreach ($piiName in ($script:CtgPiiCatalog.Keys | Sort-Object)) {
        if (-not $store.ContainsKey($piiName)) { continue }
        if (-not $index.ContainsKey($piiName)) { continue }
        $plain = [string]$store[$piiName]
        $tag = $index[$piiName].tag
        foreach ($variant in (Get-CtgPiiMatchVariants -PiiName $piiName -PlainText $plain)) {
            if ($variant.Length -lt 2) { continue }
            $replacements += [PSCustomObject]@{
                Pattern = [regex]::Escape($variant)
                Tag     = $tag
                Length  = $variant.Length
            }
        }
    }
    $redacted = $Text
    foreach ($item in ($replacements | Sort-Object Length -Descending)) {
        $redacted = [regex]::Replace($redacted, $item.Pattern, "[REDACTED:$($item.Tag)]")
    }
    return $redacted
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
    $names = @(Get-CtgProtectedSecretNames -VaultFile $vaultFile)
    if ($names.Count -lt 1) {
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

if ($SetSecretHash) {
    Set-CtgProtectedSecretHash -SecretName $Name -SecretValue $Value -VaultFile $vaultFile
    exit 0
}

if ($TestSecretHash) {
    $matched = Test-CtgProtectedSecretHash -SecretName $Name -SecretValue $Value -VaultFile $vaultFile
    if ($matched) {
        Write-Host "Hash match: $Name"
        exit 0
    }
    Write-Host "Hash mismatch or missing: $Name"
    exit 1
}

if ($SetPii) {
    Set-CtgProtectedPii -PiiName $Name -PiiValue $Value -VaultFile $vaultFile -OverrideVaultPath $VaultPath
    exit 0
}

if ($GetPii) {
    $found = Get-CtgProtectedPii -PiiName $Name -VaultFile $vaultFile -AsObject:$Quiet
    if ($null -eq $found) {
        exit 1
    }
    Write-Output $found
    exit 0
}

if ($SetPiiHash) {
    Set-CtgProtectedPiiHash -PiiName $Name -PiiValue $Value -OverrideVaultPath $VaultPath
    exit 0
}

Write-Host @'
CTG DPAPI secret vault — interactive use only (no secrets or PII in git).

  Set username:  .\Protect-CtgSecrets.ps1 -SetSecret -Name KALI_SSH_USER
  Set password:  .\Protect-CtgSecrets.ps1 -SetSecret -Name KALI_SSH_PASSWORD
  Set phone PII: .\Protect-CtgSecrets.ps1 -SetPii -Name CTG_PII_PHONE
  Get phone PII: .\Protect-CtgSecrets.ps1 -GetPii -Name CTG_PII_PHONE
  Set hash only: .\Protect-CtgSecrets.ps1 -SetSecretHash -Name KALI_SSH_PASSWORD
  Test hash:     .\Protect-CtgSecrets.ps1 -TestSecretHash -Name KALI_SSH_PASSWORD
  List names:    .\Protect-CtgSecrets.ps1 -ListSecrets
  Read (script): .\Protect-CtgSecrets.ps1 -GetSecret -Name KALI_SSH_USER

Never embed SHA256, passwords, or PII in committed .ps1 files — use this vault or .env (gitignored).

See docs/SECRET_VAULT.md
'@
