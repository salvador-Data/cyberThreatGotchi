# Hosting & domain — Hacker Planet LLC website

## TL;DR for Andy

| Need | Best choice | Cost |
|------|-------------|------|
| **Host the shop now** | GitHub Pages (already set up) | **$0** |
| **URL without buying a domain** | https://salvador-Data.github.io/cyberThreatGotchi/ | **$0** |
| **Custom name later** (e.g. `hackerplanet.dev`) | Cloudflare Registrar + GitHub Pages custom domain | **~$10–15/yr** |
| **Truly free custom domain** | Not realistic for `.com` — use GitHub URL above | **$0** |

All links: [WEBSITE_LINKS.md](WEBSITE_LINKS.md)

---

## Current live hosting (what we're doing now)

| Item | Detail |
|------|--------|
| **Repository** | [salvador-Data/cyberThreatGotchi](https://github.com/salvador-Data/cyberThreatGotchi) |
| **Source branch** | `main` — static site in `website/` |
| **Deploy workflow** | [.github/workflows/pages.yml](../.github/workflows/pages.yml) on push to `main` (paths: `website/**`, `docs/web/**`, sync script, workflow file) |
| **Deploy action** | [peaceiris/actions-gh-pages@v4](https://github.com/peaceiris/actions-gh-pages) publishes `website/` → **`gh-pages`** branch (root) |
| **Pre-deploy step** | `python scripts/sync_website_to_docs.py` mirrors `website/` → `docs/web/` for repo browsing |
| **Live URL** | **https://salvador-Data.github.io/cyberThreatGotchi/** |
| **GitHub Pages setting** | [Settings → Pages](https://github.com/salvador-Data/cyberThreatGotchi/settings/pages) → branch **`gh-pages`** / **(root)** |

**Published pages:** `index`, `about`, `services`, `shop`, `contact`, `cyberthreatgotchi`, `ecosystem`, `github`, `crackbot` (plus CSS/JS/assets under `website/`).

**Current state:** HackerPlanet branding, Philadelphia HQ copy, pre-launch shop (`demoMode` in payments config), inquiry email placeholder `hello@hackerplanet.dev` (domain not purchased yet).

**Custom domain path:** Register **`hackerplanet.dev`** (~$10–12/yr at Cloudflare Registrar) → add `website/CNAME` → DNS A/CNAME records → **Settings → Pages → Custom domain** → enforce HTTPS. Full steps in [Connect custom domain](#connect-custom-domain-to-github-pages-after-purchase) below.

Contact & business phone: [CONTACT_AND_PHONE.md](CONTACT_AND_PHONE.md)

---

### Brand vs URL (common confusion)

We **rebranded the site to HackerPlanet** (logo, page titles, copy). That does **not** change the browser URL automatically.

| What changed | What did not |
|--------------|--------------|
| Site says **HackerPlanet** everywhere | Address bar still **`salvador-Data.github.io/cyberThreatGotchi/`** |
| Contact email placeholder **`hello@hackerplanet.dev`** | No `CNAME` file in `website/` yet — domain not purchased |
| Docs mention **`hackerplanet.dev`** as the target | **`hackerplanet.com`** is listed for sale (~$6k) — not ours today |

To get **`https://hackerplanet.dev`** (or another name you own), follow [Connect custom domain](#connect-custom-domain-to-github-pages-after-purchase) below.

---

## Free hosting (recommended — already configured)

### GitHub Pages ✅

| Item | Cost |
|------|------|
| Hosting | **$0** |
| HTTPS | **$0** |
| Bandwidth | Free tier (enough for shop traffic) |

- **Site files:** `website/` on `main`
- **Auto-deploy:** pushes to **`gh-pages`** branch ([workflow](../.github/workflows/pages.yml))
- **One-time enable:** [Settings → Pages](https://github.com/salvador-Data/cyberThreatGotchi/settings/pages) → branch **`gh-pages`** / **(root)**

**URLs:** https://salvador-Data.github.io/cyberThreatGotchi/

Setup: [GITHUB_PAGES_SETUP.md](GITHUB_PAGES_SETUP.md)

### Other free hosts (alternatives — not required)

| Provider | Free subdomain | Notes |
|----------|----------------|-------|
| [Cloudflare Pages](https://pages.cloudflare.com/) | `*.pages.dev` | Connect GitHub; fast CDN |
| [Netlify](https://www.netlify.com/) | `*.netlify.app` | Drag-and-drop or Git |
| [Vercel](https://vercel.com/) | `*.vercel.app` | Overkill for static HTML today |

**You do not need these** unless you want a second mirror. GitHub Pages is enough.

---

## Domain names — free vs cheap

### Option A: Free (use this to launch)

**GitHub Pages project URL** — no registration, no renewal, no credit card:

```
https://salvador-Data.github.io/cyberThreatGotchi/
```

Put this on business cards, Reddit, Stripe business profile until you buy a custom domain.

### Option B: Cheapest paid custom domain (when ready)

There is **no trustworthy free `.com`** long-term (old “free” TLD services like Freenom are gone or unsafe). Budget **~$10–15/year** for a professional name.

| Registrar | `.com` first year | `.com` renewal | WHOIS privacy | Best for |
|-----------|-------------------|----------------|---------------|----------|
| **[Cloudflare Registrar](https://domains.cloudflare.com/)** | ~**$10.44** | ~**$10.44** | Free | **Lowest long-term cost** (at-cost, no markup) |
| [Porkbun](https://porkbun.com/) | ~$11 | ~$11 | Free | Simple UI, fair renewals |
| [Namecheap](https://www.namecheap.com/) | ~**$5.98** promo | ~**$13.98** | Free | Cheapest **year 1 only** |
| GoDaddy | ~$2–5 promo | ~**$22+** | Often paid | Avoid — renewal traps |

**Recommendation:** **Cloudflare Registrar** at [domains.cloudflare.com](https://domains.cloudflare.com/) — same price every year, free privacy, pairs well with GitHub Pages custom domain.

**Name ideas to search:** `hackerplanet.dev`, `hackerplanetllc.com`, `cipherhorn.dev`, `cyberthreatgotchi.com`

### Option C: Other free-ish subdomains (not custom brand)

| Service | Example | Cost |
|---------|---------|------|
| Cloudflare Pages | `hacker-planet.pages.dev` | $0 |
| Netlify | `hacker-planet.netlify.app` | $0 |

Still not as clean as GitHub’s URL for your repo name.

### Option D: Student / nonprofit credits

- **[GitHub Student Developer Pack](https://education.github.com/pack)** — sometimes includes domain/hosting credits if eligible
- **Namecheap / Google for Nonprofits** — if Hacker Planet LLC qualifies later

---

## Connect custom domain to GitHub Pages (after purchase)

**Prerequisite:** You own the domain (e.g. register `hackerplanet.dev` at [Cloudflare Registrar](https://domains.cloudflare.com/) — typically ~$10–12/yr for `.dev`).

### Step 1 — Add `CNAME` to the repo

Create `website/CNAME` (one line, no `https://`):

```
hackerplanet.dev
```

Or use `www.hackerplanet.dev` if you prefer the `www` hostname. Push to `main`; the Pages workflow copies it to `gh-pages`.

### Step 2 — GitHub Pages custom domain

1. Open [Settings → Pages](https://github.com/salvador-Data/cyberThreatGotchi/settings/pages)
2. **Custom domain** → enter `hackerplanet.dev` (or `www.hackerplanet.dev`)
3. Wait for DNS check; enable **Enforce HTTPS** when offered
4. If GitHub shows a **TXT** verification record, add it in Cloudflare DNS

### Step 3 — Cloudflare DNS records

For apex (`hackerplanet.dev`):

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| `A` | `@` | `185.199.108.153` | DNS only (grey cloud) |
| `A` | `@` | `185.199.109.153` | DNS only |
| `A` | `@` | `185.199.110.153` | DNS only |
| `A` | `@` | `185.199.111.153` | DNS only |

For `www`:

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| `CNAME` | `www` | `salvador-Data.github.io` | DNS only |

GitHub’s four `A` records are required for apex domains; `CNAME` to `salvador-Data.github.io` works for subdomains like `www`.

### Step 4 — SSL

In Cloudflare: **SSL/TLS → Full (strict)**. GitHub provisions the certificate after DNS propagates (often 5–30 minutes).

### Step 5 — Verify

- https://hackerplanet.dev/ loads the HackerPlanet site
- Old URL still works: https://salvador-Data.github.io/cyberThreatGotchi/

Optional CLI (after `gh auth login`):

```powershell
gh api repos/salvador-Data/cyberThreatGotchi/pages -X PUT -f cname=hackerplanet.dev -f build_type=legacy -f source[branch]=gh-pages -f source[path]=/
```

GitHub docs: https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site

### Alternative: user/org site at repo root (no `/cyberThreatGotchi/`)

A URL like `https://salvador-Data.github.io/` (no project folder) requires a repo named **`salvador-Data.github.io`**. That is a different setup from this project repo; most teams prefer a purchased domain instead.

---

## What costs money later (optional)

| Service | Cost | When |
|---------|------|------|
| Custom domain | ~$10–15/yr | Brand URL |
| VPS (Stripe webhooks 24/7) | ~$6/mo | `stripe_provision.py` always on |
| Stripe fees | 2.9% + 30¢ | Per sale |

The **marketing shop + catalog** stays **$0** on GitHub Pages.

---

## Decision matrix

| Goal | Do this |
|------|---------|
| Launch shop this week | Enable GitHub Pages + use free GitHub URL |
| Look professional later | Cloudflare `.com` or `.dev` ~$10/yr |
| Fastest global CDN | Cloudflare Pages mirror (optional) |
| Backend / webhooks | $6 DigitalOcean droplet when needed |

---

*Hacker Planet LLC · Philadelphia, PA*
