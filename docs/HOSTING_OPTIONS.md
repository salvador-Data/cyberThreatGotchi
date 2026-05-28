# Hosting options — Hacker Planet LLC website

You asked for **free** and **cheap** hosting without domain registration. The site is already set up for the best free option.

## Recommended: GitHub Pages (already configured)

| Item | Cost |
|------|------|
| Hosting | **$0** |
| SSL (HTTPS) | **$0** (automatic) |
| Bandwidth | Generous free tier |
| Custom domain | Optional later (~$12/yr if you want `hackerplanet.dev`) |

**Live URL (after one-time Pages enable):**  
https://salvador-Data.github.io/cyberThreatGotchi/

**Setup:** [GITHUB_PAGES_SETUP.md](GITHUB_PAGES_SETUP.md) — point Pages to `gh-pages` branch.

**Deploy:** Every push to `website/` on `main` runs `.github/workflows/pages.yml`.

No server to maintain. Static HTML/CSS/JS only — perfect for shop + drop-ship links.

---

## Other free static hosts (no registration required to start)

| Provider | Free tier | Best for | Notes |
|----------|-----------|----------|-------|
| **Cloudflare Pages** | Unlimited static | Global CDN, fast | Connect GitHub repo; free `*.pages.dev` subdomain |
| **Netlify** | 100 GB/mo bandwidth | Drag-and-drop deploy | Free `*.netlify.app` subdomain |
| **Vercel** | Hobby free | React/Next if you expand | Overkill for current static site |
| **Render** | Static sites free | Simple Git deploy | Spins down unused services on free tier |

All support custom domains later without moving code.

---

## Cheap paid options (if you outgrow free)

| Option | Typical cost | When to use |
|--------|--------------|-------------|
| **Cloudflare Pages + domain** | ~$10–12/yr domain only | Brand URL `hackerplanet.dev` |
| **Namecheap shared hosting** | ~$4–8/mo | PHP/WordPress (not needed today) |
| **DigitalOcean droplet** | $6/mo | Dynamic backend, webhooks, Stripe listener 24/7 |
| **Fly.io / Railway** | ~$5/mo | Run `stripe_provision.py` + CTG API always-on |

For **CyberThreatGotchi dashboard + Stripe webhooks**, a $6/mo VPS is enough when you go production. The **marketing shop** stays free on GitHub Pages.

---

## What runs where

```
GitHub Pages (free)     →  shop.html, drop-ship links, about pages
Your homelab / VPS      →  python main.py --web, stripe_provision.py
GitHub repo             →  source of truth, CI, releases
```

---

## Decision matrix

| Need | Pick |
|------|------|
| Shop + docs only | **GitHub Pages** ✅ (current) |
| Faster global CDN | Cloudflare Pages (mirror repo) |
| Custom domain later | Buy domain + Cloudflare DNS (no hosting bill) |
| 24/7 Pro key provisioning | $6 VPS + Caddy reverse proxy |

No domain registration is required to launch. The GitHub Pages URL is production-ready for Etsy/AliExpress drop-ship and Stripe checkout links.
