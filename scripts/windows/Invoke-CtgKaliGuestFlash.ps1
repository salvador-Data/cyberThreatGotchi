# Flash latest CTG Kali scripts from vboxsf share. Authorized lab use only.
param(
    [string]$CredentialsFile = 'C:\Users\Owner\Backups\kali-vm-credentials.txt',
    [int]$SshPort = 2222,
    [switch]$WhatIf
)
$ErrorActionPreference = 'Stop'
$LogDir = 'C:\Users\Owner\Backups\logs'
$LogFile = Join-Path $LogDir 'kali-guest-flash.log'
function Write-CtgFlashLog([string]$Message) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Host $line
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}
function Get-CtgKaliCredentials {
    param([string]$Path)
    $result = @{ User = 'sal'; Password = $null; Source = 'none' }
    if (Test-Path $Path) {
        $text = Get-Content -Path $Path -Raw
        if ($text -match '(?m)^User:\s*(.+)$') { $result.User = $Matches[1].Trim() }
        if ($text -match '(?m)^Password:\s*(.+)$') { $result.Password = $Matches[1].Trim() }
        $result.Source = $Path
    }
    if (-not $result.Password) { throw "No credentials in $Path" }
    return $result
}
Write-CtgFlashLog '=== Invoke-CtgKaliGuestFlash.ps1 start ==='
$creds = Get-CtgKaliCredentials -Path $CredentialsFile
Write-CtgFlashLog ("SSH user={0} port={1}" -f $creds.User, $SshPort)
$inner = 'sudo mkdir -p /mnt/ctg; if ! mountpoint -q /mnt/ctg; then sudo mount -t vboxsf ctg-backups /mnt/ctg; fi; sudo CTG_NO_REBOOT=1 bash /mnt/ctg/RUN-KALI-LAB-NOW.sh; bash /mnt/ctg/ctg-seamless-guest.sh; bash /mnt/ctg/ctg-retbleed-check.sh'
$escapedPass = $creds.Password.Replace("'", "'\''")
$cmd = "echo '$escapedPass' | sudo -S bash -lc '$($inner.Replace("'","'\''"))'"
$sshOpts = @('-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=NUL', '-o', 'ConnectTimeout=20')
if ($WhatIf) { Write-CtgFlashLog '[WhatIf] ssh flash'; exit 0 }
& ssh -p $SshPort @sshOpts "$($creds.User)@127.0.0.1" $cmd 2>&1 | ForEach-Object { Write-CtgFlashLog $_ }
if ($LASTEXITCODE -ne 0) { Write-CtgFlashLog "SSH flash failed exit=$LASTEXITCODE"; exit 1 }
Write-CtgFlashLog '=== Guest flash complete ==='
exit 0
