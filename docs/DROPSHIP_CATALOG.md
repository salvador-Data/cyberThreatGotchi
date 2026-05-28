# Drop-ship catalog — merchant guide

Hacker Planet LLC operates **retail drop-ship**: customer pays you at **retail price** → you order from **supplierUrl** → supplier ships to customer.

No affiliate “buy on Etsy” buttons on the live shop — everything with a price checks out through **Stripe** (plus PayPal/Venmo/Cash App when configured).

## Workflow

```
Customer → shop.html checkout ($ retail)
         → Stripe webhook / email to you
         → You order from supplierUrl
         → Supplier drop-ships to customer address
```

## Config files

| File | Purpose |
|------|---------|
| `website/js/catalog.config.js` | Products, retail prices, `supplierUrl`, `stripeKey` |
| `website/js/payments.config.js` | Stripe Payment Links (one per `stripeKey`) |
| `docs/DROPSHIP_CATALOG.md` | This guide + supplier table |

## Retail catalog (current)

| Product | Retail | Stripe key | Supplier |
|---------|--------|------------|----------|
| Pwnagotchi wardrive pod | $169 | `dsPwnagotchi` | Etsy makers |
| Netgotchi | $99 | `dsNetgotchi` | OlleAdventures |
| Netgotchi Pro | $129 | `dsNetgotchiPro` | OlleAdventures |
| Night Hunter Kali pod | $189 | `dsNightHunter` | HoneyHoneyTrading / CYD |
| LilyGO T-Beam Meshtastic | $89 | `dsMeshtasticTBeam` | LilyGO / AliExpress |
| Heltec V3 Meshtastic | $79 | `dsMeshtasticHeltec` | Heltec |
| RAK4631 Meshtastic starter | $119 | `dsMeshtasticRAK` | RAKwireless |
| Meshtastic field case | $34 | `dsMeshtasticCase` | Etsy 3D print |
| Hackberry Pi Zero | $279 | `dsHackberryZero` | ZitaoTech |
| Hackberry Pi 5 | $449 | `dsHackberryPi5` | ZitaoTech |
| Hackberry Pi CM5 | $499 | `dsHackberryCM5` | ZitaoTech |
| Marauder GPS pocket v2 | $219 | `dsMarauderGps` | HoneyHoneyTrading |
| CYD battery + GPS mod | $59 | `dsMarauderBatteryMod` | Biscuit Shop |
| HPL Marauder custom GPS | $199 | `marauderCustom175` | HPL assembly |
| Boost Formula COD kit | $99 | `boostFormulaCod` | HPL assembly |
| Official Marauder Kit | $89 | `dsMarauderKoko` | JustCallMeKoko |
| Raspberry Pi 5 kit | $139 | `dsRaspberryPi5` | AliExpress vetted |
| Orange Pi 5 Plus kit | $119 | `dsOrangePi5` | AliExpress / Orange Pi |
| Banana Pi BPI-R3 Mini | $109 | `dsBananaPiR3` | AliExpress |
| ESP32 CYD lab bundle (×2) | $49 | `dsEsp32Cyd` | AliExpress |
| COD STL + KSS pack | $19 | `codStlPack` | HPL digital |

Free STLs (GitHub / Printables) stay as direct download links — no checkout.

## Margin tip

Target **~30–45%** over supplier cost to cover payment fees, shipping variance, and handling. Adjust `retailPrice` in `catalog.config.js` and matching `price` in `payments.js`.

## Go-live

1. Create Stripe Payment Links for every `stripeKey` in `payments.config.js`
2. Set `demoMode: false`
3. `python scripts/check_payments.py`
4. `python scripts/sync_website_to_docs.py` → push to `main`

## Legal

Authorized lab / education use only for offensive-capable RF tools. Meshtastic complies with local LoRa regulations — customer responsible for band plan.
