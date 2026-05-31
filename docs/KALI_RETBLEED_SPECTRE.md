# Kali VirtualBox â€” Spectre v2 / RETBleed (`--spec-ctrl`)

**Hacker Planet LLC / CyberThreatGotchi** â€” authorized defensive lab documentation.

**Full context:** [KALI_RETBLEED.md](KALI_RETBLEED.md) Â· **Host helper:** `scripts/windows/Harden-KaliVmCpu.ps1` (alias `Harden-KaliVmSpectre.ps1`)

---

## Problem

On RETBleed-affected host CPUs (e.g. Intel Coffee Lake **i9-8950HK**), a Kali guest may log:

```text
Spectre v2: WARNING: Spectre v2 mitigation leaves CPU vulnerable to RETBleed attacks, data leaks possible!
```

When VirtualBox does **not** expose `IA32_SPEC_CTRL` / `IA32_PRED_CMD` to the guest, the kernel cannot use **IBRS/IBPB** and falls back to retpoline â€” insufficient for RETBleed on these cores.

This is **not** `mitigations=off`. Never disable kernel mitigations in GRUB.

---

## Host fix (Windows, VM powered off)

Diagnose:

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\Harden-KaliVmSpectre.ps1 -DiagnoseOnly
```

Apply (graceful ACPI shutdown + modifyvm + optional restart):

```powershell
.\scripts\windows\Harden-KaliVmSpectre.ps1 -StopVmIfRunning -StartAfter
```

Equivalent VirtualBox flags (idempotent):

```text
VBoxManage modifyvm kali --spec-ctrl on
VBoxManage modifyvm kali --ibpb-on-vm-exit on
VBoxManage modifyvm kali --ibpb-on-vm-entry on
```

Optional extra barriers (Coffee Lake L1TF/MDS): `-FullCpuMitigations` on the helper script.

**Primary mitigation remains host BIOS + Windows Update microcode** for the physical CPU.

---

## Guest verify (after reboot)

Quick readout:

```bash
bash /mnt/ctg/ctg-retbleed-check.sh
```

Full diagnose + GRUB audit:

```bash
sudo bash /mnt/ctg/fix-retbleed-mitigation.sh --diagnose-only
```

Manual:

```bash
cat /sys/devices/system/cpu/vulnerabilities/retbleed
cat /sys/devices/system/cpu/vulnerabilities/spectre_v2
```

Logs: `/var/log/ctg-retbleed.log` Â· host `C:\Users\Owner\Backups\logs\harden-kali-vm-cpu.log`

---

## Staging

Copy to shared folder via `Stage-KaliLabToBackups.ps1` / `Deploy-KaliBootAutopatch.ps1` so `/mnt/ctg/` has `ctg-retbleed-check.sh` and this doc.