# iPhone 15 Pro Max — laptop connection (honest scope)

**Hacker Planet LLC / CyberThreatGotchi** — defensive guidance for devices you **own** or are **explicitly authorized** to administer.

**Related:** [IPHONE_HARDENING.md](IPHONE_HARDENING.md) · [IPHONE_USB_HARDENING.md](IPHONE_USB_HARDENING.md) · [SECURITY_HARDENING.md](SECURITY_HARDENING.md)

---

## What Windows and Kali cannot do (read first)

Apple does **not** expose APIs for third-party Windows or Linux tools to:

| Claim you may see online | iOS / Apple reality |
|--------------------------|---------------------|
| “Change iPhone MAC from PC” | **Wi‑Fi MAC** is per-network **Private Wi‑Fi Address** (Settings on device). USB tethering uses a **separate** interface; neither is writable from Windows PowerShell. |
| “Spoof hardware ID / UDID from laptop” | **UDID, serial, IMEI** are not modifiable without jailbreak + unauthorized tooling — out of scope for CTG. |
| “Push hardening profiles from PowerShell” | Requires **Apple Business Manager + MDM** (Intune, Jamf). Personal iPhones are **Settings-only** from the device. |
| “Install App Store apps from Windows” | Not supported without MDM / Apple Configurator fleet workflows. |

**CTG scripts are read-only on the phone:** log reminders, checklist output, and links to Settings paths. They **never** modify iPhone configuration.

**Preserve Andy’s stack:** **DuckDuckGo VPN/DNS** and **DuckDuckGo Password Manager** — hardening steps below do **not** replace them.

---

## Connection modes and exposure

| Mode | What the laptop sees | Privacy notes |
|------|----------------------|---------------|
| **USB‑C data cable** | PnP device (Apple VID `05AC`); optional **Trust This Computer**; Apple Devices backup/sync | Lowest radio exposure; enables forensic-class tools **only if unlocked + trusted**. Use **USB Restricted Mode**. |
| **USB tethering** | Windows gets a network adapter; iPhone shares cellular | Phone IP visible to host routing; prefer **Limit IP Tracking** (cellular). |
| **Personal Hotspot (Wi‑Fi)** | Laptop joins phone’s AP | Extra Wi‑Fi hop; rotate hotspot password; **Private Wi‑Fi Address** on laptop for other networks. |
| **Wi‑Fi only (no cable)** | No USB attack surface | Run checklist manually; `iphone_tethering_privacy_checklist.ps1` may not detect device. |

---

## Defensive checklist (on the iPhone — manual)

Complete on the **device**. Check each item when connecting to Andy’s Windows SOC laptop.

```
[ ] Private Wi‑Fi Address     Settings → Wi‑Fi → ⓘ on network → Private Wi‑Fi Address ON
[ ] Limit IP Tracking         Settings → Wi‑Fi → ⓘ → Limit IP Address Tracking ON (iOS 14+)
[ ] Limit IP Tracking (cell)  Settings → Cellular → Cellular Data Options → Limit IP Address Tracking ON
[ ] USB Restricted Mode       Settings → Face ID & Passcode → USB Accessories OFF when locked
[ ] Trust This Computer       Prompt on cable — Trust ONLY Andy’s laptop; Reset Location & Privacy if unsure
[ ] iOS updates               Settings → General → Software Update — latest iOS; Automatic Updates ON
[ ] VPN/DNS baseline          Settings → VPN — DuckDuckGo unchanged; Wi‑Fi ⓘ → Configure DNS unchanged
[ ] Password Manager          Settings → AutoFill & Passwords → DuckDuckGo Autofill ON
[ ] Hotspot password          Settings → Personal Hotspot — strong password if sharing cellular
[ ] Find My / Stolen Device   Find My ON; Stolen Device Protection ON (iOS 17.3+)
```

### Settings path quick reference

| Control | Path |
|---------|------|
| Private Wi‑Fi Address | **Settings** → **Wi‑Fi** → **ⓘ** → **Private Wi‑Fi Address** |
| Limit IP Tracking (Wi‑Fi) | **Settings** → **Wi‑Fi** → **ⓘ** → **Limit IP Address Tracking** |
| Limit IP Tracking (cellular) | **Settings** → **Cellular** → **Cellular Data Options** → **Limit IP Address Tracking** |
| USB Restricted Mode | **Settings** → **Face ID & Passcode** → **USB Accessories** (off when locked) |
| Reset trust list | **Settings** → **General** → **Transfer or Reset iPhone** → **Reset** → **Reset Location & Privacy** |
| Personal Hotspot | **Settings** → **Personal Hotspot** |
| Software Update | **Settings** → **General** → **Software Update** |

---

## When plugged into Windows (Andy’s SOC laptop)

1. **Trust** only when you initiated the connection (encrypted backup, photo import).
2. **Apple Devices** — prefer **encrypted local backup**; password in password manager (never in git).
3. Backup trees covered by CTG nightly: `D:\Backups\Andy-PC-YYYY-MM-DD\`, `C:\Users\Owner\Backups\...`, OneDrive `Backups\`.
4. **Disable auto-sync** in Apple Devices unless you want sync on every connect.
5. Run read-only checklist (no device modification):

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\iphone\iphone_tethering_privacy_checklist.ps1
```

Legacy log stub (USB detect only): `.\scripts\windows\iphone_usb_check.ps1`

---

## Hotspot vs USB tethering — blue-team framing

| Vector | Hotspot (Wi‑Fi) | USB tethering |
|--------|-----------------|---------------|
| Nearby eavesdrop | WPA2/WPA3 on hotspot; use strong password | Cable only — no over-the-air |
| Laptop IDS visibility | Phone as gateway; Snort/Suricata on laptop sees tunneled traffic | Same; different adapter name |
| Physical | Shoulder-surf / evil twin if misconfigured | Trust + Restricted Mode matter most |
| Recommendation | Fine for lab; rotate password | Prefer for sensitive sessions when cable available |

Network-layer IDS on the Windows SOC (**Snort/Suricata**) detects **malicious traffic** — not RAM side-channel bugs on the phone SoC. See [SECURITY_HARDENING.md § IDS vs CPU](SECURITY_HARDENING.md#ids-vs-cpu-side-channel-exploits-honest-scope).

---

## What CTG automates (Windows)

| Script | Behavior |
|--------|----------|
| `scripts/iphone/iphone_tethering_privacy_checklist.ps1` | Prints checklist + Settings paths; optional USB PnP detect |
| `scripts/windows/iphone_usb_check.ps1` | Log-only one-liner when Apple USB PnP present |

Neither script changes iPhone settings, MAC addresses, or hardware IDs.

---

**Author:** [Hacker Planet LLC](ABOUT_HACKER_PLANET.md) · **Maintained with:** [IPHONE_HARDENING.md](IPHONE_HARDENING.md)
