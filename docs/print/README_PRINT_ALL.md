# CTG print-all audit — master index

**Hacker Planet LLC / CyberThreatGotchi** · complete printable bundle · **no secrets on any sheet**

---

## PRESERVE FIRST — DuckDuckGo VPN / DNS / Password Manager

**Do not change** during any audit in this bundle:

- DuckDuckGo VPN / Privacy Pro (Windows + iPhone)
- Wi‑Fi Configure DNS baseline
- DuckDuckGo Password Manager autofill

Print and run: **[DUCKDUCKGO_PRESERVE_PRINT.md](DUCKDUCKGO_PRESERVE_PRINT.md)** before and after every session.

---

## Run order (recommended)

| Step | Where | Print doc | Automatable |
|------|-------|-----------|-------------|
| 0 | All | [DUCKDUCKGO_PRESERVE_PRINT.md](DUCKDUCKGO_PRESERVE_PRINT.md) | Partial (Windows script) |
| 1 | Windows SOC | [../WINDOWS_SOC_AUDIT_PRINT.md](../WINDOWS_SOC_AUDIT_PRINT.md) | `Invoke-CtgPrintAllAudit.ps1` |
| 2 | iPhone (manual) | [../IPHONE_AUDIT_PRINT.md](../IPHONE_AUDIT_PRINT.md) | Checklist only |
| 3 | Memory / HVCI | [MEMORY_PROTECTION_AUDIT_PRINT.md](MEMORY_PROTECTION_AUDIT_PRINT.md) | Diagnose scripts |
| 4 | Vault / secrets | [VAULT_SECRETS_AUDIT_PRINT.md](VAULT_SECRETS_AUDIT_PRINT.md) | Interactive init |
| 5 | GitHub + email | [GITHUB_EMAIL_AUDIT_PRINT.md](GITHUB_EMAIL_AUDIT_PRINT.md) | Bridge `-GithubOnly` |
| 6 | UTMS Wi‑Fi AI | [UTMS_WIFI_AUDIT_PRINT.md](UTMS_WIFI_AUDIT_PRINT.md) | Jam detect diagnose |
| 7 | Kali lab | [KALI_LAB_AUDIT_PRINT.md](KALI_LAB_AUDIT_PRINT.md) | CLICK-ME in guest |
| 7b | Gatekeeper.TOR | [GATEKEEPER_TOR_PRINT.md](GATEKEEPER_TOR_PRINT.md) | Lit tray = active mode |
| 8 | Lab maturity | [LAB_MATURITY_AUDIT_PRINT.md](LAB_MATURITY_AUDIT_PRINT.md) | NIST self-score |

---

## One command — print-all audit (Windows)

From repo root:

```powershell
cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
```

```powershell
.\scripts\windows\Invoke-CtgPrintAllAudit.ps1
```

Open print folder in Explorer:

```powershell
.\scripts\windows\Invoke-CtgPrintAllAudit.ps1 -OpenPrintFolder
```

Log: `%USERPROFILE%\Backups\logs\ctg-print-all-audit-YYYYMMDD-HHmmss.txt`

Optional Defender apply (Admin, after ASR review):

```powershell
.\scripts\windows\Invoke-CtgPrintAllAudit.ps1 -ApplySafeDefender
```

---

## All print files (this bundle)

| File | Domain |
|------|--------|
| [README_PRINT_ALL.md](README_PRINT_ALL.md) | This index |
| [DUCKDUCKGO_PRESERVE_PRINT.md](DUCKDUCKGO_PRESERVE_PRINT.md) | DDG DO NOT CHANGE |
| [../IPHONE_AUDIT_PRINT.md](../IPHONE_AUDIT_PRINT.md) | iPhone 15 Pro Max |
| [../WINDOWS_SOC_AUDIT_PRINT.md](../WINDOWS_SOC_AUDIT_PRINT.md) | Windows SOC |
| [KALI_LAB_AUDIT_PRINT.md](KALI_LAB_AUDIT_PRINT.md) | Kali VM lab |
| [GATEKEEPER_TOR_PRINT.md](GATEKEEPER_TOR_PRINT.md) | Gatekeeper.TOR tray (lit icon) |
| [MEMORY_PROTECTION_AUDIT_PRINT.md](MEMORY_PROTECTION_AUDIT_PRINT.md) | HVCI / RETBleed |
| [UTMS_WIFI_AUDIT_PRINT.md](UTMS_WIFI_AUDIT_PRINT.md) | Event bus / jam detect |
| [LAB_MATURITY_AUDIT_PRINT.md](LAB_MATURITY_AUDIT_PRINT.md) | NIST CSF worksheet |
| [VAULT_SECRETS_AUDIT_PRINT.md](VAULT_SECRETS_AUDIT_PRINT.md) | Credential vault |
| [GITHUB_EMAIL_AUDIT_PRINT.md](GITHUB_EMAIL_AUDIT_PRINT.md) | Proton / GitHub-CTG |
| [PRINT_ALL_COMBINED.md](PRINT_ALL_COMBINED.md) | Single long print job |
| [PRINT_ALL.html](PRINT_ALL.html) | Browser print with page breaks |

---

## Combined print (one job)

**Markdown:** open [PRINT_ALL_COMBINED.md](PRINT_ALL_COMBINED.md) → print to PDF.

**HTML (page breaks):** open [PRINT_ALL.html](PRINT_ALL.html) in browser → Ctrl+P → Save as PDF.

---

## Full documentation cross-links

- [IPHONE_HARDENING.md](../IPHONE_HARDENING.md)
- [MEMORY_PROTECTION.md](../MEMORY_PROTECTION.md)
- [UTMS_WIFI_AI.md](../UTMS_WIFI_AI.md)
- [LAB_MATURITY.md](../LAB_MATURITY.md)
- [SECRET_VAULT.md](../SECRET_VAULT.md)
- [GITHUB_NOTIFICATIONS.md](../GITHUB_NOTIFICATIONS.md)
- [SCRIPTS_CATALOG.md](../SCRIPTS_CATALOG.md)
- [CTG_NEXT_STEPS.md](../CTG_NEXT_STEPS.md)

---

**Footer:** Hacker Planet LLC · CyberThreatGotchi · print-all audit bundle · authorized defensive lab use
