# GitHub Pages — one-time enable

The workflow publishes `website/` to the **`gh-pages`** branch on every push.

## One-time setup (about 30 seconds)

1. Open [repo Settings → Pages](https://github.com/salvador-Data/cyberThreatGotchi/settings/pages)
2. **Build and deployment** → **Source:** **Deploy from a branch**
3. **Branch:** `gh-pages` · **Folder:** `/ (root)`
4. Save — site URL: **https://salvador-Data.github.io/cyberThreatGotchi/**

After the first successful workflow run, the `gh-pages` branch will exist.

## Verify workflow

Actions → **Deploy website (GitHub Pages)** → should be green after push to `website/`.

## Manual deploy trigger

Actions → **Deploy website (GitHub Pages)** → **Run workflow**.

## Alternative (GitHub Actions source)

If you prefer the official Actions Pages flow later, switch Source to **GitHub Actions** in Settings after enabling Pages once.

## Local preview

```powershell
cd website
python -m http.server 8080
# http://127.0.0.1:8080/
```
