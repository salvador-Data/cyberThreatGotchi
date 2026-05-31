<#
.SYNOPSIS
  Diagnose and optionally encrypt the VirtualBox Kali lab VM (authorized hosts only).

.DESCRIPTION
  Diagnose-only by default. -Apply powers off the VM, runs VBoxManage encryptvm setencryption
  (AES-256; VirtualBox selects GCM/XTS per component). Password is read via SecureString only -
  never logged or written to git. Requires Oracle VM VirtualBox Extension Pack (disk encryption).

.PARAMETER DiagnoseOnly
  Report VM presence, power state, encryption status, disk paths (default without -Apply).

.PARAMETER Apply
  Encrypt the VM after confirmation. Interactive password entry required.

.PARAMETER BackupFirst
  Copy the VM configuration folder to %USERPROFILE%\Backups\vm-backup-kali\ before -Apply.

.PARAMETER VmName
  VirtualBox VM name (default: kali).

.PARAMETER PasswordId
  VirtualBox encryption password identifier (default: ctg-kali).

.PARAMETER Cipher
  AES-128 or AES-256 per VirtualBox 7 docs (default: AES-256).

.EXAMPLE
  .\scripts\windows\Encrypt-KaliVm.ps1 -DiagnoseOnly

.EXAMPLE
  .\scripts\windows\Encrypt-KaliVm.ps1 -Apply -BackupFirst
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch] $DiagnoseOnly,
    [switch] $Apply,
    [switch] $BackupFirst,
    [string] $VmName = 'kali',
    [string] $PasswordId = 'ctg-kali',
    [string] $Cipher = 'AES-256'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$ScriptDir = $PSScriptRoot
. (Join-Path $ScriptDir 'CTG-AdminCommon.ps1')
$script:CtgIsAdmin = Test-CtgIsAdmin

if (-not $Apply) {
    $DiagnoseOnly = $true
}

$LogDir = Join-Path $env:USERPROFILE 'Backups\logs'
$LogFile = Join-Path $LogDir 'encrypt-kali-vm.log'
$BackupDest = Join-Path $env:USERPROFILE 'Backups\vm-backup-kali'

function Write-CtgKaliEncryptLog {
    param([string] $Message, [ConsoleColor] $Color = [ConsoleColor]::Gray)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Host $line -ForegroundColor $Color
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Get-CtgVBoxManagePath {
    $candidates = @(
        (Join-Path ${env:ProgramFiles} 'Oracle\VirtualBox\VBoxManage.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Oracle\VirtualBox\VBoxManage.exe')
    )
    foreach ($path in $candidates) {
        if ($path -and (Test-Path $path)) { return $path }
    }
    return $null
}

function Invoke-CtgVBox {
    param(
        [string] $VBoxManage,
        [string[]] $Args
    )
    $out = & $VBoxManage @Args 2>&1
    $code = $LASTEXITCODE
    return @{ Output = ($out | Out-String).Trim(); ExitCode = $code }
}

function Test-CtgVmRegistered {
    param([string] $VBoxManage, [string] $Name)
    $r = Invoke-CtgVBox -VBoxManage $VBoxManage -Args @('list', 'vms')
    if ($r.ExitCode -ne 0) { return $false }
    $escaped = [regex]::Escape($Name)
    return [bool]($r.Output -match "`"$escaped`"")
}

function Get-CtgVmState {
    param([string] $VBoxManage, [string] $Name)
    $r = Invoke-CtgVBox -VBoxManage $VBoxManage -Args @('showvminfo', $Name, '--machinereadable')
    if ($r.ExitCode -ne 0) { return 'unknown' }
    if ($r.Output -match 'VMState="([^"]+)"') { return $Matches[1] }
    return 'unknown'
}

function Get-CtgVmCfgFile {
    param([string] $VBoxManage, [string] $Name)
    $r = Invoke-CtgVBox -VBoxManage $VBoxManage -Args @('showvminfo', $Name, '--machinereadable')
    if ($r.ExitCode -ne 0) { return $null }
    if ($r.Output -match 'CfgFile="([^"]+)"') {
        return $Matches[1] -replace '\\', '\'
    }
    return $null
}

function Get-CtgVmEncryptionDiagnosis {
    param([string] $VBoxManage, [string] $Name)
    $result = [ordered]@{
        Encrypted       = $false
        MachineUuid     = ''
        CfgFile         = ''
        Notes           = @()
        DiskAttachments = @()
    }
    $cfg = Get-CtgVmCfgFile -VBoxManage $VBoxManage -Name $Name
    $result.CfgFile = $cfg
    if (-not $cfg -or -not (Test-Path $cfg)) {
        $result.Notes += 'Could not resolve VM .vbox path.'
        return [pscustomobject]$result
    }
    $vmDir = Split-Path $cfg -Parent
    $xml = Get-Content -Path $cfg -Raw -ErrorAction SilentlyContinue
    if ($xml -match '<MachineEncrypted') {
        $result.Encrypted = $true
        $result.Notes += 'MachineEncrypted present in .vbox - VM is encrypted at hypervisor layer.'
    }
    if ($xml -match 'uuid="\{([^}]+)\}"') {
        $result.MachineUuid = $Matches[1]
    }
    $r = Invoke-CtgVBox -VBoxManage $VBoxManage -Args @('showvminfo', $Name)
    if ($r.ExitCode -eq 0) {
        foreach ($line in ($r.Output -split "`n")) {
            if ($line -match '(?i)encryption|encrypted|inaccessible') {
                $result.Notes += $line.Trim()
            }
            if ($line -match '^(Storage|IDE|SATA|SCSI|NVMe)' -or $line -match '\.vdi|\.vhd') {
                if ($line.Trim().Length -gt 0) {
                    $result.DiskAttachments += $line.Trim()
                }
            }
        }
    }
    $stor = Invoke-CtgVBox -VBoxManage $VBoxManage -Args @('showvminfo', $Name, '--machinereadable')
    if ($stor.ExitCode -eq 0) {
        $paths = [regex]::Matches($stor.Output, '(?:^|\n)[^=]*="([^"]+\.(?:vdi|vhd|vmdk))"') |
            ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
        foreach ($p in $paths) {
            if ($p -notmatch '^\$') {
                $result.DiskAttachments += $p
            }
        }
    }
    $result.DiskAttachments = @($result.DiskAttachments | Select-Object -Unique)
    if ($result.DiskAttachments.Count -eq 0 -and $vmDir) {
        $result.Notes += "VM folder: $vmDir"
    }
    return [pscustomobject]$result
}

function Get-CtgVBoxExtensionPackDiagnosis {
    param([string] $VBoxManage)
    $r = Invoke-CtgVBox -VBoxManage $VBoxManage -Args @('list', 'extpacks')
    $installed = $false
    $cryptoHint = $false
    if ($r.ExitCode -eq 0) {
        $installed = $r.Output -match 'Oracle VM VirtualBox Extension Pack'
        $cryptoHint = $r.Output -match 'Disk Encryption|full VM encryption|VBoxPuelCrypto'
    }
    return [pscustomobject]@{
        ListOutput  = $r.Output
        Installed   = $installed
        CryptoHint  = $cryptoHint
        ExitCode    = $r.ExitCode
    }
}

function Stop-CtgKaliVmIfRunning {
    param([string] $VBoxManage, [string] $Name)
    $state = Get-CtgVmState -VBoxManage $VBoxManage -Name $Name
    if ($state -eq 'poweroff' -or $state -eq 'aborted') {
        Write-CtgKaliEncryptLog "VM already powered off (state=$state)." 'DarkGray'
        return $true
    }
    Write-CtgKaliEncryptLog "VM state=$state - sending ACPI poweroff..." 'Yellow'
    $null = Invoke-CtgVBox -VBoxManage $VBoxManage -Args @('controlvm', $Name, 'acpipowerbutton')
    $deadline = (Get-Date).AddMinutes(3)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        $state = Get-CtgVmState -VBoxManage $VBoxManage -Name $Name
        if ($state -eq 'poweroff' -or $state -eq 'aborted') {
            Write-CtgKaliEncryptLog "VM powered off." 'Green'
            return $true
        }
    }
    Write-CtgKaliEncryptLog 'ACPI shutdown timed out - trying poweroff...' 'Yellow'
    $null = Invoke-CtgVBox -VBoxManage $VBoxManage -Args @('controlvm', $Name, 'poweroff')
    Start-Sleep -Seconds 5
    $state = Get-CtgVmState -VBoxManage $VBoxManage -Name $Name
    return ($state -eq 'poweroff' -or $state -eq 'aborted')
}

function New-CtgVBoxPasswordFile {
    param([SecureString] $Secure)
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    )
    try {
        $tmp = Join-Path $env:TEMP ("ctg-vbox-pw-{0}.tmp" -f [guid]::NewGuid().ToString('N'))
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($tmp, $plain, $utf8NoBom)
        $acl = Get-Acl $tmp
        $acl.SetAccessRuleProtection($true, $false)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $env:USERNAME, 'FullControl', 'Allow'
        )
        $acl.SetAccessRule($rule)
        Set-Acl -Path $tmp -AclObject $acl
        return $tmp
    } finally {
        if ($plain) {
            $plain = $null
        }
    }
}

function Read-CtgKaliEncryptPassword {
    Write-Host ''
    Write-Host 'Enter a STRONG encryption password (not echoed). Store in DuckDuckGo Password Manager.' -ForegroundColor Cyan
    Write-Host 'Lost password = lost VM. BitLocker on the host does NOT replace this password.' -ForegroundColor Yellow
    $a = Read-Host 'New encryption password' -AsSecureString
    $b = Read-Host 'Confirm encryption password' -AsSecureString
    $ptrA = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($a)
    $ptrB = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($b)
    try {
        $plainA = [Runtime.InteropServices.Marshal]::PtrToStringAuto($ptrA)
        $plainB = [Runtime.InteropServices.Marshal]::PtrToStringAuto($ptrB)
        if ($plainA -cne $plainB) {
            throw 'Passwords do not match.'
        }
        if ($plainA.Length -lt 12) {
            throw 'Password must be at least 12 characters.'
        }
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptrA)
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptrB)
    }
    return $a
}

function Copy-CtgKaliVmBackup {
    param([string] $CfgFile, [string] $DestRoot)
    if (-not $CfgFile -or -not (Test-Path $CfgFile)) {
        throw "Cannot backup - invalid CfgFile: $CfgFile"
    }
    $vmDir = Split-Path $CfgFile -Parent
    if (-not (Test-Path $DestRoot)) {
        New-Item -ItemType Directory -Path $DestRoot -Force | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dest = Join-Path $DestRoot $stamp
    Write-CtgKaliEncryptLog "Backing up VM folder -> $dest (may take several minutes)..." 'Yellow'
    Copy-Item -Path $vmDir -Destination $dest -Recurse -Force
    Write-CtgKaliEncryptLog 'VM folder backup completed.' 'Green'
    return $dest
}

function Invoke-CtgKaliVmEncryptApply {
    param(
        [string] $VBoxManage,
        [string] $Name,
        [string] $CipherId,
        [string] $PassId,
        [string] $CfgFile
    )
    if (-not $script:CtgIsAdmin) {
        Write-CtgKaliEncryptLog 'Apply: Administrator PowerShell recommended (Extension Pack / file ACLs).' 'Yellow'
    }
    if (-not (Stop-CtgKaliVmIfRunning -VBoxManage $VBoxManage -Name $Name)) {
        Write-CtgKaliEncryptLog 'Apply blocked - VM did not power off. Close GUI or run: VBoxManage controlvm poweroff' 'Red'
        return 2
    }
    $enc = Get-CtgVmEncryptionDiagnosis -VBoxManage $VBoxManage -Name $Name
    if ($enc.Encrypted) {
        Write-CtgKaliEncryptLog 'Apply skipped - VM already encrypted.' 'Green'
        return 0
    }
    if ($BackupFirst -and $CfgFile) {
        try {
            Copy-CtgKaliVmBackup -CfgFile $CfgFile -DestRoot $BackupDest | Out-Null
        } catch {
            Write-CtgKaliEncryptLog "Backup failed: $($_.Exception.Message)" 'Red'
            return 3
        }
    }
    Write-Host ''
    Write-Host 'Type YES to encrypt the Kali VM (irreversible without password + backup).' -ForegroundColor Yellow
    $confirm = Read-Host 'Confirmation'
    if ($confirm -ne 'YES') {
        Write-CtgKaliEncryptLog 'Apply cancelled - confirmation was not YES.' 'Yellow'
        return 1
    }
    $secure = Read-CtgKaliEncryptPassword
    $pwFile = $null
    try {
        $pwFile = New-CtgVBoxPasswordFile -Secure $secure
        Write-CtgKaliEncryptLog (
            "Running encryptvm setencryption (cipher=$CipherId password-id=$PassId)..." 
        ) 'Cyan'
        $r = Invoke-CtgVBox -VBoxManage $VBoxManage -Args @(
            'encryptvm', $Name, 'setencryption',
            "--cipher=$CipherId",
            "--new-password=$pwFile",
            "--new-password-id=$PassId"
        )
        if ($r.Output) {
            foreach ($line in ($r.Output -split "`n")) {
                if ($line -notmatch '(?i)password') {
                    Write-CtgKaliEncryptLog $line.Trim() 'DarkGray'
                }
            }
        }
        if ($r.ExitCode -ne 0) {
            Write-CtgKaliEncryptLog "encryptvm failed (exit $($r.ExitCode)). Check Extension Pack version matches VirtualBox." 'Red'
            return 4
        }
        Write-CtgKaliEncryptLog 'VM encryption completed. After restarting VirtualBox Manager, run addpassword if VM shows Inaccessible.' 'Green'
        Write-CtgKaliEncryptLog "Start VM: VBoxManage startvm `"$Name`" --password-id $PassId --password -" 'Cyan'
        return 0
    } finally {
        if ($pwFile -and (Test-Path $pwFile)) {
            Remove-Item -Path $pwFile -Force -ErrorAction SilentlyContinue
        }
        $secure.Dispose()
    }
}

# --- Main ---
Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ' CTG - Kali VirtualBox VM encryption' -ForegroundColor Cyan
Write-Host ' Authorized defensive use on systems you own' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host " Computer:  $env:COMPUTERNAME"
Write-Host " User:      $env:USERNAME"
Write-Host " Admin:     $script:CtgIsAdmin"
Write-Host " VM name:   $VmName"
Write-Host " Mode:      $(if ($Apply) { 'Diagnose + Apply' } else { 'DiagnoseOnly' })"
Write-Host " Log:       $LogFile"
Write-Host ''

Write-CtgKaliEncryptLog '--- Kali VM encryption session started ---' 'Cyan'

$vbox = Get-CtgVBoxManagePath
if (-not $vbox) {
    Write-CtgKaliEncryptLog 'VirtualBox VBoxManage.exe not found. Install Oracle VirtualBox 7.x.' 'Red'
    exit 10
}
Write-CtgKaliEncryptLog "VBoxManage: $vbox" 'DarkGray'

if (-not (Test-CtgVmRegistered -VBoxManage $vbox -Name $VmName)) {
    Write-CtgKaliEncryptLog "VM '$VmName' not registered. Run Install-KaliVirtualBox.ps1 or register VM in VirtualBox." 'Red'
    exit 11
}
Write-CtgKaliEncryptLog "VM '$VmName' is registered." 'Green'

$state = Get-CtgVmState -VBoxManage $vbox -Name $VmName
Write-CtgKaliEncryptLog "Power state: $state" $(if ($state -eq 'poweroff') { 'Green' } else { 'Yellow' })

$ext = Get-CtgVBoxExtensionPackDiagnosis -VBoxManage $vbox
Write-CtgKaliEncryptLog "Extension Pack installed: $($ext.Installed) (crypto in description: $($ext.CryptoHint))" $(if ($ext.Installed) { 'Green' } else { 'Red' })

$encDiag = Get-CtgVmEncryptionDiagnosis -VBoxManage $vbox -Name $VmName
Write-CtgKaliEncryptLog "CfgFile: $($encDiag.CfgFile)" 'DarkGray'
Write-CtgKaliEncryptLog "Already encrypted: $($encDiag.Encrypted)" $(if ($encDiag.Encrypted) { 'Green' } else { 'Yellow' })
if ($encDiag.MachineUuid) {
    Write-CtgKaliEncryptLog "UUID (note if GUI shows Inaccessible): $($encDiag.MachineUuid)" 'DarkGray'
}
foreach ($n in $encDiag.Notes) { Write-CtgKaliEncryptLog "  $n" 'DarkGray' }
Write-CtgKaliEncryptLog '--- Disk / storage paths ---' 'Yellow'
if ($encDiag.DiskAttachments.Count -eq 0) {
    Write-CtgKaliEncryptLog '  (no .vdi paths parsed - see VM folder above)' 'DarkGray'
} else {
    foreach ($d in $encDiag.DiskAttachments) {
        Write-CtgKaliEncryptLog "  $d" 'DarkGray'
    }
}

Write-CtgKaliEncryptLog '--- Apply readiness ---' 'Yellow'
$blockers = @()
if (-not $ext.Installed) {
    $blockers += 'Install Oracle VM VirtualBox Extension Pack (version must match VirtualBox).'
}
if ($encDiag.Encrypted) {
    $blockers += 'VM already encrypted - no need to -Apply.'
} elseif ($state -ne 'poweroff' -and $state -ne 'aborted') {
    $blockers += "VM must be powered off before -Apply (current: $state). Script will ACPI-stop when applying."
}
if ($blockers.Count -eq 0 -and -not $encDiag.Encrypted) {
    Write-CtgKaliEncryptLog 'No blockers for -Apply (power-off handled automatically).' 'Green'
} else {
    foreach ($b in $blockers) { Write-CtgKaliEncryptLog "  $b" 'Yellow' }
}

Write-CtgKaliEncryptLog 'WARNING: Do NOT use cryptsetup luksFormat on running Kali root - see docs/KALI_DISK_ENCRYPTION.md' 'Yellow'
Write-CtgKaliEncryptLog 'Host BitLocker protects the laptop. VBox encryption protects copied .vdi off the host.' 'DarkGray'

$exitCode = 0
if ($Apply) {
    $exitCode = Invoke-CtgKaliVmEncryptApply -VBoxManage $vbox -Name $VmName -CipherId $Cipher `
        -PassId $PasswordId -CfgFile $encDiag.CfgFile
}

Write-Host ''
Write-Host 'Done.' -ForegroundColor Cyan
exit $exitCode
