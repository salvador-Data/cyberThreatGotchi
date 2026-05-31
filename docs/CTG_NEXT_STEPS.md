# CTG â€” start here (Andy)

One-page checklist for **Hacker Planet LLC** lab + website rollout. Authorized defensive use only.

**Related docs:** [SCRIPTS_CATALOG.md](SCRIPTS_CATALOG.md) Â· [SECURITY_HARDENING.md](SECURITY_HARDENING.md) Â· [PASSWORD_HARDENING.md](PASSWORD_HARDENING.md) Â· [SECRET_VAULT.md](SECRET_VAULT.md) Â· [CPU_PERFORMANCE.md](CPU_PERFORMANCE.md) Â· [KALI_RETBLEED.md](KALI_RETBLEED.md) Â· [KALI_VIRTUALBOX_SEAMLESS.md](KALI_VIRTUALBOX_SEAMLESS.md) Â· [KALI_SEAMLESS_MODE.md](KALI_SEAMLESS_MODE.md) Â· [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md)

---

## Session status (automated vs manual)

| Item | Status | Notes |
|------|--------|-------|
| Kali seamless host script | **Done** | `Start-KaliSeamless.ps1` â€” VB7 extradata, diagnose, lock retry |
| Kali guest seamless prerequisites | **Done** | `kali-boot-autopatch.sh`, `ctg-seamless-guest.sh`, staged to Backups |
| Seamless toggle on running VM | **Manual** | Log in to Kali GUI, then **Host+L** (VB7 has no `controlvm seamless`) |
| CPU safe optimize scripts | **Done** | `Optimize-CpuPerformance.ps1`, `Register-CtgCpuOptimizeTask.ps1`, docs |
| CPU `-ApplySafe` / scheduled task | **Manual (Admin)** | UAC required â€” see step 7 below |
| PII privacy Cursor rule | **Done** | `.cursor/rules/no-pii-in-repo.mdc` |
| Wi-Fi repair | **Manual (Admin)** | Wi-Fi disconnected; DDG VPN up â€” run `Repair-WindowsWifi.ps1 -ApplyFixes` elevated |
| Kali SSH autopatch | **Manual (TTY)** | If 127.0.0.1:2222 fails: `sudo bash /mnt/ctg/RUN-KALI-LAB-NOW.sh` |
| Vault secrets | **Manual** | `Protect-CtgSecrets.ps1 -SetSecret` for KALI_SSH_* (never in git) |
| pytest + push | **Done when green** | Run `pytest tests\ -q` then commit/push main + split repos |
| RETBleed host ``--spec-ctrl on`` | **Done (host)** | ``Harden-KaliVmSpectre.ps1`` applied — **reboot Kali**, then ``bash /mnt/ctg/ctg-retbleed-check.sh`` |
| Seamless menu glitch | **Manual (guest)** | ``bash /mnt/ctg/ctg-seamless-guest.sh`` if needed; host: ``Start-KaliSeamless.ps1 -DiagnoseOnly`` |

**Seamless root cause (2026-05-31 diagnose):** VM `kali` running, Guest Additions 7.0.14 OK, VRAM 128 VMSVGA OK, `GUI/Seamless=on` â€” **no graphical login** (`DesktopReady: False`). Fix: log in at Kali console, optional `bash /mnt/ctg/ctg-seamless-guest.sh`, then Host+L.

**CPU diagnose (Andy laptop):** Intel i9-8950HK, likely laptop, High performance plan active â€” **script OC: N**; manual BIOS/XTU only if desired.

---

## Tonight (Windows â€” Admin PowerShell)

Run each command in its **own** elevated window from the repo root:

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
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

## Kali TTY one-liner (if SSH on 127.0.0.1:2222 fails)

At the Kali console (Ctrl+Alt+F2 if blank screen):

```bash
sudo bash /mnt/ctg/RUN-KALI-LAB-NOW.sh
```

Or manual chain:

```bash
sudo mkdir -p /mnt/ctg && sudo mount -t vboxsf ctg-backups /mnt/ctg && sudo bash /mnt/ctg/kali-boot-autopatch.sh --install && sudo bash /mnt/ctg/ctg-lab-autorun.sh
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
cd c:\Users\Owner\Projects\cyberThreatGotchi
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
cd c:\Users\Owner\Projects\cyberThreatGotchi
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
cd c:\Users\Owner\Projects\cyberThreatGotchi
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
