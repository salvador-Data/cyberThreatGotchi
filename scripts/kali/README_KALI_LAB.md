# Kali lab scripts — CyberThreatGotchi

**Authorized defensive lab use only** · [Hacker Planet LLC](https://salvador-Data.github.io/cyberThreatGotchi/)

## Quick start

From **Windows** (master deploy — DuckDuckGo preserve **on** by default):

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\Deploy-KaliLab.ps1 -StartVmIfStopped
```

Optional: force Kali resolv.conf to DuckDuckGo only:

```powershell
.\scripts\windows\Deploy-KaliLab.ps1 -StartVmIfStopped -DdgDnsOnly
```

**Blank screen after login?** See [docs/CTG_LAB_AUTORUN.md](../../docs/CTG_LAB_AUTORUN.md) § Blank screen. Windows: `.\scripts\windows\Fix-KaliBlankScreen.ps1`. In-guest TTY: `sudo bash /mnt/ctg/fix-kali-blank-screen.sh`.

From **inside Kali** (after install):

```bash
sudo bash /mnt/ctg/ctg-lab-autorun.sh
```

Or bootstrap only:

```bash
sudo bash /tmp/kali-lab-bootstrap.sh --wifi-profile=company-lab --preserve-ddg-dns --lab-anonymity
```

```bash
sudo bash /tmp/kali-lab-bootstrap.sh --wifi-profile=company-lab --ddg-dns-only
```

Lab anonymity + pentest scope (default **on** for company lab):

```bash
cp lab-targets.example lab-targets.conf
```

```bash
sudo bash /tmp/kali-lab-bootstrap.sh --no-lab-anonymity
```

## Rogue AP guard (passive WiFi)

Detect duplicate SSIDs, open networks, and evil-twin hints — **no deauth, no jamming**.

```bash
sudo bash /mnt/ctg/rogue-ap-guard.sh -k "YourHomeSSID"
```

Install copy: `~/Backups/kali-wifi-guard/rogue-ap-guard.sh` · Log: `~/Backups/logs/rogue-ap-guard.log`

See [docs/DEFENSE_DDOS_ROGUE_WIFI.md](../../docs/DEFENSE_DDOS_ROGUE_WIFI.md).

## DuckDuckGo preserve

Same rules as [docs/IPHONE_HARDENING.md](../../docs/IPHONE_HARDENING.md):

- Do **not** replace DuckDuckGo VPN/DNS on Windows, iPhone, or home router.
- Kali: `--preserve-ddg-dns` (default) skips changes when DDG already in `resolv.conf`.
- OPNsense lab: [docs/OPNSENSE_LAB_DNS.md](../../docs/OPNSENSE_LAB_DNS.md) — forward to `94.140.14.14` / `94.140.15.15` only; no NextDNS/Cloudflare stack.

## Files

| File | Purpose |
|------|---------|
| `kali-lab-bootstrap.sh` | Monolithic bootstrap: DDG preserve, lab anonymity (Tor/proxychains), harden, ClamAV, passive Snort, OSINT apt, Realtek detect, WiFi Option 2 |
| `ctg-wifi-lab-autorun.sh` | USB Realtek detect, OOT driver, lab WPA2 connect, eth promisc + optional WiFi monitor |
| `ctg-ids-ips-autorun.sh` | ClamAV + passive Snort/Suricata IDS; optional `--EnableIPS` (lab VLAN) |
| `lab-wifi.conf.example` | Lab SSID/PSK template → `/etc/ctg/lab-wifi.conf` (mode 600, gitignored) |
| `lab-targets.example` | Authorized targets template — copy to `lab-targets.conf` (gitignored) |
| `ansible/` | Optional Ansible mirror (includes `ddg-dns` role) |

## WiFi profiles

| Profile | Use |
|---------|-----|
| `company-lab` (default) | Hacker Planet lab VLAN / owned AP — legal regdomain, link-quality tuning |
| `home-conservative` | Minimal RF changes for home NAT VM |

No illegal regdomain bypass or TX power overrides in this repo.

## WiFi + Ethernet capture (promisc vs monitor)

**Ethernet (CAT5):** classic `ip link set promisc on` when cable is plugged — sees LAN-segment frames.  
**WiFi:** `promisc` on wlan is usually **not** enough; use **`airmon-ng`** monitor mode for 802.11 Wireshark capture.

Both interfaces can be configured at once (different paths). See [docs/KALI_WIFI_ETH_PROMISC.md](../../docs/KALI_WIFI_ETH_PROMISC.md).

```bash
sudo cp /mnt/ctg/lab-wifi.conf.example /etc/ctg/lab-wifi.conf
sudo chmod 600 /etc/ctg/lab-wifi.conf
sudo nano /etc/ctg/lab-wifi.conf
```

```bash
sudo bash /mnt/ctg/ctg-wifi-lab-autorun.sh
```

Monitor mode when lab 802.11 capture is enabled:

```bash
sudo CTG_WIFI_MONITOR=1 bash /mnt/ctg/ctg-wifi-lab-autorun.sh --monitor
```

Boot autopatch with WiFi lab phase:

```bash
sudo bash /mnt/ctg/kali-boot-autopatch.sh --wifi-lab
```

## Secrets

Copy and edit locally (gitignored):

- `/etc/ctg/lab-wifi.conf` — from `lab-wifi.conf.example`
- `/etc/environment.d/ctg-osint.env` — Shodan, Censys, VT placeholders
- `ansible/group_vars/realtek.yml` — from `realtek.yml.example`

## Architecture

See [docs/KALI_LAB_ARCHITECTURE.md](../../docs/KALI_LAB_ARCHITECTURE.md) for the full 15-item checklist.
