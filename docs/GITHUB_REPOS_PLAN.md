# CTG script repos â€” split plan

**Parent monorepo:** [salvador-Data/cyberThreatGotchi](https://github.com/salvador-Data/cyberThreatGotchi)  
**Catalog:** [SCRIPTS_CATALOG.md](SCRIPTS_CATALOG.md)

Hacker Planet LLC splits defensive automation into focused public repos so labs can clone only what they need. No secrets, `.env`, or `Backups/` trees are copied.

## Repos created

| Repo | Focus | Clone |
|------|--------|-------|
| [ctg-kali-lab](https://github.com/salvador-Data/ctg-kali-lab) | Kali VM bootstrap, IDS/IPS, WiFi lab, Tor scrambler | `git clone https://github.com/salvador-Data/ctg-kali-lab.git` |
| [ctg-windows-soc](https://github.com/salvador-Data/ctg-windows-soc) | Windows hardening, Sysmon, Wazuh, nightly, Wireshark IDS | `git clone https://github.com/salvador-Data/ctg-windows-soc.git` |
| [ctg-device-hardening](https://github.com/salvador-Data/ctg-device-hardening) | iPhone laptop connection, exploit mitigations, CVE feeds, IDS/RAM honesty docs | `git clone https://github.com/salvador-Data/ctg-device-hardening.git` |

Sync device-hardening subtree:

```powershell
.\scripts\publish\Sync-CtgDeviceHardeningRepo.ps1
```

## iPhone hardening â€” monorepo + ctg-device-hardening

Primary docs stay in the monorepo ([IPHONE_HARDENING.md](IPHONE_HARDENING.md), [IPHONE_LAPTOP_CONNECTION.md](IPHONE_LAPTOP_CONNECTION.md)). Read-only checklist: `scripts/iphone/iphone_tethering_privacy_checklist.ps1`. Split copy ships in **ctg-device-hardening** and **ctg-windows-soc** catalog references.

## Privatize lab repos (allowlist)

`scripts/publish/Set-CtgPrivateRepos.ps1 -DiagnoseOnly` lists **ctg-kali-lab** and **ctg-windows-soc** as sensitive candidates. `-Apply` only privatizes names in the committed `$Script:CtgPrivateRepoAllowlist` â€” review before Apply. **cyberThreatGotchi** (public site) and firmware repos (M5_OS-Cardputer, etc.) are excluded.

## Manual recreate (if `gh` fails)

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC
```

```powershell
gh repo create salvador-Data/ctg-kali-lab --public --description "CyberThreatGotchi Kali defensive lab scripts â€” Hacker Planet LLC"
```

```powershell
gh repo create salvador-Data/ctg-windows-soc --public --description "CyberThreatGotchi Windows SOC hardening & nightly automation â€” Hacker Planet LLC"
```

After copying files and adding `README.md` + `LICENSE` (MIT, same as parent):

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\ctg-kali-lab
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
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\publish\Sync-CtgSplitRepos.ps1
```

Copies `scripts/kali` â†’ ctg-kali-lab and `scripts/windows` + `wireshark_ids` â†’ ctg-windows-soc with doc subsets. No `.env`, `Backups/`, or lab conf secrets.

## What not to publish

- `ctg-soc-run-log-elevated.txt` or any `Backups\` logs
- `.env`, Stripe secrets, Twilio tokens, Wazuh enrollment passwords
- `lab-wifi.conf`, `lab-targets.conf` (gitignored lab secrets)
