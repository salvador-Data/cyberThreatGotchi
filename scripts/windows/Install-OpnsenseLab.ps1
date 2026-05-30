# Create OPNsense lab VM in VirtualBox (lab LAN, 2 NICs). Not edge/production by default.
# Authorized defensive lab use only — Hacker Planet LLC.
param(
    [string]$VmName = 'OPNsense-Lab',
    [string]$IsoPath = '',
    [int]$MemoryMB = 2048,
    [int]$DiskGB = 20,
    [int]$Cpus = 2,
    [switch]$EdgeMode,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$VBoxManage = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'

if (-not (Test-Path $VBoxManage)) {
    Write-Warning 'VirtualBox not installed — OPNsense lab VM skipped.'
    return
}

if ($EdgeMode) {
    Write-Host ''
    Write-Host '*** WARNING: -EdgeMode would replace ISP edge — NOT implemented by default. ***'
    Write-Host 'Use lab VLAN / host-only only. Export ISP config and get household approval first.'
    Write-Host ''
    throw 'EdgeMode blocked. Re-run without -EdgeMode for lab-only VM.'
}

if (-not $IsoPath) {
    $candidates = @(
        (Get-ChildItem -Path 'C:\Users\Owner\Downloads' -Filter 'OPNsense*.iso' -ErrorAction SilentlyContinue),
        (Get-ChildItem -Path 'C:\Users\Owner\Downloads' -Filter 'opnsense*.iso' -ErrorAction SilentlyContinue)
    ) | ForEach-Object { $_ } | Sort-Object LastWriteTime -Descending
    if ($candidates) { $IsoPath = $candidates[0].FullName }
}

$vmList = & $VBoxManage list vms 2>$null
$exists = $vmList -match "`"$([regex]::Escape($VmName))`""

if ($exists) {
    Write-Host "OPNsense lab VM already exists: $VmName"
    return
}

if (-not $IsoPath -or -not (Test-Path $IsoPath)) {
    Write-Warning "OPNsense ISO not found in Downloads. Download from https://opnsense.org/download/ and re-run."
    Write-Warning 'Skipping OPNsense VM creation — Kali bootstrap is not blocked.'
    return
}

if ($WhatIf) {
    Write-Host "[WhatIf] Would create $VmName with WAN=nat nic1, LAN=intnet(opn-lab)"
    return
}

$vmBase = Join-Path $env:USERPROFILE 'VirtualBox VMs'
$vmDir = Join-Path $vmBase $VmName
$vdiPath = Join-Path $vmDir "$VmName.vdi"
$diskMb = $DiskGB * 1024

New-Item -ItemType Directory -Path $vmDir -Force | Out-Null
& $VBoxManage createvm --name $VmName --register --basefolder $vmBase --ostype FreeBSD_64
& $VBoxManage modifyvm $VmName --memory $MemoryMB --cpus $Cpus --vram 16 `
    --boot1 dvd --boot2 disk --acpi on --ioapic on --hwvirtex on
& $VBoxManage modifyvm $VmName --nic1 nat --nictype1 82540EM
& $VBoxManage modifyvm $VmName --nic2 intnet --intnet2 opn-lab --nictype2 82540EM
& $VBoxManage createhd --filename $vdiPath --size $diskMb --format VDI
& $VBoxManage storagectl $VmName --name SATA --add sata --controller IntelAhci --portcount 2 --bootable on
& $VBoxManage storageattach $VmName --storagectl SATA --port 0 --device 0 --type hdd --medium $vdiPath
& $VBoxManage storagectl $VmName --name IDE --add ide --controller PIIX4 --portcount 2 --bootable on
& $VBoxManage storageattach $VmName --storagectl IDE --port 0 --device 0 --type dvddrive --medium $IsoPath

Write-Host "Created $VmName - 2 NICs (WAN NAT + LAN intnet:opn-lab). Start GUI and complete OPNsense installer."
Write-Host "Backup config to C:\Users\Owner\Backups\opnsense-config-YYYY-MM-DD.xml (gitignored)."
Write-Host ""
Write-Host "DNS (mandatory preserve): configure Unbound forwarders to DuckDuckGo only when DDG is your stack."
Write-Host "  Primary: 94.140.14.14  Secondary: 94.140.15.15  (DoH: https://dns.duckduckgo.com/dns-query)"
Write-Host "  Do NOT stack NextDNS, Cloudflare 1.1.1.1, or 9.9.9.9 when DuckDuckGo is set."
Write-Host "  Template: docs/OPNSENSE_LAB_DNS.md  |  iPhone/Windows rules: docs/IPHONE_HARDENING.md"
