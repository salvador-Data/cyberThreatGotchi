<#
.SYNOPSIS
  Encrypted username/password vault for CTG lab (Argon2id/scrypt + AES-256-GCM).

.DESCRIPTION
  Vault file: %USERPROFILE%\Backups\.vault\credentials.vault (gitignored).
  Crypto implemented in core/ctg_vault.py via scripts/ctg_vault_cli.py.
  Master password is never logged. Optional DPAPI wrap for Windows quick-unlock.

.PARAMETER InitVault
  Create a new vault (prompts for master password).

.PARAMETER UnlockVault
  Unlock vault into memory session (15-minute idle timeout).

.PARAMETER LockVault
  Clear in-memory session.

.PARAMETER AddCredential
  Add entry (requires unlocked session).

.PARAMETER GetCredential
  Return one entry by -Title.

.PARAMETER ListCredentials
  List titles/usernames only.

.PARAMETER SetCredential
  Update an existing entry.

.PARAMETER RemoveCredential
  Delete an entry.

.PARAMETER ExportVaultBackup
  Copy encrypted vault blob to Backups (gitignored).

.PARAMETER ImportFromCsv
  Import local CSV (never commit CSV files).

.PARAMETER EnableDpapiWrap
  After unlock, wrap content key with Windows DPAPI (CurrentUser).

.PARAMETER UseWindowsUser
  Unlock via DPAPI wrap (no master password prompt).

.PARAMETER VaultPath
  Override vault path (tests only).

.PARAMETER Quiet
  With -GetCredential, emit JSON only.

.EXAMPLE
  .\Ctg-CredentialVault.ps1 -InitVault

.EXAMPLE
  .\Ctg-CredentialVault.ps1 -UnlockVault
  .\Ctg-CredentialVault.ps1 -AddCredential -Title 'Kali SSH' -Username 'sal'
  .\Ctg-CredentialVault.ps1 -ListCredentials
#>
[CmdletBinding(DefaultParameterSetName = 'Help')]
param(
    [Parameter(ParameterSetName = 'Init', Mandatory = $true)]
    [switch] $InitVault,

    [Parameter(ParameterSetName = 'Unlock', Mandatory = $true)]
    [switch] $UnlockVault,

    [Parameter(ParameterSetName = 'Lock', Mandatory = $true)]
    [switch] $LockVault,

    [Parameter(ParameterSetName = 'Add', Mandatory = $true)]
    [switch] $AddCredential,

    [Parameter(ParameterSetName = 'Get', Mandatory = $true)]
    [switch] $GetCredential,

    [Parameter(ParameterSetName = 'List', Mandatory = $true)]
    [switch] $ListCredentials,

    [Parameter(ParameterSetName = 'Set', Mandatory = $true)]
    [switch] $SetCredential,

    [Parameter(ParameterSetName = 'Remove', Mandatory = $true)]
    [switch] $RemoveCredential,

    [Parameter(ParameterSetName = 'Export', Mandatory = $true)]
    [switch] $ExportVaultBackup,

    [Parameter(ParameterSetName = 'Import', Mandatory = $true)]
    [switch] $ImportFromCsv,

    [Parameter(ParameterSetName = 'Status', Mandatory = $true)]
    [switch] $VaultStatus,

    [Parameter(ParameterSetName = 'EnableDpapi', Mandatory = $true)]
    [switch] $EnableDpapiWrap,

    [Parameter(ParameterSetName = 'Init')]
    [switch] $WithDpapiWrap,

    [Parameter(ParameterSetName = 'Unlock')]
    [switch] $UseWindowsUser,

    [Parameter(ParameterSetName = 'Add')]
    [Parameter(ParameterSetName = 'Get')]
    [Parameter(ParameterSetName = 'Set')]
    [Parameter(ParameterSetName = 'Remove')]
    [string] $Title,

    [Parameter(ParameterSetName = 'Add')]
    [Parameter(ParameterSetName = 'Set')]
    [string] $Username,

    [Parameter(ParameterSetName = 'Add')]
    [Parameter(ParameterSetName = 'Set')]
    [SecureString] $Password,

    [Parameter(ParameterSetName = 'Add')]
    [Parameter(ParameterSetName = 'Set')]
    [string] $Url,

    [Parameter(ParameterSetName = 'Add')]
    [Parameter(ParameterSetName = 'Set')]
    [string] $Notes,

    [Parameter(ParameterSetName = 'Add')]
    [string] $Tags,

    [Parameter(ParameterSetName = 'Import')]
    [string] $CsvPath,

    [Parameter(ParameterSetName = 'Export')]
    [string] $BackupDestination = '',

    [Parameter(ParameterSetName = 'Get')]
    [switch] $Quiet,

    [string] $VaultPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CtgRepoRootFromScript {
    return Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

function Get-CtgDefaultCredentialVaultPath {
    return Join-Path $env:USERPROFILE 'Backups\.vault\credentials.vault'
}

function Get-CtgCredentialVaultPath {
    param([string] $OverrideVaultPath)
    if ($OverrideVaultPath) { return $OverrideVaultPath }
    return Get-CtgDefaultCredentialVaultPath
}

function Get-CtgPythonExecutable {
    $candidates = @(
        $env:CTG_PYTHON,
        (Get-Command python -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source),
        (Get-Command py -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
    ) | Where-Object { $_ }
    foreach ($exe in $candidates) {
        if ($exe -eq 'py') {
            return @('py', '-3')
        }
        if (Test-Path $exe) {
            return @($exe)
        }
    }
    throw 'Python not found. Install Python 3.10+ or set $env:CTG_PYTHON.'
}

function Test-CtgConstantTimeEqual {
    param(
        [string] $A,
        [string] $B
    )
    if ($null -eq $A -or $null -eq $B) { return $false }
    $aBytes = [Text.Encoding]::UTF8.GetBytes($A)
    $bBytes = [Text.Encoding]::UTF8.GetBytes($B)
    if ($aBytes.Length -ne $bBytes.Length) { return $false }
    $result = 0
    for ($i = 0; $i -lt $aBytes.Length; $i++) {
        $result = $result -bor ($aBytes[$i] -bxor $bBytes[$i])
    }
    return ($result -eq 0)
}

function ConvertTo-CtgPlainSecureString {
    param([SecureString] $Secure)
    if (-not $Secure) { return '' }
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Read-CtgMasterPasswordSecure {
    param([string] $Prompt = 'Enter vault master password (SecureString)')
    $secure = Read-Host -Prompt $Prompt -AsSecureString
    return ConvertTo-CtgPlainSecureString -Secure $secure
}

function Read-CtgPasswordSecure {
    param([string] $Prompt = 'Enter password (SecureString)')
    $secure = Read-Host -Prompt $Prompt -AsSecureString
    return ConvertTo-CtgPlainSecureString -Secure $secure
}

function Invoke-CtgVaultCli {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $CliArgs,
        [string] $StdinPlain = ''
    )
    $repoRoot = Get-CtgRepoRootFromScript
    $cli = Join-Path $repoRoot 'scripts\ctg_vault_cli.py'
    if (-not (Test-Path $cli)) {
        throw "Vault CLI missing: $cli"
    }
    $python = Get-CtgPythonExecutable
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $python[0]
    if ($python.Count -gt 1) {
        $psi.Arguments = ($python[1..($python.Count - 1)] + @($cli) + $CliArgs) -join ' '
    } else {
        $psi.Arguments = (@($cli) + $CliArgs) -join ' '
    }
    $psi.WorkingDirectory = $repoRoot
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $proc2 = [Diagnostics.Process]::Start($psi)
    if ($StdinPlain) {
        $proc2.StandardInput.WriteLine($StdinPlain)
    }
    $proc2.StandardInput.Close()
    $stdout = $proc2.StandardOutput.ReadToEnd()
    $stderr = $proc2.StandardError.ReadToEnd()
    $proc2.WaitForExit()
    if ($proc2.ExitCode -ne 0 -and -not $stdout) {
        throw "Vault CLI failed ($($proc2.ExitCode)): $stderr"
    }
    try {
        return ($stdout | ConvertFrom-Json)
    } catch {
        throw "Vault CLI returned invalid JSON. stderr: $stderr stdout: $stdout"
    }
}

function Get-CtgLabCredentialFromVault {
    param(
        [string] $Title = 'Kali SSH',
        [string] $VaultPathOverride = ''
    )
    $vaultFile = Get-CtgCredentialVaultPath -OverrideVaultPath $VaultPathOverride
    if (-not (Test-Path $vaultFile)) { return $null }
    $cliArgs = @('status', '--vault-path', $vaultFile)
    $status = Invoke-CtgVaultCli -CliArgs $cliArgs
    if (-not $status.session_active) {
        if ($status.dpapi_wrapped) {
            $unlockArgs = @('unlock', '--vault-path', $vaultFile, '--use-dpapi')
            $unlock = Invoke-CtgVaultCli -CliArgs $unlockArgs
            if (-not $unlock.ok) { return $null }
        } else {
            return $null
        }
    }
    $getArgs = @('get', '--vault-path', $vaultFile, '--title', $Title)
    $result = Invoke-CtgVaultCli -CliArgs $getArgs
    if (-not $result.ok) { return $null }
    return @{
        User     = [string]$result.credential.username
        Password = [string]$result.credential.password
        Title    = [string]$result.credential.title
        Source   = 'Credential vault (Ctg-CredentialVault.ps1)'
    }
}

$vaultPathResolved = Get-CtgCredentialVaultPath -OverrideVaultPath $VaultPath
$commonVaultArgs = @('--vault-path', $vaultPathResolved)

if ($InitVault) {
    $master = Read-CtgMasterPasswordSecure
    $confirm = Read-CtgMasterPasswordSecure -Prompt 'Confirm vault master password (SecureString)'
    if (-not (Test-CtgConstantTimeEqual -A $master -B $confirm)) {
        throw 'Master password confirmation mismatch'
    }
    $args = @('init') + $commonVaultArgs
    if ($WithDpapiWrap) { $args += '--enable-dpapi-wrap' }
    $result = Invoke-CtgVaultCli -CliArgs $args -StdinPlain $master
    if (-not $result.ok) { throw $result.error }
    Write-Host "Credential vault created: $($result.vault_path)"
    exit 0
}

if ($UnlockVault) {
    $args = @('unlock') + $commonVaultArgs
    $stdin = ''
    if ($UseWindowsUser) {
        $args += '--use-dpapi'
    } else {
        $stdin = Read-CtgMasterPasswordSecure
    }
    $result = Invoke-CtgVaultCli -CliArgs $args -StdinPlain $stdin
    if (-not $result.ok) { throw $result.error }
    Write-Host "Vault unlocked ($($result.entry_count) entries). Session timeout: 15 minutes."
    exit 0
}

if ($LockVault) {
    $result = Invoke-CtgVaultCli -CliArgs @('lock')
    if (-not $result.ok) { throw $result.error }
    Write-Host 'Vault locked.'
    exit 0
}

if ($VaultStatus) {
    $result = Invoke-CtgVaultCli -CliArgs (@('status') + $commonVaultArgs)
    if (-not $result.ok) { throw $result.error }
    $result | ConvertTo-Json -Compress | Write-Output
    exit 0
}

if ($ListCredentials) {
    $result = Invoke-CtgVaultCli -CliArgs (@('list') + $commonVaultArgs)
    if (-not $result.ok) { throw $result.error }
    foreach ($item in $result.credentials) {
        Write-Host "$($item.title) | user=$($item.username) | updated=$($item.updated)"
    }
    exit 0
}

if ($GetCredential) {
    if ([string]::IsNullOrWhiteSpace($Title)) { throw '-Title required' }
    $result = Invoke-CtgVaultCli -CliArgs (@('get') + $commonVaultArgs + @('--title', $Title))
    if (-not $result.ok) { throw $result.error }
    if ($Quiet) {
        $result.credential | ConvertTo-Json -Compress | Write-Output
    } else {
        Write-Output $result.credential
    }
    exit 0
}

if ($AddCredential) {
    if ([string]::IsNullOrWhiteSpace($Title)) { throw '-Title required' }
    $plainPassword = ''
    if ($Password) {
        $plainPassword = ConvertTo-CtgPlainSecureString -Secure $Password
    } else {
        $plainPassword = Read-CtgPasswordSecure -Prompt "Password for $Title"
    }
    if ([string]::IsNullOrWhiteSpace($Username)) {
        $Username = Read-Host -Prompt "Username for $Title"
    }
    $args = @('add') + $commonVaultArgs + @('--title', $Title, '--username', $Username)
    if ($Url) { $args += @('--url', $Url) }
    if ($Notes) { $args += @('--notes', $Notes) }
    if ($Tags) { $args += @('--tags', $Tags) }
    $result = Invoke-CtgVaultCli -CliArgs $args -StdinPlain $plainPassword
    if (-not $result.ok) { throw $result.error }
    Write-Host "Added credential: $($result.credential.title)"
    exit 0
}

if ($SetCredential) {
    if ([string]::IsNullOrWhiteSpace($Title)) { throw '-Title required' }
    $args = @('set') + $commonVaultArgs + @('--title', $Title)
    if ($Username) { $args += @('--username', $Username) }
    if ($Url) { $args += @('--url', $Url) }
    if ($Notes) { $args += @('--notes', $Notes) }
    $stdin = ''
    if ($Password) {
        $stdin = ConvertTo-CtgPlainSecureString -Secure $Password
        $args += '--password-from-stdin'
    }
    $result = Invoke-CtgVaultCli -CliArgs $args -StdinPlain $stdin
    if (-not $result.ok) { throw $result.error }
    Write-Host "Updated credential: $($result.credential.title)"
    exit 0
}

if ($RemoveCredential) {
    if ([string]::IsNullOrWhiteSpace($Title)) { throw '-Title required' }
    $result = Invoke-CtgVaultCli -CliArgs (@('remove') + $commonVaultArgs + @('--title', $Title))
    if (-not $result.ok) { throw $result.error }
    Write-Host "Removed credential: $Title"
    exit 0
}

if ($ExportVaultBackup) {
    $dest = $BackupDestination
    if ([string]::IsNullOrWhiteSpace($dest)) {
        $dest = Join-Path $env:USERPROFILE 'Backups\vault-backups'
    }
    $result = Invoke-CtgVaultCli -CliArgs (@('export', '--destination', $dest) + $commonVaultArgs)
    if (-not $result.ok) { throw $result.error }
    Write-Host "Encrypted vault backup: $($result.backup_path)"
    exit 0
}

if ($ImportFromCsv) {
    if ([string]::IsNullOrWhiteSpace($CsvPath)) { throw '-CsvPath required' }
    if (-not (Test-Path $CsvPath)) { throw "CSV not found: $CsvPath" }
    $result = Invoke-CtgVaultCli -CliArgs (@('import-csv', '--csv-path', $CsvPath) + $commonVaultArgs)
    if (-not $result.ok) { throw $result.error }
    Write-Host "Imported $($result.imported) credential(s) from CSV"
    exit 0
}

if ($EnableDpapiWrap) {
    $result = Invoke-CtgVaultCli -CliArgs (@('enable-dpapi') + $commonVaultArgs)
    if (-not $result.ok) { throw $result.error }
    Write-Host 'DPAPI wrap enabled on vault (Windows quick-unlock).'
    exit 0
}

if ($MyInvocation.InvocationName -eq '.') {
    return
}

Write-Host @'
CTG encrypted credential vault — master password + optional DPAPI quick-unlock.

  Init:     .\Ctg-CredentialVault.ps1 -InitVault [-WithDpapiWrap]
  Unlock:   .\Ctg-CredentialVault.ps1 -UnlockVault [-UseWindowsUser]
  Lock:     .\Ctg-CredentialVault.ps1 -LockVault
  Add:      .\Ctg-CredentialVault.ps1 -UnlockVault; .\Ctg-CredentialVault.ps1 -AddCredential -Title 'Kali SSH' -Username sal
  List:     .\Ctg-CredentialVault.ps1 -ListCredentials
  Get:      .\Ctg-CredentialVault.ps1 -GetCredential -Title 'Kali SSH'
  Backup:   .\Ctg-CredentialVault.ps1 -ExportVaultBackup

Vault file: %USERPROFILE%\Backups\.vault\credentials.vault (gitignored)
See docs/SECRET_VAULT.md
'@
