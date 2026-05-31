# CTG audit cloud sink

Audit runs under `Backups\audit\` can be replicated to **open-source, self-hosted** SIEM or object storage. All configuration uses **environment variables only** — never commit secrets, rclone configs, or Elastic credentials to this repository.

Orchestrator: `scripts/windows/CTG-AuditAutorun.ps1 -SinkCloud`

## Option A — Wazuh (recommended live telemetry)

Wazuh agent provides **continuous** ingestion (Sysmon, FIM, ossec rules). The audit autorun **documents** agent status when `-SinkCloud` is set; live events flow to your manager independently of compartment folders.

| Variable | Purpose |
|----------|---------|
| `CTG_WAZUH_MANAGER` | Manager IP or hostname (preferred) |
| `WAZUH_MANAGER` | Alias accepted by `harden_windows.ps1` / agent setup |

Setup:

```powershell
$env:CTG_WAZUH_MANAGER = '192.168.1.50'
.\scripts\windows\harden_windows.ps1 -SetupWazuhAgent
```

Confirm agent **Active** in Wazuh dashboard. Correlate with `network-ids\wireshark-alerts.json` copied into compartment runs.

Docs: [Wazuh quickstart](https://documentation.wazuh.com/current/quickstart.html), `scripts/windows/wazuh_agent_setup.ps1`

## Option B — rclone (Nextcloud WebDAV, S3/MinIO, B2)

Use rclone for **batch upload** of each append-only run folder. Configure remotes locally (`rclone config`) — **do not** commit `rclone.conf`.

| Variable | Example | Purpose |
|----------|---------|---------|
| `CTG_AUDIT_REMOTE` | `nextcloud:CTG-Audit` | rclone destination (remote:path) |

Examples (after `rclone config`):

```powershell
# Nextcloud WebDAV
$env:CTG_AUDIT_REMOTE = 'nextcloud:Backups/CTG-Audit'

# MinIO / S3-compatible
$env:CTG_AUDIT_REMOTE = 'minio:ctg-audit'

# Backblaze B2
$env:CTG_AUDIT_REMOTE = 'b2:hp-llc-ctg-audit'
```

Manual test:

```powershell
.\scripts\windows\CTG-AuditAutorun.ps1 -AuditOnly -SinkCloud
```

The script runs:

```
rclone copy %RunRoot% %CTG_AUDIT_REMOTE% --create-empty-src-dirs
```

## Option C — Filebeat → Elastic / OpenSearch

Template: `config/filebeat/filebeat-audit.yml.example`

| Variable | Purpose |
|----------|---------|
| `CTG_ELASTIC_HOST` | Elasticsearch/OpenSearch host:port (e.g. `192.168.1.60:9200`) |
| `CTG_ELASTIC_USER` | Optional basic auth user (set in Filebeat keystore, not git) |
| `CTG_ELASTIC_PASSWORD` | Optional password (keystore only) |

Steps:

1. Install [Filebeat](https://www.elastic.co/downloads/beats/filebeat) or OpenSearch Data Prepper equivalent.
2. Copy template to `C:\ProgramData\CTG\filebeat\filebeat.yml`.
3. Set `CTG_ELASTIC_HOST` in machine or user environment.
4. Point inputs at `Backups\audit\*\run-*\` JSON paths (already in template).
5. Start Filebeat service.

For **OpenSearch**, replace `output.elasticsearch` with `output.opensearch` per vendor docs.

## Option D — OneDrive (existing nightly path)

`cloud_backup.ps1` stages **backup manifests** to OneDrive — not full audit compartments. Audit runs remain local (+ SSD mirror) unless rclone or Filebeat is configured. OneDrive can still hold `Backups\logs\ctg-audit-autorun.log` via nightly log mirror.

## CTG API signing (application audit chain)

Separate from compartment storage:

| Variable | Purpose |
|----------|---------|
| `CTG_AUDIT_SECRET` | HMAC on `/api/export/audit.json` |
| `CTG_WEB_PORT` | CTG dashboard port (default `8765`) |

## Security notes

- Never log `CTG_AUDIT_REMOTE` credentials, rclone tokens, or Elastic passwords.
- Use `CTG_WEBHOOK_URL` + `CTG_WEBHOOK_SECRET` only for optional backup-complete notifications (`cloud_backup.ps1`).
- Compartment runs exclude payment payloads and API keys by design.

## Quick reference

| Goal | Mechanism | Env vars |
|------|-----------|----------|
| Live SIEM | Wazuh agent | `CTG_WAZUH_MANAGER` |
| Cold archive / Nextcloud | rclone | `CTG_AUDIT_REMOTE` |
| Searchable JSON | Filebeat | `CTG_ELASTIC_HOST` |
| Signed app export | CTG API | `CTG_AUDIT_SECRET` |

See also [AUDIT_COMPARTMENTS.md](AUDIT_COMPARTMENTS.md), [SECURITY_HARDENING.md](SECURITY_HARDENING.md).
