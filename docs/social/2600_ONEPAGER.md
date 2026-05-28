# 2600 meeting one-pager — CyberThreatGotchi

**Print this page** (or save as PDF) for Philly / local 2600 meetings, DEF CON groups, and maker nights.

---

## What it is (30 seconds)

**CyberThreatGotchi** is an open-source **defensive edge sensor** with a Tamagotchi-style UI. It watches traffic on networks **you own or are authorized to monitor**, scores threats, blocks repeat attackers, and logs evidence to SQLite.

Your mascot **Cipherhorn** (unicorn CISO + cat sentinels) reacts on e-ink, LCD, terminal, or a web dashboard.

**Not** an exploit kit. **Not** for unauthorized networks.

---

## Why it exists

| Problem | CTG answer |
|---------|------------|
| Flat logs nobody reads | Mood + sprite = instant “something’s wrong” |
| Expensive SOHO gear | Runs on Banana Pi BPI-R3 Mini (~$160) |
| No audit trail | SQLite + **tamper-evident hash chain export** |
| SOC needs feed | Webhooks + CSV/JSON export + optional **Pro threat feed** |

---

## Quick demo (QR)

**Latest release:** https://github.com/salvador-Data/cyberThreatGotchi/releases/tag/v1.1.0

```bash
git clone https://github.com/salvador-Data/cyberThreatGotchi
cd cyberThreatGotchi
python -m venv .venv && .venv\Scripts\activate   # Windows
pip install -r requirements.txt
python main.py --simulation --web
# Browser → http://127.0.0.1:8765/
```

---

## Ecosystem (same author)

| Project | Role |
|---------|------|
| [CyberThreatGotchi](https://github.com/salvador-Data/cyberThreatGotchi) | Edge IPS + pet |
| [Bjorn](https://github.com/salvador-Data/Bjorn) | Pi network assessment |
| [Mr.-CrackBot-AI-Nano](https://github.com/salvador-Data/Mr.-CrackBot-AI-Nano) | Lab wordlists |
| [M5_OS-Cardputer](https://github.com/salvador-Data/M5_OS-Cardputer) | Field launcher |

CTG **webhooks → Bjorn bridge** (`scripts/bjorn_bridge.py`) pushes one-line status to Pi e-paper.

---

## Talk to me after the meeting

| | |
|---|---|
| **Name** | Salvador Data |
| **Org** | Hacker Planet LLC |
| **City** | Philadelphia, PA |
| **GitHub** | [salvador-Data](https://github.com/salvador-Data) |
| **Reddit** | u/Salvador_Data |

**Ask me about:** homelab setup, CISO visibility UX, Kickstarter kit, or contributing YARA rules.

---

## 2600-appropriate framing

> “I built a defensive box for my network that logs and blocks — open source. Come talk after if you run a homelab or small SOC.”

Avoid: “hack any Wi-Fi,” credential stuffing demos on live targets, or anything without **explicit authorization**.

---

*Defensive use only · Authorized networks only · MIT license*
