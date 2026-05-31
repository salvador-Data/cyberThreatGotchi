# Defense: DDoS, deauth, and rogue WiFi

**Hacker Planet LLC / CyberThreatGotchi** â€” authorized defensive guidance for systems and networks you **own** or are **explicitly permitted** to administer. This document does **not** cover offensive countermeasures (deauth attacks, jamming, â€œfighting backâ€ on air).

**Related:**

- Windows SOC: [scripts/windows/README_WINDOWS_SOC.md](../scripts/windows/README_WINDOWS_SOC.md)
- iPhone layers: [IPHONE_HARDENING.md](IPHONE_HARDENING.md)
- CTG API / env: [SECURITY_HARDENING.md](SECURITY_HARDENING.md)
- Perimeter (homelab): [FIREWALL_BASELINE.md](FIREWALL_BASELINE.md)
- **UTMS Wi-Fi event bus + jam/deauth detect:** [UTMS_WIFI_AI.md](UTMS_WIFI_AI.md)

---

## Threat model (what you are defending against)

| Threat | What it looks like | Primary defender |
|--------|-------------------|------------------|
| **Volumetric DDoS** | Flood to your **public IP** â€” sites slow/unreachable, modem lights pegged | **ISP** (null route, scrubbing) |
| **Application / L7 abuse** | HTTP floods, login spam, game/server griefing | Service host + CDN/WAF; client: donâ€™t expose services |
| **WiFi deauth / disassoc** | Connection drops on WiFi only; captive portal reappears | Router WPA3/802.11w; avoid untrusted open WiFi; VPN |
| **Evil twin / rogue AP** | Same SSID name, stronger signal, fake captive portal | Verify BSSID; VPN; never creds on unexpected portal |
| **LAN spoofing (LLMNR/NetBIOS)** | Name-resolution tricks on local network | Disable LLMNR/NetBIOS; firewall inbound |

---

## What a **client** can vs cannot do

### Can (this repoâ€™s scripts)

- Enable Windows Firewall â€” block inbound by default
- Block common LAN/WAN probe ports (SMB, RDP, WinRM, etc.)
- Disable LLMNR and NetBIOS over TCP/IP (reboot may be required)
- Stop auto-connect to **open** WiFi hotspots
- Keep CTG web API on **127.0.0.1** only when running locally
- Turn on **DuckDuckGo VPN** â€” hides home IP for some attack types and encrypts traffic on untrusted WiFi
- **Passive** Kali scan for duplicate SSIDs and open networks (`rogue-ap-guard.sh`)
- **Passive** Kali deauth frame counter in monitor mode (`ctg-deauth-watch.sh` — detection only)
- **Windows** disconnect-storm / gateway-loss heuristic (`Detect-CtgWifiJam.ps1`)
- **CTG event bus** deduped LAN publish (`core/ctg_event_bus.py`, [UTMS_WIFI_AI.md](UTMS_WIFI_AI.md))
- iPhone: Private Wiâ€‘Fi Address, VPN, no creds on unexpected portals ([IPHONE_HARDENING.md](IPHONE_HARDENING.md))

### Cannot (honest limits)

- Stop a **large volumetric DDoS** aimed at your residential public IP â€” only your **ISP** can sinkhole or scrub that traffic
- Prevent a determined **deauth** against your client radio without proper **802.11w (PMF)** on AP **and** client (partial mitigation)
- Guarantee detection of every rogue AP without dedicated wireless IDS (WIDS) or enterprise gear
- â€œAttack backâ€ legally or safely from a home lab â€” **do not**

---

## Under active attack â€” do this first

1. **Volumetric / home internet unusable**
   - Unplug modem/WAN or disable WiFi on router briefly to confirm itâ€™s network-side
   - **Call ISP** â€” report DDoS, request mitigation / IP change
   - Avoid running **personal hotspot** as a long-term fix ( exposes phone IP )
   - Document times and symptoms for **police report** if harassment/stalking is suspected

2. **WiFi deauth or rogue portal**
   - Disconnect from WiFi; use **wired Ethernet** or **cellular + VPN**
   - Do **not** enter passwords on a captive portal you did not expect
   - Run Windows diagnose: `Harden-DDoSRogueWifi.ps1 -DiagnoseOnly`
   - Run Windows jam detect: `Detect-CtgWifiJam.ps1 -DiagnoseOnly` ([UTMS_WIFI_AI.md](UTMS_WIFI_AI.md))
   - On Kali (authorized lab): `sudo bash rogue-ap-guard.sh -k "YourLabSSID"`
   - On Kali monitor mode: `sudo bash ctg-deauth-watch.sh --diagnose` then `-i wlan0mon --watch`

3. **Suspected credential capture**
   - Change passwords from a **trusted network** (cellular + VPN)
   - Revoke sessions (Apple ID, Microsoft, email)
   - Review [IPHONE_HARDENING.md](IPHONE_HARDENING.md) Â§ verify VPN/DNS unchanged

---

## Layer 1 â€” Windows laptop

Script: [`scripts/windows/Harden-DDoSRogueWifi.ps1`](../scripts/windows/Harden-DDoSRogueWifi.ps1)

### Diagnose (no Admin required)

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\Harden-DDoSRogueWifi.ps1 -DiagnoseOnly
```

Log: `%USERPROFILE%\Backups\logs\harden-ddos-rogue.log`

### Apply hardening (Administrator)

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\Harden-DDoSRogueWifi.ps1 -ApplyHardening
```

Optional aggressive inbound block:

```powershell
.\scripts\windows\Harden-DDoSRogueWifi.ps1 -ApplyHardening -StrictInbound
```

**Admin applies:**

- Firewall all profiles ON; default BlockInbound
- Inbound blocks: 135, 137â€“139, 445, 3389, 5985â€“5986, 23, 21, 69, 161, 1900
- LLMNR off (`EnableMulticast=0`)
- NetBIOS over TCP/IP off per interface
- WiFi `AutoConnectOpenNetworks=0`
- Firewall dropped-connection log: `Backups\logs\firewall.log`

**Reboot** after registry changes if LLMNR/NetBIOS still show enabled.

**DuckDuckGo VPN:** script runs `Preserve-DuckDuckGoVpn.ps1` â€” Defender exclusions; no second VPN install.

**CTG web API:** when running `python main.py --web`, bind to **127.0.0.1** only; set `CTG_WEB_API_TOKEN` if exposed beyond localhost ([SECURITY_HARDENING.md](SECURITY_HARDENING.md)).

Orchestrator also references this from [`harden_windows.ps1`](../scripts/windows/harden_windows.ps1) (guidance flag `-DDoSRogueWifiDiagnose`).

---

## Layer 2 â€” Kali WiFi (passive guard)

Script: [`scripts/kali/rogue-ap-guard.sh`](../scripts/kali/rogue-ap-guard.sh)

Installs a copy to `~/Backups/kali-wifi-guard/` (or `CTG_KALI_BACKUPS`).

Inside **Kali VM** (USB WiFi passthrough or lab NIC â€” authorized networks only):

```bash
sudo bash /mnt/ctg/rogue-ap-guard.sh -k "YourHomeSSID,YourPhoneHotspot"
```

Or after copy to Backups:

```bash
sudo ~/Backups/kali-wifi-guard/rogue-ap-guard.sh -i wlan0 -k "YourHomeSSID"
```

Log: `~/Backups/logs/rogue-ap-guard.log`

**Exit code 2** = warnings (duplicate SSID, open network, evil-twin hint). **Do not** run deauth tools in response.

---

## Layer 3 â€” iPhone

Use existing hardening â€” do **not** replace DuckDuckGo VPN/DNS:

| Control | Where |
|---------|--------|
| VPN on untrusted networks | Settings â†’ VPN (DuckDuckGo) |
| Private Wiâ€‘Fi Address | Settings â†’ Wiâ€‘Fi â†’ â“˜ â†’ Private Address |
| No open WiFi auto-join | Settings â†’ Wiâ€‘Fi â†’ Ask to Join Networks / forget `xfinitywifi`-style profiles |
| Captive portal discipline | Never enter creds unless **you** joined that network on purpose |
| Personal hotspot | Settings â†’ Personal Hotspot â€” strong password; off when not needed |
| Lockdown Mode | Optional if targeted â€” [IPHONE_HARDENING.md Â§ 8](IPHONE_HARDENING.md) |

Full checklist: [IPHONE_HARDENING.md](IPHONE_HARDENING.md) Â· runbook: [IPHONE_RUN_NOW.md](IPHONE_RUN_NOW.md)

---

## ISP and law enforcement

Residential DDoS almost always requires:

1. **ISP NOC** â€” account verification, source IPs if available, mitigation or **new public IP**
2. **Timestamped logs** â€” modem lights, `harden-ddos-rogue.log`, `firewall.log`, router logs
3. **Police / IC3** â€” if tied to harassment, swatting threats, or extortion (keep ISP ticket number)

---

## Verification checklist

**Windows:**

```powershell
netsh advfirewall show allprofiles state
```

```powershell
Get-NetTCPConnection -State Listen | Where-Object LocalAddress -notin '127.0.0.1','::1'
```

**Kali:**

```bash
sudo nmcli dev wifi list
```

**iPhone:** Settings â†’ VPN connected; Wiâ€‘Fi â“˜ shows expected DNS; no unknown profiles under VPN & Device Management.

---

## Authorized use

- Your home lab, Andyâ€™s laptop, Kali VM on authorized SSIDs
- MSP customer networks **with contract**

**Not authorized:** scanning or â€œguardâ€ scripts on coffee-shop or corporate WLAN without permission; any deauth/jamming â€œcounterattack.â€
