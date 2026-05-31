# CTG one-shot SOC run (elevated). Logs to Desktop + D:\Backups if writable.
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'CTG-Paths.ps1')
$Repo = Get-CtgRepoRoot -FromPath $PSScriptRoot
$Win = Join-Path $Repo 'scripts\windows'
. (Join-Path $Win 'CTG-AdminCommon.ps1')
$script:CtgIsAdmin = Test-CtgIsAdmin
$LogLocal = Join-Path $Win 'ctg-soc-run-log-elevated.txt'
$LogDesktop = Join-Path ([Environment]::GetFolderPath('Desktop')) 'ctg-soc-run-log.txt'
$LogSsd = 'D:\Backups\ctg-soc-run-log.txt'
function Write-Log([string]$m) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"
    Add-Content -Path $LogLocal -Value $line -Encoding utf8 -ErrorAction SilentlyContinue
    foreach ($attempt in 1..3) {
        try {
            Add-Content -Path $LogDesktop -Value $line -Encoding utf8 -ErrorAction Stop
            break
        } catch {
            if ($attempt -eq 3) {
                Write-Warning "Desktop log locked (OneDrive?): $($_.Exception.Message)"
            } else {
                Start-Sleep -Milliseconds 250
            }
        }
    }
    Write-Host $line
}
Write-Log '=== Elevated CTG SOC run started ==='
Write-Log ('Running as Admin: ' + $script:CtgIsAdmin)
Write-Log "Computer=$env:COMPUTERNAME User=$env:USERNAME Running as Admin: $script:CtgIsAdmin"
. (Join-Path $Win 'Preserve-DuckDuckGoVpn.ps1')
Invoke-CtgPreserveDuckDuckGoVpn -LogAction { param($m) Write-Log $m }
try {
    Write-Log '--- Restore point (Checkpoint-Computer) ---'
    Checkpoint-Computer -Description 'CTG-Windows-Hardening' -RestorePointType MODIFY_SETTINGS
    Write-Log 'Restore point: OK'
} catch {
    Write-Log "Restore point: FAILED - $($_.Exception.Message)"
}
Write-Log '--- Selective SSD backup ---'
& (Join-Path $Win 'selective_ssd_backup.ps1') *>&1 | ForEach-Object { Write-Log $_ }
if (Test-Path (Join-Path $Win 'cloud_backup.ps1')) {
    Write-Log '--- cloud_backup.ps1 ---'
    & (Join-Path $Win 'cloud_backup.ps1') *>&1 | ForEach-Object { Write-Log $_ }
}
Write-Log '--- Sysmon install ---'
& (Join-Path $Win 'harden_windows.ps1') -InstallSysmon -SkipRestorePoint *>&1 | ForEach-Object { Write-Log $_ }
if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) { $sysmonOk = $true } else { $sysmonOk = $false }
Write-Log "Sysmon phase last exit: $LASTEXITCODE"
Write-Log '--- Harden-Windows-Security (audit only) ---'
& (Join-Path $Win 'harden_windows.ps1') -RunHardenWindowsSecurity -HardenWindowsSecurityAuditOnly -SkipRestorePoint *>&1 | ForEach-Object { Write-Log $_ }
Write-Log '--- Defender ASR audit ---'
& (Join-Path $Win 'harden_windows.ps1') -DefenderASRAudit -SkipRestorePoint *>&1 | ForEach-Object { Write-Log $_ }
if ($env:CTG_WAZUH_MANAGER -or $env:WAZUH_MANAGER) {
    Write-Log '--- Wazuh setup (env set) ---'
    & (Join-Path $Win 'harden_windows.ps1') -SetupWazuhAgent -SkipRestorePoint *>&1 | ForEach-Object { Write-Log $_ }
} else {
    Write-Log 'Wazuh: SKIPPED (CTG_WAZUH_MANAGER / WAZUH_MANAGER not set)'
}
Invoke-CtgPreserveDuckDuckGoVpn -LogAction { param($m) Write-Log $m }
Write-Log '=== Elevated CTG SOC run finished ==='
try { Copy-Item $LogLocal $LogDesktop -Force -ErrorAction Stop } catch { Write-Log "Desktop log mirror failed: $($_.Exception.Message)" }
if (Test-Path 'D:\') {
    try {
        New-Item -ItemType Directory -Path (Split-Path $LogSsd -Parent) -Force | Out-Null
        Copy-Item $LogLocal $LogSsd -Force
        Write-Log "Copied log to $LogSsd"
    } catch {
        Write-Log "SSD log copy failed: $($_.Exception.Message)"
    }
} else {
    Write-Log 'D: missing — skip SSD log copy'
}
