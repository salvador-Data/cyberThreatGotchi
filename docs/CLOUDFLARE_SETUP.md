# Cloudflare setup — hackerplanet.dev

Step-by-step checklist for **Hacker Planet LLC** custom domain on GitHub Pages with Cloudflare DNS and security settings. Mirrors [SETUP_CHECKLIST.md § C](SETUP_CHECKLIST.md#c-domain-hackerplanetdev--in-progress) with expanded WAF/TLS/email detail.

**Current repo state (2026-05-28):**

- `website/CNAME` → `hackerplanet.dev`
- GitHub Pages API: `cname=hackerplanet.dev`, `https_enforced=false` (HTTPS after DNS verifies)
- Public DNS for `hackerplanet.dev` may not resolve until domain registration completes

---

## Prerequisites

| Step | Action |
|------|--------|
| 1 | [Cloudflare account](https://dash.cloudflare.com/) (created) |
| 2 | Register **`hackerplanet.dev`** at [Cloudflare Registrar](https://domains.cloudflare.com/) (~$10–12/yr) |
| 3 | Confirm zone **`hackerplanet.dev`** appears under **Websites** |

---

## 1. DNS for GitHub Pages (DNS only — grey cloud)

GitHub Pages requires **DNS only** (grey cloud ☁️ off / not proxied) for the apex and `www` records until you intentionally front the site with Cloudflare proxy (not recommended for initial GitHub HTTPS provisioning).

### Apex `@` — four A records

Add **four separate A records** (same name `@`, different IPv4):

| Type | Name | Content | Proxy status |
|------|------|---------|--------------|
| A | `@` | `185.199.108.153` | **DNS only** (grey) |
| A | `@` | `185.199.109.153` | DNS only |
| A | `@` | `185.199.110.153` | DNS only |
| A | `@` | `185.199.111.153` | DNS only |

### `www` — CNAME

| Type | Name | Content | Proxy status |
|------|------|---------|--------------|
| CNAME | `www` | `salvador-Data.github.io` | **DNS only** (grey) |

**Alternative apex:** single CNAME `@` → `salvador-Data.github.io` (Cloudflare CNAME flattening). Use **either** four A records **or** apex CNAME — not both methods mixed incorrectly.

### GitHub repo custom domain

1. [Settings → Pages](https://github.com/salvador-Data/cyberThreatGotchi/settings/pages)
2. Custom domain: **`hackerplanet.dev`** → Save
3. Wait for DNS check (up to 24h after Cloudflare records propagate)
4. Enable **Enforce HTTPS** once GitHub provisions the certificate

CLI (optional):

```powershell
gh api -X PUT repos/salvador-Data/cyberThreatGotchi/pages -f cname=hackerplanet.dev
gh api repos/salvador-Data/cyberThreatGotchi/pages
```

**Ignore** GitHub **Profile → Settings → Pages → Verified domains** for this project — use **repo Settings → Pages** instead.

---

## 2. SSL/TLS and HTTPS (after GitHub verifies domain)

Path: **Cloudflare dashboard → hackerplanet.dev → SSL/TLS**

| Setting | Value | When |
|---------|-------|------|
| **Overview → encryption mode** | **Full (strict)** | After GitHub Pages shows custom domain verified and HTTPS available |
| **Edge Certificates → Always Use HTTPS** | **On** | After DNS + GitHub cert |
| **Edge Certificates → Minimum TLS Version** | **TLS 1.2** (or 1.3 if all clients support) | Anytime |
| **Edge Certificates → Automatic HTTPS Rewrites** | On | Recommended |

Until GitHub serves HTTPS on the custom domain, leave proxy **grey** and GitHub **Enforce HTTPS** off to avoid redirect loops.

Order of operations:

1. Grey-cloud DNS → GitHub verifies → GitHub **Enforce HTTPS** on
2. Optionally orange-cloud later with **Full (strict)** and origin understood (GitHub Pages)

---

## 3. Security / WAF (free tier)

Path: **Security** section in zone dashboard

| Setting | Recommended | Location |
|---------|-------------|----------|
| **Security Level** | **Medium** | Security → Settings |
| **Bot Fight Mode** | **On** | Security → Bots (free tier) |
| **Browser Integrity Check** | On | Security → Settings |
| **Challenge Passage** | Default (30 min) | Security → Settings |

Paid features (document only — not required for launch):

- WAF custom rules, rate limiting, Super Bot Fight Mode

---

## 4. Email Routing — hello@hackerplanet.dev

Path: **Email → Email Routing**

1. Select zone **`hackerplanet.dev`** → **Email Routing** → **Get started**
2. **Routing rules** → **Create address**
   - Custom address: **`hello`**
   - Destination: **your personal Gmail** (or Google Workspace inbox)
3. Cloudflare adds **MX** (and SPF **TXT**) automatically — confirm under **DNS → Records**
4. Send test mail to `hello@hackerplanet.dev`; reply-from testing optional
5. Update Stripe/PayPal business profiles with `hello@hackerplanet.dev`

Contact page already displays the address; deliverability works once MX propagates.

---

## 5. Hardening checklist (apply after HTTPS live)

Path: **Security**, **SSL/TLS**, **Rules** in zone dashboard.

| Control | Setting | Location |
|---------|---------|----------|
| **HSTS** | Enable · max-age 31536000 · includeSubDomains · preload (after stable HTTPS) | SSL/TLS → Edge Certificates |
| **TLS 1.3** | On | SSL/TLS → Edge Certificates |
| **Opportunistic Encryption** | On | SSL/TLS → Edge Certificates |
| **Security Headers** | Add via Transform Rules (see below) | Rules → Transform Rules → Modify response header |
| **Rate limiting** | `/api/*` or contact forms if proxied later | Security → WAF → Rate limiting rules |
| **Block AI bots** | On (free tier crawl control) | Security → Bots |
| **Email obfuscation** | Off for `hello@` mailto links on static site | Scrape Shield |
| **Hotlink protection** | On for `/images/` if orange-clouded | Scrape Shield |
| **DNSSEC** | Enable | DNS → Settings |
| **Account 2FA** | Required | My Profile → Authentication |
| **API tokens** | Scoped: Zone.DNS Edit + Zone.Read only; never commit | My Profile → API Tokens |

### Recommended response headers (Transform Rule)

When traffic is proxied through Cloudflare (optional, after GitHub HTTPS works):

| Header | Value |
|--------|-------|
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains; preload` |
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | `geolocation=(), microphone=(), camera=()` |

Static GitHub Pages already sets several headers; Cloudflare rules add defense-in-depth when orange-clouded.

### Redirect rule (canonical host)

**Rules → Redirect Rules** — after HTTPS:

- If hostname equals `www.hackerplanet.dev` → 301 to `https://hackerplanet.dev$1`

---

## 6. Optional hardening

| Item | Action |
|------|--------|
| **Page Rules / Redirect Rules** | Redirect `www` → apex (pick one canonical host) |

Example redirect rule (after HTTPS works): `www.hackerplanet.dev` → `https://hackerplanet.dev` (301).

---

## 7. Verify

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
.\.venv\Scripts\python scripts\verify_live_site.py
```

Checks `salvador-Data.github.io` always; checks `https://hackerplanet.dev/` when DNS resolves.

Manual:

```powershell
nslookup hackerplanet.dev
nslookup www.hackerplanet.dev
curl -I https://hackerplanet.dev/
```

---

## 8. Automation status (Cloudflare MCP)

Cursor **user-cloudflare** MCP authenticated in this workspace (account `Salvadordata@proton.me`).

| MCP action | Result |
|------------|--------|
| List zones | ✅ Zone **`hackerplanet.dev`** found — status **`pending`** (registration propagating) |
| Read DNS | ✅ One **A** record `@` → `185.199.108.153` — **proxied ON** (should be grey/DNS only for GitHub Pages) |
| Create/update DNS via API | ❌ Write failed: `Authentication error` (10000) — token lacks DNS write scope or zone pending |
| Security/TLS settings | ❌ Not automated — configure in dashboard |

**After auth, manual dashboard steps remain required** until API token has Zone.DNS Edit permission and zone status is **active**:

- [ ] Complete domain registration if still pending
- [ ] Set all four GitHub Pages **A** records (grey cloud / DNS only)
- [ ] Add **CNAME** `www` → `salvador-Data.github.io` (grey cloud)
- [ ] Turn off proxy (orange cloud) on apex records used for GitHub verification
- [ ] Wait for GitHub Pages DNS check → enable **Enforce HTTPS**
- [ ] Set SSL/TLS **Full (strict)**, **Always Use HTTPS**, min TLS 1.2
- [ ] Security Level **Medium**, **Bot Fight Mode** on
- [ ] Apply **§5 Hardening checklist** (HSTS, transform headers, Bot Fight Mode)
- [ ] Enable **Email Routing** for `hello@`

---

## Related docs

- [SETUP_CHECKLIST.md](SETUP_CHECKLIST.md) — go-live order (Voice → domain → email → payments)
- [HOSTING_OPTIONS.md](HOSTING_OPTIONS.md) — brand vs URL, DNS table
- [GITHUB_PAGES_SETUP.md](GITHUB_PAGES_SETUP.md) — Pages enable / troubleshoot
- [FIREWALL_BASELINE.md](FIREWALL_BASELINE.md) — BPI-R3 device firewall (separate from Cloudflare)

*Hacker Planet LLC · Philadelphia, PA · Authorized use only*
