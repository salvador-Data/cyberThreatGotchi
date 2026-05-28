# Stripe Payment Link metadata — drop-ship fulfillment

Hacker Planet LLC uses **`checkout.session.completed`** to auto-queue partner drop-ship orders.
The CTG web API (`POST /api/fulfillment/webhook`) and `scripts/stripe_fulfillment_import.py` read
**Checkout Session metadata** — not the public `payments.config.js` URL alone.

## Required metadata

| Metadata key | Value | Notes |
|--------------|-------|-------|
| `stripe_key` | Same string as `stripeKey` in `website/js/catalog.config.js` | Must start with `ds` |

Optional: `notes` (operator text copied into the queue order).

Alternate keys accepted by the importer (fallback only): `stripeKey`, `product_key`, `sku`.
Prefer **`stripe_key`** everywhere so Dashboard setup matches this doc.

## Priority SKUs (Meshtastic, lab, SBC)

Set metadata on **each** Stripe Payment Link, then paste the link into
`website/js/payments.config.js` under the matching property name.

| `payments.config.js` key | `stripe_key` metadata value | Product | Typical supplier |
|--------------------------|----------------------------|---------|------------------|
| `dsMeshtasticHeltec` | `dsMeshtasticHeltec` | Heltec V3 fully built Meshtastic | LayerFabUK Etsy |
| `dsMeshtasticTBeam` | `dsMeshtasticTBeam` | LilyGO T-Beam Meshtastic kit | LilyGO store |
| `dsMeshtasticRAK` | `dsMeshtasticRAK` | RAK4631 Meshtastic starter | RAKwireless |
| `dsMeshtasticCase` | `dsMeshtasticCase` | Meshtastic field case | 3D print partner |
| `dsKaliNetHunter` | `dsKaliNetHunter` | Kali NetHunter lab phone | kalinethunter.com / ViP3R Hunter |
| `dsWiringLab` | `dsWiringLab` | Breadboard + jumper wiring kit | SparkFun / Adafruit |
| `dsRaspberryPi5` | `dsRaspberryPi5` | Raspberry Pi 5 starter kit | Authorized Pi reseller |
| `dsHackberryZero` | `dsHackberryZero` | Hackberry Pi Zero cyberdeck | ZitaoTech |
| `dsEsp32Cyd` | `dsEsp32Cyd` | ESP32 CYD lab bundle | AliExpress / lab stock |

All other `ds*` keys in `payments.config.js` use the same pattern:
metadata `stripe_key` equals the config property name (e.g. `dsPwnagotchi` → `stripe_key=dsPwnagotchi`).

## Stripe Dashboard — step by step (Salvador Data)

Do this **once per product** Payment Link (repeat for all nine SKUs above, then other `ds*` links).

1. Sign in to [Stripe Dashboard](https://dashboard.stripe.com) (live mode when go-live).
2. **Product catalog** → open the product (or create it) that matches the shop SKU and price.
3. **Payment links** → **+ New** (or edit an existing link for that product).
4. Under **After payment** (or link settings), enable **Collect customers' shipping addresses**
   so `customer_details` / shipping fields populate the fulfillment queue ship-to line.
5. Expand **Metadata** (sometimes under **Additional options**).
6. Add a row: **Key** `stripe_key` · **Value** exactly as in the table (e.g. `dsMeshtasticHeltec`).
7. Save the Payment Link and copy the URL (`https://buy.stripe.com/...`).
8. Paste into `website/js/payments.config.js` → `stripePaymentLinks.<key>` (same name as metadata value).
9. Run `python scripts/sync_website_to_docs.py` and deploy the site.

### Webhook (auto-queue on payment)

1. **Developers** → **Webhooks** → **Add endpoint**.
2. URL: `https://<your-ctg-host>/api/fulfillment/webhook` (local dev: Stripe CLI forward to `http://127.0.0.1:8765/api/fulfillment/webhook`).
3. Events: **`checkout.session.completed`** (optional: `payment_intent.succeeded` if you attach metadata there too).
4. Copy signing secret → set env `CTG_STRIPE_WEBHOOK_SECRET=whsec_...` on the machine running `python main.py --web`.
5. Set `CTG_OPERATOR_TOKEN` and open `/operator/fulfillment` to work the queue.

See also [DROPSHIP_FULFILLMENT_RUNBOOK.md](DROPSHIP_FULFILLMENT_RUNBOOK.md) and [SECURITY_HARDENING.md](SECURITY_HARDENING.md).

## Verify metadata

```powershell
# Dry-run import (no queue write)
stripe events retrieve evt_xxx --stripe-key sk_test_... | python scripts/stripe_fulfillment_import.py --stdin --dry-run

# Or override if a test session lacks metadata:
python scripts/stripe_fulfillment_import.py sample.json --dry-run --stripe-key dsMeshtasticHeltec
```

Completed sessions without `stripe_key` metadata will **not** queue automatically;
use `--stripe-key` on the CLI or manual POST to `/api/fulfillment/queue`.

---

*Hacker Planet LLC · Philadelphia, PA*
