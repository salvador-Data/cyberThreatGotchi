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

From **inside Kali** (after install):

```bash
sudo bash /tmp/kali-lab-bootstrap.sh --wifi-profile=company-lab --preserve-ddg-dns
```

```bash
sudo bash /tmp/kali-lab-bootstrap.sh --wifi-profile=company-lab --ddg-dns-only
```

## DuckDuckGo preserve

Same rules as [docs/IPHONE_HARDENING.md](../../docs/IPHONE_HARDENING.md):

- Do **not** replace DuckDuckGo VPN/DNS on Windows, iPhone, or home router.
- Kali: `--preserve-ddg-dns` (default) skips changes when DDG already in `resolv.conf`.
- OPNsense lab: [docs/OPNSENSE_LAB_DNS.md](../../docs/OPNSENSE_LAB_DNS.md) — forward to `94.140.14.14` / `94.140.15.15` only; no NextDNS/Cloudflare stack.

## Files

| File | Purpose |
|------|---------|
| `kali-lab-bootstrap.sh` | Monolithic bootstrap: DDG preserve, harden, ClamAV, passive Snort, OSINT apt, Realtek detect, WiFi Option 2 |
| `ansible/` | Optional Ansible mirror (includes `ddg-dns` role) |

## WiFi profiles

| Profile | Use |
|---------|-----|
| `company-lab` (default) | Hacker Planet lab VLAN / owned AP — legal regdomain, link-quality tuning |
| `home-conservative` | Minimal RF changes for home NAT VM |

No illegal regdomain bypass or TX power overrides in this repo.

## Secrets

Copy and edit locally (gitignored):

- `/etc/environment.d/ctg-osint.env` — Shodan, Censys, VT placeholders
- `ansible/group_vars/realtek.yml` — from `realtek.yml.example`

## Architecture

See [docs/KALI_LAB_ARCHITECTURE.md](../../docs/KALI_LAB_ARCHITECTURE.md) for the full 15-item checklist.
