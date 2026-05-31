# CTG complete audit bundle — combined print

**Hacker Planet LLC / CyberThreatGotchi** · single print job · **no secrets**

Use `---` page breaks when printing from Markdown. For browser print with forced breaks, use [PRINT_ALL.html](PRINT_ALL.html).

Individual sheets: [README_PRINT_ALL.md](README_PRINT_ALL.md)

---

<div style="page-break-after: always"></div>

# Section 0 — DuckDuckGo PRESERVE

See full sheet: [DUCKDUCKGO_PRESERVE_PRINT.md](DUCKDUCKGO_PRESERVE_PRINT.md)

- [ ] DuckDuckGo VPN — do not remove or replace
- [ ] Wi‑Fi DNS — unchanged from baseline
- [ ] DuckDuckGo Password Manager autofill — stay On
- [ ] No Cloudflare WARP / NextDNS / MB paid VPN stacked

Baseline: DDG start Y/N ___ end Y/N ___ Date ___

---

<div style="page-break-after: always"></div>

# Section 1 — Windows SOC

See full sheet: [../WINDOWS_SOC_AUDIT_PRINT.md](../WINDOWS_SOC_AUDIT_PRINT.md)

```powershell
.\scripts\windows\Invoke-CtgPrintAllAudit.ps1
```

- [ ] Preserve-DuckDuckGoVpn BEFORE/AFTER in log
- [ ] Enforce-CtgMemoryProtection -DiagnoseOnly
- [ ] Harden-CtgWindowsDefender -DiagnoseOnly
- [ ] Detect-CtgWifiJam / Harden-DDoSRogueWifi -DiagnoseOnly
- [ ] Initialize-CtgEmailVault -DiagnoseOnly
- [ ] Nightly 4 AM task registered
- [ ] DDG unchanged at end

---

<div style="page-break-after: always"></div>

# Section 2 — iPhone 15 Pro Max

See full sheet: [../IPHONE_AUDIT_PRINT.md](../IPHONE_AUDIT_PRINT.md)

- [ ] Phase 0 baseline: VPN + DNS + DDG Autofill documented
- [ ] Phase 1 Settings (1.1–1.11) complete
- [ ] Phase 1 VERIFY before Phase 2
- [ ] Phase 2 Malwarebytes SMS/Safari only — MB VPN OFF
- [ ] End VERIFY: VPN + DNS + Autofill unchanged

---

<div style="page-break-after: always"></div>

# Section 3 — Memory protection

See: [MEMORY_PROTECTION_AUDIT_PRINT.md](MEMORY_PROTECTION_AUDIT_PRINT.md)

- [ ] HVCI / Memory integrity On — never disable for VirtualBox
- [ ] Enforce-CtgMemoryProtection.ps1 -DiagnoseOnly
- [ ] Harden-KaliVmCpu.ps1 -DiagnoseOnly — spec-ctrl on
- [ ] Kali: ctg-retbleed-check.sh + ram enforcer --diagnose-only
- [ ] Vault -LockVault after session

---

<div style="page-break-after: always"></div>

# Section 4 — Vault & secrets

See: [VAULT_SECRETS_AUDIT_PRINT.md](VAULT_SECRETS_AUDIT_PRINT.md)

- [ ] Ctg-CredentialVault.ps1 -InitVault (once, interactive)
- [ ] Titles: Kali SSH, Proton IMAP (hand-entered only)
- [ ] Initialize-CtgEmailVault.ps1 -DiagnoseOnly
- [ ] No secrets on paper

---

<div style="page-break-after: always"></div>

# Section 5 — GitHub & email

See: [GITHUB_EMAIL_AUDIT_PRINT.md](GITHUB_EMAIL_AUDIT_PRINT.md)

- [ ] GitHub notifications → Proton (failures only)
- [ ] Proton filter folder GitHub-CTG
- [ ] Start-CtgEmailNotifyBridge.ps1 -Once -UseSecretVault -GithubOnly

---

<div style="page-break-after: always"></div>

# Section 6 — UTMS Wi‑Fi AI

See: [UTMS_WIFI_AUDIT_PRINT.md](UTMS_WIFI_AUDIT_PRINT.md)

- [ ] Event bus Start-CtgEventBus.ps1 tested
- [ ] Jam/deauth detect — NOT counter-jam
- [ ] Threat pack OTA to Backups\ctg-utms-broadcast
- [ ] Cardputer bridge client documented
- [ ] Lab AP --diagnose; --apply only with --i-understand-lab-only

---

<div style="page-break-after: always"></div>

# Section 7 — Kali lab

See: [KALI_LAB_AUDIT_PRINT.md](KALI_LAB_AUDIT_PRINT.md)

- [ ] CLICK-ME-RUN-IN-KALI.sh success
- [ ] Display scale + seamless docs reviewed
- [ ] RETBleed check not Vulnerable
- [ ] ctg-deauth-watch --diagnose
- [ ] a$k --help and lab-targets gate

---

<div style="page-break-after: always"></div>

# Section 8 — Lab maturity (NIST CSF)

See: [LAB_MATURITY_AUDIT_PRINT.md](LAB_MATURITY_AUDIT_PRINT.md)

| Domain | Score /10 |
|--------|-----------|
| Identify | ___ |
| Protect | ___ |
| Detect | ___ |
| Respond | ___ |
| Recover | ___ |

Target: 8–9/10 lab-grade

---

**Footer:** Hacker Planet LLC · CyberThreatGotchi · combined print bundle · preserve DuckDuckGo VPN/DNS/PM
