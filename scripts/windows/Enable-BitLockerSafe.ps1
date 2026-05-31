<#
.SYNOPSIS
  Safe BitLocker diagnosis and optional OS-volume encryption (authorized hosts only).

.DESCRIPTION
  Diagnose-only by default - no volume changes unless -Apply is passed from an elevated
  Administrator session. Recovery passwords are written only under
  %USERPROFILE%\Backups\.vault\ (gitignored). Never logs recovery keys to the console.

.PARAMETER DiagnoseOnly
  Report TPM, BitLocker, and boot-safety checks (default when -Apply is omitted).

.PARAMETER Apply
  Enable BitLocker on the OS volume with TPM + recovery password protectors.
  Requires Administrator; prompts for confirmation unless -Force.

.PARAMETER Force
  Skip the interactive confirmation before -Apply.

.PARAMETER MountPoint
  Volume to target (default C:).

.PARAMETER VaultDirectory
  Override recovery-key directory (tests only).

.EXAMPLE
  .\scripts\windows\Enable-BitLockerSafe.ps1

.EXAMPLE
  .\scripts\windows\Enable-BitLockerSafe.ps1 -Apply
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch] $DiagnoseOnly,
    [switch] $Apply,
    [switch] $Force,
    [string] $MountPoint = 'C:',
    [string] $VaultDirectory = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$ScriptDir = $PSScriptRoot
. (Join-Path $ScriptDir 'CTG-AdminCommon.ps1')
$script:CtgIsAdmin = Test-CtgIsAdmin

if (-not $Apply) {
    $DiagnoseOnly = $true
}

$MountPoint = $MountPoint.TrimEnd('\')
if ($MountPoint -notmatch ':$') {
    $MountPoint = "${MountPoint}:"
}

function Get-CtgBitLockerVaultDirectory {
    param([string] $Override)
    if ($Override) {
        return $Override
    }
    return Join-Path $env:USERPROFILE 'Backups\.vault'
}

function Write-CtgBlBanner {
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ' CTG - BitLocker safe encryption' -ForegroundColor Cyan
    Write-Host ' Authorized defensive use on systems you own' -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host " Computer:   $env:COMPUTERNAME"
    Write-Host " User:       $env:USERNAME"
    Write-Host " Admin:      $script:CtgIsAdmin"
    Write-Host " MountPoint: $MountPoint"
    Write-Host " Mode:       $(if ($Apply) { 'Diagnose + Apply' } else { 'DiagnoseOnly' })"
    Write-Host " Date:       $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host ''
}

function Write-CtgBlSection {
    param([string] $Title)
    Write-Host "--- $Title ---" -ForegroundColor Yellow
}

function Test-CtgBitLockerCmdletAvailable {
    return [bool](Get-Command -Name 'Get-BitLockerVolume' -ErrorAction SilentlyContinue)
}

function Get-CtgOsEditionBitLockerHint {
    $hint = 'Unknown edition - verify BitLocker is licensed on this SKU.'
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $caption = $os.Caption
        $sku = $os.OperatingSystemSKU
        $hint = "$caption (SKU $sku)"
        # Common: 48=Pro, 4=Enterprise, 101=Pro for Workstations, 121=Education
        $proSkus = @(48, 4, 101, 121, 27, 125, 161)
        if ($caption -match 'Home') {
            $hint += ' - Windows Home may use Device Encryption instead of full BitLocker management.'
        } elseif ($sku -in $proSkus -or $caption -match 'Pro|Enterprise|Education|Workstation') {
            $hint += ' - Edition typically supports BitLocker.'
        }
    } catch {
        $hint = "Could not read OS edition: $($_.Exception.Message)"
    }
    return $hint
}

function Get-CtgTpmDiagnosis {
    $result = [ordered]@{
        Available = $false
        Ready     = $false
        Enabled   = $null
        Owned     = $null
        Details   = @()
    }
    try {
        $tpm = Get-Tpm -ErrorAction Stop
        $result.Available = $true
        $props = $tpm.PSObject.Properties.Name
        if ('TpmReady' -in $props) {
            $result.Ready = [bool]$tpm.TpmReady
        } elseif ('TpmPresent' -in $props) {
            $result.Ready = [bool]$tpm.TpmPresent
            $result.Details += 'TpmReady not exposed; using TpmPresent as fallback.'
        } else {
            $result.Ready = $false
            $result.Details += 'TPM cmdlet returned no Ready/Present flags; check firmware.'
        }
        if ('TpmEnabled' -in $props) { $result.Enabled = $tpm.TpmEnabled }
        if ('TpmOwned' -in $props) { $result.Owned = $tpm.TpmOwned }
        if ('ManufacturerIdTxt' -in $props -and $tpm.ManufacturerIdTxt) {
            $result.Details += "ManufacturerIdInfo: $($tpm.ManufacturerIdTxt)"
        }
        if ('SpecVersion' -in $props -and $tpm.SpecVersion) {
            $result.Details += "SpecVersion: $($tpm.SpecVersion)"
        }
    } catch {
        $result.Details += "Get-Tpm failed: $($_.Exception.Message)"
        try {
            $tpmWmi = Get-CimInstance -Namespace 'root\cimv2\security\microsofttpm' -ClassName Win32_Tpm -ErrorAction Stop
            if ($tpmWmi) {
                $result.Available = $true
                $result.Details += 'TPM present via WMI (legacy check).'
            }
        } catch {
            $result.Details += 'No TPM WMI provider - firmware TPM or disabled in BIOS.'
        }
    }
    return [PSCustomObject]$result
}

function Get-CtgSecureBootDiagnosis {
    try {
        $sb = Confirm-SecureBootUEFI -ErrorAction Stop
        return [PSCustomObject]@{ Enabled = $sb; Note = 'Secure Boot reported by firmware.' }
    } catch {
        return [PSCustomObject]@{ Enabled = $null; Note = 'Secure Boot check unavailable (legacy BIOS or permission).' }
    }
}

function Get-CtgBitLockerVolumeDiagnosis {
    param([string] $Volume)
    if (-not (Test-CtgBitLockerCmdletAvailable)) {
        return [PSCustomObject]@{
            CmdletsAvailable = $false
            Error            = 'BitLocker PowerShell module not available on this edition.'
        }
    }
    try {
        $bl = Get-BitLockerVolume -MountPoint $Volume -ErrorAction Stop
        return [PSCustomObject]@{
            CmdletsAvailable    = $true
            MountPoint          = $bl.MountPoint
            VolumeStatus        = $bl.VolumeStatus
            EncryptionPercentage = $bl.EncryptionPercentage
            ProtectionStatus    = $bl.ProtectionStatus
            EncryptionMethod    = $bl.EncryptionMethod
            KeyProtectorCount   = ($bl.KeyProtector | Measure-Object).Count
            KeyProtectorTypes   = ($bl.KeyProtector | ForEach-Object { $_.KeyProtectorType }) -join ', '
        }
    } catch {
        return [PSCustomObject]@{
            CmdletsAvailable = $true
            Error            = $_.Exception.Message
        }
    }
}

function Get-CtgManageBdeStatusLines {
    param([string] $Volume)
    $lines = @()
    try {
        $out = & manage-bde.exe -status $Volume 2>&1
        foreach ($line in $out) {
            if ($line -match 'recovery password|numerical password|password:\s*\S') {
                $lines += '[redacted - use Backups\.vault recovery file]'
            } else {
                $lines += [string]$line
            }
        }
    } catch {
        $lines += "manage-bde failed: $($_.Exception.Message)"
    }
    return $lines
}

function Get-CtgBootSafetyChecks {
    $checks = [ordered]@{}
    try {
        $re = reagentc.exe /info 2>&1 | Out-String
        $checks.WindowsRE = if ($re -match 'Windows RE status:\s*Enabled') { 'Enabled' } else { 'Disabled or unknown' }
    } catch {
        $checks.WindowsRE = 'Could not query reagentc'
    }
    try {
        $boot = bcdedit /enum '{current}' 2>&1 | Out-String
        if ($boot -match 'path\s+.*\\bootmgr') {
            $checks.BcdCurrent = 'Present'
        } else {
            $checks.BcdCurrent = 'Review BCD - unusual boot configuration'
        }
    } catch {
        $checks.BcdCurrent = 'bcdedit unavailable without elevation'
    }
    $checks.DualBootHint = 'If you dual-boot Linux/macOS, capture recovery key before Apply and avoid resizing partitions.'
    return [PSCustomObject]$checks
}

function Get-CtgBitLockerApplyBlockers {
    param(
        $VolumeDiag,
        $TpmDiag
    )
    $blockers = @()
    if (-not $script:CtgIsAdmin) {
        $blockers += 'Administrator elevation required for -Apply.'
    }
    if (-not (Test-CtgBitLockerCmdletAvailable)) {
        $blockers += 'BitLocker cmdlets unavailable - upgrade edition or enable feature.'
    }
    if ($VolumeDiag.PSObject.Properties['Error'] -and $VolumeDiag.Error) {
        $blockers += "Volume query failed: $($VolumeDiag.Error)"
    } elseif ($VolumeDiag.PSObject.Properties['VolumeStatus']) {
        if ($VolumeDiag.VolumeStatus -eq 'FullyEncrypted' -and $VolumeDiag.ProtectionStatus -eq 'On') {
            $blockers += 'Volume already fully encrypted with protection on - no action needed.'
        }
        if ($VolumeDiag.VolumeStatus -eq 'EncryptionInProgress') {
            $blockers += 'Encryption already in progress - wait for completion before -Apply.'
        }
    }
    if (-not $TpmDiag.Available -or -not $TpmDiag.Ready) {
        $blockers += 'TPM not available or not ready - enable TPM 2.0 in firmware first.'
    }
    return @($blockers)
}

function Save-CtgBitLockerRecoveryKeyFile {
    param(
        [string] $RecoveryPassword,
        [string] $KeyId,
        [string] $VaultDir
    )
    New-Item -ItemType Directory -Path $VaultDir -Force | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $safeHost = ($env:COMPUTERNAME -replace '[^\w\-]', '_')
    $fileName = "bitlocker-recovery-${safeHost}-${stamp}.txt"
    $path = Join-Path $VaultDir $fileName
    $body = @(
        '# CTG BitLocker recovery password - KEEP OFFLINE; never commit to git.'
        "# Computer: $env:COMPUTERNAME"
        "# MountPoint: $MountPoint"
        "# Generated: $(Get-Date -Format 'o')"
        "# KeyProtectorId: $KeyId"
        ''
        "RecoveryPassword: $RecoveryPassword"
        ''
        '# Store a copy in DuckDuckGo Password Manager or print to a safe.'
    ) -join "`r`n"
    Set-Content -Path $path -Value $body -Encoding UTF8 -NoNewline
    try {
        $acl = Get-Acl -Path $path
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $env:USERNAME, 'FullControl', 'Allow'
        )
        $acl.SetAccessRuleProtection($true, $false)
        $acl.SetAccessRule($rule)
        Set-Acl -Path $path -AclObject $acl
    } catch {
        Write-Host "Warning: could not harden ACL on recovery file: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    return $path
}

function Invoke-CtgBitLockerApply {
    param(
        $VolumeDiag,
        [string] $VaultDir
    )
    $blockers = Get-CtgBitLockerApplyBlockers -VolumeDiag $VolumeDiag -TpmDiag (Get-CtgTpmDiagnosis)
    if (@($blockers).Count -gt 0) {
        Write-CtgBlSection 'Apply blocked'
        foreach ($b in $blockers) {
            Write-Host " BLOCKED: $b" -ForegroundColor Red
        }
        return 1
    }

    if (-not $Force) {
        Write-Host ''
        Write-Host 'Apply will enable BitLocker on the OS volume (UsedSpaceOnly, XtsAes256).' -ForegroundColor Yellow
        Write-Host 'A recovery password file will be saved under Backups\.vault\ only.' -ForegroundColor Yellow
        Write-Host 'Ensure you have a recent backup and BitLocker recovery path before continuing.' -ForegroundColor Yellow
        $confirm = Read-Host 'Type YES to proceed with -Apply'
        if ($confirm -ne 'YES') {
            Write-Host 'Apply cancelled (confirmation not YES).' -ForegroundColor Gray
            return 2
        }
    }

    if (-not $PSCmdlet.ShouldProcess($MountPoint, 'Enable BitLocker with TPM and recovery password')) {
        return 0
    }

    try {
        $existing = Get-BitLockerVolume -MountPoint $MountPoint -ErrorAction Stop
        if ($existing.VolumeStatus -eq 'FullyEncrypted') {
            Write-Host 'Volume already encrypted - ensuring recovery protector is archived.' -ForegroundColor Green
            $rp = $existing.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } | Select-Object -First 1
            if ($rp -and $rp.RecoveryPassword) {
                $saved = Save-CtgBitLockerRecoveryKeyFile -RecoveryPassword $rp.RecoveryPassword `
                    -KeyId $rp.KeyProtectorId -VaultDir $VaultDir
                Write-Host "Recovery key archived (existing protector): $saved" -ForegroundColor Green
            } else {
                $added = Add-BitLockerKeyProtector -MountPoint $MountPoint -RecoveryPasswordProtector -ErrorAction Stop
                $newRp = $added.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } | Select-Object -First 1
                $saved = Save-CtgBitLockerRecoveryKeyFile -RecoveryPassword $newRp.RecoveryPassword `
                    -KeyId $newRp.KeyProtectorId -VaultDir $VaultDir
                Write-Host "New recovery protector added; saved: $saved" -ForegroundColor Green
            }
            return 0
        }

        Enable-BitLocker -MountPoint $MountPoint -EncryptionMethod XtsAes256 -UsedSpaceOnly `
            -TpmProtector -SkipHardwareTest -ErrorAction Stop
        Write-Host 'BitLocker enable started (TPM protector). Adding recovery password...' -ForegroundColor Green

        $kpResult = Add-BitLockerKeyProtector -MountPoint $MountPoint -RecoveryPasswordProtector -ErrorAction Stop
        $recovery = $kpResult.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } | Select-Object -First 1
        if (-not $recovery -or -not $recovery.RecoveryPassword) {
            throw 'Recovery password protector was not returned by Add-BitLockerKeyProtector.'
        }

        $savedPath = Save-CtgBitLockerRecoveryKeyFile -RecoveryPassword $recovery.RecoveryPassword `
            -KeyId $recovery.KeyProtectorId -VaultDir $VaultDir
        Write-Host "Recovery key saved (not printed here): $savedPath" -ForegroundColor Green
        Write-Host 'Reboot when convenient; first boot should use TPM unlock.' -ForegroundColor Cyan
        return 0
    } catch {
        Write-Host "Apply failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host 'Boot should be unchanged if Enable-BitLocker did not start - check manage-bde -status.' -ForegroundColor Yellow
        return 3
    }
}

# --- Main ---
Write-CtgBlBanner
$vaultDir = Get-CtgBitLockerVaultDirectory -Override $VaultDirectory

Write-CtgBlSection 'OS edition'
Write-Host (Get-CtgOsEditionBitLockerHint)

Write-CtgBlSection 'TPM'
$tpmDiag = Get-CtgTpmDiagnosis
Write-Host " Available: $($tpmDiag.Available)"
Write-Host " Ready:     $($tpmDiag.Ready)"
Write-Host " Enabled:   $($tpmDiag.Enabled)"
Write-Host " Owned:     $($tpmDiag.Owned)"
foreach ($d in $tpmDiag.Details) { Write-Host "  $d" }

Write-CtgBlSection 'Secure Boot'
$sb = Get-CtgSecureBootDiagnosis
Write-Host " Enabled: $($sb.Enabled) - $($sb.Note)"

Write-CtgBlSection 'BitLocker volume'
$volDiag = Get-CtgBitLockerVolumeDiagnosis -Volume $MountPoint
if (-not $volDiag.CmdletsAvailable) {
    Write-Host $volDiag.Error -ForegroundColor Red
} elseif ($volDiag.PSObject.Properties['Error'] -and $volDiag.Error) {
    Write-Host $volDiag.Error -ForegroundColor Red
} else {
    Write-Host " VolumeStatus:         $($volDiag.VolumeStatus)"
    Write-Host " ProtectionStatus:     $($volDiag.ProtectionStatus)"
    Write-Host " EncryptionPercentage: $($volDiag.EncryptionPercentage)%"
    Write-Host " EncryptionMethod:     $($volDiag.EncryptionMethod)"
    Write-Host " KeyProtectors:        $($volDiag.KeyProtectorTypes)"
}

Write-CtgBlSection 'manage-bde status (redacted)'
Get-CtgManageBdeStatusLines -Volume $MountPoint | ForEach-Object { Write-Host $_ }

Write-CtgBlSection 'Boot safety'
$boot = Get-CtgBootSafetyChecks
$boot.PSObject.Properties | ForEach-Object { Write-Host " $($_.Name): $($_.Value)" }

Write-CtgBlSection 'Vault path (recovery keys only)'
Write-Host " $vaultDir"
Write-Host ' (gitignored - never commit recovery files)'

$blockers = Get-CtgBitLockerApplyBlockers -VolumeDiag $volDiag -TpmDiag $tpmDiag
if (@($blockers).Count -gt 0) {
    Write-CtgBlSection 'Apply readiness'
    foreach ($b in $blockers) {
        Write-Host " $b" -ForegroundColor $(if ($b -match 'already fully encrypted') { 'Green' } else { 'Yellow' })
    }
} else {
    Write-CtgBlSection 'Apply readiness'
    Write-Host ' No blockers - -Apply is permitted from elevated PowerShell.' -ForegroundColor Green
}

$exitCode = 0
if ($Apply) {
    $exitCode = Invoke-CtgBitLockerApply -VolumeDiag $volDiag -VaultDir $vaultDir
}

Write-Host ''
Write-Host 'Done.' -ForegroundColor Cyan
exit $exitCode
