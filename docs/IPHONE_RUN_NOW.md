# iPhone 15 Pro Max â€” run Phase 1 + Phase 2 now

**Device:** iPhone 15 Pro Max Â· **iOS:** 17 / 18  
**Full reference:** [IPHONE_HARDENING.md](IPHONE_HARDENING.md) (Phase definitions, UTMS honesty, Lockdown tradeoffs)  
**USB detail:** [IPHONE_USB_HARDENING.md](IPHONE_USB_HARDENING.md)

---

## One command â€” full automated assist (recommended)

From repo root â€” interactive orchestrator for all **21 steps** (Step 0 â†’ Phase 1 â†’ Phase 2 â†’ verify). Logs progress, shows Settings deep links, preserves DuckDuckGo VPN/DNS/Password Manager warnings.

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\iphone_hardening_automate.ps1 -OpenGuide
```

Resume where you left off:

```powershell
.\scripts\windows\iphone_hardening_automate.ps1 -Resume -OpenGuide
```

Validate URLs without prompts (dry-run):

```powershell
.\scripts\windows\iphone_hardening_automate.ps1 -LogOnly
```

Same Wi-Fi LAN URL for phone (optional):

```powershell
.\scripts\windows\iphone_hardening_automate.ps1 -OpenGuide -ServeOnLan
```

**Honest limit:** Stock iOS cannot auto-toggle Settings from Windows â€” you tap each change; the script guides, copies deep links, and logs to `%USERPROFILE%\Backups\logs\iphone_hardening_automate.log`.

Legacy alias (same behavior): `iphone_hardening_assist.ps1` forwards to `iphone_hardening_automate.ps1`.

---

## Guided walkthrough (Safari on phone)

Use the **step-by-step wizard** on your iPhone â€” **Previous / Next**, progress bar, and **Open Settings** deep links per step (with manual fallback on every screen). Preserves DuckDuckGo VPN/DNS and DuckDuckGo Password Manager warnings throughout.

| Resource | Use when |
|----------|----------|
| **[iphone_hardening_guide.html](iphone_hardening_guide.html)** | Primary: AirDrop or Files â†’ open in **Safari** on the phone |
| **Windows:** `.\scripts\windows\iphone_hardening_automate.ps1 -OpenGuide` | Full 21-step orchestrator + opens HTML wizard (sync via `?step=N`) |
| **[iphone_hardening_shortcuts.md](iphone_hardening_shortcuts.md)** | Optional iOS **Shortcuts** routine (open URL â†’ wait â†’ next pane) |
| [iphone-run-now.html](../website/iphone-run-now.html) | Static tap list on GitHub Pages (no Prev/Next wizard) |

**Simplest on phone:** AirDrop `docs/iphone_hardening_guide.html` from the laptop â†’ tap â†’ **Open in Safari**.

**Honest limit:** Stock iOS cannot auto-enable Face ID, passcodes, or Settings toggles â€” the guide only opens the right pane; you tap through.

---

Manual checklist below â€” **no CTG automation can change iPhone Settings** without Apple MDM. Run on the phone today in order: **Phase 1 â†’ Phase 2 â†’ verify**.

**Rule:** **Do not replace** Andyâ€™s existing **DuckDuckGo VPN/DNS** or **DuckDuckGo Password Manager** (or any working VPN/DNS). Phase 1 is Settings-only and safe. Phase 2 adds Malwarebytes and USB layers â€” **skip** Cloudflare/NextDNS if VPN/DNS is already set. **Keep DuckDuckGo Password Manager** â€” do not migrate to Apple Keychain during hardening unless Andy chooses to.

---

## Automated assist (Windows + Shortcuts)

**Best-effort guided automation** â€” not full remote hardening. Stock iOS still requires **you** to tap toggles, enroll Face ID, trust USB, and install App Store apps.

| Tool | What it does |
|------|----------------|
| **`scripts/windows/iphone_hardening_automate.ps1`** | Primary: interactive 21-step flow, USB check at start, deep-link clipboard, `-Resume`, `-LogOnly`, `-OpenGuide`, `-ServeOnLan`. Log: `Backups\logs\iphone_hardening_automate.log`. |
| **`scripts/windows/iphone_hardening_assist.ps1`** | Deprecated alias â€” forwards to `iphone_hardening_automate.ps1` (`-OpenRunbook` still works). |
| **[iphone_hardening_shortcuts.md](iphone_hardening_shortcuts.md)** | Importable **CTG iPhone Harden** Shortcuts recipe (open URL â†’ wait â†’ next). |
| **[iphone-run-now.html](../website/iphone-run-now.html)** | Static tap list on GitHub Pages (no Prev/Next wizard). |

**Cannot automate:** passcode/Face ID, Trust This Computer, Malwarebytes permissions, encrypted backup password, or replacing DuckDuckGo VPN/DNS/Password Manager without your intent.

---

## Order of operations (today)

| Order | Phase | Time (approx.) | What |
|-------|-------|------------------|------|
| **0** | Baseline | 2 min | Document VPN + Wiâ€‘Fi DNS + DuckDuckGo Password Manager â€” do not change |
| **1** | Phase 1 | 15â€“25 min | Settings hardening (no new apps) |
| **1V** | Verify | 1 min | VPN + DNS unchanged |
| **2** | Phase 2 | 10â€“15 min | Malwarebytes, USB, optional Lockdown |
| **2V** | Verify | 1 min | VPN + DNS still match baseline |
| **\* ** | Windows | When cabled | Optional encrypted backup via Apple Devices |

---

## Step 0 â€” Baseline VPN, DNS & password manager (before Phase 1)

Document current state. **Do not toggle anything off.**

| Check | Path | Write down |
|-------|------|------------|
| **VPN profiles** | **Settings** â†’ **General** â†’ **VPN & Device Management** â†’ **VPN** | Profile name(s), Connected / Not Connected |
| **Wiâ€‘Fi DNS** | **Settings** â†’ **Wiâ€‘Fi** â†’ **â“˜** on home network â†’ **Configure DNS** | Automatic / Manual (which servers) / Off |
| **DuckDuckGo Password Manager** | **Settings** â†’ **General** â†’ **AutoFill & Passwords** | **DuckDuckGo Passwords** / **DuckDuckGo Autofill** â†’ **On**; confirm **DuckDuckGo** app installed |

**Andy â€” keep as-is:** **DuckDuckGo VPN / Privacy Pro** + **DuckDuckGo Password Manager (Autofill)**, iCloud Private Relay, corporate VPN, NextDNS, Cloudflare 1.1.1.1, Tailscale, Wiâ€‘Fi Manual DNS. **Do not** disable DuckDuckGo autofill during hardening â€” Malwarebytes/Safari hardening is compatible.

**iOS rule:** Only **one** DNS-capturing VPN profile at a time. Phase 2 must **not** add Cloudflare **and** NextDNS on top of DuckDuckGo or any active DNS VPN.

---

## Phase 1 â€” Baseline hardening (Settings only)

These steps **do not** change VPN or DNS. Complete **all** before Phase 2.

### 1.1 â€” iOS current

- [ ] **Settings** â†’ **General** â†’ **Software Update** â†’ install latest **iOS 17** or **18**
- [ ] **Automatic Updates** â†’ **On** (iOS Updates + Security Responses & System Files)

### 1.2 â€” Passcode, Face ID, Stolen Device Protection

- [ ] **Settings** â†’ **Face ID & Passcode** â†’ **Custom Alphanumeric Code** (or strong 6-digit minimum)
- [ ] Confirm **Face ID** for unlock / Apple Pay as you use them
- [ ] **Stolen Device Protection** â†’ **On** (requires iOS **17.3+**)

### 1.3 â€” Find My

- [ ] **Settings** â†’ **[your name]** â†’ **Find My** â†’ **Find My iPhone** â†’ **On**
- [ ] **Find My network** and **Send Last Location** â†’ **On** if shown

### 1.4 â€” Apple ID

- [ ] **Settings** â†’ **[your name]** â†’ **Sign-In & Security** â†’ **Two-Factor Authentication** â†’ **On**
- [ ] **Sign-In & Security** â†’ **Devices** â€” remove anything unrecognized
- [ ] Unique strong Apple ID password (**keep DuckDuckGo Password Manager** for autofill; iCloud Keychain may coexist)

### 1.5 â€” Safari

- [ ] **Settings** â†’ **Apps** â†’ **Safari** (or **Settings** â†’ **Safari** on some versions)
- [ ] **Fraudulent Website Warning** â†’ **On**
- [ ] **Prevent Cross-Site Tracking** â†’ **On**
- [ ] **Hide IP Address** â†’ **From Trackers and Websites** (or Trackers Only)
- [ ] Optional: **Block Pop-ups** â†’ **On**

### 1.6 â€” Mail

- [ ] **Settings** â†’ **Apps** â†’ **Mail** â†’ **Privacy Protection** â†’ **Protect Mail Activity** â†’ **On**

### 1.7 â€” Privacy permissions

- [ ] **Settings** â†’ **Privacy & Security** â†’ **Bluetooth** â€” revoke apps that do not need Bluetooth
- [ ] **Settings** â†’ **Privacy & Security** â†’ **Local Network** â€” revoke unnecessary LAN access
- [ ] **Settings** â†’ **Privacy & Security** â†’ **Tracking** â€” deny cross-app tracking
- [ ] Optional: **Location Services** â€” per-app minimum; review **System Services**

### 1.8 â€” Lock screen

- [ ] **Settings** â†’ **Face ID & Passcode** â†’ **Allow Access When Locked** â€” turn off unneeded items
- [ ] **Settings** â†’ **Notifications** â†’ sensitive apps â†’ **Show Previews** â†’ **When Unlocked** or **Never**

### 1.9 â€” USB Restricted Mode (also Phase 2 â€” set now)

- [ ] **Settings** â†’ **Face ID & Passcode** â†’ **USB Accessories** (or **Allow Accessories When Locked**) â†’ **Off**

### 1.10 â€” AirDrop & profiles

- [ ] **Settings** â†’ **General** â†’ **AirDrop** â†’ **Contacts Only** (or **Receiving Off** in public)
- [ ] **Settings** â†’ **General** â†’ **VPN & Device Management** â€” remove profiles you did not install from known work/school MDM

### 1.11 â€” Recommended extras (same session if time)

- [ ] **Settings** â†’ **Privacy & Security** â†’ **Analytics & Improvements** â€” disable if minimizing telemetry
- [ ] **Settings** â†’ **Apps** â†’ **Messages** â†’ **Filter Unknown Senders** â†’ **On**
- [ ] **Settings** â†’ **General** â†’ **AutoFill & Passwords** â†’ **DuckDuckGo Passwords** / **DuckDuckGo Autofill** â†’ **On** (verify â€” do not turn off)
- [ ] Optional: **Settings** â†’ **[your name]** â†’ **iCloud** â†’ **Passwords** â†’ **Sync this iPhone** â†’ **On**; review Security Recommendations (does not replace DuckDuckGo PM)

### Phase 1 verify (required before Phase 2)

- [ ] **Settings** â†’ **General** â†’ **VPN & Device Management** â†’ **VPN** â€” **same** as Step 0 (DuckDuckGo / existing profile still **Connected** if it was before)
- [ ] **Settings** â†’ **Wiâ€‘Fi** â†’ **â“˜** â†’ **Configure DNS** â€” **unchanged** from Step 0
- [ ] **Settings** â†’ **General** â†’ **AutoFill & Passwords** â†’ **DuckDuckGo Autofill** still **On** (unchanged from Step 0)

More detail: [IPHONE_HARDENING.md Â§ Phase 1](IPHONE_HARDENING.md#phase-1-checklist-baseline--do-all).

---

## Phase 2 â€” Advanced layers (after Phase 1 verify)

### 2.1 â€” Malwarebytes (always â€” safe with DuckDuckGo / existing VPN/DNS)

Malwarebytes **free** tier = SMS filtering + Safari content blocking. It does **not** install a system DNS VPN.

1. **App Store** â†’ **Search** â†’ **Malwarebytes Mobile Security** â†’ **Get**
2. Open **Malwarebytes** â†’ complete onboarding
3. **Settings** â†’ **Apps** â†’ **Messages** â†’ **Unknown & Spam** â†’ enable **Malwarebytes**
4. **Settings** â†’ **Apps** â†’ **Safari** â†’ **Extensions** â†’ enable Malwarebytes blockers if offered
5. **Do not** enable **Malwarebytes paid VPN** â€” keep DuckDuckGo / existing VPN/DNS

### 2.2 â€” DNS VPN apps (skip if Step 0 already configured)

| Your Step 0 baseline | Action |
|----------------------|--------|
| **DuckDuckGo**, corporate VPN, Private Relay, NextDNS, Cloudflare, or other DNS VPN **connected** | **SKIP** Cloudflare 1.1.1.1 and NextDNS â€” your DNS layer is already UTMS-like |
| Wiâ€‘Fi **Manual DNS** you want to keep | **SKIP** DNS VPN apps |
| No VPN and no Manual DNS | **Optional:** install **one** of **Cloudflare 1.1.1.1** **or** **NextDNS** (not both) |

Install steps (only if table says you need one): [IPHONE_HARDENING.md Â§ Manual install](IPHONE_HARDENING.md#what-andy-must-do-manually-on-the-iphone).

**Optional Wiâ€‘Fi-only DNS (no VPN app):** **Settings** â†’ **Wiâ€‘Fi** â†’ **â“˜** â†’ **Configure DNS** â†’ **Manual** â†’ add resolvers â†’ affects **this Wiâ€‘Fi only**.

### 2.3 â€” USB connection hardening

Run when using **USB-C** to the Windows laptop or after trusting a new PC. **Does not** change VPN/DNS.

**On iPhone:**

- [ ] **USB Accessories** OFF when locked â€” confirm [1.9](#19--usb-restricted-mode-also-phase-2--set-now)
- [ ] **Trust This Computer** â€” only Andyâ€™s laptop; if unsure â†’ **Settings** â†’ **General** â†’ **Transfer or Reset iPhone** â†’ **Reset** â†’ **Reset Location & Privacy**
- [ ] **Stolen Device Protection** ON â€” confirm [1.2](#12--passcode-face-id-stolen-device-protection)
- [ ] **Find My iPhone** ON â€” confirm [1.3](#13--find-my)
- [ ] **Settings** â†’ **Privacy & Security** â†’ **Developer Mode** â†’ **Off** (unless active dev week)
- [ ] **Settings** â†’ **General** â†’ **VPN & Device Management** â€” no unknown profiles
- [ ] Trusted USB-C cable; **USB data blocker** on untrusted public charge ports when possible

**On Windows (when cable attached):**

- [ ] **Apple Devices** â†’ select iPhone â†’ enable **Encrypt local backup** â†’ **Back Up Now** (encryption password in password manager â€” never git)
- [ ] Turn **off** automatic sync unless you want photos/music every connect
- [ ] Optional log reminder (no phone changes):

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

```powershell
.\scripts\windows\iphone_usb_check.ps1
```

Backup paths (CTG nightly): `D:\Backups\Andy-PC-YYYY-MM-DD\`, `C:\Users\Owner\Backups\...`, OneDrive `Backups\Andy-PC-...` â€” [IPHONE_USB_HARDENING.md](IPHONE_USB_HARDENING.md).

### 2.4 â€” Lockdown Mode (optional)

Use only if you face a **credible targeted threat**. Normal daily use: **skip**.

- [ ] **Settings** â†’ **Privacy & Security** â†’ **Lockdown Mode** â†’ **Turn On Lockdown Mode**
- Tradeoffs: some websites/messages/shared albums behave differently; stronger USB limits when locked â€” [IPHONE_HARDENING.md Â§ 8](IPHONE_HARDENING.md#8-lockdown-mode-optional--high-threat-profile)

### 2.5 â€” Free UTMS / AV honesty (no install â€” read once)

- **No filesystem AV or Cardputer UTMS on iPhone** â€” sandbox + XProtect only
- **Your stack:** Phase 1 Settings + Phase 2 Malwarebytes (SMS/Safari) + **keep** DuckDuckGo VPN/DNS = honest defense-in-depth
- **Cardputer UTMS** stays on M5 â€” separate device â€” [IPHONE_HARDENING.md Â§ UTMS-like layers](IPHONE_HARDENING.md#free-security-apps--utms-like-layers-keep-vpndns)
- **Do not install** â€œvirus cleaner,â€ â€œphone booster,â€ or fake AV apps

### Phase 2 verify (required â€” end of session)

- [ ] **Settings** â†’ **General** â†’ **VPN & Device Management** â†’ **VPN** â€” matches Step 0 baseline
- [ ] **Settings** â†’ **Wiâ€‘Fi** â†’ **â“˜** â†’ **Configure DNS** â€” matches Step 0 baseline
- [ ] VPN icon in status bar behaves as before (if you used VPN before)
- [ ] Browse a familiar site â€” no unexpected captive portal or â€œno internetâ€

**If something broke:** Disconnect any **new** VPN profile from Phase 2; DuckDuckGo / original profile should return. Do not disable corporate VPN or Private Relay without IT intent.

More detail: [IPHONE_HARDENING.md Â§ Phase 2](IPHONE_HARDENING.md#phase-2-checklist-advanced-layers--do-after-phase-1).

---

## Quick decision card

```
DuckDuckGo or VPN/DNS already set?  â†’  Phase 1 YES  |  Phase 2 Malwarebytes YES  |  Cloudflare/NextDNS SKIP
No VPN/DNS at all?                  â†’  Phase 1 YES  |  Phase 2 Malwarebytes YES  |  Cloudflare OR NextDNS (one, optional)
USB to Windows laptop today?        â†’  Phase 2 Â§ 2.3 USB  |  encrypted backup  |  Phase 2 verify VPN unchanged
High-threat / targeted?             â†’  Phase 2 Â§ 2.4 Lockdown Mode (optional)
Pocket UTMS?                        â†’  M5 Cardputer only â€” not iPhone App Store
```

---

## One-page checkbox (print or Notes app)

**Step 0:** VPN + Wiâ€‘Fi DNS + DuckDuckGo Password Manager documented â€” keep DuckDuckGo VPN + PM  
**Phase 1:** 1.1â€“1.11 Settings âœ“ â†’ **1.V verify VPN/DNS**  
**Phase 2:** Malwarebytes âœ“ â†’ skip DNS VPN if set âœ“ â†’ USB âœ“ â†’ (optional Lockdown) â†’ **2.V verify VPN/DNS**

---

**Author:** [Hacker Planet LLC](ABOUT_HACKER_PLANET.md) Â· **Maintained with:** [IPHONE_HARDENING.md](IPHONE_HARDENING.md)
