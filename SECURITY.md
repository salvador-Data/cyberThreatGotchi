# Security policy — Hacker Planet LLC / CyberThreatGotchi

## Supported versions

| Version | Supported |
|---------|-----------|
| 1.1.x   | Yes       |
| 1.0.x   | Best effort |
| < 1.0   | No        |

## Reporting a vulnerability

**Do not** open public GitHub issues for security problems.

Email or DM the maintainer with:

1. Description of the issue and impact
2. Steps to reproduce
3. Affected version / commit
4. Suggested fix (optional)

| Channel | Contact |
|---------|---------|
| GitHub (private) | [Security advisories](https://github.com/salvador-Data/cyberThreatGotchi/security/advisories/new) |
| Maintainer | Andy Klwal · [salvador-Data](https://github.com/salvador-Data) |

We aim to acknowledge reports within **72 hours** and patch critical issues in **7 days**.

## Scope

In scope:

- CyberThreatGotchi core (`core/`, `dashboard/`, `db/`, `main.py`)
- Web API (`/api/*`) — auth bypass, injection, path traversal
- Webhook / Stripe provisioner scripts
- Pro feed key handling
- Website checkout configuration (no card data touches our servers — Stripe/PayPal hosted)

Out of scope:

- Third-party services (Stripe, PayPal, GitHub)
- Authorized-use / legal questions
- Issues requiring physical access to your BPI-R3 Mini

## Secure deployment checklist

- [ ] Set `CTG_WEB_API_TOKEN` for production web UI (Feed/Pet)
- [ ] Set `CTG_WEBHOOK_SECRET` on CTG and all webhook receivers
- [ ] Set `CTG_PRO_API_KEY` or use Stripe provisioner — disable demo key
- [ ] Set `CTG_AUDIT_SECRET` for signed audit exports
- [ ] Bind web UI to LAN only or place behind reverse proxy + TLS
- [ ] Run `python scripts/check_payments.py` before shop go-live

See [docs/SECURITY_HARDENING.md](docs/SECURITY_HARDENING.md).

## Recognition

We credit researchers in release notes with permission.
