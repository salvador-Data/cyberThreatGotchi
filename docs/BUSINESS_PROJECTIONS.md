# Hacker Planet LLC — business projections (Year 1–3)

**Author:** Salvador Data · Hacker Planet LLC · Philadelphia, PA  
**Pricing authority:** [PRODUCT_PRICING.md](PRODUCT_PRICING.md) · **Kickstarter:** [kickstarter/KICKSTARTER_CAMPAIGN.md](kickstarter/KICKSTARTER_CAMPAIGN.md)  
**Strategy context:** [CISO_PLAYBOOK.md](CISO_PLAYBOOK.md) · Year 1 operating target **~$84K**

> Internal planning doc. COGS and margin notes stay here — not on public Kickstarter or shop pages.

---

## Assumptions (May 2026)

| Input | Value | Source |
|-------|-------|--------|
| Stripe card fee | 2.9% + $0.30 per charge | Standard US pricing |
| Kickstarter + payment fees | ~10% of pledged gross | Platform + processor |
| Direct-ship US ground | $8.95–$17.95 avg **$12** | [SHIPPING_AND_TAX.md](SHIPPING_AND_TAX.md) |
| Philly assembly labor | ~$35/unit core · ~45 min flash + burn-in | [PRODUCT_PRICING.md](PRODUCT_PRICING.md) |
| BPI-R3 Mini floor | **$160** | Supplier planning floor |
| Pro feed retail | $9/mo · $99/yr | `proMonthly` / `proYearly` |
| MSP install retainer (lite) | **$500–$750/mo** | Single-site CTG deploy + health checks |
| MSP Monitor retainer | **$1,500/mo** | [services.html](../website/services.html) `#blue-team` |
| MSP Defend retainer | **$2,750/mo** | UTM policy + triage |
| Partner SKUs | ~30–40% gross margin | [DROPSHIP_CATALOG.md](DROPSHIP_CATALOG.md) |

**Fulfillment time cost:** Treat founder assembly at **$40/hr** for planning. Core kit ~0.75 hr loaded → **~$30 labor** (partially subsidized at $219 retail; see margin table).

---

## Unit economics (direct-ship)

| SKU | Retail | Parts COGS | Loaded COGS | Stripe fee (1×) | Ship (direct) | Est. net before labor |
|-----|--------|------------|-------------|-----------------|---------------|------------------------|
| `coreKit` | $219 | ~$212 | ~$247 | ~$6.65 | ~$12 | **−$46** |
| `fieldPack` | $279 | ~$283 | ~$330 | ~$8.39 | ~$12 | **−$71** |
| `crackbotBench` | $499 | ~$341 | ~$341 | ~$14.77 | ~$15 | **~$128** |
| `remotePossibility` | $99.99 | ~$71 | ~$71 | ~$3.20 | ~$10 | **~$16** |
| `bleBot` | $89.99 | ~$64 | ~$64 | ~$2.91 | ~$10 | **~$13** |
| Cardputer Duo (2×) | $189.98 | ~$135 | ~$135 | ~$5.81 | ~$12 | **~$37** |
| `cydStandard` | $89.99 | ~$49 | ~$49 | ~$2.91 | ~$10 | **~$28** |
| Pro monthly | $9 | ~$0 | ~$0 | ~$0.56 | — | **~$8.44/mo** |

Loaded COGS for `coreKit` at BPI **$160** floor leaves **~$7** parts margin before fees at $219 — Philadelphia assembly is subsidized until volume or price moves to **$229–249** (see [PRODUCT_PRICING.md](PRODUCT_PRICING.md)).

---

## Year 1 revenue scenarios

### Conservative (~$58,400)

| Stream | Volume | Gross revenue |
|--------|--------|---------------|
| `coreKit` | 55 @ $219 | $12,045 |
| `fieldPack` | 18 @ $279 | $5,022 |
| `crackbotBench` | 2 @ $499 | $998 |
| Partner lab SKUs (avg $119) | 12 | $1,428 |
| CYD / Cardputer standalone | 10 | $900 |
| Pro feed ($9/mo, avg 5 mo) | 60 subs | $2,700 |
| MSP install retainer ($500/mo) | 1 × 6 mo | $3,000 |
| Kickstarter net (partial Y1) | — | $18,000 |
| Workshops / OSINT one-offs | — | $4,307 |
| **Total** | | **~$58,400** |

### Base (~$84,200) — operating target

| Stream | Volume | Gross revenue |
|--------|--------|---------------|
| `coreKit` | 85 @ $219 | $18,615 |
| `fieldPack` | 35 @ $279 | $9,765 |
| `crackbotBench` | 5 @ $499 | $2,495 |
| Partner lab SKUs (avg $129) | 30 | $3,870 |
| CYD / Cardputer / digital | 20 | $2,200 |
| Pro feed ($9/mo, avg 7.5 mo) | 95 subs | $6,412 |
| MSP install retainer ($750/mo) | 2 × 6 mo | $9,000 |
| MSP Monitor ($1,500/mo) | 1 × 5 mo | $7,500 |
| Kickstarter net recognized Y1 | $35K goal, ~63% in Y1 | $22,000 |
| Authorized lab workshops | 2 sessions | $1,500 |
| Scoped services (Red Team lite, OSINT) | — | $343 |
| **Total** | | **~$84,200** |

### Optimistic (~$128,600)

| Stream | Volume | Gross revenue |
|--------|--------|---------------|
| `coreKit` | 140 @ $219 | $30,660 |
| `fieldPack` | 70 @ $279 | $19,530 |
| `crackbotBench` | 12 @ $499 | $5,988 |
| Partner lab SKUs | 55 @ $129 | $7,095 |
| Pro feed | 220 subs × 9 mo avg | $17,820 |
| MSP Monitor | 2 × 8 mo | $24,000 |
| MSP Defend | 1 × 4 mo | $11,000 |
| Kickstarter + post-campaign shop surge | — | $8,500 |
| Workshops + WhiteHat services | — | $4,007 |
| **Total** | | **~$128,600** |

---

## Year 2–3 outlook (base trajectory)

Assumes Kickstarter fulfilled, Pro feed retention **~70%**, one FTE-equivalent assembly capacity in Philadelphia.

| Metric | Year 2 (base) | Year 3 (base) |
|--------|---------------|---------------|
| **Total revenue** | **~$118K** | **~$156K** |
| Hardware (direct + partner) | ~$62K | ~$78K |
| Pro + MSP recurring | ~$44K | ~$62K |
| Services / workshops | ~$12K | ~$16K |
| `coreKit` units | ~130 | ~165 |
| Active Pro subs (Dec) | ~140 | ~210 |
| MSP retainers (avg sites) | 3–4 | 5–7 |
| Gross margin (blended) | ~28% | ~34% |

Year 2 drivers: repeat Field Pack upsells, MSP Pilot conversions from Kickstarter, Philly MSP outreach.  
Year 3 drivers: Defend-tier retainers, partner SKU attach (Meshtastic, Netgotchi), Cardputer ecosystem bundles.

---

## MSP retainer math

| Tier | Monthly | Typical scope | Year 1 sites (base) | Annual if full year |
|------|---------|---------------|---------------------|---------------------|
| **Install lite** | $500 | Remote CTG install, 30-day hypercare, quarterly check-in | 0–1 | $6,000 |
| **Install + feed** | $750 | Lite + Pro keys per site, signature cadence review | 2 | $18,000 |
| **Monitor** | $1,500 | Log review, CTG health, patch advisory, QBR | 1 (from mo 8) | $18,000 |
| **Defend** | $2,750 | Monitor + UTM policy + BH triage | 0 (Year 1) | — |
| **Harden** | $4,500 | Defend + DDoS edge playbooks | 0 (Year 1) | — |

**Path to $84K without full Monitor retainers:** 2× install @ $750 × 6 mo = **$9,000** + 1× Monitor × 5 mo = **$7,500** → **$16,500** recurring/services alongside hardware.

**MSP Pilot Kickstarter tier ($2,499):** 3× Field Pack (~$702 hardware COGS) + 90 min onboarding + 6 mo Pro × 3 sites ($162 value). Internal margin ~53% on service value — use as **channel seed**, not primary Year 1 revenue.

---

## Break-even analysis

### Single-SKU shop break-even (loaded COGS + Stripe + ship)

| SKU | Break-even retail (approx.) | Current retail |
|-----|----------------------------|----------------|
| `coreKit` | **~$268** (loaded COGS + fees + ship) | $219 (subsidized) |
| `fieldPack` | **~$355** | $279 (bundle CAC) |
| `crackbotBench` | **~$395** | $499 ✓ |

### Company monthly fixed costs (planning)

| Item | Monthly |
|------|---------|
| BOM float / tools | $400 |
| Stripe + domain + email | $80 |
| Print farm / consumables | $250 |
| Insurance / misc | $150 |
| **Subtotal fixed** | **~$880/mo** (~$10,560/yr) |

**Contribution margin needed from Pro + CrackBot + services:** ~$10.5K/yr to cover fixed ops if core kits sold at subsidized margin.

### Path to $84K Year 1 (base checklist)

1. **Kickstarter funds** (~$22K net in Y1) — validates BOM buy, caps Early Bird loss leader at 50 units  
2. **85 coreKit + 35 fieldPack** — shop + campaign fulfillment  
3. **95 Pro subs** — attach at 3 mo bundled (Early Bird) + shop checkout  
4. **2 install + 1 Monitor MSP** — Philly outreach + Kickstarter MSP Pilot pipeline  
5. **30 partner SKUs** — Meshtastic, Netgotchi, Pwnagotchi attach; no public “dropship” language  

---

## Kickstarter impact on Year 1

| Scenario | Gross pledged | Net after ~10% fees | Hardware COGS (tier mix) | Est. campaign contribution |
|----------|---------------|---------------------|--------------------------|----------------------------|
| Goal hit ($35K) | $35,000 | ~$31,500 | ~$18,000 | ~$13,500 before labor |
| Stretch $50K | $50,000 | ~$45,000 | ~$24,000 | ~$21,000 |
| Stretch $75K | $75,000 | ~$67,500 | ~$32,000 | ~$35,500 |

Early Bird Core ($149) is a **loss leader** (~−$87/unit internal) — cap 50, convert to Pro feed and Field Pack upsell in survey.

---

## Sensitivity: BPI price spike

If BPI-R3 Mini moves from **$160 → $175** (+$15/unit):

- `coreKit` loaded COGS → **~$262**  
- At $219 retail: **−$43/unit** worsens to **−$58/unit** before fees  
- **Mitigation:** Kickstarter holds price; post-campaign shop test **$229**; MSP bundles include hardware at contract price  

---

## Key metrics to track (monthly)

| KPI | Target Y1 |
|-----|-----------|
| Core kits shipped | 85 |
| Pro active subs | 95 by Dec |
| MSP retainer MRR | $1,500+ by Q4 |
| Pro attach rate (hardware buyers) | ≥35% |
| Partner SKU attach | ≥15% of hardware orders |
| Kickstarter → shop conversion (90 day) | ≥20% |

---

*Last updated: 2026-05-28 · Hacker Planet LLC internal · Salvador Data*
