# BLE Bot — M5 Cardputer authorized BLE lab tool

**Hacker Planet LLC** · Philadelphia, PA · [cardputer.html](https://hackerplanet.dev/cardputer.html)

Keyboard-first **BLE scout / proximity lab** firmware for the M5Stack Cardputer. This is an M5 field SKU — not a CYD Wi‑Fi build.

| SKU | Stripe key | Retail |
|-----|------------|--------|
| BLE Bot | `bleBot` | **$79.99** (+ tax/shipping) |

Philadelphia-assembled units ship pre-flashed. DIY builders build from this repo.

## Contents

- `platformio/` — Arduino / PlatformIO firmware (`pio run -e m5stack-cardputer`)
- `data/firmware/` — slot for `ble_bot.bin` (M5 OS manifest / SD); prebuilt on [Releases](https://github.com/salvador-Data/BLE-Bot-Cardputer/releases)

## Build (Windows / macOS / Linux)

Install [PlatformIO](https://platformio.org/), then:

```bash
cd platformio
pio run -e m5stack-cardputer
pio run -e m5stack-cardputer -t upload
```

Copy `platformio/.pio/build/m5stack-cardputer/firmware.bin` → `data/firmware/ble_bot.bin` for M5 OS packaging. Full steps: [platformio/README.md](platformio/README.md).

## M5 OS launcher

Install **M5 OS** first so packages load from SD or manifest: [M5_OS-Cardputer](https://github.com/salvador-Data/M5_OS-Cardputer). Manifest entry template: [docs/CARDPUTER_PRODUCTS.md](docs/CARDPUTER_PRODUCTS.md).

## Shop & pricing

- https://hackerplanet.dev/cardputer.html#ble-bot
- [PRODUCT_PRICING.md](https://github.com/salvador-Data/cyberThreatGotchi/blob/main/docs/PRODUCT_PRICING.md)

*Authorized BLE lab workflows only — networks and devices you own or have written permission to test.*

**Source repo:** https://github.com/salvador-Data/BLE-Bot-Cardputer
