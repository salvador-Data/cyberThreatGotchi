# iPhone USB connection hardening — iPhone 15 Pro Max, iOS 17 / 18

**Hacker Planet LLC / CyberThreatGotchi** — defensive guidance for USB-C and **Trust This Computer** when you connect your iPhone to Andy’s Windows SOC laptop. Use with the full mobile runbook: [IPHONE_RUN_NOW.md](IPHONE_RUN_NOW.md) (Phase 2 § 2.3) · [IPHONE_HARDENING.md](IPHONE_HARDENING.md).

**Windows companion:** [scripts/windows/README_WINDOWS_SOC.md](../scripts/windows/README_WINDOWS_SOC.md) · stub `scripts/windows/iphone_usb_check.ps1` (log-only reminder).

---

## Keep VPN, DNS, and DuckDuckGo Password Manager (do not break while hardening USB)

Hardening USB settings and Windows backup habits **does not** require changing VPN, DNS, or password autofill. Repeat these rules every time you plug in:

| Rule | Why |
|------|-----|
| **Do not** install a second DNS VPN app if **DuckDuckGo**, **NextDNS**, **Cloudflare 1.1.1.1**, or **Wi‑Fi Manual DNS** is already working | iOS allows only one DNS-capturing VPN profile at a time |
| **Keep DuckDuckGo Password Manager** — **Settings** → **General** → **AutoFill & Passwords** → DuckDuckGo Autofill **On** | Hardening is not a reason to migrate to Apple Keychain; Malwarebytes/Safari layers are compatible |
| **Malwarebytes** SMS/Safari only — **no** Malwarebytes paid VPN if you keep existing VPN/DNS | Avoids a competing system VPN profile |
| After any Settings change, verify **Settings** → **General** → **VPN & Device Management** → **VPN** — profile unchanged |
| Re-check **Settings** → **Wi‑Fi** → **ⓘ** → **Configure DNS** — still Automatic / Manual / Off as before |

Full preserve-VPN/DNS tables: [IPHONE_HARDENING.md § Preserve your existing VPN and DNS](IPHONE_HARDENING.md#preserve-your-existing-vpn-and-dns-read-before-installing-apps).

---

## On the iPhone — USB-specific settings

Tap **Settings** in order below. Names may vary slightly on iOS 17 vs 18.

### 1. USB Restricted Mode (required)

1. **Settings** → **Face ID & Passcode** (enter passcode)
2. **USB Accessories** (or **Allow Accessories When Locked**) → **Off**

Effect: After the device has been locked for about **one hour**, USB data connections (including some forensic/accessory tools) are blocked until you unlock with Face ID or passcode. **Charging** still works.

### 2. Trust This Computer (only Andy’s laptop)

When you first plug into Windows, iPhone shows **Trust This Computer?**

- Tap **Trust** only on **your** SOC laptop (Andy’s daily driver)
- Enter passcode when prompted
- If you ever trusted a hotel PC, friend’s machine, or unknown kiosk → reset trust list:

1. **Settings** → **General** → **Transfer or Reset iPhone** → **Reset** → **Reset Location & Privacy**
2. Re-trust **only** your laptop on next USB connect

### 3. Stolen Device Protection (already in main doc — confirm on)

1. **Settings** → **Face ID & Passcode** → **Stolen Device Protection** → **On** (iOS 17.3+)

Adds friction for passcode/Apple ID changes away from familiar locations — complements USB lockdown.

### 4. Find My and Activation Lock

1. **Settings** → **[your name]** → **Find My** → **Find My iPhone** → **On**
2. Enable **Find My network** and **Send Last Location** if shown

USB theft or “juice jacking” at public ports is rarer than device loss; Find My remains the primary anti-theft control.

### 5. Developer Mode (off unless needed)

1. **Settings** → **Privacy & Security** → **Developer Mode** → **Off**

Turn on only when actively building Cardputer/firmware or Xcode workflows; off for daily carry.

### 6. Configuration profiles (unknown sources)

1. **Settings** → **General** → **VPN & Device Management**
2. Remove any profile you did not install from **work/school MDM** you recognize

Never install profiles from “speed booster,” sideload, or random links. **CTG does not push MDM** without your Apple Business Manager enrollment.

### 7. Lockdown Mode (optional — stronger USB limits)

1. **Settings** → **Privacy & Security** → **Lockdown Mode** → **Turn On**

**Tradeoffs:** Further restricts wired accessories when locked, some web/messaging features, and shared albums. Use if you face credible targeted threat; skip for normal daily use if friction is too high.

See [IPHONE_HARDENING.md § Lockdown Mode](IPHONE_HARDENING.md#8-lockdown-mode-optional--high-threat-profile).

### 8. USB-C cable and public charging

- Use **Apple or MFi/trusted** USB-C cable for data sync to the laptop
- Prefer **AC adapter or battery pack** in public; avoid unknown USB-A/C ports when possible
- For untrusted ports, use a **USB data blocker** (charge-only adapter) so the port cannot negotiate data

---

## When plugged into Windows (Andy’s SOC laptop)

Apple does not expose full device policy APIs to arbitrary PowerShell scripts. **Hardening happens on the phone**; Windows side is backup hygiene and reminders only.

### Apple Devices / iTunes — encrypted local backup (recommended)

1. Install **Apple Devices** (or legacy iTunes) from Microsoft Store / Apple
2. Connect iPhone via USB-C → unlock → **Trust** if prompted
3. Select the device → **Back Up Now**
4. Enable **Encrypt local backup** (store encryption password in your password manager — **not** in git)
5. Save backups to a path covered by nightly CTG backup:

| Tier | Path |
|------|------|
| **SSD (preferred)** | `D:\Backups\Andy-PC-YYYY-MM-DD\` (when D: online) |
| **C: fallback** | `C:\Users\Owner\Backups\Andy-PC-YYYY-MM-DD\` |
| **OneDrive staging** | `OneDrive\Backups\Andy-PC-YYYY-MM-DD\` via `cloud_backup.ps1` |

Default Apple backup location is under `%AppData%\Apple Computer\MobileSync\Backup\` — ensure that folder is included in selective backup scope or copy encrypted backup sets into `Andy-PC-*` trees if you want them in SSD/OneDrive manifests.

**Optional nightly note:** `ctg_nightly_4am.ps1` does **not** run Apple backup automatically (requires unlocked phone + trust). Run encrypted backup manually after major iOS upgrades or monthly.

### Disable auto-sync junk

In **Apple Devices** / iTunes:

- Turn **off** automatic sync when iPhone connects if you only need occasional encrypted backup
- Do **not** enable “Automatically sync when this iPhone is connected” for photos/music unless you intentionally want it

### What Windows scripts do (and do not do)

| Allowed | Not allowed |
|---------|-------------|
| `iphone_usb_check.ps1` logs “iPhone attached — run IPHONE_RUN_NOW USB section” | Push MDM profiles without Apple Business Manager |
| `selective_ssd_backup.ps1` / `cloud_backup.ps1` stage manifests | Modify iPhone Settings from PC without Apple APIs |
| Manual encrypted backup via Apple Devices | Install App Store apps remotely |

---

## Quick USB checklist

```
[ ] VPN + Wi‑Fi DNS documented (unchanged after USB hardening)
[ ] USB Accessories OFF when locked (USB Restricted Mode)
[ ] Only Andy's laptop trusted; Reset Location & Privacy if unknown PCs were trusted
[ ] Find My ON; Stolen Device Protection ON
[ ] Developer Mode OFF (unless dev week)
[ ] No unknown configuration profiles
[ ] Trusted USB-C cable; data blocker for untrusted public ports
[ ] (Optional) Lockdown Mode if high-threat
[ ] Encrypted local backup via Apple Devices when plugged in
[ ] Auto-sync OFF unless you want it
[ ] Settings → VPN — profile still correct after all steps
```

---

**Author:** [Hacker Planet LLC](ABOUT_HACKER_PLANET.md) · **Maintained with:** [IPHONE_HARDENING.md](IPHONE_HARDENING.md) · [SECURITY_HARDENING.md](SECURITY_HARDENING.md)
