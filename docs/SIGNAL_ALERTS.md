# Signal alerts for CTG SOC (Snort / Suricata IDS)

**Authorized defensive use only** on networks and hosts you own or are explicitly permitted to monitor.

Signal is the **preferred** alert channel for CTG IDS scripts when `signal-cli` is linked on the Windows SOC host. Twilio SMS remains available as fallback (`CTG_USE_TWILIO=1`).

## Why Signal over Twilio SMS

| | Signal (signal-cli) | Twilio SMS |
|---|---------------------|------------|
| Cost | Free (OSS CLI) | Per-message billing |
| Secrets in repo | None — linked device + local config | Twilio SID/token in `.env` |
| Privacy | End-to-end encrypted | Carrier SMS |
| Setup | Link device once (QR) | Twilio account + phone numbers |

## Prerequisites

1. **Signal** installed on your phone (primary account)
2. **Java 21+** (for JAR builds) or Windows-native `signal-cli` binary
3. **Windows SOC** or WSL with outbound HTTPS to Signal servers

## Install signal-cli

Run the CTG installer guide (diagnose + link steps):

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\Install-CtgSignalCli.ps1 -DiagnoseOnly
```

Download from [signal-cli releases](https://github.com/AsamK/signal-cli/releases). Extract to e.g. `%LOCALAPPDATA%\Programs\signal-cli\`.

## Link device (recommended)

Link this host as a Signal **linked device** — no separate phone number required:

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

Set path if not on PATH:

```powershell
$env:CTG_SIGNAL_CLI_PATH = "$env:LOCALAPPDATA\Programs\signal-cli\signal-cli.exe"
```

Create config dir and link (scan QR in Signal app → Settings → Linked Devices):

```powershell
& $env:CTG_SIGNAL_CLI_PATH --config "$env:USERPROFILE\.local\share\signal-cli" link -n CTG-SOC
```

Alternative config location (gitignored vault):

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\Backups\.vault\signal-cli" | Out-Null
```

```powershell
& $env:CTG_SIGNAL_CLI_PATH --config "$env:USERPROFILE\Backups\.vault\signal-cli" link -n CTG-SOC
```

## Environment variables (local `.env` only — never commit)

Add to `C:\Users\Owner\Projects\cyberThreatGotchi\.env` (gitignored):

```env
CTG_SIGNAL_CLI_PATH=C:\Users\Owner\AppData\Local\Programs\signal-cli\signal-cli.exe
CTG_SIGNAL_CONFIG_DIR=%USERPROFILE%\.local\share\signal-cli
CTG_ALERT_SIGNAL_TO=+1XXXXXXXXXX
CTG_SIGNAL_ACCOUNT=+1XXXXXXXXXX
```

| Variable | Purpose |
|----------|---------|
| `CTG_SIGNAL_CLI_PATH` | Full path to `signal-cli.exe` or JAR launcher |
| `CTG_SIGNAL_CONFIG_DIR` | Gitignored account data (default `%USERPROFILE%\.local\share\signal-cli`) |
| `CTG_ALERT_SIGNAL_TO` | Destination E.164 or Signal uuid |
| `CTG_SIGNAL_ACCOUNT` | Sender linked account (auto-detected when only one account) |
| `CTG_USE_TWILIO=1` | Force Twilio SMS instead of Signal |

**Prefer** DPAPI vault for the phone number (same key as SMS):

```powershell
.\scripts\windows\Protect-CtgSecrets.ps1 -SetPii -Name CTG_PII_PHONE
```

Use `-UseSecretVault` on alert scripts when reading from vault.

## Test alert (no attack traffic)

Direct Signal test:

```powershell
.\scripts\windows\Send-CtgSignalAlert.ps1 -TestMessage -UseSecretVault
```

Via IDS dispatcher (Signal preferred):

```powershell
.\scripts\windows\Send-CtgIdsAlert.ps1 -TestMessage -UseSecretVault
```

Suricata / Snort test hooks:

```powershell
.\scripts\windows\Start-CtgSuricataIDS.ps1 -TestAlert
```

```powershell
.\scripts\windows\Start-CtgSnortIDS.ps1 -TestAlert
```

Force Signal on IDS run:

```powershell
.\scripts\windows\Start-CtgSuricataIDS.ps1 -TestAlert -UseSignal
```

## Alert message format

Short, no payloads, no PII:

```text
CTG Suricata: [high] sid 12345 — review log
```

Rate limit: **one message per rule SID per 15 minutes** (shared rate file with SMS: `Backups\logs\sms-rate-limit.json`).

## Scripts

| Script | Role |
|--------|------|
| `Install-CtgSignalCli.ps1` | Diagnose + print install/link steps |
| `Send-CtgSignalAlert.ps1` | signal-cli send with rate limit |
| `Send-CtgIdsAlert.ps1` | Route Signal (default) or Twilio |
| `CTG-SignalCommon.ps1` | Shared paths and config checks |
| `Start-CtgSnortIDS.ps1` | Snort IDS → `Send-CtgIdsAlert.ps1` |
| `Start-CtgSuricataIDS.ps1` | Suricata IDS → `Send-CtgIdsAlert.ps1` |
| `Start-CtgKaliSuricataSmsBridge.ps1` | Kali EVE bridge → `Send-CtgIdsAlert.ps1` |

## Security notes

- Never commit `.env`, phone numbers, or `signal-cli` account data
- Config dirs `%USERPROFILE%\.local\share\signal-cli\` and `Backups\.vault\signal-cli\` must stay gitignored
- Kali guest only stages EVE JSON — alerts fire on Windows host
- See [WINDOWS_SNORT_IDS_SMS.md](WINDOWS_SNORT_IDS_SMS.md) and [SECURITY_HARDENING.md](SECURITY_HARDENING.md)

## Related

- [WINDOWS_SNORT_IDS_SMS.md](WINDOWS_SNORT_IDS_SMS.md) — Snort IDS (Signal preferred)
- [FREE_IPS_SURICATA.md](FREE_IPS_SURICATA.md) — Suricata-primary on Kali
- [SECRET_VAULT.md](SECRET_VAULT.md) — DPAPI `CTG_PII_PHONE`
