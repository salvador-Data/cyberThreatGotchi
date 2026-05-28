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

1. Buy domain (e.g. `hackerplanet.dev` on Cloudflare)
2. GitHub repo → **Settings → Pages → Custom domain** → enter domain
3. Cloudflare DNS → `CNAME` `@` or `www` → `salvador-Data.github.io`
4. Enable **Full (strict)** SSL in Cloudflare

GitHub docs: https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site

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
