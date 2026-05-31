# CPU & GPU performance — safe Windows tuning (no script OC)

**Hacker Planet LLC · Philadelphia, PA · authorized lab use only**

Conservative CPU, GPU, and power posture for the Windows SOC laptop. This stack **does not** change voltage, multiplier, BIOS settings, or Spectre/RETBleed mitigations from scripts.

## Andy laptop snapshot (2026-05-31)

| Item | Detected |
|------|----------|
| Model | **Dell Precision 5530** |
| CPU | **Intel Core i9-8950HK** (6C/12T @ 2.90 GHz base) |
| iGPU | **Intel UHD Graphics 630** |
| dGPU | **NVIDIA Quadro P2000** (driver 556.12 via nvidia-smi) |
| Form factor | Laptop (battery present) — script OC **not** recommended |

### Applied this session (automated)

| Action | Result |
|--------|--------|
| CPU `-DiagnoseOnly` | OK — High performance plan already active |
| CPU `-ApplySafe` | **Needs Admin UAC** — re-run via `Run-AsAdmin.ps1` (tunes boost, min/max 100% AC, core parking) |
| GPU visual effects | **Applied** — HKCU `VisualFXSetting=2` (Best performance) |
| NVIDIA `-pm 1` | **Skipped** — requires Admin; mobile Quadro often reports persistence mode `[N/A]` |
| Scheduled task | **Not registered** — run `Register-CtgCpuOptimizeTask.ps1` elevated |

### Manual (Dell / GPU / thermals)

- **Dell Power Manager** — install from Dell support; set **Ultra Performance** on AC when thermals allow (not scripted — user consent).
- **Windows Graphics Settings** — Settings → System → Display → Graphics → add VirtualBox, Cursor, Chrome → **High performance** (Quadro P2000).
- **Intel XTU / ThrottleStop undervolt** — optional manual only if BIOS allows; monitor thermals; not scripted.
- **Revert CPU plan** — `powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e` (Balanced).

## Why not hash your Windows password in the script?

Embedding `$expectedHash = 'abc123â€¦'` in a committed PowerShell file does **not** secure CPU optimization or scheduled tasks:

- The hash is **crackable offline** and lives in git history forever.
- Windows **cannot** use SHA-256 to run an elevated scheduled task â€” it needs **Interactive logon**, **UAC**, or a **DPAPI/plaintext credential** registered with Task Scheduler.
- CTG CPU scripts apply **powercfg** tweaks only; they do **not** need your login password.

**Andy-safe pattern:** register the task with **Interactive + Highest** (logged-on only, no password in XML), or run once via **UAC** with `Run-AsAdmin.ps1`. Lab SSH passwords belong in the DPAPI vault (`Protect-CtgSecrets.ps1 -SetSecret`), never as hashes in repo scripts. See [SECRET_VAULT.md](SECRET_VAULT.md).

## Quick start

Diagnose (default â€” no changes):

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
.\scripts\windows\Optimize-CpuPerformance.ps1
```

Apply safe Windows-level tweaks (Administrator):

```powershell
.\scripts\windows\Run-AsAdmin.ps1 -TargetScript .\scripts\windows\Optimize-CpuPerformance.ps1 -TargetArguments '-ApplySafe'
```

Log: `C:\Users\Owner\Backups\logs\optimize-cpu.log` — **no secrets in git**.

GPU diagnose / apply:

```powershell
.\scripts\windows\Optimize-GpuPerformance.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Run-AsAdmin.ps1 -TargetScript .\scripts\windows\Optimize-GpuPerformance.ps1 -TargetArguments '-ApplySafe'
```

Log: `C:\Users\Owner\Backups\logs\optimize-gpu.log`

## What `-ApplySafe` does (CPU)

On **AC power** (when plugged in):

- Activates **High performance** or **Ultimate Performance** power plan
- Sets processor minimum/maximum state to **100%** on AC for the performance plan
- Enables **aggressive** turbo boost mode when supported
- Reduces core parking on AC for the performance plan

With **BalancedOnBattery** (default ON):

- Battery stays on **Balanced** â€” no aggressive drain on battery

## What is NOT scripted

| Action | Status |
|--------|--------|
| Voltage / frequency OC | **Rejected** â€” `-ApplyUnsafe` exits 2 with manual guidance only |
| Intel XTU / AMD Ryzen Master automation | **Not implemented** â€” manual tuning with thermal monitoring |
| BIOS changes | **Manual only** |

Use `-ApplyUnsafe` to print BIOS/vendor-tool guidance; it will **not** apply changes.

## What `-ApplySafe` does (GPU)

When a discrete GPU is present:

- **NVIDIA:** `nvidia-smi -pm 1` (persistence mode) when elevated and supported — no clock/voltage offsets
- **Visual effects:** HKCU Best performance preset (disable animations/shadows) unless `-SkipVisualEffects`
- **Intel-only systems:** discrete GPU actions skipped; per-app GPU preference remains manual

Does **not** change power-limit offsets, enable aggressive OC, or disable Hyper-V/VirtualBox GPU passthrough policies.

## Scheduled task (optional)

Register weekly safe optimization (Sunday 03:30 local, **Interactive + Highest** â€” logged-on only):

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\Register-CtgCpuOptimizeTask.ps1
```

At logon instead:

```powershell
.\scripts\windows\Register-CtgCpuOptimizeTask.ps1 -Schedule AtLogon
```

Unregister:

```powershell
.\scripts\windows\Register-CtgCpuOptimizeTask.ps1 -Unregister
```

**No password in repo or task registration script** â€” `Register-CtgCpuOptimizeTask.ps1` does not call `Protect-CtgSecrets` or embed hashes. For a one-off elevated run without a stored password, use `Run-AsAdmin.ps1` (UAC prompt).

## Audit autorun integration

`CTG-AuditAutorun.ps1 -CpuOptimize` runs diagnose-only when not elevated, or `-ApplySafe` when Admin. Output: `Backups\audit\...\windows-security\cpu-optimize.txt`.

## OC possible? (manual)

The diagnose output reports:

- CPU model, cores, current vs max clock
- Laptop vs desktop heuristic (battery / chassis)
- Intel XTU / AMD Ryzen Master detection
- Active power plan and boost settings
- Thermal hints (WMI when available)

**Laptops:** BIOS voltage/frequency OC is usually locked or unsafe â€” prefer `-ApplySafe` only.

**Desktops:** BIOS OC may be possible; still **not scripted** here. Use vendor tools with stress tests and thermal limits.

## Revert

Switch back to Balanced:

```powershell
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
```

## Related

- [SECRET_VAULT.md](SECRET_VAULT.md) â€” DPAPI vault; why not hash passwords in committed scripts
- [CTG_NEXT_STEPS.md](CTG_NEXT_STEPS.md) â€” nightly checklist
- [SCRIPTS_CATALOG.md](SCRIPTS_CATALOG.md) â€” full script index
