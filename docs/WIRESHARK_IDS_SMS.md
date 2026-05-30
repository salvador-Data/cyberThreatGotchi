# Wireshark IDS + SMS alerts — CyberThreatGotchi Windows SOC

**Authorized defensive use only** on networks and hosts you own or are explicitly permitted to monitor.

## Honest scope

| Capability | Windows (this stack) | Full IPS (recommended) |
|------------|----------------------|-------------------------|
| Packet capture | Yes — `tshark` ring buffer to `Backups\pcap\` | SPAN/tap + OPNsense |
| IDS heuristics | Port scan, SYN flood hints, DNS tunnel length, ARP duplicate MAC, CTG payload signatures | Suricata/Snort rulesets |
| Snort (optional) | Parses alert log if Snort installed on Windows | Kali passive Snort or OPNsense |
| SMS alerts | Twilio via env vars | Same |
| IPS block | Optional `netsh` inbound block for repeat offenders (**Admin**, lab only) | **OPNsense Suricata** inline or blocking mode |

Wireshark on Windows is **not** a full inline IPS. Promiscuous WiFi capture is limited by drivers/Npcap. For perimeter IPS, see [README_WINDOWS_SOC.md](../scripts/windows/README_WINDOWS_SOC.md) OPNsense section and [KALI_LAB_ARCHITECTURE.md](KALI_LAB_ARCHITECTURE.md).

## Prerequisites

1. Install Wireshark + Npcap:

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\Install-WiresharkNpcap.ps1
```

2. Configure Twilio SMS in **local `.env`** (gitignored — never commit):

```env
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_FROM_NUMBER=+1xxxxxxxxxx
CTG_ALERT_SMS_TO=+1XXXXXXXXXX
```

Use E.164 format for `CTG_ALERT_SMS_TO` (your mobile — set locally only).

3. Verify diagnose mode:

```powershell
.\scripts\windows\Start-CTGWiresharkIDS.ps1 -DiagnoseOnly
```

4. Test SMS (only when Twilio env is set):

```powershell
.\scripts\windows\Send-CtgSmsAlert.ps1 -TestMessage
```

## Start monitoring

Short capture + analysis cycle (5 minutes default):

```powershell
.\scripts\windows\Start-CTGWiresharkIDS.ps1 -CaptureMinutes 10
```

Continuous loop (15-minute cycles):

```powershell
.\scripts\windows\ctg_wireshark_ids_loop.ps1 -CycleMinutes 15
```

Optional IPS-style inbound block after two high-severity alerts from same IP (**Administrator**):

```powershell
.\scripts\windows\Start-CTGWiresharkIDS.ps1 -CaptureMinutes 10 -BlockRepeatOffenders
```

Specify interface (from `tshark -D`):

```powershell
.\scripts\windows\Start-CTGWiresharkIDS.ps1 -Interface 3 -CaptureMinutes 5
```

## What gets saved

| Path | Content |
|------|---------|
| `%USERPROFILE%\Backups\pcap\ctg-YYYY-MM-DD.pcapng` | Ring-buffer capture (50 MB × 48 files, time rotation) |
| `%USERPROFILE%\Backups\pcap\snippets\` | High-severity alert window extracts |
| `%USERPROFILE%\Backups\logs\wireshark-ids.log` | Text log |
| `%USERPROFILE%\Backups\logs\wireshark-alerts.json` | Structured alerts |
| `%USERPROFILE%\Backups\logs\wireshark-export.csv` | Latest tshark fields export for analysis |
| `%USERPROFILE%\Backups\logs\sms-rate-limit.json` | SMS rate-limit state (15 min per alert type) |

When SSD **D:** is online and writable, paths use `D:\Backups\` instead of `%USERPROFILE%\Backups\`.

## Detection patterns (basic)

- **Port scan** — many distinct destination ports from one source
- **SYN flood hint** — high SYN-without-ACK count to one target/port
- **DNS tunnel hint** — unusually long DNS query names
- **ARP spoof hint** — same IP observed with multiple MAC addresses
- **CTG signatures** — payload matches from `rules/signatures.py` (SQLi, RCE, etc.)
- **Snort** — parses classic Snort alert file when present

High/critical severity triggers SMS (rate-limited) and optional pcap snippet.

## Kali optional: syslog forwarding

Inside Kali lab VM, forward Snort/Suricata or custom CTG alerts to your Windows SIEM listener:

```bash
# Example rsyslog forward (adjust IP to Windows host)
echo '*.* @@192.168.56.1:514' | sudo tee /etc/rsyslog.d/50-ctg-forward.conf
sudo systemctl restart rsyslog
```

On Windows, ingest with Wazuh agent or a syslog receiver; correlate with `wireshark-alerts.json`. Kali bootstrap installs passive Snort — primary network IPS remains **Suricata on OPNsense**.

See [scripts/kali/README_KALI_LAB.md](../scripts/kali/README_KALI_LAB.md) and [CTG_SHIELD_SIEM_PLAYBOOK.md](CTG_SHIELD_SIEM_PLAYBOOK.md).

## Nightly integration

`ctg_nightly_4am.ps1` does **not** run continuous capture (too heavy for 4 AM backup window). Run `ctg_wireshark_ids_loop.ps1` as a separate scheduled task during lab hours, or a single `-CaptureMinutes 5` snapshot before SOC review.

## Related scripts

| Script | Role |
|--------|------|
| `Start-CTGWiresharkIDS.ps1` | Capture + analyze + alert |
| `Send-CtgSmsAlert.ps1` | Twilio SMS with rate limit |
| `ctg_wireshark_ids_loop.ps1` | Continuous monitoring loop |
| `CTG-WiresharkCommon.ps1` | Shared paths/helpers |
| `scripts/wireshark_ids/analyze_traffic.py` | Alert parsing (also used in CI tests) |

## Security notes

- Never commit `.env`, Twilio tokens, or phone numbers
- SMS bodies avoid full packet payloads or secrets
- `-BlockRepeatOffenders` can lock out legitimate IPs if mis-tuned — lab only
- Full production IPS: deploy OPNsense + Suricata on your perimeter VLAN
