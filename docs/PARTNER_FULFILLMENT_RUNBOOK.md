# Partner fulfillment runbook (all channels)

**Hacker Planet LLC** â€” manual partner sourcing for curated lab hardware. Customer pays HPL via Stripe â†’ operator buys from supplier/marketplace â†’ ships to customer. **No** stored marketplace cards, **no** API auto-purchase.

Public language: **partner fulfillment** or **curated hardware** â€” never â€œdropshipâ€ on the website.

See also: [MARKET_PRICING_INTERNET.md](MARKET_PRICING_INTERNET.md) Â· [MARKET_PRICING_EBAY.md](MARKET_PRICING_EBAY.md) Â· [DROPSHIP_FULFILLMENT_RUNBOOK.md](DROPSHIP_FULFILLMENT_RUNBOOK.md)

---

## Channels

| Channel | Portal | Typical SKUs |
|---------|--------|--------------|
| **eBay** | [ebay.com/mye/myebay/purchase](https://www.ebay.com/mye/myebay/purchase) | CYD boards, Pi kits, Pwnagotchi, BPI spare, Orange Pi |
| **Amazon** | [amazon.com order history](https://www.amazon.com/gp/your-account/order-history) | RTL-SDR Blog kits, Pi kits (fallback) |
| **AliExpress** | [aliexpress.com orders](https://www.aliexpress.com/p/order/index.html) | CYD, Orange Pi, BPI spare |
| **Etsy** | [etsy.com/your/purchases](https://www.etsy.com/your/purchases) | Meshtastic Heltec, Netgotchi, Pwnagotchi fallback |
| **Tindie** | [tindie.com accounts/orders](https://www.tindie.com/accounts/orders/) | Marauder, Hackberry, Koko kits |
| **Supplier store** | Hak5, SparkFun, Adafruit, NooElec, CanaKit, KaliNetHunter | LAN Tap, Ducky, WiFi Pineapple, wiring, SDR, phones |

Philadelphia direct-ship (`coreKit`, `cydStandard`, etc.) are **not** partner-sourced.

---

## My operator workflow

1. **Confirm Stripe payment** â€” pull ship-to from fulfillment queue (never log full payment payloads).

2. **Export order packet**
   ```powershell
   cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
   ```
   All partner SKUs:
   ```powershell
   python scripts/partner_fulfillment_export.py --stripe-key dsRtlSdrKit --ship-to "Name, 123 Main St, Philadelphia PA 19103" --json
   ```
   eBay-only (legacy path):
   ```powershell
   python scripts/ebay_fulfillment_export.py --stripe-key dsEsp32Cyd --json
   ```
   Filter by channel:
   ```powershell
   python scripts/partner_fulfillment_export.py --channel amazon --json
   ```

3. **Operator dashboard** â€” `website/operator/fulfillment.html`:
   - **Copy ship-to** â†’ paste into checkout
   - **Open supplier listing** â†’ primary URL
   - **Search eBay / Amazon** â†’ fallback search links when primary OOS
   - Save tracking URL + status when shipped

4. **Buy manually** â€” ship **direct to customer** unless forwarding from Philly.

5. **Channel-specific checks**
   - **RTL-SDR / NESDR:** receive-only; authorized spectrum lab scope
   - **LAN Tap:** passive monitoring on owned segments only
   - **USB Rubber Ducky / WiFi Pineapple:** written authorization required; training/engagement scope card in shipment email
   - **CYD:** ESP32-2432S028R resistive touch / ILI9341
   - **BPI-R3 Mini spare:** 2 GB RAM variant; reject grey-market <$100 listings
   - **Flipper / HackRF / O.MG cable:** reference pricing in docs only â€” not HPL catalog SKUs

6. **Margin gate** â€” if supplier listing exceeds retail minus Stripe/fees, pause and contact customer.

---

## Security

- Never commit marketplace passwords or payment instruments.
- Never scrape listing images into the shop â€” link out only.
- Rate-limit operator API; use `CTG_OPERATOR_TOKEN` / `CTG_WEB_API_TOKEN` on mutating routes when exposed.

---

## Related docs

- [ORDER_FULFILLMENT.md](ORDER_FULFILLMENT.md) â€” queue + Stripe metadata
- [EBAY_PARTNER_FULFILLMENT.md](EBAY_PARTNER_FULFILLMENT.md) â€” legacy eBay-focused note (superseded by this runbook)

---

*Hacker Planet LLC Â· Philadelphia, PA Â· Authorized lab use only*
