# Kickstarter visual brief — creator / designer

**Brand:** Hacker Planet LLC · **Product:** CyberThreatGotchi / Cipherhorn  
**Site reference:** [hackerplanet.dev](https://hackerplanet.dev) · CSS: `website/css/style.css`  
**Campaign copy:** [KICKSTARTER_CAMPAIGN.md](KICKSTARTER_CAMPAIGN.md)

---

## Brand palette (match site CSS vars)

| Token | Hex | Use |
|-------|-----|-----|
| `--bg` | `#0a0e14` | Page background, video letterbox |
| `--bg-elevated` | `#121820` | Cards, tier panels |
| `--panel` | `rgba(22, 27, 34, 0.72)` | Frosted overlays |
| `--panel-border` | `rgba(255, 255, 255, 0.08)` | Card strokes |
| `--ink` | `#e6edf3` | Primary text |
| `--muted` | `#8b949e` | Secondary text, captions |
| `--accent` | `#00b48c` | CTAs, highlights, "live" indicators |
| `--accent-glow` | `rgba(0, 180, 140, 0.35)` | Hero gradients |
| `--magenta` | `#d2a8ff` | Secondary accent (ecosystem badges) |
| `--warn` | `#f85149` | Threat / alert states (sparingly) |
| `--philly-gold` | `#c9a227` | Philly maker badge, stretch goals |

**Typography**

| Role | Font | Weight |
|------|------|--------|
| Display / headlines | **Syne** | 600–800 |
| Body / UI | **DM Sans** | 400–700 |

Google Fonts link (from site):

```
Syne:wght@500;600;700;800 & DM+Sans:opsz,wght@9..40,400;9..40,500;9..40,600;9..40,700
```

**Background texture:** 48px grid at 3% white opacity + radial accent glows (see `.grid-bg` + `body::before` in style.css).

---

## Deliverable specs

### 1. Project thumbnail (Kickstarter)

| Spec | Value |
|------|-------|
| Size | **1024 × 576** px (16:9) — KS crops to square in some views; keep subject center-safe |
| Safe zone | Center 576×576 for square crop |
| Content | Cipherhorn e-ink face on hardware, subtle `#0a0e14` background, accent glow |
| Text | Max 5 words: "Edge IPS · Tamagotchi Soul" |
| Avoid | Cartoon-only OG without hardware · stock hacker hoodies · skull clip art |

**Source photo:** `website/images/products/direct-core-kit.jpg`  
**Alt:** `website/images/products/cyphertek-rache-product.jpg`

---

### 2. Campaign banner

| Spec | Value |
|------|-------|
| Size | **1200 × 675** px (16:9) |
| Use | Kickstarter hero, YouTube thumb, LinkedIn link preview |
| Layout | Left 40%: headline + sub · Right 60%: product hero on grid bg |
| Headline | Syne 800, `#e6edf3`, 48–56px |
| Sub | DM Sans 400, `#8b949e`, 20–24px |
| Badge | Pill: "Philadelphia · Authorized lab gear" — `#c9a227` border |

**Export:** PNG + WebP · sRGB · < 500 KB WebP for site

---

### 3. Reward tier cards (×8)

| Spec | Value |
|------|-------|
| Size | **800 × 1000** px (4:5) each |
| Background | `#121820` + 1px `#ffffff14` border, `border-radius: 16px` |
| Structure | Top: product photo · Middle: tier name (Syne 700) · Price (accent) · Bottom: 3 bullet inclusions |
| Photo sources | See matrix below |

| Tier | Image asset |
|------|-------------|
| Digital | Sprite sheet / STL render |
| Early Bird / Core | `direct-core-kit.jpg` |
| Field Pack | Core + Cardputer composite |
| Pro Lab | Core + CYD `direct-cyd-standard.jpg` |
| Bench Lab | `mr-pac-bot-product.png` |
| Meshtastic | `ds-meshtastic-case.jpg` or catalog banner |
| MSP Pilot | Three-kit flat lay mock |

**Footer line on every card:** "Defensive · Authorized networks only" — 12px muted

---

### 4. Hero video

| Spec | Value |
|------|-------|
| Duration | **60–90 sec** (script: 75s in campaign doc) |
| Resolution | **1920 × 1080** master · export **1080 × 1920** Shorts cut |
| Frame rate | 24 or 30 fps |
| Color grade | Cool shadows, teal accent lift — match site |
| Lower thirds | Syne 600, accent bar left 4px |
| End card | 5 sec — logo, URL, KS CTA, disclaimer |
| Captions | Burn-in for Shorts · SRT for YouTube long |

**Shot list:** See [KICKSTARTER_CAMPAIGN.md](KICKSTARTER_CAMPAIGN.md) hero video table.

---

### 5. Stretch goal graphics (×5)

| Spec | Value |
|------|-------|
| Size | **1080 × 1080** px |
| Style | Icon + dollar threshold + one-line benefit |
| Colors | Locked = muted · Unlocked = accent glow |

---

### 6. Social crops

| Platform | Size | Notes |
|----------|------|-------|
| Reddit banner | 1920 × 384 | `docs/images/social/reddit-banner.png` refresh |
| X header | 1500 × 500 | Product left, text right |
| LinkedIn cover | 1128 × 191 | Minimal text |
| Instagram square | 1080 × 1080 | Use existing `square-*.png` style |
| YouTube Shorts | 1080 × 1920 | Hook text top 20% safe zone |

Regenerate programmatic base cards:

```bash
python assets/marketing/generate_graphics.py
```

---

## Photo & video inventory (repo)

| Path | Use |
|------|-----|
| `website/images/hero-cybertech.png` | Banner background |
| `website/images/og-cybertech.png` | OG fallback |
| `website/images/products/direct-core-kit.jpg` | Core tier |
| `website/images/products/cyphertek-rache-product.jpg` | CTG product page |
| `website/images/products/direct-cyd-standard.jpg` | CYD |
| `website/images/products/mr-pac-bot-product.png` | CrackBot |
| `website/images/products/ds-meshtastic-case.jpg` | Meshtastic |
| `docs/images/og-cyberthreatgotchi.png` | Social share |
| `docs/images/social/` | Profile crops |

**Do not use on shop/checkout flows:** cartoon OG assets (see `test_shop_flows_avoid_mascot_og_assets`).

---

## Copy overlays (Canva-style — text in markdown)

See [assets/marketing/kickstarter/TEXT_OVERLAYS.md](../../assets/marketing/kickstarter/TEXT_OVERLAYS.md).

---

## Wording constraints (public assets)

| Use | Don't use |
|-----|-----------|
| Partner fulfillment | Dropship, drop-ship |
| Philadelphia, PA | Warehouse street address |
| Authorized lab / defensive | "Hack anything," illegal framing |
| Open source (MIT) | "Unhackable," "military grade" |
| Cipherhorn / CyberThreatGotchi | ThreatGotchi, Cypertech typos |

---

## File naming convention

```
assets/marketing/kickstarter/
  ks-thumb-1024x576.png
  ks-banner-1200x675.png
  ks-tier-core-800x1000.png
  ks-stretch-50k-1080.png
  ks-endcard-1920x1080.png
```

---

## Approval checklist

- [ ] Palette matches CSS vars (eyedropper `#00b48c`, `#0a0e14`)
- [ ] Syne + DM Sans only
- [ ] Hardware visible in hero (not mascot-only)
- [ ] Authorized-use line on tier cards
- [ ] No warehouse address
- [ ] No dropship wording
- [ ] Square-safe crop for KS thumbnail
- [ ] Prices match [KICKSTARTER_REWARDS_TABLE.md](KICKSTARTER_REWARDS_TABLE.md)

---

*Hacker Planet LLC · Salvador Data · salvadorData@proton.me*
