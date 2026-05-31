<#
.SYNOPSIS
  DEPRECATED alias - forwards to iphone_hardening_automate.ps1.

.DESCRIPTION
  Backward-compatible wrapper. All parameters pass through to the full 21-step
  interactive orchestrator (iphone_hardening_automate.ps1).

  Use iphone_hardening_automate.ps1 directly for new sessions.

.PARAMETER OpenRunbook
  Open docs/IPHONE_RUN_NOW.md and GitHub Pages runbook.

.PARAMETER OpenGuide
  Open docs/iphone_hardening_guide.html with optional LAN serve.

.PARAMETER ServeOnLan
  With -OpenGuide: LAN http.server on port 8765.

.PARAMETER LogOnly
  Validate step URLs and run USB check - no prompts.

.PARAMETER Resume
  Continue from last incomplete step in automate log.

.EXAMPLE
  .\scripts\windows\iphone_hardening_assist.ps1 -OpenRunbook

.EXAMPLE
  .\scripts\windows\iphone_hardening_assist.ps1 -OpenGuide -ServeOnLan
#>
[CmdletBinding()]
param(
    [switch] $OpenRunbook,
    [switch] $OpenGuide,
    [switch] $ServeOnLan,
    [switch] $LogOnly,
    [switch] $Resume,
    [string] $LogDir = ''
)

$AutomateScript = Join-Path $PSScriptRoot 'iphone_hardening_automate.ps1'
if (-not (Test-Path $AutomateScript)) {
    Write-Error "iphone_hardening_automate.ps1 not found: $AutomateScript"
    exit 1
}

Write-Host 'Note: iphone_hardening_assist.ps1 forwards to iphone_hardening_automate.ps1' -ForegroundColor DarkGray

$params = @{}
if ($OpenRunbook) { $params['OpenRunbook'] = $true }
if ($OpenGuide) { $params['OpenGuide'] = $true }
if ($ServeOnLan) { $params['ServeOnLan'] = $true }
if ($LogOnly) { $params['LogOnly'] = $true }
if ($Resume) { $params['Resume'] = $true }
if ($LogDir) { $params['LogDir'] = $LogDir }

& $AutomateScript @params
exit $LASTEXITCODE
