# SEO — Hacker Planet website

Central config: **`website/seo/site.json`**. Regenerate tags on all pages:

```powershell
python scripts/sync_seo.py
python scripts/sync_website_to_docs.py
```

`sync_website_to_docs.py` runs `sync_seo.py` automatically before mirroring to `docs/web/`.

## What gets injected (each HTML page)

| Tag | Purpose |
|-----|---------|
| `<title>` | Page title (unique per page) |
| `meta description` / `keywords` | Search snippets |
| `link rel="canonical"` | Primary URL (`https://hackerplanet.dev/...`) |
| `link rel="alternate"` | GitHub Pages mirror URL |
| Open Graph + Twitter Card | Social previews |
| JSON-LD | Organization, WebSite, Product, BreadcrumbList, etc. |

## Static files

| File | URL |
|------|-----|
| `website/robots.txt` | `/robots.txt` |
| `website/sitemap.xml` | `/sitemap.xml` |

Submit sitemap in [Google Search Console](https://search.google.com/search-console) after `hackerplanet.dev` DNS is live.

## Editing

1. Update `website/seo/site.json` (titles, descriptions, keywords, `ogImage`).
2. Run `python scripts/sync_seo.py`.
3. Run `pytest tests/test_seo.py tests/test_website.py -v`.

Canonical base is **`https://hackerplanet.dev`** — matches `website/CNAME`. GitHub Pages alternate stays until custom domain fully propagates.

*Hacker Planet LLC · Philadelphia, PA*
