# Kickstarter rewards matrix — internal

**Campaign:** CyberThreatGotchi / Hacker Planet LLC  
**Pricing authority:** [PRODUCT_PRICING.md](../PRODUCT_PRICING.md) · BOM: [KICKSTARTER_BOM.md](../KICKSTARTER_BOM.md)  
**Public campaign copy:** [KICKSTARTER_CAMPAIGN.md](KICKSTARTER_CAMPAIGN.md)

> **Margin notes are internal.** Do not publish COGS or margin % on Kickstarter page.

---

## Tier summary

| Tier ID | Backer name | Pledge | Limit | Est. delivery | Ship regions |
|---------|-------------|--------|-------|---------------|--------------|
| `KS-DIG` | Digital Defender | $15 | ∞ | Jul 2026 (+7 days post-campaign) | Worldwide (email) |
| `KS-EB` | Early Bird Core | $149 | 50 | Oct 2026 | US, CA, EU, UK |
| `KS-CORE` | Cipherhorn Core | $219 | 300 | Oct–Nov 2026 | US, CA, EU, UK |
| `KS-FIELD` | Field Pack | $279 | 150 | Nov 2026 | US, CA, EU, UK |
| `KS-CARDUO` | Cardputer Field Duo | $169 | 75 | Nov 2026 | US, CA, EU, UK |
| `KS-PROLAB` | Pro Lab | $529 | 40 | Nov–Dec 2026 | US, CA |
| `KS-BENCH` | Bench Lab (CrackBot) | $499 | 25 | Nov–Dec 2026 | US, CA |
| `KS-MESH` | Meshtastic Relay | $159 | 75 | Dec 2026 – Jan 2027 | US, CA, EU, UK |
| `KS-MSP` | MSP Pilot | $2,499 | 10 | Dec 2026 – Jan 2027 | US only (initial) |

---

## Contents matrix

| Tier | Hardware / digital contents | Retail value (ref) | Stripe / shop key |
|------|----------------------------|--------------------|-------------------|
| Digital Defender | Digital Pack — STLs, sprites, wallpapers | $15 | `digital` |
| Early Bird Core | Core kit + 3 mo Pro ($27 value) | $246 | `coreKit` + promo |
| Cipherhorn Core | Core kit | $219 | `coreKit` |
| Field Pack | Core + Remote Possibility Cardputer (M5 OS) | $318.99 | `fieldPack` |
| Cardputer Field Duo | Remote Possibility + BLE Bot (2× M5 OS Cardputer) | $189.98 | `remotePossibility` + `bleBot` |
| Pro Lab | Field Pack + CYD Standard + 1 yr Pro | $437.98 + $99 | bundle |
| Bench Lab | CrackBot Jetson bench only | $499 | `crackbotBench` |
| Meshtastic Relay | Heltec V3 built + field case + guide PDF | $163 | `dsMeshtasticHeltec` + case |
| MSP Pilot | 3× Field Pack + onboarding + 6 mo Pro ×3 sites | $657 + service | custom |

---

## Margin notes (internal)

Assumes Kickstarter + payment fees ~**10%**, US ground shipping billed separately in survey (~$10 avg direct).

| Tier | Pledge | Est. COGS + ship cost | Est. fees (10%) | Est. net before labor | Margin note |
|------|--------|------------------------|-------------------|----------------------|-------------|
| Digital Defender | $15 | ~$0 | $1.50 | ~$13.50 | ~90% · zero hardware risk |
| Early Bird Core | $149 | ~$212 + $10 ship = $222 | $14.90 | **−$87** | **Loss leader** · cap 50 · Pro upsell |
| Cipherhorn Core | $219 | ~$212 parts + $35 assembly = $247 | $21.90 | **−$49** | BPI $160 floor · Philly assembly subsidized |
| Field Pack | $279 | ~$247 + $71 + $12 = $330 | $27.90 | **−$78** | Bundle discount · marketing CAC |
| Cardputer Field Duo | $169 | ~$64 + $71 + $12 = $147 | $16.90 | **~$5** | ~3% · ecosystem attach · M5 OS on both units |
| Pro Lab | $529 | ~$330 + $59 + $0 Pro = $389 | $52.90 | **~$87** | ~16% · Pro yr + CYD attach |
| Bench Lab | $499 | ~$341 + $15 ship | $49.90 | ~$93 | ~19% · matches retail intent |
| Meshtastic Relay | $159 | ~$90 + $18 + ship incl. $12 | $15.90 | ~$23 | ~14% · partner variance |
| MSP Pilot | $2,499 | ~$702 hardware + $15 ship ×3 + $200 labor | $249.90 | ~$1,332 | ~53% · service value drives margin |

**Labor not fully allocated** in Core/Field at retail-aligned pledges — treat Early Bird + Field as **marketing CAC** if Pro feed converts.

**Break-even rough count (Core-only scenario):** ~160× `$219` units cover $35K goal after fees if loaded COGS+ship ~$257 (excludes fixed tooling).

---

## Shipping regions

| Region | Tiers available | Shipping model |
|--------|-----------------|----------------|
| **US** | All | Direct: zone rates $8.95–$17.95 + weight · Meshtastic: included in pledge |
| **Canada** | All except MSP Pilot | Direct: +$22–$28 est. · Duties backer responsibility |
| **EU / UK** | Digital, Core, Field, Meshtastic | Direct small parcel ~$35–$45 · CE/FCC radio notice for Meshtastic |
| **Rest of world** | Digital only (launch) | Expand if demand + compliance review |

Public label: **Philadelphia, PA** — no warehouse street on backer comms.

---

## Fulfillment routing

| SKU component | Fulfillment path | Lead time |
|---------------|------------------|-----------|
| BPI-R3 + e-ink + enclosure + SD | **Philadelphia direct** | 6–8 weeks post-survey batch |
| Cardputer Remote Possibility | **Philadelphia direct** | +1 week after core batch |
| CYD Standard / Custom | **Philadelphia direct** | 3–5 days handling each |
| CrackBot bench | **Philadelphia direct** | 5–7 days each (assembly queue) |
| Heltec Meshtastic + case | **Partner fulfillment** | 5–14 business days after PO + transit |
| Digital Pack | Email / download link | 7 days post-campaign |
| Pro feed keys | Stripe / manual keygen | With hardware ship or email |

Operator runbook: [ORDER_FULFILLMENT.md](../ORDER_FULFILLMENT.md) · Partner: [DROPSHIP_FULFILLMENT_RUNBOOK.md](../DROPSHIP_FULFILLMENT_RUNBOOK.md).

---

## Add-ons (pledge manager)

| Add-on | Price | COGS (est.) | Notes |
|--------|-------|-------------|-------|
| BLE Bot | $79 | ~$64 | Cardputer flash |
| CYD Custom upgrade | +$95 | ~$60 delta | From Standard CYD in Pro Lab |
| Extra Pro year | $89 | ~$0 | Digital delivery |
| Second Core kit | $159 | ~$151 | No Early Bird pricing |

---

## Risk buffers (built into goal)

| Buffer | $ |
|--------|---|
| RMA / defect (3% of hardware COGS) | ~$1,200 |
| BOM price spike (+10% contingency) | ~$2,800 |
| Kickstarter fees on $35K | ~$3,500 |
| Partner Meshtastic MOQ float | ~$1,500 |

---

*Last updated: 2026-05-28 · Hacker Planet LLC internal*
