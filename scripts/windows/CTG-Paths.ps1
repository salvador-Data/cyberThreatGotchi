<#
.SYNOPSIS
  Canonical Hacker Planet LLC path helpers for CTG scripts.

.DESCRIPTION
  Resolves repo and Programs roots: canonical first, legacy Projects fallback.
  Dot-source from scripts/windows/*.ps1:

    . (Join-Path $PSScriptRoot 'CTG-Paths.ps1')
    $Repo = Get-CtgRepoRoot -FromPath $PSScriptRoot

.NOTES
  Canonical: $env:USERPROFILE\Programs\Hacker Planet LLC
  Legacy:    $env:USERPROFILE\Projects
#>
Set-StrictMode -Version Latest

function Get-CtgProgramsRoot {
    $canonical = Join-Path $env:USERPROFILE 'Programs\Hacker Planet LLC'
    if (Test-Path -LiteralPath $canonical) {
        return (Resolve-Path -LiteralPath $canonical).Path
    }
    $legacy = Join-Path $env:USERPROFILE 'Projects'
    if (Test-Path -LiteralPath $legacy) {
        return (Resolve-Path -LiteralPath $legacy).Path
    }
    return $canonical
}

function Get-CtgRepoRoot {
    param(
        [string] $FromPath
    )
    $programs = Get-CtgProgramsRoot
    $candidates = @(
        (Join-Path $programs 'cyberThreatGotchi'),
        (Join-Path $env:USERPROFILE 'Projects\cyberThreatGotchi')
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath (Join-Path $c '.git')) {
            return (Resolve-Path -LiteralPath $c).Path
        }
    }
    if ($FromPath) {
        $dir = $FromPath
        while ($dir) {
            if (Test-Path -LiteralPath (Join-Path $dir '.git')) {
                return (Resolve-Path -LiteralPath $dir).Path
            }
            $parent = Split-Path $dir -Parent
            if (-not $parent -or $parent -eq $dir) { break }
            $dir = $parent
        }
    }
    return (Join-Path $programs 'cyberThreatGotchi')
}

function Get-CtgSiblingRepo {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name
    )
    Join-Path (Split-Path (Get-CtgRepoRoot) -Parent) $Name
}
