# eBay partner fulfillment runbook

**Hacker Planet LLC** — manual eBay sourcing for curated partner hardware. Customer pays HPL via Stripe → operator buys on eBay → ships to customer. **No** stored marketplace cards, **no** eBay API auto-purchase.

Public language: **partner fulfillment** or **curated hardware** — never “dropship” on the website.

---

## When to use eBay

| SKU | Primary channel | eBay role |
|-----|-----------------|-----------|
| `dsEsp32Cyd` | eBay | CYD boards (ESP32-2432S028R) |
| `dsRaspberryPi5` | eBay / authorized reseller | Pi 5 starter kits when CanaKit backordered |
| `dsPwnagotchi` | eBay | Assembled wardrive pods |
| `dsOrangePi5` | eBay | Orange Pi 5 Plus 8 GB kits |
| `dsBananaPiR3` | eBay / AliExpress | Ops spare board only (`catalogHidden`) |
| `dsMeshtasticHeltec` | Etsy (LayerFabUK) | eBay fallback if Etsy OOS |
| `dsNetgotchi` / Pro | Etsy (OlleAdventures) | eBay fallback search only |

Philadelphia direct-ship SKUs (`coreKit`, `cydStandard`, etc.) are **not** eBay-sourced — assembled in-house.

---

## Andy operator workflow

1. **Stripe webhook / fulfillment queue** — confirm payment and pull customer ship-to (never log full payment payloads).

2. **Export order packet**
   ```powershell
   cd c:\Users\Owner\Projects\cyberThreatGotchi
   ```
   ```powershell
   python scripts/ebay_fulfillment_export.py --stripe-key dsEsp32Cyd --ship-to "Name, 123 Main St, Philadelphia PA 19103" --json
   ```
   Or batch CSV under `data/ebay_exports/`.

3. **Open operator dashboard** — `website/operator/fulfillment.html` (local API + `CTG_OPERATOR_TOKEN`):
   - **Copy ship-to** — paste into eBay checkout.
   - **Search eBay (partner source)** — opens `ebaySearchUrl` for the SKU.
   - **Open supplier listing** — Etsy/Tindie primary when not eBay-only.

4. **Buy on eBay manually**
   - Ship **directly to customer** (not HPL warehouse unless forwarding).
   - Pick **2 GB RAM** BPI-R3 Mini variant when sourcing spare boards.
   - CYD: confirm **ESP32-2432S028R** / ILI9341 resistive touch in listing photos.
   - Pi 5: prefer 8 GB + official cooler bundle; avoid grey-market-only sellers for customer-facing orders.

5. **Record fulfillment**
   - Paste eBay order ID into fulfillment queue (`supplier_order_id`).
   - Set status → **Ordered at supplier** → **Shipped** with carrier tracking URL.
   - Run `python scripts/dropship_order_export.py` for non-eBay partner SKUs as needed.

6. **Customer email** — HPL-branded shipment notice with tracking; include authorized-lab disclaimer for RF tools.

---

## Margin check (before checkout)

Export includes `retail_usd`, `supplier_cost_usd`, and `est_margin_usd`. If eBay listing exceeds retail minus Stripe/fees, **pause** and email customer (substitute SKU or partial refund) — do not eat loss without approval.

---

## Security

- Never commit eBay passwords or payment instruments.
- Never scrape eBay listing images into the shop — link out only.
- Rate-limit operator API; use `CTG_WEB_API_TOKEN` on mutating routes when exposed.

---

## Related docs

- [DROPSHIP_FULFILLMENT_RUNBOOK.md](DROPSHIP_FULFILLMENT_RUNBOOK.md) — Etsy / Tindie / AliExpress
- [MARKET_PRICING_EBAY.md](MARKET_PRICING_EBAY.md) — price sanity table
- [ORDER_FULFILLMENT.md](ORDER_FULFILLMENT.md) — queue + Stripe metadata

---

*Hacker Planet LLC · Philadelphia, PA*
