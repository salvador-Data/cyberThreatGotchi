# Hacker Planet LLC — go-live setup helper (verify + next steps)
# Usage: .\scripts\setup_go_live.ps1

$ErrorActionPreference = "Continue"
Set-Location (Split-Path $PSScriptRoot -Parent)

$BaseUrl = "https://salvador-Data.github.io/cyberThreatGotchi/"
$Repo = "salvador-Data/cyberThreatGotchi"

Write-Host ""
Write-Host "Hacker Planet LLC — go-live setup" -ForegroundColor Cyan
Write-Host "Checklist: docs/SETUP_CHECKLIST.md" -ForegroundColor Gray
Write-Host ""

# --- gh auth (optional) ---
$gh = Get-Command gh -ErrorAction SilentlyContinue
if ($gh) {
    $authOk = $true
    gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $authOk = $false
        Write-Host "GitHub CLI: not logged in. Run: gh auth login" -ForegroundColor Yellow
    } else {
        Write-Host "GitHub CLI: authenticated" -ForegroundColor Green
        Write-Host "Latest pages.yml runs:" -ForegroundColor Gray
        gh run list --workflow=pages.yml -L 3 -R $Repo 2>&1
        Write-Host ""
        Write-Host "Pages API:" -ForegroundColor Gray
        gh api "repos/$Repo/pages" 2>&1
    }
} else {
    Write-Host "GitHub CLI: not on PATH (install: winget install GitHub.cli)" -ForegroundColor Yellow
    Write-Host "  Manual: https://github.com/$Repo/settings/pages" -ForegroundColor Gray
}

Write-Host ""

# --- Python checks ---
$py = Join-Path (Split-Path $PSScriptRoot -Parent) ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) {
    $pyCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pyCmd) { $py = "python" } else { $py = $null }
}
if ($py) {
    & $py scripts\verify_live_site.py
    if ($LASTEXITCODE -ne 0) { Write-Host "Live site check failed" -ForegroundColor Red }
    & $py scripts\check_shop.py | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "check_shop.py: aligned" -ForegroundColor Green
    } else {
        Write-Host "check_shop.py: FAILED" -ForegroundColor Red
    }
} else {
    Write-Host "Python not found — skip verify_live_site.py" -ForegroundColor Yellow
    try {
        $r = Invoke-WebRequest -Uri $BaseUrl -Method Head -UseBasicParsing -TimeoutSec 30
        Write-Host "Home URL: $($r.StatusCode) $BaseUrl" -ForegroundColor Green
    } catch {
        Write-Host "Home URL check failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========== LIVE NOW ==========" -ForegroundColor Green
Write-Host "  $BaseUrl"
Write-Host "  ${BaseUrl}shop.html"
Write-Host "  ${BaseUrl}contact.html"
Write-Host ""

Write-Host "========== YOUR NEXT 3 STEPS (manual) ==========" -ForegroundColor Yellow
Write-Host "  1. Google Voice — voice.google.com — 215 area, forward to cell"
Write-Host "     Then update website/contact.html with tel: link (see docs/CONTACT_AND_PHONE.md)"
Write-Host ""
Write-Host "  2. Domain — register hackerplanet.dev at Cloudflare (~`$10/yr)"
Write-Host "     Add website/CNAME, DNS per docs/HOSTING_OPTIONS.md, GitHub Pages custom domain"
Write-Host ""
Write-Host "  3. Payments (when ready) — Stripe Payment Links, demoMode false"
Write-Host "     See docs/SHOP_GO_LIVE.md and: .\.venv\Scripts\python scripts\check_payments.py"
Write-Host ""
Write-Host "Full checklist: docs\SETUP_CHECKLIST.md" -ForegroundColor Cyan
Write-Host ""
