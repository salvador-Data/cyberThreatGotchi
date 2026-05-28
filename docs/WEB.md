# Web dashboard

CyberThreatGotchi serves a lightweight Flask UI when started with `--web`.

## Start

```powershell
python assets\sprites\generate_sprites.py
python main.py --simulation --web
```

Default URL: **http://127.0.0.1:8765/**

On the BPI-R3 Mini installer, the service binds `0.0.0.0:8765` so you can open it from another machine on the LAN.

## UI

| Area | Description |
|------|-------------|
| Sprite panel | Live Cipherhorn PNG by mood |
| Stats | Level, XP, hunger, happiness, threats seen/blocked |
| Threat feed | Recent events from the state bus |
| **Feed** / **Pet** | Tamagotchi care actions |

## HTTP API

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/` | Dashboard HTML |
| `GET` | `/api/health` | Liveness probe `{ "ok": true }` |
| `GET` | `/api/status` | JSON snapshot (mood, stats, recent threats) |
| `GET` | `/api/export/threats.csv` | Download threat log CSV |
| `GET` | `/api/export/report.json` | Executive JSON report + stats |
| `GET` | `/api/export/audit.json` | Tamper-evident hash chain export |
| `GET` | `/api/pro/feed/signatures` | Pro tier — signature pack (`X-CTG-Pro-Key`) |
| `GET` | `/api/pro/feed/yara` | Pro tier — YARA rules bundle |
| `GET` | `/api/pro/feed/hashes` | Pro tier — SHA256 deny list |
| `GET` | `/api/threats?limit=50` | SQLite threat history (JSON) |
| `GET` | `/api/sprite/<mood>.png?frame=0` | PNG sprite (animated frames 0/1) |
| `POST` | `/api/feed` | Feed Cipherhorn |
| `POST` | `/api/pet` | Pet Cipherhorn |
| `GET` | `/api/stream` | Server-Sent Events — one JSON snapshot per second |

### Example: status

```bash
curl -s http://127.0.0.1:8765/api/status | jq .
```

### Example: SSE stream

```bash
curl -N http://127.0.0.1:8765/api/stream
```

## CLI + web together

```powershell
python main.py --simulation --web --cli
```

Rich terminal dashboard and browser UI run concurrently; both read the same gotchi state.

## Pro threat feed (Stripe-ready)

Subscription customers poll signed rule packs from the same web server:

```bash
curl -s -H "X-CTG-Pro-Key: demo" http://127.0.0.1:8765/api/pro/feed/signatures | jq .
curl -s -H "X-CTG-Pro-Key: demo" http://127.0.0.1:8765/api/pro/feed/yara | jq .
```

Production: set `CTG_PRO_API_KEY` to a strong secret; Stripe webhook → provision keys per customer.

| Variable | Purpose |
|----------|---------|
| `CTG_PRO_API_KEY` | Required header value (omit = demo key `demo` only) |
| `CTG_AUDIT_SECRET` | HMAC on `/api/export/audit.json` |
