# Kickstarter dashboard — paste pack

**Hacker Planet LLC** · Salvador Data · Philadelphia, PA  
Paste sections into [kickstarter.com](https://www.kickstarter.com/start) project editor.  
Reward amounts match commit `b3176e2` tiers and [KICKSTARTER_CAMPAIGN.md](KICKSTARTER_CAMPAIGN.md).

After approval, set `kickstarterProjectUrl` in `website/js/kickstarter.config.js` to your live URL.

---

## Project title

```
CyberThreatGotchi — Edge IPS with a Tamagotchi Soul
```

## Subtitle (60 chars max)

```
Real threats in. Mood out. Evidence saved. Philly-made edge IPS.
```

## Category

- **Technology** → **Hardware**

## Location

```
Philadelphia, PA, United States
```

## Funding goal

```
35000
```

USD · All-or-nothing.

## Campaign duration

```
30
```

days (adjust in dashboard).

---

## Project description (Story tab)

Paste as rich text / markdown where Kickstarter accepts it:

```markdown
## Real threats in. Mood out. Evidence saved.

Your network is talking all day. Most dashboards whisper. **CyberThreatGotchi** is an open-source edge IPS on the **Banana Pi BPI-R3 Mini** — with **Cipherhorn**, a unicorn CISO on e-ink that *reacts* to scored threats while logging evidence you can export.

Built in **Philadelphia** by **Hacker Planet LLC**. Defensive use on networks you own or are authorized to monitor.

---

### What you're backing

Each reward maps to a **real SKU** — no mystery boxes.

**Cipherhorn Core** — BPI-R3 Mini + Waveshare 2.13″ e-ink HAT + PETG enclosure + pre-flashed SD + PSU. Philadelphia assembly with burn-in.

**Field Pack** — Core kit + M5 Cardputer with **Remote Possibility** firmware (polls CTG `/api/status` over Wi‑Fi).

**Cardputer Field Duo** — Two M5 Cardputers: **Remote Possibility** + **BLE Bot**, both with **M5 OS** launcher.

**Pro Lab** — Field Pack + CYD Field Build Standard + 1 year Pro threat feed.

**Bench Lab** — Mr. CrackBot AI Nano Jetson bench (separate product line from CYD).

**Meshtastic Relay** — Heltec V3 node + field case + CTG webhook guide. **Partner fulfillment** (verified maker, not Philadelphia warehouse).

**MSP Pilot** — 3× Field Pack + 90-min onboarding + 6 months Pro feed (3 sites).

**Digital Defender** — STL zip, sprite pack, backer wallpapers — instant email delivery.

---

### Why it's real (not cosplay security)

- Live capture → signature/YARA scoring → optional ClamAV → **iptables block** on Linux
- SQLite logging + **tamper-evident audit chain** (v1.1+)
- MIT open source: [github.com/salvador-Data/cyberThreatGotchi](https://github.com/salvador-Data/cyberThreatGotchi)
- Run without hardware: `python main.py --simulation --web`

The Tamagotchi UI is the *interface*, not the engine.

---

### The team

**Salvador Data** — founder, assembler, public face of Hacker Planet LLC. Small Philly shop: transparent lead times, direct replies, firmware you can read.

Site: [hackerplanet.dev](https://hackerplanet.dev) · Contact: salvadorData@proton.me

---

### Timeline (honest)

| Tier | Target ship |
|------|-------------|
| Digital | Within 7 days of campaign end |
| Early Bird / Core | Oct 2026 (US wave 1) |
| Field Pack / Cardputer Duo / Pro Lab | Nov 2026 |
| Bench Lab | Nov–Dec 2026 |
| Meshtastic Relay | 8–12 weeks post-survey (partner batch) |
| MSP Pilot | Dec 2026 – Jan 2027 |

Bi-weekly updates during production. Weekly first month post-fund.

**Shipping:** Not included in pledge for Philadelphia-built kits; US zones ~$9–$18 in post-campaign survey. Meshtastic tier includes partner shipping in pledge.

---

### Stretch goals

- **$50,000** — LCD face STL pack + ST7789 HAT coupon for all Core+ backers
- **$75,000** — Meshtastic → CTG webhook bridge beta firmware
- **$100,000** — Backer workshop series (3 live streams)
- **$125,000** — Philly maker meetup + backer lab day
- **$150,000** — Signed enclosure serial + 18-month hardware defect warranty

---

### Authorized use

CyberThreatGotchi is a **defensive edge sensor** for networks you own or have **written permission** to monitor. We do not ship pre-configured attack payloads against third parties. Backers acknowledge authorized use in the post-campaign survey.

Preview page: [hackerplanet.dev/kickstarter.html](https://hackerplanet.dev/kickstarter.html)
```

---

## Risks and challenges

```
Supply chain — BPI-R3 Mini and Waveshare e-ink HAT have seen 8–12 week OEM lead times. We maintain alternate supplier quotes and will communicate slips before silent delays.

Firmware — MIT open source. Backer units ship pinned to a tested release tag (v1.1.x+). Updates via GitHub with documented breaking changes.

Partner fulfillment (Meshtastic) — Meshtastic Relay tier ships from independent verified makers, not our Philadelphia bench. We batch-order after survey; customs may add time for non-US backers.

Scale — If we exceed 300 Core units, assembly moves to a second Philly print/flash shift (~3 weeks added, communicated in updates).

Regulatory — Defensive lab tools only. We may restrict certain destinations for radio hardware (Meshtastic). Export compliance is the backer's responsibility where applicable.
```

---

## Environmental commitments

```
We design for repair and transparency:

• Open-source firmware and enclosure STLs on GitHub — owners can reflash, reprint, and extend life of the device.
• PETG enclosures printed locally in Philadelphia; we minimize foam and single-use plastic in pack-out where safe for transit.
• Partner-fulfilled Meshtastic nodes ship from verified makers with existing packaging standards; we batch orders to reduce split shipments.
• End-of-life: SD cards and boards are standard components; we publish disassembly notes in backer updates for responsible e-waste routing.

We are a small shop — not claiming carbon-neutral certification in v1, but we document BOM and ship methods honestly in campaign updates.
```

---

## Reward tiers (create each in Rewards tab)

| Title | Pledge USD | Quantity limit | Shipping | Notes |
|-------|------------|----------------|----------|-------|
| Digital Defender | **$15** | unlimited | Digital | STLs, sprites, backer badge — email delivery |
| Early Bird Core | **$149** | **50** | Ship to backers | Core kit ($219 value) + 3 mo Pro feed |
| Cipherhorn Core | **$219** | **300** | Ship to backers | Core kit + quick-start |
| Field Pack | **$279** | **150** | Ship to backers | Core + Remote Possibility Cardputer (M5 OS) |
| Cardputer Field Duo | **$169** | **75** | Ship to backers | Remote Possibility + BLE Bot (2× M5 OS Cardputer) |
| Pro Lab | **$529** | **40** | Ship to backers | Field Pack + CYD Standard + 1 yr Pro feed |
| Bench Lab | **$499** | **25** | Ship to backers | Mr. CrackBot Jetson bench (standalone) |
| Meshtastic Relay | **$159** | **75** | Ship to backers | Heltec V3 + case + webhook guide — partner fulfillment |
| MSP Pilot | **$2,499** | **10** | Ship to backers | 3× Field Pack + 90-min onboarding + 6 mo Pro (3 sites) |

### Reward description snippets (paste per tier)

**Digital Defender ($15)**

```
Instant email: STL zip, Cipherhorn sprite pack, backer wallpapers. No hardware. MIT core repo free on GitHub — this tier supports the project and gets you print-ready assets.
```

**Early Bird Core ($149) — limit 50**

```
Cipherhorn Core kit (BPI-R3 Mini + e-ink + enclosure + flashed SD + PSU) — $219 retail value. Includes 3 months CTG Pro threat feed. Philadelphia assembly, burn-in before ship. Shipping charged in post-campaign survey (US ~$9–$18).
```

**Cipherhorn Core ($219) — limit 300**

```
Full Cipherhorn Core kit: Banana Pi BPI-R3 Mini, Waveshare 2.13″ e-Paper HAT, PETG enclosure, 32 GB pre-flashed SD, UL-listed PSU, quick-start card. Philadelphia assembly.
```

**Field Pack ($279) — limit 150**

```
Everything in Cipherhorn Core + M5Stack Cardputer with Remote Possibility firmware (M5 OS launcher) + printed field pairing guide. Poll CTG status away from the desk.
```

**Cardputer Field Duo ($169) — limit 75**

```
Two M5Stack Cardputers — one Remote Possibility, one BLE Bot. Both pre-flashed with M5 OS + respective app firmware. Retail separate: $189.98. Authorized lab workflows only for BLE Bot.
```

**Pro Lab ($529) — limit 40**

```
Field Pack + CYD Field Build Standard ($89.99 value) + 1 year CTG Pro threat feed. Full desk + pocket + display lab bundle.
```

**Bench Lab ($499) — limit 25**

```
Mr. CrackBot AI Nano — NVIDIA Jetson Nano 4GB bench with CYD UI shell. GPU hashcat path for authorized lab scope. 3–5 day assembly queue per unit. Not included in Core or Field tiers.
```

**Meshtastic Relay ($159) — limit 75**

```
Heltec V3 Meshtastic node + field case + CTG webhook integration guide. Partner fulfillment — ships from verified maker 8–12 weeks after survey. LoRa mesh for off-grid status relay on your authorized mesh.
```

**MSP Pilot ($2,499) — limit 10**

```
Three Field Packs + 90-minute MSP onboarding (multi-site deploy, webhook → SIEM notes) + six months Pro feed for three sites. Channel seed tier — retainer services quoted separately at hackerplanet.dev/services.html
```

---

## FAQ (paste into FAQ section)

1. **Is this a real IPS or a toy?** Real stack: capture, YARA/signatures, optional ClamAV, iptables block, SQLite + audit chain. The Tamagotchi UI is the interface.

2. **Can I run it without hardware?** Yes — clone GitHub, `python main.py --simulation --web`, or Docker.

3. **Is CrackBot in the Core kit?** No. CrackBot is the separate $499 Bench Lab tier.

4. **What's partner fulfillment?** Meshtastic Relay ships from verified independent makers we batch-order after the campaign.

5. **Shipping costs?** Not in pledge for Philly-built kits; survey estimates US $9–$18. Meshtastic includes partner shipping in pledge.

6. **Authorized use?** Monitor/block only on networks you own or have written permission to test.

7. **Open source?** MIT on core CyberThreatGotchi. Hardware is yours; STLs stay on GitHub.

8. **Returns?** DOA replacement within 30 days; defect warranty per campaign updates.

---

## Video / image checklist

- Hero video (75s script): [KICKSTARTER_CAMPAIGN.md#hero-video-script-75-seconds](KICKSTARTER_CAMPAIGN.md#hero-video-script-75-seconds)
- Hero image: `website/images/products/direct-core-kit.jpg`
- Tier cards: [KICKSTARTER_VISUAL_BRIEF.md](KICKSTARTER_VISUAL_BRIEF.md)

---

*Defensive use only · Authorized networks only · © Hacker Planet LLC*
