# GitHub Pages — one-time enable

The **Deploy website** workflow fails at **Setup Pages** until Pages uses GitHub Actions as its source.

## Option A — GitHub website (recommended)

1. Open [repo Settings → Pages](https://github.com/salvador-Data/cyberThreatGotchi/settings/pages)
2. **Build and deployment** → **Source:** select **GitHub Actions**
3. Re-run the latest failed **Deploy website** workflow (Actions tab → workflow → Re-run)

Live URL: **https://salvador-Data.github.io/cyberThreatGotchi/**

## Option B — Script (requires `gh auth login`)

```powershell
gh auth login
python scripts/enable_github_pages.py
```

## Option C — Automatic (already in workflow)

The **Deploy website** workflow runs `actions/github-script` to create/update the Pages site with `build_type: workflow` before deploy. If deploy still fails, use Option A once, then re-run the workflow.
