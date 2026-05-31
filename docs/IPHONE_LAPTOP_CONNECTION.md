# iPhone 15 Pro Max â€” laptop connection (honest scope)

**Hacker Planet LLC / CyberThreatGotchi** â€” defensive guidance for devices you **own** or are **explicitly authorized** to administer.

**Related:** [IPHONE_HARDENING.md](IPHONE_HARDENING.md) Â· [IPHONE_USB_HARDENING.md](IPHONE_USB_HARDENING.md) Â· [SECURITY_HARDENING.md](SECURITY_HARDENING.md)

---

## What Windows and Kali cannot do (read first)

Apple does **not** expose APIs for third-party Windows or Linux tools to:

| Claim you may see online | iOS / Apple reality |
|--------------------------|---------------------|
| â€œChange iPhone MAC from PCâ€ | **Wiâ€‘Fi MAC** is per-network **Private Wiâ€‘Fi Address** (Settings on device). USB tethering uses a **separate** interface; neither is writable from Windows PowerShell. |
| â€œSpoof hardware ID / UDID from laptopâ€ | **UDID, serial, IMEI** are not modifiable without jailbreak + unauthorized tooling â€” out of scope for CTG. |
| â€œPush hardening profiles from PowerShellâ€ | Requires **Apple Business Manager + MDM** (Intune, Jamf). Personal iPhones are **Settings-only** from the device. |
| â€œInstall App Store apps from Windowsâ€ | Not supported without MDM / Apple Configurator fleet workflows. |

**CTG scripts are read-only on the phone:** log reminders, checklist output, and links to Settings paths. They **never** modify iPhone configuration.

**Preserve Andyâ€™s stack:** **DuckDuckGo VPN/DNS** and **DuckDuckGo Password Manager** â€” hardening steps below do **not** replace them.

---

## Connection modes and exposure

| Mode | What the laptop sees | Privacy notes |
|------|----------------------|---------------|
| **USBâ€‘C data cable** | PnP device (Apple VID `05AC`); optional **Trust This Computer**; Apple Devices backup/sync | Lowest radio exposure; enables forensic-class tools **only if unlocked + trusted**. Use **USB Restricted Mode**. |
| **USB tethering** | Windows gets a network adapter; iPhone shares cellular | Phone IP visible to host routing; prefer **Limit IP Tracking** (cellular). |
| **Personal Hotspot (Wiâ€‘Fi)** | Laptop joins phoneâ€™s AP | Extra Wiâ€‘Fi hop; rotate hotspot password; **Private Wiâ€‘Fi Address** on laptop for other networks. |
| **Wiâ€‘Fi only (no cable)** | No USB attack surface | Run checklist manually; `iphone_tethering_privacy_checklist.ps1` may not detect device. |

---

## Defensive checklist (on the iPhone â€” manual)

Complete on the **device**. Check each item when connecting to Andyâ€™s Windows SOC laptop.

```
[ ] Private Wiâ€‘Fi Address     Settings â†’ Wiâ€‘Fi â†’ â“˜ on network â†’ Private Wiâ€‘Fi Address ON
[ ] Limit IP Tracking         Settings â†’ Wiâ€‘Fi â†’ â“˜ â†’ Limit IP Address Tracking ON (iOS 14+)
[ ] Limit IP Tracking (cell)  Settings â†’ Cellular â†’ Cellular Data Options â†’ Limit IP Address Tracking ON
[ ] USB Restricted Mode       Settings â†’ Face ID & Passcode â†’ USB Accessories OFF when locked
[ ] Trust This Computer       Prompt on cable â€” Trust ONLY Andyâ€™s laptop; Reset Location & Privacy if unsure
[ ] iOS updates               Settings â†’ General â†’ Software Update â€” latest iOS; Automatic Updates ON
[ ] VPN/DNS baseline          Settings â†’ VPN â€” DuckDuckGo unchanged; Wiâ€‘Fi â“˜ â†’ Configure DNS unchanged
[ ] Password Manager          Settings â†’ AutoFill & Passwords â†’ DuckDuckGo Autofill ON
[ ] Hotspot password          Settings â†’ Personal Hotspot â€” strong password if sharing cellular
[ ] Find My / Stolen Device   Find My ON; Stolen Device Protection ON (iOS 17.3+)
```

### Settings path quick reference

| Control | Path |
|---------|------|
| Private Wiâ€‘Fi Address | **Settings** â†’ **Wiâ€‘Fi** â†’ **â“˜** â†’ **Private Wiâ€‘Fi Address** |
| Limit IP Tracking (Wiâ€‘Fi) | **Settings** â†’ **Wiâ€‘Fi** â†’ **â“˜** â†’ **Limit IP Address Tracking** |
| Limit IP Tracking (cellular) | **Settings** â†’ **Cellular** â†’ **Cellular Data Options** â†’ **Limit IP Address Tracking** |
| USB Restricted Mode | **Settings** â†’ **Face ID & Passcode** â†’ **USB Accessories** (off when locked) |
| Reset trust list | **Settings** â†’ **General** â†’ **Transfer or Reset iPhone** â†’ **Reset** â†’ **Reset Location & Privacy** |
| Personal Hotspot | **Settings** â†’ **Personal Hotspot** |
| Software Update | **Settings** â†’ **General** â†’ **Software Update** |

---

## When plugged into Windows (Andyâ€™s SOC laptop)

1. **Trust** only when you initiated the connection (encrypted backup, photo import).
2. **Apple Devices** â€” prefer **encrypted local backup**; password in password manager (never in git).
3. Backup trees covered by CTG nightly: `D:\Backups\Andy-PC-YYYY-MM-DD\`, `C:\Users\Owner\Backups\...`, OneDrive `Backups\`.
4. **Disable auto-sync** in Apple Devices unless you want sync on every connect.
5. Run read-only checklist (no device modification):

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\iphone\iphone_tethering_privacy_checklist.ps1
```

Legacy log stub (USB detect only): `.\scripts\windows\iphone_usb_check.ps1`

---

## Hotspot vs USB tethering â€” blue-team framing

| Vector | Hotspot (Wiâ€‘Fi) | USB tethering |
|--------|-----------------|---------------|
| Nearby eavesdrop | WPA2/WPA3 on hotspot; use strong password | Cable only â€” no over-the-air |
| Laptop IDS visibility | Phone as gateway; Snort/Suricata on laptop sees tunneled traffic | Same; different adapter name |
| Physical | Shoulder-surf / evil twin if misconfigured | Trust + Restricted Mode matter most |
| Recommendation | Fine for lab; rotate password | Prefer for sensitive sessions when cable available |

Network-layer IDS on the Windows SOC (**Snort/Suricata**) detects **malicious traffic** â€” not RAM side-channel bugs on the phone SoC. See [SECURITY_HARDENING.md Â§ IDS vs CPU](SECURITY_HARDENING.md#ids-vs-cpu-side-channel-exploits-honest-scope).

**Tether egress monitoring:** [IPHONE_TETHER_MONITORING.md](IPHONE_TETHER_MONITORING.md) â€” auto-detect hotspot/USB adapter and run IDS + checklist (`Start-CtgIphoneTetherIds.ps1`). Laptop monitors **NAT IP traffic** only; cannot emulate phone Wiâ€‘Fi/BLE/cellular radios.

---

## What CTG automates (Windows)

| Script | Behavior |
|--------|----------|
| `scripts/iphone/iphone_tethering_privacy_checklist.ps1` | Prints checklist + Settings paths; optional USB PnP detect |
| `scripts/windows/Start-CtgIphoneTetherIds.ps1` | Detect tether adapter â†’ checklist â†’ Snort/Suricata + Signal |
| `scripts/windows/iphone_usb_check.ps1` | Log-only one-liner when Apple USB PnP present |

Neither script changes iPhone settings, MAC addresses, or hardware IDs.

---

**Author:** [Hacker Planet LLC](ABOUT_HACKER_PLANET.md) Â· **Maintained with:** [IPHONE_HARDENING.md](IPHONE_HARDENING.md)
