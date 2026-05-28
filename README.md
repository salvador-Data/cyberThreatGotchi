<p align="center">
  <img src="docs/images/hero.png" alt="CyberThreatGotchi — Cipherhorn mascot" width="720"/>
</p>

<h1 align="center">CyberThreatGotchi</h1>

<p align="center">
  <strong>Portable network-security Tamagotchi for Hacker Planet LLC</strong><br/>
  Live threats feed your unicorn CISO <em>Cipherhorn</em> — mood, hunger, and XP on e-ink, LCD, terminal, or web.
</p>

<p align="center">
  <a href="https://github.com/salvador-Data/cyberThreatGotchi/actions/workflows/ci.yml">
    <img src="https://github.com/salvador-Data/cyberThreatGotchi/actions/workflows/ci.yml/badge.svg" alt="CI"/>
  </a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT"/></a>
  <img src="https://img.shields.io/badge/python-3.10%2B-3776AB?logo=python&logoColor=white" alt="Python"/>
  <img src="https://img.shields.io/badge/platform-BPI--R3%20Mini%20%7C%20dev-FF6B35" alt="Platform"/>
</p>

---

## About

**CyberThreatGotchi** turns edge defense into something you actually want on your desk: a Tamagotchi-style appliance that **reacts to real security events** — IPS blocks, scan detection, ClamAV/YARA/hash hits — while logging evidence for your program.

Built for the **Banana Pi BPI-R3 Mini** (2× 2.5GbE, Wi-Fi 6) and dev machines. Your mascot **Cipherhorn** is a unicorn CISO in a business suit and mask, orbited by **cat sentinels** (business, mass-market, and SOC personas).

Full story → **[docs/ABOUT.md](docs/ABOUT.md)** · Company → **[docs/ABOUT_HACKER_PLANET.md](docs/ABOUT_HACKER_PLANET.md)** · **Website** → **[website/](website/)** ([GitHub Pages](https://salvador-Data.github.io/cyberThreatGotchi/)) · Web UI → **[docs/WEB.md](docs/WEB.md)** · Export → **[docs/EXPORT.md](docs/EXPORT.md)** · Cardputer → **[docs/CARDPUTER.md](docs/CARDPUTER.md)** · **Launch kit** → **[docs/social/LAUNCH.md](docs/social/LAUNCH.md)** · Integrations → **[docs/INTEGRATIONS.md](docs/INTEGRATIONS.md)** · CISO playbook → **[docs/CISO_PLAYBOOK.md](docs/CISO_PLAYBOOK.md)** · Hardware → **[hardware/README.md](hardware/README.md)** · Ecosystem → **[docs/ECOSYSTEM.md](docs/ECOSYSTEM.md)**

## Features

| Module | Role |
|--------|------|
| `core/sniffer.py` | Live Scapy capture or simulation mode |
| `core/analyzer.py` | Traffic analysis, scan detection |
| `core/detector.py` | Signatures + AV scoring |
| `core/ips.py` | Auto-block via iptables (Linux) |
| `core/antivirus.py` | ClamAV + YARA + SHA256 deny-list |
| `core/gotchi.py` | Tamagotchi state machine + sprites |
| `display/` | Terminal, e-ink, or SPI LCD backends |
| `dashboard/cli.py` | Rich live threat dashboard |
| `dashboard/web_server.py` | Flask UI with Feed / Pet controls |

## Quick start (Windows / dev)

```powershell
git clone https://github.com/salvador-Data/cyberThreatGotchi.git
cd cyberThreatGotchi
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
python main.py --simulation
```

### Web dashboard

```powershell
python assets\sprites\generate_sprites.py
python main.py --simulation --web
```

Open **http://127.0.0.1:8765/** — live sprite, threat feed, Feed/Pet buttons. Add `--cli` for the Rich terminal dashboard too.

## Quick start (BPI-R3 Mini)

```bash
sudo bash scripts/install.sh
sudo systemctl start cyberthreatgotchi
```

## Environment

| Variable | Default | Description |
|----------|---------|-------------|
| `CTG_SIMULATION` | auto on Windows | Force simulated packets |
| `CTG_INTERFACE` | auto-detect | Capture interface |
| `CTG_DISPLAY` | `terminal` | `terminal`, `eink`, `lcd` |
| `CTG_IPS` | `true` | Enable IPS blocking |
| `CTG_DATA_DIR` | `./data` | SQLite + hash DB |
| `CTG_WEBHOOK_URL` | *(empty)* | POST JSON on each threat |
| `CTG_WEBHOOK_SECRET` | *(empty)* | Optional `X-CTG-Secret` header |
| `CTG_PRO_API_KEY` | *(empty)* | Pro feed auth; unset = demo key `demo` |
| `CTG_AUDIT_SECRET` | *(empty)* | HMAC on `/api/export/audit.json` |
| `CTG_CONFIG` | `config/default.yaml` | YAML settings file |
| `CTG_EINK_REFRESH_SEC` | `8` | Min seconds between idle e-ink updates |

## Recommended hardware

| Part | Recommendation |
|------|----------------|
| Brain | **Banana Pi BPI-R3 Mini** |
| Face (retro) | **Waveshare 2.13" SPI e-ink** — Tamagotchi feel |
| Face (smooth) | **2.4" ILI9341 SPI LCD** |
| Power | **20W USB-C PD** bank or 3S LiPo + PD trigger |
| Enclosure | **3D print** `hardware/stl/` — [hardware/README.md](hardware/README.md) (e-ink + LCD variants) |

## Launch & social

Marketing graphics live in **`docs/images/`** (regenerate: `python assets/marketing/generate_graphics.py`).

| Platform | You | Copy-paste guide |
|----------|-----|------------------|
| **GitHub** | [salvador-Data/cyberThreatGotchi](https://github.com/salvador-Data/cyberThreatGotchi) | [v1.1.0 release](https://github.com/salvador-Data/cyberThreatGotchi/releases/tag/v1.1.0) · [docs/RELEASE.md](docs/RELEASE.md) |
| **Reddit** | u/Salvador_Data | [docs/social/REDDIT.md](docs/social/REDDIT.md) |
| **Facebook** | Andy Klwal · Philadelphia | [docs/social/FACEBOOK.md](docs/social/FACEBOOK.md) |
| **2600 / meetups** | Local chapter | [docs/social/2600_ONEPAGER.md](docs/social/2600_ONEPAGER.md) |
| **Kickstarter BOM** | Kit planning | [docs/KICKSTARTER_BOM.md](docs/KICKSTARTER_BOM.md) |
| **Website** | Hacker Planet LLC · Philly | [salvador-Data.github.io/cyberThreatGotchi](https://salvador-Data.github.io/cyberThreatGotchi/) |

## Tests

```bash
pip install -r requirements.txt
pytest tests/ -v
```

## Project layout

```
cyberThreatGotchi/
├── core/           # sniffer, analyzer, detector, ips, av, gotchi
├── db/             # SQLite threat logger
├── dashboard/      # Rich CLI + Flask web
├── display/        # terminal | eink | lcd
├── assets/sprites/ # Cipherhorn + cat frames
├── rules/          # signatures + custom_rules.yar
├── hardware/       # STL enclosure + OpenSCAD sources
├── docs/           # About + README art
├── scripts/        # install.sh (BPI-R3 Mini)
└── tests/
```

## Hacker Planet LLC

Defensive security program alignment: risk register, IPS, AV pipeline, executive-friendly status, and logged evidence for incidents.

**Author:** [salvador-Data](https://github.com/salvador-Data)

---

<p align="center"><sub>★ Star the repo if Cipherhorn guards your network.</sub></p>
