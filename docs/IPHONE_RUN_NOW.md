# iPhone 15 Pro Max — run now (preserve VPN & DNS)

**Device:** iPhone 15 Pro Max · **iOS:** 17 / 18  
**Full reference:** [IPHONE_HARDENING.md](IPHONE_HARDENING.md)  
**USB focus:** [IPHONE_USB_HARDENING.md](IPHONE_USB_HARDENING.md)

Use this checklist on the phone. **Do not replace** an existing VPN profile or DNS setup unless you intentionally want to switch.

---

## Step 0 — Baseline VPN & DNS (do this first)

Document current state **before** any hardening app installs:

| Check | Path | Write down |
|-------|------|------------|
| **VPN profiles** | **Settings** → **General** → **VPN & Device Management** → **VPN** | Profile name(s), Connected / Not Connected |
| **Wi‑Fi DNS** | **Settings** → **Wi‑Fi** → **ⓘ** on home network → **Configure DNS** | Automatic / Manual (which servers) / Off |

Examples of “already set — do not override”: iCloud Private Relay, corporate VPN, NextDNS app, Cloudflare 1.1.1.1, Tailscale, Wi‑Fi Manual DNS (1.1.1.1, 9.9.9.9, custom NextDNS IP).

**iOS rule:** Only **one** DNS VPN–style app can be active. Do not install Cloudflare **and** NextDNS **and** keep MDM DNS — pick one strategy.

---

## Step 1 — Settings hardening (always safe with VPN/DNS)

These do **not** change VPN or DNS. Run all of them:

- [ ] **Settings** → **General** → **Software Update** → install latest iOS; turn **Automatic Updates** on
- [ ] **Settings** → **Face ID & Passcode** → strong passcode; **Stolen Device Protection** on (iOS 17.3+)
- [ ] **Settings** → **[your name]** → **Find My** → **Find My iPhone** on
- [ ] **Settings** → **[your name]** → **Sign-In & Security** → **Two-Factor Authentication** on; remove unknown devices
- [ ] **Settings** → **Apps** → **Safari** → **Fraudulent Website Warning** on; **Prevent Cross-Site Tracking** on; **Hide IP Address** as preferred
- [ ] **Settings** → **Apps** → **Mail** → **Protect Mail Activity** on
- [ ] **Settings** → **Privacy & Security** → audit **Bluetooth** and **Local Network**
- [ ] **Settings** → **Face ID & Passcode** → **Allow Access When Locked** — restrict previews
- [ ] **Settings** → **Face ID & Passcode** → **USB Accessories** off when locked
- [ ] **Settings** → **General** → **AirDrop** → **Contacts Only** (or Receiving Off in public)

Details and optional items (Lockdown Mode, analytics off): [IPHONE_HARDENING.md](IPHONE_HARDENING.md).

---

## Step 2 — Malwarebytes (install even if VPN/DNS already set)

Malwarebytes free tier does **not** replace system DNS or VPN.

1. **App Store** → search **Malwarebytes Mobile Security** → install
2. Open app → complete onboarding
3. **Settings** → **Apps** → **Messages** → **Unknown & Spam** → enable **Malwarebytes**
4. **Settings** → **Apps** → **Safari** → **Extensions** → enable Malwarebytes blockers if offered
5. **Do not** enable Malwarebytes paid VPN if you keep your existing VPN/DNS

---

## Step 3 — DNS VPN apps (skip if already configured)

| Your baseline (Step 0) | Action |
|------------------------|--------|
| Corporate VPN, Private Relay, NextDNS, Cloudflare, or other DNS VPN **already connected** | **SKIP** Cloudflare 1.1.1.1 and NextDNS installs |
| Wi‑Fi **Manual DNS** you want to keep | **SKIP** DNS VPN apps unless replacing that setup |
| No VPN and no Manual DNS | **Optional:** install **one** of Cloudflare 1.1.1.1 **or** NextDNS (not both) |

Install instructions (only if skipping table says you need one): [IPHONE_HARDENING.md § Manual install](IPHONE_HARDENING.md#what-andy-must-do-manually-on-the-iphone).

**Optional Wi‑Fi-only DNS (no VPN app):** **Settings** → **Wi‑Fi** → **ⓘ** → **Configure DNS** → **Manual** → add resolvers → affects **this Wi‑Fi only**; cellular VPN unchanged.

---

## Step 4 — Verify VPN & DNS unchanged

After Steps 1–3:

- [ ] **Settings** → **General** → **VPN & Device Management** → **VPN** — same profile(s) as Step 0 baseline
- [ ] **Settings** → **Wi‑Fi** → **ⓘ** → **Configure DNS** — matches Step 0 (Automatic / Manual / Off)
- [ ] VPN icon in status bar behaves as before (if you used VPN before)
- [ ] Browse a familiar site — no unexpected “no internet” or captive portal

**If something broke:** Disconnect any **new** VPN profile you added during hardening; your original setup should return. Do not toggle off corporate VPN or Private Relay without IT / intent.

---

## Step 5 — USB connection hardening (preserve VPN/DNS)

Run when you use **USB-C** to the Windows laptop or after trusting a new PC. **Does not** change VPN/DNS if you skip new DNS VPN apps.

### Keep VPN/DNS (repeat before and after)

- **Do not** install DuckDuckGo/NextDNS/Cloudflare/**second** DNS VPN if one is already working.
- **Malwarebytes** SMS/Safari only — **no** Malwarebytes VPN if you keep existing VPN/DNS.
- After this step: **Settings** → **General** → **VPN & Device Management** → **VPN** — same as Step 0.

### On the iPhone

- [ ] **Settings** → **Face ID & Passcode** → **USB Accessories** → **Off** when locked
- [ ] **Trust This Computer** — only on Andy’s laptop; if unsure → **Settings** → **General** → **Transfer or Reset iPhone** → **Reset** → **Reset Location & Privacy**
- [ ] **Settings** → **Face ID & Passcode** → **Stolen Device Protection** on
- [ ] **Settings** → **[your name]** → **Find My** → **Find My iPhone** on
- [ ] **Settings** → **Privacy & Security** → **Developer Mode** off (unless dev week)
- [ ] **Settings** → **General** → **VPN & Device Management** — no unknown profiles
- [ ] Trusted USB-C cable; data blocker for untrusted public charging when possible
- [ ] (Optional) **Settings** → **Privacy & Security** → **Lockdown Mode** — see [IPHONE_HARDENING.md](IPHONE_HARDENING.md)

### On Windows (when cable attached)

- [ ] **Apple Devices** → device → **Encrypt local backup** → **Back Up Now** (password in password manager)
- [ ] Turn **off** automatic sync unless you want it every connect
- [ ] Optional log reminder (no phone changes):

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\iphone_usb_check.ps1
```

Backup paths aligned with nightly CTG: `D:\Backups\Andy-PC-YYYY-MM-DD\`, `C:\Users\Owner\Backups\...`, OneDrive `Backups\Andy-PC-...` — details in [IPHONE_USB_HARDENING.md](IPHONE_USB_HARDENING.md).

---

## Quick decision card

```
HAVE VPN or DNS already?  →  Settings hardening YES  |  Malwarebytes YES  |  Cloudflare/NextDNS SKIP
NO VPN/DNS?               →  Settings hardening YES  |  Malwarebytes YES  |  Cloudflare OR NextDNS (pick one, optional)
Want Wi‑Fi DNS only?      →  Configure DNS → Manual on home Wi‑Fi  |  skip DNS VPN apps
USB to Windows laptop?    →  Step 5 USB hardening  |  encrypted backup  |  VPN verify unchanged
```

---

**Author:** [Hacker Planet LLC](ABOUT_HACKER_PLANET.md) · **Maintained with:** [IPHONE_HARDENING.md](IPHONE_HARDENING.md)
