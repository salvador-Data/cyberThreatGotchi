# One-command SEO go-live status check for hackerplanet.dev
# Usage: .\scripts\seo_go_live_checklist.ps1
# Run from repo root or any path.

$ErrorActionPreference = "Continue"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

$Domain = "https://hackerplanet.dev"
$RequiredBots = @(
    "Googlebot",
    "Bingbot",
    "DuckDuckBot",
    "Slurp",
    "Yandex",
    "Applebot",
    "Baiduspider",
    "Brave",
    "facebot"
)
$LiveUrls = @(
    "$Domain/robots.txt",
    "$Domain/sitemap.xml",
    "$Domain/hpl-hackerplanet-indexnow-key.txt",
    "$Domain/cybersecurity-philadelphia.html",
    "$Domain/kickstarter.html"
)
$LocalFiles = @(
    "website/robots.txt",
    "website/sitemap.xml",
    "website/seo/site.json",
    "website/hpl-hackerplanet-indexnow-key.txt",
    "website/hacker-planet.html",
    "docs/SEO_SEARCH_ENGINES.md",
    "docs/SEO_INDEXING_NOW.md",
    "docs/SEO_GET_ON_TOP.md",
    "docs/SEO_GOOGLE_BUSINESS_PROFILE.md",
    "scripts/ping_indexnow.py",
    "scripts/seo_verification_dns.py",
    "scripts/seo_all_engines_go_live.ps1"
)

Write-Host ""
Write-Host "SEO go-live checklist - hackerplanet.dev" -ForegroundColor Cyan
Write-Host ""

$fail = 0

Write-Host "Local files" -ForegroundColor Yellow
foreach ($rel in $LocalFiles) {
    $path = Join-Path $Root $rel
    if (Test-Path $path) {
        Write-Host "  OK   $rel" -ForegroundColor Green
    } else {
        Write-Host "  MISS $rel" -ForegroundColor Red
        $fail++
    }
}

Write-Host ""
Write-Host "Local robots.txt bot coverage" -ForegroundColor Yellow
$robotsPath = Join-Path $Root "website/robots.txt"
if (Test-Path $robotsPath) {
    $robotsLocal = Get-Content $robotsPath -Raw
    foreach ($bot in $RequiredBots) {
        if ($robotsLocal -match "User-agent:\s*$bot") {
            Write-Host "  OK   User-agent: $bot" -ForegroundColor Green
        } else {
            Write-Host "  MISS User-agent: $bot" -ForegroundColor Red
            $fail++
        }
    }
    if ($robotsLocal -match "Sitemap:\s*https://hackerplanet\.dev/sitemap\.xml") {
        Write-Host "  OK   Sitemap line" -ForegroundColor Green
    } else {
        Write-Host "  MISS Sitemap line" -ForegroundColor Red
        $fail++
    }
}

Write-Host ""
Write-Host "Live URL checks" -ForegroundColor Yellow
foreach ($url in $LiveUrls) {
    try {
        $resp = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 20
        if ($resp.StatusCode -eq 200) {
            Write-Host "  OK   $($resp.StatusCode) $url" -ForegroundColor Green
        } else {
            Write-Host "  FAIL $($resp.StatusCode) $url" -ForegroundColor Red
            $fail++
        }
    } catch {
        Write-Host "  FAIL $url - $($_.Exception.Message)" -ForegroundColor Red
        $fail++
    }
}

Write-Host ""
Write-Host "Live robots.txt bot coverage" -ForegroundColor Yellow
try {
    $robotsLive = (Invoke-WebRequest -Uri "$Domain/robots.txt" -UseBasicParsing -TimeoutSec 20).Content
    foreach ($bot in $RequiredBots) {
        if ($robotsLive -match "User-agent:\s*$bot") {
            Write-Host "  OK   live User-agent: $bot" -ForegroundColor Green
        } else {
            Write-Host "  MISS live User-agent: $bot (deploy pending?)" -ForegroundColor Red
            $fail++
        }
    }
    if ($robotsLive -match "User-agent:\s*\*" -and $robotsLive -match "Allow:\s*/") {
        Write-Host "  OK   User-agent: * Allow: /" -ForegroundColor Green
    }
} catch {
    Write-Host "  FAIL could not fetch live robots.txt" -ForegroundColor Red
    $fail++
}

Write-Host ""
Write-Host "IndexNow dry-run" -ForegroundColor Yellow
$py = Join-Path $Root ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) { $py = "python" }
$idx = & $py scripts\ping_indexnow.py --dry-run 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK   ping_indexnow.py --dry-run" -ForegroundColor Green
} else {
    Write-Host "  FAIL ping_indexnow.py --dry-run" -ForegroundColor Red
    $idx | ForEach-Object { Write-Host "       $_" -ForegroundColor Gray }
    $fail++
}

Write-Host ""
Write-Host "DNS verification helper (doc mode)" -ForegroundColor Yellow
$docOut = & $py scripts\seo_verification_dns.py --doc 2>&1
$docCode = $LASTEXITCODE
if ($docCode -eq 0) {
    Write-Host "  OK   seo_verification_dns.py --doc" -ForegroundColor Green
} else {
    Write-Host "  FAIL seo_verification_dns.py" -ForegroundColor Red
    $docOut | Select-Object -First 3 | ForEach-Object { Write-Host "       $_" -ForegroundColor Gray }
    $fail++
}

Write-Host ""
Write-Host "Live brand signals (search engines)" -ForegroundColor Yellow
try {
    $homeHtml = (Invoke-WebRequest -Uri "$Domain/" -UseBasicParsing -TimeoutSec 25).Content
    if ($homeHtml -match "<title>Hacker Planet \|") {
        Write-Host "  OK   homepage title starts with Hacker Planet |" -ForegroundColor Green
    } else {
        Write-Host "  MISS homepage title missing Hacker Planet | prefix (deploy pending?)" -ForegroundColor Red
        $fail++
    }
    if ($homeHtml -match 'property="og:site_name" content="Hacker Planet"') {
        Write-Host "  OK   og:site_name is Hacker Planet" -ForegroundColor Green
    } else {
        Write-Host "  MISS og:site_name not Hacker Planet (deploy pending?)" -ForegroundColor Red
        $fail++
    }
    if ($homeHtml -match '"name":"Hacker Planet"' -or $homeHtml -match '"name": "Hacker Planet"') {
        Write-Host "  OK   Organization/WebSite JSON-LD brand name" -ForegroundColor Green
    } else {
        Write-Host "  MISS JSON-LD missing name Hacker Planet (deploy pending?)" -ForegroundColor Red
        $fail++
    }
} catch {
    Write-Host "  FAIL could not fetch homepage for brand checks - $($_.Exception.Message)" -ForegroundColor Red
    $fail++
}

Write-Host ""
Write-Host "Andy - manual steps remaining (all engines)" -ForegroundColor Yellow
Write-Host "  - Run: .\scripts\seo_all_engines_go_live.ps1  (GSC + Bing verify + IndexNow)"
Write-Host "  - Checklist: docs/SEO_INDEXING_NOW.md  |  Ranking: docs/SEO_GET_ON_TOP.md"
Write-Host "  - GSC + Bing: verify domain, submit sitemap.xml, request indexing for / and key pages"
Write-Host "  - DuckDuckGo/Yahoo/Ecosia: covered by Bing; Apple/Brave: robots + IndexNow"
Write-Host "  - Test: site:hackerplanet.dev then hacker planet philadelphia"
Write-Host ""

if ($fail -eq 0) {
    Write-Host "PASS - all automated checks OK" -ForegroundColor Green
} else {
    Write-Host "FAIL - $fail check(s) need attention" -ForegroundColor Red
}

Write-Host ""
exit $fail
