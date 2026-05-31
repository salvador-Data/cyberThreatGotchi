# Vault & secrets audit — printable checklist

**Hacker Planet LLC / CyberThreatGotchi** · **fill secrets by hand only** · **nothing pre-printed**

**Full refs:** [../SECRET_VAULT.md](../SECRET_VAULT.md) · [../PASSWORD_HARDENING.md](../PASSWORD_HARDENING.md) · [../EMAIL_NOTIFICATIONS.md](../EMAIL_NOTIFICATIONS.md)

---

## Rule — no secrets on this page

- [ ] No passwords, API keys, or IMAP app passwords written in repo docs
- [ ] Vault blob: `%USERPROFILE%\Backups\.vault\credentials.vault` (gitignored)
- [ ] If a password appeared in chat — **rotate immediately** (see SECRET_VAULT.md)

---

## Ctg-CredentialVault.ps1 — init checklist (once per machine)

Prerequisites:

- [ ] `pip install cryptography argon2-cffi` (once)
- [ ] Master password chosen — **write nowhere on this sheet**

Steps (interactive — run on Windows SOC):

```powershell
cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
```

```powershell
.\scripts\windows\Ctg-CredentialVault.ps1 -InitVault -WithDpapiWrap
```

```powershell
.\scripts\windows\Ctg-CredentialVault.ps1 -UnlockVault
```

```powershell
.\scripts\windows\Ctg-CredentialVault.ps1 -AddCredential -Title 'Kali SSH' -Username your-kali-user
```

(Prompt for password — hidden SecureString)

Optional titles (add when ready — placeholders only):

- [ ] `Proton IMAP` (or `CTG_EMAIL_IMAP`) — email bridge
- [ ] `Microsoft Account` — optional
- [ ] Router / lab admin — as needed

---

## Session TTL & lock

- [ ] Default idle lock **15 minutes** understood
- [ ] `CTG_VAULT_SESSION_TTL` override documented if set: ___________
- [ ] End session: `Ctg-CredentialVault.ps1 -LockVault`
- [ ] Memory protection tie-in: [MEMORY_PROTECTION_AUDIT_PRINT.md](MEMORY_PROTECTION_AUDIT_PRINT.md)

---

## DPAPI / Protect-CtgSecrets (legacy hash store)

- [ ] `Protect-CtgSecrets.ps1 -SetSecret -Name KALI_SSH_USER` (interactive)
- [ ] `Protect-CtgSecrets.ps1 -SetSecret -Name KALI_SSH_PASSWORD` (interactive)
- [ ] Deploy scripts use `-UseSecretVault` — no default passwords in git

---

## Diagnose (no secrets in log)

```powershell
.\scripts\windows\Initialize-CtgEmailVault.ps1 -DiagnoseOnly
```

- [ ] Vault file exists: Y / N
- [ ] Expected **titles** listed (not values): _________________________
- [ ] Email bridge `-UseSecretVault` path documented

---

## Backup (local only)

- [ ] `-ExportVaultBackup` to gitignored path noted: _________________________
- [ ] CSV import path gitignored — never commit exports

---

## VERIFY — end of session

- [ ] Vault locked (`-LockVault`)
- [ ] No secrets pasted into CTG_NEXT_STEPS or git
- [ ] DuckDuckGo Password Manager still primary for web — not replaced by paper notes

---

**Footer:** Hacker Planet LLC · CyberThreatGotchi · Argon2id + AES-256-GCM · no secrets on paper
