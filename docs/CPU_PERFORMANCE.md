# CPU performance — safe Windows tweaks (no secrets in git)

**Hacker Planet LLC / CyberThreatGotchi** — authorized use on **Andy-owned** Windows SOC laptop only.

**Scripts:** `Optimize-CpuPerformance.ps1`, `Register-CtgCpuOptimizeTask.ps1`, `Run-AsAdmin.ps1`

**Related:** [SECRET_VAULT.md](SECRET_VAULT.md) — DPAPI vault; never embed passwords or hashes in repo scripts.

---

## Laptop vs desktop (Andy hardware)

| Factor | Andy (DESKTOP-G88VH3D) | Desktop |
|--------|------------------------|---------|
| CPU | Intel Core i9-8950HK (6C/12T, 2.9 GHz base) | Varies |
| Form factor | **Laptop** (PCSystemType=2, battery present) | Often OC-capable in BIOS |
| Real OC | **Not via script** — BIOS/XTU only if unlocked | BIOS may allow multiplier |
| Safe script scope | Windows **powercfg** only | Same |

Diagnose on this machine reports: likely laptop/mobile, no Intel XTU or Ryzen Master installed, High performance plan often already active.

---

## Why not hash your Windows password in the script?

Embedding `$expectedHash = 'abc123…'` in a committed PowerShell file does **not** secure CPU optimization or scheduled tasks:

- The hash is **crackable offline** and becomes part of git history forever.
- Windows **cannot** use a SHA-256 hash to run an elevated scheduled task — it needs **Interactive logon**, **UAC**, or a **DPAPI/plaintext credential** registered with the Task Scheduler.
- CTG CPU scripts apply **powercfg** tweaks only; they do not need your login password at all.

**Andy-safe pattern:** register the weekly task with **Interactive + Highest** (logged-on only, no password in XML), or run once via **UAC** with `Run-AsAdmin.ps1`.

---

## One-time: register weekly safe optimize (Administrator)

One command per step:

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\Register-CtgCpuOptimizeTask.ps1
```

Default: **Sunday 03:30**, runs `Optimize-CpuPerformance.ps1 -ApplySafe` when you are logged on. No password stored in script or git.

At logon instead of weekly:

```powershell
.\scripts\windows\Register-CtgCpuOptimizeTask.ps1 -Schedule AtLogon
```

Remove the task:

```powershell
.\scripts\windows\Register-CtgCpuOptimizeTask.ps1 -Unregister
```

---

## Manual run (UAC — no vault password)

Diagnose only:

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\Optimize-CpuPerformance.ps1 -DiagnoseOnly
```

Apply safe tweaks (prompts UAC if not already Administrator):

```powershell
.\scripts\windows\Run-AsAdmin.ps1 -TargetScript .\scripts\windows\Optimize-CpuPerformance.ps1 -TargetArguments '-ApplySafe'
```

Log file (no secrets): `%USERPROFILE%\Backups\logs\optimize-cpu.log`

---

## What `-ApplySafe` does

- Activates **High performance** or **Ultimate Performance** on AC when available
- Processor min/max 100% on AC for the performance plan
- Aggressive boost where supported; optional **Balanced on battery** (default ON)
- Does **not** implement `-ApplyUnsafe` (voltage/frequency OC) — BIOS / Intel XTU / AMD Ryzen Master only

---

## Secrets and this workflow

| Question | Answer |
|----------|--------|
| Does CPU optimize need a vault secret? | **No** |
| Should I put a password hash in `Register-CtgCpuOptimizeTask.ps1`? | **No** — use Interactive principal |
| Where do lab SSH passwords go? | `Protect-CtgSecrets.ps1 -SetSecret` → `.vault/` (see [SECRET_VAULT.md](SECRET_VAULT.md)) |
| Optional "did I type it right?" check | `-SetSecretHash` / `-TestSecretHash` in vault only — not in committed scripts |

---

## Policy alignment

- **NIST CSF PR.AC-1** — credentials not embedded in code.
- **CIS Control 3** — secure configuration; power settings are reversible via `powercfg`.
- Monitor thermals after `-ApplySafe`; revert to Balanced if the laptop runs hot.

Revert to Balanced:

```powershell
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
```

## Audit integration

```powershell
.\scripts\windows\CTG-AuditAutorun.ps1 -HardenAndAudit -CpuOptimize
```

Output: `Backups\audit\...\windows-security\cpu-optimize.txt`.
