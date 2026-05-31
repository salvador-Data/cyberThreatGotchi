# CTG one working orchestrator

**Hacker Planet LLC** · authorized defensive lab · Andy Kowal

Single entry point for the full Windows SOC diagnose pipeline. Use this instead of running five separate audit scripts by hand.

**Related:** [CYBERSECURITY_ETHICS.md](CYBERSECURITY_ETHICS.md) · [CTG_NEXT_STEPS.md](CTG_NEXT_STEPS.md) · [print/PRINT_ALL.html](print/PRINT_ALL.html)

---

## What it does

`Invoke-CtgOneWorking.ps1` runs in order:

| Step | Script | Purpose |
|------|--------|---------|
| 1 | `Preserve-DuckDuckGoVpn.ps1` + `Repair-WindowsWifi.ps1 -DiagnoseOnly` | DDG VPN/DNS preserve; Wi-Fi read-only |
| 2 | `Invoke-CtgInstallAudit.ps1` | INSTALLED / PENDING / MANUAL / OPTIONAL table |
| 3 | `Invoke-CtgPreserveStackAudit.ps1` | Defender, memory, DDoS, email vault, VLAN batch |
| 4 | `Invoke-CtgPrintAllAudit.ps1 -SkipStackAudit` | List print paths (no duplicate stack work) |
| 5 | `Enforce-CtgMemoryProtection.ps1 -DiagnoseOnly` | HVCI/VBS/spec-ctrl — do not regress |
| 6 | `Stage-KaliLabToBackups.ps1` | CLICK-ME + Kali tree → `C:\Users\Owner\Backups` |
| 7 | Summary | Console + `%USERPROFILE%\Backups\logs\ctg-one-working-*.txt` |

**Never automated:** Wi-Fi `-ApplyFixes` without DDG OK, guest-flash loops, mitigation disable, competing VPN installs.

---

## When to run

- **Before** claiming something is installed in chat or docs
- **After** Admin task registration, vault init, Docker/Wazuh, or Kali staging
- **Weekly** lab hygiene (DiagnoseOnly is safe anytime)
- **Before** print-audit sessions — add `-OpenPrintFolder`

---

## Commands

Canonical repo:

```powershell
cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
```

Diagnose only (default):

```powershell
.\scripts\windows\Invoke-CtgOneWorking.ps1
```

Safe applies (pip + staging):

```powershell
.\scripts\windows\Invoke-CtgOneWorking.ps1 -ApplySafe
```

Open print folder after run:

```powershell
.\scripts\windows\Invoke-CtgOneWorking.ps1 -OpenPrintFolder
```

Install audit alone (source of truth for component list):

```powershell
.\scripts\windows\Invoke-CtgInstallAudit.ps1 -Json
```

---

## Admin manual block

Run each in its **own** elevated PowerShell when ready — not from One Working:

| Task | Command |
|------|---------|
| Nightly 4 AM | `.\scripts\windows\Register-CtgNightlyTask.ps1` |
| CPU optimize | `.\scripts\windows\Register-CtgCpuOptimizeTask.ps1` |
| Memory protection task | `.\scripts\windows\Register-CtgMemoryProtectionTask.ps1` |
| Defender ASR | `.\scripts\windows\Harden-CtgWindowsDefender.ps1 -ApplySafe` |
| Wi-Fi repair | `.\scripts\windows\Repair-WindowsWifi.ps1 -ApplyFixes` *(only when Wi-Fi up + DDG OK)* |
| Vault init | `.\scripts\windows\Ctg-CredentialVault.ps1 -InitVault -WithDpapiWrap` |
| Wazuh stack | `.\scripts\windows\Install-CtgWazuhLab.ps1 -ApplySafe` |

---

## Print bundle

- **Combined HTML:** [print/PRINT_ALL.html](print/PRINT_ALL.html)
- **Index:** [print/README_PRINT_ALL.md](print/README_PRINT_ALL.md)
- **Script:** `Invoke-CtgPrintAllAudit.ps1 -OpenPrintFolder`

---

## Cursor rule

Merged agent memory: `.cursor/rules/ctg-one-working.mdc` (canonical path, DDG preserve, HVCI, ethics, vault, install audit).

---

## Ethics

All CTG work assumes **authorized lab use** on Andy-owned systems. See [CYBERSECURITY_ETHICS.md](CYBERSECURITY_ETHICS.md) for ISC2/ACM/NIST references and refusal policy.
