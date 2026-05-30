# iPhone 15 Pro Max — run Phase 1 + Phase 2 now

**Device:** iPhone 15 Pro Max · **iOS:** 17 / 18  
**Full reference:** [IPHONE_HARDENING.md](IPHONE_HARDENING.md) (Phase definitions, UTMS honesty, Lockdown tradeoffs)  
**USB detail:** [IPHONE_USB_HARDENING.md](IPHONE_USB_HARDENING.md)

Manual steps only — **no CTG automation can change iPhone Settings** without Apple MDM. Run on the phone today in order: **Phase 1 → Phase 2 → verify**.

**Rule:** **Do not replace** Andy’s existing **DuckDuckGo VPN/DNS** or **DuckDuckGo Password Manager** (or any working VPN/DNS). Phase 1 is Settings-only and safe. Phase 2 adds Malwarebytes and USB layers — **skip** Cloudflare/NextDNS if VPN/DNS is already set. **Keep DuckDuckGo Password Manager** — do not migrate to Apple Keychain during hardening unless Andy chooses to.

---

## Order of operations (today)

| Order | Phase | Time (approx.) | What |
|-------|-------|------------------|------|
| **0** | Baseline | 2 min | Document VPN + Wi‑Fi DNS + DuckDuckGo Password Manager — do not change |
| **1** | Phase 1 | 15–25 min | Settings hardening (no new apps) |
| **1V** | Verify | 1 min | VPN + DNS unchanged |
| **2** | Phase 2 | 10–15 min | Malwarebytes, USB, optional Lockdown |
| **2V** | Verify | 1 min | VPN + DNS still match baseline |
| **\* ** | Windows | When cabled | Optional encrypted backup via Apple Devices |

---

## Step 0 — Baseline VPN, DNS & password manager (before Phase 1)

Document current state. **Do not toggle anything off.**

| Check | Path | Write down |
|-------|------|------------|
| **VPN profiles** | **Settings** → **General** → **VPN & Device Management** → **VPN** | Profile name(s), Connected / Not Connected |
| **Wi‑Fi DNS** | **Settings** → **Wi‑Fi** → **ⓘ** on home network → **Configure DNS** | Automatic / Manual (which servers) / Off |
| **DuckDuckGo Password Manager** | **Settings** → **General** → **AutoFill & Passwords** | **DuckDuckGo Passwords** / **DuckDuckGo Autofill** → **On**; confirm **DuckDuckGo** app installed |

**Andy — keep as-is:** **DuckDuckGo VPN / Privacy Pro** + **DuckDuckGo Password Manager (Autofill)**, iCloud Private Relay, corporate VPN, NextDNS, Cloudflare 1.1.1.1, Tailscale, Wi‑Fi Manual DNS. **Do not** disable DuckDuckGo autofill during hardening — Malwarebytes/Safari hardening is compatible.

**iOS rule:** Only **one** DNS-capturing VPN profile at a time. Phase 2 must **not** add Cloudflare **and** NextDNS on top of DuckDuckGo or any active DNS VPN.

---

## Phase 1 — Baseline hardening (Settings only)

These steps **do not** change VPN or DNS. Complete **all** before Phase 2.

### 1.1 — iOS current

- [ ] **Settings** → **General** → **Software Update** → install latest **iOS 17** or **18**
- [ ] **Automatic Updates** → **On** (iOS Updates + Security Responses & System Files)

### 1.2 — Passcode, Face ID, Stolen Device Protection

- [ ] **Settings** → **Face ID & Passcode** → **Custom Alphanumeric Code** (or strong 6-digit minimum)
- [ ] Confirm **Face ID** for unlock / Apple Pay as you use them
- [ ] **Stolen Device Protection** → **On** (requires iOS **17.3+**)

### 1.3 — Find My

- [ ] **Settings** → **[your name]** → **Find My** → **Find My iPhone** → **On**
- [ ] **Find My network** and **Send Last Location** → **On** if shown

### 1.4 — Apple ID

- [ ] **Settings** → **[your name]** → **Sign-In & Security** → **Two-Factor Authentication** → **On**
- [ ] **Sign-In & Security** → **Devices** — remove anything unrecognized
- [ ] Unique strong Apple ID password (**keep DuckDuckGo Password Manager** for autofill; iCloud Keychain may coexist)

### 1.5 — Safari

- [ ] **Settings** → **Apps** → **Safari** (or **Settings** → **Safari** on some versions)
- [ ] **Fraudulent Website Warning** → **On**
- [ ] **Prevent Cross-Site Tracking** → **On**
- [ ] **Hide IP Address** → **From Trackers and Websites** (or Trackers Only)
- [ ] Optional: **Block Pop-ups** → **On**

### 1.6 — Mail

- [ ] **Settings** → **Apps** → **Mail** → **Privacy Protection** → **Protect Mail Activity** → **On**

### 1.7 — Privacy permissions

- [ ] **Settings** → **Privacy & Security** → **Bluetooth** — revoke apps that do not need Bluetooth
- [ ] **Settings** → **Privacy & Security** → **Local Network** — revoke unnecessary LAN access
- [ ] **Settings** → **Privacy & Security** → **Tracking** — deny cross-app tracking
- [ ] Optional: **Location Services** — per-app minimum; review **System Services**

### 1.8 — Lock screen

- [ ] **Settings** → **Face ID & Passcode** → **Allow Access When Locked** — turn off unneeded items
- [ ] **Settings** → **Notifications** → sensitive apps → **Show Previews** → **When Unlocked** or **Never**

### 1.9 — USB Restricted Mode (also Phase 2 — set now)

- [ ] **Settings** → **Face ID & Passcode** → **USB Accessories** (or **Allow Accessories When Locked**) → **Off**

### 1.10 — AirDrop & profiles

- [ ] **Settings** → **General** → **AirDrop** → **Contacts Only** (or **Receiving Off** in public)
- [ ] **Settings** → **General** → **VPN & Device Management** — remove profiles you did not install from known work/school MDM

### 1.11 — Recommended extras (same session if time)

- [ ] **Settings** → **Privacy & Security** → **Analytics & Improvements** — disable if minimizing telemetry
- [ ] **Settings** → **Apps** → **Messages** → **Filter Unknown Senders** → **On**
- [ ] **Settings** → **General** → **AutoFill & Passwords** → **DuckDuckGo Passwords** / **DuckDuckGo Autofill** → **On** (verify — do not turn off)
- [ ] Optional: **Settings** → **[your name]** → **iCloud** → **Passwords** → **Sync this iPhone** → **On**; review Security Recommendations (does not replace DuckDuckGo PM)

### Phase 1 verify (required before Phase 2)

- [ ] **Settings** → **General** → **VPN & Device Management** → **VPN** — **same** as Step 0 (DuckDuckGo / existing profile still **Connected** if it was before)
- [ ] **Settings** → **Wi‑Fi** → **ⓘ** → **Configure DNS** — **unchanged** from Step 0
- [ ] **Settings** → **General** → **AutoFill & Passwords** → **DuckDuckGo Autofill** still **On** (unchanged from Step 0)

More detail: [IPHONE_HARDENING.md § Phase 1](IPHONE_HARDENING.md#phase-1-checklist-baseline--do-all).

---

## Phase 2 — Advanced layers (after Phase 1 verify)

### 2.1 — Malwarebytes (always — safe with DuckDuckGo / existing VPN/DNS)

Malwarebytes **free** tier = SMS filtering + Safari content blocking. It does **not** install a system DNS VPN.

1. **App Store** → **Search** → **Malwarebytes Mobile Security** → **Get**
2. Open **Malwarebytes** → complete onboarding
3. **Settings** → **Apps** → **Messages** → **Unknown & Spam** → enable **Malwarebytes**
4. **Settings** → **Apps** → **Safari** → **Extensions** → enable Malwarebytes blockers if offered
5. **Do not** enable **Malwarebytes paid VPN** — keep DuckDuckGo / existing VPN/DNS

### 2.2 — DNS VPN apps (skip if Step 0 already configured)

| Your Step 0 baseline | Action |
|----------------------|--------|
| **DuckDuckGo**, corporate VPN, Private Relay, NextDNS, Cloudflare, or other DNS VPN **connected** | **SKIP** Cloudflare 1.1.1.1 and NextDNS — your DNS layer is already UTMS-like |
| Wi‑Fi **Manual DNS** you want to keep | **SKIP** DNS VPN apps |
| No VPN and no Manual DNS | **Optional:** install **one** of **Cloudflare 1.1.1.1** **or** **NextDNS** (not both) |

Install steps (only if table says you need one): [IPHONE_HARDENING.md § Manual install](IPHONE_HARDENING.md#what-andy-must-do-manually-on-the-iphone).

**Optional Wi‑Fi-only DNS (no VPN app):** **Settings** → **Wi‑Fi** → **ⓘ** → **Configure DNS** → **Manual** → add resolvers → affects **this Wi‑Fi only**.

### 2.3 — USB connection hardening

Run when using **USB-C** to the Windows laptop or after trusting a new PC. **Does not** change VPN/DNS.

**On iPhone:**

- [ ] **USB Accessories** OFF when locked — confirm [1.9](#19--usb-restricted-mode-also-phase-2--set-now)
- [ ] **Trust This Computer** — only Andy’s laptop; if unsure → **Settings** → **General** → **Transfer or Reset iPhone** → **Reset** → **Reset Location & Privacy**
- [ ] **Stolen Device Protection** ON — confirm [1.2](#12--passcode-face-id-stolen-device-protection)
- [ ] **Find My iPhone** ON — confirm [1.3](#13--find-my)
- [ ] **Settings** → **Privacy & Security** → **Developer Mode** → **Off** (unless active dev week)
- [ ] **Settings** → **General** → **VPN & Device Management** — no unknown profiles
- [ ] Trusted USB-C cable; **USB data blocker** on untrusted public charge ports when possible

**On Windows (when cable attached):**

- [ ] **Apple Devices** → select iPhone → enable **Encrypt local backup** → **Back Up Now** (encryption password in password manager — never git)
- [ ] Turn **off** automatic sync unless you want photos/music every connect
- [ ] Optional log reminder (no phone changes):

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\iphone_usb_check.ps1
```

Backup paths (CTG nightly): `D:\Backups\Andy-PC-YYYY-MM-DD\`, `C:\Users\Owner\Backups\...`, OneDrive `Backups\Andy-PC-...` — [IPHONE_USB_HARDENING.md](IPHONE_USB_HARDENING.md).

### 2.4 — Lockdown Mode (optional)

Use only if you face a **credible targeted threat**. Normal daily use: **skip**.

- [ ] **Settings** → **Privacy & Security** → **Lockdown Mode** → **Turn On Lockdown Mode**
- Tradeoffs: some websites/messages/shared albums behave differently; stronger USB limits when locked — [IPHONE_HARDENING.md § 8](IPHONE_HARDENING.md#8-lockdown-mode-optional--high-threat-profile)

### 2.5 — Free UTMS / AV honesty (no install — read once)

- **No filesystem AV or Cardputer UTMS on iPhone** — sandbox + XProtect only
- **Your stack:** Phase 1 Settings + Phase 2 Malwarebytes (SMS/Safari) + **keep** DuckDuckGo VPN/DNS = honest defense-in-depth
- **Cardputer UTMS** stays on M5 — separate device — [IPHONE_HARDENING.md § UTMS-like layers](IPHONE_HARDENING.md#free-security-apps--utms-like-layers-keep-vpndns)
- **Do not install** “virus cleaner,” “phone booster,” or fake AV apps

### Phase 2 verify (required — end of session)

- [ ] **Settings** → **General** → **VPN & Device Management** → **VPN** — matches Step 0 baseline
- [ ] **Settings** → **Wi‑Fi** → **ⓘ** → **Configure DNS** — matches Step 0 baseline
- [ ] VPN icon in status bar behaves as before (if you used VPN before)
- [ ] Browse a familiar site — no unexpected captive portal or “no internet”

**If something broke:** Disconnect any **new** VPN profile from Phase 2; DuckDuckGo / original profile should return. Do not disable corporate VPN or Private Relay without IT intent.

More detail: [IPHONE_HARDENING.md § Phase 2](IPHONE_HARDENING.md#phase-2-checklist-advanced-layers--do-after-phase-1).

---

## Quick decision card

```
DuckDuckGo or VPN/DNS already set?  →  Phase 1 YES  |  Phase 2 Malwarebytes YES  |  Cloudflare/NextDNS SKIP
No VPN/DNS at all?                  →  Phase 1 YES  |  Phase 2 Malwarebytes YES  |  Cloudflare OR NextDNS (one, optional)
USB to Windows laptop today?        →  Phase 2 § 2.3 USB  |  encrypted backup  |  Phase 2 verify VPN unchanged
High-threat / targeted?             →  Phase 2 § 2.4 Lockdown Mode (optional)
Pocket UTMS?                        →  M5 Cardputer only — not iPhone App Store
```

---

## One-page checkbox (print or Notes app)

**Step 0:** VPN + Wi‑Fi DNS + DuckDuckGo Password Manager documented — keep DuckDuckGo VPN + PM  
**Phase 1:** 1.1–1.11 Settings ✓ → **1.V verify VPN/DNS**  
**Phase 2:** Malwarebytes ✓ → skip DNS VPN if set ✓ → USB ✓ → (optional Lockdown) → **2.V verify VPN/DNS**

---

**Author:** [Hacker Planet LLC](ABOUT_HACKER_PLANET.md) · **Maintained with:** [IPHONE_HARDENING.md](IPHONE_HARDENING.md)
