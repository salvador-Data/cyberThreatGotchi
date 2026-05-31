# Shell performance (Windows PowerShell / CTG)

Quick wins for **Hacker Planet LLC** CTG workflows on Andy's Windows SOC laptop. Defensive lab only — does not disable Defender, HVCI/VBS, or DuckDuckGo VPN/DNS.

## Diagnose

```powershell
cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
```

```powershell
.\scripts\windows\Optimize-CtgShellPerformance.ps1
```

Report: `%USERPROFILE%\Backups\logs\ctg-shell-perf-*.txt`

## Apply safe profile snippet (optional)

Adds `ctg` cd helper and silences progress bars in interactive sessions.

```powershell
.\scripts\windows\Optimize-CtgShellPerformance.ps1 -ApplySafe
```

Snippet file: `scripts\windows\profile.d\ctg-shell-fast.ps1`

## Use PowerShell 7 as default terminal

- **pwsh 7** is faster for CTG scripts and matches CI-style `-Parallel` where used.
- Windows Terminal → Settings → set **PowerShell** (7.x) as default profile.
- This repo does not change system defaults for you.

## Orchestrator entry (fastest full diagnose)

```powershell
.\scripts\windows\Invoke-CtgOneWorking.ps1 -DiagnoseOnly
```

Skips redundant Wi-Fi diagnose, memory re-run, and Kali re-stage when already covered.

## Install audit only

```powershell
.\scripts\windows\Invoke-CtgInstallAudit.ps1 -Json
```

## Notes

| Topic | Guidance |
|-------|----------|
| Profile | `$PROFILE` load time shown in diagnose; keep profile minimal |
| Transcription | GPO transcription can slow shells — review policy, do not disable security |
| Defender | Real-time scan on `scripts\windows` may add cold-start ms — expected |
| Heavy modules | Avoid `Import-Module Az`, Graph, etc. in CTG orchestrators |

See also: [CTG_NEXT_STEPS.md](CTG_NEXT_STEPS.md), [SCRIPTS_CATALOG.md](SCRIPTS_CATALOG.md)
