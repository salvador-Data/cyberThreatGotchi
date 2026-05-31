# Gatekeeper.TOR — advanced-safe Tor / HTTPS mode switch

**Product:** Gatekeeper.TOR (evolves [CTG Tor/HTTP scrambler](CTG_TOR_HTTP_SCRAMBLER.md))  
**Authorized use:** Hacker Planet LLC lab, Andy-owned hosts, written pentest scope only — **not** for illegal evasion, credential theft, or unauthorized third-party access.

## Honest crypto language

| Mode | What it means |
|------|----------------|
| **TOR** | Traffic for **opt-in** apps uses Tor’s SOCKS proxy (`127.0.0.1:9050`) and Tor Project’s onion-routing crypto stack. |
| **HTTPS** | Clearnet mode. Gatekeeper’s **health probe only** prefers **TLS 1.3** via `curl --tlsv1.3` (negotiated cipher often **AES-256-GCM**). This is **not** a system-wide VPN and not a separate “356 AES” product — Andy’s “356 aes” maps to standard TLS 1.3 semantics. |

## Threat model (defensive)

- **Protects:** Lab analyst privacy for authorized research; reduces casual clearnet leakage when TOR mode is on; documents safest **client-only** Tor (`ExitPolicy reject *:*`).
- **Does not protect against:** Malware on host, compromised browser extensions, DNS leaks from misconfigured apps, nation-state adversaries, or misuse outside scope.
- **Refused:** RF jammer/counter-jam tooling (see [UTMS_WIFI_AI.md](UTMS_WIFI_AI.md)).

## DuckDuckGo coexistence (Windows — mandatory)

Gatekeeper.TOR **must not** replace **DuckDuckGo VPN / DNS / Password Manager**.

| Layer | Behavior |
|-------|----------|
| DDG VPN | Remains primary system VPN when active. |
| Gatekeeper tray | Shows DDG status; optional **local** Tor Expert Bundle SOCKS for apps that **opt in**. |
| Routes | Do **not** stack conflicting system-wide VPN routes without explicit user consent. |
| Kali VM | Tor default for lab browser path; Windows tray may show **remote** status via SSH or local SOCKS if Tor is installed. |

Run `Preserve-DuckDuckGoVpn.ps1` before SOC changes. See [SCRIPTS_CATALOG.md](SCRIPTS_CATALOG.md).

## Architecture

```
scripts/gatekeeper-tor/
  gatekeeper-daemon.sh      # Kali: torrc, mode, scrambler bridge
  templates/gatekeeper.conf # /etc/tor/torrc.d/gatekeeper.conf
  kali/
    install-gatekeeper-kali.sh
    gatekeeper-tray.py        # Xfce systray (pystray)
  windows/
    Start-GatekeeperTorTray.ps1
    Install-GatekeeperTorWindows.ps1
core/gatekeeper_tor.py        # State JSON + health checks
assets/gatekeeper-tor/logo.svg
```

**Modes:** `tor` | `https` (maps to scrambler `tor` | `http`).

**State file (gitignored):**

- Windows: `%USERPROFILE%\Backups\gatekeeper-tor\state.json`
- Kali: `/var/lib/ctg/gatekeeper-tor/` (via `CTG_GATEKEEPER_STATE_FILE`)

## Safest Tor client config (Kali)

Template: `scripts/gatekeeper-tor/templates/gatekeeper.conf` → `/etc/tor/torrc.d/gatekeeper.conf`

- `SafeLogging`, `AvoidDiskWrites` (where supported)
- `SocksPort 127.0.0.1:9050`, `ControlPort 9051` (cookie auth — configure on host, **never** in git)
- `ExitPolicy reject *:*` (client-only, no exit relay)
- Bridges / obfs4: **optional manual** step for censored networks ([Tor bridges](https://bridges.torproject.org/))

References: [Tor hardening](https://community.torproject.org/relay/setup/post-install/), [Tor manual](https://2019.www.torproject.org/docs/tor-manual.html.en).

## Install

### Kali (from `/mnt/ctg` share after staging)

```bash
sudo bash /mnt/ctg/gatekeeper-tor/kali/install-gatekeeper-kali.sh
```

Diagnose only (no root changes):

```bash
bash /mnt/ctg/gatekeeper-tor/kali/install-gatekeeper-kali.sh --diagnose-only
```

Optional: `sudo apt install -y tor python3-pil python3-pystray`

### Windows

Tor Expert Bundle is **not** bundled in git. Install from [Tor Project](https://www.torproject.org/download/tor/), then:

```powershell
.\scripts\gatekeeper-tor\windows\Start-GatekeeperTorTray.ps1 -DiagnoseOnly
```

```powershell
.\scripts\gatekeeper-tor\windows\Start-GatekeeperTorTray.ps1 -InstallTray
```

## Tray usage

### Kali — Xfce top bar (systray)

1. Autostart: `~/.config/autostart/gatekeeper-tor-tray.desktop`
2. After login: neon **G** shield = TOR; gray = HTTPS/off styling
3. **Manual pin:** Panel → Add New Items → **Notification Area** (if missing) → right-click tray icon → keep Gatekeeper visible in top panel

Toggle: menu **TOR** / **HTTPS** or **Toggle TOR ↔ HTTPS**.

### Windows — system tray

- Neon/shield icon when TOR mode; warning icon when HTTPS mode (clearnet probe path)
- Menu documents DDG VPN coexistence and link to Tor Expert Bundle if SOCKS `:9050` is down

## Health checks

```bash
python3 /opt/ctg/core/gatekeeper_tor.py health tor
python3 /opt/ctg/core/gatekeeper_tor.py health https
```

- **TOR:** `https://check.torproject.org/api/ip` via `--socks5-hostname 127.0.0.1:9050`
- **HTTPS:** clearnet `curl --tlsv1.3` to probe URL (default Cloudflare trace endpoint)

## Relation to tor-http-scrambler

| Component | Role |
|-----------|------|
| [tor-http-scrambler](../scripts/kali/tor-http-scrambler/) | Legacy CTG Privacy Router, SIEM hook, shield rotate |
| Gatekeeper.TOR | Branded mode switch + safest torrc + trays + shared `core/gatekeeper_tor.py` |

`gatekeeper-daemon.sh` calls `scrambler-daemon.sh set-mode` when installed.

## Split repo

Monorepo-first; sync to `ctg-gatekeeper-tor` via:

```powershell
.\scripts\publish\Sync-CtgGatekeeperTorRepo.ps1
```

## Ethics

Defensive privacy and lab education only. See [CYBERSECURITY_ETHICS.md](CYBERSECURITY_ETHICS.md) and NIST CSF **Protect** / **Detect** functions.

## Cross-references

- [UTMS_WIFI_AI.md](UTMS_WIFI_AI.md) — Wi-Fi AI (no counter-jam)
- [CTG_TOR_HTTP_SCRAMBLER.md](CTG_TOR_HTTP_SCRAMBLER.md)
- [CTG_NEXT_STEPS.md](CTG_NEXT_STEPS.md)
