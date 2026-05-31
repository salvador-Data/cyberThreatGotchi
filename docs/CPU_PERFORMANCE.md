# CPU performance — safe Windows tuning (no script OC)

**Hacker Planet LLC · Philadelphia, PA · authorized lab use only**

Conservative CPU and power posture for the Windows SOC laptop. This stack **does not** change voltage, multiplier, or BIOS settings from scripts.

## Why not hash your Windows password in the script?

Embedding `$expectedHash = 'abc123…'` in a committed PowerShell file does **not** secure CPU optimization or scheduled tasks:

- The hash is **crackable offline** and lives in git history forever.
- Windows **cannot** use SHA-256 to run an elevated scheduled task — it needs **Interactive logon**, **UAC**, or a **DPAPI/plaintext credential** registered with Task Scheduler.
- CTG CPU scripts apply **powercfg** tweaks only; they do **not** need your login password.

**Andy-safe pattern:** register the task with **Interactive + Highest** (logged-on only, no password in XML), or run once via **UAC** with `Run-AsAdmin.ps1`. Lab SSH passwords belong in the DPAPI vault (`Protect-CtgSecrets.ps1 -SetSecret`), never as hashes in repo scripts. See [SECRET_VAULT.md](SECRET_VAULT.md).

## Quick start

Diagnose (default — no changes):

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
.\scripts\windows\Optimize-CpuPerformance.ps1
```

Apply safe Windows-level tweaks (Administrator):

```powershell
.\scripts\windows\Run-AsAdmin.ps1 -TargetScript .\scripts\windows\Optimize-CpuPerformance.ps1 -TargetArguments '-ApplySafe'
```

Log: `C:\Users\Owner\Backups\logs\optimize-cpu.log` — **no secrets in git**.

## What `-ApplySafe` does

On **AC power** (when plugged in):

- Activates **High performance** or **Ultimate Performance** power plan
- Sets processor minimum/maximum state to **100%** on AC for the performance plan
- Enables **aggressive** turbo boost mode when supported
- Reduces core parking on AC for the performance plan

With **BalancedOnBattery** (default ON):

- Battery stays on **Balanced** — no aggressive drain on battery

## What is NOT scripted

| Action | Status |
|--------|--------|
| Voltage / frequency OC | **Rejected** — `-ApplyUnsafe` exits 2 with manual guidance only |
| Intel XTU / AMD Ryzen Master automation | **Not implemented** — manual tuning with thermal monitoring |
| BIOS changes | **Manual only** |

Use `-ApplyUnsafe` to print BIOS/vendor-tool guidance; it will **not** apply changes.

## Scheduled task (optional)

Register weekly safe optimization (Sunday 03:30 local, **Interactive + Highest** — logged-on only):

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
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

**No password in repo or task registration script** — `Register-CtgCpuOptimizeTask.ps1` does not call `Protect-CtgSecrets` or embed hashes. For a one-off elevated run without a stored password, use `Run-AsAdmin.ps1` (UAC prompt).

## Audit autorun integration

`CTG-AuditAutorun.ps1 -CpuOptimize` runs diagnose-only when not elevated, or `-ApplySafe` when Admin. Output: `Backups\audit\...\windows-security\cpu-optimize.txt`.

## OC possible? (manual)

The diagnose output reports:

- CPU model, cores, current vs max clock
- Laptop vs desktop heuristic (battery / chassis)
- Intel XTU / AMD Ryzen Master detection
- Active power plan and boost settings
- Thermal hints (WMI when available)

**Laptops:** BIOS voltage/frequency OC is usually locked or unsafe — prefer `-ApplySafe` only.

**Desktops:** BIOS OC may be possible; still **not scripted** here. Use vendor tools with stress tests and thermal limits.

## Revert

Switch back to Balanced:

```powershell
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
```

## Related

- [SECRET_VAULT.md](SECRET_VAULT.md) — DPAPI vault; why not hash passwords in committed scripts
- [CTG_NEXT_STEPS.md](CTG_NEXT_STEPS.md) — nightly checklist
- [SCRIPTS_CATALOG.md](SCRIPTS_CATALOG.md) — full script index
