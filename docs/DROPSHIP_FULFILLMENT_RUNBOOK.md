# Drop-ship fulfillment runbook — Hacker Planet LLC

**Authorized lab / defensive use only.** This workflow deliberately avoids automated card charges on Etsy, AliExpress, or other marketplaces (PCI scope and marketplace ToS).

## Automated flow (v1.3+)

```
Stripe payment → queue ingestion → operator dashboard → supplier link + copy address → manual Pay → mark shipped
```

| Artifact | Purpose |
|----------|---------|
| `website/js/catalog.config.js` | Customer-facing SKUs, retail prices, supplier links |
| `website/js/shipping-tracker.config.js` | Lead times, checklists, channel portals |
| `website/js/shipping-tracker.js` | Tracking URL builder + packet formatter (browser) |
| `website/js/fulfillment-dashboard.js` | Operator dashboard helpers (clipboard, status) |
| `website/operator/fulfillment.html` | Token-gated fulfillment UI (served by CTG web server) |
| `data/fulfillment_queue.json` | Local order queue (gitignored; see `data/fulfillment_queue.example.json`) |
| `core/fulfillment_queue.py` | Queue schema, enrichment, Stripe parsing |
| `scripts/fulfillment_queue.py` | CLI: add / list / update orders |
| `scripts/stripe_fulfillment_import.py` | Import Stripe CLI export or JSON paste |
| `scripts/dropship_order_export.py` | Legacy CSV + text packets (still supported) |

## Operator workflow (~30 seconds per order)

1. **Stripe pays** — customer completes hosted checkout (Payment Link or Checkout Session).
2. **Auto-queue** — Stripe webhook (`POST /api/fulfillment/webhook`) or CLI import adds order to `data/fulfillment_queue.json`.
3. **Open dashboard** — with CTG web server running:
   ```powershell
   $env:CTG_OPERATOR_TOKEN = "long-random-token"
   python main.py --simulation --web
   ```
   Browse to [http://127.0.0.1:8765/operator/fulfillment](http://127.0.0.1:8765/operator/fulfillment), paste token, click **Refresh queue**.
4. **Per order:** click **Open supplier listing** (new tab) → **Copy ship-to** → paste in marketplace checkout → pay manually with business card.
5. **Mark ordered** — set status `ordered`, add supplier order ID in notes if needed.
6. **When tracking exists** — set status `shipped`, paste tracking URL → **Save**.
7. Optional: `CTG_FULFILLMENT_WEBHOOK_URL` posts to Discord/Slack when orders queue or status changes.

## Queue ingestion options

### A — Stripe webhook (recommended when CTG web is running)

Stripe Dashboard → Webhooks → `checkout.session.completed`  
→ `http://your-host:8765/api/fulfillment/webhook`  
Set `CTG_STRIPE_WEBHOOK_SECRET=whsec_...`

Add **metadata** on Payment Links: `stripe_key` = `dsMeshtasticHeltec` (matches `catalog.config.js`). Full SKU table and Dashboard steps: [STRIPE_FULFILLMENT_METADATA.md](STRIPE_FULFILLMENT_METADATA.md).

### B — CLI after Stripe Dashboard copy-paste

```powershell
python scripts/fulfillment_queue.py add --stripe-key dsMeshtasticHeltec --ship-to "Name, Street, City ST ZIP" --email buyer@example.com
```

### C — Stripe CLI / JSON import

```powershell
stripe events retrieve evt_xxx --stripe-key sk_test_... > data/stripe_event.json
python scripts/stripe_fulfillment_import.py data/stripe_event.json
# or pipe: type event.json | python scripts/stripe_fulfillment_import.py --stdin
```

### D — Manual API (automation / scripts)

```powershell
curl -X POST http://127.0.0.1:8765/api/fulfillment/queue `
  -H "Authorization: Bearer $env:CTG_OPERATOR_TOKEN" `
  -H "Content-Type: application/json" `
  -d '{"stripe_key":"dsMeshtasticHeltec","ship_to":"Name, 1 St, Philly PA 19107"}'
```

## Fulfillment statuses

Dashboard uses: `pending` → `ordered` → `shipped` → `delivered` (or `exception`)

Legacy tracker labels in `shipping-tracker.config.js` map to `pending` on import.

## Channel-specific notes

### Etsy (Meshtastic V3 built, cases, Netgotchi)

- Primary Heltec V3 turnkey: [LayerFabUK — THE KNIGHT listing](https://www.etsy.com/listing/1733234765/the-knight-complete-device-heltec-v3)
- Star Seller alternative: [GarthVH shop](https://www.etsy.com/shop/GarthVH)
- Message buyer with LoRa band + case color from Stripe order notes.

### AliExpress (CYD boards, some SBC kits)

- Use **vetted seller** per SKU; confirm controller (ILI9341) and model `ESP32-2432S028R`.
- Community sourcing guide: [ESP32-Cheap-Yellow-Display](https://github.com/witnessmenow/ESP32-Cheap-Yellow-Display)

### Tindie / Elecrow (Hackberry, Marauder)

- Hackberry Pi Zero: [Elecrow Q10 listing](https://www.elecrow.com/hackberrypi-zero-with-q10-keyboard.html)
- Hackberry Pi 5: [Tindie ZitaoTech](https://www.tindie.com/products/zitaotech/hackberrypi5-with-9900-keyboard/)
- Marauder pocket: [HoneyHoneyTrading](https://www.tindie.com/products/honeyhoneytrading/esp32-marauder-pocket-unit-with-gps-v2/)

### Authorized resellers (Pi kits, wiring)

- Raspberry Pi 5 kits: [CanaKit](https://www.canakit.com/raspberry-pi-5.html), [PiShop.us](https://www.pishop.us/)
- Jumper kits: [SparkFun 140pc](https://www.sparkfun.com/jumper-wire-kit-140pcs.html), [Adafruit breadboard bundle](https://www.adafruit.com/product/3314)

### Kali NetHunter lab phones

- Builders (manual quote/stock): [kalinethunter.com](https://kalinethunter.com/products), [nethunterdevices.com](https://nethunterdevices.com/)
- Official install docs (self-build reference): [kali.org NetHunter install](https://www.kali.org/docs/nethunter/installing-nethunter/)
- Confirm **authorized testing** scope in customer email; do not log IMEI in git.

## Notification hook (optional)

Set a Discord or Slack incoming webhook URL (never commit it):

```powershell
$env:CTG_FULFILLMENT_WEBHOOK_URL = "https://discord.com/api/webhooks/..."
```

Triggered on: `fulfillment.queued`, `fulfillment.ordered`, `fulfillment.shipped`, etc. Payload is minimal (order id, SKU, status — no card data).

## What we never do

- Store Etsy/AliExpress passwords in the repository
- Run headless checkout bots or saved-card automation on marketplaces
- Copy supplier product photos or descriptions verbatim on the HPL shop

---

See also: [DROPSHIP_CATALOG.md](DROPSHIP_CATALOG.md) · [ORDER_FULFILLMENT.md](ORDER_FULFILLMENT.md) · [SECURITY_HARDENING.md](SECURITY_HARDENING.md)
