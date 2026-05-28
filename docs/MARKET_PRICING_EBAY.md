# eBay US market pricing reference (May 2026)

Snapshot for **Hacker Planet LLC** partner-fulfillment sourcing and retail sanity checks. Prices are representative fixed-price / Buy-It-Now listings on eBay.com (US ship-to). **Not** a mandate to match eBay — use with [PRODUCT_PRICING.md](PRODUCT_PRICING.md) BOM and Philadelphia COGS.

**Method:** Category searches and vetted listings, May 2026. Gray-market imports excluded from “typical” where they undercut authorized supply (especially BPI-R3 Mini).

---

## Price table vs HPL retail

| Category | Condition | Low | Typical | High | HPL SKU / retail |
|----------|-----------|-----|---------|------|------------------|
| Banana Pi BPI-R3 **Mini** (2 GB RAM / 8 GB eMMC, board only) | New | ~$90¹ | ~$108–110 | ~$217–222 | Component in `coreKit` (~$160 supplier floor); **`dsBananaPiR3` ops spare only** |
| BPI-R3 Mini + case / PSU bundle | New | ~$108 | ~$150 | ~$300 | — |
| BPI-R3 Mini RAM target | — | N/A | **2 GB only** for Mini SKU | — | No 1 GB Mini variant in CTG production |
| Complete CTG-like edge IPS (BPI + e-ink + enclosure + flash) | New | — | **No direct eBay comps** | — | `coreKit` **$219** |
| ESP32 CYD 2.8″ (board only, ESP32-2432S028R) | New | ~$9 | ~$14–16 | ~$23 | Raw BOM ~$14 in `cydStandard`; `dsEsp32Cyd` **$49** (×2 bundle) |
| CYD Marauder / Launcher flashed (basic) | New | ~$34–40 | ~$65–80 | ~$90 | `cydStandard` **$89.99** |
| CYD Marauder GPS + battery + case | New | — | ~$90 | ~$90 | `cydFieldCustom` **$189.99**; `dsNightHunter` **$189** |
| M5Stack Cardputer (board / kit only) | New | ~$47 | ~$50 | ~$74 | BOM ~$58 in Cardputer SKUs |
| M5 Cardputer + custom security firmware | New | — | scarce | ~$166 | `remotePossibility` **$99.99** · `bleBot` **$89.99** |
| Meshtastic Heltec V3 fully built (case + battery) | New | ~$47² | ~$70–85 | ~$166 | `dsMeshtasticHeltec` **$129** (Etsy-primary; eBay fallback search) |
| Raspberry Pi 5 8 GB (board only) | New / used | ~$60 / ~$46 | ~$80 MSRP | ~$120 | Reference |
| Raspberry Pi 5 8 GB starter / PRO kit | New | ~$130 | ~$190 | ~$280–294 | `dsRaspberryPi5` **$159** |
| Kali NetHunter phone (pre-rooted) | Used / new-other | ~$110 | ~$189–220 | ~$800–1,800 | `dsKaliNetHunter` **$399** (builder-direct primary) |
| Pwnagotchi assembled (basic e-ink) | New | ~$108 | ~$112–115 | ~$115 | `dsPwnagotchi` **$169** |
| Fancygotchi / premium pwnagotchi | New | ~$150 | ~$185–235 | ~$255 | Tindie-heavy; eBay thin |
| Netgotchi / defensive tamagotchi | New | ~$39–44³ | ~$52–59 | ~$157³ | `dsNetgotchi` **$99** · `dsNetgotchiPro` **$129** |
| Orange Pi 5 Plus 8 GB kit | New | ~$78 | ~$95–110 | ~$140 | `dsOrangePi5` **$119** |
| Breadboard + jumper kit | New | ~$8 | ~$12–16 | ~$22 | `dsWiringLab` **$22** |
| NVIDIA Jetson Nano 4 GB dev kit | New / pre-owned | ~$100 | ~$180–285 | ~$300 | BOM ref in `crackbotBench`; **`crackbotBench` $499** full lab |

¹ Gray-market imports; unreliable for Philly COGS — treat **~$160** as planning floor per authorized supplier (May 2026).

² Bare Heltec V3 LoRa boards; built nodes cluster ~$70–85 on eBay.

³ Netgotchi sold primarily on Tindie/Etsy (OlleStore); few eBay listings.

---

## Upsell margin guidance (eBay floor → HPL retail)

| Trigger SKU | Upsell | eBay est. floor | HPL retail | Assembly / curation value |
|-------------|--------|-----------------|------------|---------------------------|
| `coreKit` | `fieldPack` | Cardputer ~$50 | **$279** bundle | Philly flash + bundle QC |
| `coreKit` | `proYearly` | — | **$99/yr** | Rule curation + API |
| `cydStandard` | `dsWiringLab` | ~$12 | **$22** | Curated kit + ship |
| `dsMeshtasticHeltec` | `dsMeshtasticCase` | ~$15 | **$34** | Board-fit routing |
| `dsEsp32Cyd` | `dsWiringLab` | ~$12 | **$22** | Lab bring-up bundle |

Public copy: **partner fulfillment** / **curated hardware** — never “dropship” on customer-facing pages.

---

## Operator eBay search templates

Use [PARTNER_FULFILLMENT_RUNBOOK.md](PARTNER_FULFILLMENT_RUNBOOK.md) and `python scripts/partner_fulfillment_export.py` (or `ebay_fulfillment_export.py` for eBay-only) for ship-to packets. Search URLs are in `website/js/shipping-tracker.config.js`.

---

*Hacker Planet LLC · Philadelphia, PA · Authorized lab use only*
