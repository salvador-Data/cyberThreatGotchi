# Windows SOC stack â€” free hardening, IDS, IPS, SIEM

**Hacker Planet LLC / CyberThreatGotchi** â€” defensive automation for systems you **own** or are **explicitly authorized** to administer. Do not run these scripts against third-party networks without written permission.

## What you get (free tier)

| Layer | Tool | Role |
|-------|------|------|
| Hardening | [Harden-Windows-Security](https://github.com/Harden-Windows-Security/Module) | CIS-aligned baselines, GPO-style settings |
| Host IDS | [Sysmon](https://learn.microsoft.com/en-us/sysinternals/downloads/sysmon) + [SwiftOnSecurity config](https://github.com/SwiftOnSecurity/sysmon-config) | Process/network/file telemetry |
| SIEM | [Wazuh](https://wazuh.com/) | Agent â†’ manager, rules, dashboards, FIM |
| Network IPS | [OPNsense](https://opnsense.org/) + Suricata | Perimeter IDS/IPS (separate appliance) |
| Endpoint AV | Microsoft Defender | ASR rules (audit before enforce) |

Scripts live in `scripts/windows/`. They contain **no secrets** â€” set your Wazuh manager IP via environment variables only.

## Recommended install order

1. **Document & backup** â€” restore point, snapshot VM, or gold image.
2. **Sysmon** â€” host telemetry before heavy policy changes.
3. **Harden-Windows-Security** â€” audit/report first, then apply.
4. **Wazuh agent** â€” point at your manager (lab VM or homelab SIEM).
5. **Defender ASR** â€” audit mode, review Event Viewer, then enforce.
6. **OPNsense/Suricata** â€” network edge (not installed by these scripts).

## Environment variables

| Variable | Purpose |
|----------|---------|
| `CTG_WAZUH_MANAGER` | Preferred Wazuh manager IP or hostname |
| `WAZUH_MANAGER` | Alternate name (same meaning) |
| `TWILIO_ACCOUNT_SID` | Twilio SMS (see `Send-CtgSmsAlert.ps1`; `.env` only) |
| `TWILIO_AUTH_TOKEN` | Twilio auth token |
| `TWILIO_FROM_NUMBER` | Twilio from number (E.164) |
| `CTG_ALERT_SMS_TO` | SMS destination (E.164; `.env` only) |

Never commit manager credentials, Twilio secrets, or phone numbers to git. Use Wazuh dashboard enrollment for production.

## Quick start (Andy)

Open **PowerShell as Administrator**, then run **one command per block** from the repo root.

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

Review the orchestrator (guidance only â€” no hardening until you add flags):

```powershell
.\scripts\windows\harden_windows.ps1
```

Install Sysmon + SwiftOnSecurity config:

```powershell
.\scripts\windows\harden_windows.ps1 -InstallSysmon
```

Set Wazuh manager (your lab SIEM IP â€” example only):

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
| `iphone_usb_check.ps1` | Log-only: iPhone USB attached â†’ run `IPHONE_RUN_NOW` USB steps (no device modification) |
| `iphone_hardening_automate.ps1` | **Primary:** interactive 21-step Phase 1+2 orchestrator â€” USB check, deep links, `-Resume`, `-LogOnly`, `-OpenGuide`, `-ServeOnLan` |
| `iphone_hardening_assist.ps1` | Deprecated alias â€” forwards to `iphone_hardening_automate.ps1` (`-OpenRunbook` still works) |
| `Pause-DefenderRealtime.ps1` | **Admin:** pause/resume Defender real-time during PlatformIO builds |
| `Pause-DefenderRealtime.bat` | Double-click UAC shim â€” toggles realtime pause/resume |
| `Start-CTGLab.ps1` | **Master CTG lab autorun** â€” DDG, deploy Kali, Wireshark, OPNsense stub |
| `Deploy-KaliLab.ps1` | Kali lab deploy (VBox/VMware, SSH bootstrap) |
| `Install-KaliVirtualBox.ps1` | Create Kali VM from installer ISO |
| `Install-OpnsenseLab.ps1` | OPNsense lab VM (2 NICs) |
| `Install-WiresharkNpcap.ps1` | Wireshark + Npcap on Windows |
| `Start-CTGWiresharkIDS.ps1` | **Wireshark IDS** â€” tshark ring capture, heuristics, JSON alerts, optional SMS |
| `Send-CtgSmsAlert.ps1` | Twilio SMS alerts (env only; rate-limited) |
| `ctg_wireshark_ids_loop.ps1` | Continuous Wireshark IDS monitoring loop |
| `Repair-WindowsSignIn.ps1` | **Read-only** Sign-in options diagnostic (Password/PIN/Hello); safe service fixes with `-ApplySafeFixes` â€” never sets password |
| `Harden-DDoSRogueWifi.ps1` | **DDoS / rogue WiFi** â€” `-DiagnoseOnly` (any user) or `-ApplyHardening` (Admin); see [docs/DEFENSE_DDOS_ROGUE_WIFI.md](../../docs/DEFENSE_DDOS_ROGUE_WIFI.md) |

Check Wazuh without installing:

```powershell
.\scripts\windows\harden_windows.ps1 -CheckWazuhAgent
```

Sysmon only:

```powershell
.\scripts\windows\install_sysmon.ps1
```

## Windows 11 Sign-in options (Password / PIN / Hello)

If **Settings â†’ Accounts â†’ Sign-in options â†’ Password** is greyed out, **Change** does nothing, or PIN works but password path fails:

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

Read-only diagnostic (safe anytime):

```powershell
.\scripts\windows\Repair-WindowsSignIn.ps1
```

Open Sign-in options after the report:

```powershell
.\scripts\windows\Repair-WindowsSignIn.ps1 -OpenSettings
```

Safe service restart (Administrator â€” still **no password change**):

```powershell
.\scripts\windows\Repair-WindowsSignIn.ps1 -ApplySafeFixes -OpenSettings
```

**Microsoft account:** password is often managed at [account.microsoft.com/security](https://account.microsoft.com/security), not only in Settings. **Local account:** `Ctrl+Alt+Del` â†’ Change a password, or `Win+R` â†’ `netplwiz`. **CTG hardening:** `ctg_soc_run_once.ps1` runs Harden-Windows-Security **audit only** by default; full HWS enforce can enable Hello-only sign-in â€” see `ADMIN_STEPS.md`.

Log: `%USERPROFILE%\Backups\logs\repair-windows-signin.log`

## Wazuh manager (SIEM)

These scripts install the **agent** only. You need a Wazuh **manager** (Linux VM, Docker, or cloud trial):

- [Wazuh quickstart](https://documentation.wazuh.com/current/quickstart.html)
- Default agent port: **1514/TCP** to manager
- After install, confirm agent **Active** in the Wazuh dashboard

## Kali lab (VirtualBox / VMware)

Authorized analyst VM bootstrap â€” harden, ClamAV, passive Snort, OSINT apt, Realtek detect, WiFi **Option 2 company-lab** default.

| Script | Purpose |
|--------|---------|
| `Deploy-KaliLab.ps1` | **Master:** detect hypervisor, NAT SSH forward, copy/run `kali-lab-bootstrap.sh` |
| `Install-KaliVirtualBox.ps1` | Create unattended Kali VM (credentials â†’ `Backups\kali-vm-credentials.txt`) |
| `Install-OpnsenseLab.ps1` | Optional lab OPNsense VM (2 NICs; not edge by default) |
| `Install-WiresharkNpcap.ps1` | Windows Wireshark + Npcap |

Architecture: [docs/KALI_LAB_ARCHITECTURE.md](../../docs/KALI_LAB_ARCHITECTURE.md) Â· Autorun: [docs/CTG_LAB_AUTORUN.md](../../docs/CTG_LAB_AUTORUN.md) Â· Kali scripts: [scripts/kali/README_KALI_LAB.md](../kali/README_KALI_LAB.md)

**One-command lab autorun (recommended):**

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\Start-CTGLab.ps1
```

Deploy only (without full autorun chain):

```powershell
.\scripts\windows\Deploy-KaliLab.ps1 -StartVmIfStopped -InstallSshServerHint
```

If SSH is not ready, finish Kali install and run inside the guest:

```bash
sudo apt install -y openssh-server && sudo systemctl enable --now ssh
sudo bash /mnt/ctg/ctg-lab-autorun.sh
```

Or bootstrap only:

```bash
sudo bash /tmp/kali-lab-bootstrap.sh --wifi-profile=company-lab
```

## OPNsense / Suricata (network IPS)

Lab VM helper: `Install-OpnsenseLab.ps1`. Typical homelab path:

1. Install OPNsense on a spare NIC/VM (script creates `OPNsense-Lab` in VirtualBox when ISO present).
2. Enable **Intrusion Detection â†’ Suricata**.
3. Send alerts to Wazuh or syslog (optional integration).

Use for **your** perimeter/lab VLANs only.

## Wireshark IDS + SMS (Windows host)

Lab-oriented packet capture and basic anomaly detection â€” **not** a substitute for OPNsense Suricata inline IPS. Full guide: [docs/WIRESHARK_IDS_SMS.md](../../docs/WIRESHARK_IDS_SMS.md).

Install capture stack:

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\Install-WiresharkNpcap.ps1
```

Diagnose (safe anytime):

```powershell
.\scripts\windows\Start-CTGWiresharkIDS.ps1 -DiagnoseOnly
```

Run a 10-minute capture cycle:

```powershell
.\scripts\windows\Start-CTGWiresharkIDS.ps1 -CaptureMinutes 10
```

Continuous loop:

```powershell
.\scripts\windows\ctg_wireshark_ids_loop.ps1 -CycleMinutes 15
```

Optional inbound block for repeat offenders (**Administrator**, lab only):

```powershell
.\scripts\windows\Start-CTGWiresharkIDS.ps1 -CaptureMinutes 10 -BlockRepeatOffenders
```

Set Twilio + `CTG_ALERT_SMS_TO` in local `.env` (never commit). Test SMS when configured:

```powershell
.\scripts\windows\Send-CtgSmsAlert.ps1 -TestMessage
```

Logs: `%USERPROFILE%\Backups\logs\wireshark-ids.log`, `wireshark-alerts.json` Â· pcaps: `Backups\pcap\ctg-YYYY-MM-DD.pcapng`

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

**Not authorized:** unauthorized scanning, â€œred teamâ€ on systems you do not own, or evasion of monitoring on networks you do not control.

## DDoS / rogue WiFi (under attack or hardening)

Client-side posture only â€” **volumetric DDoS requires your ISP**. Full guide: [docs/DEFENSE_DDOS_ROGUE_WIFI.md](../../docs/DEFENSE_DDOS_ROGUE_WIFI.md).

Diagnose (safe without Admin):

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\Harden-DDoSRogueWifi.ps1 -DiagnoseOnly
```

Apply firewall + LLMNR/NetBIOS + WiFi open-network blocks (**Administrator**):

```powershell
.\scripts\windows\Harden-DDoSRogueWifi.ps1 -ApplyHardening
```

Or via orchestrator:

```powershell
.\scripts\windows\harden_windows.ps1 -DDoSRogueWifiDiagnose
```

```powershell
.\scripts\windows\harden_windows.ps1 -DDoSRogueWifiApply
```

Kali passive scan (inside VM): `sudo bash /mnt/ctg/rogue-ap-guard.sh -k "YourHomeSSID"`

Logs: `%USERPROFILE%\Backups\logs\harden-ddos-rogue.log`, `firewall.log`

## Related docs

- [docs/WIRESHARK_IDS_SMS.md](../../docs/WIRESHARK_IDS_SMS.md) â€” Wireshark IDS, Twilio SMS, honest IPS scope
- [docs/DEFENSE_DDOS_ROGUE_WIFI.md](../../docs/DEFENSE_DDOS_ROGUE_WIFI.md) â€” DDoS, deauth, rogue captive portal layers
- [docs/SECURITY_HARDENING.md](../../docs/SECURITY_HARDENING.md) â€” project-wide env vars and API hardening
- [docs/FIREWALL_BASELINE.md](../../docs/FIREWALL_BASELINE.md) â€” Linux/BPI-R3 firewall (complements Windows stack)
- [docs/IPHONE_HARDENING.md](../../docs/IPHONE_HARDENING.md) Â· [docs/IPHONE_RUN_NOW.md](../../docs/IPHONE_RUN_NOW.md) Â· [docs/IPHONE_USB_HARDENING.md](../../docs/IPHONE_USB_HARDENING.md) â€” iPhone Settings + USB (preserve VPN/DNS)

## iPhone USB + hardening assist (Windows SOC laptop)

When the **iPhone 15 Pro Max** is on USB-C to this PC, hardening is done **on the device** (USB Restricted Mode, Trust This Computer, Find My). CTG scripts do **not** push MDM or change iPhone Settings without Apple Business Manager.

| Item | Detail |
|------|--------|
| **Runbook** | [docs/IPHONE_RUN_NOW.md](../../docs/IPHONE_RUN_NOW.md) Phase 2 Â§ 2.3 Â· [docs/IPHONE_USB_HARDENING.md](../../docs/IPHONE_USB_HARDENING.md) |
| **Automate (primary)** | `iphone_hardening_automate.ps1` â€” 21-step interactive flow, Settings deep links, DuckDuckGo preserve warnings; [iphone_hardening_shortcuts.md](../../docs/iphone_hardening_shortcuts.md) for iOS **CTG iPhone Harden** Shortcut |
| **Guided HTML wizard** | [docs/iphone_hardening_guide.html](../../docs/iphone_hardening_guide.html) â€” Prev/Next/Mark done; sync via `?step=N` with automate script |
| **Assist (alias)** | `iphone_hardening_assist.ps1` â€” forwards to automate for backward compatibility |
| **Tap-friendly web** | [iphone-run-now.html](https://salvador-Data.github.io/cyberThreatGotchi/iphone-run-now.html) â€” open on phone |
| **Preserve VPN/DNS** | Do not install a second DNS VPN on the phone; verify **Settings â†’ VPN** after hardening (DuckDuckGo/NextDNS/1.1.1.1 unchanged) |
| **Encrypted backup** | Apple Devices â†’ **Encrypt local backup**; align with `D:\Backups\Andy-PC-*`, `C:\Users\Owner\Backups\`, OneDrive `Backups\Andy-PC-*` (see `cloud_backup.ps1`) |
| **Log stub** | `iphone_usb_check.ps1` â€” writes `Backups\logs\iphone_usb_check.log`; reminder only |
| **Assist log** | `iphone_hardening_automate.ps1` â€” writes `Backups\logs\iphone_hardening_automate.log` (legacy assist log name deprecated) |

### Automated assist (Windows + Shortcuts)

Best-effort **guided** automation â€” full Settings hardening on stock iOS is impossible without MDM. The automate script walks all 21 steps interactively; you complete toggles on the phone.

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
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

Interpretation: **on Windows cloud services** â€” Microsoft OneDrive sync, Windows Backup settings, Defender for Cloud (CSPM), and Entra ID sign-in security. Not IONOS or third-party "Ion" products.

### Build-time AV and OneDrive (PlatformIO / Cardputer)

PlatformIO builds under `Projects\` or `C:\pio\` can stall when **Microsoft Defender real-time scanning** or **OneDrive sync** locks object files mid-compile.

| Mitigation | How |
|------------|-----|
| **Defender pause (short window)** | **Administrator required.** `Pause-DefenderRealtime.ps1` â€” pause before build, **resume after**. Double-click `Pause-DefenderRealtime.bat` to toggle (UAC). |
| **Defender exclusions (preferred long-term)** | Same script with `-AddBuildExclusions` adds `C:\pio\`, `M5_OS-Cardputer\.pio`, and `Projects\` â€” keeps realtime on. |
| **OneDrive** | No reliable PowerShell pause for consumer OneDrive. **Tray icon â†’ Pause syncing** for 2/8/24 hours, or exclude build folders from sync / use `PLATFORMIO_BUILD_DIR=C:\pio\m5os-build` outside OneDrive. |

Check Defender realtime status (**Admin PowerShell**):

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\Pause-DefenderRealtime.ps1 -Status
```

Pause before a Cardputer flash (**Admin** â€” resume when done):

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

**Warning:** Do not leave realtime protection off. Nightly `ctg_nightly_4am.ps1` runs Defender QuickScan â€” pausing is for manual build windows only.

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

1. **Microsoft account** â€” Settings â†’ Accounts â†’ sign in with your Microsoft account.
2. **OneDrive** â€” Install or open OneDrive; confirm folder `C:\Users\Owner\OneDrive` (or `%OneDriveCommercial%`). Allow sync for `Backups\Andy-PC-*`.
3. **Windows Backup (Win11)** â€” Settings â†’ Accounts â†’ Windows backup â†’ enable where offered (settings sync, OneDrive folders, File History if you use it).
4. **Microsoft Defender for Cloud** â€” [Azure portal](https://portal.azure.com) â†’ Microsoft Defender for Cloud â†’ enable **Foundational CSPM** (free tier) on your subscription; review Secure Score recommendations.
5. **Entra ID (personal/work)** â€” [Microsoft Entra admin center](https://entra.microsoft.com) â†’ Protection â†’ enable MFA and review sign-in risk for your account.
6. **Optional CTG alert** â€” Set user/machine env vars `CTG_WEBHOOK_URL` and `CTG_WEBHOOK_SECRET` (never commit); `cloud_backup.ps1` posts a non-secret JSON event when both are set.

### Backup flow (recommended)

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\selective_ssd_backup.ps1
```

```powershell
.\scripts\windows\cloud_backup.ps1
```

SSD default: drive **D:** (volume label **SSD**) â†’ `D:\Backups\Andy-PC-YYYY-MM-DD\`.

### Environment variables (cloud / CTG)

| Variable | Purpose |
|----------|---------|
| `OneDrive` / `OneDriveCommercial` | Set by OneDrive client; script auto-detects |
| `CTG_WEBHOOK_URL` | Optional HTTPS endpoint for backup-complete ping |
| `CTG_WEBHOOK_SECRET` | Sent as `X-CTG-Secret` header (env only) |

## Nightly 4 AM automation

> **Portfolio deep dive:** [docs/PORTFOLIO_AUTOMATION_SOC.md](../../docs/PORTFOLIO_AUTOMATION_SOC.md) Â· LinkedIn blurb: [PORTFOLIO_AUTOMATION_SOC_SUMMARY.md](../../docs/PORTFOLIO_AUTOMATION_SOC_SUMMARY.md)

> **Windows laptop + [hackerplanet.dev](https://hackerplanet.dev/) only â€” Andy's PC.**
>
> Every run includes **ctg_website_nightly.ps1** (website backup, sync, portfolio export, health check). Does not flash or schedule anything on M5 Cardputer â€” that is separate manual dev work.

Daily **4:00 AM local** task for backup (SSD + OneDrive), **mandatory website sync/health**, audit scans, and logging â€” without running disruptive hardening every night. **Harden-Windows-Security** remains a manual or weekly elevated run (`ctg_soc_run_once.ps1` or `harden_windows.ps1`); do not schedule full hardening nightly.

### Scripts

| Script | Purpose |
|--------|---------|
| `ctg_nightly_4am.ps1` | Main orchestrator (elevated preferred) |
| `ctg_website_nightly.ps1` | Website + portfolio backup, sync, health check |
| `Register-CtgNightlyTask.ps1` | Creates scheduled task **HackerPlanet-CTG-Nightly-4AM** |
| `ctg_nightly_install.ps1` | One-shot Admin installer (calls register script) |

### Orchestration order

1. Timestamp + hostname header (laptop + hackerplanet.dev scope)
2. Disk space on **C:** and **D:** (if present) â€” warn if &lt; 5 GB free
3. **SSD detection** â€” Disk 1 / **D:** writable probe; logs `SSD: online|offline|not_ready`; `mount_ssd_d.ps1` if needed (Admin)
4. Resolve nightly backup tree (`D:\Backups\Andy-PC-YYYY-MM-DD` or C: fallback)
5. **selective_ssd_backup.ps1** â€” user data + **Projects** (skipped when `-SkipBackup`)
6. **cloud_backup.ps1** â€” mirror subset to OneDrive (skipped when `-SkipBackup`)
7. **ctg_website_nightly.ps1** â€” **always runs**: `website/`, `docs/web/`, portfolio â†’ backup tree; `sync_website_to_docs.py`; GET **https://hackerplanet.dev/**
8. Windows Update audit, Defender QuickScan, Sysmon, Wazuh (status), VPN preserve, Git dry-run
9. **SOC logs** copied to `D:\Backups\logs\` when SSD online

### Backup matrix

| Content | Source | SSD online (`D:\Backups\Andy-PC-YYYY-MM-DD\`) | C: fallback | OneDrive mirror |
|---------|--------|-----------------------------------------------|-------------|-----------------|
| Documents / Desktop / Pictures | User folders | Via selective backup | Same | Manifest + subset via `cloud_backup.ps1` |
| **Projects** | `C:\Users\Owner\Programs\Hacker Planet LLC` | `Projects\` (robocopy, size/exclusion caps) | Same | Manifest references |
| **Website** | `website/` | `website\` | Same | `website\` |
| **Docs web mirror** | `docs/web/` | `docs-web\` | Same | `docs-web\` |
| **hackerplanet.dev health** | `ctg_website_nightly.ps1` | Logged nightly | Same log on C: | N/A (live GET) |
| **Portfolio md** | `docs/PORTFOLIO_*.md` | `portfolio\` | Same | `portfolio\` |
| **Portfolio HTML** | `export_portfolio_html.py` | `portfolio_export\` | Same | `portfolio_export\` |
| Registry sample / programs list | selective backup | Root of day folder | Same | Copied by cloud_backup |
| **Nightly log** | `Backups\logs\nightly-*.log` | `D:\Backups\logs\` | Primary on C: | `OneDrive\Backups\logs\` |
| **SOC log** | Desktop `ctg-soc-run-log.txt` | `D:\Backups\logs\` | Desktop | Nightly log mirrored |

Deploy path: **GitHub Pages** via `.github/workflows/pages.yml` (`website/` â†’ `gh-pages` branch). Custom domain **hackerplanet.dev** (Cloudflare DNS â†’ GitHub Pages). Nightly run does **not** deploy unless `-DeployWebsite`.

### SSD behavior (Andy SDK drive)

At start the orchestrator checks **Disk 1** (SDK SSD), `Test-Path D:\`, and a write probe under `D:\Backups`. If the disk shows **No Media** or is not writable, it logs clearly and falls back to **C:\Users\Owner\Backups** + OneDrive only (no failure exit).

When SSD is **online and writable**:

- Runs `mount_ssd_d.ps1` if **D:** is missing or Disk 1 is offline (Admin)
- All backup rows above land under `D:\Backups\Andy-PC-YYYY-MM-DD\`
- SOC + nightly logs under `D:\Backups\logs\`

### Install (Admin PowerShell, one command per block)

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
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

Optional website deploy (commit/push â†’ GitHub Actions):

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

