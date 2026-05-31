<#
.SYNOPSIS
  Poll Proton IMAP (single source) and stage email notifications for Kali guest.

.DESCRIPTION
  Architecture: Duck Email Protection forwards alias -> Proton inbox. Poll ONE IMAP
  (Proton Bridge localhost:1143 or Proton IMAP with vault creds). Dedup by Message-ID
  then SHA-256 content fingerprint — avoids double notify when forward + direct arrive.

  Credentials: vault title 'Proton IMAP' or 'CTG_EMAIL_IMAP' (never in git).
  State: %USERPROFILE%\Backups\.vault\email-notify-state.json (gitignored).
  Output: %USERPROFILE%\Backups\ctg-email-notify\*.json (ctg-backups share).

.PARAMETER DiagnoseOnly
  Check vault, paths, Python CLI — no IMAP poll.

.PARAMETER Once
  Single poll cycle.

.PARAMETER Loop
  Poll every -IntervalSeconds (Ctrl+C to stop).

.PARAMETER UseSecretVault
  Read IMAP creds from Ctg-CredentialVault.ps1.

.PARAMETER VaultTitle
  Vault entry title (default: Proton IMAP).

.PARAMETER SignalHighPriority
  Invoke Send-CtgIdsAlert.ps1 for urgent subjects.

.PARAMETER GithubOnly
  Poll only GitHub CI/Actions emails for cyberThreatGotchi (dedupe still applies).

.EXAMPLE
  .\scripts\windows\Start-CtgEmailNotifyBridge.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Start-CtgEmailNotifyBridge.ps1 -Once -UseSecretVault
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [switch] $Once,
    [switch] $Loop,
    [int] $IntervalSeconds = 120,
    [switch] $UseSecretVault,
    [string] $VaultTitle = '',
    [switch] $SignalHighPriority,
    [switch] $GithubOnly,
    [string] $ImapHost = '127.0.0.1',
    [int] $ImapPort = 1143,
    [string] $Mailbox = 'INBOX'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'CTG-Paths.ps1')

$LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
$LogFile = Join-Path $LogDir 'start-ctg-email-notify-bridge.log'
$StatePath = Join-Path $env:USERPROFILE 'Backups\.vault\email-notify-state.json'
$OutDir = Join-Path $env:USERPROFILE 'Backups\ctg-email-notify'
$Repo = Get-CtgRepoRoot -FromPath $PSScriptRoot
$Cli = Join-Path $Repo 'scripts\ctg_email_notify_cli.py'

if (-not $VaultTitle) {
    $VaultTitle = [Environment]::GetEnvironmentVariable('CTG_EMAIL_VAULT_TITLE', 'User')
    if (-not $VaultTitle) { $VaultTitle = 'Proton IMAP' }
}

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

function Write-CtgEmailLog {
    param([string] $Message, [string] $Color = 'Gray')
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Host $line -ForegroundColor $Color
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Get-CtgEmailImapCredential {
    if (-not $UseSecretVault) {
        return @{
            User     = $env:CTG_IMAP_USER
            Password = $env:CTG_IMAP_PASSWORD
            Source   = 'environment'
        }
    }
    $vaultScript = Join-Path $PSScriptRoot 'Ctg-CredentialVault.ps1'
    if (-not (Test-Path $vaultScript)) { return $null }
    . $vaultScript
    foreach ($title in @($VaultTitle, 'CTG_EMAIL_IMAP', 'Proton IMAP')) {
        $cred = Get-CtgLabCredentialFromVault -Title $title
        if ($cred) {
            return @{
                User     = $cred.User
                Password = $cred.Password
                Source   = $cred.Source
                Title    = $title
            }
        }
    }
    return $null
}

function Invoke-CtgEmailPollOnce {
    $cred = Get-CtgEmailImapCredential
    if (-not $cred -or -not $cred.User -or -not $cred.Password) {
        Write-CtgEmailLog 'IMAP credentials missing — run Initialize-CtgEmailVault.ps1 -DiagnoseOnly' 'Yellow'
        return 2
    }

    $env:CTG_IMAP_HOST = $ImapHost
    $env:CTG_IMAP_PORT = [string]$ImapPort
    $env:CTG_IMAP_USER = $cred.User
    $env:CTG_IMAP_PASSWORD = $cred.Password
    $env:CTG_IMAP_MAILBOX = $Mailbox
    $env:CTG_EMAIL_NOTIFY_STATE = $StatePath
    $env:CTG_EMAIL_NOTIFY_OUT = $OutDir

    $pollArgs = @($Cli, 'poll')
    if ($GithubOnly) {
        $pollArgs += '--github-only'
        Write-CtgEmailLog 'GithubOnly: filtering notifications@github.com + cyberThreatGotchi subjects' 'Gray'
    }

    $py = Get-Command python -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
    if (-not $py) {
        Write-CtgEmailLog 'Python not found — activate .venv or install Python' 'Red'
        return 1
    }

    $titleLabel = if ($cred.Title) { $cred.Title } else { $VaultTitle }
    Write-CtgEmailLog ("Polling IMAP {0}:{1} as vault title '{2}'" -f $ImapHost, $ImapPort, $titleLabel) 'Cyan'
    $output = & $py.Path @pollArgs 2>&1 | Out-String
    try {
        $result = $output | ConvertFrom-Json
    } catch {
        Write-CtgEmailLog "Poll failed (non-JSON): $output" 'Red'
        return 1
    }
    if (-not $result.ok) {
        Write-CtgEmailLog ("Poll error: $($result.error)" ) 'Red'
        return 1
    }

    Write-CtgEmailLog ("New: $($result.new_count) skipped_dup: $($result.skipped_duplicate_count)") 'Green'

    if ($SignalHighPriority -and $result.new_count -gt 0) {
        $alertScript = Join-Path $PSScriptRoot 'Send-CtgIdsAlert.ps1'
        foreach ($path in @($result.written)) {
            if (-not (Test-Path $path)) { continue }
            $note = Get-Content $path -Raw | ConvertFrom-Json
            $subj = [string]$note.subject
            if ($subj -match '(?i)(urgent|critical|alert|security|breach|wazuh|ids|fail2ban)') {
                & $alertScript -AlertType 'email-notify' -Message ("Email: $subj") -UseSecretVault
            }
        }
    }
    return 0
}

Write-CtgEmailLog '=== CTG email notify bridge ===' 'Cyan'
Write-CtgEmailLog "State: $StatePath"
Write-CtgEmailLog "Output: $OutDir"
Write-CtgEmailLog 'Dedup: Message-ID primary; fallback SHA-256(From+Date+Subject+1KB body)' 'Gray'
Write-CtgEmailLog 'See docs/EMAIL_NOTIFICATIONS.md' 'Gray'

$credCheck = Get-CtgEmailImapCredential
if ($credCheck -and $credCheck.User) {
    Write-CtgEmailLog ("Vault/env creds: user present (source={0})" -f $credCheck.Source) 'Green'
} else {
    Write-CtgEmailLog 'No IMAP credentials — DiagnoseOnly will list setup steps' 'Yellow'
}

if (-not (Test-Path $Cli)) {
    Write-CtgEmailLog "Missing CLI: $Cli" 'Red'
    exit 1
}

if ($DiagnoseOnly -and -not $Once -and -not $Loop) {
    Write-CtgEmailLog 'DiagnoseOnly complete. Proton Bridge must be running on 127.0.0.1:1143 for Bridge mode.' 'Cyan'
    exit 0
}

if (-not $Once -and -not $Loop) { $Once = $true }

if ($Once) {
    exit (Invoke-CtgEmailPollOnce)
}

while ($true) {
    Invoke-CtgEmailPollOnce | Out-Null
    Start-Sleep -Seconds $IntervalSeconds
}
