# Create or reinstall a Kali lab VM in Oracle VirtualBox (unattended Debian/Ubuntu preseed).
# Authorized defensive lab use only. Do not commit ISOs or credential files.
param(
    [string]$IsoPath = '',
    [string]$VmName = 'Kali-Lab',
    [int]$MemoryMB = 4096,
    [int]$DiskGB = 40,
    [int]$Cpus = 2,
    [string]$User = 'kali',
    [string]$CredentialsFile = 'C:\Users\Owner\Backups\kali-vm-credentials.txt',
    [string]$PasswordFile = '',
    [string]$Hostname = 'kali-lab.local',
    [switch]$StartGui,
    [switch]$RecreateVm
)

$ErrorActionPreference = 'Stop'
$VBoxManage = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
if (-not (Test-Path $VBoxManage)) {
    throw "VBoxManage not found at $VBoxManage. Install Oracle VirtualBox first."
}

if (-not $IsoPath) {
    $candidates = Get-ChildItem -Path 'C:\Users\Owner\Downloads' -Filter 'kali*-installer*.iso' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch 'virtualbox' } |
        Sort-Object LastWriteTime -Descending
    if (-not $candidates) {
        throw 'No Kali installer ISO found in Downloads. Pass -IsoPath explicitly.'
    }
    $IsoPath = $candidates[0].FullName
}

$backupDir = Split-Path -Parent $CredentialsFile
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

if (-not $PasswordFile) {
    $PasswordFile = Join-Path $backupDir 'kali-vm-vbox-password.txt'
}

function New-RandomPassword([int]$Length = 24) {
    $chars = 48..57 + 65..90 + 97..122
    -join (1..$Length | ForEach-Object { [char]($chars | Get-Random) })
}

if (-not (Test-Path $PasswordFile)) {
    $pw = New-RandomPassword
    $pw | Set-Content -Path $PasswordFile -NoNewline -Encoding ASCII
    @"
VM: $VmName
User: $User
Password: $pw
Generated: $(Get-Date -Format o)
ISO: $IsoPath
"@ | Set-Content -Path $CredentialsFile -Encoding UTF8
    Write-Host "Wrote credentials to $CredentialsFile (and password-only file for VBoxManage)."
}

$vmList = & $VBoxManage list vms 2>$null
$exists = $vmList -match "`"$([regex]::Escape($VmName))`""

if ($RecreateVm -and $exists) {
    & $VBoxManage controlvm $VmName poweroff 2>$null
    Start-Sleep -Seconds 2
    & $VBoxManage unregistervm $VmName --delete
    $exists = $false
}

$vmBase = Join-Path $env:USERPROFILE 'VirtualBox VMs'
$vmDir = Join-Path $vmBase $VmName
$vdiPath = Join-Path $vmDir "$VmName.vdi"
$diskMb = $DiskGB * 1024

if (-not $exists) {
    if (-not (Test-Path $vmDir)) {
        New-Item -ItemType Directory -Path $vmDir -Force | Out-Null
    }
    & $VBoxManage createvm --name $VmName --register --basefolder $vmBase --ostype Debian_64
    & $VBoxManage modifyvm $VmName --memory $MemoryMB --cpus $Cpus --vram 128 `
        --boot1 dvd --boot2 disk --boot3 none --acpi on --ioapic on --hwvirtex on `
        --graphicscontroller vmsvga --nic1 nat --audio-driver default --audio-out on
    & $VBoxManage createhd --filename $vdiPath --size $diskMb --format VDI --variant Standard
    & $VBoxManage storagectl $VmName --name SATA --add sata --controller IntelAhci --portcount 2 --bootable on
    & $VBoxManage storageattach $VmName --storagectl SATA --port 0 --device 0 --type hdd --medium $vdiPath
    & $VBoxManage storagectl $VmName --name IDE --add ide --controller PIIX4 --portcount 2 --bootable on
    & $VBoxManage storageattach $VmName --storagectl IDE --port 1 --device 0 --type dvddrive --medium $IsoPath
}

$startArg = if ($StartGui) { 'gui' } else { 'none' }
& $VBoxManage unattended install $VmName --iso=$IsoPath --user=$User --password-file=$PasswordFile `
    --locale=en_US --country=US --time-zone=America/New_York --hostname=$Hostname `
    --install-additions --start-vm=$startArg

Write-Host "VM: $VmName | RAM: ${MemoryMB}MB | CPUs: $Cpus | Disk: ${DiskGB}GB | ISO: $IsoPath"
Write-Host "Credentials: $CredentialsFile"
