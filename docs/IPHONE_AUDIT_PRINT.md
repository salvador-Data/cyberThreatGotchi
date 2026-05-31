# iPhone 15 Pro Max — audit checklist (print)

**Hacker Planet LLC / CyberThreatGotchi** · defensive · authorized use on devices you own · **no secrets on this page**

Print this sheet (or copy to Notes). Complete **on the iPhone** — Windows cannot change Settings without MDM.

**Full reference:** [IPHONE_HARDENING.md](IPHONE_HARDENING.md) · [IPHONE_RUN_NOW.md](IPHONE_RUN_NOW.md)

---

## PRESERVE — do not change during this audit

| Keep as-is | Path to verify unchanged |
|------------|--------------------------|
| **DuckDuckGo VPN / Privacy Pro** | Settings → General → VPN & Device Management → VPN |
| **Wi‑Fi DNS baseline** | Settings → Wi‑Fi → ⓘ → Configure DNS |
| **DuckDuckGo Password Manager (Autofill)** | Settings → General → AutoFill & Passwords → DuckDuckGo Autofill **On** |

**Do NOT:** install Cloudflare WARP, NextDNS, or Malwarebytes **paid VPN** on top of DuckDuckGo. **Do NOT** migrate passwords to Apple Keychain unless you choose to separately.

---

## One-page summary (Phase 0 → 2)

| Step | Action | Verify after |
|------|--------|--------------|
| **0** | Document VPN + Wi‑Fi DNS + DDG Autofill (write baseline below) | — |
| **1** | Phase 1 Settings (1.1–1.11) | **1.V** VPN + DNS + Autofill unchanged |
| **2** | Phase 2 Malwarebytes SMS/Safari + USB + optional tiers | **2.V** VPN + DNS + Autofill unchanged |

**Baseline notes (Step 0):**

```
VPN profile(s): _________________________  Connected? Y / N
Wi‑Fi DNS: Automatic / Manual (servers): _________________________
DDG Autofill: On / Off (must stay On): _________________________
Date: ___________
```

---

## Phase 1 — baseline hardening (Settings only)

Complete all before Phase 2. **Does not change VPN/DNS.**

### 1.1 — iOS current

- [ ] Settings → General → Software Update → latest iOS 17/18
- [ ] Automatic Updates → **On** (iOS Updates + **Security Responses & System Files** / RSR)

### 1.2 — Passcode, Face ID, Stolen Device Protection

- [ ] Face ID & Passcode → **Custom Alphanumeric Code** (or strong 6-digit)
- [ ] Face ID enabled for unlock / Apple Pay as you use them
- [ ] **Stolen Device Protection** → **On** (iOS 17.3+)

### 1.3 — Find My

- [ ] Settings → [your name] → Find My → Find My iPhone → **On**
- [ ] Find My network + Send Last Location → **On** if shown

### 1.4 — Apple ID

- [ ] Sign-In & Security → Two-Factor Authentication → **On**
- [ ] Sign-In & Security → Devices → remove unrecognized devices
- [ ] Strong Apple ID password (**keep DuckDuckGo Password Manager** for autofill)

### 1.5 — Safari

- [ ] Settings → Apps → Safari → Fraudulent Website Warning → **On**
- [ ] Prevent Cross-Site Tracking → **On**
- [ ] Hide IP Address → From Trackers and Websites (or Trackers Only)
- [ ] Optional: Block Pop-ups → **On**

### 1.6 — Mail

- [ ] Settings → Apps → Mail → Privacy Protection → Protect Mail Activity → **On**

### 1.7 — Privacy permissions

- [ ] Privacy & Security → Bluetooth — revoke unneeded apps
- [ ] Privacy & Security → Local Network — revoke unneeded apps
- [ ] Privacy & Security → Tracking → deny cross-app tracking

### 1.8 — Lock screen

- [ ] Face ID & Passcode → Allow Access When Locked — restrict unneeded items
- [ ] Notifications → sensitive apps → Show Previews → When Unlocked or Never

### 1.9 — USB Restricted Mode

- [ ] Face ID & Passcode → USB Accessories (Allow Accessories When Locked) → **Off**

### 1.10 — AirDrop & profiles

- [ ] General → AirDrop → Contacts Only (or Receiving Off in public)
- [ ] General → VPN & Device Management — remove unknown profiles only

### 1.11 — Recommended extras

- [ ] Privacy & Security → Analytics & Improvements — disable if minimizing telemetry
- [ ] Apps → Messages → Filter Unknown Senders → **On**
- [ ] General → AutoFill & Passwords → **DuckDuckGo Autofill → On** (verify, do not turn off)

### Phase 1 VERIFY (required before Phase 2)

- [ ] VPN profile(s) **same** as Step 0 (DuckDuckGo still Connected if it was before)
- [ ] Wi‑Fi ⓘ → Configure DNS **unchanged** from Step 0
- [ ] AutoFill & Passwords → DuckDuckGo Autofill still **On**

---

## Phase 2 — advanced layers (after Phase 1 verify)

### 2.1 — Malwarebytes (SMS + Safari only)

- [ ] App Store → Malwarebytes Mobile Security → install + onboarding
- [ ] Apps → Messages → Unknown & Spam → **Malwarebytes** enabled
- [ ] Apps → Safari → Extensions → Malwarebytes blockers **On** if offered
- [ ] **Malwarebytes paid VPN → OFF** — keep DuckDuckGo VPN/DNS

### 2.2 — DNS VPN apps

- [ ] **SKIP** Cloudflare 1.1.1.1 and NextDNS if Step 0 had DuckDuckGo VPN or Manual DNS

### 2.3 — USB connection hardening

- [ ] USB Accessories OFF when locked — confirm 1.9
- [ ] Trust This Computer — Andy's laptop only; Reset Location & Privacy if unsure
- [ ] Developer Mode → **Off** unless dev week
- [ ] Trusted USB-C cable; data blocker on untrusted charge ports when possible
- [ ] When cabled to Windows: Apple Devices → encrypted local backup (password in password manager — not on this sheet)

### 2.4 — Lockdown Mode (optional)

- [ ] Only if credible targeted threat — otherwise **skip**

### Phase 2 VERIFY (end of session)

- [ ] VPN matches Step 0 baseline
- [ ] Wi‑Fi Configure DNS matches Step 0 baseline
- [ ] DuckDuckGo Autofill still **On**
- [ ] Browse a familiar site — no unexpected captive portal

---

## DDG-compatible improvements (Tier 1–3)

Apply **after** Phase 1 verify. All tiers preserve DuckDuckGo VPN, Wi‑Fi DNS, and DDG Autofill.

### Tier 1 — core (Phase 1 essentials)

- [ ] iOS + RSR automatic updates
- [ ] Strong passcode + Face ID + **Stolen Device Protection**
- [ ] Find My + 2FA + Safari/Mail privacy toggles
- [ ] USB Restricted Mode + AirDrop Contacts Only

### Tier 2 — network & abuse visibility (DDG-safe)

- [ ] **Private Wi‑Fi Address** → Settings → Wi‑Fi → ⓘ → **On** (per network)
- [ ] **Limit IP Address Tracking** → Wi‑Fi ⓘ + Cellular Data Options → **On**
- [ ] **Safety Check** → Settings → Privacy & Security → Safety Check → review sharing / access
- [ ] **Malwarebytes free** — SMS filter + Safari extensions only (**MB VPN OFF**)
- [ ] Messages → Filter Unknown Senders → **On**

### Tier 3 — optional advanced (still DDG-safe)

- [ ] **Advanced Data Protection** (iCloud) — optional E2E for iCloud data; test recovery key storage in password manager first
- [ ] **Lockdown Mode** — high-threat profile only
- [ ] **Safety Check → Emergency Reset** — only if compromise suspected

---

## DO NOT CHANGE (explicit)

- [ ] DuckDuckGo VPN profile — do not remove or replace
- [ ] Wi‑Fi Configure DNS — do not point away from baseline unless intentional IT change
- [ ] DuckDuckGo Autofill / Password Manager — do not disable for hardening
- [ ] Do not stack second DNS-capturing VPN (Cloudflare app, NextDNS app, MB VPN)

---

## Windows read-only assist (optional)

From repo root — prints reminders only; **no iPhone changes**:

```powershell
cd "C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi"
```

```powershell
.\scripts\iphone\iphone_tethering_privacy_checklist.ps1 -DetectUsb
```

---

**Footer:** Hacker Planet LLC · CyberThreatGotchi · no passwords · no API keys · gitignored logs only
