<#
.SYNOPSIS
  Start CTG local event bus (HTTP + file inbox on Backups share).

.DESCRIPTION
  Runs core.ctg_event_bus serve on 127.0.0.1:8766 by default.
  Events persist under %USERPROFILE%\Backups\ctg-events\ and dedupe state in
  Backups\.vault\ctg-event-state.json (gitignored).

.PARAMETER Port
  Local HTTP port (127.0.0.1 only).

.PARAMETER DiagnoseOnly
  Print paths and exit without starting server.

.EXAMPLE
  .\scripts\windows\Start-CtgEventBus.ps1
#>
[CmdletBinding()]
param(
    [int] $Port = 8766,
    [switch] $DiagnoseOnly
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'CTG-WiresharkCommon.ps1')

$repo = Get-CtgRepoRoot -FromPath $PSScriptRoot
$backups = Get-CtgBackupsRoot
$eventsDir = Join-Path $backups 'ctg-events'
$statePath = Join-Path $backups '.vault\ctg-event-state.json'

Write-Host 'CTG event bus - authorized defensive lab use only' -ForegroundColor Cyan
Write-Host "  Repo:       $repo"
Write-Host "  Events dir: $eventsDir"
Write-Host "  State:      $statePath"
Write-Host ('  HTTP:       http://127.0.0.1:' + $Port + '/events')

if ($DiagnoseOnly) {
    exit 0
}

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command python3 -ErrorAction SilentlyContinue
}
if (-not $python) {
    throw 'Python not found on PATH.'
}

Push-Location $repo
try {
    & $python.Source -m core.ctg_event_bus serve --host 127.0.0.1 --port $Port
} finally {
    Pop-Location
}
