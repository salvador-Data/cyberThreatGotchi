# CTG audit compartments — design

CyberThreatGotchi audit autorun (`scripts/windows/CTG-AuditAutorun.ps1`) implements **compartmentalized, append-only** audit collection suitable for SOC review, compliance-style evidence, and cloud archival. Each run is immutable in practice: new folder per execution, no in-place edits to prior runs.

## Why compartments?

Proper audit design **separates evidence by domain** so analysts can:

- Scope access (network team sees `network-ids`, identity team sees `windows-security`)
- Retain different retention policies per compartment later (Wazuh index vs cold storage)
- Correlate across compartments via `manifest.json` without mixing raw sources

This mirrors NIST-style *collect → store → analyze* with explicit boundaries, not one monolithic log dump.

## Layout

```
%USERPROFILE%\Backups\audit\
  YYYY-MM-DD\
    run-HHmmss\
      manifest.json           # run metadata + optional hash chain
      usb-disks.json          # USB disk enumeration (when present)
      windows-security\       # host OS posture
      network-ids\              # IDS / packet heuristics
      soc-ctg\                  # CTG application exports
      kali-bridge\              # Kali lab sync placeholder
      cloud-sink-*.txt          # sink notes when -SinkCloud
```

When external SSD (`D:`) is online, the same run folder is **mirrored** to:

```
D:\Backups\audit\YYYY-MM-DD\run-HHmmss\
```

## Compartment reference

| Compartment | Purpose | Typical sources |
|-------------|---------|-----------------|
| `windows-security` | Firewall, Defender, sign-in events | `Get-MpComputerStatus`, Security log 4624/4625, `firewall.log` tail, hardening diagnose output |
| `network-ids` | Network detection artifacts | `wireshark-alerts.json`, `wireshark-ids.log`, Snort if present |
| `soc-ctg` | Application SOC exports | `GET /api/export/audit.json`, `GET /api/export/threats.json`, SOC run logs |
| `kali-bridge` | Off-host lab telemetry | `Backups\kali-bridge\` or SMB share when configured |

## Manifest and hash chain

`manifest.json` records:

- `run_id`, `timestamp`, `hostname`, `username`, `admin`
- `mode`: `audit-only` or `harden-and-audit`
- `ssd_online`, `ssd_detail`
- `compartments`, `errors`
- `prev_hash`: SHA-256 of the **previous** run’s manifest on the same calendar day (optional chain)
- `content_hash`: SHA-256 of manifest body after initial write

This supports tamper-evident **daily chains** without requiring a database. For HMAC-signed CTG exports, set `CTG_AUDIT_SECRET` on the CTG web API (see `docs/EXPORT.md`).

## Run modes

| Switch | Behavior |
|--------|----------|
| `-AuditOnly` | Collect compartments only (default) |
| `-HardenAndAudit` | Defensive hardening diagnose + firewall verify + DuckDuckGo VPN preserve, then audit |
| `-SinkCloud` | After collection, forward via Wazuh status note, `rclone` (`CTG_AUDIT_REMOTE`), or Filebeat template |
| `-SkipSsdBackup` | Do not invoke `selective_ssd_backup.ps1` |

## Nightly integration

`ctg_nightly_4am.ps1` invokes:

```powershell
.\scripts\windows\CTG-AuditAutorun.ps1 -AuditOnly -SinkCloud
```

Elevated hardening passes remain in `ctg_soc_run_once.ps1` — nightly audit is **non-destructive** by default.

## Operational log

All autorun messages append to:

```
%USERPROFILE%\Backups\logs\ctg-audit-autorun.log
```

## Related docs

- [AUDIT_CLOUD_SINK.md](AUDIT_CLOUD_SINK.md) — Wazuh, rclone, Elastic/OpenSearch
- [EXPORT.md](EXPORT.md) — CTG API audit export + `CTG_AUDIT_SECRET`
- [PORTFOLIO_AUTOMATION_SOC.md](PORTFOLIO_AUTOMATION_SOC.md) — nightly orchestration context
