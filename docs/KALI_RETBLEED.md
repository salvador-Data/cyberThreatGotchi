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

## CTG automation

Scripts (staged to `C:\Users\Owner\Backups` via `Stage-KaliLabToBackups.ps1`):

| Script | Purpose |
|--------|---------|
| `scripts/kali/fix-retbleed-mitigation.sh` | Diagnose + optional apply (microcode, kernel upgrade, GRUB audit) |
| `scripts/kali/kali-boot-autopatch.sh` | Calls RETBleed diagnose on every boot; `--retbleed` for full apply |

**Log:** `/var/log/ctg-retbleed.log` (before/after snapshots)

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

1. **Host microcode matters.** Updating Kali alone cannot fix silicon the host never exposes. Run **Windows Update** and **OEM BIOS updates** on the laptop.
2. **Guest Additions / headers** — `kali-boot-autopatch.sh` already installs VBox guest packages; unrelated to RETBleed but stabilizes boot.
3. **Warning may persist** even after best-effort fixes if:
   - Host BIOS/microcode is still behind vendor guidance for your CPU generation
   - VirtualBox passes through CPU flags that still report vulnerable RETBleed state
   - Kernel logs a **conservative warning** while mitigations are partially active

**Acceptable lab posture:** warnings in `dmesg` with `mitigations=off` **absent**, microcode installed, kernel current, no untrusted multi-tenant workloads on the same host.

---

## Manual verification checklist

```
[ ] Host Windows: latest BIOS + cumulative updates
[ ] Kali: intel-microcode OR amd64-microcode installed (dpkg -l)
[ ] Kali: apt full-upgrade; reboot if /var/run/reboot-required
[ ] /proc/cmdline: no mitigations=off
[ ] /var/log/ctg-retbleed.log: BEFORE/AFTER sections captured
[ ] Vulnerabilities sysfs: document state (Mitigation: ... vs Vulnerable)
```

---

## References

- [Intel RETBleed guidance](https://www.intel.com/content/www/us/en/developer/articles/technical/software-security-guidance/advisory-guidance/retbleed.html)
- [AMD security bulletins](https://www.amd.com/en/corporate/product-security/bulletin)
- Linux kernel docs: `Documentation/admin-guide/hw-vuln/` (retbleed, spectre)

**Authorized use:** systems you own — Hacker Planet lab VLAN.
