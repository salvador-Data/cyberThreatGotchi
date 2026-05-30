# Google Drive upload — Hacker Planet portfolio (andygkowal@gmail.com)

**Account:** andygkowal@gmail.com  
**Folder name:** `HackerPlanet-Portfolio`  
**Sharing goal:** Anyone with the link can **view** (reader)

This machine has **no Google Drive for Desktop** sync folder and **no rclone** remote. Files are staged locally for manual upload (or install Drive for Desktop later).

---

## Staged files (ready now)

| Path | Contents |
|------|----------|
| `C:\Users\Owner\OneDrive\HackerPlanet-Portfolio\` | 4× `.md` + 4× `.html` portfolio exports |

**Markdown sources (repo):** `docs/PORTFOLIO_FIRMWARE_OS.md`, `PORTFOLIO_FIRMWARE_OS_SUMMARY.md`, `PORTFOLIO_SYSTEM_HARDENING.md`, `PORTFOLIO_SYSTEM_HARDENING_SUMMARY.md`

**Regenerate HTML** (after editing markdown):

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\.venv\Scripts\python.exe scripts\export_portfolio_html.py "C:\Users\Owner\OneDrive\HackerPlanet-Portfolio"
```

Copy refreshed `.md` into the same folder if you changed docs in git.

---

## Option A — Upload via drive.google.com (recommended today)

1. Sign in at [https://drive.google.com](https://drive.google.com) as **andygkowal@gmail.com**.
2. Click **+ New** → **Folder** → name it `HackerPlanet-Portfolio`.
3. Open the folder → **+ New** → **File upload** (or drag-drop).
4. Upload everything from `C:\Users\Owner\OneDrive\HackerPlanet-Portfolio\` (all `.md` and `.html` files).
5. In the folder list, select the folder (or each file) → **Share** (person icon).
6. Under **General access**, change from *Restricted* to **Anyone with the link**.
7. Role: **Viewer** (read-only).
8. Click **Copy link** — that is your public portfolio link. Do not paste the link into the git repo if you treat it as semi-private; share it on LinkedIn/resume as you prefer.

**Folder-level share (one link for all files):** Share the `HackerPlanet-Portfolio` folder once with “Anyone with the link” → Viewer; nested files inherit access.

---

## Option B — Google Drive for Desktop (future automation)

1. Install [Google Drive for desktop](https://www.google.com/drive/download/).
2. Sign in as **andygkowal@gmail.com**.
3. Note the sync path (often `G:\My Drive` or `C:\Users\Owner\Google Drive\My Drive`).
4. Create `HackerPlanet-Portfolio` under **My Drive**.
5. Copy staged files from OneDrive folder into that sync folder; wait for sync checkmark.
6. Set sharing on the folder as in Option A steps 5–8.

**PowerShell copy** (adjust `$drive` after install):

```powershell
$drive = "G:\My Drive"
```

```powershell
$dest = Join-Path $drive "HackerPlanet-Portfolio"
```

```powershell
New-Item -ItemType Directory -Path $dest -Force
```

```powershell
Copy-Item "C:\Users\Owner\OneDrive\HackerPlanet-Portfolio\*" -Destination $dest -Force
```

Then set **Anyone with the link → Viewer** in the Drive web UI (sync client does not set public ACLs by itself).

---

## Option C — rclone (if you configure later)

Do **not** store OAuth tokens or `rclone.conf` in this repository.

1. Install rclone and run `rclone config` → remote name e.g. `gdrive`, type Google Drive, account andygkowal@gmail.com.
2. Upload:

```powershell
rclone copy "C:\Users\Owner\OneDrive\HackerPlanet-Portfolio" gdrive:HackerPlanet-Portfolio
```

3. Public link (if your rclone build supports it):

```powershell
rclone link gdrive:HackerPlanet-Portfolio/PORTFOLIO_SYSTEM_HARDENING.md
```

4. For **folder-wide** “anyone reader”, use Google Drive web UI on the folder, or Google Drive API `permissions.create` with `type=anyone`, `role=reader` (requires OAuth outside the repo).

---

## PDF export (optional)

**pandoc** is not installed on this workstation. To add PDFs later:

1. Install [Pandoc](https://pandoc.org/installing.html) and a PDF engine (e.g. MiKTeX or wkhtmltopdf).
2. Example per file:

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi\docs
```

```powershell
pandoc PORTFOLIO_SYSTEM_HARDENING.md -o PORTFOLIO_SYSTEM_HARDENING.pdf
```

3. Upload PDFs to the same `HackerPlanet-Portfolio` Drive folder.

---

## Security notes

- Portfolio docs contain **no secrets** (no API keys, tokens, or webhook values).
- Never commit `.env`, `rclone.conf`, or Google OAuth JSON into **cyberThreatGotchi**.
- Public “Anyone with the link” means **unlisted but accessible** to anyone who has the URL — appropriate for portfolio sharing, not for private keys or customer data.

---

## Status checklist (fill in after upload)

| Step | Done? |
|------|-------|
| Files in `HackerPlanet-Portfolio` on Drive | ☐ |
| Folder shared: Anyone with link → Viewer | ☐ |
| Link copied for LinkedIn/resume | ☐ |
| HTML copies uploaded (optional) | ☐ |

*Last automated staging: agent upload task — Drive API / Desktop sync unavailable on host.*
