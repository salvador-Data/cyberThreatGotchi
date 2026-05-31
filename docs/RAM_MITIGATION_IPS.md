# RAM mitigation "IPS" — honest scope (Hacker Planet LLC)

**Authorized defensive lab use only.** CyberThreatGotchi uses the term **RAM IPS** for a **Host Exploit Mitigation Enforcer**, not a network intrusion prevention system.

## Professor honesty (mandatory)

Network IPS (**Snort**, **Suricata**, OPNsense) inspects **packets on the wire**. It **cannot block** Spectre, **RETBleed**, Meltdown, MDS, L1TF, or other **RAM/CPU speculative side-channel** classes. Those flaws are mitigated on the **host** with **microcode**, **OS/kernel patches**, **VirtualBox CPU flags** for lab VMs, and **Core isolation (HVCI)** — not with IDS rules.

When CTG detects exposure, **Signal alerts** (via `Send-CtgIdsAlert.ps1`) tell you to run `Update-CtgExploitMitigations.ps1` and guest checks — the same alert path as network IDS, but the **control** is host patching, not packet drop.

## RAM CVE class → network IPS vs host mitigation

| RAM / CPU class | Examples | Blocked by Snort/Suricata IPS? | Host mitigation (CTG) |
|-----------------|----------|--------------------------------|------------------------|
| Branch target / return stack | **Spectre v2**, **RETBleed** (Intel SA-00702) | **No** | Windows Update + BIOS microcode; Kali `linux-image` + `intel-microcode`; VBox `--spec-ctrl on` |
| Bounds / store bypass | Spectre v1, Speculative Store Bypass | **No** | Kernel mitigations (`mitigations=auto`); security apt |
| Meltdown / MDS / L1TF | Meltdown, MDS, L1TF, SRBDS | **No** | Same — microcode + kernel; guest `/sys/.../vulnerabilities/*` |
| Memory integrity | Kernel code injection (related hardening) | **No** | Windows **Memory integrity / HVCI**; DEP + ASLR baseline |

## Framework mapping

| Framework | Relevance |
|-----------|-----------|
| **NIST CSF — Protect (PR.IP, PR.DS)** | Patch management, platform integrity, vulnerability management for CPU flaws |
| **Intel SA-00702 (RETBleed)** | Microcode + OS updates for affected Intel cores; primary reference for Coffee Lake–class lab hosts |
| **CIS Control 7** | Continuous vulnerability management — WU scan, CISA KEV cache, guest apt security list |

Split repo for hardening-only consumers: [salvador-Data/ctg-device-hardening](https://github.com/salvador-Data/ctg-device-hardening) (sync via `Sync-CtgDeviceHardeningRepo.ps1`).

## Windows SOC scripts

| Script | Role |
|--------|------|
| `scripts/windows/Enforce-CtgRamMitigations.ps1` | **RAM IPS enforcer**: `-DiagnoseOnly`, `-ApplySafe`, `-Monitor` + Signal alert |
| `scripts/windows/Register-CtgRamMitigationTask.ps1` | Weekly/at-logon scheduled `-Monitor` (Interactive + Highest) |
| `scripts/windows/Update-CtgExploitMitigations.ps1` | WU scan + Kali VM spec-ctrl diagnose (delegates extended RAM check to Enforce) |
| `scripts/windows/Harden-KaliVmCpu.ps1` | VirtualBox `--spec-ctrl on` for Kali guest MSRs |
| `scripts/windows/CTG-AuditAutorun.ps1` | Optional `-RamMitigationCheck` compartment in audit runs |

### Admin commands (one per block)

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\Enforce-CtgRamMitigations.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Enforce-CtgRamMitigations.ps1 -ApplySafe
```

```powershell
.\scripts\windows\Enforce-CtgRamMitigations.ps1 -Monitor -UseSecretVault
```

```powershell
.\scripts\windows\Register-CtgRamMitigationTask.ps1 -UseSecretVault
```

```powershell
.\scripts\windows\CTG-AuditAutorun.ps1 -AuditOnly -RamMitigationCheck
```

## Kali guest

```bash
bash /mnt/ctg/ctg-ram-mitigation-enforcer.sh
```

```bash
sudo bash /mnt/ctg/ctg-ram-mitigation-enforcer.sh --apply-safe
```

```bash
sudo bash /mnt/ctg/ctg-ram-mitigation-enforcer.sh --apply-safe --apply
```

Exit **non-zero** if any `/sys/devices/system/cpu/vulnerabilities/*` entry contains **Vulnerable** — suitable for CTG audit hooks.

## Related docs

- [SECURITY_HARDENING.md](SECURITY_HARDENING.md) — IDS vs CPU side-channel table
- [KALI_RETBLEED_SPECTRE.md](KALI_RETBLEED_SPECTRE.md) — VirtualBox + guest verification
- [SIGNAL_ALERTS.md](SIGNAL_ALERTS.md) — Signal-first alert routing

## Author

[Hacker Planet LLC](https://salvador-Data.github.io/cyberThreatGotchi/) · Philadelphia, PA
