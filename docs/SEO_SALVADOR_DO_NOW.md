# SEO — Salvador do now (hackerplanet.dev)

One page, run in order from repo root (`c:\Users\Owner\Projects\cyberThreatGotchi`). Last automated run: checklist **PASS**, IndexNow **200 (14 URLs)**, `CF_API_TOKEN` **not set** (I use manual DNS or set token before step 2).

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

Replace `PASTE_FROM_GSC` with the **exact** TXT value Google Search Console shows (starts with `google-site-verification=`). Do not use the placeholder string.

### Troubleshooting: Cloudflare API error 9109

If the script prints `"code": 9109` (often `Unauthorized to access requested resource` or `Cannot use the access token from location`), the token is rejected before DNS can be created. **Never paste API tokens in chat, commits, or screenshots** — revoke any leaked token at [API tokens](https://dash.cloudflare.com/profile/api-tokens) and create a new one.

**Cloudflare token permission checklist (exact)**

| Setting | Required value |
|--------|----------------|
| Token type | Custom token or **Edit zone DNS** template |
| Permission 1 | **Zone → DNS → Edit** |
| Permission 2 | **Zone → Zone → Read** |
| Zone resources | **Include → Specific zone → `hackerplanet.dev`** (not a different zone) |
| Account | `a819200afa7f246ea8bdb770f634ab84` |
| Zone ID (script default) | `c81e69edbf957423a22392798309fc35` |
| Optional override | `$env:CF_ZONE_ID = "c81e69edbf957423a22392798309fc35"` |
| IP filtering | **None**, or my current public IP must be allowed (9109 often means IP block) |

Create or edit token: [dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens)

**Verify token can read the zone (session only — use real token locally):**

Go to the repo root:

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
```

Set token for this PowerShell session only:

```powershell
$env:CF_API_TOKEN = "your_cloudflare_edit_zone_dns_token"
```

Test zone read (expect `"success": true`):

```powershell
curl.exe -s "https://api.cloudflare.com/client/v4/zones/c81e69edbf957423a22392798309fc35" -H "Authorization: Bearer $env:CF_API_TOKEN" -H "Content-Type: application/json"
```

If verify fails with 9109, fix permissions/zone scope or IP filter, then retry. If verify succeeds, re-run with the real GSC value:

Go to the repo root:

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
```

Apply Google Search Console TXT (replace with value copied from GSC):

```powershell
py scripts/seo_verification_dns.py --google-txt "google-site-verification=YOUR_ACTUAL_GSC_VALUE"
```

**Manual alternative — Google Search Console TXT (no API token)**

Use this when 9109 persists or I prefer the dashboard.

1. Open [Google Search Console](https://search.google.com/search-console) → **Add property** → **Domain** → enter `hackerplanet.dev`.
2. GSC shows a **TXT** record — copy the **full** content, e.g. `google-site-verification=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX` (value differs per property).
3. Open [Cloudflare DNS for hackerplanet.dev](https://dash.cloudflare.com/a819200afa7f246ea8bdb770f634ab84/hackerplanet.dev/dns/records) → **Add record**.
4. Set **Type** = `TXT`, **Name** = `@` (apex; Cloudflare may display as `hackerplanet.dev`), **Content** = paste the exact GSC value, **TTL** = Auto → **Save**.
5. Wait 1–5 minutes for DNS propagation, then in GSC click **Verify**.
6. Optional — confirm TXT exists from repo root:

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
py scripts/seo_verification_dns.py --doc
```

Print-only; compares shapes to what I added in the dashboard.

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

**My next PowerShell commands right now:**

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
