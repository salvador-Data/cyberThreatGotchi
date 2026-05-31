# DuckDuckGo preserve — DO NOT CHANGE (print)

**Hacker Planet LLC / CyberThreatGotchi** · **no secrets on this page**

Run this verify **before and after** every CTG hardening session on Windows or iPhone.

**Full policy:** [../SECURITY_HARDENING.md](../SECURITY_HARDENING.md) · Script: `Preserve-DuckDuckGoVpn.ps1`

---

## DO NOT CHANGE

- [ ] **DuckDuckGo VPN / Privacy Pro** — do not remove, replace, or stack a second DNS VPN
- [ ] **Wi‑Fi Configure DNS** — do not point away from baseline unless intentional IT change
- [ ] **DuckDuckGo Password Manager (Autofill)** — do not disable for hardening
- [ ] **No competing clients** — do not install Cloudflare WARP, NextDNS app, or Malwarebytes **paid VPN**

---

## Windows — verify steps

Baseline notes (fill by hand):

```
DDG VPN connected at start: Y / N     at end: Y / N
Wi‑Fi DNS on adapter (if any): _________________________
Date: ___________
```

- [ ] DuckDuckGo VPN process running (or intentionally off — note above)
- [ ] DuckDuckGo WireGuard tunnel adapter **Up** when VPN should be connected
- [ ] CTG scripts did **not** change Wi‑Fi adapter DNS (`Repair-WindowsWifi -DiagnoseOnly` only unless approved)
- [ ] Browse + ping familiar host — no new DNS breakage

From repo root:

```powershell
cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
```

```powershell
.\scripts\windows\Preserve-DuckDuckGoVpn.ps1
```

Stack audit (DDG BEFORE/AFTER in log):

```powershell
.\scripts\windows\Invoke-CtgPrintAllAudit.ps1
```

Log: `%USERPROFILE%\Backups\logs\ctg-print-all-audit-*.txt`

---

## iPhone — verify steps

- [ ] Settings → General → VPN & Device Management → VPN — DuckDuckGo profile **unchanged**
- [ ] Settings → Wi‑Fi → ⓘ → Configure DNS — **unchanged** from baseline
- [ ] Settings → General → AutoFill & Passwords → DuckDuckGo Autofill → **On**
- [ ] Malwarebytes paid VPN → **OFF** (SMS/Safari extensions OK)

**Print checklist:** [../IPHONE_AUDIT_PRINT.md](../IPHONE_AUDIT_PRINT.md)

---

## CTG script policy (all platforms)

- [ ] `CTG_PRESERVE_DUCKDUCKGO_VPN=1` honored by deploy / SOC / nightly scripts
- [ ] No CTG script installs a second VPN client
- [ ] Defender exclusions for DDG paths only — not a DNS override

---

**Footer:** Hacker Planet LLC · CyberThreatGotchi · preserve DuckDuckGo VPN/DNS/PM · no passwords · no tokens in git
