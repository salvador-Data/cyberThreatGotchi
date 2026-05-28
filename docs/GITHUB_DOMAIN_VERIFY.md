# GitHub domain verification — hackerplanet.dev

Salvador Data runbook for the **“There are no verified domains”** message on GitHub.com during SEO / go-live. This is **not** the same as Google Search Console (GSC) verification.

| ID | Value |
|----|-------|
| GitHub user | `salvador-Data` |
| Repo | `salvador-Data/cyberThreatGotchi` |
| Domain | `hackerplanet.dev` |
| Cloudflare zone | `c81e69edbf957423a22392798309fc35` |
| DNS dashboard | [Cloudflare DNS records](https://dash.cloudflare.com/a819200afa7f246ea8bdb770f634ab84/hackerplanet.dev/dns/records) |

---

## Root cause (three different “verify domain” flows)

| Where you see it | What it is | Blocks site / GSC? |
|------------------|------------|-------------------|
| **Profile → Settings → Pages → Verified domains** — *“There are no verified domains”* | Optional **account-level** anti-takeover check. Requires TXT `_github-pages-challenge-salvador-Data`. | **No** — informational until you add the TXT |
| **Repo → Settings → Pages → Custom domain** — DNS check + HTTPS | **Repo-level** hosting. Needs A/CNAME to GitHub (`185.199.x.x`, `salvador-Data.github.io`). | Site won’t serve on custom domain until DNS is correct |
| **Google Search Console** — domain property | **Search indexing**. Needs TXT `@` with `google-site-verification=…` | GSC won’t verify until that TXT exists |

**Current repo state (2026-05-28):** Custom domain `hackerplanet.dev` is set, HTTPS cert is **approved**, `https_enforced=true`, site returns **HTTP 200**. GSC TXT is already in public DNS. The GitHub **Verified domains** list is still empty because `_github-pages-challenge-salvador-Data` TXT was never added — that is what triggers the banner I saw.

**Do not confuse:** GSC verification does **not** populate GitHub Verified domains, and vice versa. Two TXT records on `@` (SPF + GSC) already coexist; GitHub’s challenge uses a **subdomain** TXT, not `@`.

See also: [PAGES_VERIFIED_DOMAINS_FAQ.md](PAGES_VERIFIED_DOMAINS_FAQ.md), [SEO_SALVADOR_DO_NOW.md](SEO_SALVADOR_DO_NOW.md), [CLOUDFLARE_SETUP.md](CLOUDFLARE_SETUP.md).

---

## My steps — in order

### Step 0 — Confirm repo custom domain (already done)

1. Open [repo Settings → Pages](https://github.com/salvador-Data/cyberThreatGotchi/settings/pages).
2. **Custom domain** should show **`hackerplanet.dev`** with DNS check ✓.
3. **Enforce HTTPS** should be on.

Quick check from repo root:

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
& "C:\Program Files\GitHub CLI\gh.exe" api repos/salvador-Data/cyberThreatGotchi/pages
```

Expect `"cname":"hackerplanet.dev"`, `"https_enforced":true`, `"https_certificate":{"state":"approved"}`.

---

### Step 1 — GitHub Pages DNS (grey cloud)

GitHub Pages needs these records **DNS only** (grey cloud ☁️ off). Orange cloud (proxied) can break DNS checks and cert issuance; keep grey until GitHub shows verified + HTTPS.

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| A | `@` | `185.199.108.153` | **DNS only** (grey) |
| A | `@` | `185.199.109.153` | DNS only |
| A | `@` | `185.199.110.153` | DNS only |
| A | `@` | `185.199.111.153` | DNS only |
| CNAME | `www` | `salvador-Data.github.io` | DNS only |

**Fastest import:** [DNS records](https://dash.cloudflare.com/a819200afa7f246ea8bdb770f634ab84/hackerplanet.dev/dns/records) → **Import and Export** → **Import** → upload [`scripts/cloudflare/dns-github-pages.bind`](../scripts/cloudflare/dns-github-pages.bind) → grey-cloud every A/CNAME.

**Or API** (after scoped token):

```powershell
$env:CF_API_TOKEN = "paste_token_here"
```

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\.venv\Scripts\python scripts\cloudflare_apply_dns.py
```

Verify apex resolves to GitHub (not Cloudflare proxy IPs):

```powershell
nslookup hackerplanet.dev
```

Expect four addresses in `185.199.108–111.153` range when grey-cloud is correct.

---

### Step 2 — GitHub **Verified domains** (fixes “no verified domain” banner)

> **Profile settings, not repo settings.** Click your avatar → **Settings** → **Pages** → **Verified domains**.

1. Open [Profile → Settings → Pages](https://github.com/settings/pages).
2. Under **Verified domains**, click **Add a domain**.
3. Enter **`hackerplanet.dev`** → **Add domain**.
4. GitHub shows **Add a DNS TXT record** with:
   - **Host / name:** `_github-pages-challenge-salvador-Data` (username is case-sensitive on GitHub)
   - **Value:** unique token GitHub generates (copy exactly — yours differs from anyone else’s)
5. In [Cloudflare DNS](https://dash.cloudflare.com/a819200afa7f246ea8bdb770f634ab84/hackerplanet.dev/dns/records) → **Add record**:
   - **Type:** `TXT`
   - **Name:** `_github-pages-challenge-salvador-Data`
   - **Content:** paste the exact value from GitHub
   - **Proxy status:** DNS only (TXT is never proxied)
   - **TTL:** Auto → **Save**
6. Wait 1–5 minutes (up to 24h globally). Confirm TXT exists:

```powershell
nslookup -type=TXT _github-pages-challenge-salvador-Data.hackerplanet.dev
```

7. Return to [Profile → Settings → Pages](https://github.com/settings/pages) → **Verify** (or **Continue verifying**).
8. **Keep the TXT record permanently** — removing it can un-verify the domain.

After success, `hackerplanet.dev` appears under **Verified domains** and the repo Pages banner clears.

---

### Step 3 — Google Search Console (separate TXT on `@`)

GSC does **not** use `_github-pages-challenge`. It uses apex TXT:

| Type | Name | Content | Purpose |
|------|------|---------|---------|
| TXT | `@` | `google-site-verification=FNXHyHmm4-YkSzY0Ms27yme1XygbyfSoaRVM46Hb7o8` | GSC domain property *(already in DNS as of 2026-05-28)* |
| TXT | `@` | `v=spf1 include:_spf.mx.cloudflare.net ~all` | Email SPF *(coexists with GSC TXT)* |

If GSC shows a **different** verification string, use the value GSC displays — not a placeholder.

**Manual:** [GSC](https://search.google.com/search-console) → Add property → **Domain** → `hackerplanet.dev` → add TXT on `@` in Cloudflare → **Verify**.

**API apply** (optional):

```powershell
$env:CF_API_TOKEN = "paste_token_here"
```

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
py scripts/seo_verification_dns.py --google-txt "google-site-verification=PASTE_FROM_GSC"
```

Confirm both apex TXT records:

```powershell
nslookup -type=TXT hackerplanet.dev
```

Then in GSC: submit sitemap `https://hackerplanet.dev/sitemap.xml`. Full SEO flow: [SEO_SALVADOR_DO_NOW.md](SEO_SALVADOR_DO_NOW.md).

---

## Complete Cloudflare DNS record map

All records that may coexist on `hackerplanet.dev`:

| Type | Name | Content | Proxy | Required for |
|------|------|---------|-------|--------------|
| A ×4 | `@` | `185.199.108.153` … `185.199.111.153` | Grey | GitHub Pages apex |
| CNAME | `www` | `salvador-Data.github.io` | Grey | GitHub Pages www |
| TXT | `_github-pages-challenge-salvador-Data` | *(from GitHub Profile → Pages)* | — | GitHub Verified domains |
| TXT | `@` | `google-site-verification=…` | — | Google Search Console |
| TXT | `@` | `v=spf1 include:_spf.mx.cloudflare.net ~all` | — | Email routing |
| TXT | `_dmarc` | `v=DMARC1; p=none; rua=mailto:salvadorData@proton.me` | — | Email (optional) |
| MX ×3 | `@` | `route1/2/3.mx.cloudflare.net` | — | Email routing |

**Multiple TXT on `@`:** Cloudflare stores each as a separate TXT record with the same name. SPF + GSC + future records can all live on `@` without conflict.

**GitHub challenge vs GSC:** Different hostnames — `_github-pages-challenge-salvador-Data` (subdomain) vs `@` (apex). Add both if you want GitHub verified-domain badge **and** GSC indexing.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| “No verified domains” on repo Pages | Account TXT missing | Step 2 — Profile → Settings → Pages |
| GSC verify fails | Wrong TXT or not propagated | Match exact GSC string on `@`; wait 5 min |
| GitHub DNS check fails | Orange cloud or missing A records | Step 1 — four A records, grey cloud |
| `ERR_CERT_COMMON_NAME_INVALID` | Cert not issued yet | Grey cloud, wait 24h, re-run `github_pages_https.py` |
| Confused Profile vs repo Pages | Wrong settings page | Custom domain = **repo** Settings; Verified domains = **Profile** Settings |

Enable HTTPS after DNS verifies:

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\.venv\Scripts\python scripts\github_pages_https.py
```

Full go-live checklist: [GO_LIVE_NOW.md](GO_LIVE_NOW.md).

---

*Hacker Planet LLC · Philadelphia, PA · Authorized use only*
