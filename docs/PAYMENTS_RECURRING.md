# Recurring payments — Pro feed & MSP retainers

Stripe subscriptions, Customer Portal, and optional PayPal subscription plans for Hacker Planet LLC.

**PCI scope:** SAQ-A — card data stays on Stripe/PayPal hosted pages. Our static site never receives PAN.

---

## Architecture

| Flow | Stripe | PayPal (optional) |
|------|--------|-------------------|
| CTG Pro $9/mo, $99/yr | Payment Link (recurring) | Subscription plan ID |
| MSP Monitor/Defend/Harden | Payment Link (recurring) | Subscription plan ID |
| Returning customer billing | Customer Portal URL | PayPal account settings |
| Ship-to convenience | Browser `localStorage` only | N/A |

Webhook provisioning: `scripts/stripe_provision.py` with `CTG_STRIPE_WEBHOOK_SECRET`.

---

## 1. Stripe Customer Portal

One portal link serves all subscribers (Pro + MSP).

1. Open [Stripe Dashboard](https://dashboard.stripe.com/settings/billing/portal).
2. Enable **Customers can update payment methods**.
3. Enable **Customers can cancel subscriptions** (optional grace period).
4. Enable **Invoice history**.
5. Copy the portal link (format `https://billing.stripe.com/p/login/...`).
6. Paste into `website/js/payments.config.js`:

```javascript
stripeCustomerPortal: "https://billing.stripe.com/p/login/xxxxxxxx",
```

The shop renders **Manage subscriptions & invoices** when this URL is set. Returning customers manage cards and cancellations on Stripe — not on our servers.

---

## 2. Pro subscription Payment Links

Create **Products** in Stripe with **Recurring** pricing:

| Config key | Product | Price |
|------------|---------|-------|
| `proMonthly` | CTG Pro Feed | $9/month |
| `proYearly` | CTG Pro Feed | $99/year |

For each Payment Link:

1. Set **After payment** → redirect to `https://hackerplanet.dev/shop.html#pro-feed` (or GitHub Pages URL).
2. Add metadata (optional): `stripe_key` = `proMonthly` or `proYearly`.
3. Enable **Stripe Tax** for digital services in PA.
4. Paste URLs into `stripePaymentLinks` in `payments.config.js`.

---

## 3. MSP retainer subscription Payment Links

Match [services.html](../website/services.html) Blue Team tiers:

| Config key | Tier | Price |
|------------|------|-------|
| `mspMonitor` | Monitor | $1,500/month |
| `mspDefend` | Defend | $2,750/month |
| `mspHarden` | Harden | $4,500/month |

Use Stripe **Payment Links** with recurring monthly billing. Typical contract: 12-month term (enforce via Stripe subscription settings or manual onboarding).

MSP subscriptions do **not** auto-provision CTG Pro API keys — operators onboard after intake. Pro keys are only provisioned for `proMonthly` / `proYearly` checkout sessions.

---

## 4. Stripe webhooks (Pro API keys)

Point webhook endpoint to my provisioner:

- Local: `python scripts/stripe_provision.py --port 9091`
- Production: reverse proxy to same path `/stripe/webhook`

Subscribe to events:

| Event | Action |
|-------|--------|
| `checkout.session.completed` | Provision Pro API key when mode=subscription or metadata stripe_key is pro* |
| `customer.subscription.deleted` | Revoke Pro API key |
| `customer.subscription.updated` | Revoke if status is canceled/unpaid/incomplete_expired |
| `invoice.payment_failed` | Log only (Stripe retries; portal lets customer fix card) |

Signature verification uses `constant_time_equal` via `verify_stripe_webhook()` in `core/security.py`.

```powershell
$env:CTG_STRIPE_WEBHOOK_SECRET = "whsec_..."
python scripts/stripe_provision.py --port 9091
```

Fulfillment (hardware) uses a separate route: `POST /api/fulfillment/webhook` on the CTG web server — see [ORDER_FULFILLMENT.md](ORDER_FULFILLMENT.md).

---

## 5. PayPal subscriptions (optional)

Optional — PayPal for Pro or MSP billing:

1. [PayPal Developer](https://developer.paypal.com/dashboard/) → **Subscriptions** → create plans.
2. Copy plan IDs (`P-XXXXXXXX`) into `payments.config.js`:

```javascript
paypalSubscriptions: {
  proMonthly: { planId: "P-xxxxxxxx" },
  proYearly: { planId: "P-xxxxxxxx" },
  mspMonitor: { planId: "P-xxxxxxxx" },
  mspDefend: { planId: "P-xxxxxxxx" },
  mspHarden: { planId: "P-xxxxxxxx" },
},
paypal: { clientId: "YOUR_CLIENT_ID", currency: "USD" },
```

3. Shop loads PayPal SDK with `vault=true&intent=subscription` when any plan ID is set.
4. PayPal subscription lifecycle is managed in PayPal Dashboard — no card data on our site.

---

## 6. Returning customer prefill (localStorage)

`website/js/customer-prefill.js` stores in the browser only:

- Email (prefilled on Stripe Payment Links via `?prefilled_email=`)
- Name, city, state, ZIP for shipping estimator

**Never stored:** card number, CVV, Stripe customer ID, PayPal billing agreement tokens.

Storage key: `hpl_customer_prefill_v1`. User can clear via **Clear saved ship-to** on the shop page.

---

## 7. Validate & deploy

```powershell
cd c:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
python scripts/check_payments.py
```

```powershell
python scripts/check_shop.py
```

```powershell
python scripts/sync_website_to_docs.py
```

Set `demoMode: false` when all links are live, then push to `main`.

---

## My Stripe Dashboard checklist

Run these in order (one command per step when using PowerShell locally):

### Portal & products

1. Open Stripe Dashboard → Settings → Billing → Customer portal → configure features → copy portal URL.
2. Create Product **CTG Pro Feed** with recurring prices $9/mo and $99/yr.
3. Create Payment Links for `proMonthly` and `proYearly` → paste into `payments.config.js`.
4. Create Products for **MSP Monitor**, **MSP Defend**, **MSP Harden** with monthly recurring prices.
5. Create Payment Links for `mspMonitor`, `mspDefend`, `mspHarden` → paste into `payments.config.js`.

### Tax & hardware links

6. Enable Stripe Tax → add Pennsylvania nexus.
7. Create one-time Payment Links for every hardware `stripeKey` in [PAYMENTS.md](PAYMENTS.md) → paste URLs.
8. For each partner `ds*` link, add metadata `stripe_key` matching the config property name.

### Webhooks & go-live

9. Developers → Webhooks → Add endpoint → URL `https://YOUR-HOST/stripe/webhook` → select subscription events above.
10. Copy signing secret → `$env:CTG_STRIPE_WEBHOOK_SECRET = "whsec_..."`.
11. Set `stripeCustomerPortal` and all `stripePaymentLinks` in `payments.config.js`.
12. Set `demoMode: false` → run `python scripts/check_payments.py` (exit 0) → sync website → push.

---

*Hacker Planet LLC · Philadelphia, PA*
