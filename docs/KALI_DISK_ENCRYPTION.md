# Kali & lab VM disk encryption

Authorized **lab-only** guidance for Hacker Planet LLC. Complements Windows BitLocker ([DEVICE_ENCRYPTION.md](DEVICE_ENCRYPTION.md)).

## Policy: no destructive in-place encrypt

**Do not** run `cryptsetup luksFormat` or full-disk re-encryption on an **existing** Kali VM disk that already has data unless you:

1. Have a **verified backup** (VirtualBox snapshot + export, or `Stage-KaliLabToBackups.ps1` output).
2. Type an explicit acknowledgment (e.g. `I_ACK_LUKS_FORMAT`) in your lab journal â€” CTG scripts **will not** auto-run LUKS on live disks.

Fresh installs may use LUKS at install time; existing CTG Kali VMs should use **snapshot â†’ new encrypted disk â†’ migrate** instead of in-place format.

---

## LUKS on new Kali installs (guide only)

During **Debian/Kali manual partitioning** (installer):

1. Choose **Guided - use entire disk with encrypted LVM** *or* manual: partition â†’ **physical volume for encryption** â†’ `dm-crypt` â†’ LVM â†’ `/`, `swap`, `/home`.
2. Set a **strong passphrase** â€” store in DuckDuckGo Password Manager, not git.
3. Keep `/boot` unencrypted (standard Debian layout) unless you implement initramfs unlock hooks (advanced).

Post-install checks (inside guest):

```bash
sudo cryptsetup status /dev/mapper/* 2>/dev/null | head
```

```bash
lsblk -f
```

Ansible/CTG lab WiFi secrets: `chmod 600` on `/etc/ctg/lab-wifi.conf` per [SECRET_VAULT.md](SECRET_VAULT.md).

### Migrating an existing VM to LUKS (safe path)

1. **Snapshot** the VM in VirtualBox (or export OVA to `Backups\`).
2. Create a **new** virtual disk; install Kali with LUKS on that disk **or** attach new disk and `dd`/clone after encrypted install on spare volume.
3. Validate boot + SSH + `/mnt/ctg` share; delete old disk only after a week of stable lab use.

---

## VirtualBox VM encryption (recommended for existing **kali** VM)

VirtualBox 7 **full VM encryption** protects the VM configuration, saved state, and related data at the hypervisor layer. This is the **safe path** for an existing CTG Kali VM â€” **not** in-place `cryptsetup luksFormat` on the running root disk.

### When to use

| Layer | Protects against |
|-------|------------------|
| **BitLocker (Windows host)** | Stolen laptop, offline access to `C:` and `Backups\` |
| **VBox full VM encryption** | Someone copies the VM folder or `.vdi` off the host without the VM password |
| **LUKS inside Kali (fresh install)** | Guest disk at rest inside the image; use installer **Encrypted LVM** |

Use **host BitLocker + VBox VM encryption** for CTG laptops. Add **LUKS at install** only on new gold images or spare disks.

### CTG script (existing VM â€” interactive password)

Diagnose only (safe for automation / agents):

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\Encrypt-KaliVm.ps1 -DiagnoseOnly
```

Encrypt (Administrator PowerShell â€” **you** type the password; never commit or log it):

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\Encrypt-KaliVm.ps1 -Apply -BackupFirst
```

- Requires **Oracle VM VirtualBox Extension Pack** (version must match VirtualBox).
- VM must be **powered off** (script ACPI-stops **kali** when applying).
- Cipher: **AES-256** (VirtualBox selects GCM/XTS per component â€” not a separate CLI flag).
- Password ID default: `ctg-kali` â€” store passphrase in **DuckDuckGo Password Manager** only.
- Log: `%USERPROFILE%\Backups\logs\encrypt-kali-vm.log` (no secrets).
- Optional backup: `%USERPROFILE%\Backups\vm-backup-kali\<timestamp>\`
- **Time:** often **15â€“60+ minutes** depending on disk size; do not interrupt.
- **Lost VM password = lost VM** â€” BitLocker does not unlock VirtualBox encryption.

After encrypting, if VirtualBox Manager shows **Inaccessible**, register the password:

```powershell
cd "C:\Program Files\Oracle\VirtualBox"
```

```powershell
.\VBoxManage.exe encryptvm kali addpassword --password-id ctg-kali --password -
```

### Fresh install: Kali installer Encrypted LVM

On a **new** VM or spare disk, use the Kali/Debian installer option **Guided - use entire disk with encrypted LVM**. Do **not** run `cryptsetup luksFormat` on an existing booted root without reinstall.

### NOT safe: in-place LUKS on live root

**Do not** run `cryptsetup luksFormat` on the current `/` of a running CTG Kali VM â€” it breaks boot. Use VBox encryption above or reinstall with Encrypted LVM.

### Manual GUI (optional)

VirtualBox Manager may expose encryption on some builds; Oracle 7.x often requires **VBoxManage** for existing VMs. See Oracle User Guide â€” *Encryption of VMs*.

### CLI reference

```powershell
cd "C:\Program Files\Oracle\VirtualBox"
```

```powershell
.\VBoxManage.exe list vms
```

```powershell
.\VBoxManage.exe encryptvm kali setencryption --cipher=AES-256 --new-password-id ctg-kali --new-password -
```

Passwords belong in **Backups\.vault\** or password manager â€” **never** in git (`Backups/kali-vm-vbox-password.txt` is gitignored).

### CTG integration

- `Deploy-KaliLab.ps1` / `Install-KaliVirtualBox.ps1` do **not** enable VBox encryption automatically (avoids lockout without documented password).
- `Encrypt-KaliVm.ps1` never logs or commits the encryption password.
- Document VM name and password location in your **local** lab journal only.

---

## Comparison table

| Method | Boot impact | CTG automation |
|--------|-------------|----------------|
| Windows BitLocker | TPM unlock at boot | `Enable-BitLockerSafe.ps1 -Apply` |
| VirtualBox full VM encryption | VM password when starting **kali** | `Encrypt-KaliVm.ps1 -Apply` (interactive) |
| LUKS in guest (fresh install) | Passphrase at initramfs | **Guide only** â€” no in-place on live VM |

---

## References

- [KALI_LAB_ARCHITECTURE.md](KALI_LAB_ARCHITECTURE.md) â€” VM sizing, snapshots
- [SECRET_VAULT.md](SECRET_VAULT.md) â€” PII and credential storage
- [DEVICE_ENCRYPTION.md](DEVICE_ENCRYPTION.md) â€” Windows host
