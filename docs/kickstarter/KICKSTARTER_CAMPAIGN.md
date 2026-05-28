# CyberThreatGotchi — Kickstarter campaign draft

**Hacker Planet LLC** · Philadelphia, PA · **Salvador Data**  
Public contact: salvadorData@proton.me · [hackerplanet.dev](https://hackerplanet.dev) · [GitHub](https://github.com/salvador-Data/cyberThreatGotchi)

> Internal planning doc. Reward economics → [KICKSTARTER_REWARDS_TABLE.md](KICKSTARTER_REWARDS_TABLE.md).  
> Social rollout → [KICKSTARTER_SOCIAL_LAUNCH.md](KICKSTARTER_SOCIAL_LAUNCH.md). Visual specs → [KICKSTARTER_VISUAL_BRIEF.md](KICKSTARTER_VISUAL_BRIEF.md).

---

## Project title options

| # | Title | Best for |
|---|-------|----------|
| **A (recommended)** | **CyberThreatGotchi — Edge IPS with a Tamagotchi Soul** | Broad homelab + creator audience; flagship name forward |
| B | Cipherhorn Field Kit — Open Defense for Your Network Edge | Hardware-forward; less cute, more CISO |
| C | Hacker Planet Desk Guardian — Philly-Made Network Sensor | Local maker + ecosystem story |

**Primary recommendation:** **Option A** — it matches repo, site, and v1.1 release branding while signaling real IPS capability.

---

## Tagline / one-liner

> **Real threats in. Mood out. Evidence saved.**  
> Open-source edge IPS on Banana Pi — with Cipherhorn, the unicorn CISO your homelab actually wants on the desk.

**Alt one-liners (A/B test in ads):**

- Not a toy firewall. A field sensor with personality — and SQLite audit logs.
- Turn network noise into signal your execs (and you) can feel.
- Built in Philadelphia. Authorized networks only. MIT licensed core.

---

## Hero video script (75 seconds)

**Tone:** Calm, credible cybersecurity creator — no hype-bro, no unauthorized-access framing.  
**Music:** Low-tempo synth + subtle kick; duck under VO.  
**On-screen text:** Syne Bold, `#e6edf3` on `#0a0e14`, accent highlights `#00b48c`.

| Time | VO | Shot list |
|------|-----|-----------|
| 0:00–0:08 | "Your network is talking all day. Most dashboards whisper. I wanted something that *reacts* — on my desk, at the edge, with evidence I can show." | Close-up: e-ink face idle → alert pulse. Desk B-roll, Philly window light optional. |
| 0:08–0:18 | "Meet **CyberThreatGotchi**. Open-source edge IPS on the Banana Pi BPI-R3 Mini. Live traffic — or simulation for lab — feeds **Cipherhorn**, your unicorn CISO." | Over-shoulder: web UI `/api/status`, mood change on threat score. Split: packet flow diagram (simple arrows, not hacker stock footage). |
| 0:18–0:30 | "Signatures, YARA, optional ClamAV, hash deny-lists. Repeat offenders get blocked on Linux. Everything lands in SQLite — plus a tamper-evident audit chain in v1.1." | Terminal: `iptables` block log (sanitized IPs). SQLite browser row scroll. Audit chain hash line. |
| 0:30–0:42 | "This isn't cosplay security. It's the same defensive stack I'd deploy for a SOHO or MSP edge — with a UI that helps non-technical stakeholders *feel* pressure without another flat Grafana panel." | Cardputer polling status over Wi‑Fi. Executive glance at e-ink mood. |
| 0:42–0:55 | "We're **Hacker Planet LLC** — Philadelphia. We assemble the Cipherhorn core kit, flash SD images, burn-in every unit, and ship the enclosure STLs open on GitHub." | Timelapse: PETG print → assembly → burn-in sticker. Quick cut: M5 Cardputer, CYD field build (separate SKUs — label on screen). |
| 0:55–1:05 | "Kickstarter backs the first production run: core kits, field packs, Meshtastic bundles for off-grid status, and an MSP pilot tier for shops rolling CTG to clients." | Reward tier cards animate in. Map: US + EU ship regions. |
| 1:05–1:15 | "Defensive use on networks you own or are authorized to monitor. Back us to put Cipherhorn on your edge — and help open defense stay weird in the best way." | Hero product shot. End card: logo, URL, "Back this project" + authorized-use disclaimer. |

**B-roll library to shoot:** e-ink refresh slow-mo, Cardputer keyboard poll, shop bench assembly, GitHub release page, simulation mode on laptop.

---

## Campaign story

### The problem

Homelab builders, small MSPs, and security-curious creators face the same gap: **edge visibility tools are either enterprise-heavy or hobby scripts with no audit story.** SOHO routers hide telemetry. DIY Snort setups need a PhD to maintain. Executives ignore flat dashboards.

You need **evidence** (logs, blocks, exportable trails) and **signal** (something that says "we're under pressure" without a 3 AM Slack pile-on).

### The solution

**CyberThreatGotchi** is an open-source edge IPS with a Tamagotchi-grade UX. Cipherhorn reacts to scored threats on e-ink or web. The stack is real: capture → score → block → log → webhook export.

Hardware kits ship **Philadelphia-assembled** BPI-R3 Mini + Waveshare e-ink + enclosure + pre-flashed SD. Field tools (M5 Cardputer, CYD builds, CrackBot bench lab) extend the ecosystem — each SKU is documented and priced separately so backers know what they're getting.

### Why now

- **v1.1.0 shipped:** tamper-evident audit chain, marketing assets, enclosure STLs on GitHub Releases.
- **Site live:** [hackerplanet.dev](https://hackerplanet.dev) with shop catalog, services, and shipping estimates.
- **Supply chain mapped:** BOM in [KICKSTARTER_BOM.md](../KICKSTARTER_BOM.md); partner-fulfilled Meshtastic SKUs sourced from verified makers (see [DROPSHIP_CATALOG.md](../DROPSHIP_CATALOG.md) — internal; public copy says **partner fulfillment**).
- **MSP path validated:** Year 1 model in [CISO_PLAYBOOK.md](../CISO_PLAYBOOK.md) — kits + Pro feed + retainers.

### The team

| | |
|---|---|
| **Founder / builder** | **Salvador Data** (Andy Klwal) — Philadelphia. Open-source defender, field hardware assembler, public face of Hacker Planet LLC. |
| **Brand** | Hacker Planet LLC — Blue Team retainers, authorized Red Team assessments, OSINT, and open edge tools. |
| **Community** | GitHub [salvador-Data](https://github.com/salvador-Data) · Reddit u/SalvadorData · ecosystem: Bjorn, Mr. CrackBot AI Nano, M5 Cardputer launcher. |

We are a **small Philly shop**, not a VC-backed appliance vendor. That means transparent lead times, direct replies from the builder, and firmware you can read.

### The ask

**Funding goal:** $35,000 (covers first 150+ core kit run, tooling, Kickstarter fees, RMA buffer, and partner-fulfillment deposits for Meshtastic bundles).

**What success unlocks:**

1. Production-scale SD flashing + burn-in workflow
2. Guaranteed BOM buy for BPI-R3 Mini and e-ink HAT (lead-time risk reduction)
3. Backer-only Pro feed keys for launch window
4. Stretch goals → LCD face variant, Meshtastic bridge beta, workshop series

---

## What you're making (SKU explainer for backers)

Each reward maps to a **real SKU** from [PRODUCT_PRICING.md](../PRODUCT_PRICING.md). No mystery boxes.

### CyberThreatGotchi Cipherhorn Core (`coreKit` — $189 retail)

- Banana Pi BPI-R3 Mini (2× 2.5GbE)
- Waveshare 2.13″ e-Paper HAT (Cipherhorn face)
- 32 GB microSD, pre-flashed CTG image
- UL-listed USB-C 5V/3A PSU
- 3D-printed PETG enclosure (e-ink variant STL on GitHub)
- Quick-start card + QR to docs
- **Philadelphia assembly** · ~30 min burn-in before pack-out

### Field Pack (`fieldPack` — $249 retail)

- Everything in Core +
- M5Stack Cardputer with **Remote Possibility** firmware (polls CTG `/api/status` over Wi‑Fi)
- Printed field pairing guide

### CYD Field Build — Standard (`cydStandard` — $89.99 retail)

- ESP32-2432S028 CYD 2.8″ pocket display
- PETG enclosure, USB-C cable, HPL field profile flash
- **Not** CrackBot — separate product line

### CYD Field Build — Custom (`cydFieldCustom` — $189.99 retail)

- CYD + GPS, extended Wi‑Fi/BLE radio + SMA antenna, LiPo + switch
- Custom wardrive / lab profile (Marauder GPS, extended Wi‑Fi lab, etc.)
- Authorized lab workflows only

### Mr. CrackBot AI Nano — Bench Lab (`crackbotBench` — $499 retail)

- NVIDIA Jetson Nano 4GB + carrier, CYD UI shell, GPU hashcat path
- 4 hr assembly + burn-in — **difficult bench build**, not a pocket toy
- Wordlist scope chosen at checkout; simulation repo free on GitHub

### M5 Cardputer tools

| SKU | Price | Role |
|-----|-------|------|
| Remote Possibility | $99.99 | CTG remote status + field HTTP client |
| BLE Bot | $89.99 | Authorized BLE scout / proximity lab tool |

### Meshtastic bundle (partner fulfillment)

- Heltec V3 fully built Meshtastic node ($129 retail) + field case ($34)
- Ships from **verified partner maker** (5–14 business days after order placement)
- LoRa mesh for off-grid status relay — configure for **your** authorized mesh

### Digital Pack (`digital` — $15 retail)

- STL zip + sprite pack + backer wallpaper set
- No hardware · instant delivery

### CTG Pro threat feed

- $9/mo or $99/yr — curated signatures/YARA cadence (Stripe after campaign)

---

## Reward tiers

Shipping charged at pledge manager post-campaign (US zones per [SHIPPING_AND_TAX.md](../SHIPPING_AND_TAX.md)). PA sales tax collected for PA addresses.

| Tier | Pledge | Limit | Includes | Ship from |
|------|--------|-------|----------|-----------|
| **Digital Defender** | **$15** | ∞ | Digital Pack — STLs, sprites, backer badge | Email |
| **Early Bird Core** | **$149** | 50 | Cipherhorn Core kit ($189 value) + 3 mo Pro feed | Philadelphia |
| **Cipherhorn Core** | **$189** | 300 | Core kit + quick-start | Philadelphia |
| **Field Pack** | **$249** | 150 | Core + Remote Possibility Cardputer | Philadelphia |
| **Pro Lab** | **$529** | 40 | Field Pack + CYD Standard ($89.99) + 1 yr Pro feed | Philadelphia |
| **Bench Lab** | **$499** | 25 | Mr. CrackBot Jetson bench (standalone SKU) | Philadelphia |
| **Meshtastic Relay** | **$159** | 75 | Heltec V3 node + field case + CTG webhook guide | Partner |
| **MSP Pilot** | **$2,499** | 10 | 3× Field Pack + MSP onboarding call (90 min) + 6 mo Pro feed keys (3 sites) | Philadelphia + partner |

**Add-ons (pledge manager):**

- BLE Bot Cardputer — $79
- CYD Custom upgrade — +$95 (from Field Pack backers)
- Extra Pro feed year — $89
- Enclosure color choice — free

---

## Stretch goals

| Unlocked at | Goal | Reward |
|-------------|------|--------|
| 🦄 | **$50,000** | All Core+ backers get **LCD face STL pack** + optional ST7789 HAT coupon code |
| 📡 | **$75,000** | **Meshtastic → CTG webhook bridge** beta firmware (opt-in, documented) |
| 🎓 | **$100,000** | **Backer workshop series** — 3 live streams: edge deploy, MSP multi-site, audit chain walkthrough |
| 🏙️ | **$125,000** | **Philly maker meetup** + backer lab day (travel not included) |
| 🔐 | **$150,000** | **Signed enclosure serial** + extended 18-month hardware defect warranty |

---

## Timeline & fulfillment

Honest estimates — we are a small shop, not Amazon.

| Phase | Window | Milestone |
|-------|--------|-----------|
| Campaign | 30 days | Kickstarter live |
| Survey + payment capture | +2 weeks | BackerKit / Kickstarter survey; shipping charged |
| Core kit production | Weeks 3–10 | BOM purchase, print farm, SD flash, burn-in |
| Core kit ship wave 1 | **Oct 2026** target | Early Bird + Core (US first) |
| Field Pack / Pro Lab | **Nov 2026** target | Cardputer flash + bundle QA |
| Bench Lab (CrackBot) | **Nov–Dec 2026** | Jetson assembly queue (3–5 day handling each) |
| Meshtastic bundle | **8–12 weeks** post-survey | Partner fulfillment order batch |
| MSP Pilot | **Dec 2026 – Jan 2027** | Scheduled onboarding calls + multi-unit ship |
| Digital tier | **Within 7 days** of campaign end | Email delivery |

**EU / UK / CA backers:** Selected tiers only (Core, Field, Digital). VAT/import duties may apply — disclosed in survey.

Updates: **bi-weekly** during production; **weekly** first month post-fund.

---

## Risks & challenges

### Supply chain

BPI-R3 Mini and Waveshare e-ink HAT have seen **8–12 week OEM lead times** in 2024–2025. We maintain alternate supplier quotes (Banana Pi shop, Digi-Key, vetted AliExpress) and will communicate slip **before** silent delays.

### Firmware & software

CyberThreatGotchi is **MIT open source**. Backer units ship pinned to a **tested release tag** (v1.1.x+). Post-ship updates via GitHub; breaking changes documented in RELEASE notes.

### Partner fulfillment (Meshtastic)

Meshtastic Relay tier ships from **independent verified makers**, not our Philadelphia bench. Lead times vary (5–14 business days per partner). We order in batch after survey; customs can add time for non-US backers.

### Regulatory & authorized use

Products are **defensive lab and edge monitoring tools** for networks you own or have written permission to test. We do not ship pre-configured attack payloads against third parties. Backers must acknowledge **authorized use** in survey.

Kickstarter is not a substitute for **export compliance** — we may restrict certain destinations for radio hardware (Meshtastic).

### Scale

If we exceed 300 Core units, assembly moves to a **second Philly print/flash shift** — adds ~3 weeks, not hidden.

---

## FAQ (12)

1. **Is this a real IPS or a toy?**  
   Real stack: capture, signature/YARA scoring, optional ClamAV, iptables block on Linux, SQLite logging, tamper-evident audit chain. The Tamagotchi UI is the *interface*, not the engine.

2. **Can I run it without buying hardware?**  
   Yes. Clone the repo, `python main.py --simulation --web`, Docker compose for homelab. Digital tier adds STLs/sprites.

3. **What network do I need?**  
   BPI-R3 Mini has 2× 2.5GbE — typical deploy is inline or mirrored span on **your** edge. Documented in install.sh and WEB.md.

4. **Does it replace my enterprise firewall?**  
   No. It's an **edge sensor + evidence node** for SOHO, homelab, MSP remote sites — not a Fortune 500 NGFW replacement.

5. **Authorized use — what does that mean?**  
   Monitor and block only on networks you own or where you have **written permission**. Red Team / wardrive profiles require explicit scope.

6. **What's the difference between Core and Field Pack?**  
   Field Pack adds M5 Cardputer with Remote Possibility firmware to poll CTG status away from the desk.

7. **Is CrackBot included in the Core kit?**  
   **No.** CrackBot is a separate $499 Jetson bench lab. CYD builds are separate SKUs. We label every tier clearly.

8. **What's partner fulfillment for Meshtastic?**  
   We purchase from verified makers (e.g. LayerFabUK-class suppliers) who ship directly to you. Hacker Planet handles support routing and order batching — we don't claim to warehouse every SKU.

9. **Shipping costs?**  
   Not included in pledge. US zones ~$9–$18 for direct Philly SKUs (weight-based). Meshtastic tier: shipping included in pledge (partner model).

10. **Sales tax?**  
    Pennsylvania sales tax on taxable goods to PA addresses. Other states per economic nexus — see survey.

11. **Pro feed — what is it?**  
    Curated threat intel cadence (signatures/YARA updates) for CTG. $9/mo retail; bundled months on select tiers. Not required to run open-source core rules.

12. **MSP Pilot — what do I get?**  
    Three Field Packs, 90-minute onboarding (multi-site deploy patterns, webhook → SIEM notes), six months Pro feed for three sites. Retainer services quoted separately at [services.html](https://hackerplanet.dev/services.html).

13. **Open source license?**  
    MIT on core CyberThreatGotchi. Hardware is yours; STLs and docs stay on GitHub.

14. **Return policy?**  
    DOA replacement within 30 days. Otherwise Kickstarter "all-or-nothing" + standard hardware defect warranty — see updates for RMA process.

---

## Press kit (bullet list)

**Boilerplate**

- Hacker Planet LLC — Philadelphia defensive security company. Open-source edge tools + field hardware. Flagship: CyberThreatGotchi (Cipherhorn). Authorized use only.

**Founder quote**

> "We built the sensor I'd want on my own edge — logs for the auditor, mood for the human. Kickstarter funds honest production scale, not vaporware."  
> — Salvador Data, Hacker Planet LLC

**Facts**

- Open source: [github.com/salvador-Data/cyberThreatGotchi](https://github.com/salvador-Data/cyberThreatGotchi)
- Release: v1.1.0 with audit chain + STLs
- Core kit: BPI-R3 Mini + e-ink + ~$141 BOM
- Ecosystem: Bjorn, Mr. CrackBot AI Nano, M5 Cardputer
- Site: [hackerplanet.dev](https://hackerplanet.dev)
- Contact: salvadorData@proton.me

**Assets (request or GitHub)**

- `docs/images/og-cyberthreatgotchi.png`
- `website/images/products/direct-core-kit.jpg`
- `website/images/hero-cybertech.png`
- Enclosure STLs in GitHub Releases
- Hero video (on launch)

**Angles for press**

- "Tamagotchi UX meets edge IPS" — prosumer / homelab
- "Philly maker ships open defensive hardware" — local tech
- "MSP-priced edge sensor" — channel / SMB security
- **Avoid:** "hack anything," dropship jargon, warehouse street address

**Interview topics**

- Why personality helps security communication
- Open vs opaque threat feeds
- Authorized lab culture in 2026
- Kickstarter vs ongoing shop at hackerplanet.dev

---

*Defensive use only · Authorized networks only · © Hacker Planet LLC*
