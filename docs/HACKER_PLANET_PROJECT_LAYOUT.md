# Hacker Planet LLC — project layout (Windows SOC)

Authorized lab use · Hacker Planet LLC · Andy Kowal


> **Naming:** Andy sometimes says *Hackers Planet LLC* (with an **s**). On disk the folder is **`Hacker Planet LLC`** (no **s**), under profile **`Programs`**, not `C:\Program Files`.
## Canonical dev root

| Role | Path |
|------|------|
| **Canonical (2026-05-31+)** | `C:\Users\Owner\Programs\Hacker Planet LLC\` |
| **Legacy (pre-move)** | `C:\Users\Owner\Projects\` — stubs only; do not develop here |

Do **not** put git repos under `C:\Program Files` (admin locks, broken tooling).

## One `cd` forever

```powershell
cd "$env:USERPROFILE\Programs\Hacker Planet LLC\cyberThreatGotchi"
```

Scripts resolve paths via `scripts/windows/CTG-Paths.ps1` (`Get-CtgRepoRoot`, `Get-CtgProgramsRoot`).

## Project folders (inventory)

| Repo | Path under Programs |
|------|---------------------|
| cyberThreatGotchi | `cyberThreatGotchi` |
| ctg-kali-lab | `ctg-kali-lab` |
| ctg-windows-soc | `ctg-windows-soc` |
| ctg-device-hardening | `ctg-device-hardening` |
| M5_OS-Cardputer | `M5_OS-Cardputer` |
| BLE-Bot-Cardputer | `BLE-Bot-Cardputer` |
| Bjorn | `Bjorn` |
| Mr.-CrackBot-AI-Nano | `Mr.-CrackBot-AI-Nano` (move from Projects if still legacy) |
| Mr-CrackBot-AI | `Mr-CrackBot-AI` |
| Mr.-CrackBot-AI-CYD | `Mr.-CrackBot-AI-CYD` |
| Remote-Possibility | `Remote-Possibility` |
| M5-Cardputer-refs | `M5-Cardputer-refs` |

## Automation scripts

| Script | Purpose |
|--------|---------|
| `scripts/windows/CTG-Paths.ps1` | `Get-CtgRepoRoot`, `Get-CtgProgramsRoot`, `Get-CtgSiblingRepo` |
| `scripts/windows/Move-HackerPlanetProjects.ps1` | DiagnoseOnly move plan; `-ApplyMove`; `-UpdatePaths`; `-ApplyDiskCleanup` |
| `scripts/publish/Sync-CtgSplitRepos.ps1` | Monorepo → ctg-kali-lab + ctg-windows-soc |
| `scripts/publish/Sync-CtgDeviceHardeningRepo.ps1` | Monorepo → ctg-device-hardening |
| `scripts/windows/Find-CtgDuplicateFiles.ps1` | SHA256 duplicate report; `-ApplyDedupe` |

Logs: `C:\Users\Owner\Backups\logs\hacker-planet-move.log`, `hacker-planet-move-plan.json`, `ctg-duplicate-report.json`

## After path migration

1. Re-open Cursor: `C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi`
2. Re-register nightly task (Admin): `.\scripts\windows\Register-CtgNightlyTask.ps1`
3. Split repos: run sync scripts, commit + push each clone separately

## Path references (operational)

Priority PowerShell files use `Get-CtgRepoRoot` (dot-source `CTG-Paths.ps1`):

- `ctg_nightly_4am.ps1`, `cloud_backup.ps1`, `selective_ssd_backup.ps1`
- `ctg_soc_run_once.ps1`, `ctg_website_nightly.ps1`, `CTG-AuditAutorun.ps1`

Scheduled tasks use `$PSScriptRoot` when registered from the repo; **re-register** after move.

## Dedupe policy

- **DiagnoseOnly first** — review `ctg-duplicate-report.json`
- Exclude: `.git`, `node_modules`, `.venv`, `__pycache__`, `.vault`, VirtualBox VMs
- **ApplyDedupe** only removes extra copies under `Backups` and `Downloads` (same hash)
