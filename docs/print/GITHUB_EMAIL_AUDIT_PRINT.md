# GitHub & email audit — printable checklist

**Hacker Planet LLC / CyberThreatGotchi** · placeholders only · **no real emails on this page**

**Full refs:** [../GITHUB_NOTIFICATIONS.md](../GITHUB_NOTIFICATIONS.md) · [../EMAIL_NOTIFICATIONS.md](../EMAIL_NOTIFICATIONS.md)

---

## PRESERVE — DuckDuckGo Password Manager

- [ ] GitHub login stored in **DuckDuckGo PM** — not on this sheet
- [ ] Proton credentials in **vault** (`Proton IMAP` title) — not in git
- [ ] Do not stack second DNS VPN for email hardening — [DUCKDUCKGO_PRESERVE_PRINT.md](DUCKDUCKGO_PRESERVE_PRINT.md)

---

## GitHub notification settings (browser — manual)

- [ ] [GitHub Settings → Notifications](https://github.com/settings/notifications)
- [ ] Primary email → your Proton address (vault: `your-alias@proton.me` placeholder)
- [ ] Actions → **failed workflows only** (recommended)
- [ ] Custom routing: repo `salvador-Data/cyberThreatGotchi` → failures only

---

## Proton folder filter — GitHub-CTG

In Proton Mail → Settings → Filters:

- [ ] Create folder: **GitHub-CTG**
- [ ] Filter name: **GitHub-CTG**
- [ ] From contains `notifications@github.com` OR `github.com`
- [ ] Subject contains `cyberThreatGotchi`
- [ ] Action: Move to folder **GitHub-CTG**

Optional second filter for subject prefix `[salvador-Data/cyberThreatGotchi]`

---

## Vault — Proton IMAP (for CTG bridge)

Titles in credential vault (values **hand-entered at prompt only**):

- [ ] `Proton IMAP` added via `Ctg-CredentialVault.ps1 -AddCredential`
- [ ] Proton Bridge running locally when polling
- [ ] See [VAULT_SECRETS_AUDIT_PRINT.md](VAULT_SECRETS_AUDIT_PRINT.md)

Diagnose:

```powershell
cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
```

```powershell
.\scripts\windows\Initialize-CtgEmailVault.ps1 -DiagnoseOnly
```

---

## CTG email bridge — GitHub-only mode

```powershell
.\scripts\windows\Start-CtgEmailNotifyBridge.ps1 -Once -UseSecretVault -GithubOnly
```

- [ ] Output: `Backups\ctg-email-notify\github\*.json`
- [ ] Dedup by Message-ID — no duplicate alerts
- [ ] **Fix CI first** — green `pytest` on Linux reduces noise

CLI equivalent:

```powershell
python scripts\ctg_email_notify_cli.py poll --github-only
```

---

## Duck @duck.com → Proton (if used)

- [ ] Poll Proton **once** (Bridge IMAP) — dedup handles Duck forward + direct
- [ ] Do not double-poll Duck and Proton for same message

---

## End-of-session VERIFY

- [ ] GitHub-CTG folder receiving failure mail only (or empty if CI green)
- [ ] No email passwords in logs under `Backups\logs\`
- [ ] Vault locked after bridge run

---

**Footer:** Hacker Planet LLC · CyberThreatGotchi · Proton + GitHub-CTG filter · no real emails in git
