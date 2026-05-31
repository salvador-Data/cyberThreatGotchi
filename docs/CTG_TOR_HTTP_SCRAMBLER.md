# CTG Tor/HTTP Scrambler + Shield

**Hacker Planet LLC** · authorized defensive lab · Philadelphia, PA

Privacy routing for the CyberThreatGotchi Kali lab: Tor-default browsing, optional clearnet HTTP via site-rules, **CTG Shield** for lab USB WiFi identity refresh, and **SIEM hook** for IDS-driven **prompted** rotate (v1).

---

## Install (Kali)

From shared folder or repo copy:

```bash
sudo bash /mnt/ctg/tor-http-scrambler/install-scrambler.sh
```

Or after `ctg-lab-autorun.sh` / bootstrap `--install-scrambler`.

---

## Files (`scripts/kali/tor-http-scrambler/`)

| File | Purpose |
|------|---------|
| `scrambler-daemon.sh` | `tor` / `http` / `auto` modes |
| `site-rules.example` | Per-domain routing template |
| `ctg-scrambler-gui.py` | Tkinter GUI: modes, shield, IDS tail |
| `ctg-shield-rotate.sh` | USB wlan IP/MAC status + rotate |
| `siem-hook.sh` | IDS tail + high-severity y/n rotate |
| `install-scrambler.sh` | Install under `/opt/ctg/tor-http-scrambler` |

---

## Quick start

```bash
sudo /opt/ctg/tor-http-scrambler/scrambler-daemon.sh start
```

```bash
python3 /opt/ctg/tor-http-scrambler/ctg-scrambler-gui.py
```

```bash
sudo /opt/ctg/tor-http-scrambler/ctg-shield-rotate.sh status
```

```bash
sudo /opt/ctg/tor-http-scrambler/siem-hook.sh
```

---

## Shield + SIEM

Full playbook: [CTG_SHIELD_SIEM_PLAYBOOK.md](CTG_SHIELD_SIEM_PLAYBOOK.md)

Windows read-only status: `scripts/windows/CTG-Shield-Status.ps1`

---

## Orchestration

- [CTG_LAB_AUTORUN.md](CTG_LAB_AUTORUN.md) — `Start-CTGLab.ps1` + `ctg-lab-autorun.sh`  
- [KALI_LAB_ARCHITECTURE.md](KALI_LAB_ARCHITECTURE.md) — Phase 7 Privacy Router

**DuckDuckGo:** bootstrap and shield preserve `94.140.14.14` / `94.140.15.15` in `resolv.conf` when already configured; Windows host uses `Preserve-DuckDuckGoVpn.ps1` — no competing CTG VPN installers.

**Gatekeeper.TOR:** branded tray + safest torrc — [GATEKEEPER_TOR.md](GATEKEEPER_TOR.md) (`scripts/gatekeeper-tor/`). Daemon bridges modes `tor`/`https` to scrambler `tor`/`http`.
