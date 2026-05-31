# SEO: get Hacker Planet on top â€” honest playbook

**Hacker Planet LLC Â· https://hackerplanet.dev**

---

## Why you're NOT on top today

**Direct answer:** Google and Bing have **not indexed** `hackerplanet.dev` yet. When `site:hackerplanet.dev` returns zero results, no amount of title-tag tuning will make you appear â€” the site literally does not exist in their index.

Secondary factors (after indexing):

| Factor | Status | Impact |
|--------|--------|--------|
| Domain not verified in GSC/Bing | **Blocker** | Site invisible in search |
| New domain, zero backlinks | High | Brand queries lag 2â€“8 weeks |
| Competing "hacker planet" entities | Medium | Media, games, other labs share the name |
| Competitive keywords (`cybersecurity philadelphia`) | High | 3â€“6+ months vs established firms |
| No Google Business Profile yet | Medium | Local pack won't show Hacker Planet |

**I cannot guarantee #1.** I can implement every legitimate on-site lever and document the exact steps that unlock visibility **this week**.

---

## Honest timeline

| Phase | When | What you'll see |
|-------|------|-----------------|
| **Indexing unblock** | Week 1 | `site:hackerplanet.dev` returns pages |
| **Brand queries** | Weeks 2â€“8 | `hacker planet`, `hacker planet llc`, `hackerplanet.dev` rank |
| **Local long-tail** | Months 2â€“4 | `hacker planet philadelphia`, `ethical hacking lab philadelphia` |
| **Competitive terms** | Months 3â€“6+ | `cybersecurity philadelphia` â€” needs content + backlinks |

---

## My 3 things THIS WEEK (mandatory)

These three actions unlock **all major search engines** (Google, Bing, DuckDuckGo via Bing, Yahoo, Ecosia, Apple crawl, Brave):

### 1. Verify Google Search Console (DNS TXT)

Go to the repo root:

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

Run the all-engines go-live script (opens GSC/Bing dashboards):

```powershell
.\scripts\seo_all_engines_go_live.ps1
```

Or manually: [SEO_INDEXING_NOW.md](./SEO_INDEXING_NOW.md) Step 1.

### 2. Verify Bing Webmaster Tools (DNS CNAME)

Same script â€” Step 3. Bing verification also feeds DuckDuckGo web results and Yahoo.

### 3. Submit sitemap + request indexing

- GSC â†’ Sitemaps â†’ `sitemap.xml`
- Bing â†’ Sitemaps â†’ `https://hackerplanet.dev/sitemap.xml`
- GSC URL Inspection â†’ request indexing for `/`, `/hacker-planet.html`, `/cybersecurity-philadelphia.html`

Go to the repo root:

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

Ping IndexNow after sitemap submission:

```powershell
py scripts/ping_indexnow.py
```

**Without steps 1â€“3, the site will not appear in search at all.**

---

## What we shipped (on-site levers)

### Brand SERP signals

| Lever | Implementation |
|-------|----------------|
| Title pattern | `Hacker Planet \| Official Site â€” â€¦` on every page |
| H1 + first paragraph | Exact "Hacker Planet" on homepage and brand page |
| Organization + WebSite JSON-LD | `name: Hacker Planet`, `url: https://hackerplanet.dev/` |
| Brand page | `/hacker-planet.html` in sitemap (priority 0.98) |
| Internal links | All pages footer â†’ "Hacker Planet" â†’ home |
| og:site_name | `Hacker Planet` on every page |
| Competitive differentiation | "Official Site" in titles vs unrelated hacker results |

### Advanced schema

| Schema | Pages |
|--------|-------|
| FAQPage | Homepage (5 FAQs), cybersecurity-philadelphia (4 FAQs) |
| BreadcrumbList | All inner pages via `sync_seo.py` |
| LocalBusiness + Organization | All pages |

### Technical

| Item | Status |
|------|--------|
| robots.txt â€” 9 crawlers + `*` allow | Live |
| sitemap.xml â€” 14 pages | Live |
| IndexNow key + ping script | Live |
| Preconnect Google Fonts | Injected via sync_seo |
| Hero image alt tags | Brand name in alt text |
| Canonical URLs | hackerplanet.dev only |

---

## Off-site signals (Salvador Data â€” can't be coded)

Do these in parallel with GSC/Bing verification:

| Action | Why |
|--------|-----|
| **Google Business Profile** â€” service area Philadelphia, website hackerplanet.dev | Local pack + entity trust â€” [SEO_GOOGLE_BUSINESS_PROFILE.md](./SEO_GOOGLE_BUSINESS_PROFILE.md) |
| **GitHub** â€” set repo website URL to https://hackerplanet.dev, description mentions Hacker Planet LLC Philadelphia | sameAs + backlink |
| **Reddit u/SalvadorData** â€” profile + posts linking hackerplanet.dev (defensive framing) | Brand entity signal |
| **Kickstarter page** â€” link to hackerplanet.dev in project story | Backlink + brand |
| **Bing Places** (if applicable) â€” service-area business | Bing local signals |

NAP consistency everywhere:

```
Hacker Planet LLC
Philadelphia, PA
salvadorData@proton.me
(215) 839-8738
https://hackerplanet.dev
```

---

## Engine coverage summary

| Engine | How Hacker Planet gets indexed |
|--------|-------------------------------|
| Google | GSC verify â†’ sitemap â†’ URL inspection |
| Bing | Bing Webmaster verify â†’ sitemap â†’ IndexNow |
| DuckDuckGo | Bing index + DuckDuckBot crawl |
| Yahoo | Bing index + Slurp crawl |
| Apple | Applebot crawl (no dashboard) |
| Brave | Brave crawler + IndexNow |
| Yandex | robots allow + optional Webmaster |
| Baidu | robots allow + optional Ziyuan |
| Ecosia | Bing index |

---

## Maintenance rhythm

After content changes, run each step separately from repo root.

Go to the repo root:

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

Sync SEO meta, robots, and sitemap:

```powershell
py scripts/sync_seo.py
```

Sync website copy into docs:

```powershell
py scripts/sync_website_to_docs.py
```

Run SEO tests:

```powershell
pytest tests/test_seo.py -v
```

Ping IndexNow for updated URLs:

```powershell
py scripts/ping_indexnow.py
```

Verify live site checks:

```powershell
.\scripts\seo_go_live_checklist.ps1
```

Track in GSC Performance (after verify):

- `hacker planet`
- `hacker planet llc`
- `hacker planet philadelphia`
- `hackerplanet.dev`
- `site:hackerplanet.dev`

---

## Related docs

- [SEO_INDEXING_NOW.md](./SEO_INDEXING_NOW.md) â€” 10-minute all-engines checklist
- [SEO_SEARCH_ENGINES.md](./SEO_SEARCH_ENGINES.md) â€” full multi-engine playbook
- [SEO_GOOGLE_BUSINESS_PROFILE.md](./SEO_GOOGLE_BUSINESS_PROFILE.md) â€” GBP setup

---

*No one can promise top rankings. Verification + sitemap + IndexNow + brand consistency + backlinks are the legitimate path. Start with GSC and Bing today.*
