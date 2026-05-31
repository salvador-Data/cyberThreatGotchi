# GitHub Pages â€” enable in 60 seconds

Your site **is already built** on the `gh-pages` branch. GitHub just has not turned on the public URL yet.

## You do NOT need â€œVerified domainsâ€ for launch

On **Settings â†’ Pages** you may see:

> *There are no verified domains. Verified domains are strictâ€¦*

**Ignore that section for now.** That is only if you buy a custom domain later (e.g. `hackerplanet.dev`) and want HTTPS on it.

For the **free** URL you do **not** verify any domain:

**https://salvador-Data.github.io/cyberThreatGotchi/**

---

## Step-by-step (do this exactly)

1. Sign in to GitHub as **salvador-Data**

2. Open: **https://github.com/salvador-Data/cyberThreatGotchi/settings/pages**

3. Find **Build and deployment** (top of the page â€” not â€œVerified domainsâ€)

4. **Source** â†’ choose **Deploy from a branch**  
   (NOT â€œGitHub Actionsâ€ unless you intentionally switched workflows)

5. Set:
   - **Branch:** `gh-pages`
   - **Folder:** `/ (root)`

6. Click **Save**

7. Wait 1â€“3 minutes. Refresh until you see:  
   *â€œYour site is live at https://salvador-Data.github.io/cyberThreatGotchi/â€*

8. Test:
   - https://salvador-Data.github.io/cyberThreatGotchi/
   - https://salvador-Data.github.io/cyberThreatGotchi/shop.html

---

## If â€œDeploy from a branchâ€ is greyed out

The `gh-pages` branch must exist first (it does â€” check  
https://github.com/salvador-Data/cyberThreatGotchi/tree/gh-pages).

If missing, run the deploy workflow once:

1. **Actions** â†’ **Deploy website (GitHub Pages)** â†’ **Run workflow**

2. Wait for green âœ“

3. Return to **Settings â†’ Pages** and pick `gh-pages`

---

## Optional: enable via CLI (after login)

```powershell
gh auth login
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
python scripts\enable_github_pages.py
```

Or run **Actions â†’ Enable GitHub Pages (one-time)** â€” it verifies the site is live (does not require admin token).

**Note:** The one-time enable workflow may show red if run before Pages was enabled â€” use Settings or `gh` above instead. After Pages is live, re-run the workflow and it should pass.

---

## Optional: custom domain later (then â€œVerified domainsâ€ matters)

1. Buy a domain (e.g. Cloudflare ~$10/yr) â€” see [HOSTING_OPTIONS.md](HOSTING_OPTIONS.md)
2. **Settings â†’ Pages â†’ Custom domain** â†’ enter `www.yourdomain.com`
3. GitHub shows a **TXT record** â€” add it in Cloudflare DNS
4. After verification, that domain appears under **Verified domains**

---

## How deploy works (automatic)

Every push to `website/` on `main` runs `.github/workflows/pages.yml` â†’ updates `gh-pages`.

You only enable Pages **once** in Settings.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| 404 on github.io URL | Enable branch `gh-pages` / root (above) |
| â€œVerified domainsâ€ empty | Normal â€” skip until custom domain |
| Old content | Hard refresh (Ctrl+F5) or wait 5 min |
| Workflow red | Actions tab â†’ read **Deploy website** log |

---

*Hacker Planet LLC Â· Philadelphia, PA*
