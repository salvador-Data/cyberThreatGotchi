# Go live now â€” my checklist

One-page runbook. **Phone and email are already on the site.** Code is deployed on GitHub Pages.

| ID | Value |
|----|-------|
| Cloudflare **Account ID** | `a819200afa7f246ea8bdb770f634ab84` |
| Cloudflare **Zone ID** | `c81e69edbf957423a22392798309fc35` |
| Domain | `hackerplanet.dev` |
| Active email | `salvadorData@proton.me` |
| Active phone | `(215) 839-8738` |
| Brand email (after routing) | `hello@hackerplanet.dev` â†’ Proton |

---

## Run automated checks (PowerShell)

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
.\scripts\go_live_all.ps1
```

---

## Step 1 â€” Activate domain (if zone status is **Pending**)

1. Open [Cloudflare Registrar](https://domains.cloudflare.com/)
2. Search **`hackerplanet.dev`** â†’ purchase (~$10â€“12/yr)
3. Wait until **Websites â†’ hackerplanet.dev** shows status **Active**

---

## Step 2 â€” DNS for GitHub Pages (grey cloud)

**Option A â€” Import (fastest)**

1. [DNS records](https://dash.cloudflare.com/a819200afa7f246ea8bdb770f634ab84/hackerplanet.dev/dns/records)
2. **Import and Export** â†’ **Import**
3. Upload [`scripts/cloudflare/dns-github-pages.bind`](../scripts/cloudflare/dns-github-pages.bind)
4. For **every** A and CNAME for GitHub: click the **orange cloud** â†’ **grey** (DNS only)

**Option B â€” API (after token)**

1. [Create API token](https://dash.cloudflare.com/profile/api-tokens) â†’ **Edit zone DNS**
   - Zone: `hackerplanet.dev`
   - Permissions: **Zone â†’ DNS â†’ Edit**, **Zone â†’ Zone â†’ Read**
2. PowerShell:

```powershell
$env:CF_API_TOKEN = "paste_token_here"
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
.\.venv\Scripts\python scripts\cloudflare_apply_dns.py
```

**Interactive DNS apply (recommended)** â€” run `scripts/apply_dns_interactive.ps1` from the repo root instead of pasting the token on the command line.
Hidden prompt sets `CF_API_TOKEN` for the current PowerShell session only, then runs `cloudflare_apply_dns.py --all`.
Do not paste API tokens in chat; revoke at [API tokens](https://dash.cloudflare.com/profile/api-tokens) if leaked.
On Cloudflare error **9109**, the script prints the [DNS records](https://dash.cloudflare.com/a819200afa7f246ea8bdb770f634ab84/hackerplanet.dev/dns/records) import and grey-cloud steps.


---

## Step 3 â€” GitHub Pages HTTPS

1. [Settings â†’ Pages](https://github.com/salvador-Data/cyberThreatGotchi/settings/pages)
2. Custom domain **`hackerplanet.dev`** (already set)
3. Wait for **DNS check** âœ“
4. Enable **Enforce HTTPS**

Or when DNS is verified:

```powershell
.\.venv\Scripts\python scripts\github_pages_https.py
```

---

## Step 4 â€” Email Routing (fixes spoofing warning)

Cloudflare warns *â€œEmail cannot reach @hackerplanet.dev addressesâ€* until MX, SPF, DKIM, and DMARC exist. Add the records below, then enable routing.

**Option A â€” Import (fastest)**

1. [DNS records](https://dash.cloudflare.com/a819200afa7f246ea8bdb770f634ab84/hackerplanet.dev/dns/records) â†’ **Import and Export** â†’ **Import**
2. Upload [`scripts/cloudflare/dns-email-routing.bind`](../scripts/cloudflare/dns-email-routing.bind)
3. [Email Routing](https://dash.cloudflare.com/a819200afa7f246ea8bdb770f634ab84/hackerplanet.dev/email/routing) â†’ **Get started** (creates DKIM if missing)

**Option B â€” API (after token)**

```powershell
$env:CF_API_TOKEN = "paste_token_here"
.\.venv\Scripts\python scripts\cloudflare_apply_dns.py --email
# or both GitHub Pages + email:
.\.venv\Scripts\python scripts\cloudflare_apply_dns.py --all
```

**DNS records (exact values)**

| Type | Name | Content | Priority |
|------|------|---------|----------|
| MX | `@` | `route1.mx.cloudflare.net` | 82 |
| MX | `@` | `route2.mx.cloudflare.net` | 83 |
| MX | `@` | `route3.mx.cloudflare.net` | 84 |
| TXT | `@` | `v=spf1 include:_spf.mx.cloudflare.net ~all` | â€” |
| TXT | `_dmarc` | `v=DMARC1; p=none; rua=mailto:salvadorData@proton.me` | â€” |
| TXT | `cf2024-1._domainkey` | *(from Email Routing dashboard â€” click **Get started**)* | â€” |

**Enable routing + test**

1. [Email Routing](https://dash.cloudflare.com/a819200afa7f246ea8bdb770f634ab84/hackerplanet.dev/email/routing) â†’ **Get started** (if not done)
2. Custom address: **`hello@hackerplanet.dev`** â†’ destination **`salvadorData@proton.me`**
3. Send a test email to `hello@hackerplanet.dev` from an external mailbox (Gmail, Proton, etc.)

*Only one SPF TXT on `@` â€” if you add Google/Office 365 later, merge into a single record with multiple `include:` statements.*

---

## Step 5 â€” Cloudflare hardening

In zone dashboard:

| Area | Setting |
|------|---------|
| SSL/TLS | **Full (strict)**, **Always Use HTTPS**, min TLS **1.2** |
| Security | Level **Medium**, **Bot Fight Mode** on |
| DNS | **DNSSEC** enable (optional) |

Details: [CLOUDFLARE_SETUP.md](CLOUDFLARE_SETUP.md) Â§5

---

## Step 6 â€” Google Search Console

1. [Add property](https://search.google.com/search-console) â†’ **`hackerplanet.dev`**
2. Verify via DNS TXT (Cloudflare) or HTML file
3. Submit sitemap: **`https://hackerplanet.dev/sitemap.xml`**

SEO config: [SEO.md](SEO.md)

---

## Step 7 â€” Stripe checkout (when ready)

1. [Stripe Dashboard](https://dashboard.stripe.com) â†’ **Tax** (PA)
2. Create **Payment Links** for every key in `website/js/payments.config.js` ([PAYMENTS.md](PAYMENTS.md))
3. Paste links â†’ set **`demoMode: false`**
4. `python scripts/check_payments.py`

---

## Verify

```powershell
.\.venv\Scripts\python scripts\verify_live_site.py
nslookup hackerplanet.dev
```

Expect **HTTP 200** on `https://hackerplanet.dev/` once DNS propagates.

*Hacker Planet LLC Â· Philadelphia, PA*
