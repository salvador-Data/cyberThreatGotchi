# Windows Snort IDS + SMS alerts — CyberThreatGotchi SOC

**Authorized defensive use only** on networks and hosts you own or are explicitly permitted to monitor.

## Honest scope (blue team)

| Capability | Windows Snort stack | Recommended production |
|------------|---------------------|------------------------|
| Network IDS | Snort **2.9.x** detect-only on Npcap interface | **Suricata on OPNsense** (perimeter) |
| Snort 3 | **Not available** on Windows (roadmap item) | Kali / Linux / OPNsense |
| SMS alerts | Twilio via local `.env` / DPAPI vault | Same |
| IPS inline block | **Not in this stack** — detect + alert only | OPNsense Suricata blocking mode |
| Fallback | `-UseWiresharkFallback` → tshark heuristics | Wireshark IDS doc |

Windows host IDS complements — it does not replace — **Suricata-primary** on Kali (`ctg-ids-ips-autorun.sh`) or OPNsense. See [KALI_IDS_IPS_CLAMAV.md](KALI_IDS_IPS_CLAMAV.md) and [WIRESHARK_IDS_SMS.md](WIRESHARK_IDS_SMS.md).

## Why Snort 2.9 on Windows (not Snort 3)

Cisco Snort 3 targets Linux with CMake/DDAQ builds. The official Windows path remains **Snort 2.9.x installer + Npcap**. Chocolatey carries a legacy 2.9.14.1 package; newer 2.9.17 builds come from [snort.org/downloads](https://www.snort.org/downloads). If Snort install is impractical, use `-UseWiresharkFallback` or the Wireshark IDS stack.

## Prerequisites

1. **Windows 11 Pro** (or Enterprise/Education) on your SOC laptop
2. **Npcap** — install via Wireshark or [npcap.com](https://npcap.com/) (WinPcap-compatible mode)
3. **Snort 2.9.x Windows** — manual installer from snort.org (or `choco install snort` legacy package)
4. **Community rules** — free account at snort.org → rule downloads → extract to `Backups\ctg-snort\rules\`

## Environment variables (local `.env` only — never commit)

Add to `C:\Users\Owner\Projects\cyberThreatGotchi\.env` (gitignored):

```env
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_FROM_NUMBER=+1xxxxxxxxxx
CTG_ALERT_SMS_TO=+1XXXXXXXXXX
```

Replace `+1XXXXXXXXXX` with your mobile in E.164 format. **Prefer** DPAPI vault for the phone number:

```powershell
.\scripts\windows\Protect-CtgSecrets.ps1 -SetPii -Name CTG_PII_PHONE
```

Then use `Send-CtgSmsAlert.ps1 -UseSecretVault` (Start-CtgSnortIDS uses `.env` by default; vault is available on the SMS script).

## Install (Administrator PowerShell — one command per block)

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\Install-WiresharkNpcap.ps1
```

Install Snort 2.9.x from [snort.org/downloads](https://www.snort.org/downloads) to `C:\Snort` (default), then:

```powershell
.\scripts\windows\Install-CtgSnortWindows.ps1
```

Optional Chocolatey attempt (legacy 2.9.14.1):

```powershell
.\scripts\windows\Install-CtgSnortWindows.ps1 -InstallViaChocolatey
```

Diagnose only:

```powershell
.\scripts\windows\Install-CtgSnortWindows.ps1 -DiagnoseOnly
```

## Configure rules

```powershell
.\scripts\windows\Start-CtgSnortIDS.ps1 -ApplyRules
```

This deploys `Backups\ctg-snort\etc\snort.conf` and syncs rules from `C:\Snort\rules` when present.

## Start monitoring

Diagnose Snort + Twilio env:

```powershell
.\scripts\windows\Start-CtgSnortIDS.ps1 -DiagnoseOnly
```

Run Snort IDS for 2 hours on interface 3 (from `snort -W`):

```powershell
.\scripts\windows\Start-CtgSnortIDS.ps1 -RunMinutes 120 -Interface 3
```

Continuous loop (lab hours):

```powershell
.\scripts\windows\ctg_snort_ids_loop.ps1 -CycleMinutes 60
```

Wireshark fallback when Snort binary missing:

```powershell
.\scripts\windows\Start-CtgSnortIDS.ps1 -UseWiresharkFallback -RunMinutes 15
```

## SMS test (no attack traffic)

```powershell
.\scripts\windows\Start-CtgSnortIDS.ps1 -TestAlert
```

Or directly:

```powershell
.\scripts\windows\Send-CtgSmsAlert.ps1 -TestMessage
```

## Scheduled task (logon, Interactive + Highest)

Register continuous Snort loop at user logon:

```powershell
.\scripts\windows\Register-CtgSnortIdsTask.ps1
```

With Wireshark fallback if Snort not installed:

```powershell
.\scripts\windows\Register-CtgSnortIdsTask.ps1 -UseWiresharkFallback
```

Unregister:

```powershell
.\scripts\windows\Register-CtgSnortIdsTask.ps1 -Unregister
```

## SMS alert format

High/critical Snort alerts send a short message (no payloads, no PII):

```text
[CTG-high] CTG Snort: [high] rule 1000001 on Wi-Fi — review log
```

Rate limit: **one SMS per rule SID per 15 minutes** (`Send-CtgSmsAlert.ps1`).

## What gets saved

| Path | Content |
|------|---------|
| `%USERPROFILE%\Backups\ctg-snort\etc\snort.conf` | CTG detect-only config |
| `%USERPROFILE%\Backups\ctg-snort\rules\` | Community + local rules |
| `%USERPROFILE%\Backups\logs\snort\alert` | Snort alert_fast log |
| `%USERPROFILE%\Backups\logs\snort\snort-ids.log` | CTG orchestration log |
| `%USERPROFILE%\Backups\logs\snort\snort-alerts.json` | Structured alert history |
| `%USERPROFILE%\Backups\logs\sms-rate-limit.json` | SMS rate-limit state |

When SSD **D:** is online, paths use `D:\Backups\` instead.

## NIST / CIS mapping (defensive)

| Control | Implementation |
|---------|----------------|
| DE.CM-1 | Network monitoring via Snort detect-only on authorized interface |
| DE.AE-2 | Alert analysis — review `snort\alert` and JSON, correlate with Wireshark/Kali Suricata |
| PR.PT-1 | Npcap + Snort on hardened Win11 Pro host; secrets in `.env`/vault only |
| RS.AN-1 | SMS notifies analyst; full forensics from local logs (no payload in SMS) |

## Related scripts

| Script | Role |
|--------|------|
| `Install-CtgSnortWindows.ps1` | Npcap/Snort diagnose, CTG config layout |
| `Start-CtgSnortIDS.ps1` | Run Snort IDS, tail alerts, SMS |
| `ctg_snort_ids_loop.ps1` | Continuous monitoring loop |
| `Register-CtgSnortIdsTask.ps1` | Logon scheduled task |
| `Send-CtgSmsAlert.ps1` | Twilio SMS with rate limit |
| `CTG-SnortCommon.ps1` | Shared paths/helpers |
| `Start-CTGWiresharkIDS.ps1` | Fallback / parallel heuristics |

## Security notes

- Never commit `.env`, Twilio tokens, or phone numbers
- Snort on Windows is **detect-only** in this stack — no inline drop
- Promiscuous WiFi capture depends on driver/Npcap — prefer Ethernet or Kali USB monitor for 802.11 lab
- Full perimeter IPS: OPNsense + Suricata — see [README_WINDOWS_SOC.md](../scripts/windows/README_WINDOWS_SOC.md)
