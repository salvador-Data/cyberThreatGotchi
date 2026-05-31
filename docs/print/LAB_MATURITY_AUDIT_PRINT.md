# Lab maturity audit — NIST CSF self-score (print)

**Hacker Planet LLC / CyberThreatGotchi** · self-assessment **1–10** · target **8–9/10** · **no secrets on this page**

**Full rubric:** [../LAB_MATURITY.md](../LAB_MATURITY.md) · [../CTG_NEXT_STEPS.md](../CTG_NEXT_STEPS.md)

---

## Scoring guide

| Score | Meaning |
|-------|---------|
| 1–3 | Ad hoc — no scripts, no logs |
| 4–5 | Partial — some controls, manual only |
| 6–7 | Repeatable — scripts + docs, gaps remain |
| **8–9** | **Lab-grade — automate diagnose, vault, drills, SIEM path** |
| 10 | Enterprise fleet — optional for home lab |

Date: ___________  Reviewer: ___________

---

## NIST CSF worksheet (fill scores 1–10)

### Identify (ID)

- [ ] Asset inventory (VMs, Cardputer, iPhone, repos) — score: ___ / 10
- [ ] Risk assessment (flat network, VLAN plan) — score: ___ / 10
- Script: `Test-CtgLabNetworkSegment.ps1 -DiagnoseOnly`

### Protect (PR)

- [ ] EDR / Windows Defender + ASR — score: ___ / 10
- [ ] Mobile hardening (iPhone checklist) — score: ___ / 10
- [ ] Secrets vault (no git secrets) — score: ___ / 10
- [ ] Network segment / VLAN — score: ___ / 10

### Detect (DE)

- [ ] Host telemetry (Sysmon, Defender) — score: ___ / 10
- [ ] Network IDS (Snort/Suricata) — score: ___ / 10
- [ ] SIEM sink (Wazuh lab) — score: ___ / 10
- [ ] Email / GitHub alert path — score: ___ / 10

### Respond (RS)

- [ ] Alert routing (Signal deduped) — score: ___ / 10
- [ ] SSH brute-force (fail2ban stub) — score: ___ / 10

### Recover (RC)

- [ ] Nightly backups (4 AM task) — score: ___ / 10
- [ ] Restore drill quarterly — score: ___ / 10
- [ ] Golden Kali snapshot — score: ___ / 10

---

## Quick diagnose commands (Windows)

Run from repo root — one command per block:

```powershell
cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
```

```powershell
.\scripts\windows\Harden-CtgWindowsDefender.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Test-CtgLabNetworkSegment.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Install-CtgWazuhLab.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Invoke-CtgRestoreDrill.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Test-CtgCisBenchmarkDiagnose.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Initialize-CtgEmailVault.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Invoke-CtgPrintAllAudit.ps1
```

---

## Gap notes (handwritten)

```
Lowest domain: _________________________  Target date: ___________
Blockers: _______________________________________________________
Admin-only skips: ________________________________________________
```

---

## PRESERVE — DuckDuckGo during maturity sprint

- [ ] DDG VPN/DNS/PM verified — [DUCKDUCKGO_PRESERVE_PRINT.md](DUCKDUCKGO_PRESERVE_PRINT.md)

---

**Footer:** Hacker Planet LLC · CyberThreatGotchi · NIST CSF aligned · no passwords on paper
