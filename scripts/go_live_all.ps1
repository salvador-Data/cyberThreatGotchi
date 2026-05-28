# Hacker Planet LLC - run every automated go-live check + optional Cloudflare/GitHub steps
# Usage: .\scripts\go_live_all.ps1
# Optional: $env:CF_API_TOKEN = "..." then re-run for DNS apply

$ErrorActionPreference = "Continue"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

$CfAccountId = "a819200afa7f246ea8bdb770f634ab84"
$CfZoneId = "c81e69edbf957423a22392798309fc35"
$Domain = "hackerplanet.dev"
$Repo = "salvador-Data/cyberThreatGotchi"

Write-Host ""
Write-Host "=== Hacker Planet go-live (automated) ===" -ForegroundColor Cyan
Write-Host "Account ID: $CfAccountId"
Write-Host "Zone ID:    $CfZoneId"
Write-Host ""

$py = Join-Path $Root ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) { $py = "python" }

Write-Host "--- Tests and shop ---" -ForegroundColor Gray
& $py -m pytest tests/test_seo.py tests/test_website.py -q
& $py scripts\check_shop.py
& $py scripts\check_payments.py

Write-Host ""
Write-Host "--- Live site ---" -ForegroundColor Gray
& $py scripts\verify_live_site.py

if (Get-Command gh -ErrorAction SilentlyContinue) {
    Write-Host ""
    Write-Host "--- GitHub Pages ---" -ForegroundColor Gray
    gh api "repos/$Repo/pages" 2>&1
    & $py scripts\github_pages_https.py 2>&1
}

if ($env:CF_API_TOKEN) {
    Write-Host ""
    Write-Host "--- Cloudflare DNS (API token set) ---" -ForegroundColor Gray
    & $py scripts\cloudflare_apply_dns.py --all
} else {
    Write-Host ""
    Write-Host "CF_API_TOKEN not set - skip Cloudflare DNS API." -ForegroundColor Yellow
    Write-Host "Create token: https://dash.cloudflare.com/profile/api-tokens" -ForegroundColor Gray
    Write-Host "  Template: Edit zone DNS | Zone: $Domain | Permissions: Zone.DNS Edit, Zone.Read" -ForegroundColor Gray
    Write-Host '  Then: $env:CF_API_TOKEN = "your_token"; .\scripts\go_live_all.ps1' -ForegroundColor Gray
    Write-Host ""
    Write-Host "--- Cloudflare DNS (manual steps) ---" -ForegroundColor Yellow
    & $py scripts\cloudflare_apply_dns.py --all
}

Write-Host ""
Write-Host "=== Manual (browser) if zone still pending ===" -ForegroundColor Yellow
Write-Host "  1. Register domain: https://domains.cloudflare.com/"
Write-Host "  2. DNS records:    https://dash.cloudflare.com/$CfAccountId/$Domain/dns/records"
Write-Host "     Import file:    scripts/cloudflare/dns-github-pages.bind"
Write-Host "     Turn ALL GitHub records to grey cloud (DNS only)"
Write-Host "  3. Email DNS:      Import scripts/cloudflare/dns-email-routing.bind"
Write-Host "     MX route1/2/3, SPF, _dmarc; DKIM via Email Routing Get started"
Write-Host "  4. Email Routing:  https://dash.cloudflare.com/$CfAccountId/$Domain/email/routing"
Write-Host "     hello@ -> salvadorData@proton.me"
Write-Host "  5. GitHub HTTPS:   https://github.com/$Repo/settings/pages"
Write-Host "  6. Search Console: https://search.google.com/search-console"
Write-Host "     Add $Domain + sitemap https://$Domain/sitemap.xml"
Write-Host ""
Write-Host "Full guide: docs/GO_LIVE_NOW.md" -ForegroundColor Cyan
Write-Host ""
