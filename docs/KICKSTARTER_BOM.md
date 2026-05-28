# CyberThreatGotchi Kickstarter kit — bill of materials

Estimated retail kit for **Hacker Planet LLC** desk defender bundle (Cipherhorn e-ink face + BPI-R3 Mini edge sensor). Prices are **USD MSRP-ish** for planning; bulk/OEM quotes will differ.

**Target kit price:** $149–$179 retail  
**Target margin:** ~35% after fulfillment (Kickstarter fees + shipping)

---

## Core kit (required)

| Qty | Part | Supplier / SKU hint | Unit | Extended |
|-----|------|---------------------|------|----------|
| 1 | Banana Pi BPI-R3 Mini (2×2.5GbE) | BPI shop / AliExpress | $89 | $89 |
| 1 | Waveshare 2.13" e-Paper HAT V4 (250×122) | Waveshare `250×122, V4` | $22 | $22 |
| 1 | microSD 32 GB (SanDisk Industrial or A2) | Amazon / Digi-Key | $8 | $8 |
| 1 | USB-C 5V/3A PSU (UL listed) | Anker / Cable Matters | $12 | $12 |
| 1 | 3D printed enclosure (e-ink variant) | In-house PETG print | $6 | $6 |
| 1 | M2.5 screw kit + standoffs | McMaster / Amazon | $3 | $3 |
| 1 | Quick-start card + QR to GitHub | Print house | $1 | $1 |

**Core subtotal:** ~**$141**

---

## Optional add-ons

| Qty | Part | Notes | Unit |
|-----|------|-------|------|
| 1 | Waveshare 1.3" LCD HAT (ST7789) | Color “arcade” face — use `hardware/stl/lcd/` | $18 |
| 1 | Enclosure LCD variant STL pack | Same repo, different bezel | $6 |
| 1 | M5Stack Cardputer | Field status client (polls CTG HTTP) | $55 |
| 1 | Raspberry Pi 4/5 + Bjorn image | Assessment companion (separate SKU) | $75+ |

---

## Consumables & fulfillment

| Item | Est. cost per backer |
|------|----------------------|
| Shipping box + foam | $4 |
| Outbound US shipping (ground) | $8–$12 |
| Kickstarter + payment fees (~10%) | ~$15 on $149 tier |
| RMA / defect buffer (3%) | ~$4 |

---

## Tier suggestions

| Tier | Includes | Backer price | Notes |
|------|----------|--------------|-------|
| **Digital** | Repo + STL zip + sprites | $15 | No hardware |
| **Cipherhorn Core** | BPI-R3 Mini + e-ink + enclosure + SD + PSU | $189 | Early bird $149 (limit 50) |
| **Field Pack** | Core + Cardputer + printed quick guide | $249 | Polls CTG over Wi-Fi |
| **Lab Duo** | Core + Pi 4 Bjorn bundle (no CTG on Pi) | $289 | Two-device story |

---

## Software included (no extra BOM)

- CyberThreatGotchi pre-flashed SD image (optional manufacturing step)
- `install.sh` for bare-metal
- Docker compose for homelab
- Pro feed demo key (`demo`) — production keys via Stripe subscription (Phase 5 API)

---

## Manufacturing notes

1. **Flash SD** with Raspberry Pi Imager equivalent for ARM64 Debian + CTG systemd unit.
2. **Print enclosures** — PETG, 0.2 mm layers; STLs from [hardware/stl/eink/](../hardware/stl/eink/).
3. **Burn-in** — 30 min `--simulation --web` before pack-out.
4. **Label** — MAC + default `http://<dhcp>:8765/` on inner lid.

---

## Year 1 revenue tie-in

See [CISO_PLAYBOOK.md](CISO_PLAYBOOK.md): Kickstarter validates demand before MSP retainer pitch (~$84K Year 1 target with kits + Pro feed + install services).

---

*Hacker Planet LLC — defensive use on authorized networks only.*
