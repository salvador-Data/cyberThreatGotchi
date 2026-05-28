# Reddit launch — u/Salvador_Data

**Username:** `Salvador_Data` (underscore between Salvador and Data)  
**Not:** SalvadorData11  
**Banner image:** `docs/images/social/reddit-banner.png` (upload in Reddit profile settings)

---

## Post 1 — r/homelab (post first)

**Type:** Text post recommended (Reddit often prefers context)

**Title:**
```
[Release] CyberThreatGotchi — edge IPS + Tamagotchi UI on Banana Pi (open source)
```

**Body:**
```
Hey homelab — I open-sourced a defensive edge box I've been building for Hacker Planet LLC.

**CyberThreatGotchi** captures traffic (or simulates on Windows), scores threats with signatures + YARA + hash lists, optional ClamAV, blocks repeat offenders via IPS, and logs to SQLite. The gimmick that actually helps: a Tamagotchi mascot (Cipherhorn) whose mood tracks live security pressure — e-ink, LCD, terminal, or Flask web UI.

**Hardware target:** Banana Pi BPI-R3 Mini + Waveshare 2.13" e-ink  
**Dev mode:** `python main.py --simulation --web` → http://127.0.0.1:8765/

**Repo:** https://github.com/salvador-Data/cyberThreatGotchi  
**Release (STLs, sprites, graphics):** https://github.com/salvador-Data/cyberThreatGotchi/releases/tag/v1.1.0

Also in the ecosystem (separate repos):
- Bjorn — Pi network assessment (authorized use)
- Mr.-CrackBot-AI-Nano — lab wordlists
- M5_OS-Cardputer — pocket tool launcher

3D printable Tamagotchi enclosure STLs included (e-ink + LCD variants).

Defensive / authorized networks only. MIT license. CI + Docker in repo.

Happy to help with BPI-R3 install or simulation setup.
```

---

## Post 2 — r/opensource (48h later)

**Title:** `CyberThreatGotchi — Python defensive network appliance with Tamagotchi UX (MIT)`

**Link:** https://github.com/salvador-Data/cyberThreatGotchi

**Comment:**
```
Python 3.10+, Flask web UI, optional Scapy live capture, webhook export for SOC, 29 tests in CI. Defensive homelab / SOHO focus — not offensive tooling.
```

---

## Post 3 — r/cybersecurity (check rules / use weekly thread if required)

**Title:** `OSS edge sensor with audit logging + "executive friendly" Tamagotchi status UI`

**Body:** Short technical summary + repo link. Emphasize SQLite export CSV, IPS, governance narrative.

---

## Post 4 — r/selfhosted (optional)

Focus on `--web`, Docker Compose, webhook integrations, LAN polling from Cardputer.

---

## Engagement tips

- Reply to every comment for 24–48h after posting  
- Don't cross-post identical text to 5 subs same hour — Reddit flags spam  
- If mod removes post, ask politely which thread fits  
- Pin GitHub link in your Reddit profile bio

---

## Subreddits to avoid or use carefully

| Sub | Note |
|-----|------|
| r/netsec | Often no direct self-promo — use megathread |
| r/hacking | Defensive framing only; read rules |
| r/HowToHack | Do not post — wrong audience |
