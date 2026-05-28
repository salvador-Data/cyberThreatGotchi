# Cardputer + CyberThreatGotchi integration

Show **Cipherhorn mood** and the latest threat on your M5Stack Cardputer by polling the CTG web API over Wi-Fi.

## Architecture

```
  BPI-R3 Mini (CTG)                    M5Stack Cardputer
  ┌─────────────────┐                  ┌──────────────────┐
  │ main.py --web   │  Wi-Fi LAN       │ ctg_status.py    │
  │ :8765 /api/status ─────────────────►│ poll every 4s    │
  └─────────────────┘                  └──────────────────┘
```

No firmware changes to CTG are required — the Cardputer is a **read-only status client**.

## Desktop test (before flashing Cardputer)

Terminal A — start CTG:

```powershell
python main.py --simulation --web
```

Terminal B — Cardputer-style display:

```powershell
python scripts\cardputer_status.py --host 127.0.0.1 --watch
```

You should see mood, level, blocked count, and the last threat source IP updating every 3 seconds.

## Flash to Cardputer

1. Copy `scripts/cardputer/ctg_status.py` to your Cardputer SD or M5 OS payload folder.
2. Edit `CTG_HOST` to the LAN IP of your BPI-R3 Mini (e.g. `192.168.1.50`).
3. Ensure Cardputer and CTG are on the same network.
4. Run from M5 OS launcher or as a standalone MicroPython script.

Requires `urequests` (or `requests` on CPython test builds) and your M5 LCD library (`M5.LCD` or LovyanGFX wrapper).

## PlatformIO firmware (native C++)

For lower latency and M5Unified graphics, use the PlatformIO project:

```bash
cd scripts/cardputer/platformio
pio run -t upload
```

Configure `CTG_HOST` in `platformio.ini` and Wi-Fi credentials in `src/main.cpp`. See [platformio/README.md](../scripts/cardputer/platformio/README.md).

## M5 OS launcher (firmware catalog)

Field apps ship through **[M5_OS-Cardputer](https://github.com/salvador-Data/M5_OS-Cardputer)** — SD layout, manifest download, and flash-from-SD workflow. Security details (HTTPS-only manifest URLs, SHA-256 verify before flash, Wi-Fi password handling): [M5 OS SECURITY.md](https://github.com/salvador-Data/M5_OS-Cardputer/blob/main/SECURITY.md).

Host-side manifest validation:

```bash
python scripts/validate_manifest.py data/manifest.example.json
```

(Run from the M5_OS-Cardputer repo root.)

## JSON fields used

| Path | Cardputer display |
|------|-------------------|
| `gotchi.mood` | Status label (IDLE, ALERT, BLOCK, …) |
| `gotchi.name` | Title line |
| `gotchi.level` | Level |
| `gotchi.threats_blocked` | Block counter |
| `gotchi.status_line` | Caption |
| `threats[0].source_ip` | Last attacker |
| `threats[0].severity` | Severity color hint |
| `threats[0].action_taken` | IPS action |

## Mood → icon map (desktop client)

| Mood | Icon |
|------|------|
| idle | `(~)` |
| happy | `(^)` |
| alert | `(!)` |
| attack | `(X)` |
| sleep | `(z)` |
| feed | `(o)` |
| defend | `[=]` |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `CTG unreachable` | Ping CTG IP; confirm `--web` and firewall allow port 8765 |
| Empty threats | Normal until simulation/live traffic generates events |
| Wrong mood | Check `/api/status` in browser — Cardputer mirrors that JSON |

## Ecosystem

Part of the [Hacker Planet LLC toolkit](ECOSYSTEM.md). CTG defends the edge; Cardputer shows status in the field; Bjorn handles authorized assessment on a separate Pi.

See also [INTEGRATIONS.md](INTEGRATIONS.md) for webhooks and Bjorn log bridging.
