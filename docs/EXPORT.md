# Threat export & reporting

CyberThreatGotchi logs every detected event to SQLite. Export for SOC tickets, compliance evidence, or executive summaries.

## CSV export

Download all recent threats as CSV (for Excel, Splunk HEC, Google Sheets):

```bash
curl -o ctg_threats.csv "http://127.0.0.1:8765/api/export/threats.csv?limit=500"
```

Columns: `id`, `timestamp`, `severity`, `category`, `source_ip`, `dest_ip`, `score`, `action_taken`, `description`

## JSON executive report

Single snapshot combining gotchi state, runtime, blocks, and aggregated stats:

```bash
curl -s http://127.0.0.1:8765/api/export/report.json | jq .
```

Example `statistics` block:

```json
{
  "by_severity": { "high": 12, "medium": 8, "critical": 3 },
  "top_sources": [{ "ip": "203.0.113.50", "count": 7 }],
  "total_blocked": 15,
  "total": 23
}
```

## Web dashboard

Open **http://127.0.0.1:8765/** and use:

- **Export CSV** — downloads `ctg_threats.csv`
- **Export Report** — downloads `ctg_report.json`

## CISO use (Hacker Planet LLC)

| Audience | Export | Talking point |
|----------|--------|----------------|
| Board | `report.json` | Trend in `statistics.by_severity` |
| SOC | `threats.csv` | Pivot on `source_ip`, feed IDS |
| Legal / IR | SQLite file `data/threats.db` | Chain of custody — copy before incident |
| MSP partner | Webhook + CSV | Real-time + batch reconciliation |

Full CISO playbook: [CISO_PLAYBOOK.md](CISO_PLAYBOOK.md).

## Retention

Logs live in `CTG_DATA_DIR/threats.db` (default `./data/threats.db`). Rotate or archive monthly for production deployments.

```bash
sqlite3 data/threats.db ".backup ctg_$(date +%Y%m).db"
```
