# Stripe Payment Links — Salvador Data runbook

Step-by-step to create every **42** shop SKU + subscription Payment Link in the [Stripe Dashboard](https://dashboard.stripe.com), paste URLs into `website/js/payments.config.js`, and go live.

**Prices:** authoritative retail from [PRODUCT_PRICING.md](PRODUCT_PRICING.md) and `website/js/payments.js`.  
**Partner auto-fulfillment:** add metadata `stripe_key` on every `ds*` link — [STRIPE_FULFILLMENT_METADATA.md](STRIPE_FULFILLMENT_METADATA.md).  
**Do not** set `demoMode: false` until every URL below is pasted.

---

## Before you start (once)

1. Sign in to Stripe → switch to **Live** mode when ready for real checkout.
2. **Settings → Tax** → enable Stripe Tax → add **Pennsylvania** (and any other nexus states).
3. **Settings → Payment methods** → enable **Cards**, **Apple Pay**, **Google Pay**, **Link**.
4. **Settings → Billing → Customer portal** → enable portal → copy URL → paste as `stripeCustomerPortal` in config.

Check empty keys locally:

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
py scripts\stripe_link_checklist.py
```

---

## Create each Payment Link (repeat per SKU)

For **every row** in the tables below:

1. **Product catalog → + Add product** — name matches shop; price matches **Amount** column.
2. **Payment links → + New** — attach that product/price.
3. **Subscriptions** (`/mo` or `/yr`): choose **Recurring** billing interval on the price.
4. **Direct Philly hardware** (`cyd*`, `crackbot*`, `coreKit`, `fieldPack`, `remotePossibility`, `bleBot`, `boostFormulaCod`): enable **Collect shipping address** + Stripe Tax; add US shipping rates if needed ([SHIPPING_AND_TAX.md](SHIPPING_AND_TAX.md)).
5. **Partner drop-ship** (`ds*`): enable **Collect shipping address**; under **Metadata** add `stripe_key` = config key (same string, e.g. `dsRtlSdrKit`).
6. **Digital** (`digital`, `codStlPack`): no shipping; instant fulfillment note in product description.
7. Copy link URL (`https://buy.stripe.com/...`) → paste into `stripePaymentLinks.<key>` in `website/js/payments.config.js`.
8. After **all 42** URLs are filled, set `demoMode: false` and sync:

```powershell
py scripts\check_payments.py
```

```powershell
py scripts\sync_website_to_docs.py
```

---

## Subscriptions (5)

| Config key | Product name | Amount | Stripe type |
|------------|--------------|--------|-------------|
| `proMonthly` | CTG Pro Feed | **$9/mo** | Recurring monthly |
| `proYearly` | CTG Pro Feed | **$99/yr** | Recurring yearly |
| `mspMonitor` | Blue Team MSP — Monitor | **$1,500/mo** | Recurring monthly |
| `mspDefend` | Blue Team MSP — Defend | **$2,750/mo** | Recurring monthly |
| `mspHarden` | Blue Team MSP — Harden | **$4,500/mo** | Recurring monthly |

Pro webhook provisioning: [PAYMENTS_RECURRING.md](PAYMENTS_RECURRING.md).

---

## Digital (2)

| Config key | Product name | Amount |
|------------|--------------|--------|
| `digital` | Digital Pack | **$15** |
| `codStlPack` | COD STL + KSS print pack | **$19** |

---

## Philadelphia direct ship (8)

Tax + shipping at checkout. Enable Stripe Tax on each link.

| Config key | Product name | Amount |
|------------|--------------|--------|
| `cydStandard` | CYD Field Build — Standard | **$89.99** |
| `cydFieldCustom` | CYD Field Build — Custom | **$189.99** |
| `crackbotBench` | Mr. CrackBot AI Nano — Bench Lab | **$499** |
| `remotePossibility` | Remote Possibility (M5 Cardputer) | **$99.99** |
| `bleBot` | BLE Bot (M5 Cardputer) | **$89.99** |
| `boostFormulaCod` | Boost Formula COD Field Kit | **$99** |
| `coreKit` | CyberThreatGotchi (Cipherhorn core) | **$219** |
| `fieldPack` | Field Pack (core + Cardputer) | **$279** |

---

## Partner drop-ship — tamagotchi & mesh (9)

Metadata: `stripe_key` = config key. Shipping baked into price.

| Config key | Product name | Amount |
|------------|--------------|--------|
| `dsPwnagotchi` | Pwnagotchi wardrive pod | **$169** |
| `dsNetgotchi` | Netgotchi defensive guardian | **$99** |
| `dsNetgotchiPro` | Netgotchi Pro | **$129** |
| `dsNightHunter` | Night Hunter Kali-ready pod | **$189** |
| `dsMeshtasticTBeam` | LilyGO T-Beam Meshtastic kit | **$89** |
| `dsMeshtasticHeltec` | Heltec V3 fully built Meshtastic | **$129** |
| `dsMeshtasticRAK` | RAK4631 Meshtastic starter | **$119** |
| `dsMeshtasticCase` | Meshtastic field case | **$34** |

---

## Partner drop-ship — cyberdecks & SBC (7)

| Config key | Product name | Amount |
|------------|--------------|--------|
| `dsHackberryZero` | Hackberry Pi Zero cyberdeck | **$279** |
| `dsHackberryPi5` | Hackberry Pi 5 cyberdeck | **$449** |
| `dsHackberryCM5` | Hackberry Pi CM5 | **$499** |
| `dsRaspberryPi5` | Raspberry Pi 5 starter kit | **$159** |
| `dsOrangePi5` | Orange Pi 5 Plus kit | **$119** |
| `dsBananaPiR3` | Banana Pi BPI-R3 Mini (ops spare) | **$119** |
| `dsEsp32Cyd` | ESP32 CYD lab bundle | **$49** |

`dsBananaPiR3` is **catalogHidden** — create link for spare-board ops only; not shown on public shop.

---

## Partner drop-ship — Marauder & lab (4)

| Config key | Product name | Amount |
|------------|--------------|--------|
| `dsMarauderGps` | Marauder pocket + GPS v2 | **$219** |
| `dsMarauderBatteryMod` | CYD battery + GPS mod | **$59** |
| `dsMarauderKoko` | Official Marauder Kit | **$89** |
| `dsWiringLab` | Breadboard + jumper wiring kit | **$22** |

---

## Partner drop-ship — RF, tap, Wi-Fi lab (8)

Added in partner catalog expansion (commit `2025951`).

| Config key | Product name | Amount |
|------------|--------------|--------|
| `dsKaliNetHunter` | Kali NetHunter lab phone | **$399** |
| `dsRtlSdrKit` | RTL-SDR Blog V3 starter kit | **$99** |
| `dsNesdrSmart` | NESDR SMArt v5 SDR bundle | **$65** |
| `dsLanTap` | Throwing Star LAN Tap Pro | **$59** |
| `dsThrowingStarKit` | Throwing Star LAN Tap solder kit | **$38** |
| `dsEsp32WifiLab` | ESP32 WiFi lab dev board | **$45** |
| `dsUsbRubberDucky` | USB Rubber Ducky training injector | **$129** |
| `dsHak5WifiPineapple` | WiFi Pineapple Mark VII | **$319** |

---

## After all links are pasted

1. Set `demoMode: false` in `website/js/payments.config.js` (only when every URL is non-empty).
2. Add **Developers → Webhooks** endpoint for Pro keys + drop-ship queue ([STRIPE_FULFILLMENT_METADATA.md](STRIPE_FULFILLMENT_METADATA.md)).
3. Validate:

```powershell
py scripts\check_payments.py
```

```powershell
py scripts\check_shop.py
```

```powershell
py -m pytest tests\test_payments.py -v
```

```powershell
py scripts\sync_website_to_docs.py
```

4. Push to `main` → GitHub Pages deploys shop.

---

## Quick reference — config property names

All keys live under `stripePaymentLinks` in `website/js/payments.config.js`:

```
digital, proMonthly, proYearly, mspMonitor, mspDefend, mspHarden,
coreKit, fieldPack, cydStandard, cydFieldCustom, crackbotBench,
remotePossibility, bleBot, boostFormulaCod, codStlPack,
dsPwnagotchi, dsNetgotchi, dsNetgotchiPro, dsNightHunter,
dsMeshtasticTBeam, dsMeshtasticHeltec, dsMeshtasticRAK, dsMeshtasticCase,
dsHackberryZero, dsHackberryPi5, dsHackberryCM5, dsMarauderGps,
dsMarauderBatteryMod, dsMarauderKoko, dsRaspberryPi5, dsOrangePi5,
dsBananaPiR3, dsEsp32Cyd, dsWiringLab, dsKaliNetHunter, dsRtlSdrKit,
dsNesdrSmart, dsLanTap, dsThrowingStarKit, dsEsp32WifiLab,
dsUsbRubberDucky, dsHak5WifiPineapple
```

**Never** commit Stripe secret keys — Payment Link URLs and Customer Portal URLs are publishable.

---

*Hacker Planet LLC · Philadelphia, PA · Salvador Data*
