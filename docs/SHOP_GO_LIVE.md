# Shop go-live checklist — Hacker Planet LLC

One-page checklist to launch the Philadelphia shop + partner drop-ship catalog.

**Full business go-live (Voice, domain, email, then payments):** [SETUP_CHECKLIST.md](SETUP_CHECKLIST.md)

## 1. GitHub Pages (site live)

**Website on GitHub (source):** https://github.com/salvador-Data/cyberThreatGotchi/tree/main/website  

**Free public URL (after enable):** https://salvador-Data.github.io/cyberThreatGotchi/  

**Shop:** https://salvador-Data.github.io/cyberThreatGotchi/shop.html  

All links: [WEBSITE_LINKS.md](WEBSITE_LINKS.md) · Hosting & domain costs: [HOSTING_OPTIONS.md](HOSTING_OPTIONS.md)

The deploy workflow pushes `website/` → **`gh-pages`** branch. The public URL **404s** until you enable Pages once:

1. [Settings → Pages](https://github.com/salvador-Data/cyberThreatGotchi/settings/pages)
2. **Source:** Deploy from branch → **`gh-pages`** → **`/ (root)`**
3. Wait ~2 minutes → open [shop.html](https://salvador-Data.github.io/cyberThreatGotchi/shop.html)

Details: [GITHUB_PAGES_SETUP.md](GITHUB_PAGES_SETUP.md)

---

## 2. Validate configs (local)

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
.\.venv\Scripts\python scripts\check_shop.py
.\.venv\Scripts\python scripts\check_payments.py
.\.venv\Scripts\python -m pytest tests/test_website.py -v
.\.venv\Scripts\python scripts\sync_website_to_docs.py
git push origin main
```

| Script | Pass means |
|--------|------------|
| `check_shop.py` | All 28 products aligned across payments / shipping / catalog |
| `check_payments.py` | Every Stripe link filled + `demoMode: false` |

---

## 3. Stripe (checkout)

1. [Stripe Dashboard](https://dashboard.stripe.com) → enable **Tax** (Pennsylvania minimum)
2. Create **Payment Links** for every key in `website/js/payments.config.js`
3. Paste URLs → set `demoMode: false`
4. **Direct ship products:** add shipping rates or line-item shipping on those links

Full key table: [PAYMENTS.md](PAYMENTS.md)

---

## 4. Tax (Pennsylvania)

- Register/collect PA sales tax: [PA myPATH](https://mypath.pa.gov)
- Philadelphia orders (ZIP 191xx): **8%** (6% state + 2% local) on taxable goods
- Shop calculator is an **estimate** — Stripe Tax at checkout is authoritative

Details: [SHIPPING_AND_TAX.md](SHIPPING_AND_TAX.md)

---

## 5. Fulfillment playbooks

| Order type | What you do |
|------------|-------------|
| **Direct (Philly)** | Pack & ship from Philadelphia — Sabreto Akachi, CrackBot CYD, CTG kits |
| **Partner drop-ship** | Order from `supplierUrl` in `catalog.config.js` → ship to customer |
| **Digital** | Email download link after payment |

Step-by-step: [ORDER_FULFILLMENT.md](ORDER_FULFILLMENT.md)

---

## 6. Optional payment methods

- PayPal / Venmo: `paypal.clientId` in `payments.config.js`
- Cash App: `cashapp.cashtag`
- Pro auto-keys: `python scripts/stripe_provision.py`

---

## Live URLs (after Pages enabled)

| Page | URL |
|------|-----|
| Shop | https://salvador-Data.github.io/cyberThreatGotchi/shop.html |
| Home | https://salvador-Data.github.io/cyberThreatGotchi/ |

---

*Hacker Planet LLC · Philadelphia, PA*
