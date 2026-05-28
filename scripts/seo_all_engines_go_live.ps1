# Interactive all-engines SEO indexing go-live for hackerplanet.dev
# Usage: .\scripts\seo_all_engines_go_live.ps1
#
# Cloudflare zone hackerplanet.dev:
#   Zone ID:    c81e69edbf957423a22392798309fc35  (override with $env:CF_ZONE_ID)
#   Account ID: a819200afa7f246ea8bdb770f634ab84
#
# Requires CF_API_TOKEN in environment for automated DNS apply (never commit or echo tokens).
# Manual fallback: python scripts/seo_verification_dns.py --doc
# Full checklist: docs/SEO_INDEXING_NOW.md · Ranking playbook: docs/SEO_GET_ON_TOP.md

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

$Domain = "hackerplanet.dev"
$Sitemap = "https://$Domain/sitemap.xml"
$Engines = [ordered]@{
    Google   = "https://search.google.com/search-console"
    Bing     = "https://www.bing.com/webmasters"
    Yandex   = "https://webmaster.yandex.com/"
    Baidu    = "https://ziyuan.baidu.com/"
    DuckDuckGoSuggest = "https://duckduckgo.com/duckduckgo-help-pages/company/suggesting-a-site/"
}
$CfDnsUrl = "https://dash.cloudflare.com/a819200afa7f246ea8bdb770f634ab84/$Domain/dns/records"

$py = Join-Path $Root ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) { $py = "python" }

function Write-Step([string]$n, [string]$msg) {
    Write-Host ""
    Write-Host "[$n] $msg" -ForegroundColor Cyan
}

function Open-Browser([string]$url, [string]$label) {
    Write-Host "  Opening $label ..." -ForegroundColor Gray
    Write-Host "  $url" -ForegroundColor DarkGray
    try {
        Start-Process $url | Out-Null
    } catch {
        Write-Host "  (Could not launch browser — open the URL manually.)" -ForegroundColor Yellow
    }
}

function Invoke-VerificationDns {
    param([string[]]$Args)
    $proc = Start-Process -FilePath $py -ArgumentList $Args -NoNewWindow -Wait -PassThru
    return $proc.ExitCode
}

Write-Host ""
Write-Host "All-engines SEO indexing go-live — $Domain" -ForegroundColor Green
Write-Host "10-min UI checklist: docs/SEO_INDEXING_NOW.md" -ForegroundColor Gray
Write-Host "Ranking playbook:    docs/SEO_GET_ON_TOP.md" -ForegroundColor Gray
Write-Host "Automated status:  .\scripts\seo_go_live_checklist.ps1" -ForegroundColor Gray

Write-Step "1" "Open webmaster dashboards (verify + submit sitemap)"
Write-Host "  REQUIRED this week: Google Search Console + Bing Webmaster Tools"
Write-Host "  OPTIONAL: Yandex Webmaster, Baidu Ziyuan (international)"
Write-Host "  DuckDuckGo / Yahoo / Ecosia / Apple / Brave: no separate verify — see docs"
foreach ($entry in $Engines.GetEnumerator()) {
    Open-Browser $entry.Value $entry.Key
    Start-Sleep -Milliseconds 800
}

Write-Step "2" "Google Search Console — DNS TXT verification"
Write-Host "  Add property -> Domain -> $Domain -> copy TXT (google-site-verification=...)"
Write-Host ""
$googleTxt = Read-Host "Paste GSC TXT value (or press Enter to skip)"
if ($googleTxt -and $googleTxt.Trim()) {
    $googleTxt = $googleTxt.Trim().Trim('"')
    if ($env:CF_API_TOKEN) {
        Write-Host "  Applying Google TXT via Cloudflare API (token from env — not logged)..." -ForegroundColor Yellow
        $rc = Invoke-VerificationDns @(
            "scripts/seo_verification_dns.py",
            "--google-txt", $googleTxt
        )
        if ($rc -eq 0) {
            Write-Host "  OK — TXT record applied. Wait 1-5 min, then click Verify in GSC." -ForegroundColor Green
        } else {
            Write-Host "  FAIL — API apply failed. Add manually at:" -ForegroundColor Red
            Write-Host "  $CfDnsUrl" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  CF_API_TOKEN not set — add TXT manually in Cloudflare:" -ForegroundColor Yellow
        Write-Host "    Type: TXT | Name: @ | Content: $googleTxt" -ForegroundColor Gray
        Write-Host "  Dashboard: $CfDnsUrl" -ForegroundColor DarkGray
    }
} else {
    Write-Host "  Skipped Google TXT." -ForegroundColor Gray
}

Write-Step "3" "Bing Webmaster Tools — DNS CNAME verification"
Write-Host "  Bing powers Bing, Yahoo (Slurp), DuckDuckGo web results, and Ecosia."
Write-Host ""
$bingHost = Read-Host "Paste Bing CNAME Host label (or Enter to skip)"
if ($bingHost -and $bingHost.Trim()) {
    $bingHost = $bingHost.Trim().TrimEnd(".")
    if ($bingHost -match "\.$Domain") {
        $bingHost = $bingHost -replace "\.$Domain\$", ""
    }
    $bingTarget = Read-Host "Paste Bing CNAME Target (e.g. verify.bing.com)"
    if ($bingTarget -and $bingTarget.Trim()) {
        $bingTarget = $bingTarget.Trim().TrimEnd(".")
        if ($env:CF_API_TOKEN) {
            Write-Host "  Applying Bing CNAME via Cloudflare API..." -ForegroundColor Yellow
            $rc = Invoke-VerificationDns @(
                "scripts/seo_verification_dns.py",
                "--bing-cname", $bingHost, $bingTarget
            )
            if ($rc -eq 0) {
                Write-Host "  OK — CNAME applied (DNS only). Wait 1-5 min, then Verify in Bing." -ForegroundColor Green
            } else {
                Write-Host "  FAIL — add CNAME manually (grey cloud / DNS only)." -ForegroundColor Red
            }
        } else {
            Write-Host "  CF_API_TOKEN not set — add CNAME manually (DNS only / grey cloud)." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "  Skipped Bing CNAME." -ForegroundColor Gray
}

Write-Step "4" "Submit sitemap to Google + Bing (same URL)"
Write-Host "  GSC:  Sitemaps -> Add -> sitemap.xml -> Submit"
Write-Host "  Bing: Sitemaps -> Submit -> $Sitemap"
Write-Host ""
Write-Host "  Sitemap URL: $Sitemap" -ForegroundColor Green

Write-Step "5" "Request indexing — priority URLs (GSC URL Inspection)"
Write-Host "    https://$Domain/"
Write-Host "    https://$Domain/hacker-planet.html"
Write-Host "    https://$Domain/cybersecurity-philadelphia.html"
Write-Host "    https://$Domain/kickstarter.html"

Write-Step "6" "Engines without separate dashboards"
Write-Host "  DuckDuckGo: Bing index + DuckDuckBot in robots.txt; optional suggest URL after Bing indexes"
Write-Host "  Yahoo:      Slurp allowed; covered by Bing verification"
Write-Host "  Apple:      Applebot allowed; no Apple Search Console"
Write-Host "  Brave:      Brave crawler + IndexNow (step 7)"
Write-Host "  Yandex:     Optional webmaster.yandex.com verify"
Write-Host "  Baidu:      Optional ziyuan.baidu.com verify (China market)"

Write-Step "7" "Ping IndexNow (Bing, Yandex, and partners — all sitemap URLs)"
Write-Host "  Running: python scripts/ping_indexnow.py"
$idx = & $py scripts\ping_indexnow.py 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  $idx" -ForegroundColor Green
} else {
    Write-Host "  IndexNow failed — run manually after deploy." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done. Without GSC/Bing verification, site:hackerplanet.dev stays EMPTY." -ForegroundColor Yellow
Write-Host "Test in 24-72h after verify:" -ForegroundColor Green
Write-Host "  site:$Domain"
Write-Host "  hacker planet philadelphia"
Write-Host ""
Write-Host "Re-run: .\scripts\seo_go_live_checklist.ps1" -ForegroundColor Gray
Write-Host ""
