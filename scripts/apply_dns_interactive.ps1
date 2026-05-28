# Apply Cloudflare DNS via API without pasting the token on the command line.
# Usage: .\scripts\apply_dns_interactive.ps1
# Run from repo root or any path; script cd's to project root.

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

$CfAccountId = "a819200afa7f246ea8bdb770f634ab84"
$Domain = "hackerplanet.dev"
$DnsDashboard = "https://dash.cloudflare.com/$CfAccountId/$Domain/dns/records"

Write-Host ""
Write-Host "Cloudflare DNS apply (GitHub Pages + Email Routing)" -ForegroundColor Cyan
Write-Host "Do not paste your API token in chat, email, or screenshots." -ForegroundColor Yellow
Write-Host "If the token was exposed, revoke it at:" -ForegroundColor Yellow
Write-Host "  https://dash.cloudflare.com/profile/api-tokens" -ForegroundColor Gray
Write-Host ""

$secure = Read-Host "Paste Cloudflare API token (input hidden):" -AsSecureString
if (-not $secure -or $secure.Length -eq 0) {
    Write-Host "No token entered. Exiting." -ForegroundColor Red
    exit 1
}

$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
} finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
}
$secure.Dispose()
$plain = $plain.Trim()
if (-not $plain) {
    Write-Host "Empty token. Exiting." -ForegroundColor Red
    exit 1
}

$env:CF_API_TOKEN = $plain
$plain = $null

$py = Join-Path $Root ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) {
    Write-Host "Missing venv Python: $py" -ForegroundColor Red
    Write-Host "Create venv and install deps, then re-run." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Running cloudflare_apply_dns.py --all ..." -ForegroundColor Gray
$out = & $py scripts\cloudflare_apply_dns.py --all 2>&1
$code = $LASTEXITCODE
$out | ForEach-Object { Write-Host $_ }

function Show-ManualDns9109 {
    Write-Host ""
    Write-Host "Cloudflare returned error 9109 (or exit code 9109)." -ForegroundColor Yellow
    Write-Host "Apply DNS manually:" -ForegroundColor Yellow
    Write-Host "  Dashboard: $DnsDashboard" -ForegroundColor Cyan
    Write-Host "  1. DNS -> Import and Export -> Import" -ForegroundColor Gray
    Write-Host "     - scripts\cloudflare\dns-github-pages.bind" -ForegroundColor Gray
    Write-Host "     - scripts\cloudflare\dns-email-routing.bind (email)" -ForegroundColor Gray
    Write-Host "  2. For every GitHub A and www CNAME: orange cloud -> grey (DNS only)" -ForegroundColor Gray
    Write-Host "  3. Re-run this script after zone is Active, or fix token permissions." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Full checklist: docs\GO_LIVE_NOW.md" -ForegroundColor Cyan
}

$text = ($out | Out-String)
if ($code -eq 9109 -or $text -match '\b9109\b') {
    Show-ManualDns9109
}

Write-Host ""
if ($code -eq 0) {
    Write-Host "SUCCESS: Cloudflare DNS apply finished." -ForegroundColor Green
    Write-Host "Next: grey-cloud any remaining orange GitHub records, then github_pages_https.py and Email Routing." -ForegroundColor Gray
} else {
    Write-Host "FAILED: Cloudflare DNS apply exited with code $code." -ForegroundColor Red
    if ($code -ne 9109 -and $text -notmatch '\b9109\b') {
        Write-Host "Check token (Zone.DNS Edit + Zone.Read for $Domain) and zone status Active." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Reminder: never paste API tokens in chat; revoke at Cloudflare if leaked." -ForegroundColor Yellow
Write-Host ""

exit $code
