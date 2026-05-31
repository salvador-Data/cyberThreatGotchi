# Windows SOC audit — printable verify (Dell Precision 5530)

**Hacker Planet LLC / CyberThreatGotchi** · Andy's Windows SOC laptop · **no secrets on this page**

Print and check off after running diagnose scripts. **Preserve DuckDuckGo VPN/DNS** — no competing VPN installs.

**Scripts catalog:** [SCRIPTS_CATALOG.md](SCRIPTS_CATALOG.md) · **Memory:** [MEMORY_PROTECTION.md](MEMORY_PROTECTION.md)

---

## PRESERVE — DuckDuckGo stack (before and after every run)

- [ ] DuckDuckGo VPN process running (or intentionally off — note baseline)
- [ ] DuckDuckGo WireGuard tunnel adapter **Up** when VPN should be connected
- [ ] Wi‑Fi adapter DNS **not changed** by CTG scripts (DDG DNS on adapter or via VPN tunnel)
- [ ] No Cloudflare WARP / NextDNS client installed by CTG

**Baseline notes:**

```
DDG VPN connected at start: Y / N     at end: Y / N
Wi‑Fi DNS servers (if any on adapter): _________________________
Date: ___________
```

---

## One-shot stack audit (Windows)

From repo root:

```powershell
cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
```

```powershell
.\scripts\windows\Invoke-CtgPreserveStackAudit.ps1
```

Log: `%USERPROFILE%\Backups\logs\ctg-stack-audit-YYYYMMDD-HHmmss.txt` (gitignored)

Optional safe Defender apply (Admin, after reviewing diagnose):

```powershell
.\scripts\windows\Invoke-CtgPreserveStackAudit.ps1 -ApplySafeDefender
```

---

## Checklist — defensive layers

### DuckDuckGo preserve

- [ ] `Preserve-DuckDuckGoVpn.ps1` — Defender exclusions for DDG paths; tunnel status logged
- [ ] `Repair-WindowsWifi.ps1 -DiagnoseOnly` — **no DNS server changes**; flush only if `-ApplyFixes`

### Memory protection (HVCI / VBS)

- [ ] Settings → Privacy & security → Windows Security → Device security → Core isolation → **Memory integrity On**
- [ ] `Enforce-CtgMemoryProtection.ps1 -DiagnoseOnly` — VBS/HVCI/DEP/SpeculationControl reported
- [ ] **Never** disable HVCI/VBS for VirtualBox speed (CTG policy)

### Credential vault

- [ ] `Initialize-CtgEmailVault.ps1 -DiagnoseOnly` — vault / IMAP titles documented (no secrets in log)
- [ ] `Ctg-CredentialVault.ps1 -InitVault` done once per machine (interactive — not in git)

### Defender EDR baseline

- [ ] `Harden-CtgWindowsDefender.ps1 -DiagnoseOnly` — real-time protection, cloud, PUA, ASR audit
- [ ] `-ApplySafe` (Admin) only after reviewing ASR audit lines

### Network / rogue Wi‑Fi / jam detect

- [ ] `Harden-DDoSRogueWifi.ps1 -DiagnoseOnly` — firewall + rogue AP posture
- [ ] `Detect-CtgWifiJam.ps1 -DiagnoseOnly` — deauth/jam heuristics (detect-only)
- [ ] `Test-CtgLabNetworkSegment.ps1 -DiagnoseOnly` — VLAN / lab segment hints

### IDS / SIEM (detect-only)

- [ ] Sysmon installed (`harden_windows.ps1` / SOC run log)
- [ ] `Start-CTGWiresharkIDS.ps1 -DiagnoseOnly` or Suricata/Snort task registered
- [ ] Wazuh agent — only if `CTG_WAZUH_MANAGER` set

### Nightly / backup

- [ ] `HackerPlanet-CTG-Nightly-4AM` scheduled (Interactive + Highest — no password in task XML)
- [ ] Backups under `C:\Users\Owner\Backups` and OneDrive `Backups\` (D: when SSD online)

---

## Admin-only items (document if skipped)

| Item | Script | Notes |
|------|--------|-------|
| Wi‑Fi `-ApplyFixes` | `Repair-WindowsWifi.ps1` | Only if diagnose shows issues **and** DDG preserve passes |
| Defender `-ApplySafe` | `Harden-CtgWindowsDefender.ps1` | ASR audit first |
| Memory `-ApplySafe` | `Enforce-CtgMemoryProtection.ps1` | Reboot may be required |
| CPU `-ApplySafe` | `Optimize-CpuPerformance.ps1` | `Run-AsAdmin.ps1` wrapper |
| DDoS apply | `Harden-DDoSRogueWifi.ps1 -ApplyHardening` | Review diagnose log first |

---

## VERIFY — end of Windows session

- [ ] DuckDuckGo VPN/DNS **unchanged** from baseline (compare log BEFORE/AFTER sections)
- [ ] Browse + ping familiar host — no new DNS breakage
- [ ] Stack audit log saved under `Backups\logs\`
- [ ] Admin-skipped items noted in [CTG_NEXT_STEPS.md](CTG_NEXT_STEPS.md)

---

**Footer:** Hacker Planet LLC · CyberThreatGotchi · Precision 5530 · no passwords · no tokens in git
