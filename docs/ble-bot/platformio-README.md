# PlatformIO — BLE Bot firmware

Keyboard-first **BLE scout** for the M5Stack Cardputer. Authorized lab use only — scan networks and devices you own or have written permission to test.

## Prerequisites

- [PlatformIO](https://platformio.org/) (VS Code extension or CLI)
- M5Stack Cardputer on USB (ESP32-S3)

## Environment

| Setting | Value |
|---------|--------|
| Env name | `m5stack-cardputer` |
| Board | `esp32-s3-devkitc-1` (8 MB flash) |
| Library | `m5stack/M5Cardputer@^1.0.2` |

Tune scan duration / auto-refresh in `platformio.ini`:

```ini
build_flags =
    -DBLE_SCAN_SECONDS=5
    -DBLE_REFRESH_MS=8000
```

## Build & flash

```bash
cd platformio
pio run -e m5stack-cardputer
pio run -e m5stack-cardputer -t upload
pio device monitor
```

## Package for M5 OS / SD

Copy the build artifact to the repo firmware slot (used by M5 OS manifest and shop SD cards):

```bash
# Linux / macOS / Git Bash
mkdir -p ../data/firmware
cp .pio/build/m5stack-cardputer/firmware.bin ../data/firmware/ble_bot.bin
```

```powershell
# Windows PowerShell
New-Item -ItemType Directory -Force -Path ..\data\firmware | Out-Null
Copy-Item .pio\build\m5stack-cardputer\firmware.bin ..\data\firmware\ble_bot.bin
```

Prebuilt binaries ship on [GitHub Releases](https://github.com/salvador-Data/BLE-Bot-Cardputer/releases) — source `.bin` files are gitignored.

## Controls

| Key | Action |
|-----|--------|
| `;` / `w` | Move selection up |
| `.` / `s` | Move selection down |
| Enter / Space | Device detail (address, RSSI) |
| `r` | Rescan now |
| `` ` `` | Back from detail view |

Auto-rescan runs every `BLE_REFRESH_MS` (default 8 s).

**Source repo:** https://github.com/salvador-Data/BLE-Bot-Cardputer
