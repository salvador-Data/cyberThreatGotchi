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

## OPNsense / Suricata (network IPS)

Not automated here. Typical homelab path:

1. Install OPNsense on a spare NIC/VM.
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

## Microsoft Windows cloud (OneDrive + Defender)

Interpretation: **on Windows cloud services** — Microsoft OneDrive sync, Windows Backup settings, Defender for Cloud (CSPM), and Entra ID sign-in security. Not IONOS or third-party "Ion" products.

### Scripts

| Script | Purpose |
|--------|---------|
| `selective_ssd_backup.ps1` | SSD/local selective backup + manifest |
| `cloud_backup.ps1` | Copy manifest + critical files to OneDrive `\Backups\Andy-PC-YYYY-MM-DD` |

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

Daily **4:00 AM local** task for backup (SSD + OneDrive), [hackerplanet.dev](https://hackerplanet.dev/) website sync/health, audit scans, and logging — without running disruptive hardening every night. **Harden-Windows-Security** remains a manual or weekly elevated run (`ctg_soc_run_once.ps1` or `harden_windows.ps1`); do not schedule full hardening nightly.

### Scripts

| Script | Purpose |
|--------|---------|
| `ctg_nightly_4am.ps1` | Main orchestrator (elevated preferred) |
| `ctg_website_nightly.ps1` | Website + portfolio backup, sync, health check |
| `Register-CtgNightlyTask.ps1` | Creates scheduled task **HackerPlanet-CTG-Nightly-4AM** |
| `ctg_nightly_install.ps1` | One-shot Admin installer (calls register script) |

### Orchestration order

1. Timestamp + hostname header
2. Disk space on **C:** and **D:** (if present) — warn if &lt; 5 GB free
3. **SSD detection** — Disk 1 / **D:** writable probe; logs `SSD: online|offline|not_ready`; `mount_ssd_d.ps1` if needed (Admin)
4. **selective_ssd_backup.ps1** — user data + **Projects** (`C:\Users\Owner\Projects`, robocopy caps/exclusions)
5. **ctg_website_nightly.ps1** — `website/`, `docs/web/`, portfolio → backup tree; `sync_website_to_docs.py`; GET **https://hackerplanet.dev/**
6. **cloud_backup.ps1** — mirror subset to OneDrive `\Backups\Andy-PC-YYYY-MM-DD` + `\Backups\logs\`
7. Windows Update audit, Defender QuickScan, Sysmon, Wazuh (status), VPN preserve, Git dry-run
8. **SOC logs** copied to `D:\Backups\logs\` when SSD online

### Backup matrix

| Content | Source | SSD online (`D:\Backups\Andy-PC-YYYY-MM-DD\`) | C: fallback | OneDrive mirror |
|---------|--------|-----------------------------------------------|-------------|-----------------|
| Documents / Desktop / Pictures | User folders | Via selective backup | Same | Manifest + subset via `cloud_backup.ps1` |
| **Projects** | `C:\Users\Owner\Projects` | `Projects\` (robocopy, size/exclusion caps) | Same | Manifest references |
| **Website** | `website/` | `website\` | Same | `website\` |
| **Docs web mirror** | `docs/web/` | `docs-web\` | Same | `docs-web\` |
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
| `-SkipBackup` | off | Skip selective + website + cloud backup |
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

