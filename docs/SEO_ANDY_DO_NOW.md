# SEO - Andy do now (hackerplanet.dev)

One page, run in order from repo root (`c:\Users\Owner\Projects\cyberThreatGotchi`). Last automated run: checklist **PASS**, IndexNow **200 (14 URLs)**, `CF_API_TOKEN` **not set** (use manual DNS or set token before step 2).

## 1. Confirm live site (30 sec)

Go to the repo root:

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
```

Run the automated go-live checklist:

```powershell
.\scripts\seo_go_live_checklist.ps1
```

Expect: `PASS - all automated checks OK`.

## 2. Verify Google + Bing (DNS)

**Option A - interactive (opens dashboards; applies DNS only if token set):**

Go to the repo root:

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
```

Optional — set Cloudflare token in this session only (never commit the token):

```powershell
$env:CF_API_TOKEN = "your_cloudflare_edit_zone_dns_token"
```

Run the all-engines go-live script:

```powershell
.\scripts\seo_all_engines_go_live.ps1
```

**Option A2 - no DNS prompts (no CF_API_TOKEN):** runs checklist, opens dashboards, pings IndexNow:

Go to the repo root:

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
```

Skip DNS prompts and open dashboards + IndexNow:

```powershell
.\scripts\seo_all_engines_go_live.ps1 -SkipDns
```

**Option B - manual DNS (no token):** print exact record shapes:

Go to the repo root:

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
```

Print GSC/Bing DNS record shapes:

```powershell
py scripts/seo_verification_dns.py --doc
```

Add GSC **TXT** on `@` and Bing **CNAME** (grey cloud / DNS only) in [Cloudflare DNS](https://dash.cloudflare.com/a819200afa7f246ea8bdb770f634ab84/hackerplanet.dev/dns/records), then click Verify in each dashboard.

**With token - paste values from GSC/Bing after step 2 UI:**

Go to the repo root:

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
```

Apply Google Search Console TXT via Cloudflare API:

```powershell
py scripts/seo_verification_dns.py --google-txt "google-site-verification=PASTE_FROM_GSC"
```

Apply Bing Webmaster CNAME via Cloudflare API:

```powershell
py scripts/seo_verification_dns.py --bing-cname PASTE_HOST_LABEL verify.bing.com
```

## 3. Submit sitemap + request indexing

In [Google Search Console](https://search.google.com/search-console) and [Bing Webmaster](https://www.bing.com/webmasters): property `hackerplanet.dev` → Sitemaps → `https://hackerplanet.dev/sitemap.xml` → URL inspection / Request indexing for `/`, `/hacker-planet.html`, `/cybersecurity-philadelphia.html`.

## 4. Ping IndexNow (all sitemap URLs)

Go to the repo root:

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
```

Ping IndexNow for all sitemap URLs:

```powershell
py scripts/ping_indexnow.py
```

Expect: `IndexNow OK (200)`.

## 5. Check indexing (daily for 1–2 weeks)

Search: `site:hackerplanet.dev` then `hacker planet philadelphia`. Early signal: homepage may appear before inner pages.

---

**Your next PowerShell commands right now:**

Go to the repo root:

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
```

Run go-live without DNS prompts (no token needed):

```powershell
.\scripts\seo_all_engines_go_live.ps1 -SkipDns
```

For API DNS apply, set `$env:CF_API_TOKEN` in a separate step first, then run without `-SkipDns`:

```powershell
.\scripts\seo_all_engines_go_live.ps1
```

Detail: `docs/SEO_INDEXING_NOW.md` · Ranking: `docs/SEO_GET_ON_TOP.md`
