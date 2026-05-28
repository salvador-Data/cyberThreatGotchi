# PlatformIO Cardputer firmware

Native C++ firmware for **M5Stack Cardputer** — polls CyberThreatGotchi `/api/status` over Wi-Fi.

MicroPython alternative: [../ctg_status.py](../ctg_status.py) · Full doc: [CARDPUTER.md](../../../docs/CARDPUTER.md)

## Prerequisites

- [PlatformIO](https://platformio.org/) (VS Code extension or CLI)
- Cardputer on same LAN as CTG (`python main.py --web`)

## Configure

Edit `platformio.ini`:

```ini
build_flags =
    -DCTG_HOST=\"192.168.1.50\"
    -DCTG_PORT=8765
    -DPOLL_MS=4000
```

Set Wi-Fi in `src/main.cpp` (`WIFI_SSID` / `WIFI_PASS`) or add matching `-D` flags.

## Build & flash

```bash
cd scripts/cardputer/platformio
pio run
pio run -t upload
pio device monitor
```

## Screen layout

| Row | Content |
|-----|---------|
| 1 | `CTG Cipherhorn` |
| 2 | Mood label + level |
| 3 | Blocked / seen counts |
| 4 | Gotchi status line |
| 5–6 | Last threat IP, severity, action |

Red header = CTG unreachable; yellow IP row on `alert` / `attack` moods.
