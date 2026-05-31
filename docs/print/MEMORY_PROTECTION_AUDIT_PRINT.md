# Memory protection audit — printable checklist

**Hacker Planet LLC / CyberThreatGotchi** · Dell Precision 5530 + Kali VM · **no secrets on this page**

**Full refs:** [../MEMORY_PROTECTION.md](../MEMORY_PROTECTION.md) · [../RAM_MITIGATION_IPS.md](../RAM_MITIGATION_IPS.md) · [../KALI_RETBLEED_SPECTRE.md](../KALI_RETBLEED_SPECTRE.md) · [../SECRET_VAULT.md](../SECRET_VAULT.md)

---

## PRESERVE — policy (never disable for VM speed)

- [ ] **Memory integrity (HVCI)** stays **On** — do not disable for VirtualBox
- [ ] **VBS** stays enabled — CTG rejects performance tuning that disables hypervisor-backed security
- [ ] **Guest `--spec-ctrl on`** — never `--spec-ctrl off` on Kali VM
- [ ] **Guest `mitigations=auto`** — never `mitigations=off`
- [ ] DuckDuckGo VPN/DNS unchanged on Windows host — [DUCKDUCKGO_PRESERVE_PRINT.md](DUCKDUCKGO_PRESERVE_PRINT.md)

---

## Windows — HVCI / VBS / spec-ctrl

### Manual (Settings)

- [ ] Settings → Privacy & security → Windows Security → Device security
- [ ] Core isolation → **Memory integrity → On**
- [ ] Reboot if toggled; note date: ___________

### Diagnose scripts

```powershell
cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
```

```powershell
.\scripts\windows\Enforce-CtgMemoryProtection.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Harden-KaliVmCpu.ps1 -DiagnoseOnly
```

Checklist from diagnose output:

- [ ] VBS reported enabled (or documented why not on this build)
- [ ] HVCI / Memory integrity **On**
- [ ] DEP / ASLR / SpeculationControl module loaded
- [ ] RETBleed class noted — microcode + guest mitigations path documented
- [ ] Kernel DMA protection — verify in `msinfo32` if applicable

### Apply (Admin only — after review)

- [ ] `-ApplySafe` reviewed — reboot may be required
- [ ] Weekly task: `Register-CtgMemoryProtectionTask.ps1 -UseSecretVault`

---

## Kali guest — RETBleed / ram enforcer

VM must be **off** on host before spec-ctrl changes.

- [ ] Host applied `--spec-ctrl on` via `Harden-KaliVmCpu.ps1`
- [ ] Guest rebooted after change

In Kali:

```bash
bash /mnt/ctg/ctg-retbleed-check.sh
```

```bash
bash /mnt/ctg/ctg-ram-mitigation-enforcer.sh --diagnose-only
```

- [ ] `/sys/devices/system/cpu/vulnerabilities/retbleed` not **Vulnerable**
- [ ] Optional cryptswap documented — `--setup-cryptswap` only if chosen
- [ ] Snort/Suricata noted as **network IDS** — not RAM side-channel blockers

---

## Vault session TTL (memory-adjacent)

Secrets in RAM during unlock — limit exposure.

- [ ] `Ctg-CredentialVault.ps1 -InitVault` done once (interactive)
- [ ] Default **15-minute idle lock** (or `CTG_VAULT_SESSION_TTL` documented)
- [ ] `-LockVault` after SOC session
- [ ] No master password on this sheet — see [VAULT_SECRETS_AUDIT_PRINT.md](VAULT_SECRETS_AUDIT_PRINT.md)

---

## Honest limits (check understanding)

- [ ] Snort/Suricata do **not** block RETBleed / Spectre class attacks
- [ ] No user-mode tool "encrypts all RAM" — layered OS + firmware + hypervisor only
- [ ] VirtualBox may show **green turtle** with VBS — acceptable per CTG policy

---

## End-of-session VERIFY

- [ ] Diagnose log saved under `%USERPROFILE%\Backups\logs\`
- [ ] No mitigation disable steps taken for convenience
- [ ] Windows DDG VPN/DNS unchanged (stack audit BEFORE/AFTER)

---

**Footer:** Hacker Planet LLC · CyberThreatGotchi · NIST CSF PR.IP-12 · CIS Control 7 · no passwords on paper
