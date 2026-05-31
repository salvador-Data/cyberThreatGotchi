# Stage entire scripts/kali tree to C:\Users\Owner\Backups for VirtualBox ctg-backups share.
# Authorized defensive lab use only â€” Hacker Planet LLC.
param(
    [string]$BackupRoot = 'C:\Users\Owner\Backups',
    [string]$RepoRoot = '',
    [switch]$WhatIf
)

if (-not $RepoRoot) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
$KaliSrc = Join-Path $RepoRoot 'scripts\kali'
if (-not (Test-Path $KaliSrc)) {
    throw "Kali scripts source not found: $KaliSrc"
}
if (-not (Test-Path $BackupRoot)) {
    if ($WhatIf) {
        Write-Host "[WhatIf] Would create $BackupRoot"
    } else {
        New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
    }
}

function Write-CtgStageLog([string]$Message) {
    Write-Host $Message
    $logDir = Join-Path $BackupRoot 'logs'
    if (-not $WhatIf) {
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        Add-Content -Path (Join-Path $logDir 'stage-kali-lab.log') -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message" -Encoding UTF8
    }
}

# Shell scripts must be LF for the Kali guest. Windows checkout (core.autocrlf=true)
# yields CRLF working-tree files; a CRLF .sh can fail in bash ($'\r' syntax errors),
# which would break ctg-seamless-guest.sh and the boot autopatch in the VM.
function Copy-CtgGuestFile {
    param([string]$Source, [string]$Dest)
    $ext = [IO.Path]::GetExtension($Source).ToLowerInvariant()
    if ($ext -eq '.sh') {
        $text = [IO.File]::ReadAllText($Source)
        $lf = $text -replace "`r`n", "`n" -replace "`r", "`n"
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [IO.File]::WriteAllText($Dest, $lf, $utf8NoBom)
    } else {
        Copy-Item -Path $Source -Destination $Dest -Force
    }
}

Write-CtgStageLog "Staging scripts/kali -> $BackupRoot"

$topFiles = Get-ChildItem -Path $KaliSrc -File -ErrorAction SilentlyContinue
foreach ($f in $topFiles) {
    $dest = Join-Path $BackupRoot $f.Name
    if ($WhatIf) {
        Write-CtgStageLog "[WhatIf] $($f.FullName) -> $dest"
    } else {
        Copy-CtgGuestFile -Source $f.FullName -Dest $dest
        Write-CtgStageLog "Staged: $dest"
    }
}

$subDirs = @('tor-http-scrambler', 'ansible')
foreach ($dirName in $subDirs) {
    $srcDir = Join-Path $KaliSrc $dirName
    if (-not (Test-Path $srcDir)) { continue }
    $destDir = Join-Path $BackupRoot $dirName
    if ($WhatIf) {
        Write-CtgStageLog "[WhatIf] Copy tree $srcDir -> $destDir"
    } else {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        Copy-Item -Path (Join-Path $srcDir '*') -Destination $destDir -Recurse -Force
        Get-ChildItem -Path $destDir -Recurse -File -Filter '*.sh' -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-CtgGuestFile -Source $_.FullName -Dest $_.FullName
        }
        Write-CtgStageLog "Staged tree: $destDir"
    }
}

$runScript = Join-Path $KaliSrc 'RUN-KALI-LAB-NOW.sh'
if (Test-Path $runScript) {
    $runDest = Join-Path $BackupRoot 'RUN-KALI-LAB-NOW.sh'
    if (-not $WhatIf) {
        Copy-CtgGuestFile -Source $runScript -Dest $runDest
    }
    Write-CtgStageLog "RUN script: $runDest"
}

$siemLogDir = Join-Path $BackupRoot 'logs\siem'
if (-not $WhatIf) {
    New-Item -ItemType Directory -Path $siemLogDir -Force | Out-Null
}
Write-CtgStageLog "SIEM log dir: $siemLogDir"

$docs = @(
    @{ Src = 'docs\KALI_SIEM_STACK.md'; Dest = 'KALI_SIEM_STACK.md' },
    @{ Src = 'docs\KALI_IDS_IPS_CLAMAV.md'; Dest = 'KALI_IDS_IPS_CLAMAV.md' },
    @{ Src = 'docs\CTG_SHIELD_SIEM_PLAYBOOK.md'; Dest = 'CTG_SHIELD_SIEM_PLAYBOOK.md' },
    @{ Src = 'docs\CTG_LAB_PLAYGROUND.md'; Dest = 'CTG_LAB_PLAYGROUND.md' },
    @{ Src = 'docs\CTG_LAB_AUTORUN.md'; Dest = 'CTG_LAB_AUTORUN.md' },
    @{ Src = 'docs\KALI_RETBLEED.md'; Dest = 'KALI_RETBLEED.md' },
    @{ Src = 'docs\KALI_RETBLEED_SPECTRE.md'; Dest = 'KALI_RETBLEED_SPECTRE.md' },
    @{ Src = 'docs\PASSWORD_HARDENING.md'; Dest = 'PASSWORD_HARDENING.md' },
    @{ Src = 'docs\KALI_DISPLAY_SCALING.md'; Dest = 'KALI_DISPLAY_SCALING.md' },
    @{ Src = 'docs\KALI_SEAMLESS_MODE.md'; Dest = 'KALI_SEAMLESS_MODE.md' }
)
foreach ($d in $docs) {
    $srcPath = Join-Path $RepoRoot $d.Src
    if (-not (Test-Path $srcPath)) { continue }
    $destPath = Join-Path $BackupRoot $d.Dest
    if (-not $WhatIf) {
        Copy-Item -Path $srcPath -Destination $destPath -Force
    }
    Write-CtgStageLog "Staged doc: $destPath"
}

$playgroundPs1 = Join-Path $PSScriptRoot 'CTG-Lab-Playground.ps1'
if (Test-Path $playgroundPs1) {
    $destPs1 = Join-Path $BackupRoot 'CTG-Lab-Playground.ps1'
    if (-not $WhatIf) {
        Copy-Item -Path $playgroundPs1 -Destination $destPs1 -Force
    }
    Write-CtgStageLog "Staged: $destPs1"
}

$shieldPs1 = Join-Path $PSScriptRoot 'CTG-Shield-Status.ps1'
if (Test-Path $shieldPs1) {
    $destShield = Join-Path $BackupRoot 'CTG-Shield-Status.ps1'
    if (-not $WhatIf) {
        Copy-Item -Path $shieldPs1 -Destination $destShield -Force
    }
    Write-CtgStageLog "Staged: $destShield"
}

Write-CtgStageLog 'Kali lab staging complete. In VM: sudo bash /mnt/ctg/RUN-KALI-LAB-NOW.sh'
