# Security hardening guide — CyberThreatGotchi

Defensive coding and deployment practices for Hacker Planet LLC projects.

## Environment variables

| Variable | Purpose |
|----------|---------|
| `CTG_WEB_API_TOKEN` | Bearer token for `POST /api/feed` and `POST /api/pet` |
| `CTG_WEBHOOK_SECRET` | `X-CTG-Secret` on outbound webhooks |
| `CTG_PRO_API_KEY` | Master Pro feed key (or use per-customer keys DB) |
| `CTG_AUDIT_SECRET` | HMAC on audit chain export |
| `CTG_STRIPE_WEBHOOK_SECRET` | Stripe webhook signature verification |
| `CTG_PRO_KEYS_DB` | SQLite path for provisioned Pro keys |

## Web API protections (v1.2+)

Implemented in `core/security.py` and `dashboard/web_server.py`:

- **Security headers** — CSP, `X-Frame-Options`, `nosniff`, `Referrer-Policy`
- **Rate limiting** — 120 req/min per IP on `/api/*`; 30/min on Feed/Pet
- **Sprite path sanitization** — mood parameter whitelist (blocks traversal)
- **Optional API token** — mutating routes require `Authorization: Bearer …` when token set

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

Stripe Dashboard → Webhooks → `checkout.session.completed`, `customer.subscription.deleted`  
→ `http://your-host:9091/stripe/webhook`

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
- **gitleaks** — secret scanning

## Website (GitHub Pages)

- Payment card data never hits our static site — Stripe/PayPal hosted checkout only
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
