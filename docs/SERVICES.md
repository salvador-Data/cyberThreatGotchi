# Hacker Planet LLC — Services pricing reference (internal)

> **Audience:** Salvador Data / Pat — internal pricing for proposals, not a public contract. Published ranges on `website/services.html` should stay aligned with this doc. I adjust after each closed deal.

## Market research summary (May 2026)

Reviewed packaging from regional MSPs, boutique pentest shops, and OSINT/intelligence vendors. Hacker Planet positions as a **mid-market Philadelphia boutique** — below Big Four / enterprise red-team minimums, above freelancer-only rates, with hardware + open-source differentiation.

### Sources consulted

| Source | URL | What we took |
|--------|-----|----------------|
| EndSight MSSP packaging | https://www.endsight.net/sec/packaging-and-pricing | SMB tiers **$500 / $1,500 / $3,500** per month; annual contracts; a la carte hourly |
| Bellator MDR comparison | https://bellatorcyber.com/blog/mdr-vendor-pricing-comparison | SMB MDR/MSSP **$1,500–$5,000/mo** for ~10–50 endpoints |
| HDWEBSOFT managed security | https://www.hdwebsoft.com/blog/managed-security-service-pricing.html | SMB **$500–$2,500/mo** monitoring; mid-market **$2,500–$12,000** |
| ArticSledge cybersecurity business | https://www.articsledge.com/post/cybersecurity-business | MSSP **$500–$5,000/mo**; vCISO **$3,000–$15,000/mo** |
| PenetrationTestingCost.com | https://penetrationtestingcost.com/ | Boutique **$1,200–$2,500/day**; typical engagement **$5k–$30k** |
| BSG Tech pentest guide | https://bsg.tech/blog/what-can-you-expect-to-pay-for-penetration-testing/ | Boutique **$4,000–$25,000** per engagement |
| Kobalt.io (SMB pentest) | https://kobalt.io/pentest/ | Published from **$3,000** fixed-scope web/API |
| SecureLeap startup pricing | https://www.secureleap.tech/blog/penetration-testing-cost-startup-pricing | US day rate **$1,000–$2,500**; seed scope **$4k–$8k** |
| HADI OSINT packages | https://hadi.ge/osint-data-analytics/ | Snapshot **$2,500**; deep-dive **$7,000**; monitoring **$4,500/mo** |
| Smart Intelligence (EU OSINT) | https://smartintelligence.eu/prices/ | Role rates **€80–€160/hr**; scoping sprint **€250–€600** |
| MackTechs Philadelphia | https://www.macktechs.com/small-business-it-support/ | Local flat fee from **~$195/mo** (1–3 users) — IT-heavy, not full MSSP |
| DT Solutions Philly guide | https://www.dtsolutions.com/blog/managed-it-services-philly-guide-pricing-2025 | Philly per-user **$135–$185/mo** with security bundle |

### Synthesis → Hacker Planet standard pricing

**Blue Team (managed defense + edge)** — monthly retainers, 12-month initial term typical:

| Tier | Monthly | Scope (summary) |
|------|---------|-----------------|
| Monitor | $1,500 | Log review cadence, CTG edge health checks, patch advisory, quarterly review |
| Defend | $2,750 | + UTM policy management, signature/YARA cadence, incident triage (business hours) |
| Harden | $4,500 | + DDoS edge hardening (appliance config, scrubbing vendor liaison, rate limits), on-call escalation |

**Platform add-on (not a retainer):** CTG Pro threat feed **$9/mo** or **$99/yr** — sold via [shop](../website/shop.html); included in Defend/Harden as operator-managed updates where contracted.

**Red Team (authorized testing only)** — fixed-scope projects; SOW + rules of engagement required:

| Engagement | From | Typical duration |
|------------|------|------------------|
| External / perimeter lite | $3,500 | 3–5 tester-days |
| Web + API application | $6,500 | 5–8 tester-days |
| Adversary simulation (limited scope) | $12,000 | 10–15 tester-days; not full enterprise red team |

Day-rate internal planning: **$1,400–$1,800/day** (2-person team), vs market boutique **$1,200–$2,500/day**.

**OSINT (authorized investigations)** — per matter, defensive / due-diligence framing:

| Package | Fee | Deliverable |
|---------|-----|-------------|
| Matter brief | $750 | Narrow scope, public-source summary, 5 business days |
| Due diligence | $1,500 | Entity/person screening, timeline, PDF report |
| Executive pack | $2,500 | Multi-source fusion, exec summary + evidence index |

Rush (+25%), multi-jurisdiction, or litigation support: quote separately (see Smart Intelligence / HADI models).

### Positioning notes

- **Subscriptions alone** under-represent the business; retainers + assessments + OSINT + hardware shop are the full mix.
- Philly boutique: undercut national MSSP per-user stacks ($135–$285/user) for **edge-first** clients (homelab, MSP subaccounts, small offices with UTM).
- Do **not** brand the in-repo AI/agent as “Dr. Eric” on customer-facing pages; external advisor only if mentioned in legal/advisory context.

### Review cadence

Revisit this table when:

- Three+ quotes lost on price
- New compliance driver (HIPAA, SOC 2) changes deliverables
- CTG Pro or kit BOM costs shift materially

_Last updated: 2026-05-28_
