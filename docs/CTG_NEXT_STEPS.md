# CTG â€” start here (Andy)

One-page checklist for **Hacker Planet LLC** lab + website rollout. Authorized defensive use only.

**Related docs:** [CTG_ONE_WORKING.md](CTG_ONE_WORKING.md) · [SCRIPTS_CATALOG.md](SCRIPTS_CATALOG.md) · [CYBERSECURITY_ETHICS.md](CYBERSECURITY_ETHICS.md) · [SECURITY_HARDENING.md](SECURITY_HARDENING.md) · [UTMS_WIFI_AI.md](UTMS_WIFI_AI.md) · [LAB_MATURITY.md](LAB_MATURITY.md) · [EMAIL_NOTIFICATIONS.md](EMAIL_NOTIFICATIONS.md) · [GITHUB_NOTIFICATIONS.md](GITHUB_NOTIFICATIONS.md) · [LAB_VLAN.md](LAB_VLAN.md) · [MEMORY_PROTECTION.md](MEMORY_PROTECTION.md) · [PASSWORD_HARDENING.md](PASSWORD_HARDENING.md) · [SECRET_VAULT.md](SECRET_VAULT.md) · [CPU_PERFORMANCE.md](CPU_PERFORMANCE.md) · [KALI_RETBLEED.md](KALI_RETBLEED.md) · [KALI_VIRTUALBOX_SEAMLESS.md](KALI_VIRTUALBOX_SEAMLESS.md) · [KALI_SEAMLESS_MODE.md](KALI_SEAMLESS_MODE.md) · [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md)

---

## Lab maturity 8–9/10 (2026-05-31)

**Rubric:** [LAB_MATURITY.md](LAB_MATURITY.md) (NIST CSF self-score 1–10)

| Area | Script / doc | Andy manual |
|------|----------------|-------------|
| EDR baseline | `Harden-CtgWindowsDefender.ps1 -DiagnoseOnly` | `-ApplySafe` (Admin) after ASR audit review |
| VLAN | `Test-CtgLabNetworkSegment.ps1`, [LAB_VLAN.md](LAB_VLAN.md) | Copy `lab-vlan.conf.example` → Backups |
| SIEM sink | `Install-CtgWazuhLab.ps1 -DiagnoseOnly` | Docker + `-ApplySafe`; set `CTG_WAZUH_MANAGER` |
| Golden Kali | `Snapshot-CtgKaliGolden.ps1` after CLICK-ME success | `-ApplySafe` when lab chain clean |
| Restore drill | `Invoke-CtgRestoreDrill.ps1 -ReportOnly` | `Register-CtgRestoreDrillTask.ps1` (Admin) |
| CIS subset | `Test-CtgCisBenchmarkDiagnose.ps1` | Review WARN lines |
| Email → Kali | [EMAIL_NOTIFICATIONS.md](EMAIL_NOTIFICATIONS.md) | `Initialize-CtgEmailVault.ps1`; Proton Bridge |
| GitHub CI mail | [GITHUB_NOTIFICATIONS.md](GITHUB_NOTIFICATIONS.md) | Proton filter + fix CI first |
| UTMS Wi-Fi AI | [UTMS_WIFI_AI.md](UTMS_WIFI_AI.md) | Event bus + jam/deauth detect (no RF counter-jam) |
| iOS MDM checklist | `Export-CtgIosProfileChecklist.ps1` | Supervision optional (fleet only) |
| **Print = run (iPhone)** | [IPHONE_AUDIT_PRINT.md](IPHONE_AUDIT_PRINT.md) | Manual Settings on device; preserve DDG VPN/DNS/PM |
| **Print = run (Windows SOC)** | [WINDOWS_SOC_AUDIT_PRINT.md](WINDOWS_SOC_AUDIT_PRINT.md) | `Invoke-CtgPreserveStackAudit.ps1` |
| **Print = run (all domains)** | [print/README_PRINT_ALL.md](print/README_PRINT_ALL.md) | `Invoke-CtgPrintAllAudit.ps1 -OpenPrintFolder` |

**Email vault titles needed:** `Proton IMAP` (or `CTG_EMAIL_IMAP`); optional `Microsoft Account`.

**One orchestrator (recommended):**

```powershell
cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
```

```powershell
.\scripts\windows\Invoke-CtgOneWorking.ps1
```

**Quick diagnose batch (no creds required):**

```powershell
.\scripts\windows\Invoke-CtgInstallAudit.ps1 -Json
```

```powershell
.\scripts\windows\Invoke-CtgPrintAllAudit.ps1
```

```powershell
.\scripts\windows\Invoke-CtgPreserveStackAudit.ps1
```

```powershell
.\scripts\windows\Initialize-CtgEmailVault.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Harden-CtgWindowsDefender.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Invoke-CtgRestoreDrill.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Start-CtgEventBus.ps1 -DiagnoseOnly
```

---

## Install audit (2026-05-31)

**Source of truth:** `.\scripts\windows\Invoke-CtgInstallAudit.ps1` — writes `%USERPROFILE%\Backups\logs\ctg-install-audit-*.txt`.

```powershell
cd "$env:USERPROFILE\Programs\Hacker Planet LLC\cyberThreatGotchi"
```

```powershell
.\scripts\windows\Invoke-CtgInstallAudit.ps1 -Json
```

```powershell
.\scripts\windows\Invoke-CtgInstallAudit.ps1 -ApplySafe
```

| Component | Status | Notes |
|-----------|--------|-------|
| Python `.venv` + cryptography/argon2 | **INSTALLED** | Safe pip via `-ApplySafe` |
| Legacy DPAPI `secrets.dpapi` | **INSTALLED** | Migrate to `Ctg-CredentialVault` when ready |
| `Ctg-CredentialVault` | **MANUAL** | `-InitVault -WithDpapiWrap` (interactive) |
| All `HackerPlanet-CTG-*` tasks | **MANUAL** | Admin: `Register-Ctg*.ps1` |
| signal-cli / Snort / Suricata | **OPTIONAL** | Install scripts exist; not on PATH |
| Proton Mail Bridge | **MANUAL** | User install; email vault titles in PM |
| Docker + Wazuh lab | **MANUAL** | Docker Desktop not installed |
| Defender ASR `-ApplySafe` | **MANUAL** | Admin after `-DiagnoseOnly` review |
| Kali staged to Backups | **INSTALLED** | `Stage-KaliLabToBackups.ps1` / `-ApplySafe` |
| Kali guest lab chain | **MANUAL** | CLICK-ME or share trigger |
| Kali spec-ctrl | **MANUAL** | `Harden-KaliVmSpectre.ps1 -DiagnoseOnly` |
| PlatformIO / Cardputer COM13 | **OPTIONAL / MANUAL** | Detect only; flash on request |
| Ecosystem clones (Programs) | **INSTALLED** | All required repos present 2026-05-31 |

Cursor rules: `.cursor/rules/ctg-install-status.mdc`, `cybersecurity-ethics.mdc`. Ethics doc: [CYBERSECURITY_ETHICS.md](CYBERSECURITY_ETHICS.md).

**Admin one-liners (elevated, from repo root):**

```powershell
.\scripts\windows\Register-CtgNightlyTask.ps1
```

```powershell
.\scripts\windows\Register-CtgCpuOptimizeTask.ps1
```

```powershell
.\scripts\windows\Register-CtgMemoryProtectionTask.ps1
```

```powershell
.\scripts\windows\Harden-CtgWindowsDefender.ps1 -ApplySafe
```

---

## Good build snapshot (2026-05-31)

**Canonical repo path:** `C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi` — reopen Cursor here (not `Projects\cyberThreatGotchi` unless you sync clones).

### Done on main
- **UTMS Wi-Fi AI stack:** [UTMS_WIFI_AI.md](UTMS_WIFI_AI.md) — event bus, jam/deauth detect, threat-pack OTA, Cardputer bridge
- `core/ctg_event_bus.py`, `core/ctg_event_summarize.py`, Windows/Kali scripts (see [SCRIPTS_CATALOG.md](SCRIPTS_CATALOG.md))
- Kali share path: `ctg-run-on-share-trigger.sh`, `CTG_RUN_AUTORUN_NOW` trigger, `ctg-watch-trigger.sh` polling
- One-click in guest: `CLICK-ME-RUN-IN-KALI.sh` + `CLICK-ME-RUN-IN-KALI.desktop` (staged to `C:\Users\Owner\Backups` / vboxsf)
- Host: `Invoke-CtgKaliGuestFlash.ps1 -UseSecretVault` (credential vault → DPAPI → credentials file; no passwords in git)
- Encrypted credential vault: `Ctg-CredentialVault.ps1`, `core/ctg_vault.py`, `scripts/ctg_vault_cli.py`
- **Memory protection:** `Enforce-CtgMemoryProtection.ps1`, `Register-CtgMemoryProtectionTask.ps1`, Kali `ctg-ram-mitigation-enforcer.sh` — see [MEMORY_PROTECTION.md](MEMORY_PROTECTION.md)
- Host: `Start-KaliSeamless.ps1` diagnostic string fixes; `Invoke-CtgKaliNmapAskInstall.ps1` for nmap-ask install trigger
- Lab tree re-staged: `Stage-KaliLabToBackups.ps1` (2026-05-31 — full tree on `ctg-backups` share)
- Path helpers: `CTG-Paths.ps1` resolves Programs root + canonical repo
- Tests: **496 passed, 4 skipped** (`pytest tests/ -q`, 2026-05-31 UTMS Wi-Fi AI pass)

### Good build run log (2026-05-31, Windows SOC)
| Command | Outcome |
|---------|---------|
| `pytest tests/ -q` (canonical `.venv`) | **450 passed**, 4 skipped (~2.5 min) |
| `Optimize-CpuPerformance.ps1 -DiagnoseOnly` | OK — i9-8950HK, High performance plan active |
| `Optimize-GpuPerformance.ps1 -ApplySafe` | Visual effects applied; NVIDIA `-pm` needs Admin |
| `Optimize-CpuPerformance.ps1 -ApplySafe` | **Needs Admin UAC** — use `Run-AsAdmin.ps1` |
| `Register-CtgCpuOptimizeTask.ps1` | **Manual (Admin)** — not registered this session |
| `Stage-KaliLabToBackups.ps1` | OK — 35+ `.sh`, CLICK-ME, docs → `C:\Users\Owner\Backups` |
| `Set-CtgPrivateRepos.ps1 -DiagnoseOnly` | Verify ctg-kali-lab, ctg-windows-soc, ctg-device-hardening |
| `Get-ScheduledTask HackerPlanet-CTG-*` | CPU task manual Admin registration |
| `Invoke-CtgKaliGuestFlash.ps1` | **Not run** (live creds/guest login — use CLICK-ME or share trigger) |

### Manual (Kali / Windows)
| Step | Action |
|------|--------|
| Kali lab chain | Log into Xfce → double-click **CTG Run Lab (click me)** or `bash /media/sf_ctg-backups/CLICK-ME-RUN-IN-KALI.sh` (sudo password once) |
| Share trigger (no SSH) | Windows: `New-Item C:\Users\Owner\Backups\CTG_RUN_AUTORUN_NOW -ItemType File -Force` while guest logged in |
| Secrets | `Ctg-CredentialVault.ps1 -InitVault` + title **`Kali SSH`**, or `Protect-CtgSecrets.ps1 -SetSecret`; rotate Kali login when ready |
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
| GPU safe optimize script | **Done** | `Optimize-GpuPerformance.ps1`, docs/CPU_PERFORMANCE.md GPU section |
| CPU `-ApplySafe` / scheduled task | **Manual (Admin)** | UAC required — see step 7 below |
| GPU `-ApplySafe` (NVIDIA `-pm`) | **Partial** | Visual effects applied; `-pm 1` needs Admin |
| PII privacy Cursor rule | **Done** | `.cursor/rules/no-pii-in-repo.mdc` |
| Wi-Fi repair | **Manual (Admin)** | Wi-Fi disconnected; DDG VPN up â€” run `Repair-WindowsWifi.ps1 -ApplyFixes` elevated |
| Kali SSH autopatch | **Manual (TTY)** | If 127.0.0.1:2222 fails: `sudo bash /mnt/ctg/RUN-KALI-LAB-NOW.sh` |
| Vault secrets | **Manual** | `Ctg-CredentialVault.ps1` (title `Kali SSH`) or `Protect-CtgSecrets.ps1` — never in git |
| Lab split repos private | **Done** | `Set-CtgPrivateRepos.ps1 -Apply` — ctg-kali-lab, ctg-windows-soc, ctg-device-hardening |
| pytest + push | **Done** | Run before each push; see pytest section below |
| RETBleed `--spec-ctrl on` | **Done (live)** | VBox `<SpecCtrl enabled="true"/>` — **reboot Kali**, then `bash /mnt/ctg/ctg-retbleed-check.sh` |
| Kali scripts staged to Backups | **Done** | `Stage-KaliLabToBackups.ps1` — CLICK-ME + triggers on `ctg-backups` share |
| Guest script flash | **Manual (CLICK-ME)** | Desktop one-click or `CTG_RUN_AUTORUN_NOW` on share; skip host guest-flash retry loops |
| Seamless View menu | **Manual (GUI login)** | `GUI/Seamless=on` set; menu stays gray until **LoggedInUsers>0** — log in Xfce, then Host+L |
| Seamless menu glitch | **Manual (guest)** | ``bash /mnt/ctg/ctg-seamless-guest.sh`` if needed; host: ``Start-KaliSeamless.ps1 -DiagnoseOnly`` |

**Seamless (2026-05-31 live):** VM **running headless** — `DesktopReady: False` (log in at Kali GUI). After login: `Start-KaliSeamless.ps1` (GUI session) or **Host+L**; if menu reverts: `bash /mnt/ctg/ctg-seamless-guest.sh`. **spec-ctrl:** ON (`Harden-KaliVmSpectre.ps1 -DiagnoseOnly`).

---

## Print = run session (2026-05-31)

**Goal:** Printable **full-stack** audit bundle (iPhone, Windows, Kali, memory, UTMS, vault, GitHub, NIST maturity); DDG VPN/DNS/Password Manager preserved.

| Deliverable | Path |
|-------------|------|
| **Print-all index** | [print/README_PRINT_ALL.md](print/README_PRINT_ALL.md) |
| iPhone printable | [IPHONE_AUDIT_PRINT.md](IPHONE_AUDIT_PRINT.md) |
| Windows printable | [WINDOWS_SOC_AUDIT_PRINT.md](WINDOWS_SOC_AUDIT_PRINT.md) |
| Kali / memory / UTMS / vault / GitHub sheets | `docs/print/*.md` |
| Combined one-job print | [print/PRINT_ALL.html](print/PRINT_ALL.html) |
| Print-all script | `scripts/windows/Invoke-CtgPrintAllAudit.ps1` |
| Stack audit script | `scripts/windows/Invoke-CtgPreserveStackAudit.ps1` |

**Windows run:** `Invoke-CtgPrintAllAudit.ps1 -OpenPrintFolder` (lists all sheets + stack audit + `ctg-print-all-audit-*.txt`). Or `Invoke-CtgPreserveStackAudit.ps1` alone. Optional `-ApplySafeDefender` when Admin after ASR review. **Do not** run `Repair-WindowsWifi.ps1 -ApplyFixes` unless diagnose shows issues and DDG preserve passes.

**iPhone run:** Print or AirDrop `IPHONE_AUDIT_PRINT.md` → complete Phase 0 → Phase 1 → **1.V verify** → Phase 2 → **2.V verify** on device. Windows: `iphone_tethering_privacy_checklist.ps1 -DetectUsb` (read-only).

**Admin skipped this session:** Defender exclusions (DDG paths), `Repair-WindowsWifi -ApplyFixes`, `Harden-CtgWindowsDefender -ApplySafe` — run elevated when ready. Log: `%USERPROFILE%\Backups\logs\ctg-stack-audit-20260531-105531.txt`.

**Stack audit results (2026-05-31):**

| Check | Before | After | Notes |
|-------|--------|-------|-------|
| DDG VPN installed | Yes | Yes | Process `DuckDuckGo.VPN` running |
| DDG tunnel Up | No | No | Wi-Fi disconnected; DNS via VPN when connected |
| Adapter DDG DNS | N/A | N/A | Not on adapter IPv4 (VPN DNS path) |
| HVCI / VBS | — | Running | Memory integrity on |
| Email vault | — | Not initialized | `Ctg-CredentialVault.ps1 -InitVault` once |
| Wi-Fi | Disconnected | Disconnected | WlanSvc OK; `-ApplyFixes` needs Admin |

**CPU/GPU diagnose (Andy laptop, 2026-05-31):** Dell Precision 5530 · Intel i9-8950HK · Intel UHD 630 + NVIDIA Quadro P2000 · High performance plan active · GPU visual effects Best performance · script OC: **N**; Dell Power Manager + Graphics Settings per-app: manual.

---

## Tonight (Windows â€” Admin PowerShell)

Run each command in its **own** elevated window from the repo root:

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

**0. Encrypted credential vault (once per machine — interactive, no git)**

```powershell
pip install cryptography argon2-cffi
```

```powershell
.\scripts\windows\Ctg-CredentialVault.ps1 -InitVault -WithDpapiWrap
```

```powershell
.\scripts\windows\Ctg-CredentialVault.ps1 -UnlockVault
```

```powershell
.\scripts\windows\Ctg-CredentialVault.ps1 -AddCredential -Title 'Kali SSH' -Username sal
```

See [SECRET_VAULT.md](SECRET_VAULT.md). Never paste passwords into chat or SMS.

**0b. Legacy DPAPI secrets (optional — API keys / PII phone)**

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

Then commit and push split repos (all **private** — see portfolio table). Plan: [GITHUB_REPOS_PLAN.md](GITHUB_REPOS_PLAN.md).

**Privatize lab ops repos (once per machine with `gh auth`):**

```powershell
.\scripts\publish\Set-CtgPrivateRepos.ps1 -DiagnoseOnly
```

```powershell
.\scripts\publish\Set-CtgPrivateRepos.ps1 -Apply
```

Device-hardening subtree sync:

```powershell
.\scripts\publish\Sync-CtgDeviceHardeningRepo.ps1
```

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

Expected: **449 collected**, **445 passed**, **4 skipped** (firewall/bash + platform skips on Windows).

---

## New pages / links

- **Pro feeds hub:** [website/feeds.html](../website/feeds.html) â€” signatures, YARA, hashes API
- **Shop Pro tier:** [shop.html#pro-feed](https://hackerplanet.dev/shop.html#pro-feed)
- **Kickstarter:** [kickstarter.html](https://hackerplanet.dev/kickstarter.html) â€” config in `website/js/kickstarter.config.js`

---

## Portfolio index (GitHub + site)

| Project | GitHub | Visibility | Site page | Branch | Status |
|---------|--------|------------|-----------|--------|--------|
| **cyberThreatGotchi** (monorepo) | [salvador-Data/cyberThreatGotchi](https://github.com/salvador-Data/cyberThreatGotchi) | **Public** (Pages) | [hackerplanet.dev](https://hackerplanet.dev/) · [Pages mirror](https://salvador-Data.github.io/cyberThreatGotchi/) | `main` | Flagship — CI, Pages, releases |
| **ctg-kali-lab** | [salvador-Data/ctg-kali-lab](https://github.com/salvador-Data/ctg-kali-lab) | **Private** | [github.html](https://hackerplanet.dev/github.html) | `main` | Split — Kali scripts + docs |
| **ctg-windows-soc** | [salvador-Data/ctg-windows-soc](https://github.com/salvador-Data/ctg-windows-soc) | **Private** | [github.html](https://hackerplanet.dev/github.html) | `main` | Split — Windows SOC + Wireshark IDS |
| **ctg-device-hardening** | [salvador-Data/ctg-device-hardening](https://github.com/salvador-Data/ctg-device-hardening) | **Private** | [github.html](https://hackerplanet.dev/github.html) | `main` | Split — iPhone/RAM/CVE hardening docs |
| **Bjorn** | [salvador-Data/Bjorn](https://github.com/salvador-Data/Bjorn) | Public | [ecosystem.html](https://hackerplanet.dev/ecosystem.html) | `main` | Pi assessment fork |
| **Mr. CrackBot AI Nano** | [salvador-Data/Mr.-CrackBot-AI-Nano](https://github.com/salvador-Data/Mr.-CrackBot-AI-Nano) | Public | [crackbot.html](https://hackerplanet.dev/crackbot.html) | `main` | Jetson bench lab |
| **M5 OS Cardputer** | [salvador-Data/M5_OS-Cardputer](https://github.com/salvador-Data/M5_OS-Cardputer) | Public | [cardputer.html](https://hackerplanet.dev/cardputer.html) | `main` | Pocket launcher firmware |
| **BLE Bot Cardputer** | [salvador-Data/BLE-Bot-Cardputer](https://github.com/salvador-Data/BLE-Bot-Cardputer) | Public | [github.html](https://hackerplanet.dev/github.html) | `main` | BLE scout firmware |
| **Remote Possibility** | [salvador-Data/Remote-Possibility](https://github.com/salvador-Data/Remote-Possibility) | Public | [github.html](https://hackerplanet.dev/github.html) | `main` | IR remote (legacy CTG client archived) |

**Sync split repos after monorepo script changes:** `.\scripts\publish\Sync-CtgSplitRepos.ps1` then commit/push each split clone. Plan: [GITHUB_REPOS_PLAN.md](GITHUB_REPOS_PLAN.md).

---

## SSH note

NAT forward **2222 â†’ 22** is configured on VM `kali`. Credentials: DPAPI vault (`Protect-CtgSecrets.ps1`) or local `Backups\kali-vm-credentials.txt` (gitignored). If banner exchange fails, use TTY one-liner above â€” guest SSH may need `sudo apt install -y openssh-server && sudo systemctl enable --now ssh`.
