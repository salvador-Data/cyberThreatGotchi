# SEO indexing now — 10-minute all-engines checklist

**Hacker Planet LLC · https://hackerplanet.dev · Philadelphia, PA**

> **Blocker:** If `site:hackerplanet.dev` returns **zero results**, Google has not indexed the domain yet. Technical SEO on the site is ready — **GSC + Bing verification** must happen first.

**Automated helper:** `.\scripts\seo_all_engines_go_live.ps1`  
**Status check:** `.\scripts\seo_go_live_checklist.ps1`  
**Ranking timeline:** [SEO_GET_ON_TOP.md](./SEO_GET_ON_TOP.md)

---

## Before you start (2 min)

- [ ] Run `.\scripts\seo_go_live_checklist.ps1` — all checks should PASS
- [ ] Confirm live: https://hackerplanet.dev/robots.txt (all bots allowed)
- [ ] Confirm live: https://hackerplanet.dev/sitemap.xml (14 URLs)
- [ ] Optional: `$env:CF_API_TOKEN` set (Zone DNS Edit for hackerplanet.dev) — **never commit this**

---

## Engine matrix — what Andy must do

| Engine | Verify? | Sitemap / notify | Notes |
|--------|---------|------------------|-------|
| **Google** | **Yes — GSC DNS TXT** | Submit sitemap + URL inspection | Primary index for US search |
| **Bing** | **Yes — CNAME or meta** | Same sitemap + IndexNow | Powers Yahoo, much of DDG |
| **DuckDuckGo** | No (via Bing + DuckDuckBot) | robots allow + IndexNow | Optional suggest URL after Bing indexes |
| **Yahoo** | No (via Bing / Slurp) | robots allow | Complete Bing steps |
| **Apple** | No | Applebot allowed in robots | Siri/Spotlight discover via crawl |
| **Brave** | No | Brave in robots + IndexNow | Independent Brave index |
| **Yandex** | Optional | robots allow | webmaster.yandex.com if expanding |
| **Baidu** | Optional | robots allow | ziyuan.baidu.com if China market |
| **Ecosia** | No (Bing-powered) | Same as Bing | — |
| **Meta** | No | facebot + OG tags | Social previews only |

---

## Step 1 — Google Search Console (~3 min)

1. Open [Google Search Console](https://search.google.com/search-console)
2. Click **Add property**
3. Choose **Domain** (not URL prefix)
4. Enter: `hackerplanet.dev`
5. GSC shows a **TXT record** — copy the **full** value:
   ```
   google-site-verification=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
   ```
6. Add DNS at Cloudflare:
   - **Type:** TXT
   - **Name:** `@` (apex)
   - **Content:** paste exact GSC value
   - Or run (with token in env only):
     ```powershell
     python scripts/seo_verification_dns.py --google-txt "google-site-verification=..."
     ```
7. Wait **1–5 minutes** → click **Verify** in GSC

### Submit sitemap (GSC)

1. Left sidebar → **Sitemaps**
2. **Add a new sitemap** → enter: `sitemap.xml`
3. Click **Submit**
4. Status should show **Success** within hours

### Request indexing (GSC)

1. Top search bar → **URL inspection**
2. Paste each URL → **Test live URL** → **Request indexing**:
   - `https://hackerplanet.dev/`
   - `https://hackerplanet.dev/hacker-planet.html`
   - `https://hackerplanet.dev/cybersecurity-philadelphia.html`
   - `https://hackerplanet.dev/kickstarter.html`

---

## Step 2 — Bing Webmaster Tools (~3 min)

1. Open [Bing Webmaster Tools](https://www.bing.com/webmasters)
2. **Add a site** → `https://hackerplanet.dev`
3. Choose **DNS CNAME** verification
4. Bing shows **Host** (label only, e.g. `abc123def456`) and **Target** (e.g. `verify.bing.com`)
5. Cloudflare DNS:
   - **Type:** CNAME
   - **Name:** host label only (Cloudflare adds `.hackerplanet.dev`)
   - **Target:** exact Bing target
   - **Proxy status:** DNS only (grey cloud)
   - Or API:
     ```powershell
     python scripts/seo_verification_dns.py --bing-cname abc123def456 verify.bing.com
     ```
6. Wait **1–5 minutes** → **Verify** in Bing

**Alternate:** Meta tag — set `bingSiteVerification` in `website/seo/site.json`, run `python scripts/sync_seo.py`, deploy.

### Submit sitemap (Bing)

1. **Sitemaps** → **Submit sitemap**
2. Enter: `https://hackerplanet.dev/sitemap.xml`
3. Submit

---

## Step 3 — IndexNow ping (~1 min)

Notifies Bing, Yandex, and IndexNow partners of all sitemap URLs:

```powershell
python scripts/ping_indexnow.py --dry-run   # preview
python scripts/ping_indexnow.py             # POST (13–14 URLs)
```

Key file (must return 200): https://hackerplanet.dev/hpl-hackerplanet-indexnow-key.txt

---

## Step 4 — DuckDuckGo (~2 min, after Bing verifies)

**Path A (primary):** DDG web results come from **Bing's index**. Complete Step 2 first.

**Path B (direct crawl):** `DuckDuckBot` is allowed in live robots.txt (checklist verifies).

**Optional (after Bing shows pages):**

1. [DuckDuckGo — Suggest a site](https://duckduckgo.com/duckduckgo-help-pages/company/suggesting-a-site/)
2. Suggest `https://hackerplanet.dev/`

Test: search `site:hackerplanet.dev` on Bing, then on duckduckgo.com.

---

## Step 5 — Yahoo, Apple, Brave, Ecosia (no extra verify)

| Engine | Andy action |
|--------|-------------|
| **Yahoo** | Nothing beyond Bing — Slurp crawler allowed |
| **Apple** | Nothing — Applebot allowed; keep pages mobile-friendly |
| **Brave** | Nothing — Brave crawler allowed; IndexNow helps |
| **Ecosia** | Nothing — uses Bing index |

---

## Step 6 — Optional international

| Engine | URL | When |
|--------|-----|------|
| **Yandex** | https://webmaster.yandex.com/ | Russian / CIS traffic |
| **Baidu** | https://ziyuan.baidu.com/ | China market (ICP may be required) |

Both crawlers already allowed in `robots.txt`.

---

## Step 7 — Confirm indexing (24–72h after verify)

Search these queries on **Google** and **Bing**:

```
site:hackerplanet.dev
hacker planet
hacker planet philadelphia
hacker planet llc
```

**Expected week 1:** `site:hackerplanet.dev` shows homepage + key pages.  
**Expected month 1–3:** Brand queries start ranking; competitive terms like `cybersecurity philadelphia` take **3–6+ months**.

---

## Quick reference URLs

| Resource | URL |
|----------|-----|
| Homepage | https://hackerplanet.dev/ |
| Brand page | https://hackerplanet.dev/hacker-planet.html |
| Philadelphia landing | https://hackerplanet.dev/cybersecurity-philadelphia.html |
| Sitemap | https://hackerplanet.dev/sitemap.xml |
| robots.txt | https://hackerplanet.dev/robots.txt |
| Cloudflare DNS | https://dash.cloudflare.com/a819200afa7f246ea8bdb770f634ab84/hackerplanet.dev/dns/records |

---

*Salvador Data · salvadorData@proton.me · Defensive / authorized use only*
