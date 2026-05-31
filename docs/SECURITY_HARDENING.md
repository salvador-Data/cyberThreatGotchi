# Security hardening guide — CyberThreatGotchi

Defensive coding and deployment practices for Hacker Planet LLC projects.

## Environment variables

| Variable | Purpose |
|----------|---------|
| `CTG_WEB_API_TOKEN` | Bearer token for `POST /api/feed` and `POST /api/pet` |
| `CTG_OPERATOR_TOKEN` | Bearer token for fulfillment dashboard + `/api/fulfillment/*` (falls back to `CTG_WEB_API_TOKEN`) |
| `CTG_FULFILLMENT_WEBHOOK_URL` | Discord/Slack webhook when orders queue or status changes (optional) |
| `CTG_WEBHOOK_SECRET` | `X-CTG-Secret` on outbound webhooks |
| `CTG_PRO_API_KEY` | Master Pro feed key (or use per-customer keys DB) |
| `CTG_AUDIT_SECRET` | HMAC on audit chain export |
| `CTG_STRIPE_WEBHOOK_SECRET` | Stripe webhook signature verification (`verify_stripe_webhook` / `hmac.compare_digest`) |
| `CTG_STRIPE_SECRET_KEY` | Server-only Stripe API key (`sk_…`) for `scripts/stripe_portal_session.py` — never in `payments.config.js` |
| `CTG_PRO_KEYS_DB` | SQLite path for provisioned Pro keys |
| `CTG_WEB_PORT` | Web dashboard port for firewall baseline (default `8765`) |
| `CTG_EXTRA_TCP_PORTS` | Comma-separated extra TCP ports for `scripts/firewall-baseline.sh` |
| `CTG_ALLOW_ICMP` | Set `0` to omit inbound ICMP from firewall baseline |
| `CTG_SSH_LAN_ONLY` | Set `1` to restrict SSH to RFC1918/link-local in firewall baseline |
| `CTG_FIREWALL_BASELINE` | Set `1` on `scripts/install.sh` to apply default-deny iptables after install |
| `CTG_WAZUH_MANAGER` | Wazuh SIEM manager IP/hostname for `scripts/windows/wazuh_agent_setup.ps1` (alias: `WAZUH_MANAGER`) |
| `TWILIO_ACCOUNT_SID` | Twilio account SID for `Send-CtgSmsAlert.ps1` (local `.env` only — never commit) |
| `TWILIO_AUTH_TOKEN` | Twilio auth token for SMS alerts |
| `TWILIO_FROM_NUMBER` | Twilio sender number (E.164) |
| `CTG_ALERT_SMS_TO` | Destination mobile for CTG SOC SMS (E.164). **Prefer** DPAPI `CTG_PII_PHONE` with `-UseSecretVault`; legacy: local `.env` or vault `-SetSecret -Name CTG_ALERT_SMS_TO` |

### DPAPI PII vault (Windows SOC — not env vars)

| Vault key | Purpose |
|-----------|---------|
| `CTG_PII_FULL_NAME` | Recoverable name for scripts / fulfillment helpers |
| `CTG_PII_EMAIL` | Recoverable contact email |
| `CTG_PII_PHONE` | Recoverable phone (E.164) — preferred SMS `-UseSecretVault` target |
| `CTG_PII_ADDRESS` | Optional mailing / ship-to |
| `CTG_PII_SSN_LAST4` | Optional last-4 only — never full SSN |

Set with `Protect-CtgSecrets.ps1 -SetPii`; hash sidecars in `%USERPROFILE%\Backups\.vault\*.hash` (gitignored). See [SECRET_VAULT.md](SECRET_VAULT.md).

## Windows SOC (lab / authorized hosts)

Free stack orchestration: `scripts/windows/README_WINDOWS_SOC.md`. Scripts use env vars only — no embedded manager secrets. Run PowerShell **as Administrator** on systems you own; use explicit flags on `harden_windows.ps1` (default is guidance-only).

Wireshark IDS + Twilio SMS: [WIRESHARK_IDS_SMS.md](WIRESHARK_IDS_SMS.md) — capture and heuristics on Windows; full IPS remains OPNsense Suricata.

## iPhone (personal device hardening)

iOS has **no traditional filesystem AV** — App Store “antivirus” apps cannot scan other apps like Windows Defender. Prefer Settings hardening plus reputable DNS/Safari/SMS tools. Step-by-step for iPhone 15 Pro Max (iOS 17/18): [IPHONE_HARDENING.md](IPHONE_HARDENING.md).

## Firewall baseline (BPI-R3 / Linux)

Static default-deny **iptables** allow-list: `scripts/firewall-baseline.sh`. CTG **IPS** (`core/ips.py`) inserts dynamic `iptables -I INPUT -s <ip> -j DROP` rules **above** this baseline.

```bash
sudo ./scripts/firewall-baseline.sh --dry-run
sudo CTG_WEB_PORT=8765 CTG_SSH_LAN_ONLY=1 ./scripts/firewall-baseline.sh
sudo ./scripts/firewall-baseline-save.sh
```

Full port table, OpenWrt notes, and IPS interaction: [FIREWALL_BASELINE.md](FIREWALL_BASELINE.md).

## Web API protections (v1.2+)

Implemented in `core/security.py` and `dashboard/web_server.py`:

- **Security headers** — CSP, `X-Frame-Options`, `nosniff`, `Referrer-Policy`
- **Rate limiting** — 120 req/min per IP on `/api/*`; 30/min on Feed/Pet
- **Sprite path sanitization** — mood parameter whitelist (blocks traversal)
- **Optional API token** — mutating routes require `Authorization: Bearer …` when token set

## Operator fulfillment (v1.3+)

- **Dashboard:** `http://127.0.0.1:8765/operator/fulfillment` when `python main.py --web` is running
- **Queue file:** `data/fulfillment_queue.json` (gitignored; schema in `data/fulfillment_queue.example.json`)
- **Auth:** set `CTG_OPERATOR_TOKEN` (recommended) or reuse `CTG_WEB_API_TOKEN`
- **Stripe auto-queue:** `POST /api/fulfillment/webhook` with `CTG_STRIPE_WEBHOOK_SECRET`; Payment Link metadata `stripe_key=ds…`
- **No PCI scope expansion** — operator pays suppliers manually; dashboard never stores card numbers or marketplace passwords
- **Fulfillment queue** — may store `stripe_customer_id` and ship-to text from Stripe sessions; never PAN, CVV, or PaymentMethod payloads
- **Static shop** — `customer-prefill.js` stores email + ship-to in browser `localStorage` only; saved cards live in Stripe Customer Portal / PayPal vault

```powershell
$env:CTG_OPERATOR_TOKEN = "long-random-token"
$env:CTG_FULFILLMENT_WEBHOOK_URL = "https://discord.com/api/webhooks/..."  # optional
python main.py --simulation --web
```

See [DROPSHIP_FULFILLMENT_RUNBOOK.md](DROPSHIP_FULFILLMENT_RUNBOOK.md).

```powershell
$env:CTG_WEB_API_TOKEN = "long-random-token"
python main.py --simulation --web
curl -X POST -H "Authorization: Bearer long-random-token" http://127.0.0.1:8765/api/feed
```

## Pro key provisioning (Stripe)

```powershell
$env:CTG_STRIPE_WEBHOOK_SECRET = "whsec_..."
python scripts/stripe_provision.py --port 9091
```

Stripe Dashboard → Webhooks → `checkout.session.completed`, `customer.subscription.deleted`,  
`customer.subscription.updated`, `invoice.payment_failed`  
→ `http://your-host:9091/stripe/webhook`

See [PAYMENTS_RECURRING.md](PAYMENTS_RECURRING.md) for Customer Portal, MSP subscriptions, and localStorage prefill (no PAN on server).

Keys stored in `data/pro_keys.db`; validated by `validate_pro_key()` alongside `CTG_PRO_API_KEY`.

## Webhook receivers

Always set matching secrets:

```powershell
python scripts/webhook_receiver.py --secret shared-secret
python scripts/bjorn_bridge.py --secret shared-secret
```

## CI security scans

`.github/workflows/security.yml` runs on every push:

- **bandit** — Python SAST
- **pip-audit** — dependency CVE check
- **gitleaks** — secret scanning (see `.gitleaks.toml` allowlist for docs/tests)

## Bandit policy

`.bandit` skips reviewed patterns (B104 LAN bind, B310 urllib clients). CI runs `bandit -ll` so **only Medium+** findings fail the build; Low severity is logged but allowed.

## Website (GitHub Pages)

- Payment card data never hits our static site — Stripe/PayPal hosted checkout only (PCI SAQ-A)
- Returning customer ship-to/email stored in browser `localStorage` only (`customer-prefill.js`) — never PAN or tokens
- Stripe Customer Portal URL is publishable; secret keys stay in env vars
- Configure `website/js/payments.config.js`; validate with `python scripts/check_payments.py`
- Security meta tags injected on sync (`X-Content-Type-Options`, CSP, referrer policy)

## Future coding standards

Project rules live in `.cursor/rules/` — all Hacker Planet LLC code should:

1. Use constant-time comparison for secrets (`hmac.compare_digest`)
2. Never log API keys, webhook secrets, or payment tokens
3. Validate and sanitize external input (IPs, paths, JSON size)
4. Fail closed when auth is configured but missing
5. Add tests for new security-sensitive endpoints

See [SECURITY.md](../SECURITY.md) for vulnerability reporting.
