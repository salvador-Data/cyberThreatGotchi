# Password hardening â€” Windows, Kali, iPhone

**Hacker Planet LLC / CyberThreatGotchi** â€” authorized defensive policy for **owned** systems.  
**No secrets in git.** Recovery material lives in **DuckDuckGo Password Manager** (DDG PM), not in this repo.

**Companions:**
- [IPHONE_HARDENING.md](IPHONE_HARDENING.md) â€” preserve DDG PM on iPhone; Phase 1 checklist
- [KALI_RETBLEED.md](KALI_RETBLEED.md) â€” separate CPU mitigation topic
- [scripts/windows/Repair-WindowsSignIn.ps1](../scripts/windows/Repair-WindowsSignIn.ps1) â€” Sign-in UI diagnostics (never sets password)
- [scripts/windows/ADMIN_STEPS.md](../scripts/windows/ADMIN_STEPS.md) â€” local vs Microsoft account recovery

---

## Policy summary (Andy lab)

| Control | Windows (local policy) | Kali lab user (`sal`) |
|---------|------------------------|------------------------|
| Max password age | **120 days** (4 months) | **120 days** (`chage -M 120`) |
| Failed sign-in lockout | **10** attempts | **10** (`pam_faillock deny=10`) |
| Lockout duration | **30 minutes** (configurable) | **1800 s** (30 min) |
| Min password length | **12+** if weaker today | OS default + strong passphrase in DDG PM |
| Password manager | **Keep DuckDuckGo PM** | Same vault for lab login passphrase |

CTG scripts **configure policy only** â€” they do **not** generate, read, or commit passwords.

---

## DuckDuckGo Password Manager (preserve)

**Do not replace** DDG PM with ad-hoc text files or weak browser-only storage.

| Platform | Role |
|----------|------|
| **iPhone** | Primary mobile vault â€” Apple ID, Wiâ€‘Fi, lab recovery codes ([IPHONE_HARDENING.md](IPHONE_HARDENING.md)) |
| **Windows** | Browser extension / app â€” local account, VM credentials, encrypted backup passwords |
| **Kali** | Store lab user passphrase and lockout recovery notes in DDG PM on phone/Windows â€” not on shared folder |

**Recovery codes:** When enabling 2FA (Microsoft, GitHub, Apple), save codes in DDG PM immediately. CTG docs never duplicate them.

---

## Windows

### Script

`scripts/windows/Harden-PasswordPolicy.ps1` (Administrator for `-ApplyPolicy`)

| Switch | Action |
|--------|--------|
| `-DiagnoseOnly` | Report `net accounts` + secedit export (default) |
| `-ApplyPolicy` | Set max age, lockout, min length |
| `-LockoutMinutes` | Default 30 |

**Log:** `%USERPROFILE%\Backups\logs\harden-password-policy.log`

**Audit integration:** `CTG-AuditAutorun.ps1 -HardenAndAudit` runs diagnose pass into `windows-security` compartment.

### Admin command (elevated PowerShell)

One command per step:

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\Harden-PasswordPolicy.ps1 -DiagnoseOnly
```

```powershell
.\scripts\windows\Harden-PasswordPolicy.ps1 -ApplyPolicy
```

### Recovery paths

| Account type | Where to reset |
|--------------|----------------|
| **Microsoft account** | [account.microsoft.com/security](https://account.microsoft.com/security) â€” PIN/Hello may mask password UI; use web or â€œI forgot my PINâ€ |
| **Local account** | `Ctrl+Alt+Del` â†’ Change a password; or `Win+R` â†’ `netplwiz` |
| **Sign-in UI broken** | `Repair-WindowsSignIn.ps1 -DiagnoseOnly` then `-ApplySafeFixes` (Admin) â€” still **no** automatic password change |

---

## Kali lab

### Script

`scripts/kali/harden-password-policy.sh`

```bash
sudo bash /mnt/ctg/harden-password-policy.sh --diagnose-only
sudo bash /mnt/ctg/harden-password-policy.sh --apply --lab-user=sal
```

**Log:** `/var/log/ctg-password-policy.log`

**Bootstrap:** `kali-lab-bootstrap.sh` invokes `--apply` during harden phase.

**SSH keys-only:** If `PasswordAuthentication no` in `sshd_config`, script **does not** re-enable password auth â€” faillock protects console/GDM only.

### faillock

Configured in `/etc/security/faillock.conf`:

- `deny = 10`
- `unlock_time = 1800`
- `fail_interval = 900`

Unlock after lockout: wait 30 minutes, or Admin `faillock --user sal --reset` (manual, not automated).

---

## iPhone cross-link

See [IPHONE_HARDENING.md](IPHONE_HARDENING.md):

- Step 0: document and **keep** DDG VPN/DNS + **DDG Password Manager**
- Strong passcode + Stolen Device Protection
- Do not stack conflicting DNS VPN apps on top of working DDG profile

---

## Threat model (professor summary)

| Attack | Control |
|--------|---------|
| Password spraying | 10-try lockout / faillock |
| Stolen stale password | 120-day rotation reminder (`chage` / `net accounts`) |
| Credential reuse | DDG PM unique passphrases per site/system |
| Local sign-in brute force | Windows lockout + Kali faillock |

**Red team note (lab):** Lockout thresholds trade **availability** (denial via lockout) for **confidentiality**. Monitor Security event ID **4625** on Windows and `/var/log/auth.log` on Kali during exercises.

---

## Files

| Path | Purpose |
|------|---------|
| `scripts/windows/Harden-PasswordPolicy.ps1` | Windows local policy |
| `scripts/kali/harden-password-policy.sh` | Kali faillock + chage |
| `scripts/kali/fix-retbleed-mitigation.sh` | CPU mitigations (separate doc) |

**Authorized use:** Hacker Planet LLC lab â€” systems you own.
