<#
Windows laptop + hackerplanet.dev automation only (Andy PC).

.SYNOPSIS
  Nightly website backup, sync, health check, and optional deploy for hackerplanet.dev.

.DESCRIPTION
  Mandatory step in ctg_nightly_4am.ps1 every night. Backs up website/ and docs/web/
  into the nightly backup tree (SSD D:, C: fallback, mirrored to OneDrive via cloud_backup),
  runs sync_website_to_docs.py, portfolio export when applicable, and GETs
  https://hackerplanet.dev for health.
  sync_website_to_docs.py (canonical website/ -> docs/web/), checks git status,
  optionally commits/pushes to trigger GitHub Pages, and GETs https://hackerplanet.dev.

.PARAMETER BackupRoot
  Nightly backup folder (SSD or C:\Users\Owner\Backups\Andy-PC-YYYY-MM-DD).

.PARAMETER DeployWebsite
  Commit and push website/docs/web changes to main (triggers pages.yml). Default: off.

.PARAMETER LogAction
  Scriptblock receiving log lines: { param($m) ... }
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $BackupRoot,
    [switch] $DeployWebsite,
    [scriptblock] $LogAction
)

$ErrorActionPreference = 'Continue'
$Repo = 'C:\Users\Owner\Projects\cyberThreatGotchi'
$SitePrimary = 'https://hackerplanet.dev/'
$SiteGithubPages = 'https://salvador-Data.github.io/cyberThreatGotchi/'

function Write-WsLog {
    param([string] $Message, [string] $Level = 'INFO')
    $line = if ($Level -eq 'INFO') { $Message } else { "[$Level] $Message" }
    if ($LogAction) {
        & $LogAction $line
    } else {
        Write-Host $line
    }
}

function Invoke-CtgWebsiteRobocopy {
    param([string] $Source, [string] $DestLabel, [string] $DestPath)
    if (-not (Test-Path $Source)) {
        Write-WsLog "Website backup skip missing: $Source" 'WARN'
        return
    }
    New-Item -ItemType Directory -Path $DestPath -Force | Out-Null
    Write-WsLog "Website backup: $Source -> $DestPath ($DestLabel)"
    & robocopy $Source $DestPath /E /R:1 /W:3 /XJ /FFT /Z /NP /NDL /NFL /XD node_modules .git |
        ForEach-Object { if ($_ -match '\S') { Write-WsLog "  robocopy: $_" } }
}

function Invoke-CtgWebsiteHealthCheck {
    param([string] $Url, [string] $Label)
    try {
        $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 45 -MaximumRedirection 5
        $tls = 'ok'
        if ($resp.BaseResponse -and $resp.BaseResponse.IsMutuallyAuthenticated) {
            $tls = 'mutual'
        }
        Write-WsLog "Health: $Label url=$Url status=$($resp.StatusCode) TLS=$tls"
        return $true
    } catch {
        $status = $null
        if ($_.Exception.Response) {
            try { $status = [int]$_.Exception.Response.StatusCode } catch { }
        }
        if ($status) {
            Write-WsLog "Health: $Label url=$Url status=$status TLS=ok (HTTP error response)" 'WARN'
        } else {
            Write-WsLog "Health: $Label url=$Url FAILED $($_.Exception.Message)" 'WARN'
        }
        return $false
    }
}

Write-WsLog '--- Website (hackerplanet.dev) ---'

if (-not (Test-Path $BackupRoot)) {
    New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
}

Invoke-CtgWebsiteRobocopy -Source (Join-Path $Repo 'website') -DestLabel 'website' -DestPath (Join-Path $BackupRoot 'website')
Invoke-CtgWebsiteRobocopy -Source (Join-Path $Repo 'docs\web') -DestLabel 'docs-web' -DestPath (Join-Path $BackupRoot 'docs-web')

Write-WsLog '--- Portfolio backup ---'
$portfolioDir = Join-Path $BackupRoot 'portfolio'
New-Item -ItemType Directory -Path $portfolioDir -Force | Out-Null
Get-ChildItem (Join-Path $Repo 'docs') -Filter 'PORTFOLIO_*.md' -ErrorAction SilentlyContinue |
    ForEach-Object {
        Copy-Item -Path $_.FullName -Destination (Join-Path $portfolioDir $_.Name) -Force
        Write-WsLog "Portfolio md: $($_.Name) -> $portfolioDir"
    }
$portfolioScript = Join-Path $Repo 'scripts\export_portfolio_html.py'
if (Test-Path $portfolioScript) {
    $portfolioOut = Join-Path $BackupRoot 'portfolio_export'
    New-Item -ItemType Directory -Path $portfolioOut -Force | Out-Null
    Write-WsLog "Portfolio export: $portfolioScript -> $portfolioOut"
    $py = (Get-Command python -ErrorAction SilentlyContinue).Source
    if (-not $py) { $py = (Get-Command py -ErrorAction SilentlyContinue).Source }
    if ($py) {
        & $py $portfolioScript $portfolioOut 2>&1 | ForEach-Object { Write-WsLog "  portfolio: $_" }
    } else {
        Write-WsLog 'Python not found — portfolio HTML export skipped' 'WARN'
    }
} else {
    Write-WsLog 'export_portfolio_html.py not found — md copies only' 'WARN'
}

$syncScript = Join-Path $Repo 'scripts\sync_website_to_docs.py'
if (Test-Path $syncScript) {
    Write-WsLog 'Website sync: python scripts/sync_website_to_docs.py (website/ -> docs/web/)'
    Push-Location $Repo
    try {
        $py = (Get-Command python -ErrorAction SilentlyContinue).Source
        if (-not $py) { $py = (Get-Command py -ErrorAction SilentlyContinue).Source }
        if ($py) {
            & $py $syncScript 2>&1 | ForEach-Object { Write-WsLog "  sync: $_" }
            if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
                Write-WsLog "sync_website_to_docs.py exit code $LASTEXITCODE" 'WARN'
            }
        } else {
            Write-WsLog 'Python not found — sync_website_to_docs.py skipped' 'WARN'
        }
    } finally {
        Pop-Location
    }
} else {
    Write-WsLog 'sync_website_to_docs.py not found — skipped' 'WARN'
}

Push-Location $Repo
try {
    $webChanges = git status --porcelain website/ docs/web/ 2>&1
    if ($webChanges) {
        $webChanges | ForEach-Object { Write-WsLog "  git status: $_" }
        if ($DeployWebsite) {
            Write-WsLog 'DeployWebsite: committing website/ and docs/web/ to main (triggers pages.yml -> gh-pages)'
            git add website/ docs/web/ 2>&1 | ForEach-Object { Write-WsLog "  git add: $_" }
            git commit -m "chore(website): nightly sync $(Get-Date -Format 'yyyy-MM-dd')" 2>&1 |
                ForEach-Object { Write-WsLog "  git commit: $_" }
            if ($LASTEXITCODE -eq 0) {
                git push origin main 2>&1 | ForEach-Object { Write-WsLog "  git push: $_" }
                if ($LASTEXITCODE -ne 0) {
                    Write-WsLog 'git push failed — deploy manual or run gh workflow dispatch' 'WARN'
                } else {
                    Write-WsLog 'DeployWebsite: push complete; GitHub Actions pages.yml should publish to gh-pages'
                }
            } else {
                Write-WsLog 'DeployWebsite: nothing to commit or commit failed' 'WARN'
            }
        } else {
            Write-WsLog 'Website git: changes detected — manual review (use -DeployWebsite to commit/push)'
        }
    } else {
        Write-WsLog 'Website git: clean (no changes in website/ or docs/web/)'
    }
} catch {
    Write-WsLog "Website git step failed: $($_.Exception.Message)" 'WARN'
} finally {
    Pop-Location
}

Write-WsLog '--- Website health checks ---'
Invoke-CtgWebsiteHealthCheck -Url $SitePrimary -Label 'hackerplanet.dev' | Out-Null
Invoke-CtgWebsiteHealthCheck -Url $SiteGithubPages -Label 'github.io mirror' | Out-Null

Write-WsLog '--- Website nightly finished ---'
