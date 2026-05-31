# Device encryption â€” Windows SOC + Kali lab VM

Authorized defensive use on **systems you own** (Hacker Planet LLC lab / Andy workstation). Goal: encrypt data at rest **without** breaking boot or committing secrets to git.

| Layer | Status / tool |
|-------|----------------|
| **Windows host (`C:`)** | BitLocker via `Enable-BitLockerSafe.ps1` (TPM + recovery key in `Backups\.vault\`) |
| **Kali VirtualBox VM (`kali`)** | Full VM encryption via `Encrypt-KaliVm.ps1` â€” see [KALI_DISK_ENCRYPTION.md](KALI_DISK_ENCRYPTION.md) |

## Quick commands

Diagnose (no Administrator required for most checks):

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\Enable-BitLockerSafe.ps1
```

Apply (Administrator â€” saves recovery key under `%USERPROFILE%\Backups\.vault\` only):

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\Enable-BitLockerSafe.ps1 -Apply
```

Type `YES` at the confirmation prompt unless you passed `-Force`.

## What the script does

| Mode | Behavior |
|------|----------|
| **Default / `-DiagnoseOnly`** | Reports TPM, Secure Boot, BitLocker volume status, `manage-bde` summary (recovery lines redacted), boot/WinRE hints, apply blockers |
| **`-Apply`** | Enables BitLocker on `C:` with **XtsAes256**, **UsedSpaceOnly**, **TPM protector**, adds **recovery password**, writes key file to `Backups\.vault\` with user-only ACL. Does **not** print the recovery password to the console |

## Prerequisites (blue team)

1. **TPM 2.0** enabled and **ready** in firmware (Intel/AMD platform trust).
2. **Secure Boot** on (UEFI) â€” recommended; script warns if unavailable.
3. **Windows edition** â€” BitLocker management is fully available on Pro / Enterprise / Education. Home may use **Device Encryption** instead; diagnose output explains SKU.
4. **Backup** â€” recent SOC backup (`ctg_nightly_4am.ps1`, `Backups\`) before `-Apply`.
5. **Recovery key storage** â€” file in `.vault\` plus DuckDuckGo Password Manager or offline copy (see [SECRET_VAULT.md](SECRET_VAULT.md)).

## Boot safety

- Uses **`-SkipHardwareTest`** to avoid an extra pre-encryption reboot cycle; you still reboot normally after encryption starts.
- Does **not** encrypt non-OS drives automatically.
- If volume is **already encrypted**, `-Apply` only archives an existing recovery protector or adds one â€” it does not re-encrypt from scratch.
- **Dual-boot** (Linux/macOS): do not `-Apply` until you understand bootloader interaction; keep a printed recovery key.

## Recovery key files

Path pattern:

```text
%USERPROFILE%\Backups\.vault\bitlocker-recovery-<COMPUTER>-<timestamp>.txt
```

These paths are **gitignored** (`.vault/`, `Backups/.vault/`, `bitlocker-recovery*.txt`). Never commit, SMS, or paste recovery passwords into chat or git.

## Kali VM (VirtualBox **kali**)

Diagnose (no password, no disk changes):

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\Encrypt-KaliVm.ps1 -DiagnoseOnly
```

Encrypt interactively (you type the VM password; optional folder backup):

```powershell
.\scripts\windows\Encrypt-KaliVm.ps1 -Apply -BackupFirst
```

Do **not** use in-place LUKS on a running Kali root â€” use VBox encryption or reinstall with Encrypted LVM ([KALI_DISK_ENCRYPTION.md](KALI_DISK_ENCRYPTION.md)).

## Related docs

| Topic | Doc |
|-------|-----|
| Kali VBox + LUKS policy | [KALI_DISK_ENCRYPTION.md](KALI_DISK_ENCRYPTION.md) |
| DPAPI lab secrets | [SECRET_VAULT.md](SECRET_VAULT.md) |
| VirtualBox VM encryption | [KALI_DISK_ENCRYPTION.md#virtualbox-vm-encryption-recommended-for-existing-kali-vm](KALI_DISK_ENCRYPTION.md#virtualbox-vm-encryption-recommended-for-existing-kali-vm) |
| Windows hardening orchestrator | `scripts/windows/harden_windows.ps1` |

## NIST / CIS mapping (defensive)

| Control | Implementation |
|---------|----------------|
| **PR.DS-1** (data-at-rest) | BitLocker on OS volume |
| **PR.PT-3** (access to removable media) | Separate policy for USB backups â€” encrypt backup disk if portable |
| **CIS 3.6** | Encrypt data on end-user devices |

## Troubleshooting

| Symptom | Action |
|---------|--------|
| TPM not ready | Enable TPM in BIOS; clear/initialize TPM only if you have recovery key |
| BitLocker cmdlets missing | Confirm Windows Pro/Enterprise or use Settings â†’ Privacy & security â†’ Device encryption on Home |
| Apply blocked â€” encryption in progress | Wait for `manage-bde -status` to show 100% |
| Forgot unlock at boot | Use 48-digit recovery password from `.vault\` file or DDG PM entry |

## Run log (2026-05-31 — DESKTOP-G88VH3D)

Authorized lab host encryption session via `Enable-BitLockerSafe.ps1`. **No recovery keys in this doc.**

| Volume | Hardware | Before | After (session) |
|--------|----------|--------|-----------------|
| **C:** (OS) | Internal PM981 NVMe ~512 GB, NTFS | Fully decrypted, protection off, 0% | BitLocker **enabled** (XtsAes256, UsedSpaceOnly, TPM + recovery password); encryption may still be **in progress** until `manage-bde -status C:` shows 100% |
| **D:** (label SSD) | External SDK SSD USB ~125 GiB, exFAT | Not BitLocker-managed | **Unchanged** — script default is OS volume only; use BitLocker To Go separately if portable encryption is required (consider NTFS for full policy alignment) |
| **Q:** | Empty mount | N/A | Not targeted |

**Diagnose (non-elevated):** Admin false; TPM reported not ready; volume query access denied.

**Apply (elevated UAC):** Admin true; TPM ready/enabled/owned; Secure Boot reported off; WinRE enabled. Recovery key file written under `%USERPROFILE%\Backups\.vault\` (gitignored). Reboot when convenient for TPM unlock validation.

**Kali VM:** `Encrypt-KaliVm.ps1 -DiagnoseOnly` — VM `kali` not registered in VirtualBox (no VM disk encryption this session).

**Follow-up:** Run elevated `manage-bde -status C:` until fully encrypted; optional `-MountPoint D:` / BitLocker To Go for external SSD; enable Secure Boot when lab policy allows; store recovery copy in DuckDuckGo Password Manager per [SECRET_VAULT.md](SECRET_VAULT.md).
