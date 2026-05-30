# Windows SOC — Administrator steps (CyberThreatGotchi)

You are not in an elevated session when **Running as Admin: False** appears. Disk mount, restore points, Sysmon, and full hardening need **Administrator**.

## Open Administrator PowerShell

**Option A — Win+X**

1. Press **Win+X**
2. Choose **Terminal (Admin)** or **Windows PowerShell (Admin)**
3. Click **Yes** on the UAC prompt

**Option B — Start menu**

1. Search **PowerShell**
2. **Run as administrator**
3. Click **Yes** on UAC

Confirm the window title includes **Administrator**. At the prompt you can run:

```powershell
([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
```

That should print **True**.

## Without UAC from Explorer (optional)

Double-click:

`C:\Users\Owner\Projects\cyberThreatGotchi\scripts\windows\Elevate-CTG-SOC.bat`

Or from a normal PowerShell window:

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi\scripts\windows
```

```powershell
.\Run-AsAdmin.ps1
```

That triggers UAC and runs the elevated SOC one-shot.

## Two commands to run **after** Admin PowerShell is open

**1 — Mount SDK SSD as D: (no format)**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Owner\Projects\cyberThreatGotchi\scripts\windows\mount_ssd_d.ps1"
```

Expect **Running as Admin: True** and a probe file under `D:\Backups\`.

**2 — Full elevated SOC pass (restore point, SSD backup to D:, Sysmon, hardening audit)**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Owner\Projects\cyberThreatGotchi\scripts\windows\ctg_soc_run_once.ps1"
```

Log: Desktop `ctg-soc-run-log.txt` and copy to `D:\Backups\` when D: is writable.

## Keep DuckDuckGo VPN (do not replace)

Your PC uses **DuckDuckGo VPN** (WireGuard). CTG SOC scripts are written to **preserve** it:

| Safe (keeps DDG VPN) | Avoid (can break or replace VPN) |
|----------------------|----------------------------------|
| `ctg_soc_run_once.ps1` (Sysmon + **audit-only** hardening) | Installing Cloudflare 1.1.1.1 / NextDNS / second VPN app |
| `Preserve-DuckDuckGoVpn.ps1` (Defender exclusions for DDG) | `harden_windows.ps1` **full apply** without `-HardenWindowsSecurityAuditOnly` until you review |
| Cardputer USB flash (`M5_OS-Cardputer`) | Removing DuckDuckGo VPN profile in Windows Settings |

Before/after SOC, confirm VPN in the **DuckDuckGo** app (Connected) or tray icon. Manual preserve step:

```powershell
. "C:\Users\Owner\Projects\cyberThreatGotchi\scripts\windows\Preserve-DuckDuckGoVpn.ps1"
Invoke-CtgPreserveDuckDuckGoVpn
```

## Windows 11 Sign-in options (Password greyed out / Change broken)

Symptom: **Settings → Accounts → Sign-in options** — Password option inactive, or PIN works but password path fails.

**Read-only diagnostic (no Admin):**

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\Repair-WindowsSignIn.ps1 -OpenSettings
```

**Safe fixes (Admin — restarts Credential Manager / Web Account Manager; never sets your password):**

```powershell
.\scripts\windows\Repair-WindowsSignIn.ps1 -ApplySafeFixes -OpenSettings
```

If PIN is corrupted but password UI still fails, Admin may add `-ResetNgcPinCache` (you must set PIN again afterward).

| Account type | Fix password manually |
|--------------|----------------------|
| **Microsoft account** | [account.microsoft.com/security](https://account.microsoft.com/security) → Password; or Sign-in options → **I forgot my PIN** |
| **Local account** | `Ctrl+Alt+Del` → Change a password; or Admin: `net user YOURUSERNAME *` (you type new password at prompts) |
| **Azure AD / work** | Company portal or IT — CTG scripts cannot override org policy |

**Did CTG hardening break sign-in?** `ctg_soc_run_once.ps1` uses **audit-only** Harden-Windows-Security. Full `Invoke-Hardening` enforce (without `-HardenWindowsSecurityAuditOnly`) can set **DevicePasswordLess** / Hello-only policies. Revert in **Settings → Sign-in options** (turn off “only allow Windows Hello”) or Group Policy → Windows Hello for Business.

Log: `%USERPROFILE%\Backups\logs\repair-windows-signin.log`

## What works **without** Admin

- `selective_ssd_backup.ps1` (falls back when D: is missing — often `C:\Users\Owner\Backups\...`)
- `cloud_backup.ps1` (OneDrive staging)
- `Repair-WindowsSignIn.ps1` (diagnostic / `-OpenSettings` only)
- `git status` / read-only checks
- Cardputer flash: PlatformIO upload to COM13 (no elevation)

## Cardputer flash (normal user PowerShell)

```powershell
cd C:\Users\Owner\Projects\M5_OS-Cardputer
```

```powershell
& "$env:USERPROFILE\.platformio\penv\Scripts\pio.exe" run -t upload --upload-port COM13
```

`pio` alone may not be on PATH; use the full path above if needed.
