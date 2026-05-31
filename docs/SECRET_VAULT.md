# CTG local secret vault — DPAPI, PII, and why SMS is not for passwords

**Hacker Planet LLC / CyberThreatGotchi** — authorized defensive lab use on **owned** systems only.

**Companions:**
- [PASSWORD_HARDENING.md](PASSWORD_HARDENING.md) — 120-day rotation, lockout, DuckDuckGo Password Manager policy
- [SECURITY_HARDENING.md](SECURITY_HARDENING.md) — env vars, Twilio SMS for alerts only
- [WIRESHARK_IDS_SMS.md](WIRESHARK_IDS_SMS.md) — SOC SMS rate limits

---

## Immediate action: rotate if a password appeared in chat

If you pasted a **lab password into Cursor, SMS, email, or any chat**, treat it as **compromised**:

1. **Change the password now** on the affected account (Kali user, Windows local, etc.).
2. **Update DuckDuckGo Password Manager** with the new passphrase — do not store the new secret in git, rules, docs, or scripts.
3. **Re-store** lab SSH credentials in the DPAPI vault (below) using **interactive prompts only**.
4. CTG **never** commits, logs, or transmits your real password from chat.

Chat and SMS are **not secret channels**. Assume anything typed there may be retained in logs or backups.

---

## Why SMS autofill for passwords is wrong

| Risk | Why it matters |
|------|----------------|
| **SMS is plaintext** | Carriers, device backups, and synced messages can expose content. |
| **SIM swap / SS7** | Attackers target SMS for account recovery — same class of risk for “password via text.” |
| **Autofill from SMS** | iOS/Android suggestions train users to treat SMS as a credential store. |
| **Twilio CTG alerts** | Our stack sends **operational reminders only** — never usernames, passwords, or vault contents. |

**Use DuckDuckGo Password Manager on iPhone** for autofill on sites and apps you own. For Kali/Windows lab logins, open DDG PM on the phone or extension on Windows — **do not** ask CTG to SMS credentials.

---

## Windows DPAPI vault (`Protect-CtgSecrets.ps1`)

Secrets live outside git:

```text
%USERPROFILE%\Backups\.vault\secrets.dpapi
```

- Encrypted with .NET `ProtectedData` (**CurrentUser** scope) — bound to your Windows login.
- `.gitignore` excludes `.vault/` and `.env`.
- Scripts read secrets at runtime; **no plaintext passwords in the repo**.

### Store secrets (interactive — run on your machine)

One command per step in PowerShell:

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\Protect-CtgSecrets.ps1 -SetSecret -Name KALI_SSH_USER
```

When prompted, enter your Kali SSH username (not stored in git).

```powershell
.\scripts\windows\Protect-CtgSecrets.ps1 -SetSecret -Name KALI_SSH_PASSWORD
```

When prompted, enter the password as a **SecureString** (hidden input).

```powershell
.\scripts\windows\Protect-CtgSecrets.ps1 -ListSecrets
```

Lists key names only — never values.

### Deploy Kali lab using the vault

```powershell
.\scripts\windows\Deploy-KaliLab.ps1 -UseSecretVault -StartVmIfStopped
```

`Deploy-KaliLab.ps1` reads `KALI_SSH_USER` and `KALI_SSH_PASSWORD` from the vault when `-UseSecretVault` is set. Fallback order: vault → `Backups\kali-vm-credentials.txt` (gitignored) → default `kali`/`kali` for fresh VMs.

### Read from other scripts

```powershell
$user = .\scripts\windows\Protect-CtgSecrets.ps1 -GetSecret -Name KALI_SSH_USER
```

Or dot-source and call `Get-CtgProtectedSecret` (see script header).

---

## Optional: age / SOPS on Kali

For **team-shared** or **offline backup** of Ansible/Kali secrets (not required for solo Andy lab):

| Tool | Role |
|------|------|
| **[age](https://github.com/FiloSottile/age)** | Modern file encryption; public key encrypt, private key on YubiKey or offline media |
| **[Mozilla SOPS](https://github.com/getsops/sops)** | Encrypt YAML/JSON in git; integrates with age or cloud KMS |

Example layout (gitignored private keys):

```text
scripts/kali/secrets.enc.yaml   # SOPS-encrypted — safe to commit ciphertext only
scripts/kali/.sops.yaml       # creation rules
```

Windows DPAPI vault remains the **primary** store for PuTTY/plink deploy from the SOC laptop. Use SOPS only if you need reproducible Kali Ansible vars across machines.

---

## PII encryption (defense in depth)

| Layer | Control |
|-------|---------|
| **Windows lab host** | DPAPI vault for SSH/lab credentials; BitLocker via [DEVICE_ENCRYPTION.md](DEVICE_ENCRYPTION.md) (`Enable-BitLockerSafe.ps1`) |
| **Backups** | `%USERPROFILE%\Backups` — vault under `.vault\`; avoid copying `secrets.dpapi` to cloud unencrypted |
| **Kali VM disk** | Full-disk **LUKS** for portable lab images; `chmod 600` on `/etc/ctg/lab-wifi.conf` |
| **In transit** | TLS for webhooks, Stripe, Twilio API; SSH for Kali bootstrap |
| **Logs** | CTG scripts log **source** and **username** only — never passwords, tokens, or SMS bodies with secrets |
| **Phone** | DDG PM for PII recovery codes; see [IPHONE_HARDENING.md](IPHONE_HARDENING.md) |

---

## SMS: reminders only (120 days)

Optional scheduled task registers a **password rotation reminder** — message text:

```text
CTG: rotate lab passwords (Windows/Kali). Use DuckDuckGo Password Manager — never SMS secrets.
```

Register (Administrator PowerShell):

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\Register-CtgSecretRotationReminder.ps1
```

Requires local `.env`:

| Variable | Purpose |
|----------|---------|
| `TWILIO_ACCOUNT_SID` | Twilio API |
| `TWILIO_AUTH_TOKEN` | Twilio API |
| `TWILIO_FROM_NUMBER` | Sender E.164 |
| `CTG_ALERT_SMS_TO` | Your mobile E.164 (Andy sets locally — never commit) |

Test SMS without secrets:

```powershell
.\scripts\windows\Send-CtgSmsAlert.ps1 -TestMessage
```

Unregister reminder task:

```powershell
.\scripts\windows\Register-CtgSecretRotationReminder.ps1 -Unregister
```

---

## Script map

| Script | Purpose |
|--------|---------|
| `Protect-CtgSecrets.ps1` | DPAPI set/get/list/remove |
| `Deploy-KaliLab.ps1 -UseSecretVault` | Kali bootstrap using vault |
| `Register-CtgSecretRotationReminder.ps1` | 120-day SMS reminder task |
| `Invoke-CtgSecretRotationSms.ps1` | Runner — no secrets in body |
| `Send-CtgSmsAlert.ps1` | Twilio wrapper (rate-limited) |

---

## Policy alignment

- **NIST CSF PR.AC-1** — identities managed; credentials not embedded in code.
- **CIS Control 5** — account management; rotation every 120 days ([PASSWORD_HARDENING.md](PASSWORD_HARDENING.md)).
- **MITRE ATT&CK** — credential access (T1552, T1110) — reduce exposure by keeping secrets out of chat, SMS, and git.

CTG configures **policy and storage mechanics** — it does **not** generate or commit your passwords.
