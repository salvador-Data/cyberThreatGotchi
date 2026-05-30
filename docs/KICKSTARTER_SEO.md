# Kickstarter SEO — Hacker Planet LLC / CyberThreatGotchi

**Author:** Andy Kowal · Philadelphia, PA  
**Website preview:** [hackerplanet.dev/kickstarter.html](https://hackerplanet.dev/kickstarter.html)  
**Config (publishable):** `website/js/kickstarter.config.js` — key `kickstarterProjectUrl`  
**Regenerate tags:** `py -3 scripts/sync_seo.py` then `py -3 scripts/sync_website_to_docs.py`

Payment for campaign tiers happens **only on kickstarter.com**. hackerplanet.dev uses UTM-tagged outbound links and never collects card data for Kickstarter pledges.

---

## External site (hackerplanet.dev)

| Item | Location / action |
|------|-------------------|
| Campaign URL | `kickstarterProjectUrl` in `website/js/kickstarter.config.js` |
| UTM defaults | `utm_source=hackerplanet`, `utm_medium=site`, `utm_campaign=cta` (+ `utm_content` per SKU/CTA) |
| Shop redirect | `website/js/kickstarter.js` → `HPL_KICKSTARTER_renderCheckout` when URL is **live** (slug ≠ placeholder) |
| SEO metadata | `website/seo/site.json` → `kickstarter.html` block |
| JSON-LD | Organization, LocalBusiness, Breadcrumb, WebPage, FAQPage, Product (AggregateOffer → KS URL) |
| Sitemap | `website/sitemap.xml` — `https://hackerplanet.dev/kickstarter.html` priority 0.9 |
| Internal links | Nav/footer on index, shop, ecosystem; sections on `cyberthreatgotchi.html`, `about.html`, `github.html` |

**Go-live signal:** When Kickstarter assigns a real project slug, replace `kickstarterProjectUrl`. While the URL still contains `hackerplanet/cyberthreatgotchi-edge-ips-tamagotchi`, the site stays in **preview** mode (notify-me mailto, no shop Stripe override).

After URL change:

1. `py -3 scripts/sync_seo.py`
2. `py -3 scripts/sync_website_to_docs.py`
3. `py -3 -m pytest tests/test_website.py tests/test_seo.py -v -k kickstarter`
4. Deploy `docs/web/` to hackerplanet.dev (Cloudflare Pages / your pipeline)
5. Submit updated sitemap in Google Search Console + Bing Webmaster Tools

---

## Kickstarter platform (kickstarter.com editor)

### Project identity

| Field | Guidance |
|-------|----------|
| **Title** | 60 characters max — CyberThreatGotchi: Edge IPS Tamagotchi (or approved shorter variant) |
| **Subtitle** | Real threats in. Mood out. Philadelphia-built open defense hardware. |
| **Category** | Technology → Hardware |
| **Location** | Philadelphia, PA |
| **Tags** | cybersecurity, homelab, IPS, Banana Pi, open source, blue team, tamagotchi |

### Story structure (above the fold)

1. **Hero video** (60–90s): problem → Cipherhorn demo → authorized-use framing  
2. **Three bullets:** edge IPS, e-ink mood, SQLite audit chain  
3. **Reward grid** — mirror `website/kickstarter.html` tiers ($149 / $219 / $279 / …)  
4. **Trust:** DevSecOps, no PAN on external site, partner fulfillment disclosure  
5. **Risks & challenges** — supply chain, assembly capacity, Pro feed delivery  
6. **Team** — Hacker Planet LLC, GitHub `salvador-Data`, Philadelphia lab  

### Media checklist

- [ ] Hero video uploaded (caption file for accessibility)  
- [ ] Tier images per `docs/kickstarter/KICKSTARTER_VISUAL_BRIEF.md`  
- [ ] GIF or still of e-ink mood + block event  
- [ ] Photo of BPI-R3 Mini kit (use `images/products/direct-core-kit.jpg` style)  

### Rewards & pricing

- Align amounts with `docs/kickstarter/KICKSTARTER_REWARDS_TABLE.md` and dashboard paste pack  
- Limit Early Bird quantity in Kickstarter editor (50 units)  
- Digital / add-on tiers: clear delivery method (GitHub release, email, or BackerKit later)  

### Cross-linking

- **Project URL** → paste into `kickstarterProjectUrl` after approval  
- **Story links:** hackerplanet.dev, GitHub repo, `KICKSTARTER_CAMPAIGN.md` (public draft)  
- **Social launch:** `docs/kickstarter/KICKSTARTER_SOCIAL_LAUNCH.md`  
- **Never embed Stripe** or PayPal checkout on Kickstarter story for core hardware tiers — pledges stay on kickstarter.com

### Discovery on Kickstarter

- Use all 5 tag slots with high-intent hardware/security terms  
- Pin a backer-only update plan for Week 1–4 (`docs/KICKSTARTER_LAUNCH_PLAN.md`)  
- Enable **Project We Love** prep: complete profile, shipping plan, environmental questions  

### Post-launch SEO (web + social)

| Channel | UTM example |
|---------|-------------|
| Reddit `u/SalvadorData` | `utm_campaign=reddit_launch` |
| GitHub README | `utm_campaign=github_readme` |
| Email list | `utm_campaign=email_launch` |
| Shop banner | `utm_campaign=shop_banner` (wired in `kickstarter.js`) |

---

## Related docs

- [KICKSTARTER_LAUNCH_PLAN.md](KICKSTARTER_LAUNCH_PLAN.md)  
- [kickstarter/KICKSTARTER_CREATE_ON_KICKSTARTER_COM.md](kickstarter/KICKSTARTER_CREATE_ON_KICKSTARTER_COM.md)  
- [kickstarter/KICKSTARTER_DASHBOARD_PASTE.md](kickstarter/KICKSTARTER_DASHBOARD_PASTE.md)  
- [SEO.md](SEO.md) — general site SEO pipeline  

*Defensive / authorized-use framing only.*
