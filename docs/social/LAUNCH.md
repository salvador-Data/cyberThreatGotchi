# Social launch kit — Hacker Planet LLC

Graphics, copy-paste posts, and where to publish.  
**GitHub org:** [salvador-Data](https://github.com/salvador-Data)  
**Reddit:** u/Salvador_Data (underscore — not SalvadorData11)  
**Facebook:** Andy Klwal — Philadelphia, PA (your public profile)

---

## Graphics inventory (commit to GitHub)

| File | Use |
|------|-----|
| [docs/images/hero.png](../images/hero.png) | README, main GitHub social preview |
| [docs/images/og-cyberthreatgotchi.png](../images/og-cyberthreatgotchi.png) | Facebook / LinkedIn link preview |
| [docs/images/og-ecosystem.png](../images/og-ecosystem.png) | Ecosystem announcement |
| [docs/images/og-bjorn.png](../images/og-bjorn.png) | Bjorn repo / post |
| [docs/images/og-crackbot.png](../images/og-crackbot.png) | CrackBot repo / post |
| [docs/images/og-m5-cardputer.png](../images/og-m5-cardputer.png) | M5 OS post |
| [docs/images/social/facebook-cover.png](../images/social/facebook-cover.png) | Facebook cover photo (820×312) |
| [docs/images/social/reddit-banner.png](../images/social/reddit-banner.png) | Reddit profile banner |
| [docs/images/social/square-*.png](../images/social/) | Instagram / Facebook square posts |

Regenerate all programmatic cards:

```bash
python assets/marketing/generate_graphics.py
```

---

## Facebook post (Andy Klwal — Philadelphia)

**Attach:** `docs/images/og-ecosystem.png` or `hero.png`  
**Best time:** Weekday evening US Eastern (6–9 PM)  
**Where:** Your personal timeline + relevant groups (see below)

### Post text (copy/paste)

```
🦄 Open source drop from Hacker Planet LLC — defensive security you can actually put on your desk.

CyberThreatGotchi turns live network threats into a Tamagotchi-style guardian named Cipherhorn (unicorn CISO + cat sentinels). It sniffs traffic, scores malware signatures, blocks repeat attackers, and logs evidence — on a Banana Pi, your laptop, e-ink face, or web dashboard.

Not a toy firewall — a real edge sensor with personality.

🔗 Main repo: https://github.com/salvador-Data/cyberThreatGotchi
📦 Also building: Bjorn (Pi assessment), CrackBot (lab wordlists), M5 Cardputer field tools

Defensive use on networks you own or are authorized to monitor.

#CyberSecurity #OpenSource #Homelab #Tamagotchi #InfoSec #Philadelphia #HackerPlanet

Built in Philly. Feedback welcome — especially from homelab and SOC folks.
```

### Facebook groups / pages (request-friendly)

| Place | Why |
|-------|-----|
| Your timeline | Primary — friends, local network |
| Philadelphia tech / maker groups | Local credibility |
| Homelab & Raspberry Pi groups (search) | Target audience |
| InfoSec career / education groups | CISO narrative — read group rules first |

**Avoid:** posting exploit kits or “hack anything” language — keep **defensive + authorized** framing.

---

## Reddit posts (u/Salvador_Data)

Read each sub’s rules before posting. Use **link post** where allowed, **text post** where self-promotion requires context.

### r/homelab (strong fit)

**Title:** `[Release] CyberThreatGotchi — edge IPS + Tamagotchi UI on BPI-R3 Mini (open source)`

**Body:**

```
I built a portable defensive sensor that reacts to real threats with a Tamagotchi-style mascot (Cipherhorn) on e-ink or web — signatures, YARA, optional ClamAV, SQLite logging, IPS blocks.

Runs in simulation on Windows for dev; production target is Banana Pi BPI-R3 Mini with 2.5GbE.

GitHub: https://github.com/salvador-Data/cyberThreatGotchi

Part of a larger desk/field toolkit (Bjorn Pi scanner, CrackBot lab assistant, M5 Cardputer status client). Defensive / authorized networks only.

Happy to answer setup questions — install.sh for the Pi, Docker for local demo.
```

**Flair:** Project / Setup (if available)

---

### r/cybersecurity (read rules — may require weekly thread)

**Title:** `Open-source edge sensor with executive-friendly Tamagotchi UX (CyberThreatGotchi)`

**Body:** Keep technical, no hype:

```
OSS edge appliance: packet capture → scoring → IPS block → SQLite audit trail. Web dashboard + webhook export for SOC. Positioned for SOHO/MSP/homelab, not enterprise replacement.

Repo: https://github.com/salvador-Data/cyberThreatGotchi

Built for visibility and incident evidence; mood/state UI helps non-technical stakeholders grasp “something is happening” without another flat Grafana panel.
```

---

### r/opensource

**Title:** `CyberThreatGotchi — Python defensive network guardian with Tamagotchi UI (MIT)`

**Link:** `https://github.com/salvador-Data/cyberThreatGotchi`

**Comment:** One paragraph summary + link to ecosystem doc in repo.

---

### r/SideProject or r/selfhosted

Same as homelab post; emphasize Docker `docker compose up` and `--simulation --web`.

---

### r/netsec

**Caution:** Strict moderation. Prefer commenting in **weekly open-source thread** if a sticky exists, rather than standalone promo post.

---

## 2600 / hacker community (not Reddit)

| Channel | Action |
|---------|--------|
| **2600 meetings** (Philly / your nearest city) | 60-second verbal announce + QR to GitHub |
| [2600.com forums](https://2600.com) | Post in appropriate **Open Source / Projects** area if available — no unauthorized access tools |
| DEF CON Groups / local DEF CON group FB | Defensive homelab angle |
| Philly InfoSec meetups (ISACA, OWASP chapter events) | Business card / QR to repo |

**2600 tone:** “I made a defensive box for my network that logs and blocks — open source, come talk after the meeting.”

---

## GitHub release (auto on tag)

Push a version tag to trigger GitHub Release with assets:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Workflow `.github/workflows/release.yml` attaches:

- Marketing PNGs
- Generated sprite PNGs
- STL enclosure files (eink + lcd)

See [RELEASE.md](../RELEASE.md).

---

## Suggested rollout order

1. **GitHub** — push repo, verify CI green, tag `v1.0.0` for auto-release  
2. **Reddit** — r/homelab first (most receptive)  
3. **Facebook** — personal profile + 1–2 groups  
4. **2600** — next local meeting  
5. **Cross-post** other subs spaced 48h apart (avoid spam flags)

---

## Profile links to add

| Platform | Link in bio |
|----------|-------------|
| Reddit u/Salvador_Data | `github.com/salvador-Data` |
| Facebook | Same + “Hacker Planet LLC / CyberThreatGotchi” |
| GitHub salvador-Data | Link to `docs/social/LAUNCH.md` in org README if you create org profile |

---

*Defensive use only. Authorized networks only.*
