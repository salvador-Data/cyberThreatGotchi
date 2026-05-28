# Drop-ship catalog — merchant guide

Hacker Planet LLC shop combines **direct fulfillment** (Stripe) with **partner drop-ship** (Etsy, Tindie, AliExpress). The static site links out to partners; you earn margin on Hacker Planet builds and optional affiliate revenue on external listings.

## Where things live

| File | Purpose |
|------|---------|
| `website/js/catalog.config.js` | Partner products, buy URLs, affiliate tags |
| `website/js/catalog.js` | Renders drop-ship sections on `shop.html` |
| `website/js/payments.config.js` | Stripe links for HPL custom builds |
| `website/shop.html` | Shop page layout |

## Hacker Planet direct sales (you ship)

Configure Stripe Payment Links for:

| Product | Price | Stripe key |
|---------|-------|------------|
| Boost Formula COD Field Kit | $85.99 | `boostFormulaCod` |
| Marauder GPS Custom Build | $175.00 | `marauderCustom175` |
| COD STL + KSS print pack | $12.00 | `codStlPack` |

```powershell
python scripts/check_payments.py
python scripts/sync_website_to_docs.py
```

## Partner drop-ship (they ship)

Edit `website/js/catalog.config.js`:

1. Replace `buyUrl` with your preferred listing (or your own Etsy store when you list there).
2. Add affiliate parameters when enrolled:

```javascript
affiliate: {
  aliexpress: "aff_fcid=YOUR_ID",
  etsy: "?ref=YOUR_REF",
  tindie: "",
},
```

3. Push to `main` — GitHub Pages workflow republishes automatically.

### Curated categories

- **Netgotchi** — OlleAdventures Etsy/Tindie (defensive network scanner)
- **Marauder** — CYD kits, GPS wardrive builds, battery mods
- **Mustache / custom Etsy builds** — search URL placeholder; paste specific listing URLs
- **AliExpress SBC deals** — Pi, Orange Pi, Banana Pi R3 Mini, ESP32 CYD boards
- **Free STLs** — CyberThreatGotchi enclosure + Printables Marauder CYD case

## Fulfillment workflow

```
Customer clicks "Buy on Etsy"  →  partner ships  →  you track affiliate (optional)
Customer pays via Stripe     →  you assemble   →  ship from Philly
Customer downloads STL       →  GitHub/Printables or Stripe digital delivery
```

## Legal

Listings for Marauder, WiFi Deauther, and wardrive gear must state **authorized lab / education use only**. Netgotchi and CyberThreatGotchi are defensive products.

## Validate before go-live

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
python -m pytest tests/test_website.py -v
python scripts/sync_website_to_docs.py
```

Open `website/shop.html` locally:

```powershell
cd website
python -m http.server 8080
```
