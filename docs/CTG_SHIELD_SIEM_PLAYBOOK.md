# CTG Shield + SIEM Playbook (authorized lab)

**Author:** Andy Kowal Â· **Organization:** [Hacker Planet LLC](https://salvador-Data.github.io/cyberThreatGotchi/) (Philadelphia, PA)  
**Scope:** Networks and systems you own or have **written authorization** to test. This is **defensive lab** identity hygiene â€” not law-enforcement evasion, not silent WAN auto-rotate on production banking.

---

## Components

| Asset | Path | Role |
|-------|------|------|
| Shield rotate | `scripts/kali/tor-http-scrambler/ctg-shield-rotate.sh` | USB wlan IP/MAC display + rotate; DDG DNS preserve |
| SIEM hook | `scripts/kali/tor-http-scrambler/siem-hook.sh` | Tail Snort/Suricata/syslog â†’ high severity â†’ **y/n** shield rotate |
| GUI | `ctg-scrambler-gui.py` | Shield panel, Rotate button, last high alert |
| Windows status | `scripts/windows/CTG-Shield-Status.ps1` | Read-only host + optional SSH to Kali |
| Install | `install-scrambler.sh` | Copies shield + SIEM to `/opt/ctg/tor-http-scrambler` |

---

## v1 vs v2

| Version | Shield on IDS high alert | Production banking |
|---------|--------------------------|-------------------|
| **v1 (now)** | Terminal **y/n** prompt (`siem-hook.sh`) | **Never** auto-rotate â€” operator must confirm |
| **v2 (future)** | Optional auto on **isolated lab VLAN only** | Still requires playbook gate + snapshot rollback |

---

## IP refresh order (Kali guest)

1. Reconnect **DuckDuckGo** NetworkManager/WireGuard profile if present on guest  
2. Cycle **scrambler** mode (`tor` â†” `http` â†” restore) via `scrambler-daemon.sh`  
3. **`dhclient`** renew (or `nmcli` reapply) on **lab USB wlan** only  
4. **`preserve-ddg-dns`:** if `94.140.14.14` / `94.140.15.15` were in `resolv.conf`, restore from `/var/lib/ctg/shield/resolv.conf.ddg-backup` when needed

See [IPHONE_HARDENING.md](IPHONE_HARDENING.md) and [KALI_LAB_ARCHITECTURE.md](KALI_LAB_ARCHITECTURE.md) for DDG preserve rules on Windows host and iPhone â€” **do not stack** NextDNS/Cloudflare VPN installers via CTG scripts.

---

## MAC rotate rules

- **Allowed:** USB-attached `wlan*` (sysfs path contains `usb`)  
- **Blocked:** Built-in `eth0`, host bridge NICs, random spoof without lab USB attach  
- Override for owned lab hardware only: `export CTG_LAB_WLAN_IFACE=wlan1`

Tools: `macchanger -r` when installed; else locally administered random MAC via `ip link`.

---

## Manual commands (Kali)

```bash
sudo bash /opt/ctg/tor-http-scrambler/install-scrambler.sh
```

```bash
sudo /opt/ctg/tor-http-scrambler/ctg-shield-rotate.sh status
```

```bash
sudo /opt/ctg/tor-http-scrambler/ctg-shield-rotate.sh rotate
```

```bash
sudo /opt/ctg/tor-http-scrambler/siem-hook.sh
```

**GUI:** desktop **CTG .TOR/HTTP Scrambler** â†’ **Rotate IP/MAC** (confirm dialog).

---

## Windows host (read-only)

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\CTG-Shield-Status.ps1
```

Optional Kali query (VM running, NAT SSH `127.0.0.1:2222`):

```powershell
$env:CTG_KALI_SSH_HOST = '127.0.0.1'
```

```powershell
.\scripts\windows\CTG-Shield-Status.ps1
```

---

## High-severity detection (SIEM hook)

The hook scans the last `CTG_SIEM_TAIL` lines (default 20) for patterns such as:

- Snort `Priority: 1`  
- Suricata severity 1â€“2 / `[1:` style markers  
- `CRITICAL`, `HIGH`, `ALERT` tokens in syslog/IDS lines  

On match, operator sees the line and is asked: **Rotate lab USB wlan IP/MAC via CTG Shield? [y/N]**

Declining is the safe default for shared networks or active banking sessions on other devices.

---

## Staging & autorun

`Start-CTGLab.ps1` copies the full `tor-http-scrambler/` tree to `C:\Users\Owner\Backups\tor-http-scrambler\`.  
Kali autorun: [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md).

---

## Rollback

1. VM snapshot before first shield rotate in a session  
2. Restore `resolv.conf` from backup marker if DNS breaks lab workflows  
3. Reconnect USB wlan in VirtualBox if MAC change drops association  

---

## Related docs

- [CTG_TOR_HTTP_SCRAMBLER.md](CTG_TOR_HTTP_SCRAMBLER.md)  
- [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md)  
- [KALI_LAB_ARCHITECTURE.md](KALI_LAB_ARCHITECTURE.md) Â§ Phase 7
