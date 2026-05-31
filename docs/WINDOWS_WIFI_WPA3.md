# Windows Wi-Fi repair and WPA3 (lab guide)

**Hacker Planet LLC / CyberThreatGotchi** — defensive posture for systems you **own**. Andy workstation: preserve **DuckDuckGo VPN, DNS, and Password Manager**; do not replace with conflicting VPN or DNS stacks.

## Quick fix checklist

1. **Physical layer** — Wi-Fi radio on (airplane mode off), correct SSID, signal usable.
2. **Service** — `WLAN AutoConfig` (`WlanSvc`) running, automatic start.
3. **Driver** — Intel (or vendor) Wi-Fi driver current; `netsh wlan show drivers` must list **WPA3-Personal**.
4. **Profiles** — remove open/WEP and broken entries; prefer WPA3 or WPA2/WPA3 transition profiles only.
5. **Live link vs profile** — profile may allow WPA3 while the AP negotiates **WPA2** (common on 2.4 GHz or “Maximize Compatibility” hotspots).
6. **DuckDuckGo VPN** — if pages fail but ping works, check VPN connected and DNS (`10.11.12.x` on tunnel); run `Preserve-DuckDuckGoVpn.ps1` logic via `Repair-WindowsWifi.ps1` (no competing VPN installs).
7. **Multi-homed routing** — Ethernet + Wi-Fi + VPN: check interface metrics; unplug USB Ethernet to test Wi-Fi-only path.
8. **Stack reset (last resort)** — `Repair-WindowsWifi.ps1 -ApplyFixes -ResetStack` then **reboot**.

Automation:

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

Diagnose only (default):

```powershell
.\scripts\windows\Repair-WindowsWifi.ps1
```

Safe fixes (Admin):

```powershell
.\scripts\windows\Repair-WindowsWifi.ps1 -ApplyFixes
```

List profile auth types:

```powershell
.\scripts\windows\Repair-WindowsWifi.ps1 -ListProfiles
```

WPA3 posture + remove weak saved networks:

```powershell
.\scripts\windows\Repair-WindowsWifi.ps1 -PreferWpa3
```

Log: `%USERPROFILE%\Backups\logs\repair-windows-wifi.log`

Related: `Harden-DDoSRogueWifi.ps1` (rogue AP / client exposure), `docs/DEFENSE_DDOS_ROGUE_WIFI.md`.

## WPA3-Personal (SAE) vs WPA2-PSK

| Topic | WPA2-PSK | WPA3-Personal (SAE) |
|-------|----------|---------------------|
| Key derivation | PSK + 4-way handshake | SAE (dragonfly); resistant to offline dictionary on captured frames |
| PMF (802.11w) | Optional | Required for WPA3 certification |
| Transition | N/A | **WPA2/WPA3 transition** lets legacy clients use WPA2 while WPA3-capable clients use SAE |
| Client requirement | Any modern OS | Windows 10 1903+ / **Windows 11**, updated Wi-Fi driver, profile with PMF when WPA3-only |

**Blue-team note (NIST CSF PR.AC):** prefer WPA3 or transition on the **lab/home AP**; drop open and WEP from Windows known networks to reduce evil-twin attachment (CIS Control 12).

## Router / lab AP (Andy)

The repair script **cannot** turn on WPA3 on the access point. On your **home/lab router** (web UI or app):

1. Firmware current.
2. Wireless security: **WPA2/WPA3-Personal (transition)** on 5 GHz first; use **WPA3-only** only when all lab clients support it.
3. Disable **WEP**, **WPA (TKIP)**, and **open** guest networks on trusted VLANs.
4. Enable **802.11w (PMF)** where the UI offers “required” for WPA3-only SSIDs.
5. If SSID is an **iPhone Personal Hotspot**: **Settings → Personal Hotspot → Maximize Compatibility OFF** (WPA3 where iOS/carrier allows); ON forces WPA2 for old clients.

After AP changes, forget and re-add the network on Windows or re-import a profile with WPA3 + PMF.

## Windows client settings

- **Settings → Network & Internet → Wi-Fi → Manage known networks** — remove untrusted/open entries.
- **Settings → Privacy & security** — limit Wi-Fi scan where appropriate; use `Harden-DDoSRogueWifi.ps1 -DiagnoseOnly` for exposure review.
- **Do not** store PSK in git or logs; never run `netsh wlan show profile key=clear` in shared logs.

### WPA3 profile import (PMF required)

Export a template from an existing profile, edit XML authentication to **WPA3SAE**, set PMF to **Required**, then:

```powershell
netsh wlan add profile filename="C:\Path\lab-wpa3.xml" user=all
```

Reconnect; verify with:

```powershell
netsh wlan show interfaces
```

**Authentication** should show **WPA3-Personal** when the AP offers SAE on that band.

## Preserve DuckDuckGo VPN / DNS

- `Repair-WindowsWifi.ps1` dot-sources `Preserve-DuckDuckGoVpn.ps1` during diagnosis.
- Fixes **do not** install Cloudflare WARP, NextDNS, or other stacks that conflict with DuckDuckGo.
- If DNS fails on Wi-Fi only, confirm VPN is up and that no script set a static DNS on the Wi-Fi adapter that bypasses DuckDuckGo policy.

## What we observed on this host (diagnostic snapshot)

- Intel Wireless-AC 9260 driver **23.90.0.2** reports **WPA3-Personal** support.
- Saved **Sal** profile includes WPA3 + WPA2 transition; a live link may still show **WPA2-Personal** if the AP/hotspot beacon is WPA2 (e.g. 2.4 GHz or compatibility mode).
- **DuckDuckGo.VPN** adapter up; DNS on tunnel — expected for Andy’s policy.

Re-run diagnosis after router WPA3 changes to confirm **WPA3-Personal** on `netsh wlan show interfaces`.
