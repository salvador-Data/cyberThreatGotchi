# Enable GitHub Pages from PowerShell (run once as salvador-Data)
# Usage: .\scripts\enable_pages.ps1

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "Hacker Planet LLC — enable GitHub Pages" -ForegroundColor Cyan
Write-Host ""

$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    Write-Host "Install GitHub CLI: winget install GitHub.cli" -ForegroundColor Yellow
    exit 1
}

$auth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Log in to GitHub (browser will open)..." -ForegroundColor Yellow
    gh auth login -h github.com -p https -w
}

Write-Host "Enabling Pages from gh-pages branch..." -ForegroundColor Green
python scripts\enable_github_pages.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Waiting 45s for propagation..." -ForegroundColor Gray
Start-Sleep -Seconds 45

$url = "https://salvador-Data.github.io/cyberThreatGotchi/"
try {
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30
    Write-Host "SUCCESS: $url returned $($r.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "Still starting up or needs manual Settings save:" -ForegroundColor Yellow
    Write-Host "  https://github.com/salvador-Data/cyberThreatGotchi/settings/pages"
    Write-Host "  Branch: gh-pages  Folder: / (root)"
}

Write-Host ""
Write-Host "Shop: https://salvador-Data.github.io/cyberThreatGotchi/shop.html"
