# Hacker Planet LLC — website

Static marketing site for **Hacker Planet LLC** (Philadelphia, PA) and the **CyberThreatGotchi** ecosystem.

## Pages

| File | URL path | Content |
|------|----------|---------|
| `index.html` | `/` | Company home, hero, ecosystem preview |
| `about.html` | `/about.html` | Company story, principles, founder |
| `cyberthreatgotchi.html` | `/cyberthreatgotchi.html` | Product deep-dive |
| `ecosystem.html` | `/ecosystem.html` | All four repos |
| `contact.html` | `/contact.html` | Social links, Philly, 2600 |

## Local preview

```powershell
cd website
python -m http.server 8080
# Open http://127.0.0.1:8080/
```

Or open `index.html` directly in a browser (images load from GitHub raw URLs).

## GitHub Pages deploy

1. Push to `main` — workflow publishes `website/` → **`gh-pages`** branch.
2. **One-time:** [docs/GITHUB_PAGES_SETUP.md](../docs/GITHUB_PAGES_SETUP.md) — Settings → Pages → branch **`gh-pages`**, folder **`/ (root)`**.
3. Site URL:

   **https://salvador-Data.github.io/cyberThreatGotchi/**

4. The same site is **mirrored in the repo** at `docs/web/` (run `python scripts/sync_website_to_docs.py` after edits).

5. Browse from the repo: [docs/index.html](../docs/index.html) redirects to `docs/web/`.

## Shop & payments

**[shop.html](shop.html)** — CTG kits, $85.99 COD / $175 Marauder custom builds, Etsy·AliExpress drop-ship, Pro feed.

| Method | How |
|--------|-----|
| Credit / debit | Stripe Payment Links |
| Apple Pay | Stripe (auto on Payment Links) |
| PayPal | PayPal JS SDK or PayPal.Me |
| Venmo | PayPal SDK or direct Venmo link |
| Cash App | `$Cashtag` pay URLs |

Configure `js/payments.config.js` — full guide: [docs/PAYMENTS.md](../docs/PAYMENTS.md).

### Custom domain (optional)

Add a `CNAME` file with your domain (e.g. `hackerplanet.dev`) and configure DNS:

```
www  CNAME  salvador-Data.github.io
```

## Design

- Fonts: [Syne](https://fonts.google.com/specimen/Syne) + [DM Sans](https://fonts.google.com/specimen/DM+Sans)
- Palette matches `assets/marketing/generate_graphics.py` (teal accent `#00b48c`, dark `#0a0e14`)
- OG images pulled from `docs/images/` via raw.githubusercontent.com

## Related docs

- [docs/ABOUT_HACKER_PLANET.md](../docs/ABOUT_HACKER_PLANET.md) — markdown company about
- [docs/ABOUT.md](../docs/ABOUT.md) — CyberThreatGotchi about
- [docs/social/LAUNCH.md](../docs/social/LAUNCH.md) — social launch kit
