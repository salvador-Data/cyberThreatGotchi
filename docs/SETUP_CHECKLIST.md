# Go-live setup checklist — Hacker Planet LLC

**Andy:** work top-to-bottom. Automated items are already green unless noted.

| Doc | Purpose |
|-----|---------|
| This file | **Today’s go-live steps** (Voice → domain → email → payments) |
| [HOSTING_OPTIONS.md](HOSTING_OPTIONS.md) | DNS table, `CNAME`, brand vs URL |
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
| Site branding **HackerPlanet** everywhere | Browser URL still **`salvador-Data.github.io/cyberThreatGotchi/`** |
| Email placeholder **`hello@hackerplanet.dev`** on contact | Domain **not purchased** — mail does not deliver yet |
| Docs target **`hackerplanet.dev`** | No `website/CNAME` until you register the domain |

Custom domain steps: **Section C** below and [HOSTING_OPTIONS.md](HOSTING_OPTIONS.md).

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

## B. Google Voice — YOUR ACTION (≈15 min)

**Goal:** Free US business line (215 area) that forwards to your cell. **Do not** put your personal cell on the public site.

### Exact clicks

1. Open **[voice.google.com](https://voice.google.com)** in Chrome (signed in as Andy).
2. Choose **For personal use** (free tier).
3. **Get a number** → search area code **`215`** (fallback: **267** or **445** for Philadelphia).
4. Complete number selection and confirm terms.
5. **Settings** (gear) → **Account** → **Linked numbers** → **New linked number** → enter your cell → verify via SMS or call.
6. **Settings → Calls** → confirm **Forward calls to linked numbers** is **ON**.
7. **Settings → Voicemail** → record greeting, e.g.:  
   *“You’ve reached Hacker Planet LLC in Philadelphia. Leave a message and we’ll respond during business hours.”*
8. Install **Google Voice** app on phone (optional) for outbound caller-ID as the business line.

### After you have the number

1. Format for display: `(215) XXX-XXXX` (or your chosen area code).
2. Edit **[website/contact.html](../website/contact.html)** — **Business phone** card:
   - Replace *Call forwarding setup in progress* with  
     `<a href="tel:+1215XXXXXXX">(215) XXX-XXXX</a>` (E.164 in `href`, no spaces).
   - Keep **no street address** on any public HTML (warehouse stays in `shipping.config.js` only).
3. Run sync and push:

```powershell
.\.venv\Scripts\python scripts\sync_website_to_docs.py
git add website/contact.html docs/web/contact.html
git commit -m "Add business phone to contact page"
git push origin main
```

Detail: [CONTACT_AND_PHONE.md](CONTACT_AND_PHONE.md)

---

## C. Domain `hackerplanet.dev` — YOUR ACTION (~$10/yr)

**Agent will not purchase this for you.**

1. **[Cloudflare Registrar](https://domains.cloudflare.com/)** → search **`hackerplanet.dev`** → register (~$10–12/yr, at-cost).
2. In repo, create **`website/CNAME`** (one line, no `https://`):

   ```
   hackerplanet.dev
   ```

3. Push to `main` (Pages workflow deploys `CNAME` to `gh-pages`).
4. **[GitHub → Settings → Pages](https://github.com/salvador-Data/cyberThreatGotchi/settings/pages)** → **Custom domain** → `hackerplanet.dev` → wait for DNS check → **Enforce HTTPS**.
5. **Cloudflare DNS** (DNS only / grey cloud for GitHub Pages):

   | Type | Name | Content |
   |------|------|---------|
   | `A` | `@` | `185.199.108.153` |
   | `A` | `@` | `185.199.109.153` |
   | `A` | `@` | `185.199.110.153` |
   | `A` | `@` | `185.199.111.153` |
   | `CNAME` | `www` | `salvador-Data.github.io` |

   Full table: [HOSTING_OPTIONS.md § Connect custom domain](HOSTING_OPTIONS.md#connect-custom-domain-to-github-pages-after-purchase)

6. Verify: https://hackerplanet.dev/ (old GitHub URL still works).

---

## D. Email `hello@hackerplanet.dev` — after domain (free)

1. Cloudflare dashboard → **Email** → **Email Routing** → enable for `hackerplanet.dev`.
2. Create route: **`hello@hackerplanet.dev`** → forward to your personal Gmail (or Workspace).
3. Send a test from another account; confirm receipt.
4. Update **Stripe** and **PayPal** business profiles with `hello@hackerplanet.dev`.
5. Contact page already shows the address; remove “not registered yet” copy in `contact.html` once mail works.

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

| # | Task | Blocks |
|---|------|--------|
| 1 | **Google Voice** (215 → cell) | Public phone on contact |
| 2 | **Register `hackerplanet.dev`** | Custom URL + email routing |
| 3 | **DNS + `CNAME` + GitHub custom domain** | `https://hackerplanet.dev` |
| 4 | **Cloudflare Email Routing** for `hello@` | Working business email |
| 5 | **Stripe links + `demoMode: false`** | Live checkout |

Website hosting is **already live** on GitHub Pages — steps 1–4 are branding and contact; step 5 is revenue.

---

*Hacker Planet LLC · Philadelphia, PA · Authorized use only*
