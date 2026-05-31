# CTG local secret vault â€” DPAPI, PII, and why SMS is not for passwords

**Hacker Planet LLC / CyberThreatGotchi** â€” authorized defensive lab use on **owned** systems only.

**Companions:**
- [PASSWORD_HARDENING.md](PASSWORD_HARDENING.md) â€” 120-day rotation, lockout, DuckDuckGo Password Manager policy
- [SECURITY_HARDENING.md](SECURITY_HARDENING.md) â€” env vars, Twilio SMS for alerts only
- [WIRESHARK_IDS_SMS.md](WIRESHARK_IDS_SMS.md) â€” SOC SMS rate limits

---

## Immediate action: rotate if a password appeared in chat

If you pasted a **lab password into Cursor, SMS, email, or any chat**, treat it as **compromised**:

1. **Change the password now** on the affected account (Kali user, Windows local, etc.).
2. **Update DuckDuckGo Password Manager** with the new passphrase â€” do not store the new secret in git, rules, docs, or scripts.
3. **Re-store** lab SSH credentials in the DPAPI vault (below) using **interactive prompts only**.
4. CTG **never** commits, logs, or transmits your real password from chat.

Chat and SMS are **not secret channels**. Assume anything typed there may be retained in logs or backups.

---

## Why SMS autofill for passwords is wrong

| Risk | Why it matters |
|------|----------------|
| **SMS is plaintext** | Carriers, device backups, and synced messages can expose content. |
| **SIM swap / SS7** | Attackers target SMS for account recovery â€” same class of risk for â€œpassword via text.â€ |
| **Autofill from SMS** | iOS/Android suggestions train users to treat SMS as a credential store. |
| **Twilio CTG alerts** | Our stack sends **operational reminders only** â€” never usernames, passwords, or vault contents. |

**Use DuckDuckGo Password Manager on iPhone** for autofill on sites and apps you own. For Kali/Windows lab logins, open DDG PM on the phone or extension on Windows â€” **do not** ask CTG to SMS credentials.

---

## Windows DPAPI vault (`Protect-CtgSecrets.ps1`)

Secrets live outside git:

```text
%USERPROFILE%\Backups\.vault\secrets.dpapi
```

- Encrypted with .NET `ProtectedData` (**CurrentUser** scope) â€” bound to your Windows login.
- `.gitignore` excludes `.vault/` and `.env`.
- Scripts read secrets at runtime; **no plaintext passwords in the repo**.

### Store secrets (interactive â€” run on your machine)

One command per step in PowerShell:

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
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

Lists key names only â€” never values.

### Deploy Kali lab using the vault

```powershell
.\scripts\windows\Deploy-KaliLab.ps1 -UseSecretVault -StartVmIfStopped
```

`Deploy-KaliLab.ps1` reads `KALI_SSH_USER` and `KALI_SSH_PASSWORD` from the vault when `-UseSecretVault` is set. Fallback order: vault â†’ `Backups\kali-vm-credentials.txt` (gitignored) â†’ default `kali`/`kali` for fresh VMs.

### Read from other scripts

```powershell
$user = .\scripts\windows\Protect-CtgSecrets.ps1 -GetSecret -Name KALI_SSH_USER
```

Or dot-source and call `Get-CtgProtectedSecret` (see script header).

---

## Why not hash passwords inside committed scripts?

Some automation ideas store a **SHA-256 hash** of a Windows or lab password directly in a `.ps1` file "so git never sees the plaintext." That pattern **does not help** for CTG lab scripts:

| Problem | Detail |
|---------|--------|
| **Hashes are still secrets in git** | Anyone with repo access gets an offline crack target. Windows NTLM and short passphrases fall to GPU wordlists. |
| **Hashes cannot elevate** | Scheduled tasks with `RunLevel Highest` need **plaintext** (stored in LSASS/task XML) or **Interactive/UAC** logon â€” a hash is useless to `Register-ScheduledTask`. |
| **False sense of safety** | Agents may paste hashes into chat or docs; rotation requires editing tracked files. |

**What we use instead:**

1. **Runtime secrets** â€” `Protect-CtgSecrets.ps1 -SetSecret` stores DPAPI-encrypted plaintext under `%USERPROFILE%\Backups\.vault\` (gitignored). Scripts read at runtime only.
2. **Optional hash verification** â€” `-SetSecretHash` / `-TestSecretHash` store the hash **inside the same DPAPI vault** (key `NAME_HASH`), never in committed scripts. Use this only to confirm you typed a password correctly after rotation â€” not for unattended elevation.
3. **Admin without stored password** â€” `Run-AsAdmin.ps1` (UAC) or scheduled tasks with **Interactive** principal (`Register-CtgCpuOptimizeTask.ps1`).

See [CPU_PERFORMANCE.md](CPU_PERFORMANCE.md) for the Andy-safe CPU optimize workflow.

### Hash verification (optional, local only)

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\Protect-CtgSecrets.ps1 -SetSecretHash -Name KALI_SSH_PASSWORD
```

Prompts for the password; stores `KALI_SSH_PASSWORD_HASH` in the DPAPI vault only.

```powershell
.\scripts\windows\Protect-CtgSecrets.ps1 -TestSecretHash -Name KALI_SSH_PASSWORD
```

Exit code 0 = match, 1 = mismatch. For deploy scripts, still use `-SetSecret` (plaintext in vault) â€” not hash alone.

---

## PII vault â€” encrypt for recovery, hash for redaction

**Cryptographic reality:** a **hash alone is not recoverable**. CTG stores recoverable PII with **Windows DPAPI** (same `secrets.dpapi` blob as lab credentials). A **dual sidecar** stores **SHA-256 of normalized value** in `.vault\<Name>.hash` and `pii-index.json` for log redaction and equality checks â€” **no plaintext in the index**.

All files live under `%USERPROFILE%\Backups\.vault\` (gitignored â€” never commit).

### PII key names

| Vault key | Redact tag | Notes |
|-----------|------------|-------|
| `CTG_PII_FULL_NAME` | `name` | Full legal or display name |
| `CTG_PII_EMAIL` | `email` | Contact email |
| `CTG_PII_PHONE` | `phone` | E.164 preferred â€” **preferred SMS destination** |
| `CTG_PII_ADDRESS` | `address` | Optional ship-to / mailing |
| `CTG_PII_SSN_LAST4` | `ssn_last4` | Optional â€” **last 4 digits only**; never store full SSN |

### Store PII (interactive SecureString â€” one command per step)

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\Protect-CtgSecrets.ps1 -SetPii -Name CTG_PII_FULL_NAME
```

```powershell
.\scripts\windows\Protect-CtgSecrets.ps1 -SetPii -Name CTG_PII_EMAIL
```

```powershell
.\scripts\windows\Protect-CtgSecrets.ps1 -SetPii -Name CTG_PII_PHONE
```

Optional:

```powershell
.\scripts\windows\Protect-CtgSecrets.ps1 -SetPii -Name CTG_PII_ADDRESS
```

```powershell
.\scripts\windows\Protect-CtgSecrets.ps1 -SetPii -Name CTG_PII_SSN_LAST4
```

Each `-SetPii` also writes the hash sidecar and index entry automatically.

### Hash only (no new DPAPI plaintext)

```powershell
.\scripts\windows\Protect-CtgSecrets.ps1 -SetPiiHash -Name CTG_PII_PHONE
```

### Recover PII in scripts (pipeline only â€” never Write-Host the value)

```powershell
$phone = .\scripts\windows\Protect-CtgSecrets.ps1 -GetPii -Name CTG_PII_PHONE
```

```powershell
. .\scripts\windows\Protect-CtgSecrets.ps1
$phone = Get-CtgPiiForScript -Name CTG_PII_PHONE
```

Object form:

```powershell
$obj = .\scripts\windows\Protect-CtgSecrets.ps1 -GetPii -Name CTG_PII_PHONE -Quiet
```

### Redact logs before SIEM / shared files

```powershell
$safe = .\scripts\windows\Redact-CtgPiiInText.ps1 -Text "IDS alert for +12155551234"
```

### SMS destination: vault vs `.env`

| Source | Key | When to use |
|--------|-----|-------------|
| **Preferred** | `CTG_PII_PHONE` in DPAPI vault | `-UseSecretVault` on SMS scripts |
| Alternate vault | `CTG_ALERT_SMS_TO` via `-SetSecret` | Legacy/alternate E.164 in vault |
| Fallback | `CTG_ALERT_SMS_TO` in local `.env` | Twilio creds still in `.env`; destination can move to vault |

Test SMS with vault phone:

```powershell
.\scripts\windows\Send-CtgSmsAlert.ps1 -TestMessage -UseSecretVault
```

---

## Optional: age / SOPS on Kali

For **team-shared** or **offline backup** of Ansible/Kali secrets (not required for solo Andy lab):

| Tool | Role |
|------|------|
| **[age](https://github.com/FiloSottile/age)** | Modern file encryption; public key encrypt, private key on YubiKey or offline media |
| **[Mozilla SOPS](https://github.com/getsops/sops)** | Encrypt YAML/JSON in git; integrates with age or cloud KMS |

Example layout (gitignored private keys):

```text
scripts/kali/secrets.enc.yaml   # SOPS-encrypted â€” safe to commit ciphertext only
scripts/kali/.sops.yaml       # creation rules
```

Windows DPAPI vault remains the **primary** store for PuTTY/plink deploy from the SOC laptop. Use SOPS only if you need reproducible Kali Ansible vars across machines.

---

## PII encryption (defense in depth)

| Layer | Control |
|-------|---------|
| **Windows lab host** | DPAPI vault for SSH/lab credentials **and PII** (`-SetPii`); BitLocker via [DEVICE_ENCRYPTION.md](DEVICE_ENCRYPTION.md) |
| **Backups** | `%USERPROFILE%\Backups\.vault\` â€” `secrets.dpapi`, `*.hash`, `pii-index.json`; avoid copying vault to cloud unencrypted |
| **Kali VM disk** | Full-disk **LUKS** for portable lab images; `chmod 600` on `/etc/ctg/lab-wifi.conf` |
| **In transit** | TLS for webhooks, Stripe, Twilio API; SSH for Kali bootstrap |
| **Logs** | `Redact-CtgPiiInText.ps1` before shared logs; hash sidecars enable tag lookup without plaintext in index |
| **Phone** | DDG PM for recovery codes; PII phone in vault for CTG SMS â€” see [IPHONE_HARDENING.md](IPHONE_HARDENING.md) |

---

## SMS: reminders only (120 days)

Optional scheduled task registers a **password rotation reminder** â€” message text:

```text
CTG: rotate lab passwords (Windows/Kali). Use DuckDuckGo Password Manager â€” never SMS secrets.
```

Register (Administrator PowerShell):

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
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
| `CTG_ALERT_SMS_TO` | Fallback mobile E.164 in `.env` â€” **prefer** vault `CTG_PII_PHONE` with `-UseSecretVault` |

Test SMS without secrets (vault phone when `-UseSecretVault`):

```powershell
.\scripts\windows\Send-CtgSmsAlert.ps1 -TestMessage -UseSecretVault
```

Unregister reminder task:

```powershell
.\scripts\windows\Register-CtgSecretRotationReminder.ps1 -Unregister
```

---

## Script map

| Script | Purpose |
|--------|---------|
| `Protect-CtgSecrets.ps1` | DPAPI set/get/list/remove; `-SetPii` / `-GetPii` / `-SetPiiHash`; optional `-SetSecretHash` / `-TestSecretHash` |
| `Redact-CtgPiiInText.ps1` | Replace vault PII in strings with `[REDACTED:tag]` |
| `Deploy-KaliLab.ps1 -UseSecretVault` | Kali bootstrap using vault |
| `Send-CtgSmsAlert.ps1 -UseSecretVault` | Twilio SMS using `CTG_PII_PHONE` or vault `CTG_ALERT_SMS_TO` |
| `Register-CtgCpuOptimizeTask.ps1` | Weekly CPU optimize â€” Interactive, no password in repo |
| `Run-AsAdmin.ps1` | UAC elevation without stored password |
| `Register-CtgSecretRotationReminder.ps1` | 120-day SMS reminder task |
| `Invoke-CtgSecretRotationSms.ps1` | Runner â€” no secrets in body |
| `Send-CtgSmsAlert.ps1` | Twilio wrapper (rate-limited) |

---

## Policy alignment

- **NIST CSF PR.AC-1** â€” identities managed; credentials not embedded in code.
- **CIS Control 5** â€” account management; rotation every 120 days ([PASSWORD_HARDENING.md](PASSWORD_HARDENING.md)).
- **MITRE ATT&CK** â€” credential access (T1552, T1110) â€” reduce exposure by keeping secrets out of chat, SMS, and git.

CTG configures **policy and storage mechanics** â€” it does **not** generate or commit your passwords.
