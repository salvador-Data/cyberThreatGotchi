# Kali lab scripts — CyberThreatGotchi

**Authorized defensive lab use only** · [Hacker Planet LLC](https://salvador-Data.github.io/cyberThreatGotchi/)

## Quick start

From **Windows** (master deploy):

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\Deploy-KaliLab.ps1
```

From **inside Kali** (after install):

```bash
sudo bash /tmp/kali-lab-bootstrap.sh --wifi-profile=company-lab
```

## Files

| File | Purpose |
|------|---------|
| `kali-lab-bootstrap.sh` | Monolithic bootstrap: harden, ClamAV, passive Snort, OSINT apt, Realtek detect, WiFi Option 2 |
| `ansible/` | Optional Ansible mirror of the same roles (run locally if preferred) |

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

See [docs/KALI_LAB_ARCHITECTURE.md](../../docs/KALI_LAB_ARCHITECTURE.md).
