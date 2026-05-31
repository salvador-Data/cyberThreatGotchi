# CTG script repos — split plan

**Parent monorepo:** [salvador-Data/cyberThreatGotchi](https://github.com/salvador-Data/cyberThreatGotchi)  
**Catalog:** [SCRIPTS_CATALOG.md](SCRIPTS_CATALOG.md)

Hacker Planet LLC splits defensive automation into focused public repos so labs can clone only what they need. No secrets, `.env`, or `Backups/` trees are copied.

## Repos created

| Repo | Focus | Clone |
|------|--------|-------|
| [ctg-kali-lab](https://github.com/salvador-Data/ctg-kali-lab) | Kali VM bootstrap, IDS/IPS, WiFi lab, Tor scrambler | `git clone https://github.com/salvador-Data/ctg-kali-lab.git` |
| [ctg-windows-soc](https://github.com/salvador-Data/ctg-windows-soc) | Windows hardening, Sysmon, Wazuh, nightly, Wireshark IDS | `git clone https://github.com/salvador-Data/ctg-windows-soc.git` |

## iPhone hardening — stays in monorepo

Only three Windows assist scripts (`iphone_hardening_automate.ps1`, `iphone_usb_check.ps1`, deprecated `iphone_hardening_assist.ps1`) plus [IPHONE_HARDENING.md](IPHONE_HARDENING.md). Too thin for a standalone repo; they ship inside **ctg-windows-soc** and the main catalog.

## Manual recreate (if `gh` fails)

```powershell
cd C:\Users\Owner\Projects
```

```powershell
gh repo create salvador-Data/ctg-kali-lab --public --description "CyberThreatGotchi Kali defensive lab scripts — Hacker Planet LLC"
```

```powershell
gh repo create salvador-Data/ctg-windows-soc --public --description "CyberThreatGotchi Windows SOC hardening & nightly automation — Hacker Planet LLC"
```

After copying files and adding `README.md` + `LICENSE` (MIT, same as parent):

```powershell
cd C:\Users\Owner\Projects\ctg-kali-lab
```

```powershell
git init
```

```powershell
git add .
```

```powershell
git commit -m "Initial import from cyberThreatGotchi monorepo"
```

```powershell
git branch -M main
```

```powershell
git remote add origin https://github.com/salvador-Data/ctg-kali-lab.git
```

```powershell
git push -u origin main
```

Repeat for `ctg-windows-soc` with its folder and remote URL.

## Sync from monorepo later

When scripts change in `cyberThreatGotchi`, re-copy the subtree and push the split repo:

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\publish\Sync-CtgSplitRepos.ps1
```

*(Optional future helper — today: robocopy or manual `Copy-Item` per README in each split repo.)*

## What not to publish

- `ctg-soc-run-log-elevated.txt` or any `Backups\` logs
- `.env`, Stripe secrets, Twilio tokens, Wazuh enrollment passwords
- `lab-wifi.conf`, `lab-targets.conf` (gitignored lab secrets)
