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
4. Use a **unique, strong Apple ID password** (iCloud Keychain or a password manager—see [§ Passwords](#13-icloud-keychain--unique-passwords)).

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

### 11. iCloud Keychain and unique passwords

1. **Settings** → **[your name]** → **iCloud** → **Passwords** → **Sync this iPhone** → **On**
2. **Settings** → **Apps** → **Passwords** (or **Passwords** app on iOS 18+) — review **Security Recommendations**; change reused or breached passwords.
3. Enable **AutoFill** only for apps you trust.

Unique passwords contain breach blast radius more than any “virus scanner” app could.

### 12. Avoid unknown configuration profiles

1. **Settings** → **General** → **VPN & Device Management** (or **Profiles & Device Management**)
2. Remove **any profile** you did not install intentionally from work or school.

Profiles can enforce custom DNS, certificates, and MDM control—**never** install from random links, “speed booster,” or “crypto reward” sites.

### 13. USB Restricted Mode

1. **Settings** → **Face ID & Passcode**
2. **USB Accessories** (or **Allow Accessories When Locked**) → **Off** / disallow when locked (wording varies)

When enabled, USB data accessories (including some forensic tools) cannot connect until the device is unlocked. Charging still works.

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

## Free App Store apps (realistic expectations)

These apps **supplement** Settings—they do **not** replace Apple’s platform security or a hardened network edge (see [Windows SOC stack](../scripts/windows/README_WINDOWS_SOC.md) and CyberThreatGotchi IPS on your LAN).

### Recommended (reputable, free tier useful)

| App | Free tier | What it actually does on iOS | What it does **not** do |
|-----|-----------|------------------------------|-------------------------|
| **[Malwarebytes Mobile Security](https://apps.apple.com/us/app/malwarebytes-mobile-security/id1327105431)** | Yes — ad/tracker blocking in Safari, SMS filtering to Junk, Trusted Advisor, digital footprint scanner (premium adds VPN, web protection, call blocking) | Phishing-adjacent **SMS** filtering, Safari content blocking, security guidance | **No malware scan** of device or other apps ([Malwarebytes confirms iOS limitation](https://www.malwarebytes.com/ios)) |
| **[Cloudflare 1.1.1.1](https://apps.apple.com/us/app/1-1-1-1-faster-internet/id1423538627)** | Yes — encrypted DNS; optional WARP; **1.1.1.1 for Families** blocks malware/phishing DNS in app settings | System-wide encrypted DNS (via VPN profile), optional WARP privacy | Not a filesystem AV; WARP+ is paid; only one system VPN profile active at a time |
| **[NextDNS](https://apps.apple.com/us/app/nextdns/id1464120913)** | Yes — **300,000 DNS queries/month**; full feature set on free tier; unlimited devices | Custom blocklists, logging (can disable), analytics/ads/malware DNS blocking | After quota, blocking stops (falls back to non-blocking DNS); heavy users may need Pro (~$2/mo) |
| **[AdGuard DNS](https://apps.apple.com/us/app/adguard-dns/id1499221030)** | Free tier with DNS filtering profiles | DNS-level ad/malware blocking via VPN profile | Similar VPN-slot constraint; not full AV |

### Microsoft Defender (usually not free for personal use)

**[Microsoft Defender: Security](https://apps.apple.com/us/app/microsoft-defender-security/id1526737990)** is free to **download** but requires an active **Microsoft 365 Personal or Family** subscription for full use. On iOS it provides **anti-phishing** and **identity monitoring**—**not** traditional AV scanning. Skip unless you already pay for M365; do not buy a subscription just for iPhone “AV.”

### Andy’s practical pick (1–2 apps)

1. **Malwarebytes Mobile Security** — best single free install for SMS junk/phishing filtering + Safari hardening without paying.
2. **Cloudflare 1.1.1.1** *or* **NextDNS** (pick **one** for always-on DNS) — DNS-level malware/phishing block; use Cloudflare if you want zero quota hassle; use NextDNS if you want customizable blocklists and logs.

**Do not run two DNS VPN apps connected at once** — iOS allows one VPN configuration to capture DNS at a time. Choose one primary DNS app or configure DNS over HTTPS in a single profile.

### Apps to avoid

- **“Virus cleaner,” “phone booster,” “memory cleaner,” “battery doctor”** — mostly scams, ads, or useless on iOS; cannot scan viruses.
- **Unknown profiles pushed after installing “security” apps** — legitimate DNS apps need a VPN **configuration profile**; if an app asks you to install a **MDM or root certificate** from a shady website, stop.
- **Apps with thousands of fake reviews** promising to “remove viruses found on your iPhone” — iOS does not expose that API to third parties.

---

## What Andy must do manually (on the iPhone)

You **cannot** install these from your Windows PC through the App Store without MDM. On the **iPhone 15 Pro Max**:

### Install Malwarebytes (example)

1. Open **App Store**
2. Tap **Search** (bottom)
3. Type **Malwarebytes Mobile Security** → tap **Get** / cloud icon
4. Authenticate with **Face ID** or Apple ID password
5. Open **Malwarebytes** → complete onboarding
6. **Settings** → **Apps** → **Messages** → **Unknown & Spam** → enable **Malwarebytes** for filtering (if prompted)
7. **Settings** → **Safari** → **Extensions** → enable **Malwarebytes** content blockers if offered

### Install Cloudflare 1.1.1.1 (example)

1. **App Store** → **Search** → **1.1.1.1 Faster Internet**
2. Install → open app → accept terms
3. Tap to install **VPN profile** when prompted → allow in **Settings**
4. Toggle connection **On**; in app settings enable **1.1.1.1 for Families** for malware/phishing DNS if desired
5. Optional: disable WARP if you only want DNS (Settings inside app)

### Install NextDNS (alternative DNS)

1. **App Store** → **Search** → **NextDNS**
2. Create free account at [nextdns.io](https://nextdns.io) → link device in app
3. Install VPN profile → connect
4. In NextDNS dashboard, enable **Blocklists** (e.g. Native Tracking Protection, Threat Intelligence Feeds)

Repeat the same **App Store → Search → Get → Open → grant permissions** pattern for any other app above.

---

## Optional enterprise (fleet) — overkill for personal

For **company-owned phones**, IT uses **Apple Business Manager** + **Microsoft Intune**, **Jamf**, or similar MDM to enforce passcode, OS version, app allow-lists, and remote wipe. That stack is appropriate for **Hacker Planet LLC employees or customer MSP engagements**—not required for Andy’s personal iPhone 15 Pro Max.

If you later unify Windows + mobile under one program, Intune can deploy Defender policies on Windows while mobile gets compliance policies—but personal devices stay **user-driven** unless enrolled.

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

## Quick reference card

```
[ ] iOS updated + automatic security updates ON
[ ] Strong passcode + Face ID + Stolen Device Protection ON
[ ] Find My iPhone ON
[ ] Apple ID 2FA ON + unknown devices removed
[ ] Safari fraud warning + cross-site tracking + hide IP
[ ] Mail Privacy Protection ON
[ ] Bluetooth / Local Network permissions audited
[ ] Lock screen previews restricted
[ ] USB Restricted Mode (accessories when locked OFF)
[ ] Malwarebytes installed + SMS/Safari features enabled
[ ] ONE DNS app: Cloudflare 1.1.1.1 OR NextDNS
[ ] No unknown configuration profiles
[ ] (Optional) Lockdown Mode if high-threat
```

---

**Author:** [Hacker Planet LLC](ABOUT_HACKER_PLANET.md) · **Maintained with:** [SECURITY_HARDENING.md](SECURITY_HARDENING.md)
