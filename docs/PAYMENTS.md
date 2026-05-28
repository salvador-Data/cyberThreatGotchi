# Payments setup — Hacker Planet LLC website

Configure checkout on the static GitHub Pages site (`website/` and mirrored `docs/web/`).

**Fulfillment types**

| Type | Checkout | Shipping at Stripe |
|------|----------|-------------------|
| **Direct (Philly)** | CYD builds, CrackBot bench, Cardputer tools, CTG kits | Add shipping line or Stripe Shipping Rates |
| **Partner drop-ship** | Pwnagotchi, Meshtastic, Hackberry, etc. | Shipping baked into price |
| **Digital** | STL pack, repo bundle | None |
| **Subscription** | Pro feed | None |

Use the shop **shipping & tax calculator** for estimates → [SHIPPING_AND_TAX.md](SHIPPING_AND_TAX.md).

---

## Supported payment methods

| Method | Provider | Setup |
|--------|----------|--------|
| Credit & debit cards | Stripe Payment Links | Stripe Dashboard |
| Apple Pay | Stripe (auto on Payment Links) | Settings → Payment methods |
| Google Pay | Stripe | Same |
| PayPal | PayPal JS SDK or PayPal.Me | PayPal Developer |
| Venmo | PayPal SDK or direct link | US PayPal business |
| Cash App | Direct pay URL | $Cashtag |

---

## 1. Stripe Payment Links (required for go-live)

1. Create account at [stripe.com](https://stripe.com).
2. **Enable Stripe Tax** → Settings → Tax → add Pennsylvania + states where registered.
3. Create **Products** matching every `stripeKey` in `website/js/payments.config.js`.

### Direct ship (you fulfill from Philadelphia)

| Key | Product | Price |
|-----|---------|-------|
| `cydStandard` | CYD Field Build — Standard | $79.99 + ship/tax |
| `cydFieldCustom` | CYD Field Build — Custom (GPS, ext radio, battery) | $174.99 + ship/tax |
| `crackbotBench` | Mr. CrackBot AI Nano — Bench Lab (Jetson) | $449 |
| `remotePossibility` | Remote Possibility (M5 Cardputer) | $89.99 |
| `bleBot` | BLE Bot (M5 Cardputer) | $79.99 |
| `boostFormulaCod` | Boost Formula COD kit | $99 |
| `coreKit` | CyberThreatGotchi core | $169 |
| `fieldPack` | Field Pack (core + Cardputer) | $219 |
| `digital` | Digital Pack | $15 |
| `codStlPack` | COD STL + KSS pack | $19 |

### Drop-ship auto-fulfillment metadata

For every partner `ds*` Payment Link, add Dashboard metadata **`stripe_key`** matching the `stripePaymentLinks` property (see [STRIPE_FULFILLMENT_METADATA.md](STRIPE_FULFILLMENT_METADATA.md)).

For direct hardware: enable **Stripe Tax** on the Payment Link and optionally add **Shipping rates** (US zones) matching `shipping.config.js`.

### Partner drop-ship (supplier ships)

| Key | Example | Price |
|-----|---------|-------|
| `dsPwnagotchi` | Pwnagotchi pod | $169 |
| `dsNetgotchi` | Netgotchi | $99 |
| `dsNetgotchiPro` | Netgotchi Pro | $129 |
| `dsNightHunter` | Night Hunter pod | $189 |
| `dsMeshtasticTBeam` | T-Beam kit | $89 |
| `dsMeshtasticHeltec` | Heltec V3 | $79 |
| `dsMeshtasticRAK` | RAK4631 starter | $119 |
| `dsMeshtasticCase` | Meshtastic case | $34 |
| `dsHackberryZero` | Hackberry Pi Zero | $279 |
| `dsHackberryPi5` | Hackberry Pi 5 | $449 |
| `dsHackberryCM5` | Hackberry CM5 | $499 |
| `dsMarauderGps` | Marauder GPS pocket | $219 |
| `dsMarauderBatteryMod` | CYD battery mod | $59 |
| `dsMarauderKoko` | Official Marauder Kit | $89 |
| `dsRaspberryPi5` | Pi 5 kit | $139 |
| `dsOrangePi5` | Orange Pi 5 Plus | $119 |
| `dsBananaPiR3` | BPI-R3 Mini | $109 |
| `dsEsp32Cyd` | CYD lab bundle | $49 |

### Subscriptions

| Key | Product | Price |
|-----|---------|-------|
| `proMonthly` | CTG Pro feed | $9/mo |
| `proYearly` | CTG Pro feed | $99/yr |

4. Paste each link into `website/js/payments.config.js`:

```javascript
window.HPL_PAYMENTS = {
  demoMode: false,
  stripePaymentLinks: {
    cydStandard: "https://buy.stripe.com/...",
    cydFieldCustom: "https://buy.stripe.com/...",
    crackbotBench: "https://buy.stripe.com/...",
    remotePossibility: "https://buy.stripe.com/...",
    bleBot: "https://buy.stripe.com/...",
    // ... every key above
  },
};
```

5. Validate:

```powershell
python scripts/check_payments.py
python scripts/sync_website_to_docs.py
```

**Auto Pro keys:** `python scripts/stripe_provision.py` with `CTG_STRIPE_WEBHOOK_SECRET`.

---

## 2. PayPal (PayPal + Venmo buttons)

[PayPal Developer](https://developer.paypal.com/dashboard/applications) → Client ID → `payments.config.js`:

```javascript
paypal: { clientId: "YOUR_CLIENT_ID", currency: "USD" },
```

Fallback: `paypalMe: { username: "YourPayPalMe" }`

---

## 3. Venmo & Cash App

```javascript
venmo: { username: "YourVenmoUsername" },
cashapp: { cashtag: "HackerPlanetLLC" },
```

---

## 4. Deploy

1. Set `demoMode: false` in `payments.config.js`.
2. `python scripts/sync_website_to_docs.py`
3. Push to `main` — workflow publishes `website/` → `gh-pages`.
4. **One-time:** GitHub → Settings → Pages → branch **`gh-pages`** / root → [GITHUB_PAGES_SETUP.md](GITHUB_PAGES_SETUP.md)

**Shop URL:** https://salvador-Data.github.io/cyberThreatGotchi/shop.html

---

## Security

| OK in config (public) | Never commit |
|----------------------|--------------|
| Stripe Payment Link URLs | Stripe **secret** key |
| PayPal client ID | PayPal **secret** |
| Cashtag, Venmo username | Webhook signing secrets |

---

## Test checklist

- [ ] Every `stripePaymentLinks` key has a URL (`check_payments.py` exit 0)
- [ ] Stripe Tax enabled for PA
- [ ] Direct product: calculator total ≈ Stripe Checkout
- [ ] Apple Pay on Safari/iOS
- [ ] `demoMode: false` hides placeholder text
- [ ] Partner drop-ship order workflow documented in [DROPSHIP_CATALOG.md](DROPSHIP_CATALOG.md)

---

*Hacker Planet LLC · Philadelphia, PA*
