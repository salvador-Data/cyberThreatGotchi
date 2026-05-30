# Windows SOC stack — free hardening, IDS, IPS, SIEM

**Hacker Planet LLC / CyberThreatGotchi** — defensive automation for systems you **own** or are **explicitly authorized** to administer. Do not run these scripts against third-party networks without written permission.

## What you get (free tier)

| Layer | Tool | Role |
|-------|------|------|
| Hardening | [Harden-Windows-Security](https://github.com/Harden-Windows-Security/Module) | CIS-aligned baselines, GPO-style settings |
| Host IDS | [Sysmon](https://learn.microsoft.com/en-us/sysinternals/downloads/sysmon) + [SwiftOnSecurity config](https://github.com/SwiftOnSecurity/sysmon-config) | Process/network/file telemetry |
| SIEM | [Wazuh](https://wazuh.com/) | Agent → manager, rules, dashboards, FIM |
| Network IPS | [OPNsense](https://opnsense.org/) + Suricata | Perimeter IDS/IPS (separate appliance) |
| Endpoint AV | Microsoft Defender | ASR rules (audit before enforce) |

Scripts live in `scripts/windows/`. They contain **no secrets** — set your Wazuh manager IP via environment variables only.

## Recommended install order

1. **Document & backup** — restore point, snapshot VM, or gold image.
2. **Sysmon** — host telemetry before heavy policy changes.
3. **Harden-Windows-Security** — audit/report first, then apply.
4. **Wazuh agent** — point at your manager (lab VM or homelab SIEM).
5. **Defender ASR** — audit mode, review Event Viewer, then enforce.
6. **OPNsense/Suricata** — network edge (not installed by these scripts).

## Environment variables

| Variable | Purpose |
|----------|---------|
| `CTG_WAZUH_MANAGER` | Preferred Wazuh manager IP or hostname |
| `WAZUH_MANAGER` | Alternate name (same meaning) |

Never commit manager credentials or enrollment passwords to git. Use Wazuh dashboard enrollment for production.

## Quick start (Andy)

Open **PowerShell as Administrator**, then run **one command per block** from the repo root.

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

Review the orchestrator (guidance only — no hardening until you add flags):

```powershell
.\scripts\windows\harden_windows.ps1
```

Install Sysmon + SwiftOnSecurity config:

```powershell
.\scripts\windows\harden_windows.ps1 -InstallSysmon
```

Set Wazuh manager (your lab SIEM IP — example only):

```powershell
$env:CTG_WAZUH_MANAGER = '192.168.1.50'
```

Install Wazuh agent:

```powershell
.\scripts\windows\harden_windows.ps1 -SetupWazuhAgent
```

Optional: Harden-Windows-Security module (audit first):

```powershell
.\scripts\windows\harden_windows.ps1 -RunHardenWindowsSecurity -HardenWindowsSecurityAuditOnly
```

Optional: Defender ASR audit mode:

```powershell
.\scripts\windows\harden_windows.ps1 -DefenderASRAudit
```

## Individual scripts

| Script | Purpose |
|--------|---------|
| `harden_windows.ps1` | Orchestrator; flags control each step |
| `install_sysmon.ps1` | Download Sysmon + SwiftOnSecurity XML |
| `wazuh_agent_setup.ps1` | MSI/winget/choco agent install |
| `iphone_usb_check.ps1` | Log-only: iPhone USB attached → run `IPHONE_RUN_NOW` USB steps (no device modification) |
| `iphone_hardening_automate.ps1` | **Primary:** interactive 21-step Phase 1+2 orchestrator — USB check, deep links, `-Resume`, `-LogOnly`, `-OpenGuide`, `-ServeOnLan` |
| `iphone_hardening_assist.ps1` | Deprecated alias — forwards to `iphone_hardening_automate.ps1` (`-OpenRunbook` still works) |
| `Pause-DefenderRealtime.ps1` | **Admin:** pause/resume Defender real-time during PlatformIO builds |
| `Pause-DefenderRealtime.bat` | Double-click UAC shim — toggles realtime pause/resume |
| `Deploy-KaliLab.ps1` | Kali lab master deploy (VBox/VMware, SSH bootstrap) |
| `Install-KaliVirtualBox.ps1` | Create Kali VM from installer ISO |
| `Install-OpnsenseLab.ps1` | OPNsense lab VM (2 NICs) |
| `Install-WiresharkNpcap.ps1` | Wireshark + Npcap on Windows |

Check Wazuh without installing:

```powershell
.\scripts\windows\harden_windows.ps1 -CheckWazuhAgent
```

Sysmon only:

```powershell
.\scripts\windows\install_sysmon.ps1
```

## Wazuh manager (SIEM)

These scripts install the **agent** only. You need a Wazuh **manager** (Linux VM, Docker, or cloud trial):

- [Wazuh quickstart](https://documentation.wazuh.com/current/quickstart.html)
- Default agent port: **1514/TCP** to manager
- After install, confirm agent **Active** in the Wazuh dashboard

## Kali lab (VirtualBox / VMware)

Authorized analyst VM bootstrap — harden, ClamAV, passive Snort, OSINT apt, Realtek detect, WiFi **Option 2 company-lab** default.

| Script | Purpose |
|--------|---------|
| `Deploy-KaliLab.ps1` | **Master:** detect hypervisor, NAT SSH forward, copy/run `kali-lab-bootstrap.sh` |
| `Install-KaliVirtualBox.ps1` | Create unattended Kali VM (credentials → `Backups\kali-vm-credentials.txt`) |
| `Install-OpnsenseLab.ps1` | Optional lab OPNsense VM (2 NICs; not edge by default) |
| `Install-WiresharkNpcap.ps1` | Windows Wireshark + Npcap |

Architecture: [docs/KALI_LAB_ARCHITECTURE.md](../../docs/KALI_LAB_ARCHITECTURE.md) · Kali scripts: [scripts/kali/README_KALI_LAB.md](../kali/README_KALI_LAB.md)

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\Deploy-KaliLab.ps1 -StartVmIfStopped -InstallSshServerHint
```

If SSH is not ready, finish Kali install and run inside the guest:

```bash
sudo apt install -y openssh-server && sudo systemctl enable --now ssh
sudo bash /tmp/kali-lab-bootstrap.sh --wifi-profile=company-lab
```

## OPNsense / Suricata (network IPS)

Lab VM helper: `Install-OpnsenseLab.ps1`. Typical homelab path:

1. Install OPNsense on a spare NIC/VM (script creates `OPNsense-Lab` in VirtualBox when ISO present).
2. Enable **Intrusion Detection → Suricata**.
3. Send alerts to Wazuh or syslog (optional integration).

Use for **your** perimeter/lab VLANs only.

## Harden-Windows-Security notes

- Module: `Install-Module Harden-Windows-Security`
- Run **audit/report** before enforce on daily-driver PCs.
- Some settings require reboot; test on a VM first.

## Verification checklist

```powershell
Get-Service Sysmon
```

```powershell
Get-Service WazuhSvc
```

```powershell
Get-MpComputerStatus | Select AMServiceEnabled, AntispywareEnabled
```

```powershell
Test-NetConnection -ComputerName $env:CTG_WAZUH_MANAGER -Port 1514
```

## Authorized use

- Corporate or personal devices you administer
- Cyber range / CTG lab VMs
- MSP customer hosts **with contract and scope**

**Not authorized:** unauthorized scanning, “red team” on systems you do not own, or evasion of monitoring on networks you do not control.

## Related docs

- [docs/SECURITY_HARDENING.md](../../docs/SECURITY_HARDENING.md) — project-wide env vars and API hardening
- [docs/FIREWALL_BASELINE.md](../../docs/FIREWALL_BASELINE.md) — Linux/BPI-R3 firewall (complements Windows stack)
- [docs/IPHONE_HARDENING.md](../../docs/IPHONE_HARDENING.md) · [docs/IPHONE_RUN_NOW.md](../../docs/IPHONE_RUN_NOW.md) · [docs/IPHONE_USB_HARDENING.md](../../docs/IPHONE_USB_HARDENING.md) — iPhone Settings + USB (preserve VPN/DNS)

## iPhone USB + hardening assist (Windows SOC laptop)

When the **iPhone 15 Pro Max** is on USB-C to this PC, hardening is done **on the device** (USB Restricted Mode, Trust This Computer, Find My). CTG scripts do **not** push MDM or change iPhone Settings without Apple Business Manager.

| Item | Detail |
|------|--------|
| **Runbook** | [docs/IPHONE_RUN_NOW.md](../../docs/IPHONE_RUN_NOW.md) Phase 2 § 2.3 · [docs/IPHONE_USB_HARDENING.md](../../docs/IPHONE_USB_HARDENING.md) |
| **Automate (primary)** | `iphone_hardening_automate.ps1` — 21-step interactive flow, Settings deep links, DuckDuckGo preserve warnings; [iphone_hardening_shortcuts.md](../../docs/iphone_hardening_shortcuts.md) for iOS **CTG iPhone Harden** Shortcut |
| **Guided HTML wizard** | [docs/iphone_hardening_guide.html](../../docs/iphone_hardening_guide.html) — Prev/Next/Mark done; sync via `?step=N` with automate script |
| **Assist (alias)** | `iphone_hardening_assist.ps1` — forwards to automate for backward compatibility |
| **Tap-friendly web** | [iphone-run-now.html](https://salvador-Data.github.io/cyberThreatGotchi/iphone-run-now.html) — open on phone |
| **Preserve VPN/DNS** | Do not install a second DNS VPN on the phone; verify **Settings → VPN** after hardening (DuckDuckGo/NextDNS/1.1.1.1 unchanged) |
| **Encrypted backup** | Apple Devices → **Encrypt local backup**; align with `D:\Backups\Andy-PC-*`, `C:\Users\Owner\Backups\`, OneDrive `Backups\Andy-PC-*` (see `cloud_backup.ps1`) |
| **Log stub** | `iphone_usb_check.ps1` — writes `Backups\logs\iphone_usb_check.log`; reminder only |
| **Assist log** | `iphone_hardening_automate.ps1` — writes `Backups\logs\iphone_hardening_automate.log` (legacy assist log name deprecated) |

### Automated assist (Windows + Shortcuts)

Best-effort **guided** automation — full Settings hardening on stock iOS is impossible without MDM. The automate script walks all 21 steps interactively; you complete toggles on the phone.

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

Full 21-step flow + HTML wizard (recommended):

```powershell
.\scripts\windows\iphone_hardening_automate.ps1 -OpenGuide
```

Resume after interruption:

```powershell
.\scripts\windows\iphone_hardening_automate.ps1 -Resume -OpenGuide
```

Interactive assist + open runbook (legacy alias):

```powershell
.\scripts\windows\iphone_hardening_assist.ps1 -OpenRunbook
```

Log-only check (CI-style, no prompts):

```powershell
.\scripts\windows\iphone_hardening_automate.ps1 -LogOnly
```

USB reminder only:

```powershell
.\scripts\windows\iphone_usb_check.ps1
```

Nightly `ctg_nightly_4am.ps1` does not run Apple backup or iPhone hardening assist (phone must be unlocked and trusted; assist is manual).

## Microsoft Windows cloud (OneDrive + Defender)

Interpretation: **on Windows cloud services** — Microsoft OneDrive sync, Windows Backup settings, Defender for Cloud (CSPM), and Entra ID sign-in security. Not IONOS or third-party "Ion" products.

### Build-time AV and OneDrive (PlatformIO / Cardputer)

PlatformIO builds under `Projects\` or `C:\pio\` can stall when **Microsoft Defender real-time scanning** or **OneDrive sync** locks object files mid-compile.

| Mitigation | How |
|------------|-----|
| **Defender pause (short window)** | **Administrator required.** `Pause-DefenderRealtime.ps1` — pause before build, **resume after**. Double-click `Pause-DefenderRealtime.bat` to toggle (UAC). |
| **Defender exclusions (preferred long-term)** | Same script with `-AddBuildExclusions` adds `C:\pio\`, `M5_OS-Cardputer\.pio`, and `Projects\` — keeps realtime on. |
| **OneDrive** | No reliable PowerShell pause for consumer OneDrive. **Tray icon → Pause syncing** for 2/8/24 hours, or exclude build folders from sync / use `PLATFORMIO_BUILD_DIR=C:\pio\m5os-build` outside OneDrive. |

Check Defender realtime status (**Admin PowerShell**):

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\Pause-DefenderRealtime.ps1 -Status
```

Pause before a Cardputer flash (**Admin** — resume when done):

```powershell
.\scripts\windows\Pause-DefenderRealtime.ps1 -Pause
```

Resume after build:

```powershell
.\scripts\windows\Pause-DefenderRealtime.ps1 -Resume
```

Optional persistent build exclusions (Admin, one-time):

```powershell
.\scripts\windows\Pause-DefenderRealtime.ps1 -AddBuildExclusions
```

**Warning:** Do not leave realtime protection off. Nightly `ctg_nightly_4am.ps1` runs Defender QuickScan — pausing is for manual build windows only.

### Scripts

| Script | Purpose |
|--------|---------|
| `selective_ssd_backup.ps1` | SSD/local selective backup + manifest |
| `cloud_backup.ps1` | Copy manifest + critical files to OneDrive `\Backups\Andy-PC-YYYY-MM-DD` |
| `Pause-DefenderRealtime.ps1` | Pause/resume Defender realtime; optional build-path exclusions |
| `Pause-DefenderRealtime.bat` | UAC elevation shim (toggle) |

Orchestrator flag:

```powershell
.\scripts\windows\harden_windows.ps1 -CloudBackup
```

### Andy manual steps (required once)

1. **Microsoft account** — Settings → Accounts → sign in with your Microsoft account.
2. **OneDrive** — Install or open OneDrive; confirm folder `C:\Users\Owner\OneDrive` (or `%OneDriveCommercial%`). Allow sync for `Backups\Andy-PC-*`.
3. **Windows Backup (Win11)** — Settings → Accounts → Windows backup → enable where offered (settings sync, OneDrive folders, File History if you use it).
4. **Microsoft Defender for Cloud** — [Azure portal](https://portal.azure.com) → Microsoft Defender for Cloud → enable **Foundational CSPM** (free tier) on your subscription; review Secure Score recommendations.
5. **Entra ID (personal/work)** — [Microsoft Entra admin center](https://entra.microsoft.com) → Protection → enable MFA and review sign-in risk for your account.
6. **Optional CTG alert** — Set user/machine env vars `CTG_WEBHOOK_URL` and `CTG_WEBHOOK_SECRET` (never commit); `cloud_backup.ps1` posts a non-secret JSON event when both are set.

### Backup flow (recommended)

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\selective_ssd_backup.ps1
```

```powershell
.\scripts\windows\cloud_backup.ps1
```

SSD default: drive **D:** (volume label **SSD**) → `D:\Backups\Andy-PC-YYYY-MM-DD\`.

### Environment variables (cloud / CTG)

| Variable | Purpose |
|----------|---------|
| `OneDrive` / `OneDriveCommercial` | Set by OneDrive client; script auto-detects |
| `CTG_WEBHOOK_URL` | Optional HTTPS endpoint for backup-complete ping |
| `CTG_WEBHOOK_SECRET` | Sent as `X-CTG-Secret` header (env only) |

## Nightly 4 AM automation

> **Portfolio deep dive:** [docs/PORTFOLIO_AUTOMATION_SOC.md](../../docs/PORTFOLIO_AUTOMATION_SOC.md) · LinkedIn blurb: [PORTFOLIO_AUTOMATION_SOC_SUMMARY.md](../../docs/PORTFOLIO_AUTOMATION_SOC_SUMMARY.md)

> **Windows laptop + [hackerplanet.dev](https://hackerplanet.dev/) only — Andy's PC.**
>
> Every run includes **ctg_website_nightly.ps1** (website backup, sync, portfolio export, health check). Does not flash or schedule anything on M5 Cardputer — that is separate manual dev work.

Daily **4:00 AM local** task for backup (SSD + OneDrive), **mandatory website sync/health**, audit scans, and logging — without running disruptive hardening every night. **Harden-Windows-Security** remains a manual or weekly elevated run (`ctg_soc_run_once.ps1` or `harden_windows.ps1`); do not schedule full hardening nightly.

### Scripts

| Script | Purpose |
|--------|---------|
| `ctg_nightly_4am.ps1` | Main orchestrator (elevated preferred) |
| `ctg_website_nightly.ps1` | Website + portfolio backup, sync, health check |
| `Register-CtgNightlyTask.ps1` | Creates scheduled task **HackerPlanet-CTG-Nightly-4AM** |
| `ctg_nightly_install.ps1` | One-shot Admin installer (calls register script) |

### Orchestration order

1. Timestamp + hostname header (laptop + hackerplanet.dev scope)
2. Disk space on **C:** and **D:** (if present) — warn if &lt; 5 GB free
3. **SSD detection** — Disk 1 / **D:** writable probe; logs `SSD: online|offline|not_ready`; `mount_ssd_d.ps1` if needed (Admin)
4. Resolve nightly backup tree (`D:\Backups\Andy-PC-YYYY-MM-DD` or C: fallback)
5. **selective_ssd_backup.ps1** — user data + **Projects** (skipped when `-SkipBackup`)
6. **cloud_backup.ps1** — mirror subset to OneDrive (skipped when `-SkipBackup`)
7. **ctg_website_nightly.ps1** — **always runs**: `website/`, `docs/web/`, portfolio → backup tree; `sync_website_to_docs.py`; GET **https://hackerplanet.dev/**
8. Windows Update audit, Defender QuickScan, Sysmon, Wazuh (status), VPN preserve, Git dry-run
9. **SOC logs** copied to `D:\Backups\logs\` when SSD online

### Backup matrix

| Content | Source | SSD online (`D:\Backups\Andy-PC-YYYY-MM-DD\`) | C: fallback | OneDrive mirror |
|---------|--------|-----------------------------------------------|-------------|-----------------|
| Documents / Desktop / Pictures | User folders | Via selective backup | Same | Manifest + subset via `cloud_backup.ps1` |
| **Projects** | `C:\Users\Owner\Projects` | `Projects\` (robocopy, size/exclusion caps) | Same | Manifest references |
| **Website** | `website/` | `website\` | Same | `website\` |
| **Docs web mirror** | `docs/web/` | `docs-web\` | Same | `docs-web\` |
| **hackerplanet.dev health** | `ctg_website_nightly.ps1` | Logged nightly | Same log on C: | N/A (live GET) |
| **Portfolio md** | `docs/PORTFOLIO_*.md` | `portfolio\` | Same | `portfolio\` |
| **Portfolio HTML** | `export_portfolio_html.py` | `portfolio_export\` | Same | `portfolio_export\` |
| Registry sample / programs list | selective backup | Root of day folder | Same | Copied by cloud_backup |
| **Nightly log** | `Backups\logs\nightly-*.log` | `D:\Backups\logs\` | Primary on C: | `OneDrive\Backups\logs\` |
| **SOC log** | Desktop `ctg-soc-run-log.txt` | `D:\Backups\logs\` | Desktop | Nightly log mirrored |

Deploy path: **GitHub Pages** via `.github/workflows/pages.yml` (`website/` → `gh-pages` branch). Custom domain **hackerplanet.dev** (Cloudflare DNS → GitHub Pages). Nightly run does **not** deploy unless `-DeployWebsite`.

### SSD behavior (Andy SDK drive)

At start the orchestrator checks **Disk 1** (SDK SSD), `Test-Path D:\`, and a write probe under `D:\Backups`. If the disk shows **No Media** or is not writable, it logs clearly and falls back to **C:\Users\Owner\Backups** + OneDrive only (no failure exit).

When SSD is **online and writable**:

- Runs `mount_ssd_d.ps1` if **D:** is missing or Disk 1 is offline (Admin)
- All backup rows above land under `D:\Backups\Andy-PC-YYYY-MM-DD\`
- SOC + nightly logs under `D:\Backups\logs\`

### Install (Admin PowerShell, one command per block)

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\ctg_nightly_install.ps1
```

Verify task:

```powershell
Get-ScheduledTask -TaskName 'HackerPlanet-CTG-Nightly-4AM' | Format-List
```

Manual test run (no wait until 4 AM):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\ctg_nightly_4am.ps1 -VerboseLog
```

Optional website deploy (commit/push → GitHub Actions):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\ctg_nightly_4am.ps1 -DeployWebsite -VerboseLog
```

### Flags

| Flag | Default | Effect |
|------|---------|--------|
| `-ApplyUpdates` | off | Install Windows Updates (may reboot) |
| `-SkipBackup` | off | Skip selective + cloud backup only; **website nightly still runs** |
| `-DeployWebsite` | off | Commit/push `website/` + `docs/web/` to `main` |
| `-SyncRepos` | off | `git pull` instead of dry-run log |
| `-VerboseLog` | off | Echo steps to console |

### Log paths

| Path | Purpose |
|------|---------|
| `C:\Users\Owner\Backups\logs\nightly-YYYY-MM-DD.log` | Primary nightly log |
| `%USERPROFILE%\Desktop\ctg-soc-run-log.txt` | Append mirror (SOC history) |
| `D:\Backups\logs\nightly-YYYY-MM-DD.log` | SSD copy when Disk 1 online |
| `D:\Backups\logs\ctg-soc-run-log.txt` | SSD SOC mirror |
| `%OneDrive%\Backups\logs\nightly-YYYY-MM-DD.log` | OneDrive cloud mirror |

