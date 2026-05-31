<#
.SYNOPSIS
  Diagnose or privatize security-sensitive salvador-Data repos (allowlist only).

.DESCRIPTION
  Lists public repos that match CTG hardening/lab automation patterns. -Apply sets
  visibility to private ONLY for names in the committed allowlist below - review
  before enabling -Apply. No secrets in this script.

  Does NOT privatize firmware/hardware repos (M5_OS-Cardputer, Mr-CrackBot-AI, etc.)
  or the public cyberThreatGotchi website monorepo unless explicitly allowlisted.

.PARAMETER DiagnoseOnly
  List candidate repos and allowlist status (default).

.PARAMETER Apply
  Set visibility private for allowlisted repos only (requires gh auth).

.EXAMPLE
  .\scripts\publish\Set-CtgPrivateRepos.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\publish\Set-CtgPrivateRepos.ps1 -Apply
#>
[CmdletBinding()]
param(
    [switch] $DiagnoseOnly,
    [switch] $Apply
)

$ErrorActionPreference = 'Stop'

# COMMITTED ALLOWLIST - edit here before -Apply; empty = nothing privatized on Apply
$Script:CtgPrivateRepoAllowlist = @(
    'ctg-kali-lab'
    'ctg-windows-soc'
    'ctg-device-hardening'
)

# Public repos that are hardening/lab-sensitive (recommend private - not auto-applied unless allowlisted)
$Script:CtgSensitiveRepoCandidates = @(
    'ctg-kali-lab'
    'ctg-windows-soc'
    'ctg-device-hardening'
)

# Never suggest privatizing (public site, firmware, forks, portfolio)
$Script:CtgNeverPrivatePatterns = @(
    'cyberThreatGotchi'
    'M5_OS-Cardputer'
    'Mr-CrackBot-AI'
    'Mr.-CrackBot-AI-Nano'
    'BLE-Bot-Cardputer'
    'Remote-Possibility'
    'Bjorn'
    'awesome-osint'
    'osint-cheat-sheet'
    'ghost-osint-crm'
    'WebHackersWeapons'
    'flipperzero'
    'Flipper-Zero'
    'EvilPortal'
    'evilportal'
    'Multinational-Vigenre'
)

function Test-CtgGhAvailable {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Error 'gh CLI not found - install GitHub CLI and authenticate'
        exit 2
    }
}

function Get-CtgGhRepos {
    $raw = gh repo list salvador-Data --limit 100 --json name,visibility,description 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "gh repo list failed: $raw"
        exit 2
    }
    return ($raw | ConvertFrom-Json)
}

Write-Host '=== CTG private repo helper (allowlist-gated) ===' -ForegroundColor Cyan
Test-CtgGhAvailable

$repos = Get-CtgGhRepos
$runApply = $Apply -and -not $DiagnoseOnly

if ($DiagnoseOnly -or -not $Apply) {
    Write-Host ''
    Write-Host 'Allowlist (only these change on -Apply):' -ForegroundColor Yellow
    if ($Script:CtgPrivateRepoAllowlist.Count -eq 0) {
        Write-Host '  (empty - -Apply will no-op)' -ForegroundColor DarkYellow
    } else {
        $Script:CtgPrivateRepoAllowlist | ForEach-Object { Write-Host "  $_" }
    }

    Write-Host ''
    Write-Host 'Sensitive candidates (recommend private for lab hardening scripts):' -ForegroundColor Cyan
    foreach ($name in $Script:CtgSensitiveRepoCandidates) {
        $r = $repos | Where-Object { $_.name -eq $name }
        if ($r) {
            $flag = if ($Script:CtgPrivateRepoAllowlist -contains $name) { '[ALLOWLISTED]' } else { '[review allowlist to Apply]' }
            Write-Host "  $name - $($r.visibility) $flag"
        } else {
            Write-Host "  $name - (not found on salvador-Data)" -ForegroundColor DarkGray
        }
    }

    Write-Host ''
    Write-Host 'Other public salvador-Data repos (informational):' -ForegroundColor Gray
    foreach ($r in $repos) {
        if ($r.visibility -ne 'PUBLIC') { continue }
        if ($Script:CtgSensitiveRepoCandidates -contains $r.name) { continue }
        $skip = $false
        foreach ($pat in $Script:CtgNeverPrivatePatterns) {
            if ($r.name -like "*$pat*") { $skip = $true; break }
        }
        if ($skip) {
            Write-Host "  $($r.name) - public (firmware/site/fork - not in privatize candidates)" -ForegroundColor DarkGray
        }
    }

    Write-Host ''
    Write-Host 'To privatize: add repo names to $Script:CtgPrivateRepoAllowlist in this script, commit, then:' -ForegroundColor Yellow
    Write-Host '  .\scripts\publish\Set-CtgPrivateRepos.ps1 -Apply' -ForegroundColor White
    exit 0
}

if ($Script:CtgPrivateRepoAllowlist.Count -eq 0) {
    Write-Host '-Apply requested but allowlist is empty - no repos changed.' -ForegroundColor Yellow
    exit 0
}

foreach ($name in $Script:CtgPrivateRepoAllowlist) {
    $r = $repos | Where-Object { $_.name -eq $name }
    if (-not $r) {
        Write-Warning "Repo $name not found - skip"
        continue
    }
    if ($r.visibility -eq 'PRIVATE') {
        Write-Host "$name already private" -ForegroundColor Green
        continue
    }
    Write-Host "Setting $name to private ..." -ForegroundColor Cyan
    gh repo edit "salvador-Data/$name" --visibility private 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to privatize $name"
    } else {
        Write-Host "$name is now private" -ForegroundColor Green
    }
}

Write-Host 'Apply complete - verify on GitHub Settings -> Repositories' -ForegroundColor Cyan
