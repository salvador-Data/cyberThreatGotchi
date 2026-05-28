# Go live now — Andy’s checklist

One-page runbook. **Phone and email are already on the site.** Code is deployed on GitHub Pages.

| ID | Value |
|----|-------|
| Cloudflare **Account ID** | `a819200afa7f246ea8bdb770f634ab84` |
| Cloudflare **Zone ID** | `c81e69edbf957423a22392798309fc35` |
| Domain | `hackerplanet.dev` |
| Active email | `salvadorData@proton.me` |
| Active phone | `(215) 839-8738` |
| Brand email (after routing) | `hello@hackerplanet.dev` → Proton |

---

## Run automated checks (PowerShell)

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
.\scripts\go_live_all.ps1
```

---

## Step 1 — Activate domain (if zone status is **Pending**)

1. Open [Cloudflare Registrar](https://domains.cloudflare.com/)
2. Search **`hackerplanet.dev`** → purchase (~$10–12/yr)
3. Wait until **Websites → hackerplanet.dev** shows status **Active**

---

## Step 2 — DNS for GitHub Pages (grey cloud)

**Option A — Import (fastest)**

1. [DNS records](https://dash.cloudflare.com/a819200afa7f246ea8bdb770f634ab84/hackerplanet.dev/dns/records)
2. **Import and Export** → **Import**
3. Upload [`scripts/cloudflare/dns-github-pages.bind`](../scripts/cloudflare/dns-github-pages.bind)
4. For **every** A and CNAME for GitHub: click the **orange cloud** → **grey** (DNS only)

**Option B — API (after token)**

1. [Create API token](https://dash.cloudflare.com/profile/api-tokens) → **Edit zone DNS**
   - Zone: `hackerplanet.dev`
   - Permissions: **Zone → DNS → Edit**, **Zone → Zone → Read**
2. PowerShell:

```powershell
$env:CF_API_TOKEN = "paste_token_here"
cd C:\Users\Owner\Projects\cyberThreatGotchi
.\.venv\Scripts\python scripts\cloudflare_apply_dns.py
```

---

## Step 3 — GitHub Pages HTTPS

1. [Settings → Pages](https://github.com/salvador-Data/cyberThreatGotchi/settings/pages)
2. Custom domain **`hackerplanet.dev`** (already set)
3. Wait for **DNS check** ✓
4. Enable **Enforce HTTPS**

Or when DNS is verified:

```powershell
.\.venv\Scripts\python scripts\github_pages_https.py
```

---

## Step 4 — Email Routing (free)

1. [Email Routing](https://dash.cloudflare.com/a819200afa7f246ea8bdb770f634ab84/hackerplanet.dev/email/routing)
2. **Get started**
3. Rule: **`hello@hackerplanet.dev`** → **`salvadorData@proton.me`**
4. Send a test email to `hello@hackerplanet.dev`

---

## Step 5 — Cloudflare hardening

In zone dashboard:

| Area | Setting |
|------|---------|
| SSL/TLS | **Full (strict)**, **Always Use HTTPS**, min TLS **1.2** |
| Security | Level **Medium**, **Bot Fight Mode** on |
| DNS | **DNSSEC** enable (optional) |

Details: [CLOUDFLARE_SETUP.md](CLOUDFLARE_SETUP.md) §5

---

## Step 6 — Google Search Console

1. [Add property](https://search.google.com/search-console) → **`hackerplanet.dev`**
2. Verify via DNS TXT (Cloudflare) or HTML file
3. Submit sitemap: **`https://hackerplanet.dev/sitemap.xml`**

SEO config: [SEO.md](SEO.md)

---

## Step 7 — Stripe checkout (when ready)

1. [Stripe Dashboard](https://dashboard.stripe.com) → **Tax** (PA)
2. Create **Payment Links** for every key in `website/js/payments.config.js` ([PAYMENTS.md](PAYMENTS.md))
3. Paste links → set **`demoMode: false`**
4. `python scripts/check_payments.py`

---

## Verify

```powershell
.\.venv\Scripts\python scripts\verify_live_site.py
nslookup hackerplanet.dev
```

Expect **HTTP 200** on `https://hackerplanet.dev/` once DNS propagates.

*Hacker Planet LLC · Philadelphia, PA*
