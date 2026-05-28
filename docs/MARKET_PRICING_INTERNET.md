# Internet market pricing — authorized lab hardware (May 2026)

Broad snapshot for **Hacker Planet LLC** partner-fulfillment sourcing across eBay, Amazon, AliExpress, SparkFun, Adafruit, Hak5, NooElec, and specialist builders. **Reference only** — use with [PRODUCT_PRICING.md](PRODUCT_PRICING.md) and [MARKET_PRICING_EBAY.md](MARKET_PRICING_EBAY.md).

Public copy: **partner fulfillment** / **curated hardware** — never “dropship.” Offensive-capable tools require **authorized networks and written scope** only.

---

## SDR & RF lab

| Product | Primary supplier | URL pattern | Est. cost | Suggested retail | Ship time | Authorized-use note |
|---------|------------------|-------------|-----------|------------------|-----------|---------------------|
| RTL-SDR Blog V3 + dipole kit | SparkFun / Amazon | `sparkfun.com/rtl-sdr-blog-v3*` · `amazon.com/dp/B0BMKB3L47` | ~$35–85 | **$99** (`dsRtlSdrKit`) | 3–7 days US | Receive-only lab; no transmit without license |
| NESDR SMArt v5 + antenna bundle | NooElec | `nooelec.com/store/nesdr-smart.html` | ~$42–52 | **$65** (`dsNesdrSmart`) | 5–10 days | Same; budget SDR tier |
| HackRF One (reference) | Great Scott Gadgets / NooElec | `greatscottgadgets.com/hackrf` · ~$350 | ~$350 | Not sold — reference | Varies | **TX capable** — amateur license / authorized lab only |
| Flipper Zero (reference) | flipper.net | `flipper.net/products/flipper-zero` | ~$199 MSRP | Not sold — reference | Backorder common | Sub-GHz/NFC lab; no counterfeit clones |

---

## Network tap & Ethernet lab

| Product | Primary supplier | URL pattern | Est. cost | Suggested retail | Ship time | Authorized-use note |
|---------|------------------|-------------|-----------|------------------|-----------|---------------------|
| Throwing Star LAN Tap Pro | Hak5 / resellers | `shop.hak5.org/products/throwing-star-lan-tap-pro` | ~$45 | **$59** (`dsLanTap`) | 5–10 days | Passive tap on **your** network segment only |
| Throwing Star LAN Tap kit (DIY) | Hak5 | `shop.hak5.org/products/throwing-star-lan-tap` | ~$20 | **$38** (`dsThrowingStarKit`) | 5–10 days | Solder kit; same passive monitoring scope |

---

## WiFi offensive / defensive lab (reference & curated)

| Product | Primary supplier | URL pattern | Est. cost | Suggested retail | Ship time | Authorized-use note |
|---------|------------------|-------------|-----------|------------------|-----------|---------------------|
| WiFi Pineapple Mark VII (reference) | Hak5 | `shop.hak5.org` · from ~$250 | ~$250 | **$319** (`dsHak5WifiPineapple`) | 7–14 days | **Red-team engagements with written authorization only** |
| USB Rubber Ducky | Hak5 | `shop.hak5.org/products/usb-rubber-ducky` | ~$100 | **$129** (`dsUsbRubberDucky`) | 5–10 days | Keystroke injection **training lab** — owned devices only |
| ESP32 WiFi lab board | Adafruit | `adafruit.com/product/3591` (HUZZAH32) | ~$21–28 | **$45** (`dsEsp32WifiLab`) | 3–7 days | Monitor-mode / firmware lab on authorized APs |
| O.MG cable class (reference) | Hak5 / research | Document only | ~$100+ | Not sold | — | **Document awareness only** — malicious-cable training in isolated lab |
| CYD / Marauder / ESP32 wardrive | See [MARKET_PRICING_EBAY.md](MARKET_PRICING_EBAY.md) | eBay · AliExpress · Tindie | ~$14–90 | $49–189 | 5–14 days | Authorized RF observation |

---

## Meshtastic, LoRa, gotchi pods

| Product | Primary supplier | URL pattern | Est. cost | Suggested retail | Ship time | Authorized-use note |
|---------|------------------|-------------|-----------|------------------|-----------|---------------------|
| Heltec V3 Meshtastic built | Etsy (LayerFabUK) | Etsy listing + eBay fallback search | ~$70–90 | **$129** | 5–14 days | Off-grid mesh on licensed/ISM bands per region |
| LilyGO T-Beam | LilyGO / AliExpress | `lilygo.cc/products/t-beam*` | ~$55 | **$89** | 10–21 days | LoRa band must match checkout notes |
| Pwnagotchi assembled | eBay / Etsy | eBay search · Etsy makers | ~$108–115 | **$169** | 7–14 days | Passive WiFi lab observation |
| Netgotchi defensive | OlleAdventures Etsy | Etsy primary | ~$44–59 direct | **$99–129** | 5–12 days | Defensive honeypot / scan alerts |

---

## Mobile & cyberdeck

| Product | Primary supplier | URL pattern | Est. cost | Suggested retail | Ship time | Authorized-use note |
|---------|------------------|-------------|-----------|------------------|-----------|---------------------|
| Kali NetHunter phone | KaliNetHunter.com | `kalinethunter.com/products` | ~$189–280 | **$399** | 7–21 days | Pre-flashed **authorized mobile pentest lab** |
| Hackberry Pi Zero / Pi5 | ZitaoTech / Elecrow / Tindie | Elecrow · Tindie | ~$165–320 | **$279–499** | 10–28 days | Kali-ready cyberdeck; keyboard variant at checkout |

---

## SBC & edge (existing catalog)

| Product | Channels | Est. cost | Retail | Notes |
|---------|----------|-----------|--------|-------|
| BPI-R3 Mini 2 GB | eBay · AliExpress · BPI shop | ~$160 floor | In `coreKit` **$219** | Not standalone retail |
| Raspberry Pi 5 8 GB kit | CanaKit · Amazon · eBay | ~$105–190 | **$159** | Authorized reseller preferred |
| Orange Pi 5 Plus 8 GB | Orange Pi store · AliExpress · eBay | ~$78–110 | **$119** | Homelab edge |
| M5 Cardputer | Amazon · M5Stack | ~$47–58 | In Cardputer SKUs | BOM reference |

---

## Books, badges, training media (reference — not HPL SKUs)

| Category | Typical source | Price range | HPL stance |
|----------|----------------|-------------|------------|
| Penetration testing books (RTFM, PAH) | Amazon | ~$30–50 | Link in docs; no scraped cover art |
| DEF CON / badge hardware | Event vendors | $80–300+ | Seasonal; reference only |
| Hak5 Payload Studio / courses | shop.hak5.org | $40–60 add-ons | Bundle with Ducky at operator discretion |

---

## Margin & upsell alignment

| Trigger | Cross-sell | Rationale |
|---------|------------|-----------|
| `coreKit` | `dsRtlSdrKit`, `dsLanTap`, `fieldPack`, `proYearly` | Edge IPS + RF spectrum + tap visibility |
| `cydStandard` | `dsWiringLab`, `dsEsp32WifiLab` | Bench bring-up |
| `dsRtlSdrKit` | `dsNesdrSmart` (budget alt), `dsLanTap` | Layer RF + Ethernet visibility |
| `crackbotBench` | `dsRtlSdrKit` | Jetson lab + SDR sidecar |

Operator export: `python scripts/partner_fulfillment_export.py --stripe-key dsRtlSdrKit --ship-to "..."`

---

*Hacker Planet LLC · Philadelphia, PA · Authorized lab use only*
