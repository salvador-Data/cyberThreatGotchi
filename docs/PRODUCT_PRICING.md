# Hacker Planet LLC — product pricing & BOM

Authoritative retail prices for Philadelphia direct-ship SKUs. **Tax and shipping are extra** on hardware (see [SHIPPING_AND_TAX.md](SHIPPING_AND_TAX.md)). Partner drop-ship prices live in [DROPSHIP_CATALOG.md](DROPSHIP_CATALOG.md).

**Pricing principle:** CYD pocket hardware is priced separately from **Mr. CrackBot AI Nano** (Jetson bench lab). Cardputer tools (**Remote Possibility**, **BLE Bot**) are M5Stack SKUs — not CYD builds.

---

## CYD field builds (hardware platform)

| SKU | Stripe key | Retail | + tax/shipping |
|-----|------------|--------|----------------|
| CYD Field Build — Standard | `cydStandard` | **$89.99** | Yes |
| CYD custom field build | `cydFieldCustom` | **$189.99** | Yes |

### Standard CYD — $89.99 (`cydStandard`)

| Qty | Part | Est. cost |
|-----|------|-----------|
| 1 | ESP32-2432S028 CYD 2.8″ | $14 |
| 1 | Printed PETG pocket enclosure | $6 |
| 1 | USB-C cable | $4 |
| 1 | Flash + quick-start + handling | $25 |
| **COGS** | | **~$49** |

Includes: flashed HPL field profile, enclosure color at checkout. **Not** CrackBot firmware.

### Custom CYD — $189.99 (`cydFieldCustom`)

| Qty | Part | Est. cost |
|-----|------|-----------|
| 1 | CYD 2.8″ + GPS module | $22 |
| 1 | Extended Wi‑Fi / BLE radio + SMA antenna | $35 |
| 1 | LiPo pack + on/off switch + charging | $28 |
| 1 | Custom enclosure + routing | $10 |
| 1 | Assembly + Marauder/wardrive profile flash | $45 |
| **COGS** | | **~$140** |

Includes: GPS wardrive or custom lab profile, antenna layout, battery tray. Firmware profile chosen at checkout (Marauder GPS, extended Wi‑Fi lab, etc.).

---

## Mr. CrackBot AI Nano (difficult bench build)

| SKU | Stripe key | Retail | Notes |
|-----|------------|--------|-------|
| DIY simulation | — | **$0** | GitHub only |
| Bench lab assembled | `crackbotBench` | **$499** | Jetson + CYD UI + GPU hashcat path |

**CrackBot is not sold as a CYD-only SKU.** The CYD in this build is the pocket **UI shell**; the product is the full Jetson lab.

### Bench lab BOM — $499 (`crackbotBench`)

| Qty | Part | Est. cost |
|-----|------|-----------|
| 1 | NVIDIA Jetson Nano 4GB + carrier | $119 |
| 1 | CYD 2.8″ (Mr. Pac-Bot window) | $16 |
| 1 | USB Wi‑Fi (monitor mode, vent routed) | $28 |
| 1 | LiPo + charger + power path | $22 |
| 1 | Printed Mr. Pac-Bot enclosure (front/rear/clip) | $8 |
| 1 | M2 standoffs, USB-C, internal wiring | $8 |
| 1 | CrackBot Nano flash + 4hr assembly + burn-in | $140 |
| **COGS** | | **~$341** |

Includes: pre-flashed CrackBot stack, wordlist pack scope at checkout, Philadelphia 3–5 day handling.

---

## CyberThreatGotchi (edge IPS)

| SKU | Stripe key | Retail | BOM ref |
|-----|------------|--------|---------|
| Cipherhorn core | `coreKit` | **$189** | [KICKSTARTER_BOM.md](KICKSTARTER_BOM.md) ~$212 |
| Field Pack (core + Cardputer) | `fieldPack` | **$249** | Core + M5 Cardputer bundle |

Core kit COGS: BPI-R3 Mini ($160) + e-ink HAT ($22) + SD/PSU/enclosure (~$30) → **~$212** retail **$189** (assembly tier; partner drop-ship board-only **`dsBananaPiR3`** @ **$160**).

---

## M5 Cardputer field tools

| SKU | Stripe key | Retail | Role |
|-----|------------|--------|------|
| Remote Possibility | `remotePossibility` | **$99.99** | CTG remote status + field HTTP client |
| BLE Bot | `bleBot` | **$89.99** | Authorized BLE scout / proximity lab tool |

### Remote Possibility — $99.99

| Qty | Part | Est. cost |
|-----|------|-----------|
| 1 | M5Stack Cardputer kit | $58 |
| 1 | microSD + Remote Possibility firmware | $8 |
| 1 | Quick-start + pairing guide | $5 |
| **COGS** | | **~$71** |

Polls CyberThreatGotchi `/api/status`; pairs with Field Pack or standalone.

### BLE Bot — $89.99

| Qty | Part | Est. cost |
|-----|------|-----------|
| 1 | M5Stack Cardputer kit | $58 |
| 1 | BLE Bot firmware flash | $6 |
| **COGS** | | **~$64** |

Authorized BLE lab workflows on the Cardputer keyboard UI — separate from CYD Wi‑Fi tools.

---

## Other direct / digital

| SKU | Stripe key | Retail |
|-----|------------|--------|
| Boost Formula COD field kit | `boostFormulaCod` | $99 |
| COD STL + KSS print pack | `codStlPack` | $19 |
| Digital Pack | `digital` | $15 |
| CTG Pro feed monthly | `proMonthly` | $9/mo |
| CTG Pro feed yearly | `proYearly` | $99/yr |

---

## Deprecated SKUs (do not use)

| Old key | Replaced by |
|---------|-------------|
| `crackbotCyd` | CYD = `cydStandard` / `cydFieldCustom`; CrackBot = `crackbotBench` |
| `marauderCustom175` | `cydFieldCustom` @ $189.99 |

---

*Hacker Planet LLC · Philadelphia, PA · Authorized use only*
