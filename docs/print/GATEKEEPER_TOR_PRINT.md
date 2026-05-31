# Gatekeeper.TOR — print quick ref

**Hacker Planet LLC / CyberThreatGotchi** · **no secrets on this page**

**Lit icon** = active mode (neon glow). **Dim gray** = inactive menu option.

Full doc: [../GATEKEEPER_TOR.md](../GATEKEEPER_TOR.md)

---

## Icon legend

| Active mode | Tray look | Tooltip |
|-------------|-----------|---------|
| **TOR** | Yellow/green neon shield + G | `Gatekeeper.TOR — TOR (lit)` |
| **HTTPS** | Blue/cyan neon shield + G | `Gatekeeper.TOR — HTTPS (lit)` |

Menu checkmark: `✓ TOR (lit)` or `✓ HTTPS (lit)` on selected mode.

---

## PRESERVE — DuckDuckGo first

- [ ] DuckDuckGo VPN unchanged on Windows / iPhone
- [ ] Gatekeeper is **opt-in SOCKS** — not a second system VPN
- [ ] Run `Preserve-DuckDuckGoVpn.ps1` before tray install

```powershell
cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
```

```powershell
.\scripts\windows\Preserve-DuckDuckGoVpn.ps1
```

---

## Windows commands

Stage Kali share:

```powershell
.\scripts\windows\Stage-KaliLabToBackups.ps1
```

Diagnose:

```powershell
.\scripts\gatekeeper-tor\windows\Start-GatekeeperTorTray.ps1 -DiagnoseOnly
```

Start tray (lit icon):

```powershell
.\scripts\gatekeeper-tor\windows\Start-GatekeeperTorTray.ps1
```

Autostart at login:

```powershell
.\scripts\gatekeeper-tor\windows\Start-GatekeeperTorTray.ps1 -InstallTray
```

Optional Tor bundle info:

```powershell
.\scripts\gatekeeper-tor\windows\Install-GatekeeperTorWindows.ps1 -DiagnoseOnly
```

Split repo sync:

```powershell
.\scripts\publish\Sync-CtgGatekeeperTorRepo.ps1
```

---

## Kali commands

Diagnose:

```bash
sudo bash /mnt/ctg/gatekeeper-tor/kali/install-gatekeeper-kali.sh --diagnose-only
```

Install:

```bash
sudo bash /mnt/ctg/gatekeeper-tor/kali/install-gatekeeper-kali.sh
```

Daemon:

```bash
sudo /opt/ctg/gatekeeper-tor/gatekeeper-daemon.sh start
```

```bash
sudo /opt/ctg/gatekeeper-tor/gatekeeper-daemon.sh set-mode tor
```

```bash
sudo /opt/ctg/gatekeeper-tor/gatekeeper-daemon.sh set-mode https
```

Tor health:

```bash
curl -sS --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip
```

Tray (top bar):

```bash
python3 /opt/ctg/gatekeeper-tor/gatekeeper-tray.py
```

Lab chain:

```bash
sudo bash /mnt/ctg/RUN-KALI-LAB-NOW.sh
```

---

## Pin to Xfce top bar (checklist)

- [ ] Status Tray Plugin on top panel
- [ ] `install-gatekeeper-kali.sh` completed
- [ ] Tray running — lit icon visible
- [ ] Toggle TOR ↔ HTTPS — icon color changes immediately

---

**Footer:** Hacker Planet LLC · Gatekeeper.TOR print ref · lit = active · no passwords in git
