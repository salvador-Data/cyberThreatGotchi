<#
.SYNOPSIS
  Diagnose CTG email vault readiness and print local setup steps (no PII in templates).

.DESCRIPTION
  Checks encrypted vault for Proton IMAP credentials. Prints one-command-per-block
  instructions for Andy to add creds locally. Never commits passwords to git.

.PARAMETER DiagnoseOnly
  Default - check and print guidance.

.PARAMETER VaultTitle
  Expected vault entry title (default: Proton IMAP).

.EXAMPLE
  .\scripts\windows\Initialize-CtgEmailVault.ps1 -DiagnoseOnly
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [string] $VaultTitle = 'Proton IMAP'
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-Paths.ps1')

$VaultDir = Join-Path $env:USERPROFILE 'Backups\.vault'
$VaultFile = Join-Path $VaultDir 'credentials.vault'
$vaultScript = Join-Path $PSScriptRoot 'Ctg-CredentialVault.ps1'

Write-Host ''
Write-Host '=== CTG email vault initialize (DiagnoseOnly) ===' -ForegroundColor Cyan
Write-Host 'No passwords are stored in git. Use placeholders below only.' -ForegroundColor Gray
Write-Host ''

$vaultOk = $false
$credFound = $false

if (Test-Path $vaultScript) {
    . $vaultScript
    if (Test-Path $VaultFile) {
        $vaultOk = $true
        Write-Host "Vault file: present ($VaultFile)" -ForegroundColor Green
        foreach ($title in @($VaultTitle, 'CTG_EMAIL_IMAP')) {
            $cred = Get-CtgLabCredentialFromVault -Title $title
            if ($cred -and $cred.User) {
                $credFound = $true
                Write-Host "Credential title '$title': found (username set - password not displayed)" -ForegroundColor Green
                break
            }
        }
        if (-not $credFound) {
            Write-Host "Credential title '$VaultTitle': NOT FOUND" -ForegroundColor Yellow
        }
    } else {
        Write-Host 'Vault file: NOT FOUND - initialize first' -ForegroundColor Yellow
    }
} else {
    Write-Host 'Ctg-CredentialVault.ps1 missing' -ForegroundColor Red
}

Write-Host ''
Write-Host '--- Manual setup (run locally, one command per block) ---' -ForegroundColor Cyan
Write-Host ''

if (-not $vaultOk) {
    Write-Host '1. Initialize encrypted vault (prompts for master password):'
    Write-Host ''
    Write-Host "cd `"$(Get-CtgRepoRoot -FromPath $PSScriptRoot)`""
    Write-Host ''
    Write-Host '.\scripts\windows\Ctg-CredentialVault.ps1 -InitVault -WithDpapiWrap'
    Write-Host ''
}

Write-Host '2. Unlock vault (or use -UseWindowsUser after DPAPI wrap):'
Write-Host ''
Write-Host '.\scripts\windows\Ctg-CredentialVault.ps1 -UnlockVault -UseWindowsUser'
Write-Host ''

Write-Host '3. Add Proton IMAP entry (Proton Bridge: host 127.0.0.1 port 1143):'
Write-Host ''
Write-Host ".\scripts\windows\Ctg-CredentialVault.ps1 -AddCredential -Title '$VaultTitle' -Username 'YOUR_PROTON_USERNAME' -Url 'imap://127.0.0.1:1143'"
Write-Host ''
Write-Host '# PowerShell will prompt for IMAP password (Bridge mailbox password - never paste in chat/docs)'
Write-Host ''

Write-Host '4. Optional vault titles for related integrations:'
Write-Host '   - Microsoft Account (Defender/backup SSO - optional)'
Write-Host '   - DuckDuckGo Password Manager: use browser extension + separate CTG lab entries in vault'
Write-Host '   - Do NOT export DDG PM bulk CSV into git'
Write-Host ''

Write-Host '5. Duck Email Protection -> Proton forwarding (browser only, no automation):'
Write-Host '   - Duck privacy dashboard: enable Email Protection, forward @your-alias to Proton inbox'
Write-Host '   - See docs/EMAIL_NOTIFICATIONS.md'
Write-Host ''

Write-Host '6. Test diagnose (no IMAP poll):'
Write-Host ''
Write-Host '.\scripts\windows\Start-CtgEmailNotifyBridge.ps1 -DiagnoseOnly -UseSecretVault'
Write-Host ''

Write-Host '7. Single poll (Proton Bridge must be running):'
Write-Host ''
Write-Host '.\scripts\windows\Start-CtgEmailNotifyBridge.ps1 -Once -UseSecretVault'
Write-Host ''

Write-Host '8. Stage Kali consumer on share:'
Write-Host ''
Write-Host '.\scripts\windows\Stage-KaliLabToBackups.ps1'
Write-Host ''

if ($credFound) {
    Write-Host 'Status: READY for -Once poll when Proton Bridge is running.' -ForegroundColor Green
    exit 0
}

Write-Host 'Status: vault entry required before IMAP poll.' -ForegroundColor Yellow
exit 0
