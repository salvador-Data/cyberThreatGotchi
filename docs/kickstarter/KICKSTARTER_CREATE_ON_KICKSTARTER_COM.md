# Create CyberThreatGotchi on kickstarter.com â€” today

**Salvador Data Â· Hacker Planet LLC Â· Philadelphia, PA**

I use this runbook the day I create the live Kickstarter project. Paste copy from [KICKSTARTER_DASHBOARD_PASTE.md](KICKSTARTER_DASHBOARD_PASTE.md). After approval, I wire the live URL into the website.

**Related:** [KICKSTARTER_LAUNCH_PLAN.md](../KICKSTARTER_LAUNCH_PLAN.md) Â· [BUSINESS_PROJECTIONS.md](../BUSINESS_PROJECTIONS.md) Â· Preview page [hackerplanet.dev/kickstarter.html](https://hackerplanet.dev/kickstarter.html)

---

## Before I start (15 minutes)

- [ ] Bank account ready (US checking for Hacker Planet LLC payouts)
- [ ] Government ID for identity verification
- [ ] Hero image: `website/images/products/direct-core-kit.jpg`
- [ ] Hero video uploaded to YouTube/Vimeo (unlisted OK) or ready to upload to Kickstarter
- [ ] Paste doc open: `docs/kickstarter/KICKSTARTER_DASHBOARD_PASTE.md`

---

## Step 1 â€” Open Kickstarter start flow

In my browser:

1. Go to **https://www.kickstarter.com/start**
2. Log in (or **Sign up** with salvadorData@proton.me)
3. Click **Start a project**

Kickstarter walks me through Basics â†’ Story â†’ Rewards â†’ Payment â†’ Submit.

---

## Step 2 â€” Account verification

If Kickstarter prompts:

1. Confirm email from Kickstarter inbox
2. Add profile name: **Salvador Data**
3. Connect Facebook optionally (I skip if I prefer)
4. Complete **Verify your identity** when prompted (photo ID)

I do not publish until identity and bank steps show green in the dashboard.

---

## Step 3 â€” Project basics

| Field | Value |
|-------|-------|
| Project title | `CyberThreatGotchi â€” Edge IPS with a Tamagotchi Soul` |
| Subtitle | `Real threats in. Mood out. Evidence saved. Philly-made edge IPS.` |
| Category | Technology â†’ Hardware |
| Location | Philadelphia, PA, United States |
| Funding goal | **$35,000** USD |
| Duration | **30 days** |
| Project URL slug | Prefer `cyberthreatgotchi-edge-ips-tamagotchi` under creator **hackerplanet** if available |

**Placeholder URL** (until live slug confirmed):

`https://www.kickstarter.com/projects/hackerplanet/cyberthreatgotchi-edge-ips-tamagotchi`

After Kickstarter assigns the real URL, I copy it from the browser address bar on the project preview page.

---

## Step 4 â€” Story tab (paste description)

1. Open [KICKSTARTER_DASHBOARD_PASTE.md](KICKSTARTER_DASHBOARD_PASTE.md)
2. Copy the **Project description** block into Kickstarter **Story**
3. Upload hero video or embed link
4. Add 3â€“5 images (core kit, e-ink mood, Cardputer, assembly bench)
5. Paste **Risks and challenges** into the Risks section
6. Paste **Environmental commitments** into Environmental commitments
7. Add FAQ entries from the paste doc

---

## Step 5 â€” Rewards tab (exact tiers)

Create each reward from the paste doc table. Amounts must match shop/Kickstarter preview (commit `b3176e2`):

| Tier | Pledge | Limit |
|------|--------|-------|
| Digital Defender | $15 | âˆž |
| Early Bird Core | $149 | 50 |
| Cipherhorn Core | $219 | 300 |
| Field Pack | $279 | 150 |
| Cardputer Field Duo | $169 | 75 |
| Pro Lab | $529 | 40 |
| Bench Lab | $499 | 25 |
| Meshtastic Relay | $159 | 75 |
| MSP Pilot | $2,499 | 10 |

For each tier:

1. **Reward title** and **Pledge amount** as above
2. **Quantity limit** where listed
3. **Description** from paste doc snippets
4. **Estimated delivery** â€” Oct 2026 (Core), Nov 2026 (Field/Pro), etc. per paste doc timeline
5. **Shipping** â€” Digital: none. Hardware: "Ships to certain countries" â†’ US + select EU/CA/UK for Core/Field/Digital only (see campaign doc)

---

## Step 6 â€” Payment â€” connect bank

1. Kickstarter dashboard â†’ **Payment** section
2. Connect **Stripe** (Kickstarter's payment partner) with Hacker Planet LLC bank details
3. Confirm tax/entity info for US LLC
4. Save â€” wait for "Payment processing ready" status

I never put bank secrets in the repo â€” dashboard only.

---

## Step 7 â€” Wire live URL to hackerplanet.dev

When Kickstarter shows my project preview URL (even pre-launch), I update the site config.

Open the config file in my editor:

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

Replace the placeholder in `website/js/kickstarter.config.js`:

- Key: **`kickstarterProjectUrl`**
- Value: my exact Kickstarter URL (e.g. `https://www.kickstarter.com/projects/hackerplanet/cyberthreatgotchi-edge-ips-tamagotchi` or whatever slug Kickstarter assigned)

Sync website to docs mirror:

```powershell
python scripts/sync_website_to_docs.py
```

Run tests:

```powershell
pytest tests/test_website.py -v -k kickstarter
```

Commit and push when ready (see team workflow).

**Live behavior:** When `kickstarterProjectUrl` is no longer the placeholder slug, [kickstarter.html](https://hackerplanet.dev/kickstarter.html) shows **Live on Kickstarter** and **Back this project on Kickstarter** opens kickstarter.com in a new tab.

---

## Step 8 â€” Submit for review

1. Kickstarter â†’ **Review** / **Submit for review**
2. Fix any validation errors (image size, reward shipping, video)
3. Submit â€” review typically **1â€“3 business days**
4. I stay in **Preview** mode until approved; I share preview link with trusted reviewers only

---

## Step 9 â€” Launch day (after approval)

1. Kickstarter â†’ **Launch** at scheduled time (see [KICKSTARTER_LAUNCH_PLAN.md](../KICKSTARTER_LAUNCH_PLAN.md) â€” target 10:00 AM ET Day 1)
2. Confirm `kickstarterProjectUrl` in config matches live URL
3. Deploy website (GitHub Pages / hackerplanet.dev)
4. Send preview email from `assets/marketing/kickstarter/kickstarter-preview.html` with `{{kickstarterProjectUrl}}` replaced
5. Post per [KICKSTARTER_SOCIAL_LAUNCH.md](KICKSTARTER_SOCIAL_LAUNCH.md)

---

## Quick reference â€” config key

| Item | Location |
|------|----------|
| Config key name | `kickstarterProjectUrl` |
| Authoritative file | `website/js/kickstarter.config.js` |
| Also documented | `website/js/payments.config.example.js`, `website/seo/site.json` |
| Paste pack | `docs/kickstarter/KICKSTARTER_DASHBOARD_PASTE.md` |

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Identity verification pending | Wait 24â€“48h; re-upload clear ID photo |
| Bank connection failed | Confirm LLC legal name matches bank account |
| Reward shipping errors | Set digital tier to "No shipping"; hardware tiers need weight estimates |
| Site still shows "Notify me" | URL still contains placeholder slug â€” paste exact live Kickstarter URL |

---

*Defensive use only Â· Authorized networks only Â· Â© Hacker Planet LLC*
