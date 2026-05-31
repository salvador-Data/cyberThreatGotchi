# Background watcher - refresh Kali login greeter size after logout (VirtualBox lab).
# Started by Start-KaliSeamless.ps1; polls LoggedInUsers and CTG_GREETER_REFRESH on share.
# Authorized defensive lab use only - Hacker Planet LLC.
param(
    [string]$VmName = 'kali',
    [string[]]$VmNameCandidates = @('kali', 'Kali-Lab', 'Kali', 'kali-linux'),
    [double]$LoginWindowScale = 0,
    [string]$BackupRoot = 'C:\Users\Owner\Backups',
    [int]$PollSec = 3
)

$ErrorActionPreference = 'Continue'
$watchLoginScale = $LoginWindowScale
. (Join-Path $PSScriptRoot 'Start-KaliSeamless.ps1')
$LoginWindowScale = $watchLoginScale

$VBoxManage = Get-CtgVBoxManagePath
if (-not $VBoxManage) { exit 2 }

$Name = $VmName
if (-not $Name) {
    $Name = Resolve-CtgKaliVmName -VBoxManage $VBoxManage -Candidates $VmNameCandidates
}
if (-not $Name) { exit 2 }

$triggerPath = Join-Path $BackupRoot 'CTG_GREETER_REFRESH'
$lastLoggedIn = -1
$lastTriggerStamp = $null

Write-CtgSeamlessLog "Watch-CtgGreeterLogout: monitoring $Name (poll ${PollSec}s; share trigger $triggerPath)"

while ($true) {
    $state = Get-CtgVmState -Name $Name -VBoxManage $VBoxManage
    if ($state -ne 'running') {
        Write-CtgSeamlessLog "Watch-CtgGreeterLogout: VM state $state - exiting watcher"
        break
    }

    $loggedIn = Get-CtgGuestLoggedInUserCount -Name $Name -VBoxManage $VBoxManage

    if ($lastLoggedIn -gt 0 -and $loggedIn -eq 0) {
        Invoke-CtgLoginGreeterRefresh -Name $Name -VBoxManage $VBoxManage -LoginScale $LoginWindowScale -Reason 'LoggedInUsers 0 (logout)' | Out-Null
    } elseif ($lastLoggedIn -eq -1 -and $loggedIn -eq 0) {
        Save-CtgGreeterSizeHint -Name $Name -VBoxManage $VBoxManage
    }

    if (Test-Path $triggerPath) {
        $stamp = (Get-Item $triggerPath).LastWriteTimeUtc.Ticks
        if ($stamp -ne $lastTriggerStamp) {
            $lastTriggerStamp = $stamp
            Invoke-CtgLoginGreeterRefresh -Name $Name -VBoxManage $VBoxManage -LoginScale $LoginWindowScale -Reason 'CTG_GREETER_REFRESH' | Out-Null
            Remove-Item $triggerPath -Force -ErrorAction SilentlyContinue
        }
    }

    $lastLoggedIn = $loggedIn
    Start-Sleep -Seconds $PollSec
}
