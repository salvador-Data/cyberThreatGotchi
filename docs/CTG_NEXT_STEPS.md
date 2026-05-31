# CTG â€” start here (Andy)

One-page checklist for **Hacker Planet LLC** lab + website rollout. Authorized defensive use only.

**Related docs:** [SCRIPTS_CATALOG.md](SCRIPTS_CATALOG.md) Â· [SECURITY_HARDENING.md](SECURITY_HARDENING.md) Â· [PASSWORD_HARDENING.md](PASSWORD_HARDENING.md) Â· [SECRET_VAULT.md](SECRET_VAULT.md) Â· [CPU_PERFORMANCE.md](CPU_PERFORMANCE.md) Â· [KALI_RETBLEED.md](KALI_RETBLEED.md) Â· [KALI_VIRTUALBOX_SEAMLESS.md](KALI_VIRTUALBOX_SEAMLESS.md) Â· [KALI_SEAMLESS_MODE.md](KALI_SEAMLESS_MODE.md) Â· [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md)

---

## Good build snapshot (2026-05-31)

**Canonical repo path:** `C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi` — reopen Cursor here (not `Projects\cyberThreatGotchi` unless you sync clones).

### Done on main
- Kali share path: `ctg-run-on-share-trigger.sh`, `CTG_RUN_AUTORUN_NOW` trigger, `ctg-watch-trigger.sh` polling
- One-click in guest: `CLICK-ME-RUN-IN-KALI.sh` + `CLICK-ME-RUN-IN-KALI.desktop` (staged to `C:\Users\Owner\Backups` / vboxsf)
- Host: `Invoke-CtgKaliGuestFlash.ps1 -UseSecretVault` (DPAPI vault; no passwords in git)
- Host: `Start-KaliSeamless.ps1` diagnostic string fixes; `Invoke-CtgKaliNmapAskInstall.ps1` for nmap-ask install trigger
- Lab tree re-staged: `Stage-KaliLabToBackups.ps1`
- Tests: **429 passed, 4 skipped** (`.\.venv\Scripts\python.exe -m pytest -q`)

### Manual (Kali / Windows)
| Step | Action |
|------|--------|
| Kali lab chain | Log into Xfce → double-click **CTG Run Lab (click me)** or `bash /media/sf_ctg-backups/CLICK-ME-RUN-IN-KALI.sh` (sudo password once) |
| Share trigger (no SSH) | Windows: `New-Item C:\Users\Owner\Backups\CTG_RUN_AUTORUN_NOW -ItemType File -Force` while guest logged in |
| Secrets | `Protect-CtgSecrets.ps1 -SetSecret` for `KALI_SSH_USER` / `KALI_SSH_PASSWORD`; rotate Kali login when ready |
| Seamless | After GUI login: **Host+L** or `Start-KaliSeamless.ps1` |

### Paused (do not chase)
- Automated guest flash / guestcontrol retry loops — use CLICK-ME or share trigger instead.

**Host trigger (no SSH):**

```powershell
New-Item C:\Users\Owner\Backups\CTG_RUN_AUTORUN_NOW -ItemType File -Force
```

```powershell
.\scripts\windows\Invoke-CtgKaliGuestFlash.ps1 -UseSecretVault -TriggerOnly
```

---

## Session status (automated vs manual)

| Item | Status | Notes |
|------|--------|-------|
| Kali seamless host script | **Done** | `Start-KaliSeamless.ps1` — VB7 extradata, diagnose, lock retry |
| Kali guest seamless prerequisites | **Done** | `kali-boot-autopatch.sh`, `ctg-seamless-guest.sh`, staged to Backups |
| Seamless toggle on running VM | **Manual** | Log in to Kali GUI, then **Host+L** (VB7 has no `controlvm seamless`) |
| CPU safe optimize scripts | **Done** | `Optimize-CpuPerformance.ps1`, `Register-CtgCpuOptimizeTask.ps1`, docs |
| CPU `-ApplySafe` / scheduled task | **Manual (Admin)** | UAC required â€” see step 7 below |
| PII privacy Cursor rule | **Done** | `.cursor/rules/no-pii-in-repo.mdc` |
| Wi-Fi repair | **Manual (Admin)** | Wi-Fi disconnected; DDG VPN up â€” run `Repair-WindowsWifi.ps1 -ApplyFixes` elevated |
| Kali SSH autopatch | **Manual (TTY)** | If 127.0.0.1:2222 fails: `sudo bash /mnt/ctg/RUN-KALI-LAB-NOW.sh` |
| Vault secrets | **Manual** | `Protect-CtgSecrets.ps1 -SetSecret` for KALI_SSH_* (never in git) |
| pytest + push | **Done** | 429 passed (2026-05-31); main `0e9b8ce` pushed |
| RETBleed `--spec-ctrl on` | **Done (live)** | VBox `<SpecCtrl enabled="true"/>` — **reboot Kali**, then `bash /mnt/ctg/ctg-retbleed-check.sh` |
| Kali scripts staged to Backups | **Done** | `Stage-KaliLabToBackups.ps1` — CLICK-ME + triggers on `ctg-backups` share |
| Guest script flash | **Manual (CLICK-ME)** | Desktop one-click or `CTG_RUN_AUTORUN_NOW` on share; skip host guest-flash retry loops |
| Seamless View menu | **Manual (GUI login)** | `GUI/Seamless=on` set; menu stays gray until **LoggedInUsers>0** — log in Xfce, then Host+L |
| Seamless menu glitch | **Manual (guest)** | ``bash /mnt/ctg/ctg-seamless-guest.sh`` if needed; host: ``Start-KaliSeamless.ps1 -DiagnoseOnly`` |

**Seamless (2026-05-31 live):** VM **running headless** — `DesktopReady: False` (log in at Kali GUI). After login: `Start-KaliSeamless.ps1` (GUI session) or **Host+L**; if menu reverts: `bash /mnt/ctg/ctg-seamless-guest.sh`. **spec-ctrl:** ON (`Harden-KaliVmSpectre.ps1 -DiagnoseOnly`).

**CPU diagnose (Andy laptop):** Intel i9-8950HK, likely laptop, High performance plan active â€” **script OC: N**; manual BIOS/XTU only if desired.

---

## Tonight (Windows â€” Admin PowerShell)

Run each command in its **own** elevated window from the repo root:

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

**0. Secret vault (once per machine â€” interactive, no git)**

```powershell
.\scripts\windows\Protect-CtgSecrets.ps1 -SetSecret -Name KALI_SSH_USER
```

```powershell
.\scripts\windows\Protect-CtgSecrets.ps1 -SetSecret -Name KALI_SSH_PASSWORD
```

See [SECRET_VAULT.md](SECRET_VAULT.md). Never paste passwords into chat or SMS.

**1. Password policy (diagnose, then apply if Admin)**

```powershell
.\scripts\windows\Harden-PasswordPolicy.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Harden-PasswordPolicy.ps1 -ApplyPolicy
```

Log: `C:\Users\Owner\Backups\logs\harden-password-policy.log`. See [PASSWORD_HARDENING.md](PASSWORD_HARDENING.md).

**2. DDoS / rogue WiFi hardening (diagnose first, then apply)**

```powershell
.\scripts\windows\Harden-DDoSRogueWifi.ps1 -DiagnoseOnly
```

Review `C:\Users\Owner\Backups\logs\harden-ddos-rogue.log`. If posture looks right:

```powershell
.\scripts\windows\Harden-DDoSRogueWifi.ps1 -ApplyHardening
```

**3. Kali lab full deploy (VM already has shared folder + VRAM 128 VMSVGA)**

```powershell
.\scripts\windows\Deploy-KaliBootAutopatch.ps1 -RunBlankScreenFix -StartVmIfStopped
```

Or master autorun (uses DPAPI vault when `-UseSecretVault`):

```powershell
.\scripts\windows\Start-CTGLab.ps1 -FullBootstrap -UseSecretVault
```

Seamless mode (Guest Additions required):

```powershell
.\scripts\windows\Start-KaliSeamless.ps1
```

See [KALI_VIRTUALBOX_SEAMLESS.md](KALI_VIRTUALBOX_SEAMLESS.md) and [KALI_SEAMLESS_MODE.md](KALI_SEAMLESS_MODE.md) (toolbar / Host+Home).

**4. Compartmentalized audit (weekly or pre-travel)**

```powershell
.\scripts\windows\CTG-AuditAutorun.ps1 -HardenAndAudit
```

Runs under `Backups\audit\YYYY-MM-DD\run-HHmmss\`.

**5. CTG Shield status (read-only)**

```powershell
.\scripts\windows\CTG-Shield-Status.ps1
```

**6. Wireshark IDS (OptimizeCapture ON by default)**

```powershell
.\scripts\windows\Start-CTGWiresharkIDS.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Start-CTGWiresharkIDS.ps1 -CaptureMinutes 10
```

Twilio SMS: set vars in local `.env` only â€” see [WIRESHARK_IDS_SMS.md](WIRESHARK_IDS_SMS.md).

**7. CPU performance (diagnose â€” safe Windows tweaks, no script OC)**

```powershell
.\scripts\windows\Optimize-CpuPerformance.ps1 -DiagnoseOnly
```

Apply safe AC tweaks (Admin):

```powershell
.\scripts\windows\Run-AsAdmin.ps1 -TargetScript .\scripts\windows\Optimize-CpuPerformance.ps1 -TargetArguments '-ApplySafe'
```

Weekly autorun (no password in git â€” Interactive logon):

```powershell
.\scripts\windows\Register-CtgCpuOptimizeTask.ps1
```

See [CPU_PERFORMANCE.md](CPU_PERFORMANCE.md). **Never** paste Windows password into chat or scripts.


---

## Dev root (2026-05-31)

| | |
|--|--|
| **Canonical** | ``$env:USERPROFILE\Programs\Hacker Planet LLC\cyberThreatGotchi`` |
| **Wrong name** | ``Hackers Planet LLC`` (extra **s**) — not used on disk |
| **Legacy** | ``Projects\cyberThreatGotchi`` — stub only; **re-open Cursor** on Programs path |

Path helpers: ``scripts/windows/CTG-Paths.ps1`` (dot-sourced from ``CTG-AdminCommon.ps1``). Layout: [HACKER_PLANET_PROJECT_LAYOUT.md](HACKER_PLANET_PROJECT_LAYOUT.md).
---

## Kali guest — mount then scripts (if step 1 failed)

**Most common failure:** running `bash /mnt/ctg/ctg-display-scale.sh` or `ctg-seamless-guest.sh` **before** the share is mounted, or before GUI login.

| Order | What | Command |
|-------|------|---------|
| 0 | Pre-flight | `bash /media/sf_ctg-backups/ctg-mount-share.sh --check-only` |
| 1 | Mount share | `sudo bash /media/sf_ctg-backups/ctg-mount-share.sh` |
| 2 | GUI login | Open VM window, sign in to Xfce |
| 3 | Display / seamless | `bash /mnt/ctg/ctg-display-scale.sh` or `bash /mnt/ctg/ctg-seamless-guest.sh` |

If `/media/sf_ctg-backups` is missing: Guest Additions or VM not running — Windows: `Stage-KaliLabToBackups.ps1`, ensure VM **kali** is on.

Troubleshooting tables: [KALI_DISPLAY_SCALING.md](KALI_DISPLAY_SCALING.md), [KALI_SEAMLESS_MODE.md](KALI_SEAMLESS_MODE.md).

## Kali TTY one-liner (if SSH on 127.0.0.1:2222 fails)

At the Kali console (Ctrl+Alt+F2 if blank screen):

```bash
sudo bash /mnt/ctg/RUN-KALI-LAB-NOW.sh
```

Or manual chain (mount is step 1):

```bash
sudo bash /media/sf_ctg-backups/ctg-mount-share.sh
```

```bash
sudo bash /mnt/ctg/kali-boot-autopatch.sh --install
```

```bash
sudo bash /mnt/ctg/ctg-lab-autorun.sh
```

RETBleed / microcode check (in-guest):

```bash
sudo bash /mnt/ctg/fix-retbleed-mitigation.sh --diagnose
```

See [KALI_RETBLEED.md](KALI_RETBLEED.md).

Verify autopatch:

```bash
systemctl status ctg-kali-autopatch.service
tail -20 /var/log/ctg-boot-autopatch.log
```

Rogue AP guard (authorized lab SSID):

```bash
sudo bash /mnt/ctg/rogue-ap-guard.sh -k "YourHomeSSID"
```

---

## Website deploy (any shell â€” no Admin)

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\.venv\Scripts\python.exe scripts\sync_seo.py
```

```powershell
.\.venv\Scripts\python.exe scripts\sync_website_to_docs.py
```

```powershell
pytest tests\ -v
```

```powershell
git add website docs/web
git commit -m "website: sync feeds hub and SEO"
git push origin main
```

GitHub Pages picks up `docs/web/` on push. Custom domain: `hackerplanet.dev`.

---

## Split repos (optional publish)

After monorepo changes to Kali or Windows scripts:

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\publish\Sync-CtgSplitRepos.ps1
```

Then commit and push [ctg-kali-lab](https://github.com/salvador-Data/ctg-kali-lab) and [ctg-windows-soc](https://github.com/salvador-Data/ctg-windows-soc). Plan: [GITHUB_REPOS_PLAN.md](GITHUB_REPOS_PLAN.md).

---

## Staged in `C:\Users\Owner\Backups`

| Asset | Purpose |
|-------|---------|
| `RUN-KALI-LAB-NOW.sh` | One-paste full lab when SSH fails |
| `CLICK-ME-RUN-IN-KALI.sh` | Double-click Thunar one-action lab chain |
| `ctg-run-on-share-trigger.sh` | Minimal chain when `CTG_RUN_AUTORUN_NOW` exists on share |
| `ctg-mount-share.sh` | Mount `ctg-backups` at `/mnt/ctg` (run before other guest scripts) |
| `ctg-display-scale.sh` | HiDPI / terminal font scale (after GUI login + mount) |
| `ctg-seamless-guest.sh` | Seamless panel + VBoxClient (after GUI login + mount) |
| `ctg-lab-autorun.sh` | Master Kali lab autorun |
| `kali-lab-bootstrap.sh` | Full Ansible/bootstrap |
| `kali-boot-autopatch.sh` | Boot-time GNOME/VBox fixes |
| `fix-kali-blank-screen.sh` | VRAM/Wayland recovery |
| `fix-retbleed-mitigation.sh` | RETBleed / IBRS diagnose |
| `rogue-ap-guard.sh` | Passive evil-twin scan |
| `tor-http-scrambler/` | CTG Shield + scrambler |
| `CTG-Shield-Status.ps1` | Windows host status |
| `CTG_SHIELD_SIEM_PLAYBOOK.md` | SIEM hook playbook |

VirtualBox shared folder: **ctg-backups** â†’ `C:\Users\Owner\Backups` (mount at `/mnt/ctg`).

---

## pytest before push

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
.\.venv\Scripts\activate
pytest tests\ -v
```

Expected: **277 collected**, all pass (3 firewall bash tests skip on Windows).

---

## New pages / links

- **Pro feeds hub:** [website/feeds.html](../website/feeds.html) â€” signatures, YARA, hashes API
- **Shop Pro tier:** [shop.html#pro-feed](https://hackerplanet.dev/shop.html#pro-feed)
- **Kickstarter:** [kickstarter.html](https://hackerplanet.dev/kickstarter.html) â€” config in `website/js/kickstarter.config.js`

---

## Portfolio index (GitHub + site)

| Project | GitHub | Site page | Branch | Status |
|---------|--------|-----------|--------|--------|
| **cyberThreatGotchi** (monorepo) | [salvador-Data/cyberThreatGotchi](https://github.com/salvador-Data/cyberThreatGotchi) | [hackerplanet.dev](https://hackerplanet.dev/) Â· [Pages mirror](https://salvador-Data.github.io/cyberThreatGotchi/) | `main` | Flagship â€” CI, Pages, releases |
| **ctg-kali-lab** | [salvador-Data/ctg-kali-lab](https://github.com/salvador-Data/ctg-kali-lab) | [github.html](https://hackerplanet.dev/github.html) | `main` | Split â€” Kali scripts + docs |
| **ctg-windows-soc** | [salvador-Data/ctg-windows-soc](https://github.com/salvador-Data/ctg-windows-soc) | [github.html](https://hackerplanet.dev/github.html) | `main` | Split â€” Windows SOC + Wireshark IDS |
| **Bjorn** | [salvador-Data/Bjorn](https://github.com/salvador-Data/Bjorn) | [ecosystem.html](https://hackerplanet.dev/ecosystem.html) | `main` | Pi assessment fork |
| **Mr. CrackBot AI Nano** | [salvador-Data/Mr.-CrackBot-AI-Nano](https://github.com/salvador-Data/Mr.-CrackBot-AI-Nano) | [crackbot.html](https://hackerplanet.dev/crackbot.html) | `main` | Jetson bench lab |
| **M5 OS Cardputer** | [salvador-Data/M5_OS-Cardputer](https://github.com/salvador-Data/M5_OS-Cardputer) | [cardputer.html](https://hackerplanet.dev/cardputer.html) | `main` | Pocket launcher firmware |
| **BLE Bot Cardputer** | [salvador-Data/BLE-Bot-Cardputer](https://github.com/salvador-Data/BLE-Bot-Cardputer) | [github.html](https://hackerplanet.dev/github.html) | `main` | BLE scout firmware |
| **Remote Possibility** | [salvador-Data/Remote-Possibility](https://github.com/salvador-Data/Remote-Possibility) | [github.html](https://hackerplanet.dev/github.html) | `main` | IR remote (legacy CTG client archived) |

**Sync split repos after monorepo script changes:** `.\scripts\publish\Sync-CtgSplitRepos.ps1` then commit/push each split clone. Plan: [GITHUB_REPOS_PLAN.md](GITHUB_REPOS_PLAN.md).

---

## SSH note

NAT forward **2222 â†’ 22** is configured on VM `kali`. Credentials: DPAPI vault (`Protect-CtgSecrets.ps1`) or local `Backups\kali-vm-credentials.txt` (gitignored). If banner exchange fails, use TTY one-liner above â€” guest SSH may need `sudo apt install -y openssh-server && sudo systemctl enable --now ssh`.
