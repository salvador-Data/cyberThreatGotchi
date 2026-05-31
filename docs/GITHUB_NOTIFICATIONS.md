# GitHub notification routing (Proton + CTG bridge)

**Hacker Planet LLC / CyberThreatGotchi** — authorized lab use. **No real email addresses in git** — use placeholders in notes; store your Proton login in the credential vault locally.

**Related:** [EMAIL_NOTIFICATIONS.md](EMAIL_NOTIFICATIONS.md) · [UTMS_WIFI_AI.md](UTMS_WIFI_AI.md) · [CTG_NEXT_STEPS.md](CTG_NEXT_STEPS.md)

---

## Goal

Route **GitHub Actions failure emails** for `salvador-Data/cyberThreatGotchi` to your Proton inbox, organize them in a dedicated folder, and optionally stage JSON for Kali via the email notify bridge — **without** flooding Signal/SMS.

**Best fix for failure email noise:** keep CI green (`pytest` on Linux CI). This doc covers routing for the remaining alerts.

---

## 1. GitHub account notification settings (manual — browser login required)

GitHub cannot change your account email via API without authenticated session. In the browser:

1. Open [GitHub Settings → Notifications](https://github.com/settings/notifications)
2. **Email notification preferences**
   - Set primary notification email to your Proton address (e.g. `your-alias@proton.me` — store real value in vault only)
   - Under **Actions**, choose:
     - **Only notify for failed workflows** (recommended), or
     - **Send notifications for failed workflows only** if you want minimal noise
3. **Custom routing** (optional): [Notification routing rules](https://github.com/settings/notifications/customrouting)
   - Add rule: repository `salvador-Data/cyberThreatGotchi` → email on **Failures only**
4. Save changes

---

## 2. Duck @duck.com → Proton (if using Duck alias)

If GitHub sends to a Duck Email Protection alias that forwards to Proton, see [EMAIL_NOTIFICATIONS.md](EMAIL_NOTIFICATIONS.md) — **poll Proton only once** (Bridge IMAP). Dedup handles forward + direct duplicates.

---

## 3. Proton Mail folder / label filter

In Proton Mail (web or app):

1. **Settings → Filters**
2. Create filter **GitHub-CTG**:
   - **From** contains `notifications@github.com` OR `github.com`
   - **Subject** contains `cyberThreatGotchi`
   - **Action:** Move to folder `GitHub-CTG` (create folder first)
3. Optional second filter for `[salvador-Data/cyberThreatGotchi]` subject prefix if GitHub format changes

This keeps CI failure mail out of your main inbox.

---

## 4. CTG email bridge — GitHub-only mode

Windows SOC can tag and subfolder GitHub CI mail for Kali:

```powershell
cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
```

```powershell
.\scripts\windows\Start-CtgEmailNotifyBridge.ps1 -Once -UseSecretVault -GithubOnly
```

Behavior:

| Feature | Detail |
|---------|--------|
| Filter | From contains `github.com`; subject contains `cyberThreatGotchi` and workflow/CI keywords |
| Label | JSON field `labels: ["github-ctg"]` |
| Output | `Backups\ctg-email-notify\github\*.json` (ctg-backups share) |
| Dedup | Same Message-ID / content hash store as general email bridge |

CLI equivalent:

```powershell
python scripts\ctg_email_notify_cli.py poll --github-only
```

Requires Proton Bridge on `127.0.0.1:1143` and vault title `Proton IMAP` — see [EMAIL_NOTIFICATIONS.md](EMAIL_NOTIFICATIONS.md).

---

## 5. Reduce GitHub email volume (repo-side)

Already in `.github/workflows/ci.yml`:

```yaml
concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Cancels redundant CI runs on rapid pushes to the same branch — fewer duplicate failure emails.

---

## 6. Private ops repos

Lab scripts that must not be public: run diagnose on split repos:

```powershell
.\scripts\publish\Set-CtgPrivateRepos.ps1 -DiagnoseOnly
```

Allowlisted private repos: `ctg-kali-lab`, `ctg-windows-soc`, `ctg-device-hardening`. See [GITHUB_REPOS_PLAN.md](GITHUB_REPOS_PLAN.md).

---

## Sensitive configs — not hidden jammer code

Lab Wi-Fi placeholders (`lab-wifi.conf`, event bus paths, IMAP creds) belong in:

- `Ctg-CredentialVault.ps1` / `%USERPROFILE%\Backups\.vault\`
- Optional DPAPI blobs via `Protect-CtgSensitiveScripts.ps1` (config templates only)

See [SECRET_VAULT.md](SECRET_VAULT.md). **No RF countermeasure tooling** — [UTMS_WIFI_AI.md](UTMS_WIFI_AI.md) documents why jammer overload is refused.

---

## Checklist

| Step | Owner | Done? |
|------|-------|-------|
| Fix CI (`pytest` green on Ubuntu) | Cursor / Andy push | After this doc ships |
| GitHub → Proton email | Andy (browser) | Manual |
| Proton folder filter | Andy (browser) | Manual |
| Proton Bridge + vault IMAP | Andy (local) | Manual |
| `-GithubOnly` bridge poll | Andy (optional) | When Bridge running |
| `Set-CtgPrivateRepos.ps1 -DiagnoseOnly` | Andy | Verify visibility |
