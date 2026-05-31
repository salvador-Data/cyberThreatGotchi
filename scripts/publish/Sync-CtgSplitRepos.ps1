<#
.SYNOPSIS
  Sync cyberThreatGotchi monorepo subtrees to ctg-kali-lab and ctg-windows-soc split repos.

.DESCRIPTION
  Copies scripts and docs from the parent monorepo into sibling clone directories.
  No secrets, .env, Backups/, or lab-wifi.conf/lab-targets.conf are copied.
  Run from cyberThreatGotchi root; commit and push each split repo separately.

.PARAMETER WhatIf
  List copy actions without writing files.

.EXAMPLE
  .\scripts\publish\Sync-CtgSplitRepos.ps1

.EXAMPLE
  .\scripts\publish\Sync-CtgSplitRepos.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'
$MonoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Projects = Split-Path $MonoRoot -Parent
$KaliRepo = Join-Path $Projects 'ctg-kali-lab'
$WinRepo = Join-Path $Projects 'ctg-windows-soc'

function Copy-CtgTree {
    param(
        [string] $Source,
        [string] $Dest,
        [string[]] $ExcludeNames = @()
    )
    if (-not (Test-Path $Source)) {
        Write-Warning "Source missing: $Source"
        return
    }
    if (-not (Test-Path $Dest)) {
        if ($PSCmdlet.ShouldProcess($Dest, 'Create directory')) {
            New-Item -ItemType Directory -Path $Dest -Force | Out-Null
        }
    }
    Get-ChildItem -Path $Source -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $leaf = $_.Name
            $rel = $_.FullName.Substring($Source.Length).TrimStart('\', '/')
            if ($leaf -match '^\.env' -or $leaf -eq 'lab-wifi.conf' -or $leaf -eq 'lab-targets.conf') { return $false }
            if ($rel -match '__pycache__|\.pyc$') { return $false }
            if ($rel -match '\\Backups\\|/Backups/') { return $false }
            foreach ($ex in $ExcludeNames) {
                if ($leaf -eq $ex) { return $false }
            }
            return $true
        } |
        ForEach-Object {
            $rel = $_.FullName.Substring($Source.Length).TrimStart('\', '/')
            $target = Join-Path $Dest $rel
            $targetDir = Split-Path $target -Parent
            if (-not $PSCmdlet.ShouldProcess($target, 'Copy file')) {
                return
            }
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            Copy-Item -Path $_.FullName -Destination $target -Force
        }
}

Write-Host "=== CTG split repo sync ===" -ForegroundColor Cyan
Write-Host "Monorepo: $MonoRoot"

if (-not (Test-Path -LiteralPath $KaliRepo)) {
    Write-Warning "ctg-kali-lab not found at $KaliRepo - clone first"
} else {
    Write-Host "Syncing Kali lab -> $KaliRepo"
    Copy-CtgTree -Source (Join-Path $MonoRoot 'scripts\kali') -Dest (Join-Path $KaliRepo 'scripts\kali')
    foreach ($doc in @(
            'CTG_LAB_AUTORUN.md', 'CTG_LAB_PLAYGROUND.md', 'KALI_WIFI_ETH_PROMISC.md',
            'KALI_IDS_IPS_CLAMAV.md', 'KALI_SIEM_STACK.md', 'KALI_LAB_ARCHITECTURE.md',
            'KALI_RETBLEED.md', 'KALI_VIRTUALBOX_SEAMLESS.md', 'DEFENSE_DDOS_ROGUE_WIFI.md',
            'OPNSENSE_LAB_DNS.md', 'PASSWORD_HARDENING.md'
        )) {
        $src = Join-Path $MonoRoot "docs\$doc"
        $dst = Join-Path $KaliRepo "docs\$doc"
        if (Test-Path $src) {
            if ($PSCmdlet.ShouldProcess($dst, 'Copy doc')) {
                $dstDir = Split-Path $dst -Parent
                if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
                Copy-Item -Path $src -Destination $dst -Force
            }
        }
    }
}

if (-not (Test-Path -LiteralPath $WinRepo)) {
    Write-Warning "ctg-windows-soc not found at $WinRepo - clone first"
} else {
    Write-Host "Syncing Windows SOC -> $WinRepo"
    Copy-CtgTree -Source (Join-Path $MonoRoot 'scripts\windows') -Dest (Join-Path $WinRepo 'scripts\windows') `
        -ExcludeNames @('ctg-soc-run-log-elevated.txt')
    Copy-CtgTree -Source (Join-Path $MonoRoot 'scripts\wireshark_ids') -Dest (Join-Path $WinRepo 'scripts\wireshark_ids')
    foreach ($doc in @(
            'SECURITY_HARDENING.md', 'IPHONE_HARDENING.md', 'IPHONE_RUN_NOW.md',
            'IPHONE_USB_HARDENING.md', 'DEFENSE_DDOS_ROGUE_WIFI.md', 'PORTFOLIO_SYSTEM_HARDENING.md',
            'PORTFOLIO_AUTOMATION_SOC.md', 'OPNSENSE_LAB_DNS.md', 'PASSWORD_HARDENING.md',
            'SECRET_VAULT.md', 'KALI_VIRTUALBOX_SEAMLESS.md', 'WIRESHARK_IDS_SMS.md'
        )) {
        $src = Join-Path $MonoRoot "docs\$doc"
        $dst = Join-Path $WinRepo "docs\$doc"
        if (Test-Path $src) {
            if ($PSCmdlet.ShouldProcess($dst, 'Copy doc')) {
                $dstDir = Split-Path $dst -Parent
                if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
                Copy-Item -Path $src -Destination $dst -Force
            }
        }
    }
}

Write-Host "Done. Next: cd each split repo, git add -A, commit, push origin main" -ForegroundColor Green
