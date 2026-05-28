# Drop-ship catalog — merchant guide

**Hacker Planet direct-ship** (CYD, CrackBot bench, Cardputer, CTG kits) → [PRODUCT_PRICING.md](PRODUCT_PRICING.md) and [SHIPPING_AND_TAX.md](SHIPPING_AND_TAX.md).

**Partner drop-ship** (below): customer pays HPL at retail → **operator** orders from `supplierUrl` manually → partner ships to customer.

No affiliate “buy on Etsy” buttons on the live shop — priced SKUs check out through **Stripe** when links are configured.

**Manual fulfillment only** — see [DROPSHIP_FULFILLMENT_RUNBOOK.md](DROPSHIP_FULFILLMENT_RUNBOOK.md) and `scripts/dropship_order_export.py`.

## Workflow

```
Customer → shop.html checkout ($ retail)
         → Stripe payment to Hacker Planet LLC
         → Operator exports order packet (CSV / text)
         → Manual order on Etsy / AliExpress / Tindie / authorized store
         → Supplier drop-ships to customer address
```

## Config files

| File | Purpose |
|------|---------|
| `website/js/catalog.config.js` | Products, retail prices, `supplierUrl`, `stripeKey` |
| `website/js/shipping-tracker.config.js` | Lead times, checklists, fulfillment statuses |
| `website/js/shipping-tracker.js` | Tracking URL helper (operator / future ops UI) |
| `website/js/direct.config.js` | Philadelphia direct-ship SKUs |
| `website/js/payments.config.js` | Stripe Payment Links (one per `stripeKey`) |
| `docs/DROPSHIP_CATALOG.md` | This guide + supplier table |
| `docs/PRODUCT_PRICING.md` | Direct-ship BOM and retail prices |

## Retail catalog & margin targets (~30–45% over supplier)

| Product | Retail | Est. supplier | Stripe key | Supplier / channel |
|---------|--------|---------------|------------|-------------------|
| Pwnagotchi wardrive pod | $169 | ~$115 | `dsPwnagotchi` | Etsy makers / [GarthVH](https://www.etsy.com/shop/GarthVH) |
| Netgotchi | $99 | ~$65 | `dsNetgotchi` | [OlleAdventures Etsy](https://olleadventures.etsy.com/listing/1752764124) |
| Netgotchi Pro | $129 | ~$85 | `dsNetgotchiPro` | [OlleAdventures Etsy](https://olleadventures.etsy.com/listing/1771783598) |
| Night Hunter Kali pod | $189 | ~$145 | `dsNightHunter` | [HoneyHoneyTrading Tindie](https://www.tindie.com/products/honeyhoneytrading/esp32-marauder-pocket-unit-with-gps-v2/) |
| **Heltec V3 fully built Meshtastic** | **$129** | **~$90** | **`dsMeshtasticHeltec`** | **[LayerFabUK Etsy](https://www.etsy.com/listing/1733234765/the-knight-complete-device-heltec-v3)** |
| LilyGO T-Beam Meshtastic kit | $89 | ~$55 | `dsMeshtasticTBeam` | [LilyGO T-Beam](https://www.lilygo.cc/products/t-beam-v1-1) |
| RAK4631 Meshtastic starter | $119 | ~$85 | `dsMeshtasticRAK` | [RAKwireless store](https://store.rakwireless.com/products/wisblock-meshtastic-starter-kit) |
| Meshtastic field case | $34 | ~$18 | `dsMeshtasticCase` | Etsy makers |
| Hackberry Pi Zero | $279 | ~$165 | `dsHackberryZero` | [Elecrow / ZitaoTech](https://www.elecrow.com/hackberrypi-zero-with-q10-keyboard.html) |
| Hackberry Pi 5 deck | $449 | ~$280 | `dsHackberryPi5` | [Tindie ZitaoTech](https://www.tindie.com/products/zitaotech/hackberrypi5-with-9900-keyboard/) |
| Hackberry Pi CM5 | $499 | ~$320 | `dsHackberryCM5` | [ZitaoTech CM5](https://github.com/ZitaoTech/HackberryPiCM5) |
| Marauder GPS pocket v2 | $219 | ~$155 | `dsMarauderGps` | HoneyHoneyTrading |
| CYD battery + GPS mod | $59 | ~$38 | `dsMarauderBatteryMod` | [Biscuit Shop](https://biscuitshop.us/products/esp32-marauder-battery-mod-kit) |
| Official Marauder Kit | $89 | ~$58 | `dsMarauderKoko` | [JustCallMeKoko Tindie](https://www.tindie.com/products/justcallmekoko/esp32-marauder-kit/) |
| Raspberry Pi 5 starter kit | $159 | ~$105 | `dsRaspberryPi5` | [CanaKit](https://www.canakit.com/raspberry-pi-5.html) |
| Orange Pi 5 Plus kit | $119 | ~$78 | `dsOrangePi5` | Orange Pi / vetted AliExpress |
| Banana Pi BPI-R3 Mini | $109 | ~$72 | `dsBananaPiR3` | [banana-pi.org](https://www.banana-pi.org/) |
| ESP32 CYD lab bundle (×2) | $49 | ~$28 | `dsEsp32Cyd` | [CYD community guide](https://github.com/witnessmenow/ESP32-Cheap-Yellow-Display) |
| Breadboard + jumper kit | $22 | ~$14 | `dsWiringLab` | [SparkFun](https://www.sparkfun.com/jumper-wire-kit-140pcs.html) |
| Kali NetHunter lab phone | $399 | ~$280 | `dsKaliNetHunter` | [kalinethunter.com](https://kalinethunter.com/products) |

### Direct-ship (Philadelphia) — see PRODUCT_PRICING.md

| Product | Retail | Stripe key |
|---------|--------|------------|
| CYD Field Build — Standard | $79.99 + ship/tax | `cydStandard` |
| CYD custom (GPS, ext radio, battery) | $174.99 + ship/tax | `cydFieldCustom` |
| Mr. CrackBot bench lab (Jetson) | $449 | `crackbotBench` |
| Remote Possibility (Cardputer) | $89.99 | `remotePossibility` |
| BLE Bot (Cardputer) | $79.99 | `bleBot` |
| CyberThreatGotchi core | $169 | `coreKit` |
| Field Pack | $219 | `fieldPack` |

Free STLs (GitHub / Printables) stay as direct download links — no checkout.

## Researched supplier URLs (authorized lab sourcing)

| Category | Sources |
|----------|---------|
| Meshtastic Etsy builders | [Meshtastic radio market](https://www.etsy.com/market/meshtastic_radio), [LayerFabUK](https://www.etsy.com/shop/LayerFabUK), [GarthVH](https://www.etsy.com/shop/GarthVH), [ovvys Tindie](https://www.tindie.com/products/ovvys/complete-lora-device-powered-by-meshtastic/) |
| Kali NetHunter phones | [kalinethunter.com](https://kalinethunter.com/products), [ViP3R Hunter](https://nethunterdevices.com/), [Unlimited Coverage HacPhone](https://unlimitedcoverage.net/products/hacphone-kali-linux-nethunter-nexus-6p-pentesting-phone), [Official install docs](https://www.kali.org/docs/nethunter/installing-nethunter/) |
| Hackberry Pi | [ZitaoTech GitHub Zero](https://github.com/ZitaoTech/Hackberry-Pi_Zero), [Elecrow shop](https://www.elecrow.com/marketplace/seller/collection/shop/zitaotech_70134), [Tindie Pi5](https://www.tindie.com/products/zitaotech/hackberrypi5-with-9900-keyboard/) |
| Raspberry Pi kits | [CanaKit](https://www.canakit.com/), [PiShop.us](https://www.pishop.us/), [Micro Center Pi 5 kits](https://www.microcenter.com/search/search_results.aspx?Ntt=raspberry+pi+5+kit) |
| ESP32 CYD | [witnessmenow CYD repo](https://github.com/witnessmenow/ESP32-Cheap-Yellow-Display), [Makerfabs CYD](https://www.makerfabs.com/sunton-esp32-2-8-inch-tft-with-touch.html) |
| Wiring / breadboard | [SparkFun jumper kit](https://www.sparkfun.com/jumper-wire-kit-140pcs.html), [Adafruit breadboard bundle](https://www.adafruit.com/product/3314), [Adafruit Parts Pal](https://www.adafruit.com/product/2975) |

## Margin tip

Adjust `retailPrice` in `catalog.config.js` and matching `price` in `payments.js` when supplier costs move. Re-run:

```bash
python scripts/check_shop.py
python scripts/dropship_order_export.py --json
pytest tests/test_dropship_fulfillment.py -v
```
