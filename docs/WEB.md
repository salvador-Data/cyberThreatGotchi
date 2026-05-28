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
| `GET` | `/api/status` | JSON snapshot (mood, stats, recent threats) |
| `GET` | `/api/sprite/<mood>.png` | PNG sprite (`idle`, `happy`, `alert`, …) |
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
