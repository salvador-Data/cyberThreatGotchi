# FAQ: “No verified domains” on GitHub Pages

## What that message means

GitHub shows **Verified domains** when you might attach a **custom domain** you purchased (like `hackerplanet.com`). Verification proves you own the domain (DNS TXT record).

It does **not** block the free GitHub URL:

```
https://salvador-Data.github.io/cyberThreatGotchi/
```

## What to do

| Goal | Action |
|------|--------|
| **Launch shop now (free)** | **Build and deployment** → **Deploy from a branch** → `gh-pages` / `(root)` → Save |
| **Custom domain later** | Buy domain → Pages → Custom domain → add DNS TXT → verify |

## Common mistake

Choosing **GitHub Actions** as the Pages source without completing Actions setup, while ignoring **Deploy from a branch**.

This repo publishes to **`gh-pages`** via peaceiris — use **Deploy from a branch**.

## Link

Full steps: [GITHUB_PAGES_SETUP.md](GITHUB_PAGES_SETUP.md)
