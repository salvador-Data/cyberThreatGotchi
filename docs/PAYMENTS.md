# Payments setup — Hacker Planet LLC website

Configure checkout on the static GitHub Pages site (`website/` and mirrored `docs/web/`).

**Supported methods**

| Method | Provider | Setup |
|--------|----------|--------|
| Credit & debit cards | Stripe Payment Links | Stripe Dashboard |
| Apple Pay | Stripe (auto on Payment Links) | Enable in Stripe → Settings → Payment methods |
| Google Pay | Stripe | Same as Apple Pay |
| PayPal | PayPal JS SDK or PayPal.Me | PayPal Developer + Business account |
| Venmo | PayPal SDK (`enable-funding=venmo`) or direct link | US PayPal business + Venmo username |
| Cash App | Direct pay URL | Cash App $Cashtag |

---

## 1. Stripe (cards, debit, Apple Pay)

1. Create account at [stripe.com](https://stripe.com).
2. **Products** → create products matching shop tiers (Digital $15, Pro $9/mo, etc.).
3. For each product: **Create payment link** (one-time or subscription).
4. Copy each link into `website/js/payments.config.js`:

```javascript
window.HPL_PAYMENTS = {
  demoMode: false,
  stripePaymentLinks: {
    digital: "https://buy.stripe.com/xxxx",
    proMonthly: "https://buy.stripe.com/yyyy",
    proYearly: "https://buy.stripe.com/zzzz",
    coreKit: "https://buy.stripe.com/aaaa",
    fieldPack: "https://buy.stripe.com/bbbb",
  },
  // ...
};
```

5. Stripe Dashboard → **Settings → Payment methods** → enable **Apple Pay**, **Google Pay**, **Link**.

6. After editing config, sync to docs mirror:

```bash
python scripts/sync_website_to_docs.py
```

**Subscriptions (Pro feed):** Create recurring prices on Stripe products. After payment, provision `CTG_PRO_API_KEY` manually or via Stripe webhook → your backend (future: `scripts/stripe_provision.py`).

---

## 2. PayPal (PayPal + Venmo buttons)

1. [PayPal Developer](https://developer.paypal.com/dashboard/applications) → Create app → copy **Client ID** (live or sandbox).
2. Add to `payments.config.js`:

```javascript
paypal: {
  clientId: "YOUR_CLIENT_ID",
  currency: "USD",
},
```

3. Venmo appears automatically for US buyers when `enable-funding=venmo` is set (already in `payments.js`).

**Fallback without SDK** — PayPal.Me:

```javascript
paypalMe: { username: "YourPayPalMe" },
```

Generates `https://paypal.me/YourPayPalMe/15` per tier.

---

## 3. Venmo (direct link)

```javascript
venmo: { username: "YourVenmoUsername" },
```

Opens Venmo pay flow with amount and note pre-filled. Works even without PayPal SDK.

---

## 4. Cash App

```javascript
cashapp: { cashtag: "HackerPlanetLLC" },
```

Generates `https://cash.app/$HackerPlanetLLC/15` per product price.

---

## 5. Deploy

1. Edit `website/js/payments.config.js` (set `demoMode: false`).
2. Run sync: `python scripts/sync_website_to_docs.py`
3. Commit and push — GitHub Actions deploys Pages from `website/`.
4. Repo browsers see the same files under `docs/web/`.

**GitHub Pages URL:** https://salvador-Data.github.io/cyberThreatGotchi/shop.html

---

## Security notes

| OK in config (public) | Never commit |
|----------------------|--------------|
| Stripe Payment Link URLs | Stripe **secret** key (`sk_live_…`) |
| PayPal **client ID** | PayPal **secret** |
| Cashtag, Venmo username | Webhook signing secrets |

Payment Links are designed to be shared. Rotate a link from Stripe Dashboard if leaked.

---

## Test checklist

- [ ] Stripe test link opens Checkout with card + Apple Pay (Safari/iOS)
- [ ] PayPal sandbox button completes test payment
- [ ] Venmo button visible on mobile (US)
- [ ] Cash App link opens app with correct amount
- [ ] `demoMode: false` hides demo placeholder text

---

*Hacker Planet LLC · Philadelphia, PA*
