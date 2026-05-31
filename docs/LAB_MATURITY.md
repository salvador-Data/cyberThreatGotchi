# CTG lab maturity rubric (NIST CSF aligned)

Authorized defensive lab use — **Hacker Planet LLC**. Self-assessment **1–10** per domain; target **8–9/10** for production-like SOC practice.

**Related:** [CTG_NEXT_STEPS.md](CTG_NEXT_STEPS.md) · [SECURITY_HARDENING.md](SECURITY_HARDENING.md) · [EMAIL_NOTIFICATIONS.md](EMAIL_NOTIFICATIONS.md) · [LAB_VLAN.md](LAB_VLAN.md)

---

## Scoring guide

| Score | Meaning |
|-------|---------|
| 1–3 | Ad hoc — no scripts, no logs |
| 4–5 | Partial — some controls, manual only |
| 6–7 | Repeatable — scripts + docs, gaps in segmentation/restore |
| **8–9** | **Lab-grade — automated diagnose, vault secrets, quarterly drills, SIEM path** |
| 10 | Enterprise fleet — MDM, dedicated VLAN hardware, 24/7 SOC (optional for home lab) |

---

## NIST CSF mapping

### Identify (ID)

| Control | CTG artifact | Target |
|---------|--------------|--------|
| Asset inventory | [KALI_LAB_ARCHITECTURE.md](KALI_LAB_ARCHITECTURE.md), VM snapshots | 8 |
| Risk assessment | [LAB_VLAN.md](LAB_VLAN.md), flat-network diagnose | 8 |

**Script:** `Test-CtgLabNetworkSegment.ps1 -DiagnoseOnly`

### Protect (PR)

| Control | CTG artifact | Target |
|---------|--------------|--------|
| EDR / endpoint | `Harden-CtgWindowsDefender.ps1`, ASR audit | 8 |
| Mobile | [IPHONE_HARDENING.md](IPHONE_HARDENING.md), supervision checklist | 8 |
| Secrets | [SECRET_VAULT.md](SECRET_VAULT.md), `Ctg-CredentialVault.ps1` | 9 |
| Network segment | VLAN template `lab-vlan.conf.example` | 8 |

**Scripts:** `Install-CtgDefenderEdr.ps1`, `Export-CtgIosProfileChecklist.ps1`, `Test-CtgCisBenchmarkDiagnose.ps1`

### Detect (DE)

| Control | CTG artifact | Target |
|---------|--------------|--------|
| Host telemetry | Sysmon, Defender | 8 |
| Network IDS | Snort/Suricata loops | 8 |
| Central log sink | Wazuh lab stack | 8 |
| Email alerts | [EMAIL_NOTIFICATIONS.md](EMAIL_NOTIFICATIONS.md) | 8 |

**Scripts:** `Install-CtgWazuhLab.ps1`, `Start-CtgEmailNotifyBridge.ps1`, `ctg-email-notify.sh`

### Respond (RS)

| Control | CTG artifact | Target |
|---------|--------------|--------|
| Alert routing | `Send-CtgIdsAlert.ps1` (Signal) | 8 |
| SSH brute-force | Kali `ctg-fail2ban-ssh-stub.sh` | 7 |

### Recover (RC)

| Control | CTG artifact | Target |
|---------|--------------|--------|
| Backups | `ctg_nightly_4am.ps1`, selective SSD | 8 |
| Restore drill | `Invoke-CtgRestoreDrill.ps1` | 9 |
| Golden image | `Snapshot-CtgKaliGolden.ps1` | 8 |

**Task:** `Register-CtgRestoreDrillTask.ps1` (quarterly)

---

## Commercial EDR (informational — no endorsement)

Built-in **Microsoft Defender** with ASR + cloud protection is the CTG default (`Harden-CtgWindowsDefender.ps1`). For MSP/customer engagements or higher assurance:

| Product class | Role | Notes |
|---------------|------|-------|
| **Microsoft Defender for Endpoint** | EDR + M365 integration | Natural fit if you adopt Entra/Intune |
| **CrowdStrike Falcon** | Cloud EDR | Common enterprise SOC choice |
| **SentinelOne** | Autonomous EDR | Strong rollback narrative |
| **Elastic Defend** | Open-core + Elastic stack | Pairs with self-hosted SIEM |
| **Wazuh** | OSS SIEM + lightweight agents | CTG lab default sink — `Install-CtgWazuhLab.ps1` |

Evaluate on **authorized lab VMs first**. None replace network segmentation or backup restore drills.

---

## Quick maturity commands (DiagnoseOnly)

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

---

## Golden Kali workflow

1. Run `CLICK-ME-RUN-IN-KALI.sh` until lab chain succeeds.
2. Windows: `Snapshot-CtgKaliGolden.ps1 -ApplySafe -VmName Kali`
3. Restore: `VBoxManage snapshot "Kali" restore "ctg-golden-YYYYMMDD"`

---

## Snort/Suricata → Wazuh (lab)

Forward JSON alert files from Windows IDS loops to Wazuh via Filebeat or custom `localfile` in agent `ossec.conf`. Paths are host-local — see [KALI_SIEM_STACK.md](KALI_SIEM_STACK.md) and Wazuh docs. No alert payloads with PII in git.
