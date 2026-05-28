# Order fulfillment — Hacker Planet LLC

What to do when a shop order comes in (Stripe email / webhook / manual dashboard check).

Config references:

- **Direct products:** `website/js/direct.config.js`
- **Drop-ship products:** `website/js/catalog.config.js` → `supplierUrl`
- **Fulfillment tracker:** `website/js/shipping-tracker.config.js` · `scripts/dropship_order_export.py`
- **Runbook:** [DROPSHIP_FULFILLMENT_RUNBOOK.md](DROPSHIP_FULFILLMENT_RUNBOOK.md)
- **Stripe metadata:** [STRIPE_FULFILLMENT_METADATA.md](STRIPE_FULFILLMENT_METADATA.md)
- **Shipping zones:** `website/js/shipping.config.js`

### Internal — ship-from address (not on public website)

Direct orders ship from the warehouse in `shipping.config.js` → `shipFrom`:

| Field | Value |
|-------|-------|
| Company | Hacker Planet LLC |
| Line 1 | 664 Walker Street |
| City / State / ZIP | Philadelphia, PA 11135 |

Use this on carrier labels and packing slips. The public site and shipping calculator show **Philadelphia, PA** only.

---

## Direct ship — Philadelphia (you pack & ship)

**Products:** CYD Field Build — Standard, Mr. CrackBot AI Nano on CYD, Boost Formula COD, Marauder GPS custom, Cipherhorn Core Kit, Field Pack.

### Workflow

1. **Stripe** → Payment received → note customer ship-to address
2. **Compare** shipping paid vs calculator estimate (`shipping.config.js` zones)
3. **Assemble** unit from lab inventory (flash/test if not pre-built)
4. **Ship** via USPS Priority / UPS Ground — include quick-start card
5. **Email** customer tracking number + authorized-lab reminder for RF tools
6. **Log** order in spreadsheet (date, SKU, COGS, tax collected, tracking)

### Packing checklist (hardware)

- [ ] Device powers on / firmware version recorded
- [ ] Antenna & USB cable included
- [ ] Printed enclosure intact
- [ ] No SD card with customer PII from prior tests

---

## Partner drop-ship (supplier ships)

**Products:** All `ds*` keys — Pwnagotchi, Netgotchi, Meshtastic, Hackberry Pi, partner Marauder, SBC kits.

### Workflow

1. **Stripe** → Payment received
2. **Export packet:** `python scripts/dropship_order_export.py --stripe-key dsMeshtasticHeltec --ship-to "..."`  
   (or full catalog CSV without `--stripe-key`)
3. Open **`supplierUrl`** + marketplace portal from [DROPSHIP_FULFILLMENT_RUNBOOK.md](DROPSHIP_FULFILLMENT_RUNBOOK.md)
4. **Place supplier order manually** — operator card checkout only (no bots)
5. **Use** customer email for supplier tracking if supported
6. **Margin** = retail − supplier cost − Stripe fees
7. **Lead time:** from `shipping-tracker.config.js` (typically 5–14 business days)

### Supplier quick map

| Stripe key | Order from |
|------------|------------|
| `dsNetgotchi` / `dsNetgotchiPro` | OlleAdventures Etsy/Tindie |
| `dsMeshtasticHeltec` | LayerFabUK Etsy (fully built V3) |
| `dsMeshtasticTBeam` | LilyGO store |
| `dsMeshtasticRAK` | RAKwireless store |
| `dsKaliNetHunter` | kalinethunter.com / ViP3R Hunter |
| `dsWiringLab` | SparkFun / Adafruit |
| `dsHackberryZero` / Pi5 / CM5 | ZitaoTech (Discord/Tindie) |
| `dsMarauderGps` | HoneyHoneyTrading Tindie |
| `dsRaspberryPi5` / `dsOrangePi5` / etc. | AliExpress (vetted seller) |

---

## Digital delivery

**Products:** `digital`, `codStlPack`, Pro feed keys (service not physical).

1. Confirm payment
2. Send **download link** (Google Drive, GitHub release, or email attachment)
3. For Pro feed: provision `CTG_PRO_API_KEY` via `scripts/stripe_provision.py` or manual SQLite insert

---

## Tax & records

- Keep Stripe exports for PA sales tax filing
- Taxable amount ≈ product + shipping (direct) or full retail (drop-ship baked-in)
- Consult CPA before collecting tax outside Pennsylvania

---

## Returns & RF tools

- State **authorized lab use only** on WiFi/wardrive products in order confirmation
- Defective direct-ship: replace from lab stock
- Drop-ship defects: coordinate with supplier return policy (often limited on maker goods)

---

*Hacker Planet LLC · Philadelphia, PA*
