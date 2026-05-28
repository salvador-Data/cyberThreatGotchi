# Shipping & sales tax — Hacker Planet LLC

Hacker Planet LLC is based in **Philadelphia, Pennsylvania**. The shop uses **two fulfillment models** with different shipping and tax treatment.

## Fulfillment models

| Model | Products | Shipping | Who ships |
|-------|----------|----------|-----------|
| **Direct** | CYD Field Build — Standard, Mr. CrackBot AI Nano on CYD, CTG kits, custom Marauder/COD builds | Zone rates from Philly | **You (HPL)** |
| **Drop-ship** | Pwnagotchi, Meshtastic, Hackberry Pi, partner Marauder, SBC kits | Included in retail price | **Partner supplier** |
| **Digital** | STL packs, digital bundle, Pro feed | $0 | Email / download |

Config: `website/js/shipping.config.js` · Calculator: `website/js/shipping.js`

### Internal — origin warehouse (not public)

Full ship-from address lives in `shipping.config.js` → `shipFrom` (664 Walker Street, Philadelphia, PA 11135). Customer-facing labels use `origin.publicLabel` (**Philadelphia, PA**).

---

## Direct ship (your builds)

Zone flat rates from Philadelphia (estimates in calculator):

| Zone | States (sample) | Base shipping |
|------|-----------------|---------------|
| Near | PA, NJ, DE, NY | $8.95 |
| Mid | MD–FL, Midwest | $11.95 |
| Central | South, Plains, TX | $14.95 |
| West | CA, OR, WA, etc. | $17.95 |

Weight surcharge: +$2.50 per 8 oz over 1 lb (see product `weightOz` in config).

**Stripe checkout:** Create Payment Links with shipping as a line item, or use **Stripe Shipping Rates** + **Stripe Tax** so live checkout matches the calculator.

---

## Pennsylvania sales tax

Hacker Planet LLC has **physical nexus in Pennsylvania** and must collect PA sales tax on taxable sales to PA customers.

| Destination | Rate (estimate) |
|-------------|-----------------|
| Pennsylvania (general) | **6%** state |
| Philadelphia ZIP (191xx) | **8%** (6% state + 2% Philadelphia local) |
| Other PA counties | 6% + possible local — verify at [PA DOR](https://www.revenue.pa.gov) |

The shop calculator applies these when ship-to state is **PA** and uses ZIP prefix `191` for Philadelphia local tax.

---

## Other states (economic nexus)

Most states have **economic nexus thresholds** (commonly $100,000 revenue or 200 transactions/year in that state). Until you register:

- Calculator shows **$0 tax** outside `nexusStates` in config (default: PA only).
- Add states to `nexusStates` and `stateTaxRates` in `shipping.config.js` as you register.

**Recommended at go-live:** Enable [Stripe Tax](https://stripe.com/tax) on Payment Links — it handles rate lookup, filing exports, and nexus rules automatically.

---

## Drop-ship tax notes

When **you** are the merchant of record and a **partner** drop-ships:

- Tax is still generally due on the **total charge to the customer** (product + any separate shipping you charge).
- Drop-ship items with shipping baked into price: tax the **full retail amount** in nexus states.
- Keep supplier invoices for COGS; consult a PA CPA for multi-state obligations.

---

## Digital goods & subscriptions

- **Digital downloads** (STL pack, repo bundle): taxable in PA like tangible goods in most cases.
- **SaaS / Pro feed subscriptions**: PA treats many digital services as taxable — confirm with your CPA; Stripe Tax handles subscription tax if enabled.

---

## Compliance checklist

1. [ ] Register for **PA sales tax** (if not already) — [PA myPATH](https://mypath.pa.gov)
2. [ ] Enable **Stripe Tax** on all Payment Links
3. [ ] Match calculator zones to **USPS Priority / UPS Ground** rates you actually pay
4. [ ] Add new nexus states to `shipping.config.js` when you register
5. [ ] Keep **authorized lab use** disclaimer on WiFi/RF products

---

## Disclaimer

The on-site calculator provides **estimates only**, not legal or tax advice. Final tax and shipping are determined at checkout. Consult a licensed CPA for Hacker Planet LLC's specific obligations.
