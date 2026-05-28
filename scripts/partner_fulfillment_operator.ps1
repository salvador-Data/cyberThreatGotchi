# Hacker Planet LLC — partner fulfillment operator launcher
# Starts CTG web server + opens fulfillment dashboard; optional Stripe sync on launch.
#
# Usage:
#   .\scripts\partner_fulfillment_operator.ps1
#   .\scripts\partner_fulfillment_operator.ps1 -SyncStripe
#   .\scripts\partner_fulfillment_operator.ps1 -Token "your-operator-token"

param(
    [string]$Token = $env:CTG_OPERATOR_TOKEN,
    [switch]$SyncStripe,
    [int]$SyncHours = 72,
    [int]$Port = 8765
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

$py = Join-Path $Root ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) { $py = "python" }

if (-not $Token) {
    $Token = -join ((48..57) + (97..102) | Get-Random -Count 32 | ForEach-Object { [char]$_ })
    Write-Host "Generated CTG_OPERATOR_TOKEN for this session (save if you reuse):" -ForegroundColor Yellow
    Write-Host "  $Token" -ForegroundColor Cyan
}
$env:CTG_OPERATOR_TOKEN = $Token

Write-Host ""
Write-Host "=== Hacker Planet partner fulfillment operator ===" -ForegroundColor Cyan
Write-Host "Dashboard: http://127.0.0.1:$Port/operator/fulfillment" -ForegroundColor Green
Write-Host "Paste operator token in dashboard when prompted." -ForegroundColor Gray
Write-Host ""

if ($SyncStripe) {
    if (-not $env:CTG_STRIPE_SECRET_KEY) {
        Write-Host "CTG_STRIPE_SECRET_KEY not set — skip Stripe sync." -ForegroundColor Yellow
        Write-Host "  Set key then re-run with -SyncStripe" -ForegroundColor Gray
    } else {
        Write-Host "Syncing Stripe checkouts (last $SyncHours h)..." -ForegroundColor Gray
        & $py scripts\stripe_fulfillment_sync.py --hours $SyncHours
    }
}

Write-Host ""
Write-Host "Starting CTG web server (Ctrl+C to stop)..." -ForegroundColor Gray
& $py main.py --simulation --web --web-port $Port
