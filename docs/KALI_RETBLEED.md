# RETBleed on Kali (VirtualBox) — professor notes

**Hacker Planet LLC / CyberThreatGotchi** — authorized defensive lab documentation.  
**Companion:** [PASSWORD_HARDENING.md](PASSWORD_HARDENING.md) · [KALI_LAB_ARCHITECTURE.md](KALI_LAB_ARCHITECTURE.md)

---

## What you are seeing

**RETBleed** (CVE-2022-29900 / CVE-2022-29901) is a **Spectre v2–class** side-channel issue affecting certain **Intel** (Core 6–8th gen) and **AMD** (Zen 1–3) CPUs when **Return Trampoline (Retpoline)** mitigations are incomplete. At boot, the Linux kernel logs lines such as:

```text
Spectre v2 / RETBleed: WARNING: Spectre v2 mitigation leaves CPU vulnerable to RETBleed attacks, data leaks possible!
```

This is the kernel honestly reporting that **retpoline-style mitigations alone may not fully cover RETBleed** on vulnerable microarchitectures until **CPU microcode + kernel** are current and mitigations are enabled.

### Blue team framing

| Layer | Responsibility |
|-------|----------------|
| **Host (Windows)** | BIOS/firmware update, Intel/AMD chipset drivers, Windows Update — microcode reaches the **physical CPU** |
| **VirtualBox** | Guest sees **host CPU features**; the VM does not get separate silicon microcode |
| **Kali guest** | `intel-microcode` / `amd64-microcode` packages, kernel `full-upgrade`, **never** `mitigations=off` |
| **Detection** | `/var/log/ctg-retbleed.log`, `dmesg`, `/sys/devices/system/cpu/vulnerabilities/*` |

### Red team awareness (lab only)

Side-channel bugs are not “remote code execution,” but in **multi-tenant or shared-kernel** scenarios they inform **threat models** for sensitive workloads. In Andy’s **single-user lab VM**, the practical risk is **information disclosure** if untrusted code runs on the same core — treat the VM as **lab isolation**, not a multi-tenant hypervisor.

---

## Root cause on Andy's VirtualBox setup (the real fix)

The boot **"RET error"** is the kernel line:

```text
Spectre v2: WARNING: Spectre v2 mitigation leaves CPU vulnerable to RETBleed attacks, data leaks possible!
```

On the **Intel Core i9-8950HK (Coffee Lake)** host this is a **RETBleed-affected** family. Inside the
VirtualBox guest the kernel can only fall back to **retpoline** because, by default, **VirtualBox does not
expose the `IA32_SPEC_CTRL` / `IA32_PRED_CMD` MSRs** to the guest. Retpoline alone is **insufficient for
RETBleed** on these microarchitectures, so the kernel honestly prints the warning.

This is **not** `mitigations=off` and **not** a misconfigured GRUB — verified on this VM:

- `VBoxManage showvminfo kali` → `cpu-profile="host"`, **no `SpectreControl` attribute** = `--spec-ctrl off` (default)
- `kali.vbox` `<CPU count="4">` block has **no `SpectreControl="true"`**

### The host-side fix — expose the spec-ctrl MSRs to the guest

`modifyvm` requires the **VM powered off**. From the Windows host, one command per block:

```powershell
.\scripts\windows\Harden-KaliVmCpu.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Harden-KaliVmCpu.ps1 -StopVmIfRunning -StartAfter
```

That helper performs (idempotently, VM off):

```text
VBoxManage modifyvm kali --spec-ctrl on        # IA32_SPEC_CTRL + IA32_PRED_CMD to guest (IBRS/IBPB)
VBoxManage modifyvm kali --ibpb-on-vm-exit on  # IBPB barrier on VM exit  (RETBleed-relevant)
VBoxManage modifyvm kali --ibpb-on-vm-entry on # IBPB barrier on VM entry
```

`-FullCpuMitigations` additionally sets `--l1d-flush-on-vm-entry on` and `--mds-clear-on-vm-entry on`
(L1TF / MDS — also Coffee Lake-affected; small extra overhead).

> **Host microcode is still primary.** `--spec-ctrl on` lets the guest *use* IBRS/IBPB, but the silicon
> fix is current **Windows Update + OEM BIOS microcode** for Coffee Lake. The VM cannot manufacture
> microcode the host never loaded.

---

## CTG automation

Scripts (staged to `C:\Users\Owner\Backups` via `Stage-KaliLabToBackups.ps1`):

| Script | Purpose |
|--------|---------|
| `scripts/windows/Harden-KaliVmCpu.ps1` | **Host fix** — `VBoxManage modifyvm --spec-ctrl on` (VM off); diagnose/apply/restart |
| `scripts/kali/fix-retbleed-mitigation.sh` | Diagnose + optional apply (microcode, kernel upgrade, GRUB audit); recommends host spec-ctrl |
| `scripts/kali/kali-boot-autopatch.sh` | Calls RETBleed diagnose on every boot; `--retbleed` for full apply |
| `scripts/windows/Deploy-KaliBootAutopatch.ps1` | Stops VM, applies `--spec-ctrl on` (unless `-NoSpecCtrlHardening`), deploys autopatch |

**Logs:** `/var/log/ctg-retbleed.log` (guest, before/after) · `C:\Users\Owner\Backups\logs\harden-kali-vm-cpu.log` (host)

### Kali commands (in VM)

Diagnose only:

```bash
sudo bash /mnt/ctg/fix-retbleed-mitigation.sh --diagnose-only
```

Apply mitigations (microcode + kernel upgrade):

```bash
sudo bash /mnt/ctg/fix-retbleed-mitigation.sh --apply
```

Boot autopatch with RETBleed apply + upgrade:

```bash
sudo bash /mnt/ctg/kali-boot-autopatch.sh --retbleed --upgrade
```

---

## GRUB / kernel parameters

| Parameter | CTG policy |
|-----------|------------|
| `mitigations=off` | **Forbidden** — removes Spectre/Meltdown/RETBleed defenses |
| `retbleed=off` | Avoid — disables RETBleed-specific mitigation |
| `retbleed=auto` | Documented option; kernel default is usually `auto` — only set explicitly if you need audit clarity |

After GRUB edits: `sudo update-grub` and reboot.

Check running kernel:

```bash
cat /proc/cmdline
grep -i retbleed /sys/devices/system/cpu/vulnerabilities/* 2>/dev/null
```

---

## VirtualBox-specific notes

1. **Expose spec-ctrl to the guest (the usual cause of the warning).** With the VM **off**, run
   `VBoxManage modifyvm kali --spec-ctrl on` (or `Harden-KaliVmCpu.ps1 -StopVmIfRunning -StartAfter`).
   Without it the guest never sees `IA32_SPEC_CTRL`/`IA32_PRED_CMD` and is stuck on retpoline-only.
2. **Host microcode matters.** Updating Kali alone cannot fix silicon the host never exposes. Run **Windows Update** and **OEM BIOS updates** on the laptop.
2. **Guest Additions / headers** — `kali-boot-autopatch.sh` already installs VBox guest packages; unrelated to RETBleed but stabilizes boot.
3. **Warning may persist** even after best-effort fixes if:
   - Host BIOS/microcode is still behind vendor guidance for your CPU generation
   - VirtualBox passes through CPU flags that still report vulnerable RETBleed state
   - Kernel logs a **conservative warning** while mitigations are partially active

**Acceptable lab posture:** warnings in `dmesg` with `mitigations=off` **absent**, microcode installed, kernel current, no untrusted multi-tenant workloads on the same host.

---

## Manual verification checklist

```
[ ] VirtualBox: kali --spec-ctrl on (Harden-KaliVmCpu.ps1 -DiagnoseOnly reports "spec-ctrl: on")
[ ] Host Windows: latest BIOS + cumulative updates
[ ] Kali: intel-microcode OR amd64-microcode installed (dpkg -l)
[ ] Kali: apt full-upgrade; reboot if /var/run/reboot-required
[ ] /proc/cmdline: no mitigations=off
[ ] /var/log/ctg-retbleed.log: BEFORE/AFTER sections captured
[ ] Vulnerabilities sysfs: document state (Mitigation: ... vs Vulnerable)
```

### Verify in Kali after reboot

```bash
cat /sys/devices/system/cpu/vulnerabilities/retbleed
cat /sys/devices/system/cpu/vulnerabilities/spectre_v2
grep . /sys/devices/system/cpu/vulnerabilities/*
cat /proc/cmdline
dmesg | grep -i -E 'retbleed|spectre|mitigat'
sudo bash /mnt/ctg/fix-retbleed-mitigation.sh --diagnose-only
```

With `--spec-ctrl on` the `spectre_v2` line should report an **IBRS/retpoline + IBPB** mitigation and the
RETBleed warning should be absent or downgraded (kernel/microcode dependent).

---

## References

- [Intel RETBleed guidance](https://www.intel.com/content/www/us/en/developer/articles/technical/software-security-guidance/advisory-guidance/retbleed.html)
- [AMD security bulletins](https://www.amd.com/en/corporate/product-security/bulletin)
- Linux kernel docs: `Documentation/admin-guide/hw-vuln/` (retbleed, spectre)

**Authorized use:** systems you own — Hacker Planet lab VLAN.
