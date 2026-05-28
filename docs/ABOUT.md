# About CyberThreatGotchi

**CyberThreatGotchi** is a portable, defensive security appliance dressed as a Tamagotchi. Your mascot **Cipherhorn** (unicorn CISO in a suit and mask) reacts to real network events—blocks, scans, malware hits—so executives and builders get a friendly face on serious telemetry.

## Why it exists

Most SOCs drown in dashboards. CyberThreatGotchi gives Hacker Planet LLC a **field device** that:

- Captures or simulates traffic on the edge (Banana Pi BPI-R3 Mini or dev laptop)
- Scores threats with signatures, YARA, and hash deny-lists
- Blocks repeat offenders via IPS (Linux / iptables)
- Logs evidence to SQLite for incidents
- Shows mood, hunger, and XP on terminal, web, e-ink, or SPI LCD

## Cipherhorn & the cat sentinels

| Persona | Role |
|---------|------|
| **Cipherhorn** | Unicorn CISO — mood tracks threat pressure |
| **Business cat** | Risk / policy sentinel |
| **Mass-market cat** | Consumer-facing alerts |
| **SOC cat** | Operator / analyst persona |

Sprites live in `assets/sprites/` (ASCII + generated PNG for the web UI).

## Hardware targets

| Tier | Platform | Display |
|------|----------|---------|
| **Production** | Banana Pi BPI-R3 Mini | Waveshare 2.13" e-ink or 2.4" ILI9341 LCD |
| **Development** | Windows / Linux PC | Terminal or Flask web dashboard |

Enclosure: see `hardware/ENCLOSURE.md` and `hardware/enclosure.scad`.

## Defensive use only

Run on networks and systems you own or are authorized to monitor. The IPS and detection stack is for **protection and visibility**, not unauthorized access.

## Author

[salvador-Data](https://github.com/salvador-Data) · Hacker Planet LLC
