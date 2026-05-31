# CTG Lab Playground â€” play with your stack

**Author:** Andy Kowal Â· **Organization:** [Hacker Planet LLC](https://salvador-Data.github.io/cyberThreatGotchi/) (Philadelphia, PA)  
**Authorized use:** Systems and networks you own or have written scope to test. No third-party attacks, deauth, jamming, or credential harvesting.

The playground menus let you **experiment** with CTG lab tools in a guided, professor-style session â€” without running the full autorun chain or surprise reboots.

---

## One command each side

**Windows SOC (elevated optional for capture/SMS):**

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\CTG-Lab-Playground.ps1
```

**Kali in-guest (root, after share mount):**

```bash
sudo bash /mnt/ctg/ctg-lab-playground.sh
```

Scripts are staged to `C:\Users\Owner\Backups\` on every `Start-CTGLab.ps1` / `Deploy-KaliLab.ps1` run.

---

## 15-minute lab session (suggested order)

| Min | Where | Action | What you learn |
|-----|-------|--------|----------------|
| 0â€“2 | Windows | Menu **1** Wireshark IDS DiagnoseOnly | tshark, Npcap, log paths ready |
| 2â€“4 | Windows | Menu **2** Shield Status | DDG VPN/DNS + host NIC; optional Kali SSH |
| 4â€“6 | Windows | Menu **7** Start Kali VM | VM up; note in-guest playground command |
| 6â€“8 | Kali | Menu **9** Lab dry status | What's installed vs missing |
| 8â€“10 | Kali | Menu **3** Scrambler demo | tor / http / auto modes + GUI path |
| 10â€“12 | Kali | Menu **4** SIEM dry-run | IDS tail sources without rotate prompts |
| 12â€“14 | Kali | Menu **6** + **8** | Suricata tail + Tor curl check |
| 14â€“15 | Either | Menu **0** Exit | Review logs under `Backups/logs/` |

Optional extras: Kali **1** WiFi/monitor demo, **7** rogue AP guard (your home SSID), Windows **5** 2-min capture, **6** SMS test if Twilio is in `.env`.

---

## Windows menu map

| # | Tool | Script |
|---|------|--------|
| 1 | Wireshark IDS diagnose | `Start-CTGWiresharkIDS.ps1 -DiagnoseOnly` |
| 2 | CTG Shield status | `CTG-Shield-Status.ps1` |
| 3 | DDoS / rogue WiFi | `Harden-DDoSRogueWifi.ps1 -DiagnoseOnly` |
| 4 | Open kickstarter / feeds | `website/*.html` |
| 5 | 2-min capture demo | `Start-CTGWiresharkIDS.ps1 -CaptureMinutes 2` |
| 6 | SMS test | `Send-CtgSmsAlert.ps1 -TestMessage` |
| 7 | VirtualBox Kali + hint | Prints `sudo bash /mnt/ctg/ctg-lab-playground.sh` |

---

## Kali menu map

| # | Tool | Notes |
|---|------|--------|
| 1 | WiFi + promisc/monitor | Status from `/var/log/ctg-wifi-lab.log`; optional `airmon-ng` demo |
| 2 | Shield | `ctg-shield-rotate.sh status`; y/n rotate |
| 3 | Scrambler | Cycles tor/http/auto; GUI: `ctg-scrambler-gui.py` |
| 4 | SIEM dry-run | Tail IDS/ClamAV logs only â€” no shield prompts |
| 5 | ClamAV | Small `/home` scan (max 50 files) |
| 6 | IDS tail | Last 5 Suricata/Snort lines |
| 7 | Rogue AP guard | Passive scan; prompt for known SSID |
| 8 | Tor check | `curl` via SOCKS 127.0.0.1:9050 |
| 9 | Lab dry status | Bootstrap, services, share â€” no reboot |

---

## Prerequisites

1. Run autorun once (or deploy): [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md)
2. Mount share in Kali: `sudo mount -t vboxsf ctg-backups /mnt/ctg`
3. WiFi lab config (optional): `/etc/ctg/lab-wifi.conf` from `lab-wifi.conf.example`
4. SMS (optional): `.env` with `TWILIO_*` and `CTG_ALERT_SMS_TO` â€” see [WIRESHARK_IDS_SMS.md](WIRESHARK_IDS_SMS.md)

---

## Logs to review after play

| Path | Content |
|------|---------|
| `C:\Users\Owner\Backups\logs\wireshark-ids.log` | Windows IDS cycles |
| `C:\Users\Owner\Backups\logs\siem\` | SIEM JSON export |
| `/var/log/ctg-wifi-lab.log` | WiFi/promisc autorun |
| `/var/log/ctg-snort/` | Suricata alerts |
| `/var/log/ctg-clamav/` | ClamAV playground + scheduled scans |

---

## Related docs

- [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md) â€” full stack orchestration
- [KALI_WIFI_ETH_PROMISC.md](KALI_WIFI_ETH_PROMISC.md) â€” promisc vs monitor
- [CTG_SHIELD_SIEM_PLAYBOOK.md](CTG_SHIELD_SIEM_PLAYBOOK.md) â€” live SIEM hook with y/n rotate
- [WIRESHARK_IDS_SMS.md](WIRESHARK_IDS_SMS.md) â€” Windows IDS + Twilio
