# Hacker Planet LLC — go-live setup helper (verify + next steps)
# Usage: .\scripts\setup_go_live.ps1
# Full automation: .\scripts\go_live_all.ps1  — see docs/GO_LIVE_NOW.md

$ErrorActionPreference = "Continue"
Set-Location (Split-Path $PSScriptRoot -Parent)

$BaseUrl = "https://salvador-Data.github.io/cyberThreatGotchi/"
$Repo = "salvador-Data/cyberThreatGotchi"

Write-Host ""
Write-Host "Hacker Planet LLC — go-live setup" -ForegroundColor Cyan
Write-Host "Checklist: docs/GO_LIVE_NOW.md" -ForegroundColor Gray
Write-Host ""

# --- gh auth (optional) ---
$gh = Get-Command gh -ErrorAction SilentlyContinue
if ($gh) {
    gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "GitHub CLI: not logged in. Run: gh auth login" -ForegroundColor Yellow
    } else {
        Write-Host "GitHub CLI: authenticated" -ForegroundColor Green
        gh api "repos/$Repo/pages" 2>&1
    }
} else {
    Write-Host "GitHub CLI: not on PATH" -ForegroundColor Yellow
}

Write-Host ""

$py = Join-Path (Split-Path $PSScriptRoot -Parent) ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) { $py = "python" }
if ($py) {
    & $py scripts\verify_live_site.py
    & $py scripts\check_shop.py | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Host "check_shop.py: aligned" -ForegroundColor Green }
}

Write-Host ""
Write-Host "========== LIVE NOW ==========" -ForegroundColor Green
Write-Host "  $BaseUrl"
Write-Host ""

Write-Host "========== YOUR NEXT STEPS ==========" -ForegroundColor Yellow
Write-Host "  Done: Voice (215) 839-8738, email salvadorData@proton.me, SEO, shop catalog"
Write-Host ""
Write-Host "  Run: .\scripts\go_live_all.ps1"
Write-Host "  Then: docs/GO_LIVE_NOW.md (Cloudflare DNS + Email Routing + HTTPS)"
Write-Host ""
