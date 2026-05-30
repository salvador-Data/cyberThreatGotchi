# iPhone hardening — iOS Shortcuts guided routine

**Hacker Planet LLC / CyberThreatGotchi** — defensive, authorized-use only. This complements [IPHONE_RUN_NOW.md](IPHONE_RUN_NOW.md) and the Windows assistant `scripts/windows/iphone_hardening_assist.ps1`.

**Honest limit:** Stock iOS does not allow Shortcuts (or Windows scripts) to flip Settings toggles, enroll Face ID, set passcodes, trust a PC, or install App Store apps without **you** tapping through each screen. This routine **opens each Settings pane in order** so you spend less time hunting menus.

**Preserve:** Do **not** replace Andy’s **DuckDuckGo VPN/DNS** or **DuckDuckGo Password Manager**. Skip Cloudflare/NextDNS if VPN/DNS is already set. Do **not** enable Malwarebytes paid VPN.

---

## Build the Shortcut (one time)

1. On iPhone, open **Shortcuts** → **+** → name it **CTG iPhone Hardening Phase 1+2**.
2. Add actions in order below. For each **Open URL** step, paste the URL exactly.
3. After each **Open URL**, add **Wait** → **5 seconds** (or **Show Notification** — “Complete step X, then continue”) so you can finish toggles before the next pane opens.
4. Optional: wrap the sequence in **Ask for Input** → “Continue to next step?” at Phase boundaries.

### Step 0 — Baseline (document only — no toggles)

| # | Action | URL or note |
|---|--------|-------------|
| 0a | Open URL | `prefs:root=General&path=ManagedConfigurationList` |
| 0b | Show Notification | Document VPN profile name — do not disconnect DuckDuckGo |
| 0c | Open URL | `prefs:root=WIFI` |
| 0d | Show Notification | Tap ⓘ on home Wi‑Fi → Configure DNS — write down; do not change |
| 0e | Open URL | `prefs:root=PASSWORDS` |
| 0f | Show Notification | Confirm DuckDuckGo Autofill stays **On** |

If a link opens only the parent Settings pane (common on iOS 18), follow the manual path in [IPHONE_RUN_NOW.md](IPHONE_RUN_NOW.md).

### Phase 1 — Settings

| # | Open URL | Manual follow-up |
|---|----------|------------------|
| 1.1 | `prefs:root=General&path=SOFTWARE_UPDATE_LINK` | Install updates; Automatic Updates On |
| 1.2 | `prefs:root=PASSCODE` | Strong passcode; Face ID; Stolen Device Protection **On** |
| 1.3 | `prefs:root=APPLE_ACCOUNT` | Find My → Find My iPhone **On** |
| 1.4 | `prefs:root=APPLE_ACCOUNT` | Sign-In & Security → 2FA **On**; review Devices |
| 1.5 | `App-prefs:com.apple.mobilesafari` | Fraud warning, tracking, Hide IP |
| 1.6 | `prefs:root=MAIL` | Protect Mail Activity **On** |
| 1.7 | `prefs:root=Privacy` | Bluetooth / Local Network / Tracking |
| 1.8 | `prefs:root=PASSCODE#ALLOW_ACCESS_WHEN_LOCKED` | Trim lock-screen access |
| 1.9 | `prefs:root=PASSCODE` | USB Accessories **Off** when locked |
| 1.10 | `prefs:root=General&path=AIRDROP_LINK` | Contacts Only |
| 1.10b | `prefs:root=General&path=ManagedConfigurationList` | Remove unknown profiles only |
| 1.11 | `prefs:root=PASSWORDS` | DuckDuckGo Autofill **On** — do not turn off |
| 1.V | Repeat 0a, 0c, 0e | VPN + DNS + Autofill unchanged |

### Phase 2 — Apps + USB

| # | Action | Note |
|---|--------|------|
| 2.1 | Open URL | [Malwarebytes Mobile Security](https://apps.apple.com/us/app/malwarebytes-mobile-security/id1327105431) — install in App Store |
| 2.2a | Open URL | `App-prefs:com.apple.MobileSMS` → Unknown & Spam → Malwarebytes |
| 2.2b | Open URL | `App-prefs:com.apple.mobilesafari` → Extensions → Malwarebytes |
| 2.3 | Show Notification | USB: Trust only Andy’s laptop; Developer Mode Off; Windows encrypted backup when cabled |
| 2.4 | Open URL | `prefs:root=Privacy` → Lockdown Mode — **skip** unless high-threat |
| 2.V | Repeat VPN + Wi‑Fi baseline URLs | Browse a familiar site |

---

## What CANNOT be automated (stock iOS)

| Item | Why |
|------|-----|
| **Passcode / Face ID enroll** | Secure Enclave — requires user presence |
| **Stolen Device Protection** | Security-sensitive; on-device confirmation |
| **Trust This Computer** | USB trust dialog — must tap on iPhone |
| **Malwarebytes onboarding & SMS/Safari permissions** | Per-app permission prompts |
| **Encrypted backup password** | Entered in Apple Devices on Windows — never in git |
| **Removing MDM profiles** | May require admin credentials |
| **Toggling VPN/DNS/AutoFill switches** | Apple blocks third-party automation of most Settings toggles |

**No fake MDM:** CyberThreatGotchi does not flash supervision profiles or push configuration without Apple Business Manager enrollment.

---

## Windows assist (when laptop is nearby)

From repo root:

```powershell
cd C:\Users\Owner\Projects\cyberThreatGotchi
```

```powershell
.\scripts\windows\iphone_hardening_assist.ps1 -OpenRunbook
```

Log-only check (no prompts):

```powershell
.\scripts\windows\iphone_hardening_assist.ps1 -LogOnly
```

---

**See also:** [IPHONE_RUN_NOW.md](IPHONE_RUN_NOW.md) · [IPHONE_HARDENING.md](IPHONE_HARDENING.md) · [IPHONE_USB_HARDENING.md](IPHONE_USB_HARDENING.md) · tap-friendly [iphone-run-now.html](../website/iphone-run-now.html) on GitHub Pages.
