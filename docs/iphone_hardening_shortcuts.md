# iPhone hardening â€” iOS Shortcuts guided routine

**Hacker Planet LLC / CyberThreatGotchi** â€” defensive, authorized-use only. This complements [IPHONE_RUN_NOW.md](IPHONE_RUN_NOW.md), the guided wizard **[iphone_hardening_guide.html](iphone_hardening_guide.html)** (Prev/Next/Mark done on Safari), and the Windows orchestrator `scripts/windows/iphone_hardening_automate.ps1`.

**Honest limit:** Stock iOS does not allow Shortcuts (or Windows scripts) to flip Settings toggles, enroll Face ID, set passcodes, trust a PC, or install App Store apps without **you** tapping through each screen. This routine **opens each Settings pane in order** so you spend less time hunting menus.

**Preserve:** Do **not** replace Andy's **DuckDuckGo VPN/DNS** or **DuckDuckGo Password Manager**. Skip Cloudflare/NextDNS if VPN/DNS is already set. Do **not** enable Malwarebytes paid VPN.

**Step IDs** match `iphone_hardening_guide.html` and `iphone_hardening_automate.ps1` (21 steps).

---

## Importable Shortcut: **CTG iPhone Harden**

Apple does not allow shipping a signed `.shortcut` binary in git. Build once on the iPhone using the exact action list below.

### Create the Shortcut

1. **Shortcuts** app â†’ **+** â†’ name: **CTG iPhone Harden**
2. Tap **Shortcut Settings** (â“˜) â†’ enable **Show in Share Sheet** (optional)
3. Add actions **in order** from the table below
4. After each **Open URL**, add **Wait** â†’ **8 seconds** (adjust if you need more time on a step)
5. At Phase boundaries, add **Show Notification** with the text shown

### Loop pattern (repeat per step)

For each row in the action table:

| # | Shortcuts action | Configuration |
|---|------------------|---------------|
| A | **Show Notification** | Title: `CTG Step {id}` Â· Body: step reminder text |
| B | **Open URL** | Paste URL from table (or Malwarebytes App Store link) |
| C | **Wait** | 8 seconds |
| D | *(optional)* **Ask for Input** | Prompt: `Step {id} done? Continue?` Â· Default: Yes |

Wrap all 21 iterations in a single Shortcut, or split into **CTG iPhone Harden P1** (steps 0aâ€“1.V) and **CTG iPhone Harden P2** (2.1â€“2.V).

---

## Action list (21 steps â€” paste URLs exactly)

### Step 0 â€” Baseline (document only â€” no toggles)

| ID | Notification body | Open URL |
|----|-------------------|----------|
| **0a** | Document VPN profile â€” do NOT disconnect DuckDuckGo | `prefs:root=General&path=ManagedConfigurationList` |
| **0b** | Tap (i) on home Wiâ€‘Fi â†’ Configure DNS â€” write down; do not change | `prefs:root=WIFI` |
| **0c** | Confirm DuckDuckGo Autofill stays **On** â€” screenshot baseline | `prefs:root=PASSWORDS` |

After **0c**, add **Show Notification**: `Baseline saved? Proceed to Phase 1.`

### Phase 1 â€” Settings

| ID | Notification body | Open URL |
|----|-------------------|----------|
| **1.1** | Install updates; Automatic Updates On | `prefs:root=General&path=SOFTWARE_UPDATE_LINK` |
| **1.2** | Strong passcode; Face ID; Stolen Device Protection **On** | `prefs:root=PASSCODE` |
| **1.3** | Find My â†’ Find My iPhone **On** | `prefs:root=APPLE_ACCOUNT` |
| **1.4** | Sign-In & Security â†’ 2FA **On**; review Devices | `prefs:root=APPLE_ACCOUNT` |
| **1.5** | Fraud warning, tracking, Hide IP | `App-prefs:com.apple.mobilesafari` |
| **1.6** | Protect Mail Activity **On** | `prefs:root=MAIL` |
| **1.7** | Bluetooth / Local Network / Tracking | `prefs:root=Privacy` |
| **1.8** | Trim lock-screen access; notification previews | `prefs:root=PASSCODE` |
| **1.9** | USB Accessories **Off** when locked | `prefs:root=PASSCODE` |
| **1.10** | AirDrop Contacts Only; audit profiles | `prefs:root=General&path=AIRDROP_LINK` |
| **1.11** | DuckDuckGo Autofill **On** â€” do not turn off | `prefs:root=PASSWORDS` |
| **1.V** | Verify VPN + DNS + Autofill unchanged â€” do NOT start Phase 2 until pass | `prefs:root=General&path=ManagedConfigurationList` |

After **1.V**, add notifications to re-open Wiâ€‘Fi and Passwords URLs (same as 0b, 0c) or run a **Repeat 2** loop with those two URLs.

### Phase 2 â€” Apps + USB

| ID | Notification body | Open URL / action |
|----|-------------------|-------------------|
| **2.1** | Install Malwarebytes â€” do NOT enable paid VPN | `https://apps.apple.com/us/app/malwarebytes-mobile-security/id1327105431` |
| **2.2** | SKIP Cloudflare/NextDNS if DuckDuckGo VPN/DNS already set | `prefs:root=General&path=ManagedConfigurationList` |
| **2.3** | Messages + Safari Malwarebytes extensions | `App-prefs:com.apple.MobileSMS` then `App-prefs:com.apple.mobilesafari` (two Open URL blocks) |
| **2.4** | USB: Trust only Andy's laptop; Developer Mode Off; encrypted backup when cabled | `prefs:root=PASSCODE` |
| **2.5** | Lockdown Mode â€” **skip** unless high-threat | `prefs:root=Privacy` |
| **2.V** | Final VPN + DNS verify; browse a familiar site | `prefs:root=General&path=ManagedConfigurationList` then `prefs:root=WIFI` |

---

## Advanced: loop with counter (optional)

For a compact Shortcut, use **Repeat** with a **Dictionary** or **Text** list of URLs â€” Shortcuts cannot iterate our markdown table automatically without manual setup. Recommended: linear action list above for reliability.

If a link opens only the parent Settings pane (common on iOS 18), follow the manual path in [IPHONE_RUN_NOW.md](IPHONE_RUN_NOW.md) or the HTML wizard.

---

## What CANNOT be automated (stock iOS)

| Item | Why |
|------|-----|
| **Passcode / Face ID enroll** | Secure Enclave â€” requires user presence |
| **Stolen Device Protection** | Security-sensitive; on-device confirmation |
| **Trust This Computer** | USB trust dialog â€” must tap on iPhone |
| **Malwarebytes onboarding & SMS/Safari permissions** | Per-app permission prompts |
| **Encrypted backup password** | Entered in Apple Devices on Windows â€” never in git |
| **Removing MDM profiles** | May require admin credentials |
| **Toggling VPN/DNS/AutoFill switches** | Apple blocks third-party automation of most Settings toggles |

**No fake MDM:** CyberThreatGotchi does not flash supervision profiles or push configuration without Apple Business Manager enrollment.

---

## Windows orchestrator (when laptop is nearby)

From repo root:

```powershell
cd C:\Users\Owner\Programs\Hacker Planet LLC\cyberThreatGotchi
```

Full 21-step interactive flow + HTML wizard:

```powershell
.\scripts\windows\iphone_hardening_automate.ps1 -OpenGuide
```

Resume session:

```powershell
.\scripts\windows\iphone_hardening_automate.ps1 -Resume -OpenGuide
```

Log-only validation (no prompts):

```powershell
.\scripts\windows\iphone_hardening_automate.ps1 -LogOnly
```

Legacy alias:

```powershell
.\scripts\windows\iphone_hardening_assist.ps1 -OpenRunbook
```

---

**See also:** [iphone_hardening_guide.html](iphone_hardening_guide.html) (recommended wizard) Â· [IPHONE_RUN_NOW.md](IPHONE_RUN_NOW.md) Â· [IPHONE_HARDENING.md](IPHONE_HARDENING.md) Â· [IPHONE_USB_HARDENING.md](IPHONE_USB_HARDENING.md) Â· static [iphone-run-now.html](../website/iphone-run-now.html) on GitHub Pages.
