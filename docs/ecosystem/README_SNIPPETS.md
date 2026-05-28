# Ecosystem README snippets

Copy-paste blocks for sibling repos. Graphics live in **CyberThreatGotchi** (`docs/images/`) and ship in [release assets](https://github.com/salvador-Data/cyberThreatGotchi/releases).

---

## For `salvador-Data/Bjorn`

```markdown
## Hacker Planet ecosystem

| Project | Role |
|---------|------|
| **[CyberThreatGotchi](https://github.com/salvador-Data/cyberThreatGotchi)** | Edge IPS + Tamagotchi UI on BPI-R3 Mini |
| **Bjorn** (this repo) | Raspberry Pi network assessment |
| [Mr.-CrackBot-AI-Nano](https://github.com/salvador-Data/Mr.-CrackBot-AI-Nano) | Lab wordlist assistant |
| [M5_OS-Cardputer](https://github.com/salvador-Data/M5_OS-Cardputer) | M5Stack Cardputer field tools |

![CyberThreatGotchi + Bjorn](https://raw.githubusercontent.com/salvador-Data/cyberThreatGotchi/main/docs/images/og-ecosystem.png)

### CTG → Bjorn webhook bridge

Run on your Pi:

```bash
python scripts/bjorn_bridge.py --port 9090
# On CTG host: CTG_WEBHOOK_URL=http://<pi-ip>:9090/ctg
```

See [CyberThreatGotchi INTEGRATIONS.md](https://github.com/salvador-Data/cyberThreatGotchi/blob/main/docs/INTEGRATIONS.md).
```

---

## For `salvador-Data/Mr.-CrackBot-AI-Nano`

```markdown
## Hacker Planet ecosystem

![CrackBot in the stack](https://raw.githubusercontent.com/salvador-Data/cyberThreatGotchi/main/docs/images/og-crackbot.png)

| Project | Role |
|---------|------|
| [CyberThreatGotchi](https://github.com/salvador-Data/cyberThreatGotchi) | Defensive edge sensor + audit logs |
| [Bjorn](https://github.com/salvador-Data/Bjorn) | Pi assessment |
| **Mr.-CrackBot-AI-Nano** (this repo) | Authorized lab wordlists |
| [M5_OS-Cardputer](https://github.com/salvador-Data/M5_OS-Cardputer) | Portable UI |

CrackBot stays in the **lab VLAN**. CTG monitors the **production/homelab edge** — complementary, not interchangeable.
```

---

## For `salvador-Data/M5_OS-Cardputer`

```markdown
## Hacker Planet ecosystem

![M5 Cardputer + CTG](https://raw.githubusercontent.com/salvador-Data/cyberThreatGotchi/main/docs/images/og-m5-cardputer.png)

Poll **CyberThreatGotchi** mood from the field:

| Client | Path |
|--------|------|
| MicroPython | [ctg_status.py](https://github.com/salvador-Data/cyberThreatGotchi/blob/main/scripts/cardputer/ctg_status.py) |
| PlatformIO firmware | [scripts/cardputer/platformio](https://github.com/salvador-Data/cyberThreatGotchi/tree/main/scripts/cardputer/platformio) |

```cpp
// platformio.ini — set CTG_HOST to your BPI-R3 Mini IP
-DCTG_HOST=\"192.168.1.50\"
```

Full guide: [CARDPUTER.md](https://github.com/salvador-Data/cyberThreatGotchi/blob/main/docs/CARDPUTER.md).
```

---

## For org profile / CyberThreatGotchi README footer

Link the one-pager and release:

- [Social launch kit](social/LAUNCH.md)
- [2600 handout](social/2600_ONEPAGER.md)
- [Latest release](https://github.com/salvador-Data/cyberThreatGotchi/releases/latest)
