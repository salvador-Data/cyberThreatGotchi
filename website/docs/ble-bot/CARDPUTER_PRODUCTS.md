# M5 Cardputer field firmware — Remote Possibility & BLE Bot

Hacker Planet LLC ships two Philadelphia-assembled Cardputer SKUs (see [PRODUCT_PRICING.md](https://github.com/salvador-Data/cyberThreatGotchi/blob/main/docs/PRODUCT_PRICING.md)):

| Firmware | Price | Role |
|----------|-------|------|
| **Remote Possibility** | $89.99 | Poll CyberThreatGotchi `/api/status` from the field |
| **BLE Bot** | $79.99 | Authorized BLE scout / proximity lab on Cardputer keyboard UI |

## DIY flash

1. Build **M5 OS** base from [M5_OS-Cardputer](https://github.com/salvador-Data/M5_OS-Cardputer) (`pio run -e m5stack-cardputer -t upload`).
2. Build app firmware from the product repos (PlatformIO env `m5stack-cardputer` in each).
3. Add firmware packages to your manifest (`data/manifest.example.json` on M5 OS):

```json
{
  "name": "Remote Possibility",
  "version": "1.0.0",
  "url": "https://github.com/salvador-Data/Remote-Possibility/releases/download/v1.0.0/remote_possibility.bin",
  "description": "CTG field remote status client"
},
{
  "name": "BLE Bot",
  "version": "1.0.0",
  "url": "https://github.com/salvador-Data/BLE-Bot-Cardputer/releases/download/v1.0.0/ble_bot.bin",
  "description": "Authorized BLE lab scout"
}
```

Until a release is tagged, build from source:

- Remote Possibility → [Remote-Possibility/platformio](https://github.com/salvador-Data/Remote-Possibility/tree/main/platformio)
- BLE Bot → [BLE-Bot-Cardputer/platformio](https://github.com/salvador-Data/BLE-Bot-Cardputer/tree/main/platformio)

## Shop

- [cardputer.html](https://hackerplanet.dev/cardputer.html) · `#remote-possibility` · `#ble-bot`

*Authorized networks only.*

**Source repo:** https://github.com/salvador-Data/BLE-Bot-Cardputer
