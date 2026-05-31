<#
.SYNOPSIS
  Sync Gatekeeper.TOR subtree to ctg-gatekeeper-tor split repo.

.EXAMPLE
  .\scripts\publish\Sync-CtgGatekeeperTorRepo.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\windows\CTG-Paths.ps1')
$MonoRoot = Get-CtgRepoRoot -FromPath $PSScriptRoot
$DestRepo = Join-Path (Get-CtgProgramsRoot) 'ctg-gatekeeper-tor'

function Copy-CtgTree {
    param([string] $Source, [string] $Dest)
    if (-not (Test-Path $Source)) {
        Write-Warning "Missing: $Source"
        return
    }
    Get-ChildItem -Path $Source -Recurse -File |
        Where-Object {
            $_.Name -notmatch '^\.env' -and $_.FullName -notmatch '__pycache__|\.pyc$'
        } |
        ForEach-Object {
            $rel = $_.FullName.Substring($Source.Length).TrimStart('\', '/')
            $target = Join-Path $Dest $rel
            $targetDir = Split-Path $target -Parent
            if (-not $PSCmdlet.ShouldProcess($target, 'Copy')) { return }
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            Copy-Item -Path $_.FullName -Destination $target -Force
        }
}

Write-Host '=== Sync ctg-gatekeeper-tor ===' -ForegroundColor Cyan
Write-Host "Monorepo: $MonoRoot"
Write-Host "Dest:     $DestRepo"

if (-not (Test-Path $DestRepo)) {
    Write-Warning "Clone or create: gh repo create salvador-Data/ctg-gatekeeper-tor --private"
}

$maps = @(
    @{ S = 'scripts\gatekeeper-tor'; D = 'scripts\gatekeeper-tor' }
    @{ S = 'core\gatekeeper_tor.py'; D = 'core\gatekeeper_tor.py' }
    @{ S = 'assets\gatekeeper-tor'; D = 'assets\gatekeeper-tor' }
    @{ S = 'docs\GATEKEEPER_TOR.md'; D = 'docs\GATEKEEPER_TOR.md' }
    @{ S = 'tests\test_gatekeeper_tor.py'; D = 'tests\test_gatekeeper_tor.py' }
)

foreach ($m in $maps) {
    $src = Join-Path $MonoRoot $m.S
    $dst = Join-Path $DestRepo $m.D
    if (-not (Test-Path $src)) { continue }
    if ((Get-Item $src).PSIsContainer) {
        Copy-CtgTree -Source $src -Dest $dst
    } else {
        $dir = Split-Path $dst -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        if ($PSCmdlet.ShouldProcess($dst, 'Copy file')) {
            Copy-Item -Path $src -Destination $dst -Force
        }
    }
}

$license = Join-Path $MonoRoot 'LICENSE'
if ((Test-Path $license) -and (Test-Path $DestRepo)) {
    if ($PSCmdlet.ShouldProcess((Join-Path $DestRepo 'LICENSE'), 'Copy')) {
        Copy-Item -Path $license -Destination (Join-Path $DestRepo 'LICENSE') -Force
    }
}

Write-Host 'Sync complete — commit and push ctg-gatekeeper-tor separately.' -ForegroundColor Green
