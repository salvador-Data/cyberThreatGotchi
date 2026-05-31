# Memory protection — threat model, hypervisor stack, honest limits

**Hacker Planet LLC / CyberThreatGotchi** — authorized defensive lab use on **owned** systems only (Dell Precision 5530 SOC, Kali VM in VirtualBox).

**Companion:** [RAM_MITIGATION_IPS.md](RAM_MITIGATION_IPS.md) (operational scripts) · [SECRET_VAULT.md](SECRET_VAULT.md) (credential session TTL) · [KALI_RETBLEED_SPECTRE.md](KALI_RETBLEED_SPECTRE.md)

---

## Professor honesty — what this is NOT (no snake oil)

| Claim | Reality |
|-------|---------|
| “Encrypt all RAM” user-mode tool | **False.** No application can encrypt every byte of physical RAM. OS + firmware + hypervisor layers bound exposure. |
| Snort/Suricata “RAM IPS” | **Misleading.** Network IPS inspects **packets**, not CPU speculative side-channels or kernel memory layout. |
| Disable HVCI/VBS for VirtualBox speed | **Rejected by CTG policy.** Microsoft documents that Memory integrity and Credential Guard **depend on Hyper-V**; disabling them trades measurable security for convenience ([Microsoft Learn — virtualization apps and Hyper-V](https://learn.microsoft.com/en-us/troubleshoot/windows-client/application-management/virtualization-apps-not-work-with-hyper-v)). |
| `--spec-ctrl off` on Kali VM | **Never.** Guest RETBleed/Spectre v2 mitigations require host `VBoxManage modifyvm kali --spec-ctrl on` ([VirtualBox manual — speculation control](https://www.virtualbox.org/manual/ch08.html#settings-cpu)). |

CTG **memory protection** = layered **host + guest + vault** controls: microcode, kernel mitigations, **VBS/HVCI**, Kernel DMA protection, VirtualBox guest MSR exposure, encrypted swap (opt-in), vault session lock/TTL.

---

## Threat model (blue team)

| Layer | Threat | CTG control | Framework |
|-------|--------|-------------|-----------|
| **CPU speculative** | Spectre v2, **RETBleed** (Intel [SA-00702](https://www.intel.com/content/www/us/en/security-center/advisory/intel-sa-00702.html)) | Windows Update + BIOS microcode; Kali `linux-image` + `intel-microcode`; VBox `--spec-ctrl on` | NIST CSF **PR.IP-12**, CIS **7** |
| **Kernel integrity** | Unsigned/vulnerable drivers, W^X violations | **Memory integrity (HVCI)** inside VBS ([Microsoft VBS](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-vbs)) | NIST CSF **PR.DS-6** |
| **Credential theft** | Pass-the-hash, LSASS scraping | **Credential Guard** (optional on standalone Pro; default domain Win11 22H2+) ([Credential Guard](https://learn.microsoft.com/en-us/windows/security/identity-protection/credential-guard/)) | CIS **16** |
| **DMA** | Thunderbolt/PCIe pre-boot DMA | **Kernel DMA protection** + IOMMU/VT-d ([VBS hardware requirements](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-vbs)) | NIST CSF **PR.AC-5** |
| **Swap bleed** | Secrets paged to disk | Kali **cryptswap** (opt-in); vault **lock + TTL** | CIS **3.11** |
| **Network** | Exploit delivery | Snort/Suricata **detect-only** — complementary, not substitute | NIST CSF **DE.CM** |

**Red team awareness (lab only):** Side-channel and memory attacks are chained *after* initial access — defense-in-depth assumes breach and limits blast radius (HVCI, least privilege, vault TTL).

---

## Dell Precision 5530 / Win11 Pro — what applies

| Feature | Hardware (i9-8950HK, Coffee Lake) | CTG note |
|---------|-----------------------------------|----------|
| **VBS / HVCI (Memory integrity)** | Intel 8th gen — eligible on Win11 ([HVCI enablement](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-hvci-enablement)) | Enable via Settings → Device security → Core isolation; reboot required |
| **Credential Guard** | Same VBS stack | Optional on standalone Pro; not required for lab |
| **Kernel DMA protection** | Requires VT-d/IOMMU in firmware | Verify in `msinfo32` → Kernel DMA Protection |
| **RETBleed** | Affected class — microcode + guest IBRS/IBPB | Host `Harden-KaliVmCpu.ps1`; guest `/sys/.../retbleed` |

---

## Hypervisor-backed security vs “performance tuning”

Microsoft’s Windows hypervisor backs **Memory integrity**, **Credential Guard**, and related **Device Guard** scenarios. Third-party hypervisors (VirtualBox) compete for **VT-x/AMD-V** with that stack ([Microsoft troubleshooting](https://learn.microsoft.com/en-us/troubleshoot/windows-client/application-management/virtualization-apps-not-work-with-hyper-v)).

**CTG policy (mandatory):**

1. **Never** disable Memory integrity, VBS, or HVCI for VirtualBox performance.
2. **Never** set `mitigations=off` (guest) or `--spec-ctrl off` (host VM).
3. Accept VirtualBox **emulated (green turtle)** mode if VBS is running — lab security over raw VM speed.
4. Expose **spec-ctrl MSRs** to Kali so guest kernel can apply IBRS/IBPB ([KALI_RETBLEED_SPECTRE.md](KALI_RETBLEED_SPECTRE.md)).

VirtualBox 7.x exposes speculation control to guests when the host sets:

```text
VBoxManage modifyvm kali --spec-ctrl on
```

Warnings on Linux guest boot come from the **guest kernel**, not VirtualBox ([VirtualBox forum — spectre/retbleed message](https://forums.virtualbox.org/viewtopic.php?t=107984)).

---

## Windows scripts

| Script | Role |
|--------|------|
| `Enforce-CtgRamMitigations.ps1` | Primary enforcer: `-DiagnoseOnly`, `-ApplySafe`, `-Monitor` |
| `Enforce-CtgMemoryProtection.ps1` | Alias wrapper (same parameters) |
| `Register-CtgMemoryProtectionTask.ps1` | Weekly audit + Signal on regression |
| `Register-CtgRamMitigationTask.ps1` | Same task registrar (legacy name) |
| `Harden-KaliVmCpu.ps1` | `--spec-ctrl on`, nested paging diagnose |
| `Ctg-CredentialVault.ps1` | Vault session; `-LockVault` on idle |

### Diagnose (one command per block)

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\Enforce-CtgMemoryProtection.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Register-CtgMemoryProtectionTask.ps1 -UseSecretVault
```

---

## Kali guest

```bash
bash /mnt/ctg/ctg-ram-mitigation-enforcer.sh --diagnose-only
```

```bash
sudo bash /mnt/ctg/ctg-ram-mitigation-enforcer.sh --setup-cryptswap
```

```bash
sudo bash /mnt/ctg/ctg-ram-mitigation-enforcer.sh --setup-cryptswap --apply
```

Integrated into `kali-boot-autopatch.sh` (diagnose only) and `RUN-KALI-LAB-NOW.sh` verify phase.

**Encrypted swap:** random key per boot via `/etc/crypttab` ([Debian cryptsetup README](https://cryptsetup-team.pages.debian.net/cryptsetup/README.Debian.html)). Disables hibernate/resume to swap.

**mlock:** `mlock(2)` pins pages but does not replace encrypted swap or vault lock ([man mlock](https://man7.org/linux/man-pages/man2/mlock.2.html)).

---

## Credential vault memory hygiene

| Control | Default | Override |
|---------|---------|----------|
| Session TTL | 900 s (15 min) | `$env:CTG_VAULT_SESSION_TTL` |
| Idle lock | `-LockVault` | Scripts should lock after credential fetch |
| Buffer zero | Best-effort in CLI | Python `str` immutable; see [SECRET_VAULT.md](SECRET_VAULT.md#session-timeout-and-memory-limits) |
| VirtualLock (Windows) | Not used in CTG | Native API only; documented limitation |

---

## Research sources (cited)

| Topic | URL |
|-------|-----|
| VBS overview | https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-vbs |
| Memory integrity / HVCI | https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-hvci-enablement |
| Credential Guard | https://learn.microsoft.com/en-us/windows/security/identity-protection/credential-guard/ |
| Hyper-V vs VirtualBox | https://learn.microsoft.com/en-us/troubleshoot/windows-client/application-management/virtualization-apps-not-work-with-hyper-v |
| Intel RETBleed SA-00702 | https://www.intel.com/content/www/us/en/security-center/advisory/intel-sa-00702.html |
| Debian encrypted swap | https://cryptsetup-team.pages.debian.net/cryptsetup/README.Debian.html |
| dm-crypt swap (ArchWiki) | https://wiki.archlinux.org/title/Dm-crypt/Swap_encryption |
| NIST Cybersecurity Framework | https://www.nist.gov/cyberframework |
| CIS Controls v8 | https://www.cisecurity.org/controls |

---

## Author

[Hacker Planet LLC](https://salvador-Data.github.io/cyberThreatGotchi/) · Philadelphia, PA
