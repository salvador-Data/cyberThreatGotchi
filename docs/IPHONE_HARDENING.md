# iPhone 15 Pro Max hardening — iOS 17 / 18

**Hacker Planet LLC / CyberThreatGotchi** — defensive guidance for devices you **own** or are **explicitly authorized** to administer. This is not offensive tooling; use it to protect your personal phone and align with the same security mindset as your Windows lab and CyberThreatGotchi edge stack.

**Companion doc (Windows):** [scripts/windows/README_WINDOWS_SOC.md](../scripts/windows/README_WINDOWS_SOC.md)  
**Project security baseline:** [SECURITY_HARDENING.md](SECURITY_HARDENING.md)

---

## iOS reality (read this first)

Apple **does not allow traditional filesystem antivirus on iOS**. Any App Store app labeled “antivirus” or “virus cleaner” **cannot scan other apps, the system partition, or files outside its own sandbox** the way Windows Defender or ClamAV can on a PC.

What actually protects iPhone users:

| Layer | What it does |
|-------|----------------|
| **App Store review** | Apps are signed and reviewed before distribution; sideloading is restricted without enterprise/MDM profiles |
| **Sandbox** | Each app is isolated; it cannot read arbitrary data from other apps |
| **Code signing** | Only Apple-approved code runs at the OS level |
| **XProtect / Gatekeeper (device)** | Apple pushes known-malware blocklists and signature updates silently |
| **Secure Enclave** | Face ID, passkeys, and encryption keys live in dedicated hardware |
| **System Integrity Protection** | Kernel and system files are protected from modification |

**Honest recommendation:** Harden **Settings** first. Add **reputable free apps** only where they provide real value (Safari extensions, SMS filtering, DNS filtering, phishing blocks)—not where they pretend to be full AV.

**What you cannot do from a Windows PC:** Install App Store apps on your iPhone remotely without Apple Business Manager / MDM enrollment. Andy must install apps **on the phone** (see [Manual install steps](#what-andy-must-do-manually-on-the-iphone) below).

**Action runbook:** [IPHONE_RUN_NOW.md](IPHONE_RUN_NOW.md) — consolidated **Phase 1 + Phase 2** checklist (manual steps only).  
**Printable audit:** [IPHONE_AUDIT_PRINT.md](IPHONE_AUDIT_PRINT.md) — one-page + extended Phase 1/2 checkboxes, Tier 1–3 DDG-safe improvements, VERIFY after each phase.  
**USB focus:** [IPHONE_USB_HARDENING.md](IPHONE_USB_HARDENING.md) — Trust This Computer, encrypted backup to SSD/OneDrive paths, Windows laptop reminders.  
**Laptop connection (honest scope):** [IPHONE_LAPTOP_CONNECTION.md](IPHONE_LAPTOP_CONNECTION.md) — what Windows **can and cannot** change (no MAC/hardware ID spoofing); Private Wi‑Fi Address, Limit IP Tracking, USB Restricted Mode, hotspot vs USB tethering; read-only `scripts/iphone/iphone_tethering_privacy_checklist.ps1`.  
**Tether egress IDS:** [IPHONE_TETHER_MONITORING.md](IPHONE_TETHER_MONITORING.md) — monitor NAT'd IP traffic on hotspot/USB adapter (`Start-CtgIphoneTetherIds.ps1`); cannot emulate cellular/BLE from laptop.

---

## Phase 1 and Phase 2 — run order

Complete **Phase 1** first (Settings only — safe with any VPN/DNS). Then **Phase 2** (apps, USB, optional Lockdown). **Do not replace** Andy’s existing **DuckDuckGo VPN/DNS** or **DuckDuckGo Password Manager** (or any working VPN/DNS profile).

| Phase | What it covers | Changes VPN/DNS? |
|-------|----------------|------------------|
| **Phase 1 — Baseline hardening** | Document VPN/DNS baseline → iOS updates → passcode/Face ID/Stolen Device Protection → Find My → Apple ID 2FA → Safari/Mail/privacy → lock screen → USB Restricted Mode → AirDrop → audit profiles | **No** — Settings only |
| **Phase 2 — Advanced layers** | Malwarebytes free (SMS + Safari) → skip DNS VPN apps if baseline already set → USB + Trust This Computer → optional Lockdown Mode → verify VPN/DNS unchanged → optional Windows encrypted backup | **No** if you skip new DNS VPN apps and Malwarebytes paid VPN |

**On-device today:** [IPHONE_RUN_NOW.md](IPHONE_RUN_NOW.md) · **UTMS / free AV honesty:** [§ Free security apps & UTMS-like layers](#free-security-apps--utms-like-layers-keep-vpndns).

### Phase 1 checklist (baseline — do all)

Run in order. Check each box on the phone.

```
[ ] 1.0  Document VPN + Wi‑Fi DNS + DuckDuckGo Password Manager (Step 0) — screenshot or write down; KEEP DuckDuckGo VPN/DNS + Password Manager / existing profile
[ ] 1.1  Settings → General → Software Update — latest iOS; Automatic Updates ON
[ ] 1.2  Settings → Face ID & Passcode — strong passcode; Stolen Device Protection ON (iOS 17.3+)
[ ] 1.3  Settings → [your name] → Find My → Find My iPhone ON (+ network / last location if shown)
[ ] 1.4  Settings → [your name] → Sign-In & Security — 2FA ON; remove unknown devices
[ ] 1.5  Settings → Apps → Safari — fraud warning, cross-site tracking, hide IP as preferred
[ ] 1.6  Settings → Apps → Mail → Protect Mail Activity ON
[ ] 1.7  Settings → Privacy & Security — audit Bluetooth + Local Network; Tracking denied
[ ] 1.8  Settings → Face ID & Passcode → Allow Access When Locked — restrict lock-screen leaks
[ ] 1.9  Settings → Face ID & Passcode → USB Accessories OFF when locked
[ ] 1.10 Settings → General → AirDrop → Contacts Only (or Receiving Off in public)
[ ] 1.11 Settings → General → VPN & Device Management — remove unknown profiles only
[ ] 1.12 (Recommended) Location, Analytics, Messages filter unknown senders — see [§ 14](#14-additional-hardening-recommended)
[ ] 1.V  VERIFY: Settings → VPN — unchanged; Wi‑Fi ⓘ → Configure DNS — unchanged; AutoFill & Passwords → DuckDuckGo Autofill — On
```

### Phase 2 checklist (advanced layers — do after Phase 1)

```
[ ] 2.1  App Store → Malwarebytes Mobile Security — install; onboarding complete
[ ] 2.2  Settings → Apps → Messages → Unknown & Spam → Malwarebytes ON
[ ] 2.3  Settings → Apps → Safari → Extensions → Malwarebytes blockers ON (if offered)
[ ] 2.4  Do NOT enable Malwarebytes paid VPN — keep DuckDuckGo / existing VPN/DNS
[ ] 2.5  DNS VPN apps (Cloudflare / NextDNS) — SKIP if Step 0 already had VPN or Manual DNS
[ ] 2.6  USB: Trust only Andy’s laptop; USB Restricted Mode confirmed; trusted cable / data blocker in public
[ ] 2.7  Settings → Privacy & Security → Developer Mode OFF (unless dev week)
[ ] 2.8  (Optional) Lockdown Mode — only if credible targeted threat; see [§ 8](#8-lockdown-mode-optional--high-threat-profile)
[ ] 2.9  (When USB to Windows) Apple Devices → encrypted local backup — password in password manager
[ ] 2.V  VERIFY: VPN profile + Wi‑Fi DNS match Phase 1 baseline — browse a familiar site
```

**No fake automation:** Apple does not allow CTG or Windows scripts to change iPhone Settings remotely without MDM. Every step above is **manual on the device** (Windows backup step is optional when cabled).

---

## Preserve your existing VPN, DNS, and password manager (read before installing apps)

**Do not replace** a VPN profile, DNS setup, or password manager that is already working. Hardening in **Settings** (Face ID, Find My, Safari, updates, Stolen Device Protection) does **not** change VPN, DNS, or AutoFill — run those steps regardless.

### Keep DuckDuckGo Password Manager (Andy’s preference)

Andy uses **DuckDuckGo** for **VPN + Password Manager (Autofill)**. Hardening must **preserve** both — **do not migrate away** to Apple Keychain or another password manager unless Andy explicitly chooses to.

1. Keep the **DuckDuckGo** app installed (VPN + Password Manager).
2. **Settings** → **General** → **AutoFill & Passwords** → ensure **DuckDuckGo Passwords** / **DuckDuckGo Autofill** is **On**.
3. **Do not** disable DuckDuckGo autofill during hardening — Malwarebytes SMS/Safari filtering and Safari fraud/tracking settings are **compatible** with DuckDuckGo Password Manager.
4. **iCloud Keychain** can coexist (e.g. for Apple ID, Wi‑Fi passwords) — leave **On** if already synced, but **keep DuckDuckGo as primary autofill** for sites and apps Andy uses today. Do **not** treat hardening as a reason to switch PMs.

### Check what you have first

Before installing **Cloudflare 1.1.1.1**, **NextDNS**, **AdGuard DNS**, or any app that installs a VPN configuration profile:

1. **Settings** → **General** → **VPN & Device Management** → **VPN** — note any active profile (corporate VPN, iCloud Private Relay, 1.1.1.1, NextDNS, Tailscale, etc.).
2. **Settings** → **Wi‑Fi** → tap **ⓘ** on your home network → **Configure DNS** — note **Automatic**, **Manual** (e.g. 1.1.1.1, 9.9.9.9, NextDNS DoH), or **Off**.

Screenshot or write down both screens if you might need to restore them.

### If you already have VPN or DNS configured

| Existing setup | What to do |
|----------------|------------|
| **DuckDuckGo VPN / Privacy Pro + Password Manager** (Andy’s typical stack) | **Keep both.** **Do not** install Cloudflare, NextDNS, or AdGuard DNS VPN apps. **Do not** disable DuckDuckGo Autofill or migrate to Apple Keychain during hardening. Phase 1 Settings + Phase 2 Malwarebytes (SMS/Safari only) — **no** Malwarebytes paid VPN. |
| **Corporate / school VPN** | Keep it. **Do not** install Cloudflare or NextDNS unless IT approves — only one system VPN slot is practical at a time. |
| **iCloud Private Relay** | Keep it. Skip DNS VPN apps; they conflict or duplicate filtering. Use Malwarebytes for SMS/Safari only. |
| **NextDNS profile or app already connected** | Keep it. **Skip** Cloudflare 1.1.1.1. Harden via Settings + Malwarebytes Safari filter. |
| **Cloudflare 1.1.1.1 already connected** | Keep it. **Skip** NextDNS/AdGuard DNS apps. |
| **Wi‑Fi Manual DNS only** (no VPN app) | Keep Manual DNS on Wi‑Fi. Optional: add Malwarebytes; skip second DNS VPN app unless you intentionally replace Wi‑Fi DNS. |

**Malwarebytes Mobile Security** is safe alongside any VPN/DNS — its free tier uses **SMS filtering** and **Safari content blocking**, not a system DNS VPN profile (paid Malwarebytes VPN is separate; leave it off if you keep your current VPN/DNS).

### iOS limitation: one DNS VPN at a time

iOS allows only **one** active VPN configuration that captures DNS traffic. You **cannot** stack:

- Cloudflare 1.1.1.1 **+** NextDNS **+** MDM-enforced DNS **+** another DNS VPN app

Connecting a second DNS VPN app typically **disconnects or overrides** the first. Pick **one** DNS VPN strategy (existing corporate VPN, Private Relay, Cloudflare, NextDNS, or Wi‑Fi Manual DNS) and harden everything else in Settings.

### Optional: Wi‑Fi Manual DNS without touching cellular VPN

If you want extra DNS filtering **only on home Wi‑Fi** and you are **not** using a DNS VPN app:

1. **Settings** → **Wi‑Fi** → **ⓘ** on your network → **Configure DNS** → **Manual**
2. Add servers (e.g. `1.1.1.1`, `1.0.0.1` or your NextDNS linked IP) → **Save**

This affects **that Wi‑Fi network only** — cellular and any separate VPN profile stay as configured. Do **not** add Manual DNS on Wi‑Fi if you already run Cloudflare/NextDNS via VPN profile unless you are **replacing** that approach.

### Verify settings stayed intact after hardening

After completing Settings hardening and any app installs:

1. **Settings** → **General** → **VPN & Device Management** → **VPN** — same profile(s) as before; corporate/Private Relay still **Connected** if they were before.
2. **Settings** → **Wi‑Fi** → **ⓘ** → **Configure DNS** — unchanged (**Automatic**, **Manual**, or **Off** as you documented).
3. **Settings** → **General** → **AutoFill & Passwords** — **DuckDuckGo Autofill** still **On** if it was on at baseline.
4. Open a site you use daily; if on VPN, confirm VPN icon still shows in status bar when expected.
5. If something broke, disconnect the **new** app’s VPN profile first — your original profile should return.

---

## Top 5 settings to do first

If you only have ten minutes, do these in order:

1. **Update iOS** — Settings → General → Software Update (stay on current iOS 17 or 18).
2. **Strong passcode + Face ID + Stolen Device Protection** — six-digit minimum; alphanumeric is better; enable Stolen Device Protection (iOS 17.3+).
3. **Find My iPhone + Activation Lock** — Settings → [your name] → Find My → Find My iPhone **On**.
4. **Apple ID two-factor authentication** — Settings → [your name] → Sign-In & Security → Two-Factor Authentication **On**; review signed-in devices.
5. **Safari fraud & tracking** — Settings → Apps → Safari → Fraudulent Website Warning **On**; Advanced → Privacy Preserving Ad Measurement as you prefer; enable cross-site tracking prevention; consider **Hide IP Address** (Trackers and Websites or Trackers Only).

Then continue the full checklist below.

---

## Settings checklist (iPhone 15 Pro Max, iOS 17 / 18)

Tap path uses **→** for each screen transition. Names may vary slightly by iOS minor version.

### 1. Keep iOS current

1. **Settings** → **General** → **Software Update**
2. Install the latest **iOS 17** or **iOS 18** update.
3. Enable **Automatic Updates** → **Security Responses & System Files** and **iOS Updates** → **On** (see also [§ Automatic updates](#14-automatic-updates)).

Why: Most real-world iPhone compromises are **patched OS bugs** or **social engineering**, not “viruses” a store app would find.

### 2. Strong passcode, Face ID, Stolen Device Protection

1. **Settings** → **Face ID & Passcode** (enter passcode).
2. **Turn Passcode On** if off; prefer **Custom Alphanumeric Code** over four digits.
3. Confirm **Face ID** is set up for iPhone Unlock and Apple Pay as you use them.
4. Scroll to **Stolen Device Protection** → **On** (requires iOS **17.3+**).

**Stolen Device Protection** adds extra checks when the phone is away from familiar locations (e.g. Face ID + time delay before changing Apple ID password or passcode). Tradeoff: slightly more friction if someone steals the unlocked phone or coerces passcode entry—acceptable for most users.

### 3. Find My iPhone and Activation Lock

1. **Settings** → **[your name]** → **Find My** → **Find My iPhone** → **On**
2. Also enable **Find My network** and **Send Last Location** if shown.

Activation Lock ties the device to your Apple ID after erase. This is one of the strongest anti-theft controls on iOS.

### 4. Apple ID two-factor authentication

1. **Settings** → **[your name]** → **Sign-In & Security**
2. **Two-Factor Authentication** → **On** (use trusted phone number + recovery options).
3. **Sign-In & Security** → review **Devices**; remove anything you do not recognize.
4. Use a **unique, strong Apple ID password** (keep **DuckDuckGo Password Manager** for autofill — see [§ Passwords](#11-passwords--keep-duckduckgo-password-manager-icloud-keychain-optional)).

### 5. Safari: fraud, tracking, and IP privacy

1. **Settings** → **Apps** → **Safari** (on some iOS versions: **Settings** → **Safari**)
2. **Fraudulent Website Warning** → **On**
3. **Prevent Cross-Site Tracking** → **On**
4. **Hide IP Address** → **From Trackers and Websites** (strongest) or **From Trackers Only**
5. Optional: **Block Pop-ups** → **On**; **Privacy Preserving Ad Measurement** → off if you want minimum ad telemetry

Safari is the main browser attack surface on iOS for phishing and malicious sites.

### 6. Mail Privacy Protection

1. **Settings** → **Apps** → **Mail** (or **Settings** → **Mail**)
2. **Privacy Protection** → **Protect Mail Activity** → **On**

This reduces senders’ ability to track opens and infer IP/location via remote content.

### 7. Bluetooth, Wi‑Fi, and Local Network permissions

Audit which apps can probe your LAN or persist connections:

1. **Settings** → **Privacy & Security** → **Bluetooth** — revoke apps that do not need Bluetooth.
2. **Settings** → **Privacy & Security** → **Local Network** — revoke apps that should not scan your home network (common leak for smart-home and “free” utilities).
3. **Settings** → **Wi‑Fi** → tap **ⓘ** on saved networks — use **Private Wi‑Fi Address** (on by default on modern iOS).

CyberThreatGotchi on your **edge network** benefits when phones do not unnecessarily expose LAN discovery to random apps.

### 8. Lockdown Mode (optional — high-threat profile)

1. **Settings** → **Privacy & Security** → **Lockdown Mode** → **Turn On Lockdown Mode**

**What it does:** Disables or restricts many attack surfaces (some message attachments, complex web features, wired accessories when locked, incoming FaceTime from unknown callers, configuration profiles, etc.).

**Tradeoffs:**

| Benefit | Cost |
|---------|------|
| Strongest Apple-supported profile for journalists, activists, targeted threats | Some websites break or lose features |
| Reduces risk from sophisticated link/attachment exploits | Shared albums, certain configs, and some apps behave differently |
| Limits optional connectivity attack paths | Not needed for typical daily use |

Use Lockdown Mode if you face **credible targeted threat**; skip it for normal personal use if the friction outweighs benefit.

### 9. Automatic updates

1. **Settings** → **General** → **Software Update** → **Automatic Updates** → **On**
2. Enable **iOS Updates** and **Security Responses & System File** if listed separately.

### 10. Lock screen: widgets and notifications

Prevent shoulder-surfing and lock-screen data leaks:

1. **Settings** → **Face ID & Passcode** → **Allow Access When Locked**
2. Turn **off** anything you do not need on the lock screen (e.g. **Notification Center**, **Today View**, **Reply with Message**, **Return Missed Calls** if paranoid).
3. **Settings** → **Notifications** → per app: set **Show Previews** to **When Unlocked** (or **Never** for banking, Signal, mail).
4. **Settings** → **Wallpaper** → customize Lock Screen widgets — avoid widgets that show calendar, health, or finance details at a glance.

### 11. Passwords — keep DuckDuckGo Password Manager; iCloud Keychain optional

**Andy’s preference:** **Keep DuckDuckGo Password Manager** as primary autofill — **do not migrate away** during hardening.

1. **Settings** → **General** → **AutoFill & Passwords** → **DuckDuckGo Passwords** / **DuckDuckGo Autofill** → **On**
2. Confirm **DuckDuckGo** app is installed and Password Manager is set up in-app.
3. **Optional coexistence:** **Settings** → **[your name]** → **iCloud** → **Passwords** → **Sync this iPhone** can stay **On** for Apple-ecosystem passwords — it does **not** require replacing DuckDuckGo PM.
4. **Settings** → **Apps** → **Passwords** (or **Passwords** app on iOS 18+) — review **Security Recommendations** in whichever manager holds each login; change reused or breached passwords.

Unique passwords contain breach blast radius more than any “virus scanner” app could. Malwarebytes Safari hardening does **not** conflict with DuckDuckGo autofill.

### 12. Avoid unknown configuration profiles

1. **Settings** → **General** → **VPN & Device Management** (or **Profiles & Device Management**)
2. Remove **any profile** you did not install intentionally from work or school.

Profiles can enforce custom DNS, certificates, and MDM control—**never** install from random links, “speed booster,” or “crypto reward” sites.

### 13. USB Restricted Mode

1. **Settings** → **Face ID & Passcode**
2. **USB Accessories** (or **Allow Accessories When Locked**) → **Off** / disallow when locked (wording varies)

When enabled, USB data accessories (including some forensic tools) cannot connect until the device is unlocked. Charging still works.

Full USB + Windows backup checklist: [§ USB connection hardening](#usb-connection-hardening) and [IPHONE_USB_HARDENING.md](IPHONE_USB_HARDENING.md).

### 14. Additional hardening (recommended)

| Setting | Path | Recommendation |
|---------|------|----------------|
| **Location Services** | Settings → Privacy & Security → Location Services | **Off** globally or per-app; review **System Services** |
| **Analytics & Improvements** | Settings → Privacy & Security → Analytics & Improvements | Disable sharing if you want minimum telemetry |
| **App Tracking Transparency** | Settings → Privacy & Security → Tracking | Deny cross-app tracking prompts |
| **AirDrop** | Settings → General → AirDrop | **Contacts Only** or **Receiving Off** in public |
| **Control Center** | Settings → Control Center | Remove tools you do not use |
| **Siri & Search** | Settings → Siri & Search | Limit lock screen Siri; review app shortcuts |
| **Messages** | Settings → Apps → Messages | **Filter Unknown Senders**; **Report Junk** on spam |
| **Face ID apps** | Settings → Face ID & Passcode → Other Apps | Only enable for apps that need it |

---

## USB connection hardening

Use this when the iPhone 15 Pro Max is on **USB-C** to Andy’s Windows SOC laptop or when you charge in public. **These steps do not change VPN or DNS** — complete them in addition to [Preserve your existing VPN and DNS](#preserve-your-existing-vpn-and-dns-read-before-installing-apps).

**Focused runbook:** [IPHONE_USB_HARDENING.md](IPHONE_USB_HARDENING.md) · Phase 2 on device: [IPHONE_RUN_NOW.md § 2.3](IPHONE_RUN_NOW.md#23--usb-connection-hardening).

### Keep VPN/DNS and DuckDuckGo Password Manager while hardening USB (repeat)

- **Do not** install a second DNS VPN if **DuckDuckGo**, **NextDNS**, **Cloudflare 1.1.1.1**, or **Wi‑Fi Manual DNS** is already configured.
- **Keep DuckDuckGo Password Manager** — **Settings** → **General** → **AutoFill & Passwords** → DuckDuckGo Autofill **On**; do not disable during USB hardening.
- **Malwarebytes** for SMS/Safari only — **no** Malwarebytes paid VPN alongside your existing profile.
- After USB hardening: **Settings** → **General** → **VPN & Device Management** → **VPN** — verify the same profile(s) as before (**Connected** if they were before).

### iPhone settings (USB-C, iOS 17 / 18)

| Control | Path | Action |
|---------|------|--------|
| **USB Restricted Mode** | **Settings** → **Face ID & Passcode** → **USB Accessories** | **Off** when locked (after ~1h locked, data USB blocked; charging OK) |
| **Trust This Computer** | Prompt on first USB connect | **Trust** only Andy’s laptop; if unknown PCs were trusted → **Settings** → **General** → **Transfer or Reset iPhone** → **Reset** → **Reset Location & Privacy** |
| **Stolen Device Protection** | **Settings** → **Face ID & Passcode** | **On** (iOS 17.3+) — see [§ 2](#2-strong-passcode-face-id-stolen-device-protection) |
| **Find My / Activation Lock** | **Settings** → **[your name]** → **Find My** | **Find My iPhone** **On** |
| **Developer Mode** | **Settings** → **Privacy & Security** → **Developer Mode** | **Off** unless actively developing |
| **Configuration profiles** | **Settings** → **General** → **VPN & Device Management** | Remove profiles not from known work/school MDM |
| **Lockdown Mode** (optional) | **Settings** → **Privacy & Security** → **Lockdown Mode** | Stronger USB accessory limits; see [§ 8](#8-lockdown-mode-optional--high-threat-profile) |
| **USB-C hygiene** | Physical | Trusted cable; **data blocker** on untrusted public charge ports |

### When plugged into Windows (Andy’s laptop)

1. **Apple Devices** (or iTunes) — run **encrypted local backup**; store encryption password in your password manager (never in git).
2. Prefer backup trees already covered by CTG nightly: `D:\Backups\Andy-PC-YYYY-MM-DD\`, fallback `C:\Users\Owner\Backups\Andy-PC-YYYY-MM-DD\`, OneDrive `Backups\Andy-PC-YYYY-MM-DD\` via [cloud_backup.ps1](../scripts/windows/cloud_backup.ps1). Default Apple MobileSync backups live under `%AppData%\Apple Computer\MobileSync\Backup\`.
3. **Disable auto-sync** in Apple Devices unless you want photos/music sync on every connect.
4. Run log-only reminder (no device modification): `.\scripts\windows\iphone_usb_check.ps1` — see [README_WINDOWS_SOC.md § iPhone USB](../scripts/windows/README_WINDOWS_SOC.md#iphone-usb-windows-soc-laptop).

**Do not** push MDM or configuration profiles from the PC without **Apple Business Manager** and explicit MSP scope.

---

## Free security apps & UTMS-like layers (keep VPN/DNS + DuckDuckGo Password Manager)

Andy asked whether **free UTMS or antivirus** can run on the **iPhone 15 Pro Max**. Short answer: **no true UTMS and no filesystem antivirus on iOS** — but several **free layers** stack safely if you **preserve existing VPN/DNS and DuckDuckGo Password Manager** (DuckDuckGo VPN, NextDNS, Cloudflare, Wi‑Fi Manual DNS, corporate VPN).

**Do not** treat hardening as a reason to replace **DuckDuckGo Password Manager** with Apple Keychain or another PM — keep DuckDuckGo autofill unless Andy explicitly chooses to migrate.

### Why there is no “iPhone UTMS” or desktop-style AV

| Expectation | iOS reality |
|-------------|-------------|
| **UTMS** (micro-AV, threat packs, quarantine on firmware files) | Lives on **M5 Cardputer** — see [pocket UTMS tie-in](#pocket-utms-m5-cardputer--separate-device) below |
| **Filesystem antivirus** | **Not possible** for third-party apps: sandbox, code signing, no API to scan other apps or system partitions |
| **App Store “virus cleaner”** | Marketing only — **avoid** (see [§ Apps to avoid](#apps-to-avoid)) |

CyberThreatGotchi **UTMS** on Cardputer scans `/apps/*.bin` and threat packs on SD. Your iPhone uses a **different, honest stack** — Settings plus optional apps that do not steal the **one** DNS VPN slot.

### Free layers that actually count (keep VPN/DNS)

| Layer | What it is | VPN/DNS safe? |
|-------|------------|---------------|
| **1. Malwarebytes Mobile Security (free)** | **SMS** scam/junk filter, **Safari** ad/tracker content blocking, security tips — **not** full-device AV | **Yes** — free tier has **no** system DNS VPN; leave **Malwarebytes paid VPN off** if you keep DuckDuckGo/NextDNS/1.1.1.1 |
| **2. Apple built-in** | **XProtect** (silent malware blocklist updates), **App Store** review + signing, optional **Lockdown Mode**, **Stolen Device Protection**, **Find My** | **Yes** — configure in [Settings checklist](#settings-checklist-iphone-15-pro-max-ios-17--18) |
| **3. DNS blocklists (“UTMS-like” on network only)** | Cloudflare 1.1.1.1, NextDNS, or AdGuard DNS apps = closest iOS analog to **DNS threat filtering** | **Only if you have NO existing DNS VPN / Manual DNS** — if VPN/DNS is already set, **do not** add Cloudflare or NextDNS; that is your UTMS-like layer already |
| **4. iCloud Private Relay** (iCloud+) | Encrypts DNS + IP for Safari/Mail in relay mode — **privacy**, not malware scanning | **Yes** if already on — **skip** extra DNS VPN apps; use Malwarebytes SMS/Safari only |
| **5. No scam “virus cleaner” apps** | “Phone booster,” “memory cleaner,” fake “viruses found” | N/A — **do not install** |

**After any install:** **Settings** → **General** → **VPN & Device Management** → **VPN** — profile unchanged. **Settings** → **Wi‑Fi** → **ⓘ** → **Configure DNS** — same as baseline ([verify](#verify-settings-stayed-intact-after-hardening)).

### Pocket UTMS (M5 Cardputer) — separate device

| Device | Role |
|--------|------|
| **M5Stack Cardputer** | [M5_OS-Cardputer UTMS](https://github.com/salvador-Data/M5_OS-Cardputer) — micro-AV on `/apps/*.bin`, OTA threat packs, quarantine, UTMS logs |
| **iPhone 15 Pro Max** | Layers **1–5** above — no Cardputer app replaces iOS sandbox security |

Same **defense-in-depth mindset**, different platform limits. Portfolio: [PORTFOLIO_SYSTEM_HARDENING.md](PORTFOLIO_SYSTEM_HARDENING.md) · [PORTFOLIO_FIRMWARE_OS.md](PORTFOLIO_FIRMWARE_OS.md).

### Install Malwarebytes only (when VPN/DNS already set)

If Step 0 baseline shows **any** active VPN or DNS you want to keep → install **Malwarebytes only**; **skip** Cloudflare/NextDNS in [Free App Store apps](#free-app-store-apps-realistic-expectations) below.

1. **App Store** → **Search** → **Malwarebytes Mobile Security** → **Get**
2. Open app → complete onboarding
3. **Settings** → **Apps** → **Messages** → **Unknown & Spam** → enable **Malwarebytes**
4. **Settings** → **Apps** → **Safari** → **Extensions** → enable Malwarebytes blockers if offered
5. **Do not** enable Malwarebytes **paid VPN** in the app
6. Re-check **Settings** → **VPN** and **Wi‑Fi → Configure DNS** — unchanged

Full optional DNS app steps (only when **no** existing DNS VPN): [Install Malwarebytes](#install-malwarebytes-recommended--keeps-your-vpndns) and Cloudflare/NextDNS sections under [What Andy must do manually](#what-andy-must-do-manually-on-the-iphone).

### Andy’s stack when VPN/DNS is already configured

```
Settings hardening (always)  +  Malwarebytes free (SMS + Safari)  +  existing VPN/DNS (keep)  +  DuckDuckGo Password Manager (keep)
NO second DNS VPN app  |  NO "virus cleaner"  |  NO PM migration to Keychain unless chosen  |  Cardputer UTMS on pocket device only
```

---

## Free App Store apps (realistic expectations)

See also [Free security apps & UTMS-like layers (keep VPN/DNS)](#free-security-apps--utms-like-layers-keep-vpndns) for the UTMS vs iOS honesty summary.

These apps **supplement** Settings—they do **not** replace Apple’s platform security or a hardened network edge (see [Windows SOC stack](../scripts/windows/README_WINDOWS_SOC.md) and CyberThreatGotchi IPS on your LAN).

### Recommended (reputable, free tier useful)

| App | When to install | What it actually does on iOS | What it does **not** do |
|-----|-----------------|------------------------------|-------------------------|
| **[Malwarebytes Mobile Security](https://apps.apple.com/us/app/malwarebytes-mobile-security/id1327105431)** | **Always** — safe with existing VPN/DNS | Phishing-adjacent **SMS** filtering, Safari content blocking, security guidance | **No malware scan** of device or other apps; free tier does **not** install a DNS VPN profile |
| **[Cloudflare 1.1.1.1](https://apps.apple.com/us/app/1-1-1-1-faster-internet/id1423538627)** | **Optional** — only if no DNS VPN / Manual DNS already | System-wide encrypted DNS (via VPN profile), optional WARP; **1.1.1.1 for Families** blocks malware/phishing DNS | Not filesystem AV; **conflicts** with existing NextDNS, corporate VPN, Private Relay, or second DNS VPN |
| **[NextDNS](https://apps.apple.com/us/app/nextdns/id1464120913)** | **Optional** — only if no DNS VPN / Manual DNS already | Custom blocklists, logging, analytics/ads/malware DNS blocking via VPN profile | After free quota, blocking stops; **conflicts** with Cloudflare or another active DNS VPN |
| **[AdGuard DNS](https://apps.apple.com/us/app/adguard-dns/id1499221030)** | **Optional** — same rules as Cloudflare/NextDNS | DNS-level ad/malware blocking via VPN profile | Same single VPN-slot constraint; do not stack |

### Microsoft Defender (usually not free for personal use)

**[Microsoft Defender: Security](https://apps.apple.com/us/app/microsoft-defender-security/id1526737990)** is free to **download** but requires an active **Microsoft 365 Personal or Family** subscription for full use. On iOS it provides **anti-phishing** and **identity monitoring**—**not** traditional AV scanning. Skip unless you already pay for M365; do not buy a subscription just for iPhone “AV.”

### Andy’s practical pick (depends on existing VPN/DNS)

**Always (does not replace VPN/DNS):**

1. **Malwarebytes Mobile Security** — SMS junk/phishing filtering + Safari content blocking. Safe even when corporate VPN, iCloud Private Relay, Cloudflare, or NextDNS is already active.

**Only if you have no DNS VPN / no Manual DNS you want to keep:**

2. **Cloudflare 1.1.1.1** *or* **NextDNS** (pick **one**) — optional DNS-level malware/phishing block. **Skip both** if you already use any of: corporate VPN with DNS, iCloud Private Relay, an existing 1.1.1.1 or NextDNS profile, or Wi‑Fi **Configure DNS → Manual**.

**If keeping existing DNS:** harden via **Settings** (this doc) + **Malwarebytes Safari filter** only — no new DNS VPN app.

**Do not run two DNS VPN apps connected at once** — iOS allows one VPN configuration to capture DNS at a time. Do not stack Cloudflare + NextDNS + MDM DNS profiles.

### Apps to avoid

- **“Virus cleaner,” “phone booster,” “memory cleaner,” “battery doctor”** — mostly scams, ads, or useless on iOS; cannot scan viruses.
- **Unknown profiles pushed after installing “security” apps** — legitimate DNS apps need a VPN **configuration profile**; if an app asks you to install a **MDM or root certificate** from a shady website, stop.
- **Apps with thousands of fake reviews** promising to “remove viruses found on your iPhone” — iOS does not expose that API to third parties.

---

## What Andy must do manually (on the iPhone)

You **cannot** install these from your Windows PC through the App Store without MDM. On the **iPhone 15 Pro Max**:

**Before any app install:** complete [Preserve your existing VPN and DNS](#preserve-your-existing-vpn-and-dns-read-before-installing-apps) checks. If VPN/DNS is already set, install **Malwarebytes only** and skip Cloudflare/NextDNS sections below.

### Install Malwarebytes (recommended — keeps your VPN/DNS)

1. Open **App Store**
2. Tap **Search** (bottom)
3. Type **Malwarebytes Mobile Security** → tap **Get** / cloud icon
4. Authenticate with **Face ID** or Apple ID password
5. Open **Malwarebytes** → complete onboarding
6. **Settings** → **Apps** → **Messages** → **Unknown & Spam** → enable **Malwarebytes** for filtering (if prompted)
7. **Settings** → **Safari** → **Extensions** → enable **Malwarebytes** content blockers if offered

### Install Cloudflare 1.1.1.1 (optional — only if no DNS VPN already)

**Skip this section** if **Settings → VPN** or **Wi‑Fi → Configure DNS** already shows an active DNS/VPN setup you want to keep.

1. **App Store** → **Search** → **1.1.1.1 Faster Internet**
2. Install → open app → accept terms
3. Tap to install **VPN profile** when prompted → allow in **Settings**
4. Toggle connection **On**; in app settings enable **1.1.1.1 for Families** for malware/phishing DNS if desired
5. Optional: disable WARP if you only want DNS (Settings inside app)
6. Re-check **Settings → VPN** — confirm this replaced only what you intended; verify **Wi‑Fi → Configure DNS** if you use Manual DNS elsewhere

### Install NextDNS (optional — only if no DNS VPN already)

**Skip this section** if Cloudflare, corporate VPN, Private Relay, or existing NextDNS is already active.

1. **App Store** → **Search** → **NextDNS**
2. Create free account at [nextdns.io](https://nextdns.io) → link device in app
3. Install VPN profile → connect
4. In NextDNS dashboard, enable **Blocklists** (e.g. Native Tracking Protection, Threat Intelligence Feeds)

Repeat the same **App Store → Search → Get → Open → grant permissions** pattern for any other app above — but **never** add a second DNS VPN on top of an existing one.

---

## Optional enterprise (fleet) — overkill for personal

For **company-owned phones**, IT uses **Apple Business Manager** + **Microsoft Intune**, **Jamf**, or similar MDM to enforce passcode, OS version, app allow-lists, and remote wipe. That stack is appropriate for **Hacker Planet LLC employees or customer MSP engagements**—not required for Andy’s personal iPhone 15 Pro Max.

If you later unify Windows + mobile under one program, Intune can deploy Defender policies on Windows while mobile gets compliance policies—but personal devices stay **user-driven** unless enrolled.

---

## Supervised device / Apple Configurator checklist (optional)

For **fleet or lab test devices** (not required for personal daily driver):

| Step | Action |
|------|--------|
| 1 | Encrypted backup in Finder/iTunes before supervision |
| 2 | Mac: **Apple Configurator 2** → Prepare → Manual → **Supervise** |
| 3 | Settings → General → VPN & Device Management — verify only trusted profiles |
| 4 | Restrict USB when locked (Face ID → USB Accessories) |
| 5 | Preserve **DuckDuckGo VPN/DNS** — do not add second DNS VPN |
| 6 | Passwords: DDG Password Manager for web; CTG lab creds in Windows vault separately |

**Read-only export (Windows SOC):**

```powershell
cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
```

```powershell
.\scripts\iphone\Export-CtgIosProfileChecklist.ps1
```

Log saved under `%USERPROFILE%\Backups\logs\ios-profile-checklist-*.txt` (gitignored).

See [LAB_MATURITY.md](LAB_MATURITY.md) for maturity scoring (mobile Protect domain).

---

## Tie-in: Hacker Planet defensive program

| Surface | Control |
|---------|---------|
| **Home LAN / lab PC** | [Windows SOC](../scripts/windows/README_WINDOWS_SOC.md) — Sysmon, Wazuh, Defender ASR, hardening scripts |
| **Edge network** | CyberThreatGotchi IPS, logging, webhook export to your SOC workflow |
| **iPhone** | This doc — OS settings, DNS/Safari/SMS layers; **no fake AV** |
| **Identity** | 2FA, unique passwords, Stolen Device Protection, Find My |

Same principle everywhere: **reduce attack surface**, **log and detect on infrastructure you control**, and **do not trust App Store marketing that promises desktop-style virus scans on iOS**.

---

## Quick reference card (Phase 1 + Phase 2)

**Phase 1 — baseline (Settings only; preserves DuckDuckGo VPN/DNS + Password Manager):**

```
[ ] 1.0 Documented VPN (Settings → VPN) + Wi‑Fi DNS (Configure DNS) + DuckDuckGo Password Manager (AutoFill & Passwords) BEFORE any Phase 2 apps
[ ] 1.1 iOS updated + automatic security updates ON
[ ] 1.2 Strong passcode + Face ID + Stolen Device Protection ON
[ ] 1.3 Find My iPhone ON
[ ] 1.4 Apple ID 2FA ON + unknown devices removed
[ ] 1.5 Safari fraud warning + cross-site tracking + hide IP
[ ] 1.6 Mail Privacy Protection ON
[ ] 1.7 Bluetooth / Local Network permissions audited
[ ] 1.8 Lock screen previews restricted
[ ] 1.9 USB Restricted Mode (accessories when locked OFF)
[ ] 1.10 AirDrop Contacts Only (or Receiving Off in public)
[ ] 1.11 No unknown configuration profiles
[ ] 1.V Phase 1 verify: VPN + Wi‑Fi DNS unchanged from baseline
```

**Phase 2 — advanced layers (after Phase 1):**

```
[ ] 2.1 Malwarebytes installed + SMS/Safari features enabled (safe with DuckDuckGo / existing VPN/DNS)
[ ] 2.2 Malwarebytes paid VPN OFF — do not replace existing VPN/DNS
[ ] 2.3 DNS VPN app ONLY if none already: Cloudflare 1.1.1.1 OR NextDNS — else SKIP
[ ] 2.4 USB: Trust only Andy's laptop; encrypted backup when plugged into Windows
[ ] 2.5 USB-C trusted cable; data blocker for untrusted public ports
[ ] 2.6 Developer Mode OFF (unless dev week)
[ ] 2.7 Free layers: Malwarebytes (SMS/Safari) + existing DNS VPN = UTMS-like DNS (not two DNS apps)
[ ] 2.8 No scam "virus cleaner" / booster apps
[ ] 2.9 Cardputer UTMS on M5 — separate from iPhone stack
[ ] 2.V Phase 2 verify: VPN + Wi‑Fi DNS unchanged from Phase 1 baseline
[ ] (Optional) Lockdown Mode if high-threat
[ ] (Optional) Wi‑Fi Manual DNS only — if no DNS VPN and you want home-Wi‑Fi filtering
```

---

**Author:** [Hacker Planet LLC](ABOUT_HACKER_PLANET.md) · **Maintained with:** [SECURITY_HARDENING.md](SECURITY_HARDENING.md)
