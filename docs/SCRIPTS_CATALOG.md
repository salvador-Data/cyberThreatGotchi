# CyberThreatGotchi - Scripts Catalog

**Hacker Planet LLC - Philadelphia, PA - Andy Kowal - [salvador-Data](https://github.com/salvador-Data)**

Every `.ps1`, `.sh`, and `.py` under `scripts/` - inventoried for authorized defensive use on systems you **own** or are **explicitly permitted** to administer. Cipherhorn-approved; no secrets in git.

**Split repos:** [ctg-kali-lab](https://github.com/salvador-Data/ctg-kali-lab) - [ctg-windows-soc](https://github.com/salvador-Data/ctg-windows-soc) - Plan ->[GITHUB_REPOS_PLAN.md](GITHUB_REPOS_PLAN.md)

---

## How to read each entry

| Field | Meaning |
|-------|---------|
| **Tagline** | One-line Hacker Planet voice |
| **Does** | What the script actually does |
| **When** | Typical trigger |
| **Admin** | Elevated / root required? |
| **Docs** | Related guides in this repo |

---

## Windows SOC & hardening

### `harden_windows.ps1`
- **Path:** `scripts/windows/harden_windows.ps1`
- **Tagline:** *Your Windows box, CIS-shaped - audit before you enforce.*
- **Does:** Orchestrates Sysmon, Harden-Windows-Security, Wazuh agent, Defender ASR - flags for audit-only vs install.
- **When:** Fresh SOC laptop setup or quarterly hardening pass.
- **Admin:** **Yes** (`#Requires -RunAsAdministrator`)
- **Docs:** [README_WINDOWS_SOC.md](../scripts/windows/README_WINDOWS_SOC.md) - [SECURITY_HARDENING.md](SECURITY_HARDENING.md) - [PORTFOLIO_SYSTEM_HARDENING.md](PORTFOLIO_SYSTEM_HARDENING.md)

### `ctg_soc_run_once.ps1`
- **Path:** `scripts/windows/ctg_soc_run_once.ps1`
- **Tagline:** *One elevated lap around the SOC stack - log it on Desktop and D:.*
- **Does:** Single-shot SOC orchestration; writes timestamped log locally and to SSD when `D:` is online.
- **When:** After clone or when you want a full SOC snapshot without nightly task.
- **Admin:** **Yes** (elevated)
- **Docs:** [README_WINDOWS_SOC.md](../scripts/windows/README_WINDOWS_SOC.md)

### `install_sysmon.ps1`
- **Path:** `scripts/windows/install_sysmon.ps1`
- **Tagline:** *SwiftOnSecurity Sysmon - process telemetry before the auditors arrive.*
- **Does:** Installs Sysmon with community baseline config.
- **When:** First host IDS layer on Windows SOC laptop.
- **Admin:** **Yes**
- **Docs:** [README_WINDOWS_SOC.md](../scripts/windows/README_WINDOWS_SOC.md)

### `wazuh_agent_setup.ps1`
- **Path:** `scripts/windows/wazuh_agent_setup.ps1`
- **Tagline:** *Point your endpoint at the lab SIEM - env vars only, no secrets in repo.*
- **Does:** Installs or verifies Wazuh agent; manager via `CTG_WAZUH_MANAGER` / `WAZUH_MANAGER`.
- **When:** After Sysmon, before enforcing ASR.
- **Admin:** **Yes**
- **Docs:** [README_WINDOWS_SOC.md](../scripts/windows/README_WINDOWS_SOC.md) - [KALI_SIEM_STACK.md](KALI_SIEM_STACK.md)

### `Harden-DDoSRogueWifi.ps1`
- **Path:** `scripts/windows/Harden-DDoSRogueWifi.ps1`
- **Tagline:** *Client-side shield against noisy neighbors and rogue AP hints.*
- **Does:** DDoS exposure checks, rogue WiFi awareness, firewall-adjacent hardening (owned networks only).
- **When:** Home lab or travel laptop hardening session.
- **Admin:** **Yes**
- **Docs:** [DEFENSE_DDOS_ROGUE_WIFI.md](DEFENSE_DDOS_ROGUE_WIFI.md)

### `Preserve-DuckDuckGoVpn.ps1`
- **Path:** `scripts/windows/Preserve-DuckDuckGoVpn.ps1`
- **Tagline:** *Don't let SOC scripts kick DuckDuckGo off the wire.*
- **Does:** Preserves DuckDuckGo VPN (WireGuard) through CTG SOC / hardening runs.
- **When:** Before/after any hardening that might touch VPN profiles.
- **Admin:** **Optional** (depends on VPN stack)
- **Docs:** [IPHONE_HARDENING.md](IPHONE_HARDENING.md) - [OPNSENSE_LAB_DNS.md](OPNSENSE_LAB_DNS.md)

### `Pause-DefenderRealtime.ps1`
- **Path:** `scripts/windows/Pause-DefenderRealtime.ps1`
- **Tagline:** *Five-minute truce for lab builds - then turn the sentinel back on.*
- **Does:** Pauses or resumes Defender real-time protection for short build windows.
- **When:** Kali VM deploy, Wireshark install, or heavy dev compile on same host.
- **Admin:** **Yes**
- **Docs:** [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md)

### `Repair-WindowsSignIn.ps1`
- **Path:** `scripts/windows/Repair-WindowsSignIn.ps1`
- **Tagline:** *When Hello/PIN ghosts you - safe sign-in repair, professor-guided.*
- **Does:** Diagnoses and repairs Windows 11 sign-in options (Password / PIN / Hello).
- **When:** After failed login or credential provider conflicts post-hardening.
- **Admin:** **Often yes**
- **Docs:** [README_WINDOWS_SOC.md](../scripts/windows/README_WINDOWS_SOC.md)


### `Repair-WindowsWifi.ps1`
- **Path:** `scripts/windows/Repair-WindowsWifi.ps1`
- **Tagline:** *Conservative Wi-Fi diagnose + WlanSvc/DNS flush — DDG-safe.*
- **Does:** Diagnose WLAN; safe fixes: WlanSvc restart, enable adapter, flush DNS. No profile wipe.
- **When:** Wi-Fi drops or stuck associating without nuking network stack.
- **Admin:** **For -ApplyFixes**
- **Docs:** [WINDOWS_WIFI_REPAIR.md](WINDOWS_WIFI_REPAIR.md)

### `Run-AsAdmin.ps1`
- **Path:** `scripts/windows/Run-AsAdmin.ps1`
- **Tagline:** *UAC elevator for the rest of the CTG flight deck.*
- **Does:** Re-launches a CTG script elevated or runs inline if already Administrator.
- **When:** Any time a script needs elevation and you started unprivileged PowerShell.
- **Admin:** Triggers UAC if not admin
- **Docs:** [README_WINDOWS_SOC.md](../scripts/windows/README_WINDOWS_SOC.md)

### `CTG-AdminCommon.ps1`
- **Path:** `scripts/windows/CTG-AdminCommon.ps1`
- **Tagline:** *Shared "are we admin yet?" for the SOC scripts.*
- **Does:** `Test-CtgIsAdmin` helper dot-sourced by other scripts.
- **When:** Imported by orchestrators - not run standalone.
- **Admin:** N/A (library)
- **Docs:** [README_WINDOWS_SOC.md](../scripts/windows/README_WINDOWS_SOC.md)

### `mount_ssd_d.ps1`
- **Path:** `scripts/windows/mount_ssd_d.ps1`
- **Tagline:** *Wake the SDK SSD as D: - no format, no drama.*
- **Does:** Brings external SDK disk online and mounts as `D:` when partition exists.
- **When:** Before nightly backup or SOC log to `D:\Backups`.
- **Admin:** **Yes**
- **Docs:** [PORTFOLIO_AUTOMATION_SOC.md](PORTFOLIO_AUTOMATION_SOC.md)

### `selective_ssd_backup.ps1`
- **Path:** `scripts/windows/selective_ssd_backup.ps1`
- **Tagline:** *Projects and gold configs to the external SSD - not a full C: clone.*
- **Does:** Selective user-data backup to external SSD.
- **When:** Nightly (via `ctg_nightly_4am.ps1`) or manual before risky changes.
- **Admin:** **Recommended**
- **Docs:** [PORTFOLIO_AUTOMATION_SOC.md](PORTFOLIO_AUTOMATION_SOC.md)

### `cloud_backup.ps1`
- **Path:** `scripts/windows/cloud_backup.ps1`
- **Tagline:** *Stage the critical slice to OneDrive - cloud sync does the rest.*
- **Does:** Stages backup manifest and critical subset for Microsoft OneDrive sync.
- **When:** After SSD backup in nightly pipeline.
- **Admin:** No
- **Docs:** [PORTFOLIO_AUTOMATION_SOC.md](PORTFOLIO_AUTOMATION_SOC.md)

### `Protect-CtgSecrets.ps1` / `Register-CtgSecretRotationReminder.ps1` / `Invoke-CtgSecretRotationSms.ps1`
- **Path:** `scripts/windows/Protect-CtgSecrets.ps1` - rotation helpers
- **Tagline:** *DPAPI vault on disk - names in git, values never.*
- **Does:** Stores Kali SSH and lab secrets under `%USERPROFILE%\Backups\.vault\`; rotation SMS reminds only (no password in SMS body).
- **When:** Before `Deploy-KaliLab.ps1 -UseSecretVault`; quarterly rotation reminder.
- **Admin:** No (CurrentUser DPAPI scope)
- **Docs:** [SECRET_VAULT.md](SECRET_VAULT.md) - [PASSWORD_HARDENING.md](PASSWORD_HARDENING.md)

### `Harden-PasswordPolicy.ps1`
- **Path:** `scripts/windows/Harden-PasswordPolicy.ps1`
- **Tagline:** *120-day max age, 10-try lockout, min length 12 - DuckDuckGo PM stays primary.*
- **Does:** Diagnoses and applies local Windows password policy via `net accounts`; never reads or rotates passwords.
- **When:** SOC hardening pass or `CTG-AuditAutorun.ps1 -HardenAndAudit`.
- **Admin:** **Yes** for `-ApplyPolicy`
- **Docs:** [PASSWORD_HARDENING.md](PASSWORD_HARDENING.md)

### `Start-KaliSeamless.ps1`
- **Path:** `scripts/windows/Start-KaliSeamless.ps1`
- **Tagline:** *VirtualBox seamless desktop - Host+L when extradata alone is not enough.*
- **Does:** Sets `GUI/Seamless=on`, starts Kali VM, waits for Guest Additions, toggles seamless on VirtualBox 6/7.
- **When:** Daily lab use after `kali-boot-autopatch.sh --install`.
- **Admin:** No (VBoxManage user rights)
- **Docs:** [KALI_VIRTUALBOX_SEAMLESS.md](KALI_VIRTUALBOX_SEAMLESS.md)

### `Stage-KaliLabToBackups.ps1`
- **Path:** `scripts/windows/Stage-KaliLabToBackups.ps1`
- **Tagline:** *Stage Kali scripts to Backups for vboxsf ctg-backups - no secrets copied.*
- **Does:** Copies autorun/bootstrap scripts to `C:\Users\Owner\Backups` for guest mount at `/mnt/ctg`.
- **When:** Before in-guest TTY one-liner or when share content is stale.
- **Admin:** No
- **Docs:** [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md) - [CTG_NEXT_STEPS.md](CTG_NEXT_STEPS.md)

---

## Kali lab (in-guest & deploy)

### `kali-lab-bootstrap.sh`
- **Path:** `scripts/kali/kali-lab-bootstrap.sh`
- **Tagline:** *Gold Kali ->CTG lab: DDG DNS, ClamAV, passive Snort, OSINT tier, WiFi Option 2.*
- **Does:** Monolithic in-guest bootstrap - harden, AV, DNS preserve, lab anonymity, Realtek WiFi tune.
- **When:** First boot after Kali install or full lab refresh.
- **Admin:** **root** (`sudo`)
- **Docs:** [README_KALI_LAB.md](../scripts/kali/README_KALI_LAB.md) - [KALI_LAB_ARCHITECTURE.md](KALI_LAB_ARCHITECTURE.md) - [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md)

### `Deploy-KaliLab.ps1`
- **Path:** `scripts/windows/Deploy-KaliLab.ps1`
- **Tagline:** *Windows host pushes the lab into VirtualBox - DDG preserve on by default.*
- **Does:** Master deploy: hypervisor detect, Wireshark/Npcap, OPNsense stub, Kali bootstrap over shared folder/SSH.
- **When:** New Kali VM or lab refresh from Windows SOC laptop.
- **Admin:** **Yes** (VM + optional Defender pause)
- **Docs:** [KALI_LAB_ARCHITECTURE.md](KALI_LAB_ARCHITECTURE.md) - [README_KALI_LAB.md](../scripts/kali/README_KALI_LAB.md)

### `Start-CTGLab.ps1`
- **Path:** `scripts/windows/Start-CTGLab.ps1`
- **Tagline:** *One button on Windows - whole CTG lab autorun chain.*
- **Does:** Orchestrates Defender pause (optional), DDG preserve, Kali deploy, Wireshark, OPNsense stub.
- **When:** Daily lab open or after Windows updates.
- **Admin:** **Yes**
- **Docs:** [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md)

### `CTG-Lab-Playground.ps1` / `ctg-lab-playground.sh`
- **Path:** `scripts/windows/CTG-Lab-Playground.ps1` - `scripts/kali/ctg-lab-playground.sh`
- **Tagline:** *Professor menu - poke tools without memorizing every autorun flag.*
- **Does:** Interactive menus to experiment with lab tools (authorized lab only).
- **When:** Learning lab layout or demoing to a student.
- **Admin:** Windows: varies - Kali: **sudo**
- **Docs:** [CTG_LAB_PLAYGROUND.md](CTG_LAB_PLAYGROUND.md)

### `Deploy-KaliBootAutopatch.ps1` / `kali-boot-autopatch.sh`
- **Path:** `scripts/windows/Deploy-KaliBootAutopatch.ps1` - `scripts/kali/kali-boot-autopatch.sh`
- **Tagline:** *VBox GNOME gremlins, meet boot-time autopatch.*
- **Does:** Deploy boot fix unit; fixes common VirtualBox/GNOME boot errors; optional apt upgrade, firmware, WiFi/IDS/SIEM flags; installs `ctg-nmap-ask` (`a$k`) to PATH on every boot with `--help` verify.
- **When:** Blank screen, DKMS, or guest-additions churn after updates.
- **Admin:** Windows deploy: **Yes** - Kali: **root**
- **Docs:** [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md) - [NMAP_ASK_ANALYSIS.md](NMAP_ASK_ANALYSIS.md)

### `ctg-nmap-ask.sh` / `a$k`
- **Path:** `scripts/kali/ctg-nmap-ask.sh` - `scripts/kali/nse/ctg-ask-recon.nse`
- **Tagline:** *Adaptive nmap ladder for lab asset inventory — reconnect by IP/MAC state.*
- **Does:** Defensive scan phases (discovery, ports, services, OS, safe NSE); lab-targets gate; JSON state under `/var/log/ctg/nmap-ask/`; shell alias `a$k`.
- **When:** Blue-team recon against authorized lab VMs; IDS validation; after autopatch `--install`.
- **Admin:** **sudo** recommended for SYN/OS scans
- **Docs:** [NMAP_ASK_ANALYSIS.md](NMAP_ASK_ANALYSIS.md) - [KALI_LAB_ARCHITECTURE.md](KALI_LAB_ARCHITECTURE.md)

### `RUN-KALI-LAB-NOW.sh`
- **Path:** `scripts/kali/RUN-KALI-LAB-NOW.sh`
- **Tagline:** *One paste when SSH from Windows fails - mount, autopatch, full autorun.*
- **Does:** Mounts vboxsf share, runs boot autopatch, scrambler install, and `ctg-lab-autorun.sh` with verify block.
- **When:** Kali TTY (Ctrl+Alt+F2) after blank screen or SSH banner failure.
- **Admin:** **sudo**
- **Docs:** [CTG_NEXT_STEPS.md](CTG_NEXT_STEPS.md) - [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md)

### `harden-password-policy.sh` / `fix-retbleed-mitigation.sh`
- **Path:** `scripts/kali/harden-password-policy.sh` - `scripts/kali/fix-retbleed-mitigation.sh`
- **Tagline:** *Guest faillock + chage - RETBleed/IBRS microcode diagnose for lab VM.*
- **Does:** Linux password policy (faillock, max age); checks kernel mitigations, reads `/sys` retbleed verdict, and recommends host `--spec-ctrl on` when vulnerable in a VM.
- **When:** During `kali-lab-bootstrap.sh` or manual hardening pass.
- **Admin:** **sudo**
- **Docs:** [PASSWORD_HARDENING.md](PASSWORD_HARDENING.md) - [KALI_RETBLEED.md](KALI_RETBLEED.md)

### `Harden-KaliVmCpu.ps1`
- **Path:** `scripts/windows/Harden-KaliVmCpu.ps1`
- **Tagline:** *The real RETBleed VM fix - expose SPEC_CTRL/PRED_CMD MSRs to the guest.*
- **Does:** Host-side `VBoxManage modifyvm kali --spec-ctrl on` (+ IBPB on VM exit/entry); graceful ACPI shutdown only when `-StopVmIfRunning`; idempotent; `-DiagnoseOnly` reports current state.
- **When:** Kali boot prints "Spectre v2 ... vulnerable to RETBleed"; VM must be powered off to apply.
- **Admin:** **Yes** (Windows host) - VM **off** for `modifyvm`
- **Docs:** [KALI_RETBLEED.md](KALI_RETBLEED.md)

### `ctg-lab-autorun.sh`
- **Path:** `scripts/kali/ctg-lab-autorun.sh`
- **Tagline:** *In-guest one-shot - bootstrap if needed, Tor + scrambler, print GUI command.*
- **Does:** Runs bootstrap if incomplete; starts tor + scrambler daemon.
- **When:** Every lab session start inside Kali.
- **Admin:** **sudo**
- **Docs:** [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md)

### `ctg-wifi-lab-autorun.sh`
- **Path:** `scripts/kali/ctg-wifi-lab-autorun.sh`
- **Tagline:** *Realtek USB, lab WPA3-SAE, promisc/monitor - legal regdomain only.*
- **Does:** USB dongle driver, lab WiFi connect, eth promisc, optional monitor mode.
- **When:** WiFi lab day or IDS on wireless segment.
- **Admin:** **sudo**
- **Docs:** [KALI_WIFI_ETH_PROMISC.md](KALI_WIFI_ETH_PROMISC.md)

### `ctg-ids-ips-autorun.sh`
- **Path:** `scripts/kali/ctg-ids-ips-autorun.sh`
- **Tagline:** *Suricata-primary IDS + ClamAV - detect-only unless you dare `--EnableIPS`.*
- **Does:** ClamAV + Suricata/Snort passive IDS; optional inline IPS on lab VLAN only.
- **When:** After bootstrap; before capturing malware samples in VM.
- **Admin:** **sudo**
- **Docs:** [KALI_IDS_IPS_CLAMAV.md](KALI_IDS_IPS_CLAMAV.md)

### `ctg-siem-autorun.sh`
- **Path:** `scripts/kali/ctg-siem-autorun.sh`
- **Tagline:** *JSON logs to the Windows tail path - Wazuh optional.*
- **Does:** Wazuh agent install optional; default local JSON aggregator for host tail.
- **When:** SIEM lab week or feeding Windows `Backups/logs/siem/`.
- **Admin:** **sudo**
- **Docs:** [KALI_SIEM_STACK.md](KALI_SIEM_STACK.md)

### `ctg-reboot-if-needed.sh`
- **Path:** `scripts/kali/ctg-reboot-if-needed.sh`
- **Tagline:** *Kernel says reboot - we schedule it politely.*
- **Does:** Marks/checks reboot after DKMS, GDM, apt; optional auto-reboot with countdown.
- **When:** End of autorun chains; disable with `CTG_NO_REBOOT=1`.
- **Admin:** **sudo** for schedule
- **Docs:** [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md)

### `rogue-ap-guard.sh`
- **Path:** `scripts/kali/rogue-ap-guard.sh`
- **Tagline:** *Evil-twin radar - passive scan, zero deauth.*
- **Does:** Detects duplicate SSIDs, open networks, evil-twin hints - no jamming.
- **When:** Home WiFi audit or travel AP survey (authorized).
- **Admin:** **sudo**
- **Docs:** [DEFENSE_DDOS_ROGUE_WIFI.md](DEFENSE_DDOS_ROGUE_WIFI.md)

### `ctg-nmap-ask.sh` (`a$k`)
- **Path:** `scripts/kali/ctg-nmap-ask.sh` - `scripts/kali/nse/ctg-ask-recon.nse`
- **Tagline:** *Adaptive nmap ladder for lab asset inventory - reconnect by IP/MAC state.*
- **Does:** Host discovery, top-port SYN/connect, `-sV`, OS detect, safe NSE; JSON state per target; `--reconnect` / `-` reloads last lab host; lab-targets gate with `-i` override warning.
- **When:** Blue-team recon on lab VLAN, DVWA/Metasploitable VMs, IDS validation after Suricata tuning.
- **Admin:** **sudo** recommended (SYN/OS/ARP); non-root degrades to connect scan.
- **Docs:** [NMAP_ASK_ANALYSIS.md](NMAP_ASK_ANALYSIS.md) - [KALI_LAB_ARCHITECTURE.md](KALI_LAB_ARCHITECTURE.md)

### `fix-kali-blank-screen.sh` / `Fix-KaliBlankScreen.ps1`
- **Path:** `scripts/kali/fix-kali-blank-screen.sh` - `scripts/windows/Fix-KaliBlankScreen.ps1`
- **Tagline:** *Black screen after login? VRAM + graphics + in-guest recovery.*
- **Does:** Fixes VirtualBox Kali blank GNOME session.
- **When:** Immediately after failed graphical login.
- **Admin:** Kali: **sudo** - Windows: **Yes**
- **Docs:** [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md) - Blank screen

### `Install-KaliVirtualBox.ps1` / `Install-OpnsenseLab.ps1` / `Install-WiresharkNpcap.ps1`
- **Path:** `scripts/windows/Install-*.ps1`
- **Tagline:** *VM factory + perimeter lab stub + host capture stack.*
- **Does:** Creates Kali or OPNsense lab VMs; installs Wireshark + Npcap on Windows host.
- **When:** First-time lab hardware setup on Andy workstation.
- **Admin:** **Yes**
- **Docs:** [KALI_LAB_ARCHITECTURE.md](KALI_LAB_ARCHITECTURE.md) - [OPNSENSE_LAB_DNS.md](OPNSENSE_LAB_DNS.md)

### Tor HTTP scrambler suite
- **Paths:** `scripts/kali/tor-http-scrambler/install-scrambler.sh`, `scrambler-daemon.sh`, `ctg-shield-rotate.sh`, `siem-hook.sh`, `ctg-scrambler-gui.py`
- **Tagline:** *Privacy-router lab module - Tor/HTTP rotate, Shield MAC/IP, SIEM nudge.*
- **Does:** Installs scrambler to `/opt/ctg/`; daemon modes tor/http/auto; GUI; SIEM-driven rotate prompts (manual y/n).
- **When:** After bootstrap `--lab-anonymity`; research on owned lab VLAN only.
- **Admin:** **sudo**
- **Docs:** [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md) - [KALI_LAB_ARCHITECTURE.md](KALI_LAB_ARCHITECTURE.md)

---

## iPhone hardening (monorepo + windows-soc)

### `iphone_hardening_automate.ps1`
- **Path:** `scripts/windows/iphone_hardening_automate.ps1`
- **Tagline:** *21-step professor walkthrough - Phase 1+2 without breaking your VPN.*
- **Does:** Full interactive orchestrator; opens runbooks; optional LAN guide server.
- **When:** New iPhone or quarterly mobile hardening.
- **Admin:** No (phone is manual; script guides)
- **Docs:** [IPHONE_HARDENING.md](IPHONE_HARDENING.md) - [IPHONE_RUN_NOW.md](IPHONE_RUN_NOW.md)

### `iphone_hardening_assist.ps1`
- **Path:** `scripts/windows/iphone_hardening_assist.ps1`
- **Tagline:** *Deprecated alias - use `iphone_hardening_automate.ps1`.*
- **Does:** Forwards all parameters to automate script.
- **When:** Legacy docs/scripts only.
- **Admin:** No
- **Docs:** [IPHONE_HARDENING.md](IPHONE_HARDENING.md)

### `iphone_usb_check.ps1`
- **Path:** `scripts/windows/iphone_usb_check.ps1`
- **Tagline:** *USB tether reminder - log-only when iPhone might be on the SOC laptop.*
- **Does:** Log-only detection reminder for USB-attached iPhone.
- **When:** Before imaging or forensic steps on phone.
- **Admin:** No
- **Docs:** [IPHONE_USB_HARDENING.md](IPHONE_USB_HARDENING.md)

---

## Audit & nightly automation

### `CTG-AuditAutorun.ps1`
- **Path:** `scripts/windows/CTG-AuditAutorun.ps1`
- **Tagline:** *Compartmentalized audit runs - harden, collect, SSD, optional cloud sink.*
- **Does:** Append-only audit under `Backups\audit\YYYY-MM-DD\`; compartments for Windows security, network IDS, SOC, Kali bridge.
- **When:** Weekly compliance snapshot or pre-travel checklist.
- **Admin:** **Yes** for hardening pass
- **Docs:** [SECURITY_HARDENING.md](SECURITY_HARDENING.md) - [PORTFOLIO_AUTOMATION_SOC.md](PORTFOLIO_AUTOMATION_SOC.md)

### `ctg_audit_paths.py`
- **Path:** `scripts/windows/ctg_audit_paths.py`
- **Tagline:** *Pure path math for audits - pytest-friendly, no PowerShell required.*
- **Does:** Path/date helpers for audit autorun.
- **When:** Imported by tests and `CTG-AuditAutorun.ps1`.
- **Admin:** N/A
- **Docs:** [SECURITY_HARDENING.md](SECURITY_HARDENING.md)

### `ctg_nightly_4am.ps1`
- **Path:** `scripts/windows/ctg_nightly_4am.ps1`
- **Tagline:** *4 AM Cipherhorn shift - backup, website, scan, audit, never flash the Cardputer.*
- **Does:** Nightly orchestrator: SSD, OneDrive, Defender scan, website sync, optional git pull; **does not** run full Harden-Windows-Security nightly.
- **When:** Scheduled daily 4:00 AM local on Andy laptop only.
- **Admin:** **Yes** (task runs highest)
- **Docs:** [PORTFOLIO_AUTOMATION_SOC.md](PORTFOLIO_AUTOMATION_SOC.md)

### `Register-CtgNightlyTask.ps1` / `ctg_nightly_install.ps1`
- **Path:** `scripts/windows/Register-CtgNightlyTask.ps1` - `ctg_nightly_install.ps1`
- **Tagline:** *Register `HackerPlanet-CTG-Nightly-4AM` - set it and sleep.*
- **Does:** Creates Windows Scheduled Task for nightly script.
- **When:** Once per machine imaging.
- **Admin:** **Yes**
- **Docs:** [PORTFOLIO_AUTOMATION_SOC.md](PORTFOLIO_AUTOMATION_SOC.md)

### `ctg_website_nightly.ps1`
- **Path:** `scripts/windows/ctg_website_nightly.ps1`
- **Tagline:** *hackerplanet.dev hygiene - backup, sync, health GET, optional deploy.*
- **Does:** Website backup, `sync_website_to_docs.py`, portfolio export, live site check.
- **When:** Called from `ctg_nightly_4am.ps1` every night.
- **Admin:** No (git push may need credentials)
- **Docs:** [GITHUB_PAGES_SETUP.md](GITHUB_PAGES_SETUP.md) - [WEBSITE_LINKS.md](WEBSITE_LINKS.md)

### `ctg_nightly_paths.py`
- **Path:** `scripts/windows/ctg_nightly_paths.py`
- **Tagline:** *Date/path helpers for the 4 AM run - unit-tested.*
- **Does:** Pure helpers for nightly automation.
- **When:** Library for nightly + tests.
- **Admin:** N/A
- **Docs:** [PORTFOLIO_AUTOMATION_SOC.md](PORTFOLIO_AUTOMATION_SOC.md)

---

## Wireshark / host IDS (Windows)

### `Start-CTGWiresharkIDS.ps1`
- **Path:** `scripts/windows/Start-CTGWiresharkIDS.ps1`
- **Tagline:** *Ring-buffer capture ->tshark/Snort/CTG analysis - optional lab IPS blocks.*
- **Does:** Wireshark IDS session with optimized ring buffer (default ON); optional repeat-offender netsh blocks.
- **When:** Active monitoring on home/lab LAN from Windows host.
- **Admin:** **Yes** for `-BlockRepeatOffenders`
- **Docs:** [README_WINDOWS_SOC.md](../scripts/windows/README_WINDOWS_SOC.md)

### `ctg_wireshark_ids_loop.ps1`
- **Path:** `scripts/windows/ctg_wireshark_ids_loop.ps1`
- **Tagline:** *Continuous IDS loop - capture, analyze, SMS when it hurts.*
- **Does:** Loops `Start-CTGWiresharkIDS.ps1`; Twilio SMS on high severity.
- **When:** Long-running SOC desk session.
- **Admin:** **Yes**
- **Docs:** [README_WINDOWS_SOC.md](../scripts/windows/README_WINDOWS_SOC.md)

### `CTG-WiresharkCommon.ps1`
- **Path:** `scripts/windows/CTG-WiresharkCommon.ps1`
- **Tagline:** *Shared tshark paths and helpers for the IDS scripts.*
- **Does:** Common functions for Wireshark IDS PowerShell scripts.
- **When:** Dot-sourced - not standalone.
- **Admin:** N/A
- **Docs:** [README_WINDOWS_SOC.md](../scripts/windows/README_WINDOWS_SOC.md)

### `analyze_traffic.py` / `wireshark_ids/__init__.py`
- **Path:** `scripts/wireshark_ids/analyze_traffic.py`
- **Tagline:** *Parse tshark exports - basic IDS patterns for authorized lab.*
- **Does:** Python analysis of exported capture files.
- **When:** Post-capture forensics or IDS loop analysis step.
- **Admin:** No
- **Docs:** [README_WINDOWS_SOC.md](../scripts/windows/README_WINDOWS_SOC.md)

### `Send-CtgSmsAlert.ps1` / `CTG-Shield-Status.ps1`
- **Path:** `scripts/windows/Send-CtgSmsAlert.ps1` - `CTG-Shield-Status.ps1`
- **Tagline:** *Twilio pager for high alerts - read-only Shield status from Windows or SSH.*
- **Does:** SMS via env-only Twilio vars; Shield IP/MAC/Tor status (optional Kali SSH).
- **When:** IDS loop alerts or lab shield check.
- **Admin:** No - SSH to Kali needs keys
- **Docs:** [SECURITY_HARDENING.md](SECURITY_HARDENING.md)

---

## Payments, fulfillment & shop

### `stripe_provision.py`
- **Path:** `scripts/stripe_provision.py`
- **Tagline:** *Stripe webhook ->CTG Pro API keys - signature verified.*
- **Does:** Handles checkout/subscription events; provisions Pro keys.
- **When:** Production webhook endpoint beside CTG web server.
- **Admin:** N/A (server process; needs `CTG_STRIPE_WEBHOOK_SECRET`)
- **Docs:** [SECURITY_HARDENING.md](SECURITY_HARDENING.md) - [ORDER_FULFILLMENT.md](ORDER_FULFILLMENT.md)

### `stripe_portal_session.py` / `check_payments.py`
- **Path:** `scripts/stripe_portal_session.py` - `check_payments.py`
- **Tagline:** *Billing portal sessions - pre-flight payment config validation.*
- **Does:** Creates Stripe Billing Portal URL; validates `payments.config.js` before go-live.
- **When:** Customer support or shop launch checklist.
- **Admin:** N/A - secrets in env only
- **Docs:** [SHOP_GO_LIVE.md](SHOP_GO_LIVE.md) - [ORDER_FULFILLMENT.md](ORDER_FULFILLMENT.md)

### `stripe_bootstrap_payment_links.py` / `stripe_link_checklist.py`
- **Path:** `scripts/stripe_bootstrap_payment_links.py` - `stripe_link_checklist.py`
- **Tagline:** *Mint Payment Links for every SKU - print what's still empty.*
- **Does:** Creates Stripe products/links; checklist of missing link keys.
- **When:** Shop SKU rollout or Kickstarter prep.
- **Admin:** N/A - `CTG_STRIPE_SECRET_KEY` in env
- **Docs:** [KICKSTARTER_LAUNCH_PLAN.md](KICKSTARTER_LAUNCH_PLAN.md) - [SHOP_GO_LIVE.md](SHOP_GO_LIVE.md)

### `fulfillment_queue.py` / `stripe_fulfillment_sync.py` / `stripe_fulfillment_import.py`
- **Path:** `scripts/fulfillment_queue.py` - `stripe_fulfillment_*.py`
- **Tagline:** *Partner fulfillment queue - PCI-safe, human-in-the-loop.*
- **Does:** Local JSON queue CLI; sync/import Stripe checkout into queue.
- **When:** After Stripe sale for drop-ship partner workflow.
- **Admin:** N/A
- **Docs:** [ORDER_FULFILLMENT.md](ORDER_FULFILLMENT.md)

### `partner_fulfillment_operator.ps1` / `partner_fulfillment_export.py` / `ebay_fulfillment_export.py`
- **Path:** `scripts/partner_fulfillment_*` - `ebay_fulfillment_export.py`
- **Tagline:** *Operator dashboard launcher - export order packets per channel.*
- **Does:** Starts web + dashboard; exports catalog-based fulfillment packets (eBay wrapper included).
- **When:** Daily fulfillment ops.
- **Admin:** No
- **Docs:** [ORDER_FULFILLMENT.md](ORDER_FULFILLMENT.md)

### `dropship_order_export.py` / `audit_dropship.py` / `check_shop.py`
- **Path:** `scripts/dropship_order_export.py` - `audit_dropship.py` - `check_shop.py`
- **Tagline:** *Etsy/AliExpress packets - catalog audit - shop config alignment.*
- **Does:** Manual marketplace order exports; validates dropship catalog and shop configs.
- **When:** Shop maintenance or new SKU.
- **Admin:** N/A
- **Docs:** [SHOP_GO_LIVE.md](SHOP_GO_LIVE.md)

---

## SEO, website & go-live

### `sync_website_to_docs.py` / `sync_seo.py` / `verify_live_site.py`
- **Path:** `scripts/sync_website_to_docs.py` - `sync_seo.py` - `verify_live_site.py`
- **Tagline:** *Mirror site to docs tree - inject SEO - HTTP-check every public URL.*
- **Does:** Copies `website/` ->`docs/web/`; meta/JSON-LD/sitemap/IndexNow; live URL checks.
- **When:** After any `website/` edit (required before push per DevSecOps rules).
- **Admin:** No
- **Docs:** [GITHUB_PAGES_SETUP.md](GITHUB_PAGES_SETUP.md) - [WEBSITE_LINKS.md](WEBSITE_LINKS.md)

### `seo_all_engines_go_live.ps1` / `seo_go_live_checklist.ps1` / `seo_gsc_go_live.ps1`
- **Path:** `scripts/seo_*.ps1`
- **Tagline:** *Search engines, meet hackerplanet.dev - interactive indexing go-live.*
- **Does:** All-engines SEO workflow; status checklist; GSC wrapper (deprecated ->all-engines).
- **When:** New domain or major site relaunch.
- **Admin:** No
- **Docs:** [GITHUB_DOMAIN_VERIFY.md](GITHUB_DOMAIN_VERIFY.md)

### `seo_verification_dns.py` / `cloudflare_apply_dns.py` / `apply_dns_interactive.ps1`
- **Path:** `scripts/seo_verification_dns.py` - `cloudflare_apply_dns.py` - `apply_dns_interactive.ps1`
- **Tagline:** *Cloudflare DNS - verification records without pasting tokens in shell history.*
- **Does:** GSC/Bing verification via API; GitHub Pages / email routing records; interactive token entry.
- **When:** Domain verification or Pages cutover.
- **Admin:** No - API token in env/prompt only
- **Docs:** [GITHUB_DOMAIN_VERIFY.md](GITHUB_DOMAIN_VERIFY.md)

### `go_live_all.ps1` / `setup_go_live.ps1` / `enable_github_pages.py` / `enable_pages.ps1` / `github_pages_https.py`
- **Path:** `scripts/go_live_*.ps1` - `enable_*.py` - `github_pages_https.py`
- **Tagline:** *Launch day automation - Pages, HTTPS, checklist orchestra.*
- **Does:** Full go-live checks; Pages enable via `gh`; HTTPS once DNS verified.
- **When:** Hacker Planet site launch or migration.
- **Admin:** No - needs `gh auth`
- **Docs:** [GITHUB_PAGES_SETUP.md](GITHUB_PAGES_SETUP.md)

### `ping_indexnow.py`
- **Path:** `scripts/ping_indexnow.py`
- **Tagline:** *Bing IndexNow ping after deploy - optional freshness nudge.*
- **Does:** Notifies IndexNow after content changes.
- **When:** Post-deploy when URLs changed materially.
- **Admin:** No
- **Docs:** [GITHUB_PAGES_SETUP.md](GITHUB_PAGES_SETUP.md)

### `patch_website_branding.py` / `patch_website_nav_logo.py` / `normalize_website_ascii.py`
- **Path:** `scripts/patch_website_*.py` - `normalize_website_ascii.py`
- **Tagline:** *Branding surgery on static HTML - logo, heroes, ASCII-safe copy.*
- **Does:** One-shot site patches for logo/nav/hero; ASCII normalization.
- **When:** Rebrand or GitHub Pages encoding fixes.
- **Admin:** No
- **Docs:** [WEBSITE_LINKS.md](WEBSITE_LINKS.md)

### `build_hacker_planet_logo.py` / `recolor_m5_logo.py` / `render_crackbot_product.py` / `export_portfolio_html.py`
- **Path:** `scripts/build_hacker_planet_logo.py` - etc.
- **Tagline:** *Wordmarks, M5 palette, CrackBot STLs, portfolio HTML export.*
- **Does:** Generates nav wordmark; recolors M5 logo; product renders; portfolio markdown ->HTML.
- **When:** Asset refresh or nightly portfolio export.
- **Admin:** No
- **Docs:** [WEBSITE_LINKS.md](WEBSITE_LINKS.md) - [PORTFOLIO_AUTOMATION_SOC.md](PORTFOLIO_AUTOMATION_SOC.md)

---

## Edge appliance (BPI-R3 Mini)

### `install.sh`
- **Path:** `scripts/install.sh`
- **Tagline:** *Banana Pi brain transplant - Python, ClamAV, YARA, systemd unit.*
- **Does:** Installs CyberThreatGotchi on BPI-R3 Mini (Debian/OpenWrt-style target).
- **When:** Fresh edge device imaging.
- **Admin:** **root**
- **Docs:** [README.md](../README.md) - [hardware/README.md](../hardware/README.md)

### `firewall-baseline.sh` / `firewall-baseline-save.sh`
- **Path:** `scripts/firewall-baseline.sh` - `firewall-baseline-save.sh`
- **Tagline:** *Default-deny iptables with CTG_BASELINE - IPS drops stay on top.*
- **Does:** Applies allow-list chain; saves rules for persistence including dynamic IPS blocks.
- **When:** Edge deploy or after changing allowed ports.
- **Admin:** **root**
- **Docs:** [SECURITY_HARDENING.md](SECURITY_HARDENING.md)

---

## Cardputer, Bjorn & integrations

### `cardputer/ctg_status.py` / `cardputer_status.py`
- **Path:** `scripts/cardputer/ctg_status.py` - `scripts/cardputer_status.py`
- **Tagline:** *Pocket status poll - Cipherhorn mood on the Cardputer screen.*
- **Does:** MicroPython or desktop poll of CTG `/api/status`.
- **When:** Manual dev on M5 Cardputer (COM13 - not nightly).
- **Admin:** N/A
- **Docs:** [CARDPUTER.md](CARDPUTER.md)

### `bjorn_bridge.py`
- **Path:** `scripts/bjorn_bridge.py`
- **Tagline:** *Bjorn e-paper meets CTG webhooks - ecosystem glue.*
- **Does:** Ingests CTG webhooks for Bjorn status display.
- **When:** Bjorn + CTG integration testing.
- **Admin:** N/A
- **Docs:** [INTEGRATIONS.md](INTEGRATIONS.md) - [ECOSYSTEM.md](ECOSYSTEM.md)

### `webhook_receiver.py`
- **Path:** `scripts/webhook_receiver.py`
- **Tagline:** *Minimal webhook sink for local CTG integration tests.*
- **Does:** Test receiver with optional `X-CTG-Secret` verify.
- **When:** `main.py --simulation` webhook dev loop.
- **Admin:** N/A
- **Docs:** [SECURITY_HARDENING.md](SECURITY_HARDENING.md) - [WEB.md](WEB.md)

### `package_release.py`
- **Path:** `scripts/package_release.py`
- **Tagline:** *Release zip bundles for GitHub Actions - cross-platform.*
- **Does:** Builds release artifacts for CI.
- **When:** CI release workflow or manual version cut.
- **Admin:** N/A
- **Docs:** [RELEASE.md](RELEASE.md)

### `mr_crackbot/password_generator.py`
- **Path:** `scripts/mr_crackbot/password_generator.py`
- **Tagline:** *Mr. CrackBot wordlists - authorized lab heuristics only.*
- **Does:** SSID-metadata-aware wordlist generation for lab exercises.
- **When:** Authorized password-audit lab modules.
- **Admin:** N/A
- **Docs:** [ECOSYSTEM.md](ECOSYSTEM.md)

---

## Quick index (all script files)

| Path | Category |
|------|----------|
| `scripts/windows/*.ps1` (34 files) | Windows SOC, lab deploy, iPhone, nightly, Wireshark |
| `scripts/windows/*.py` (2) | Audit/nightly path helpers |
| `scripts/kali/*.sh` (11 + tor-http-scrambler/) | Kali lab |
| `scripts/wireshark_ids/*.py` (2) | Host IDS analysis |
| `scripts/*.py` (35) | Payments, SEO, shop, edge utilities |
| `scripts/*.ps1` (8) | Go-live, SEO, DNS, Pages |
| `scripts/*.sh` (3) | BPI install + firewall |
| `scripts/cardputer/*.py` (1) | Cardputer status |

**Not cataloged as scripts:** `Elevate-CTG-SOC.bat` (launcher), `scripts/cloudflare/*.bind` (DNS templates), `scripts/kali/ansible/` (playbook mirror), `scripts/cardputer/platformio/` (firmware tree).

---

<p align="center"><sub>Catalog maintained with the monorepo - star <a href="https://github.com/salvador-Data/cyberThreatGotchi">cyberThreatGotchi</a> if Cipherhorn guards your network.</sub></p>

### `Harden-KaliVmSpectre.ps1`
- **Path:** `scripts/windows/Harden-KaliVmSpectre.ps1`
- **Tagline:** *Alias wrapper for Harden-KaliVmCpu.ps1 (RETBleed / spec-ctrl).*
- **Does:** Same as `Harden-KaliVmCpu.ps1` — `-DiagnoseOnly`, `-StopVmIfRunning`, `-StartAfter`.
- **Docs:** [KALI_RETBLEED_SPECTRE.md](KALI_RETBLEED_SPECTRE.md)

### `ctg-retbleed-check.sh`
- **Path:** `scripts/kali/ctg-retbleed-check.sh`
- **Tagline:** *Quick /sys vulnerabilities readout in the Kali guest.*
- **Does:** Prints retbleed/spectre_v2 verdicts; exit 1 if RETBleed-vulnerable with host fix hint.
- **When:** After host `--spec-ctrl on` and guest reboot.
- **Docs:** [KALI_RETBLEED_SPECTRE.md](KALI_RETBLEED_SPECTRE.md)

