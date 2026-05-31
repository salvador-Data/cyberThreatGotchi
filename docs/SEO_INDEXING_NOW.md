# SEO indexing now â€” 10-minute all-engines checklist

**Hacker Planet LLC Â· https://hackerplanet.dev Â· Philadelphia, PA**

> **Blocker:** If `site:hackerplanet.dev` returns **zero results**, Google has not indexed the domain yet. Technical SEO on the site is ready â€” **GSC + Bing verification** must happen first.

**Automated helper:** `.\scripts\seo_all_engines_go_live.ps1`  
**Status check:** `.\scripts\seo_go_live_checklist.ps1`  
**Ranking timeline:** [SEO_GET_ON_TOP.md](./SEO_GET_ON_TOP.md)

---

## Before I start (2 min)

- [ ] Run `.\scripts\seo_go_live_checklist.ps1` â€” all checks should PASS
- [ ] Confirm live: https://hackerplanet.dev/robots.txt (all bots allowed)
- [ ] Confirm live: https://hackerplanet.dev/sitemap.xml (14 URLs)
- [ ] Optional: `$env:CF_API_TOKEN` set (Zone DNS Edit for hackerplanet.dev) â€” **never commit this**

Go to the repo root first:

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

Run the automated checklist:

```powershell
.\scripts\seo_go_live_checklist.ps1
```

---

## Engine matrix â€” what I must do

| Engine | Verify? | Sitemap / notify | Notes |
|--------|---------|------------------|-------|
| **Google** | **Yes â€” GSC DNS TXT** | Submit sitemap + URL inspection | Primary index for US search |
| **Bing** | **Yes â€” CNAME or meta** | Same sitemap + IndexNow | Powers Yahoo, much of DDG |
| **DuckDuckGo** | No (via Bing + DuckDuckBot) | robots allow + IndexNow | Optional suggest URL after Bing indexes |
| **Yahoo** | No (via Bing / Slurp) | robots allow | Complete Bing steps |
| **Apple** | No | Applebot allowed in robots | Siri/Spotlight discover via crawl |
| **Brave** | No | Brave in robots + IndexNow | Independent Brave index |
| **Yandex** | Optional | robots allow | webmaster.yandex.com if expanding |
| **Baidu** | Optional | robots allow | ziyuan.baidu.com if China market |
| **Ecosia** | No (Bing-powered) | Same as Bing | â€” |
| **Meta** | No | facebot + OG tags | Social previews only |

---

## Step 1 â€” Google Search Console (~3 min)

1. Open [Google Search Console](https://search.google.com/search-console)
2. Click **Add property**
3. Choose **Domain** (not URL prefix)
4. Enter: `hackerplanet.dev`
5. GSC shows a **TXT record** â€” copy the **full** value:
   ```
   google-site-verification=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
   ```
6. Add DNS at Cloudflare:
   - **Type:** TXT
   - **Name:** `@` (apex)
   - **Content:** paste exact GSC value
   - Or run (with token in env only):

     Go to the repo root:

     ```powershell
     cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
     ```

     Apply GSC TXT via Cloudflare API:

     ```powershell
     py scripts/seo_verification_dns.py --google-txt "google-site-verification=..."
     ```

7. Wait **1â€“5 minutes** â†’ click **Verify** in GSC

### Submit sitemap (GSC)

1. Left sidebar â†’ **Sitemaps**
2. **Add a new sitemap** â†’ enter: `sitemap.xml`
3. Click **Submit**
4. Status should show **Success** within hours

### Request indexing (GSC)

1. Top search bar â†’ **URL inspection**
2. Paste each URL â†’ **Test live URL** â†’ **Request indexing**:
   - `https://hackerplanet.dev/`
   - `https://hackerplanet.dev/hacker-planet.html`
   - `https://hackerplanet.dev/cybersecurity-philadelphia.html`
   - `https://hackerplanet.dev/kickstarter.html`

---

## Step 2 â€” Bing Webmaster Tools (~3 min)

1. Open [Bing Webmaster Tools](https://www.bing.com/webmasters)
2. **Add a site** â†’ `https://hackerplanet.dev`
3. Choose **DNS CNAME** verification
4. Bing shows **Host** (label only, e.g. `abc123def456`) and **Target** (e.g. `verify.bing.com`)
5. Cloudflare DNS:
   - **Type:** CNAME
   - **Name:** host label only (Cloudflare adds `.hackerplanet.dev`)
   - **Target:** exact Bing target
   - **Proxy status:** DNS only (grey cloud)
   - Or API:

     Go to the repo root:

     ```powershell
     cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
     ```

     Apply Bing CNAME via Cloudflare API:

     ```powershell
     py scripts/seo_verification_dns.py --bing-cname abc123def456 verify.bing.com
     ```

6. Wait **1â€“5 minutes** â†’ **Verify** in Bing

**Alternate:** Meta tag â€” set `bingSiteVerification` in `website/seo/site.json`, run `py scripts/sync_seo.py`, deploy.

### Submit sitemap (Bing)

1. **Sitemaps** â†’ **Submit sitemap**
2. Enter: `https://hackerplanet.dev/sitemap.xml`
3. Submit

---

## Step 3 â€” IndexNow ping (~1 min)

Notifies Bing, Yandex, and IndexNow partners of all sitemap URLs.

Go to the repo root:

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

Preview URLs that will be pinged (dry run):

```powershell
py scripts/ping_indexnow.py --dry-run
```

POST to IndexNow (13â€“14 URLs):

```powershell
py scripts/ping_indexnow.py
```

Key file (must return 200): https://hackerplanet.dev/hpl-hackerplanet-indexnow-key.txt

---

## Step 4 â€” DuckDuckGo (~2 min, after Bing verifies)

**Path A (primary):** DDG web results come from **Bing's index**. Complete Step 2 first.

**Path B (direct crawl):** `DuckDuckBot` is allowed in live robots.txt (checklist verifies).

**Optional (after Bing shows pages):**

1. [DuckDuckGo â€” Suggest a site](https://duckduckgo.com/duckduckgo-help-pages/company/suggesting-a-site/)
2. Suggest `https://hackerplanet.dev/`

Test: search `site:hackerplanet.dev` on Bing, then on duckduckgo.com.

---

## Step 5 â€” Yahoo, Apple, Brave, Ecosia (no extra verify)

| Engine | My action |
|--------|-------------|
| **Yahoo** | Nothing beyond Bing â€” Slurp crawler allowed |
| **Apple** | Nothing â€” Applebot allowed; keep pages mobile-friendly |
| **Brave** | Nothing â€” Brave crawler allowed; IndexNow helps |
| **Ecosia** | Nothing â€” uses Bing index |

---

## Step 6 â€” Optional international

| Engine | URL | When |
|--------|-----|------|
| **Yandex** | https://webmaster.yandex.com/ | Russian / CIS traffic |
| **Baidu** | https://ziyuan.baidu.com/ | China market (ICP may be required) |

Both crawlers already allowed in `robots.txt`.

---

## Step 7 â€” Confirm indexing (24â€“72h after verify)

Search these queries on **Google** and **Bing**:

```
site:hackerplanet.dev
hacker planet
hacker planet philadelphia
hacker planet llc
```

**Expected week 1:** `site:hackerplanet.dev` shows homepage + key pages.  
**Expected month 1â€“3:** Brand queries start ranking; competitive terms like `cybersecurity philadelphia` take **3â€“6+ months**.

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

*Salvador Data Â· salvadorData@proton.me Â· Defensive / authorized use only*
