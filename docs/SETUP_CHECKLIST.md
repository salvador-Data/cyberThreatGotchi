# Go-live setup checklist — Hacker Planet LLC

**Andy:** work top-to-bottom. Automated items are already green unless noted.

| Doc | Purpose |
|-----|---------|
| This file | **Today's go-live steps** (Voice → domain → email → payments) |
| [HOSTING_OPTIONS.md](HOSTING_OPTIONS.md) | DNS table, `CNAME`, brand vs URL |
| [CLOUDFLARE_SETUP.md](CLOUDFLARE_SETUP.md) | **Expanded** Cloudflare DNS, TLS, WAF, Email Routing |
| [FIREWALL_BASELINE.md](FIREWALL_BASELINE.md) | BPI-R3 default-deny iptables + CTG IPS interaction |
| [CONTACT_AND_PHONE.md](CONTACT_AND_PHONE.md) | Google Voice detail |
| [SHOP_GO_LIVE.md](SHOP_GO_LIVE.md) | Stripe, tax, fulfillment |
| [GITHUB_PAGES_SETUP.md](GITHUB_PAGES_SETUP.md) | Pages enable / troubleshoot |

**Quick verify (local):**

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
.\scripts\setup_go_live.ps1
```

---

## A. Website — DONE (verify only)

| Item | Status |
|------|--------|
| **Live URL** | https://salvador-Data.github.io/cyberThreatGotchi/ |
| **Shop** | https://salvador-Data.github.io/cyberThreatGotchi/shop.html |
| **Contact** | https://salvador-Data.github.io/cyberThreatGotchi/contact.html |
| **Pages source** | Branch **`gh-pages`** · folder **`/ (root)`** |
| **Deploy workflow** | [.github/workflows/pages.yml](../.github/workflows/pages.yml) → `peaceiris/actions-gh-pages@v4` publishes `website/` |

### Brand vs URL (read once)

| Changed | Unchanged |
|---------|-----------|
| Site branding **HackerPlanet** everywhere | Browser URL still **`salvador-Data.github.io/cyberThreatGotchi/`** until DNS live |
| Email **`hello@hackerplanet.dev`** on contact | Custom domain DNS pending — mail after Email Routing |
| Docs target **`hackerplanet.dev`** | **`website/CNAME`** added — register domain + DNS next |

Custom domain steps: **Section C** below, [CLOUDFLARE_SETUP.md](CLOUDFLARE_SETUP.md), and [HOSTING_OPTIONS.md](HOSTING_OPTIONS.md).

### Automated verification (2026-05-28)

Run anytime:

```powershell
.\.venv\Scripts\python scripts\verify_live_site.py
.\.venv\Scripts\python scripts\check_shop.py
.\.venv\Scripts\python -m pytest tests/test_website.py -v
```

| Check | Result |
|-------|--------|
| HTTP 200 on all public HTML pages | ✅ Verified |
| `check_shop.py` (28 products aligned) | ✅ Pass |
| `tests/test_website.py` | ✅ 27 passed |
| `pages.yml` latest deploy | ✅ Success (GitHub Actions) |

**GitHub CLI (when `gh` is on PATH):**

```powershell
gh run list --workflow=pages.yml -L 3 -R salvador-Data/cyberThreatGotchi
gh api repos/salvador-Data/cyberThreatGotchi/pages
```

**One-time enable** (only if the site 404s): [Settings → Pages](https://github.com/salvador-Data/cyberThreatGotchi/settings/pages) → **`gh-pages`** / **(root)** — or `python scripts/enable_github_pages.py` after `gh auth login`.

---

## B. Google Voice — ✅ DONE (paste number on contact page)

**Goal:** Free US business line (215 area) that forwards to your cell. **Do not** put your personal cell on the public site.

| Item | Status |
|------|--------|
| Voice account + 215 number + forward to cell | ✅ **Completed** (2026-05-28) |
| Public number on contact page | ⏳ **Paste your Voice number** — see below |

### Paste your number (≈2 min)

1. Format for display: `(215) XXX-XXXX` (or your chosen area code).
2. Edit **[website/contact.html](../website/contact.html)** — **Business phone** card:
   - Replace `tel:+1XXXXXXXXXX` and `(215) XXX-XXXX` with your real number  
     (E.164 in `href`, e.g. `<a href="tel:+12155551234">(215) 555-1234</a>` — no spaces in `href`).
   - Keep **no street address** on any public HTML (warehouse stays in `shipping.config.js` only).
3. Run sync and push:

```powershell
.\.venv\Scripts\python scripts\sync_website_to_docs.py
git add website/contact.html docs/web/contact.html
git commit -m "Add business phone to contact page"
git push origin main
```

Original setup clicks (for reference): [CONTACT_AND_PHONE.md](CONTACT_AND_PHONE.md)

---

## C. Domain `hackerplanet.dev` — IN PROGRESS

**Full checklist:** [CLOUDFLARE_SETUP.md](CLOUDFLARE_SETUP.md) (DNS, SSL/TLS, Bot Fight Mode, Email Routing).

| Item | Status |
|------|--------|
| Cloudflare account | ✅ **Created** (2026-05-28) |
| Register `hackerplanet.dev` at Cloudflare Registrar | ⏳ **Your action** (~$10/yr) |
| `website/CNAME` in repo | ✅ **Added** (`hackerplanet.dev`) |
| Cloudflare DNS → GitHub Pages | ⏳ After registration |
| GitHub Pages custom domain | ✅ **`hackerplanet.dev` set** in repo Settings (via API) — enable HTTPS after DNS |

**Agent will not purchase the domain for you.** As of 2026-05-28, `hackerplanet.dev` does not resolve in public DNS — register it in Cloudflare if you have not already.

### Cloudflare Registrar (if not done)

1. Log in → **[Cloudflare Dashboard](https://dash.cloudflare.com/)** → left sidebar **Domain registration** (or **[domains.cloudflare.com](https://domains.cloudflare.com/)**).
2. Search **`hackerplanet.dev`** → **Purchase** (~$10–12/yr, at-cost).
3. Confirm the zone **`hackerplanet.dev`** appears under **Websites**.

### Repo (done — deploys via Pages workflow)

**`website/CNAME`** contains exactly:

```
hackerplanet.dev
```

Push to `main` triggers [.github/workflows/pages.yml](../.github/workflows/pages.yml) → publishes `CNAME` to **`gh-pages`**.

### GitHub Pages custom domain

**Option A — Dashboard (recommended; `gh` not on PATH on this machine):**

1. **[Settings → Pages](https://github.com/salvador-Data/cyberThreatGotchi/settings/pages)**.
2. Under **Custom domain**, enter **`hackerplanet.dev`** → **Save**.
3. Wait for **DNS check** (can take up to 24h after Cloudflare records).
4. Enable **Enforce HTTPS** once the certificate provisions.

**Option B — GitHub CLI** (after `winget install GitHub.cli` and `gh auth login`):

```powershell
gh api -X PUT repos/salvador-Data/cyberThreatGotchi/pages -f cname=hackerplanet.dev
gh api repos/salvador-Data/cyberThreatGotchi/pages
```

### Cloudflare DNS (DNS only / grey cloud for GitHub Pages)

**From your Add Record dialog:** Type **A**, Name **`@`**, paste **one** IPv4 below, click the **orange cloud** so it turns **grey** (“DNS only”), then **Save**. Repeat for all four A records.

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| `A` | `@` | `185.199.108.153` | **DNS only** (grey — not Proxied) |
| `A` | `@` | `185.199.109.153` | DNS only |
| `A` | `@` | `185.199.110.153` | DNS only |
| `A` | `@` | `185.199.111.153` | DNS only |
| `CNAME` | `www` | `salvador-Data.github.io` | DNS only |

**Ignore** GitHub **Profile → Settings → Pages → Verified domains** — that is optional account security, not where you connect the site. Use **[repo Settings → Pages](https://github.com/salvador-Data/cyberThreatGotchi/settings/pages)** instead (custom domain already set to `hackerplanet.dev`).

**Alternative apex:** single `CNAME` `@` → `salvador-Data.github.io` (Cloudflare CNAME flattening) instead of four A records — pick one method, not both.

Full table: [HOSTING_OPTIONS.md § Connect custom domain](HOSTING_OPTIONS.md#connect-custom-domain-to-github-pages-after-purchase)

### SSL/TLS (after GitHub verifies domain)

**Cloudflare → SSL/TLS → Overview** → set encryption mode to **Full (strict)** once GitHub Pages shows the custom domain as verified and HTTPS is available.

### Verify

```powershell
.\.venv\Scripts\python scripts\verify_live_site.py
```

Checks `salvador-Data.github.io` always; checks `https://hackerplanet.dev/` when DNS resolves.

---

## D. Email `hello@hackerplanet.dev` — after domain (free)

1. Cloudflare dashboard → select **`hackerplanet.dev`** → **Email** → **Email Routing** → **Get started** / enable for the zone.
2. **Routing rules** → **Create address** → custom address **`hello`** → destination **your personal Gmail** (or Workspace inbox) → **Save**.
3. Cloudflare adds required **MX** (and optional **TXT** SPF) records automatically — confirm under **DNS → Records**.
4. Send a test from another account; confirm receipt.
5. Update **Stripe** and **PayPal** business profiles with `hello@hackerplanet.dev`.
6. Contact page already shows the address; email copy notes delivery once MX routing is live.

---

## E. Payments — when ready (not blocking site launch)

Shop is live in **demo mode** (`demoMode: true` in `payments.config.js`).

1. [Stripe Dashboard](https://dashboard.stripe.com) → enable **Tax** (PA minimum).
2. Create **Payment Links** for every key in `website/js/payments.config.js`.
3. Paste URLs into config → set **`demoMode: false`**.
4. Validate:

```powershell
.\.venv\Scripts\python scripts\check_payments.py
```

5. Full playbook: [SHOP_GO_LIVE.md](SHOP_GO_LIVE.md) · key table: [PAYMENTS.md](PAYMENTS.md)

---

## F. Ship-from address — internal only (done)

Carrier labels use Philadelphia origin from **`website/js/shipping.config.js`** (`shipFrom` block). That street address must **never** appear on public HTML (enforced by `tests/test_website.py`).

Customer-facing copy: **Philadelphia, PA** only (`origin.publicLabel`).

---

## Manual order summary (Andy)

| # | Task | Status |
|---|------|--------|
| 1 | **Google Voice** (215 → cell) | ✅ Done — paste number on contact |
| 2 | **Cloudflare account** | ✅ Done |
| 3 | **Register `hackerplanet.dev`** | ⏳ ~$10 at Cloudflare Registrar |
| 4 | **DNS + GitHub custom domain** | ⏳ After step 3 (`CNAME` in repo ✅) |
| 5 | **Cloudflare Email Routing** for `hello@` | ⏳ After step 3 |
| 6 | **Stripe links + `demoMode: false`** | When ready (not blocking launch) |

Website hosting is **already live** on GitHub Pages — steps 3–5 are custom domain and contact; step 6 is revenue.

---

*Hacker Planet LLC · Philadelphia, PA · Authorized use only*
