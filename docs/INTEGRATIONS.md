# Integrations

CyberThreatGotchi can push threat events to external tools and expose live state over HTTP.

## Web dashboard (pull)

Any device on the LAN can poll the gotchi:

```bash
curl -s http://192.168.1.50:8765/api/status | jq .
curl -N http://192.168.1.50:8765/api/stream
```

See **[WEB.md](WEB.md)** for the full API.

## Webhooks (push)

Set environment variables before starting CTG:

| Variable | Description |
|----------|-------------|
| `CTG_WEBHOOK_URL` | POST target (required to enable) |
| `CTG_WEBHOOK_SECRET` | Optional shared secret → `X-CTG-Secret` header |

```powershell
$env:CTG_WEBHOOK_URL = "http://192.168.1.10:9090/ctg"
python main.py --simulation --web
```

### Payload shape

Each detected threat triggers one JSON POST:

```json
{
  "event": "threat",
  "source": "cyberthreatgotchi",
  "timestamp": "2026-05-28T01:23:45Z",
  "threat": {
    "severity": "high",
    "source_ip": "10.0.0.99",
    "category": "signature",
    "action_taken": "blocked",
    "description": "SQL Injection Probe",
    "score": 6,
    "dest_ip": "10.0.0.1"
  },
  "gotchi": {
    "name": "Cipherhorn",
    "mood": "alert",
    "level": 3,
    "threats_blocked": 12,
    "threats_seen": 15
  }
}
```

Delivery is asynchronous — the sniffer thread is never blocked on network I/O.

### Local test receiver

Terminal A:

```powershell
python scripts\webhook_receiver.py --port 9090
```

Terminal B:

```powershell
$env:CTG_WEBHOOK_URL = "http://127.0.0.1:9090/ctg"
python main.py --simulation
```

## Bjorn (Raspberry Pi)

[Bjorn](https://github.com/salvador-Data/Bjorn) and CyberThreatGotchi are **separate devices** today:

| Device | Role |
|--------|------|
| BPI-R3 Mini | CTG edge IPS + pet |
| Raspberry Pi | Bjorn assessment |

**Option A — webhook to a log script on Bjorn**

On the Pi, run a small listener (or use the test receiver above) and append events:

```bash
# Example: forward CTG threats into Bjorn's log tree (custom script)
CTG_WEBHOOK_URL=http://<bjorn-pi-ip>:9090/ctg
```

**Option B — poll CTG from Bjorn**

If CTG web UI is reachable from the Pi:

```bash
curl -s http://<ctg-ip>:8765/api/status | jq '.gotchi.mood, .threats[0]'
```

Future work: a Bjorn `actions/` module that ingests CTG webhooks into the e-Paper status line.

## M5Stack Cardputer

The Cardputer can show CTG mood as a **remote status tile** by polling `/api/status` over Wi-Fi (no CTG firmware change required).

1. Join the same LAN as the BPI-R3 Mini running CTG.
2. Poll `http://<ctg-ip>:8765/api/status` every few seconds.
3. Render `gotchi.mood`, `gotchi.level`, and the latest `threats[0]` on the LCD.

Example fields:

| JSON path | Use |
|-----------|-----|
| `gotchi.mood` | Sprite / icon selection |
| `gotchi.status_line` | One-line caption |
| `threats[0].source_ip` | Last attacker |
| `runtime.mode` | `LIVE` vs `SIMULATION` |

M5 OS firmware remote-status screen: **`scripts/cardputer/ctg_status.py`** + [CARDPUTER.md](CARDPUTER.md).

## Defensive use

Webhooks may contain attacker IPs and payload snippets. Restrict receivers to your lab VLAN and protect `CTG_WEBHOOK_SECRET` like any API key.
